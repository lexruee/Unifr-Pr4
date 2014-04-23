-module(cm_1).
-export([start/1,nodeActor/0,aggregate/2,aggregate_modulo/4]). 
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
% Starts the simplified CM algorithm.
% The start function takes as an argument the name of a "graph" file
% without the .txt extension. E.g.: file = graph.txt, start("graph") 
%
% @spec masterActor(Nodes::list(),Graph::list()) -> any()
start(File) ->
    % read graph topology from file
    Filename = list_to_atom(File++".txt"),
    io:format("llll ~p\n",[Filename]),
    {ok,Graph} = file:consult(Filename),
    % read nodes list
    {ok,[_|Nodes]} = file:consult('enodes.txt'),
    % checks if node is master or not
    masterActor(Nodes,Graph).

%
% masterActor():
% Master actor.
%
% @spec masterActor(Nodes::list(),Graph::list()) -> any()
masterActor(Nodes,Graph) ->
    % map vertices on nodes
    Map = aggregate(Nodes,Graph),
    NodeLabels = [ Label || {_,[Label|_]} <- Map ],
    io:format("map ~p\n",[Map]),
    
    % deploy node processes
    Pids = [ spawn(NodeId,?MODULE,nodeActor,[]) || {NodeId,_} <- Map ],
    % create look up table for node label v_i -> pid translation
    LookupTable = createLookupTable(Pids,Map),
    
    % translate original graph into a graph with pids
    GraphN = translateGraph(Graph,LookupTable),
    
    % let each node know his successors
    [ NodeId ! {successors,Successors} || [NodeId,Successors] <- GraphN ],
    
    % give each node process a node label v0,v1,v2 etc.
    [ NodeId ! {label,Label} || {NodeId,Label} <- lists:zip(Pids,NodeLabels) ],
    
    % distribute inverse lookup table for pids -> v_i translation
    InverseLookupTable = createInverseLookupTable(Pids,Map),
    io:format("distribute table: ~p\n",[dict:to_list(InverseLookupTable)]),
    [ NodeId ! {lookupTable,dict:to_list(InverseLookupTable)} || NodeId <- Pids ],
   
    % set master node for all nodes.
    [ NodeId ! {masterNode,self()} || NodeId <- Pids ],
            
    % after 4 seconds start phase 1 and set RootNode as initiator
    [RootNode|_] = Pids,
    erlang:send_after(4000,self(),{init,RootNode}),
    collect(Pids,[],NodeLabels).
    
%
% collect():
% Collect fucntion for master actor.
% Receives an init message and setups the initiator node 
% for starting the CM algorithm.
%
% After the computation is finished it collects the results of all nodes.
%
% @spec collect(Pids::list(),Result:list(),NodeLabels::list()) -> any()    
collect(Pids,Result,NodeLabels) ->
    case length(Pids)==0 of
        true -> Edges = [ [V,W,U] || [V,W,U] <- Result,U/=nil],
                io:format("\nfinshihed, results:\nnodes: ~p\nedges: ~p\n\n",[NodeLabels,Edges]),
                collect([nil],Result,NodeLabels);
        false -> do_nothing
    end,
        
    receive
        
        %
        % Handle finish message.
        % Received if the initator node detects that the computation 
        % is over.
        %
        {finished} ->
            % collect current state for all nodes.
            [ NodeId ! {collect} || NodeId <- Pids ],
            collect(Pids,Result,NodeLabels);
    
        %
        % Initiates phase 1 of the CM algorithm
        % and sets Root as iniator node.
        {init,Root} ->
            Root ! {initiator,self()},
            collect(Pids,Result,NodeLabels);
        
        % Handle collect messages.
        % Receive collect messages and collect the results.
        %
        {collect,State,NodePid} ->
            % Remove corresponding Pid for each received collect message.
            NPids = lists:filter(fun(Pid) -> Pid/=NodePid end,Pids),
            collect(NPids,lists:sort(Result ++ [State]),NodeLabels)
    end.
    
%
% nodeActor():
% Node actor.
%
% @spec nodeActor() -> any()
nodeActor() -> 
    nodeActor(run,{nil,nil,dict:new(),[],nil,infinity,0}).

