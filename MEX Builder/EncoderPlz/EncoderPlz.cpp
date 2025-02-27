#include "mex.h"
#include <iostream>
#include "matrix.h"
#include <string>
#include <stdint.h>
#include <vector>
#include "hiredis.h"
#include <thread>
#include <atomic>
#include <condition_variable>
#include <mutex>
#include <queue>>
#include <cstdint>
#include <chrono>

//mutex breaks matlab for some reason 
class ProcessingThread {
private:

    static ProcessingThread* instance;
    std::atomic<bool> running;
    std::atomic<bool> redisAvailable;
    std::atomic<bool> commandQueueAvailable;
    std::queue<std::string> commandQueue;
    int threshold = 3; //3 ms 

    redisContext* r;

    ProcessingThread() {
        r = redisConnect("192.168.7.15", 6379);
        if (r == nullptr || r->err) {
            std::cerr << "Error: Unable to connect to Redis." << std::endl;
            exit(1);
        }
        redisAvailable.store(true, std::memory_order_release);
        printf("connection successful");
    }

    void ListenForCommands() {
        while (running.load()) {
            //std::lock_guard<std::mutex> guard(redisMutex);
            std::this_thread::sleep_for(std::chrono::milliseconds(100)); //simulate waiting for commands 

        }
    }

public:
    static ProcessingThread* GetInstance() {
        if (instance == nullptr) {
            instance = new ProcessingThread();
        }
        return instance;
    }

    // needs a shutdown method 

    void AddToRedis(std::vector<uint32_t> events, std::vector<int16_t> cont) {

        
        redisReply* reply = (redisReply*)redisCommand(r, "xadd test * events %b cont %b", events.data(), events.size() * sizeof(uint32_t), cont.data(), cont.size() * sizeof(int16_t));

        if (reply == nullptr) {
            std::cerr << "Error: Failed to execute XADD command to Redis." << std::endl;
        }
        else {
            // Optionally: Log the reply or handle further
            std::cout << "Added data to Redis: " << reply->str << std::endl;
        }
        freeReplyObject(reply);


        /* we should for sure replace this with a semaphore 
        auto start = std::chrono::high_resolution_clock::now();
        while (std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::high_resolution_clock::now() - start).count() < threshold){
            if (redisAvailable.load(std::memory_order_acquire)) {
                printf("sfs");
                redisAvailable.store(false, std::memory_order_release);
                printf("ssssssss");

                std::string testString = "bingus";
                redisReply* reply = (redisReply*)redisCommand(r, "xadd test * data %s", testString.c_str());
                // Check if Redis responded successfully
                printf("fesf");

                if (reply == nullptr) {
                    std::cerr << "Error: Failed to execute XADD command to Redis." << std::endl;
                }
                else {
                    // Optionally: Log the reply or handle further
                    std::cout << "Added data to Redis: " << reply->str << std::endl;
                }
                freeReplyObject(reply);
                redisAvailable.store(true, std::memory_order_release);
                break;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(1));  // Sleep for 10ms to reduce CPU load
        }*/
    }

    std::queue<std::string> GetCommandBuffer() {
        //std::lock_guard<std::mutex> guard(commandQueueMutex);
        std::queue<std::string> returnQueue = commandQueue; 
        commandQueue.empty();
        return returnQueue; 
    }

};

ProcessingThread* ProcessingThread::instance = nullptr;


// Function to process the second column of the input cell array
std::vector<uint32_t> EncodeEvents(const mxArray* inputCellArray) {
    std::vector<std::vector<uint32_t>> buffers; 
    mwSize numRows = mxGetM(inputCellArray);

    size_t total_size = 0;
    for (mwSize i = 0; i < numRows; i++) {
        // Extract the cell in the second column of row i (index 1)
        mxArray* secondColumnArray = mxGetCell(inputCellArray, i + numRows);  // Second column index = 1
        printf("woogla");
        // Check if the cell is empty

        // If the cell is empty or the data inside is empty, skip the row
        if (secondColumnArray == nullptr || mxGetNumberOfElements(secondColumnArray) == 0) {
            mexPrintf("Row %zu: The second column is an empty array ([]), skipping.\n", i + 1);
            buffers.push_back(std::vector<uint32_t>(i));
            total_size += 2;
            continue;  // Skip processing this row
        }

        mwSize numElements = mxGetNumberOfElements(secondColumnArray);
        mexPrintf("Row %zu: \n", numElements);

        // Get the number of elements in the extracted array (1 * y)
        // we need to add this to our buffer, but lets do that later 

        total_size += numElements; //speciically don't add the channel num so we can an initializer 
        //int16_t* data = (int16_t*)malloc(sizeof(int16_t) * (numElements + 1));
        uint32_t *content = static_cast<uint32_t*>(mxGetData(secondColumnArray));

        printf("boogdda");

        buffers.push_back(std::vector<uint32_t> (content, content + numElements));
        printf("ssssss;a");

        // Print the length of the extracted array
    }

    printf("a");
    std::vector<uint32_t> all_data; 
    //convert into a single buffer 
    int c = 0; 
    for (int i = 0; i < buffers.size(); i++) {
        size_t size = buffers[i].size();
        for (int j = 0; j < size; j++) {
            all_data.push_back(buffers[i][j]);
        }
        //memcpy((int16_t*)mxGetData(buffer) + c, buffers[i].data(), size * sizeof(int16_t));
        //c += size;
    }
    printf("b");
    return all_data;
}

