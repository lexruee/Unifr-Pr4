-module(cm1).
-export([start/1,nodeActor/0]). 


%
% Simplified CM version for non-negative graphs without termination.
% Solution for series 8-10.
%
% author:   Alexander Rüedlinger, Michael Jungo
% date:     2014
% lecture:  Project 4: Concurrent, Parallel and Distributed Computing
% remark:   Huge hack alert. This solution is not intended to be a
%           a nice and beautiful implementation. The goal was just to
%           get the job done.


%
% start():
% Starts the simplified CM algorithm on the master node.
% The start function takes as an argument the name of a "graph" file.
% E.g.: file = graph.txt, start("graph.txt") 
%
% @spec start(File::list()) -> any()
start(File) ->
    Filename = list_to_atom(File), % never ever use something else!
    io:format("read file ~p\n",[Filename]),
    {ok,Graph} = file:consult(Filename), % read file: list of adjacency lists
    {ok,[_|Ns]} = file:consult('enodes.txt'), % read all host names from file enodes.
    
    % go into state deployment and deploy the graph on the cluster
    deployment(Ns,Graph).
    
    
%
% deployment():
% The deployment function uses two arguments Ns and Graph.
% The list Ns contains all host names and Graph describes the topology 
% in terms of a list of adjacency lists. 
%
% For clarification:
% - Ns contains a list of hostnames.
% - N is a hostname
% - Vs contains a list of vertex labels v0,v1, etc.
% - V is a vertex label.
% - Pids is a list of process ids.
% - Pid is a process id.
% - Each node process corresponds to a vertex. (Vs <--> Pids)
%
% @spec deployment(Ns::list(),Graph::list()) -> any()
deployment(Ns,Graph) ->
    Map = aggregate(Ns,Graph), % map vertices on hosts / nodes
    Vs = [ V || {_,[V|_]} <- Map ], % extract all vertex labels 
    io:format("map ~p\n",[Map]),
    
    Pids = [ spawn(N,?MODULE,nodeActor,[]) || {N,_} <- Map ], % deploy node processes
    
    % create look up table for node label v_i -> pid translation
    LookupTable = createLookupTable(Pids,Map),
    
    % translate original graph with vertex labels (N) into a graph with pids.
    GraphWithPids = translateGraph(Graph,LookupTable),
    
    % let each node process know his successor node processes
    [ Pid ! {successors,Successors} || [Pid,Successors] <- GraphWithPids ],
    
    % give each node process a node label v0,v1,v2 etc.
    [ Pid ! {label,V} || {Pid,V} <- lists:zip(Pids,Vs) ],
    
    % distribute inverse lookup table for pids -> v_i translation (for debugging purposes)
    InverseLookupTable = createInverseLookupTable(Pids,Map),
    
    %io:format("distribute table: ~p\n",[dict:to_list(InverseLookupTable)]),
    [ Pid ! {lookupTable,dict:to_list(InverseLookupTable)} || Pid <- Pids ],
   
    % set master node processes for all nodes.
    [ Pid ! {master,self()} || Pid <- Pids ],
            
    % after 3 seconds start phase 1 and set RootNode as initiator
    [InitiatorPid|_] = Pids, % choose the first node process as initiator node process.
    erlang:send_after(3000,self(),{init,InitiatorPid}),
    io:format("waiting three seconds for deployment...\n"),
    
    collect(Pids,[],Vs). % go into state collect
    
