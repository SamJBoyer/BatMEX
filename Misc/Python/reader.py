import pickle as pkl 
import matplotlib.pyplot as plt 
import numpy as np

with open ('test_data.pkl', 'rb') as f:
    data = pkl.load(f)



a = []

for i in range(len(data)):
    a += [data[i][118]]

ug = a 
buh = []
for i in range(len(ug)):
    for j in range(len(ug[i])):
        buh.append(ug[i][j])

x = np.linspace(0, len(buh), len(buh))


# Add labels and title
plt.plot(x, buh)

plt.xlabel('x')
plt.ylabel('f(x)')
plt.title('Plot of f(x) = sin(x)')
plt.grid(True)
plt.legend()

# Show the plot
plt.show()

z=1