import numpy as np 
import uuid
import subprocess
import os
import yaml
import time
import signal

def launch_cerebus_reader(sample_rate_group, filter_group, sdk_path, channel_count, global_id, raw_pot_size, central_instance) -> subprocess.Popen:
    cmd = f"matlab -batch run(\"CerebusReader({sample_rate_group}, {filter_group}, '{sdk_path}', {channel_count}, '{global_id}', {raw_pot_size}, {central_instance})\")"
    return subprocess.Popen(cmd)

def launch_bailer(channel_count, global_id):
    args = ['python', 'bailer.py', str(channel_count), str(global_id)]
    return subprocess.Popen(args)

'''
things the overlord needs to communicate to the matlab process: 

- the uuid 
- the central instance
- the filter number
- the sampling number 
- raw pot size
- data pot file 
- flag file 
- the library path 
- channel count 

things the overlord needs to communicate to the python process:

'''
filter_group = 2
sample_group = 3
#load the nsp configs 
with open ('config.yaml', 'r') as f:
    basic_nsp_config = yaml.load(f, Loader=yaml.FullLoader)

#create config dict
nsp_master_config = basic_nsp_config
#get the sample and filter number from yaml 
for key in nsp_master_config.keys():
    nsp_master_config[key]['sample_rate_group'] = sample_group
    nsp_master_config[key]['filter_group'] = filter_group

sample_rate = 30000
bytes_per_channel = 2
bin_size = 20/1000
safety_inflation = 0.5 #the percentage extra space we leave in the buffer above our calculation


#for the normal buffer size 
mmap_files = []
ongoing_processes = []
for nsp_name, config in nsp_master_config.items():
    #generate the nsp's global ID for this block and name the thread's mmaps 
    id = uuid.uuid1()
    flag_file = f'mmaps/{id}_FLAG.dat'
    data_pot_file = f'mmaps/{id}_DATA_POT.dat'
    mmap_files.append(flag_file)
    mmap_files.append(data_pot_file)
    initial_flag = b"EMPT"
    channel_count = config['channels']
    sdk_path = config['library_path']
    instance = config['instance']

    #calculate the expected size for the nsps and create the mmaps
    expected_data_size = int(sample_rate * bytes_per_channel * channel_count * bin_size * (1.0 + safety_inflation))
    initial_data_pot = np.zeros(expected_data_size, dtype=np.uint8).tobytes()
    flag_configs = {flag_file : initial_flag, data_pot_file : initial_data_pot}
    for file_name, initial_entry in flag_configs.items():
        with open(file_name, "wb") as f:
            f.write(initial_entry)

    ongoing_processes.append(launch_cerebus_reader(sample_group, filter_group, sdk_path, channel_count, id, expected_data_size, instance))
    time.sleep(10)
    ongoing_processes.append(launch_bailer(channel_count, id))
test_input = input()

# i really have no evidence this is working for matlab 
for proc in ongoing_processes:
    p = proc.pid
    os.kill(p, signal.SIGTERM)

time.sleep(3)
#delete the mmaps on clean 
for file in mmap_files:
    os.remove(file)

pass

# nsps = x, y, z

