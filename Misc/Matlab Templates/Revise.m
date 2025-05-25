% author: Sam Boyer
% gmail: sam.james.boyer@gmail.com
%
% this script is part of the adjudicator process that gets the neural data
% from matlab out into a language that isn't so slow it ruins our real-time
% system! sadly, BlackRock's API is best in matlab, and seperating the headers 
% from the raw data with udp packets is a NIGHTMARE! The matlab API is super 
% good at getting data, but using redis from matlab is unviable due to its
% sluggishness. Therefore, we will buffer the data in matlab using the
% naitive matlab API, then use a shared memory file with a custom handshaking
% procedure to get the data out into a different langauge that isn't D-tier. 

%_______
% HANDSHAKING PROCEDURE
%
% the flag is FULL if the writer has deposited data into the datapot that hasn't been processed.
% If the flag is FULL, the writer will not write
%
% the flag is EMPT if the reader has read the data. The reader will not read from the mmap until the 
% flag is FULL again 
%_______

%function exitcode = CerebusReader(sample_rate_group, filter_group, sdk_path, channel_count, uuid, raw_pot_size, central_instance)
%function exitcode = CerebusReader(myteststring)
    
% add the library dynamically. because each nsp uses a different sdk, we
% need to only temporarily add them so they don't collide with the others
% this isn't even really implemented right now 
sdk_path = 'C:\Program Files\Blackrock Microsystems\Cerebus Central Suite'
addpath(sdk_path)

central_instance = 0
channel_count = 256
filter_group = 3 
sample_rate_group = 3
% establish connection to the nsp 
cbmex('open', 0, 'instance', central_instance);

% establish configs for each channel. read the blackrock docs for more info
for i = 1:channel_count
    cbmex('config', i, 'instance', central_instance, 'smpfilter', filter_group, 'smpgroup', sample_rate_group)
end 

%config the trial
cbmex('trialconfig',1, 'instance', central_instance)

%we use softbinning to protect our less efficient
%nodes this number should be less than half that of our hard-bin, but also 
%not small enough to cause null returns. So far, 10ms seems to be the best 
bin_size = 10 / 1000;
delay_offset = bin_size; 
total_read_datapoints = 0; %used to make sure we have read all the data 

%central loop to read the data and pass it to our memory map for our python
%reader to read and put into redis 
disp("starting reading procedure")
while(true) %need to have some way to shut this down via a signal so it isn't just running forever 
    pause(bin_size);
    processing_time = tic;
    [event_data,time,cont] = cbmex('trialdata',1,'instance', central_instance);
    p=7
end 

data_points
cbmex('trialconfig',0)
cbmex('close')
disp("ended");
clearvars; 
exitcode = 0; 