%
% collect():
% Collect function for master node process.
% Receives an init message and setups the initiator node process
% for starting the CM algorithm.
%
% After the computation is finished it collects the results from all node processes.
%
% @spec collect(Pids::list(),Result:list(),Vs::list()) -> any()    
collect(Pids,Edges,Vs) ->
    case length(Pids)==0 of
        true -> FilteredEdges = [ [Pred,W,U] || [Pred,W,U] <- Edges,Pred/=nil],
                io:format("\nfinshihed, predecessor graph:\n\tnodes: ~p\n\tedge [v,w,u] := v <--w-- u\n\tedges:~p\n\n",[Vs,FilteredEdges]),
                collect([nil],Edges,Vs);
        false -> do_nothing
    end,
        
    receive
        
        %
        % Handle finish message.
        % Received if the initator node detects that the computation 
        % is over.
        %
        {finished} ->
            % collect current state for all nodes processes.
            [ Pid ! {collect} || Pid <- Pids ],
            collect(Pids,Edges,Vs);
    
        %
        % Initiates phase 1 of the CM algorithm
        % and sets one of the node processes as the iniator node process.
        {init,InitiatorPid} ->
            InitiatorPid ! {initiator},
            collect(Pids,Edges,Vs);
        
        % Handle collect messages.
        % Receive collect messages and collect the results.
        %
        {collect,State,NodePid} ->
            % Remove corresponding Pid for each received collect message.
            NPids = lists:filter(fun(Pid) -> Pid/=NodePid end,Pids),
            collect(NPids,lists:sort(Edges ++ [State]),Vs)
    end.
     
%
% nodeActor():
% The function nodeActor() acts as an init function for initialization 
% of the node actor process.
%
% @spec nodeActor() -> any()
nodeActor() -> 
    MasterPid = nil, V = nil, Lookup = nil, Successors = [], 
    Pred = nil, D = infinity, Num = 0,
    nodeActor(MasterPid,V,Lookup,Successors,Pred,D,Num).

