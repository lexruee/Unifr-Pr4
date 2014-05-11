#Series 8-10

##Exercise 1
See file cm1.erl

##Exercise 2
See file cm2.erl

##Remarks
###Simple way - use run.sh:
```
./run.sh cm2 graph.txt 5
```
This runs the cm2 erlang program with file graph.txt and with 5 nodes  


###Alternative way
```
bash ../../scripts/run_local.sh -f 'cm1:start("./graphs/graph.txt") '-n 2
```
This runs the cm1 erlang program with file graph.txt and with 2 nodes.  



##IMPORTANT FACTS:
	- run the emake shell script
	- be sure that all mac os x files are removed before running the erlang program.
