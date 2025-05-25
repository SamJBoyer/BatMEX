

%add the proper version of the matlab script 
restoredefaultpath
sdkPath1 = 'C:\Program Files (x86)\Blackrock Microsystems\NeuroPort Windows Suite';
restoredefaultpath;
addpath(sdkPath1)
savepath;
clear flag; 
clear data_pot;
clearvars;

%_______
% HANDSHAKING PROCEDURE
%
% the flag is FULL if the writer has deposited data into the datapot that hasn't been processed.
% If the flag is FULL, the writer will not write
%
% the flag is EMPT if the reader has read the data. The reader will not read from the mmap until the 
% flag is FULL again 
%_______

% get this from command line
my_uuid = "TESTUUID";
raw_pot_size = 460800; % needs to get this from the command line
sharedMemoryFileName = 'mmaps/data_pot.dat';
flag_file = "mmaps/reader.dat";

byte_size = 2; %the standard number of bytes in each sample. i've only ever seen this be 2 (int16)
flag_size = 4;


%% set up the flag mmmap 
inital_flag = 'EMPT'; % declare the pot to be empty, at first
byte_data = uint8(inital_flag);
fid = fopen(flag_file, 'wb');
% Check if the file was opened successfully
if fid == -1
    error('Failed to open the file.'); % crash if occurs
end
fwrite(fid, byte_data, 'uint8');
flag = memmapfile(flag_file, 'Format', 'uint8', 'Writable', true, 'Repeat', flag_size);

%% setup the data_pot mmap 
pot_unit_size = raw_pot_size / byte_size; %number of units in the data pot 
initial_entry = int16(zeros(pot_unit_size, 1));
fid = fopen(sharedMemoryFileName, 'wb');
% Check if the file was opened successfully
if fid == -1
    error('Failed to open the file.'); % if this occurs, the world should just explode 
end
fwrite(fid, initial_entry, 'int16');
data_pot = memmapfile(sharedMemoryFileName, 'Format', 'int16', 'Writable', true, 'Repeat', pot_unit_size);

% return if the flag is "EMPT"
function result = potIsEmpty(enemy_flag)
    data = char(enemy_flag.Data);
    str = 'EMPT';
    char_array = reshape(str, [4, 1]);
    result = isequal(data, char_array);
end 

% establish connection to the nsp 
%cbmex('open', 2, 'inst-addr', '192.168.137.34', 'inst-port', 51001);
cbmex('open', 0, 'instance', 2)

% establish configs for each channel. read the blackrock docs for more info
channel_count = 128;
sample_rate_setting = 2;
for i = 1:channel_count
    cbmex('config', i, 'instance', 2, 'smpgroup', sample_rate_setting)
end 

% we need the range of an int32 for our encoding header, but our memory map
% must be homogenous. Therefore, we must convert our int32 into 2 int16s
% (our assumed size). this function could be cleaner 
function [low, high] = convertToInt16(value)
    value = int32(value);  % Ensure input is in int32 format
    % Extract the high 16 bits (upper 16 bits) - shift to the right
    temp_high = bitshift(value, -16);  % Shifts the upper 16 bits to the lower position
    % Check if high exceeds the range of int16
    if temp_high > int16(32767)
        temp_high = temp_high - 65536;  % Convert to signed 16-bit by subtracting 2^16 (65536)
    elseif temp_high < int16(-32768)
        temp_high = temp_high + 65536;  % Convert to signed 16-bit by adding 2^16 (65536)
    end
    high = int16(temp_high);  % Cast to int16

    % Extract the low 16 bits (lower 16 bits) - mask to get the last 16 bits
    temp_low = bitand(value, int32(65535));  % Mask with 0xFFFF to get the lower 16 bits
    % Check if low exceeds the range of int16
    if temp_low > int16(32767)
        temp_low = int16(temp_low - 65536);  % Convert to signed 16-bit by subtracting 2^16 (65536)
    elseif temp_low < int16(-32768)
        temp_low = int16(temp_low + 65536);  % Convert to signed 16-bit by adding 2^16 (65536)
    end
    low = int16(temp_low);