%
% nodeActor():
% This function is basically the main algorithm of a node process.
% It handles all length messages, ack and stop messages.
% It implements phase 1 (computing shortest path) 
% and phase 2 (collect results) without terminating. 
%
% For clarification:
% - StateVariables:
%       - MasterPid::pid()      Master node process pid.
%       - Label::atom()          Corresponding Vertex label of the node process.
%       - Lookup::fun()          A lookup function for translating pids to vertex labels.
%       - Successors::list()     A list of successor node process ids.
%       - Pred::pid()            Id of the predecessor node process.
%       - D::int()               The current weight of the node process / vertex.
%       - Num::int()             The number of expected acks.
%
% - State can be either run or terminate.
%
% @spec nodeActor(MasterPid::pid(),V::atom(),Lookup::fun(),
%       Successors::list(),Pred::pid(),D::int(),Num::int()) -> any()
nodeActor(MasterPid,V,Lookup,Successors,Pred,D,Num) ->
    % print statements for debugging
    case Pred  of
        nil -> io:format("~p, ~p, num: ~p, d: ~p, pred: nil\n",[self(),V,Num,D]);
        _ -> io:format("~p, ~p, num: ~p, d: ~p, pred: ~p\n",[self(),V,Num,D,Lookup(Pred)])
    end,
      
    receive
        %---------------------------------------------------------------
        % Initialization messages for intermediate nodes.
        %---------------------------------------------------------------
        
        %
        % Setup master node
        {master,NewMasterPid} ->
            nodeActor(NewMasterPid,V,Lookup,Successors,Pred,D,Num);
        
        
        % Setup successors nodes for this node.
        %
        {successors,NewSuccessors} ->
            io:format("~p, ~p, ~p: received successors: ~p\n",
            [V,node(),self(),NewSuccessors]),
            
            nodeActor(MasterPid,V,Lookup,NewSuccessors,Pred,D,Num);
        
        % Setup lookup table.
        %
        {lookupTable,Table} ->
            NewLookupTable = dict:from_list(Table),
            LookupFun = fun(Key) -> 
                case Key==nil of
                    true -> nil;
                    false ->  dict:fetch(Key,NewLookupTable)
                end
            end,
            %io:format("lookup table: ~p\n",[Table]),
            NewV = LookupFun(self()), %dict:fetch(self(),NewLookupTable),
            
            io:format("~p, ~p, ~p: received table and label: ~p\n",
            [V,node(),self(),NewV]),
            
            nodeActor(MasterPid,NewV,LookupFun,Successors,Pred,D,Num);
        
        %---------------------------------------------------------------
        % Phase 1 for process p_j, j > 1, intermediate nodes
        %---------------------------------------------------------------
        
        % Handle length message if S < D.
        % If true the current node has found a shorter path to the
        % initiator node via node P. Inform all other nodes except Pred
        % that an improved path has been found.
        %
        {lengthMessage,P,S,Initiator} when S < D,Initiator/=self(); D == infinity,Initiator/=self() -> % number < atom 
            % print statements for debugging
            io:format("~p, received lengh message S < D from ~p, ~p \n",[V,P,Lookup(P)]),
            
            % send an ack to the old predecessor, before changing it.
            case Num > 0 of
                true -> Pred ! {ack,self(),Initiator};
                false -> nil
            end,
            
            % update D=S and Pred=P
            % set shorter path via P.
            NewPred = P,
            NewD = S,
            
            % print statements for debugging
            [ io:format("send length message from ~p to ~p, ~p, s: ~p, w: ~p, s+w: ~p\n",
            [V,SuccPid,Lookup(SuccPid),S,W,S+W]) || [SuccPid,W] <- Successors ],
            
            % send length messages to all successors of this node.
            % inform these nodes that a shorter path has been found.
            [ SuccPid ! {lengthMessage,self(),NewD+W,Initiator} || [SuccPid,W] <- Successors ],

            % increment Num
            NewNum = Num + length(Successors),
           
            case NewNum==0 of
                true -> NewPred ! {ack,self(),Initiator};
                false -> nil
            end,
            nodeActor(MasterPid,V,Lookup,Successors,NewPred,NewD,NewNum);
        
        
        % Handle length message if S >= D.
        % Received message does not lead to a shorter path, so
        % discard it and just send an ack.
        %
        {lengthMessage,P,S,Initiator} when S>= D, self()/=Initiator ->
            P ! {ack,self(),Initiator},
            nodeActor(MasterPid,V,Lookup,Successors,Pred,D,Num);
        
        % Handle ack message.
        %
        {ack,P,Initiator} when Initiator/=self() ->
            % print statements for debugging
            io:format("~p, received ack from ~p, ~p\n",[V,P,Lookup(P)]),
            
            % decrement Num
            NewNum = Num - 1,
            case NewNum == 0 of
                true -> Pred ! {ack,self(),Initiator};
                false -> do_nothing
            end,
            nodeActor(MasterPid,V,Lookup,Successors,Pred,D,NewNum);
        
        
        %---------------------------------------------------------------
        % Initialization message for initiator node.
        %---------------------------------------------------------------
       
        % Starts the computing procedure.
        % This nodes is set as initiator and computes all
        % shortest paths to all other nodes.
        %
        {initiator} ->
            % print statements for debugging
            io:format("~p initiates computing, phase 1...\n",[V]),
            
            % print statements for debugging
            [ io:format("send length message from ~p to ~p, ~p, s: ~p, w: ~p, s+w: ~p\n",
            [V,SuccPid,Lookup(SuccPid),0,W,0+W]) || [SuccPid,W] <- Successors ],
            
            % send length message to all successor nodes
            % and set this node as initiator
            Initiator = self(),
            [ SuccPid ! {lengthMessage,self(),W,Initiator} || [SuccPid,W] <- Successors],
            nodeActor(MasterPid,V,Lookup,Successors,nil,0,length(Successors));
       
               
        %---------------------------------------------------------------
        % Phase 1 for process p_j, j = 1, initiator node
        %---------------------------------------------------------------
        
        % Handle length message.
        % Send for each received length messages an ack message if S>=0.
        %
        {lengthMessage,P,S,Initiator} when S>=0, self()==Initiator ->
            P ! {ack,self(),Initiator}, % return ack to P
        nodeActor(MasterPid,V,Lookup,Successors,Pred,D,Num);
        
        % Handle ack message.
        % Decrement Num counter for each received ack message.
        % If Num==0 start phase 2.
        %
        {ack,P,Initiator} when Initiator==self() ->
            io:format("~p, received ack from ~p, ~p\n",
            [V,P,Lookup(P)]),
            
            NewNum = Num - 1,
            case NewNum==0 of
                true -> MasterPid ! {finished};
                false -> do_nothing
            end,
            nodeActor(MasterPid,V,Lookup,Successors,Pred,D,NewNum);
           
        % Handle collect messages sent by the master node.
        % Send back the current state of this node.
        %
        {collect} ->
            io:format("received collect request\n",[]),
            MasterPid ! {collect,[Lookup(Pred),D,V],self()}, % send back the current edge to pred.
            nodeActor(MasterPid,V,Lookup,Successors,Pred,D,Num)
                  
    end.

