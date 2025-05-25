import mmap
import numpy as np
from copy import copy
import time
import mmap
import sys
import pickle as pkl 
import matplotlib.pyplot as plt


'''
author: Sam Boyer
gmail: sam.james.boyer@gmail.com

_______
HANDSHAKING PROCEDURE

the flag is FULL if the writer has deposited data into the datapot that hasn't been processed.
If the flag is FULL, the writer will not write

the flag is EMPT if the reader has read the data. The reader will not read from the mmap until the 
flag is FULL again 
_______
'''
print("launching")
cmd_args = sys.argv
channel_count = int(cmd_args[1])
global_id = cmd_args[2]

flag_file = f"mmaps/{global_id}_FLAG.dat"
data_pot_file = f"mmaps/{global_id}_DATA_POT.dat"
flag_size = 4 

# Get the mmap shared memory file (data pot)
with open(data_pot_file, 'r+b') as f:
    data_pot = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)  # 0 means map the entire file

# get mmap for the flag
with open(flag_file, "r+b") as f:
    # Memory-map the file
    flag = mmap.mmap(f.fileno(), flag_size)


buffer = []
c = 0
byte_counter = 0 

while (True):

    #wait until there is a new message 
    if (flag.read().decode() == 'FULL'):
        header_bytes = data_pot.read(12)
        header = np.frombuffer(header_bytes, dtype=np.int32)
        payload_length = copy(header[0])
        nominal_num_samples = copy(header[1])
        total_samples_recorded = copy(header[2])
        data = copy(data_pot.read(payload_length - 12))
        flag[:] = b'EMPT'
        data_pot.seek(0)
        byte_counter += payload_length

        decoded_data = np.frombuffer(data, dtype=np.int16)
        calc_num_samples = len(decoded_data) // channel_count
        if calc_num_samples != nominal_num_samples:
            print("sample size mismatch")

        reshaped_data = [decoded_data[i:i + nominal_num_samples] for i in range(0, len(decoded_data), nominal_num_samples)]
        [buffer.append(i) for i in reshaped_data[9]]
        #print(c)
        #print(f"read datasize {len(data)}")
        c+=1
    flag.seek(0)

    #nothing new has been added to the file. lets process some data while we wait 

    #simulate the neurostruct process, we don't have it ported yet 
    #while len(buffer) > batch_size:
    #    j = 0 
    #    batch = [buffer.pop() for _ in range(batch_size)]
    ##    #send to redis using pipeline 
     #   simcum.append(batch)
    
    #print("loop")
#x = np.linspace(0, len(buffer), len(buffer))


# Add labels and title
#plt.plot(x, buffer)

#plt.xlabel('x')
#plt.ylabel('f(x)')
#plt.title('Plot of f(x) = sin(x)')
#plt.grid(True)
#plt.legend()

# Show the plot
#plt.show()



flag.close()
print("done")