end

% will eventually be removed, but is currently a testing feature 
trial_length=140;
current_time=tic;

%config the trial
cbmex('trialconfig',1, 'instance', 2)


%we use softbinning to protect our less efficient
%nodes this number should be less than half that of our hard-bin, but also 
%not small enough to cause null returns. So far, 10ms seems to be the best 
bin_size = 10 / 1000;
delay_offset = bin_size; 
total_read_datapoints = 0; %used to make sure we have read all the data 

%central loop to read the data and pass it to our memory map for our python
%reader to read and put into redis 
disp("starting")
while(trial_length > toc(current_time))

    pause(bin_size);
    processing_time = tic;
    [event_data,time,cont] = cbmex('trialdata',1, 'instance', 2);
    % Step 1: Extract the 3rd column from all struct entries as a cell array
    arrays = {cont{:, 3}};  % This will get all the 3rd index arrays as a cell array
    % Step 2: Concatenate all arrays into one single array
    concatenated = cell2mat(arrays);  % This will concatenate the arrays into a single long array
    % Step 3: Convert the concatenated array into uint8
    flattenedBuffer = int16(concatenated(:));

    %pause this thread until the reader has the EMPT flag. this could use
    %work because it could get stuck in here and wait for ever 
    while(potIsEmpty(flag) == false) % should check for time to abort otherwise waits forever 
        disp("CLANK!") 
    end
    
    temp = cont(1,3);
    samples_in_packet = length(temp{1,1});
    total_read_datapoints = total_read_datapoints + samples_in_packet;

    % buffer is structured as follows: 
    % first 4 bytes stores the TOTAL length of the payload in bytes 
    % total_length = 4+4+4+2*ch*x + whatever the events are 

    % the next 4 bytes stores a int32. that tells the number of samples in
    % this packet 
    % the next 4 bytes stores the number of samples read 
    % the next x byte is the sample buffer 

    % the events are CURRENTLY NOT IMPLEMENTED 
    % the next 4 bytes tells how many events are in the data packaghe\
    % maybe there should be a way to convey time 

    % since a int16 is not big enough to store the potential number of
    % samples, we need to use an int32, but bitshifted down into 2 int16s 

    payload_length = int32(4 + 4 + 4 + 2*length(flattenedBuffer));
        
    % make sure our payload doesn't overrun the size of our memory map 
    if payload_length <= raw_pot_size  
        %since all of these numbers are int32s, we have to convert them
        %into 2 int16s for our memory map to not freak out 
        [payload_length_a, payload_length_b] = convertToInt16(payload_length);
        [length_a, length_b] = convertToInt16(samples_in_packet);
        [total_a, total_b] = convertToInt16(total_read_datapoints);

        % create the total buffer, then pad with zeros because our payload
        % must equal the length of the mapped memory 
        payload = [payload_length_a; payload_length_b; length_a; length_b; total_a; total_b; flattenedBuffer];
        padded_payload = [payload; zeros(pot_unit_size - length(payload/pot_unit_size), 1, 'int16')];
    
        %rewrite the shared memory
        data_pot.Data = padded_payload;
        flag.Data = uint8('FULL');
    else
        %if our data is too large for our map (which is calculated by the
        %overlord to be 1.5 x 20ms of data) then we just toss the data
        %because we can't use it. this is a major error that shouldn't
        %occur during runtime. This error almost exclusively occurs in the
        %first 5 seconds of running while both processes are waiting to
        %boot up, which makes sense. Any process that blocks the execution
        %of the data-handoff will cause the cbmex trial data buffer to
        %overload with data, which will cause this issue. Therefore, seeing
        %this issue past the first couple seconds is a sign that either/or
        %process is performing too slow 
        disp("data was too large")
    end
    %since we generally want to keep our soft bin size consistent, we subtract
    %the time it took to process this data from the total aimed bin size,
    %to hopefully get a consistent bin. 
    delta_time = toc(processing_time);
    delay_offset = bin_size - delta_time;
end 

data_points
cbmex('trialconfig',0)
cbmex('close')
disp("ended");