%
% createLookupTable():
% Creates a lookup table for translating a vertex label (V) 
% to a node process id (Pid). It returns a dictionary.
%
% @spec createLookupTable(Pids:list(),Mappped::dict()) -> dict()
createLookupTable(Pids,Mapped) ->
    % associate pids with vertex labels.
    Tmp = [ {Pid,Vs} || {Pid,{_,Vs}} <- lists:zip(Pids,Mapped)],
    % make a lookup table for pids and vertices.    
    KeyVal = [{V,Pid} || {Pid,[V|_]} <- Tmp],
    dict:from_list(KeyVal). % return a dictionary

%
% createInverseLookupTable():
% Creates a lookup table for translating a process id  (Pid) 
% to a vertex label (V). It returns a dictionary.
%
% @spec createInverseLookupTable(Pids:list(),Mappped::dict()) -> dict()
createInverseLookupTable(Pids,Mapped) ->
    % associate pids with graph vertices
    Tmp = [{Pid,Vs} || {Pid,{_,Vs}} <- lists:zip(Pids,Mapped)],
    % make a lookup table for pids and vertices.    
    ValKey = [ {Pid,V} || {Pid,[V|_]} <- Tmp],
    dict:from_list(ValKey). % return a dictionary

%
% translateGraph():
% Translates all vertex labels in a graph (represented as an adjacency list)
% by using the provided "translation" dictionary / lookup table. 
% It returns the translated graph.
%
% @spec createLookupTable(Graph:list(),Dict::dict()) -> list()
translateGraph(Graph,Dict) ->
    % translate old Graph with lookup table
    GraphN = lists:map(
        fun([V,Vs]) ->
            [ dict:fetch(V,Dict), [ [dict:fetch(K,Dict),W] || [K,W] <- Vs] ] 
        end, Graph),
    io:format("GN: ~p\n",[GraphN]),
    GraphN.


% aggregate():
% @spec aggregate(Ns::list(),Vs::list()) -> Fs::list()
%
%   This function assigns vertices to nodes. If there are more vertices than
%   nodes, this function will take the modulo of the list of nodes and continue
%   assigning vertices. The aggregated list returned by this function is of the
%   following structure:
%      [{N0,V0}, {N1,V1}, ..., {Nk-1,Vk-1}, {N0,Vk}, ...], with k=length(Ns)
%
% aggregate {N(i rem k), Vi}, for i in 0..length(Vs)-1
aggregate(Ns,Vs) ->
  aggregate_modulo(Ns,Vs,[],Ns).

% aggregate_modulo():
% @spec agregate_modulo(Ns::list(),Vs::list(),Fs::list(),Ns_init::list()) -> 
%         Fs::list()
%
%   Helper function for the aggregate() function.
aggregate_modulo(_Ns,[],Fs,_Ns_init) ->
  lists:reverse(Fs);                          % return value Fs
aggregate_modulo([],Vs,Fs,Ns_init) ->
  aggregate_modulo(Ns_init,Vs,Fs,Ns_init);    % continue building Fs
aggregate_modulo([N|Ns],[V|Vs],Fs,Ns_init) ->
  aggregate_modulo(Ns,Vs,[{N,V}|Fs],Ns_init). % build Fs
