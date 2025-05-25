import mmap
import numpy as np
from copy import copy
import time
import mmap
import redis
import pickle as pkl 
import matplotlib.pyplot as plt
# Specify the filename for the memory-mapped file
flag_file = "mmaps/reader.dat"
data_pot_file = "mmaps/data_pot.dat"
file_size = 4 

'''

_______
HANDSHAKING PROCEDURE

the flag is FULL if the writer has deposited data into the datapot that hasn't been processed.
If the flag is FULL, the writer will not write

the flag is EMPT if the reader has read the data. The reader will not read from the mmap until the 
flag is FULL again 
_______

'''

# Get the data_pot shared memory file
with open(data_pot_file, 'r+b') as f:
    data_pot = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)  # 0 means map the entire file


# get mmap for enemy flag
with open(flag_file, "r+b") as f:
    # Memory-map the file
    flag = mmap.mmap(f.fileno(), file_size)

# grab all 
ts = time.time()
buffer = []
c = 0
batch_size = 30

#r = redis.StrictRedis('oh my god, there is no windows redis')
simcum = [] 
channels = 256
byte_counter = 0 

while (time.time() - ts < 15):

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
        calc_num_samples = len(decoded_data) // channels
        if calc_num_samples != nominal_num_samples:
            print("sample size mismatch")

        reshaped_data = [decoded_data[i:i + nominal_num_samples] for i in range(0, len(decoded_data), nominal_num_samples)]



        [buffer.append(i) for i in reshaped_data[9]]
        print(c)
        #print(f"read datasize {len(data)}")
        c+=1
        #x = np.linspace(0, len(buffer), len(buffer))
        plt.plot(reshaped_data[9])
        #plt.hold(True)
        plt.show()
    flag.seek(0)

    #nothing new has been added to the file. lets process some data while we wait 

    #simulate the neurostruct process, we don't have it ported yet 
    #while len(buffer) > batch_size:
    #    j = 0 
    #    batch = [buffer.pop() for _ in range(batch_size)]
    ##    #send to redis using pipeline 
     #   simcum.append(batch)
    
    #print("loop")
x = np.linspace(0, len(buffer), len(buffer))


# Add labels and title
#plt.plot(x, buffer)

plt.xlabel('x')
plt.ylabel('f(x)')
plt.title('Plot of f(x) = sin(x)')
plt.grid(True)
plt.legend()

# Show the plot
plt.show()


with open("test_data.pkl", 'wb') as f:
    # Use pkl.dump to serialize 'buffer' and write to file 'f'
    pkl.dump(buffer, f)


    # grab all the data from the shared memory 
    # set the reader flag to "ready"

    #for the nsp thread

    #grab the data from the buffer at the interval
    #check to see if the reader flag is ready
    # set flag to busy
    # fill the shared memory pot
    # set flag to ready 
    
    pass

flag.close()
print("done")


