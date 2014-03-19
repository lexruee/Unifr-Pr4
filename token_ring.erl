-module(token_ring).
-export([start/1, loop/1, startRec/2]).


start(N) ->
	Pid = spawn(token_ring, loop, [-1]),
	LastPid = startRec(N-1,Pid),
	io:format("next pid ~p , N=~p\n",[LastPid,N]),
	Pid ! LastPid.

startRec(0,Pid) -> Pid;
startRec(N,Pid) -> 
		NewPid = spawn(token_ring, loop, [Pid]),
		startRec(N-1,NewPid).



loop(-1) -> 
	receive
		Msg ->
		    io:format("Msg2 to ~p, from ~p\n", [self(),Msg])
	end;

loop(PredPid) -> 
	PredPid ! self(), %send pid to pred process
	receive
		Msg ->
		    io:format("Msg to ~p, from ~p\n", [self(),Msg])
	end.



