# BatMEX
There are 2 used prototype stratgies implemented in this repo that do basically the same thing. The first is using memory mapped files to quickly transfer 
data out from matlab to an awaiting python script, which can then do with the data what it wants. This strategy works, but isn't as good as the second strategy.
Launching and running this can use the 1flagger.py script wiht the recorder script, and can also maybe use the Overlord script but I can't remember where testing
for that stands. 

The other much better method is programming a redis client and encoder in a MEX file with c++. this gives the ability to encode and send data to redis so fast, it
makes the memory file approach irrelevant. Also, c++ can use static singletons to make a persistent instance of a redis connection, and can also potentially 
launch multiple threads. IMPORTANT, FOR SOME REASON MUTEXS BREAK MATLAB WHICH IS WHY I USE ATOMIC FLAGS INSTEAD. Despite this, the strategty of using MEX files 
to add high-performance integration from the MATlab API to a larger and more versitle environment is much better than the memory mapped file stuff because 
matlab is so slow that encoding the matrix is awful, so you need a MEX for encoding no matter what, so might as well make it do the databasing stuff too. 

As of right now, this repo certaintly will not work out the box. This repo is a jumble of many different folders I crammed together in an effort to save my 
work before being redirected to other projects. Since the files are no longer organized in the same way, the will issues finding the proper paths. This is 
some thoughts about how to fix this if/when I get the chance to come back around to this project: 

Both the overlord, reader, and writer will have to access the mmap files, whose directory is now slightly different. Each NSP reading thread needs to have 
the sdk path variable corrected to whatever matches the version of the NSP you want to move. The MEX builder used to be a whole seperate folder and I just 
stuck it in the repo. I don't know how that will change the solution. What I do know is the VS project was based on the MEX builder template (which was 
super duper useful) which used the paths to whatever instance of matlab that I was using. Its likely if the paths get changed, the project will have to be 
rebuilt. If so, use the template from the MEX extension its very useful. 


