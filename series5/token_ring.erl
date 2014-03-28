-module(token_ring).
-export([start/2, init/2, collector/2, loop/3, startRec/4]).

%
% Work in progress.
% Done:
%	- create n processes
%	- counter
%
%	Todo:
%	collector process
%		- collect stats
%	token

% start init/collector process
start(N,M) -> spawn(token_ring, init,[N,M]).

init(N,M) -> 
	% create N processes
	LastPid = startRec(N,M,self(),self()),
	collector(M,LastPid). % run collector loop

collector(M,SuccPid) -> 
	receive
		{counter,CounterValue} when CounterValue==M ->
			io:format("stopped\n"),
			self() ! {stopped};
		{counter,CounterValue} when CounterValue < M->
			io:format("Collector Process: ~p, counter: ~p \n", [self(),CounterValue+1]),
			SuccPid ! {counter,CounterValue+1};
			% pass counter value to the start of the ring.
		{stopped} ->
			io:format("stopped\n"),
			SuccPid ! {getState};
		{collect_state,Counter,Pid} ->
			io:format("pid: ~p, counter: ~p\n",[Pid,Counter])
	end,
	collector(M,SuccPid).


% create N processes
startRec(0,_,Pid,_) -> Pid ! {counter,0}, Pid; %if all processes are 
% created then start counting.

startRec(N,M,SuccPid,FirstPid) -> 
	Pid = spawn(token_ring, loop, [M,SuccPid,FirstPid]),
	io:format("N: ~p, Create Process: ~p\n", [N,Pid]),
	startRec(N-1,M,Pid,FirstPid).


loop(M,SuccPid,FirstPid) -> 
	receive
		{counter,CounterValue} when CounterValue==M ->
			FirstPid ! {stopped,self()};
			
		{counter,CounterValue} when CounterValue < M ->
			io:format("Process: ~p, counter: ~p \n", [self(),CounterValue+1]),
			SuccPid ! {counter,CounterValue+1};
			
		{get_state} ->
			FirstPid ! {collect_state,0,self()},
			io:format("sdd\n"),
			SuccPid ! {get_state}
	end,
	loop(M,SuccPid,FirstPid).