%
% @spec masterActor(State::atom(),Variables::tuple()) -> any()
nodeActor(State,{MasterNode,Label,Lookup,Successors,Pred,D,Num}) ->
    % print statements for debugging
    case Pred  of
        nil -> io:format("~p, ~p, num: ~p, d: ~p, pred: nil\n",[self(),Label,Num,D]);
        _ -> io:format("~p, ~p, num: ~p, d: ~p, pred: ~p\n",[self(),Label,Num,D,Lookup(Pred)])
    end,
      
    receive
        %---------------------------------------------------------------
        % Initialization messages for intermediate nodes.
        %---------------------------------------------------------------
        
        %
        % Setup master node
        {masterNode,NewMasterNode} ->
            nodeActor(State,{NewMasterNode,Label,Lookup,Successors,Pred,D,Num});
        
        
        % Setup successors nodes for this node.
        %
        {successors,NewSuccessors} ->
            io:format("~p, ~p, ~p: received successors: ~p\n",
            [Label,node(),self(),NewSuccessors]),
            
            nodeActor(State,{MasterNode,Label,Lookup,NewSuccessors,Pred,D,Num});
        
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
            io:format("lookup table: ~p\n",[Table]),
            NewLabel = LookupFun(self()), %dict:fetch(self(),NewLookupTable),
            
            io:format("~p, ~p, ~p: received table and label: ~p\n",
            [Label,node(),self(),NewLabel]),
            
            nodeActor(State,{MasterNode,NewLabel,LookupFun,Successors,Pred,D,Num});
        
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
            io:format("~p, received lengh message S < D from ~p, ~p \n",[Label,P,Lookup(P)]),
            
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
            [Label,V,Lookup(V),S,W,S+W]) || [V,W] <- Successors ],
            
            % send length messages to all successors of this node.
            % inform these nodes that a shorter path has been found.
            [ V ! {lengthMessage,self(),NewD+W,Initiator} || [V,W] <- Successors ],

            % increment Num
            NewNum = Num + length(Successors),
           
            case NewNum==0 of
                true -> NewPred ! {ack,self(),Initiator};
                false -> nil
            end,
            nodeActor(State,{MasterNode,Label,Lookup,Successors,NewPred,NewD,NewNum});
        
        
        % Handle length message if S >= D.
        % Received message does not lead to a shorter path, so
        % discard it and just send an ack.
        %
        {lengthMessage,P,S,Initiator} when S>= D, self()/=Initiator ->
            P ! {ack,self(),Initiator},
            nodeActor(State,{MasterNode,Label,Lookup,Successors,Pred,D,Num}); % <----- fix
        
        % Handle ack message.
        %
        {ack,P,Initiator} when Initiator/=self() ->
            % print statements for debugging
            io:format("~p, received ack from ~p, ~p\n",[Label,P,Lookup(P)]),
            
            % decrement Num
            NewNum = Num - 1,
            case NewNum == 0 of
                true -> Pred ! {ack,self(),Initiator};
                false -> do_nothing
            end,
            nodeActor(State,{MasterNode,Label,Lookup,Successors,Pred,D,NewNum});
        
        
        %---------------------------------------------------------------
        % Initialization message for initiator node.
        %---------------------------------------------------------------
       
        % Starts the computing procedure.
        % This nodes is set as initiator and computes all
        % shortest paths to all other nodes.
        %
        {initiator,MasterNode} ->
            % print statements for debugging
            io:format("~p initiates computing, phase 1...\n",[Label]),
            
            % print statements for debugging
            [ io:format("send length message from ~p to ~p, ~p, s: ~p, w: ~p, s+w: ~p\n",
            [Label,V,Lookup(V),0,W,0+W]) || [V,W] <- Successors ],
            
            % send length message to all successor nodes
            % and set this node as initiator
            Initiator = self(),
            [ NodeId ! {lengthMessage,self(),W,Initiator} || [NodeId,W] <- Successors],
            nodeActor(State,{MasterNode,Label,Lookup,Successors,nil,0,length(Successors)});
       
               
        %---------------------------------------------------------------
        % Phase 1 for process p_j, j = 1, initiator node
        %---------------------------------------------------------------
        
        % Handle length message.
        % Send for each received length messages an ack message if S>=0.
        %
        {lengthMessage,P,S,Initiator} when S>=0, self()==Initiator ->
            P ! {ack,self(),Initiator}, % return ack to P
        nodeActor(State,{MasterNode,Label,Lookup,Successors,Pred,D,Num});
        
        % Handle ack message.
        % Decrement Num counter for each received ack message.
        % If Num==0 start phase 2.
        %
        {ack,P,Initiator} when Initiator==self() ->
            io:format("~p, received ack from ~p, ~p\n",
            [Label,P,Lookup(P)]),
            
            NewNum = Num - 1,
            case NewNum==0 of
                true -> MasterNode ! {finished};
                false -> do_nothing
            end,
            nodeActor(run,{MasterNode,Label,Lookup,Successors,Pred,D,NewNum});
           
        % Handle collect messages sent by the master node.
        % Send back the current state of this node.
        %
        {collect} ->
            io:format("received collect request\n",[]),
            MasterNode ! {collect,[Label,D,Lookup(Pred)],self()},
            nodeActor(run,{MasterNode,Label,Lookup,Successors,Pred,D,Num})
                  
    end.

%
% createLookupTable():
% Creates a lookup table for translating a node label 
% into a node process pid
%
% @spec createLookupTable(Pids:list(),Map::dict()) -> dict()
createLookupTable(Pids,Map) ->
    % associate pids with graph vertices
    Tmp = [ {K,L} || {K,{_,L}} <- lists:zip(Pids,Map)],
    % make a lookup table for pids and vertices.    
    KeyVal = [{Key,Val} || {Val,[Key|_]} <- Tmp],
    dict:from_list(KeyVal).

%
% createInverseLookupTable():
% Creates a lookup table for translating  a process pid into
% a node label.
%
% @spec createInverseLookupTable(Pids:list(),Map::dict()) -> dict()
createInverseLookupTable(Pids,Map) ->
    % associate pids with graph vertices
    Tmp = [{K,L} || {K,{_,L}} <- lists:zip(Pids,Map)],
    % make a lookup table for pids and vertices.    
    ValKey = [ {Val,Key} || {Val,[Key|_]} <- Tmp],
    dict:from_list(ValKey).

%
% translateGraph():
% Translates all node labels in a graph (represented as an adjacency list)
% by using the provided "translation" dictionary / lookup table. 
%
% @spec createLookupTable(Graph:list(),Dict::dict()) -> list()
translateGraph(Graph,Dict) ->
    % translate old Graph with lookup table
    GraphN = lists:map(
        fun([Label,Vs]) -> [ dict:fetch(Label,Dict), 
                            lists:map(
                                fun([K,W]) -> 
                                    [dict:fetch(K,Dict),W] 
                                   end,
                             Vs) 
                           ] 
        end, 
                    Graph),
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
