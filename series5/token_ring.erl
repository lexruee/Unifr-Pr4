-module(token_ring).
-export([start/2, loop/2, startRec/2]).


start(N, M) ->
	Pid = spawn(token_ring, loop, [-1, -1]),
	io:format("Fist created Pid: ~p\n", [Pid]),
	PredPid = startRec(N-1,Pid),
	Pid ! {M, PredPid}.

startRec(0,Pid) -> Pid;
startRec(N,Pid) -> 
		NewPid = spawn(token_ring, loop, [Pid, -1]),
		io:format("newly created Pid: ~p\n", [NewPid]),
		startRec(N-1,NewPid).



loop(-1, -1) -> 
	receive
		{Counter, PredPid} ->
		    io:format("Pid: ~p, Starting with counter ~p, sending to ~p\n", [self(),Counter, PredPid]),
			PredPid ! {Counter - 1, self()},
			loop(PredPid, Counter) % Call loop (to make it a loop), and give last received value.
	end;

loop(PredPid, LastReceivedValue) -> 
	receive			
		{stop, FirstPid} ->
			FirstPid ! {self(), PredPid, LastReceivedValue},
			PredPid ! {stop, FirstPid};
			
		{0, FirstPid} ->
			io:format("Pid: ~p is last, Counter 0\n", [self()]),
			FirstPid ! stop,
			loop(PredPid, LastReceivedValue);
			
		{Counter, FirstPid} ->
		    io:format("Pid: ~p, Counter ~p, sending to ~p\n", [self(),Counter,PredPid]),
		    PredPid ! {Counter - 1, FirstPid},
		    loop(PredPid, Counter); % Call loop (to make it a loop), and give last received value.
		    
		% Only the first process will get this message.
		{Pid, Pred, Value} ->
			file:write_file("tr.hrl", io_lib:format("Pid: ~p, PredPid: ~p, Value: ~p\n", [Pid, Pred, Value]), [append]), % append to file
			loop(PredPid, LastReceivedValue); % loop again, to receive results from other processes
		
		% Only the first process will get this message.	
		stop ->
			io:format("Pid: ~p, stop!\n", [self()]),
			file:write_file("tr.hrl", io_lib:format("Pid: ~p, PredPid: ~p, Value: ~p\n", [self(), PredPid, LastReceivedValue])), % create file
			PredPid ! {stop, self()},
			loop(PredPid, LastReceivedValue) % loop again, to receive results from other processes
	end.