template <typename T>
std::vector<T> EncodeCont(const mxArray* inputCellArray, int target_col, int ratio) {
    std::vector<std::vector<T>> buffers;
    mwSize numRows = mxGetM(inputCellArray);

    size_t total_size = 0;
    for (mwSize i = 0; i < numRows; i++) {
        // Extract the cell in the second column of row i (index 1)
        mxArray* targetCell = mxGetCell(inputCellArray, i + numRows * target_col);  // Second column index = 1
        printf("woogla");
        // Check if the cell is empty

        // If the cell is empty or the data inside is empty, skip the row
        if (targetCell == nullptr || mxGetNumberOfElements(targetCell) == 0) {
            mexPrintf("Row %zu: The second column is an empty array ([]), skipping.\n", i + 1);
            buffers.push_back(std::vector<T>(i));
            total_size += 2;
            continue;  // Skip processing this row
        }

        mwSize numElements = mxGetNumberOfElements(targetCell);
        T* sizeConv = (T*)malloc(sizeof(mwSize));
        std::vector<T> conv(sizeConv, sizeConv + ratio); //convert to a smaller 
        mexPrintf("Row %zu: \n", numElements);

        // Get the number of elements in the extracted array (1 * y)
        // we need to add this to our buffer, but lets do that later 

        total_size += numElements; //speciically don't add the channel num so we can an initializer 
        //int16_t* data = (int16_t*)malloc(sizeof(int16_t) * (numElements + 1));
        T* content = static_cast<T*>(mxGetData(targetCell));

        printf("boogdda");

        buffers.push_back(std::vector<T>(content, content + numElements));
        printf("ssssss;a");

        // Print the length of the extracted array
    }

    printf("a");
    std::vector<T> all_data;
    //convert into a single buffer 
    int c = 0;
    for (int i = 0; i < buffers.size(); i++) {
        size_t size = buffers[i].size();
        for (int j = 0; j < size; j++) {
            all_data.push_back(buffers[i][j]);
        }
        //memcpy((int16_t*)mxGetData(buffer) + c, buffers[i].data(), size * sizeof(int16_t));
        //c += size;
    }
    printf("b");
    return all_data;
}

void SendToRedis(const int nrhs, const mxArray* inputArray[]) {
    ProcessingThread* instance = ProcessingThread::GetInstance();
    std::vector<uint32_t> events = EncodeEvents(inputArray[1]);
    std::vector<int16_t> cont = EncodeCont<int16_t>(inputArray[2], 2, 4);
    instance->AddToRedis(events, cont);
    printf("success");
}

mxArray* ProcessCommand(std::string input, const int nrhs, const mxArray* inputArray[]) {
    if (input == "connect") {
        ProcessingThread::GetInstance();
    }else if (input == "send") {
        printf("sending to redis");
        SendToRedis(nrhs, inputArray);
    }
    else {
        printf("can't understand you");
    }//also include get commands
    return NULL;
}

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]) {    
    // get the command string
    if (!mxIsChar(prhs[0])) {
        mexErrMsgTxt("Input must be a string.");
    }

    std::string inputString(mxArrayToString(prhs[0]));
    plhs[0] = ProcessCommand(inputString, nrhs, prhs);

}


