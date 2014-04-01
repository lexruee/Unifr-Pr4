%%%---------------------------------------------------------------------
%%% University of Fribourg 
%%% Project 4: Concurrent, Parallel and Distributed Computing
%%%
%%% @author		Alexander Rüedlinger, Michael Jungo
%%% @date		2014
%%% @version		see git history
%%% @description 	Solution for exercise series 5.
%%%---------------------------------------------------------------------

-module(token_ring).
-export([start/3, master/3, actor/4]).


%% Creates a token ring with N processes. 
%% The I-th process sends a token
%% and M messagers are sent in total.
%% @spec start(N::int(),M::int()) -> int()
%%
start(N,M,I) -> 
	out("",[],write), % overwrite output file	
	spawn(token_ring,master,[N,M,I]). % spawn master process.
	

%% Deploys N slave processes.
%% @spec start(N::int(),M::int()) -> pid()
%%
deploy(0,_,Pid) -> 
	% inform the master (myself) that all processes are deployed.
	self() ! {deployed,Pid}, % pid correspond to the "last" process in the ring.
	Pid;

deploy(N,M,SuccPid) ->
	Pid = spawn(token_ring,actor,[N,M,SuccPid,0]),
	out("deployed process ~p: pid: ~p\n",[N,Pid],append),		
	deploy(N-1,M,Pid).

%% Inital master function to initalize the token ring.
%% @spec master(N::int(),M::int(),I::int()) -> any()
%%
master(N,M,I) ->
	out("deployed process ~p: pid: ~p\n",[N,self()],append),
	deploy(N-1,M,self()),
	waitOnDeployment(N,M,I). % enter wait on deployment state.

%% Wait "loop". Waits until the token ring created.
%% @spec waitOnDeployment(M::int()) -> any()
%%
waitOnDeployment(N,M,I) ->
	receive
		{deployed,SuccPid} -> out("all processes are deployed!\n",[],append),
		SuccPid ! {find,I}, %find i-th node 
		actor(N,M,SuccPid,0) % if found enter actor state.
	end,
	waitOnDeployment(N,M,I).

%% Main actor function for slace and master process.
%% @spec actor(M::int(),SuccPid::pid(),Counter::int()) -> any()
%%
actor(I,M,SuccPid,Counter) ->
	receive	
		% starts sending a token.		
		% find i-th node and start counting and send token
		{find,Id} when I == Id ->
			out("N ~p, pid: ~p, succ pid: ~p, send token!\n",[I,self(),SuccPid],append),
			SuccPid ! {counter,0,self(),token};
 
		{find,Id} when I /= Id ->
			SuccPid ! {find,Id}; 

		% increments a counter.
		% if a counter message is received then increment the counter and
		% send it to its successor.		
		{counter,CounterValue,MasterPid,token} when CounterValue < M -> 
			out("N: ~p, pid: ~p, succ: ~p, received c: ~p: , set c to ~p\n",[I,self(),SuccPid,CounterValue,CounterValue+1],append),
			SuccPid ! {counter,CounterValue+1,MasterPid,token},
			actor(I,M,SuccPid,CounterValue); % propagate the message in the ring

		{counter,CounterValue,MasterPid,token} when CounterValue==M ->
			MasterPid ! {stopped};

		% initalizes the collection phase.
		% if the master receives a stopped message 
		% then start collecting the current states of each ring process.
		{stopped} -> 
			out("received stopped message!\n",[],append),
		SuccPid ! {state,self()};

		% collects state information.
		% if a process receives a state message then send back 
		% the master its current state
		{state,MasterPid} when MasterPid /= self() ->
			MasterPid ! {collect,self(),SuccPid,Counter},
			SuccPid ! {state,MasterPid}, % propagate the message in the ring
			shutdown();

		{state,MasterPid} when MasterPid == self() ->
			MasterPid ! {collect,self(),SuccPid,Counter},
			shutdown();

		% summarizes the collected data.
		% if the master receives a collect message
		% then write the results into a file
		{collect,Pid,SPid,CValue} ->
			out("report state of ~p: succ pid: ~p, counter: ~p\n",[Pid,SPid,CValue],append)

	end, 
	actor(I,M,SuccPid,Counter).

%% Stop function.
%% Represents a final state.
shutdown() -> stop.


%% Writes a formatted string into a file.
%% @spec actor(Str::string(),L::list(),Mode::atom()) -> any()
%%
out(Str,L,Mode) ->
	{ok, IO} = file:open("./tr.hrl",[Mode]),
	io:fwrite(IO,Str,L).


