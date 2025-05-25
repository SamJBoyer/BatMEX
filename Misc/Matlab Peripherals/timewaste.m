

%add the proper version of the matlab script 

sdkPath1 = 'C:\Program Files\Blackrock Microsystems\Cerebus Central Suite 7.6.1';
restoredefaultpath;
addpath(sdkPath1)
savepath;

clear flag; 
clear data_pot;
clearvars;
pyenv('Version', 'C:\Users\ReHAB-CNRA\anaconda3\envs\redis_test\python.exe');
% Start by checking if the Python environment is configured correctly
pyenv

% Import the redis library in Python
redis = py.importlib.import_module('redis');

% Create a connection to the Redis server (default is localhost:6379)
r = redis.Redis(pyargs('host', '192.168.7.15', 'port', 6379));

% Check if the connection is successful (ping the server)
if r.ping()
    disp('Connected to Redis server');
else
    error('Could not connect to Redis server');
end



cbmex('open')
% establish configs for each channel. read the blackrock docs for more info
channel_count = 256;
sample_rate_setting = 5;
for i = 1:channel_count
    cbmex('config', i, 'smpgroup', sample_rate_setting)
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
cbmex('trialconfig',1)


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
    tic
    pause(bin_size);
    processing_time = tic;
    [event_data,time,cont] = cbmex('trialdata',1);
    % Step 1: Extract the 3rd column from all struct entries as a cell array
    arrays = {cont{:, 3}};  % This will get all the 3rd index arrays as a cell array
    % Step 2: Concatenate all arrays into one single array
    concatenated = cell2mat(arrays);  % This will concatenate the arrays into a single long array
    % Step 3: Convert the concatenated array into uint8
    flattenedBuffer = int16(concatenated(:));

    

    % Define the stream name and a test value
    streamName = 'mystream';
    binary = typecast(flattenedBuffer, 'uint8');
    testValue = py.dict(pyargs('field1', py.bytes(binary), 'field2', 'value2'));
        %rewrite the shared memory
    streamId = r.xadd(streamName, testValue);

    %since we generally want to keep our soft bin size consistent, we subtract
    %the time it took to process this data from the total aimed bin size,
    %to hopefully get a consistent bin. 
    delta_time = toc(processing_time);
    delay_offset = bin_size - delta_time;
    toc * 1000
end 

data_points
cbmex('trialconfig',0)
cbmex('close')
disp("ended");