/*

// Function to process the second column of the input cell array
mxArray *processSecondColumn(const mxArray* inputCellArray) {


    std::vector<std::vector<int16_t>> buffers;
    mwSize numRows = mxGetM(inputCellArray);

    size_t total_size = 0;
    for (mwSize i = 0; i < numRows; i++) {
        // Extract the cell in the second column of row i (index 1)
        mxArray* secondColumnArray = mxGetCell(inputCellArray, i + numRows);  // Second column index = 1
        printf("woogla");
        // Check if the cell is empty

        // If the cell is empty or the data inside is empty, skip the row
        if (secondColumnArray == nullptr || mxGetNumberOfElements(secondColumnArray) == 0) {
            mexPrintf("Row %zu: The second column is an empty array ([]), skipping.\n", i + 1);
            continue;  // Skip processing this row
        }

        mwSize numElements = mxGetNumberOfElements(secondColumnArray);
        mexPrintf("Length of the 1 * y uint32 array in row %zu: %zu\n", i + 1, numElements);
        if (numElements == 0) {
            mexPrintf("Row %zu: The second column is an empty array ([]).\n", i + 1);
            buffers.push_back(std::vector<int16_t>(i, 0));
            total_size += 2;
            continue;  // Skip processing this row
            continue;  // Skip processing this row
        }


        printf("boog;a");

        // Get the number of elements in the extracted array (1 * y)
        // we need to add this to our buffer, but lets do that later

        total_size += numElements; //speciically don't add the channel num so we can an initializer
        //int16_t* data = (int16_t*)malloc(sizeof(int16_t) * (numElements + 1));
        int16_t *content = static_cast<int16_t*>(mxGetData(secondColumnArray));

        printf("boogdda");

        buffers.push_back(std::vector<int16_t> (content, content + numElements));
        printf("ssssss;a");

        // Print the length of the extracted array
    }

    printf("a");
    mxArray* buffer = mxCreateNumericMatrix(1, total_size, mxINT16_CLASS, mxREAL);

    //convert into a single buffer
    int c = 0;
    for (int i = 0; i < buffers.size(); i++) {
        size_t size = buffers[i].size();
        memcpy((int16_t*)mxGetData(buffer) + c, buffers[i].data(), size * sizeof(int16_t));
        c += size;
    }

    printf("b");

    return buffer;
}

void processArray(double* input, mwSize numElements) {
    for (mwSize i = 0; i < numElements; i++) {
        input[i] += 1.0;  // Add 1 to each element
    }
}

uint16_t *EncodeEvents(const mxArray *cellArray) {
    // set up the appropriate size and buffers
    mwSize channels = mxGetM(cellArray);


    size_t* sizes = new size_t[channels];
    int16_t** buffers = new int16_t * [channels];
    int numRows = 7; 
    
    for (mwSize i = 0; i < channels; i++) {

        mxArray* cellContent = mxGetCell(cellArray, i + 7);
        // Ensure that the second column contains a cell array (1 * y int32)
        if (!mxIsCell(cellContent)) {
            mexErrMsgIdAndTxt("MATLAB:extractSecondColumn:invalidSecondColumn", "Second column must contain a cell array.");
        }

        // Get the cell in the second column
        mxArray* secondColumnArray = mxGetCell(cellContent, 0);

        // Ensure that the extracted second column array is a 1 * y array of type int32
        if (!mxIsInt32(secondColumnArray)) {
            mexErrMsgIdAndTxt("MATLAB:extractSecondColumn:invalidDataType", "The extracted data must be of type int32.");
        }

        int32_t* outputData = static_cast<int32_t*>(mxGetData(secondColumnArray));
        for (int z = 0; z < 10; z++) {
            printf("survived");
        }
    }
    return NULL;

    
}


void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]) {
    // Check for the correct number of input arguments (1 cell array)
    if (nrhs != 1) {
        mexErrMsgIdAndTxt("MATLAB:extractSecondColumn:invalidNumInputs", "One input required.");
    }

    // Get the input cell array (x * 7)
    const mxArray* inputCellArray = prhs[0];

    // Ensure that the input is a cell array
    if (!mxIsCell(inputCellArray)) {
        mexErrMsgIdAndTxt("MATLAB:extractSecondColumn:inputNotCellArray", "Input must be a cell array.");
    }

    // Get the number of rows (x) in the cell array
    mwSize numRows = mxGetM(inputCellArray);
    mwSize numCols = mxGetN(inputCellArray);

    // Ensure there are 7 columns
    if (numCols != 7) {
        mexErrMsgIdAndTxt("MATLAB:extractSecondColumn:invalidNumColumns", "Input cell array must have 7 columns.");
    }
    printf("hello mexlab");
    EncodeEvents(inputCellArray);

    // Prepare the output as a cell array to store the extracted data
    plhs[0] = mxCreateCellMatrix(numRows, 1);
    

}

/*
void mexFunction(int nlhs, mxArray* plhs[], int nrhs, mxArray* prhs[]) {
    // Check for the correct number of inputs
    if (nrhs != 1) {
        mexErrMsgIdAndTxt("MATLAB:processArray:invalidNumInputs", "One input required.");
    }

    // Ensure the input is a double array
    if (!mxIsDouble(prhs[0])) {
        mexErrMsgIdAndTxt("MATLAB:processArray:invalidInput", "Input must be a numeric array.");
    }

    // Get the pointer to the input array
    double* inputArray = mxGetPr(prhs[0]);

    // Get the number of elements in the input array
    mwSize numElements = mxGetNumberOfElements(prhs[0]);

    // Process the array
    processArray(inputArray, numElements);

    // Return the modified array
    plhs[0] = prhs[0];
}*/

