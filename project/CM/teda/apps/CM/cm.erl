-module(cm).
-export([start/0,masterActor/2,nodeActor/0,aggregate/2,aggregate_modulo/4,wait/0]). 

%
% start
%
start() ->
   % read graph topology from file
    {ok,Graph} = file:consult('graph.txt'),
    % read nodes list
    {ok,[MasterId|Nodes]} = file:consult('enodes.txt'),
    % checks if node is master or not
    case node() of
        MasterId -> masterActor(Nodes,Graph);
        _ -> nodeActor()
    end.

%
% Master actor.
%
masterActor(Nodes,Graph) ->
    io:format("master, neighbors ~p\n",[nil]),
    % map vertices on nodes
    Map = aggregate(Nodes,Graph),
    NodeLabels = lists:map(fun({_,[Label|_]}) -> Label end,Map),
    io:format("map ~p\n",[Map]),
    
    % deploy node processes
    Pids = [ spawn(NodeId,?MODULE, start,[]) || {NodeId,_} <- Map ],
    % create look up table for node label and process pid translation
    LookupTable = createLookupTable(Pids,Map),
    
    % translate original graph into a graph with pids
    GraphN = translateGraph(Graph,LookupTable),
    
    % let each node know his successors
    [ NodeId ! {successors,Successors} || [NodeId,Successors] <- GraphN ],
    
    % give each node process a node label
    [ NodeId ! {label,Label} || {NodeId,Label} <- lists:zip(Pids,NodeLabels) ],
    
    % distribute inverse lookup table
    InverseLookupTable = createInverseLookupTable(Pids,Map),
    io:format("distribute table: ~p\n",[dict:to_list(InverseLookupTable)]),
    [ NodeId ! {lookupTable,dict:to_list(InverseLookupTable)} || NodeId <- Pids ],
    
    % after 7 seconds start phase 1 and set RootNode as initiator
    [RootNode|_] = Pids,
    erlang:send_after(7000,self(),{init,RootNode}),
    wait().
    
%
% Wait loop for master actor.
% Receives an init message and setups the initiator node 
% for starting the cm algorithm.
%
wait() ->
    receive
        {init,Root} ->
            Root ! {initiator}
    end,
    wait().
    
%
% Node actor.
%
nodeActor(loop,{Label,LookupTable,Successors,Pred,D,Num}) ->
    % print statements for debugging
    case Pred  of
        nil -> io:format("~p, num: ~p, d: ~p, pred: nil\n",[Label,Num,D]);
        _ -> io:format("~p, num: ~p, d: ~p, pred: ~p\n",[Label,Num,D,dict:fetch(Pred,LookupTable)])
    end,
    
    receive
        %---------------------------------------------------------------
        % Initialization messages for intermediate nodes.
        %---------------------------------------------------------------
        
        % Setup successors nodes for this node.
        %
        {successors,NewSuccessors} ->
            io:format("~p, ~p, ~p: received successors: ~p\n",
            [Label,node(),self(),NewSuccessors]),
            
            nodeActor(loop,{Label,LookupTable,NewSuccessors,Pred,D,Num});
        
        % Setup lookup table.
        %
        {lookupTable,Table} ->
            NewLookupTable = dict:from_list(Table),
            io:format("lookup table: ~p\n",[Table]),
            NewLabel = dict:fetch(self(),NewLookupTable),
            
            io:format("~p, ~p, ~p: received table and label: ~p\n",
            [Label,node(),self(),NewLabel]),
            
            nodeActor(loop,{NewLabel,NewLookupTable,Successors,Pred,D,Num});
        
        %---------------------------------------------------------------
        % Phase 1 for process p_j, j > 1, intermediate nodes
        %---------------------------------------------------------------
        
        % Handle length message if S < D.
        % If true the current node has found a shorter path to the
        % initiator node via node P. Inform all other nodes except Pred
        % that an improved path has been found.
        %
        {lengthMessage,P,S,Initiator} when S < D; D == infinity ->
            % print statements for debugging
            io:format("~p, received lengh message S < D from ~p, ~p \n",
            [Label,P,dict:fetch(P,LookupTable)]),
            
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
            [Label,V,dict:fetch(V,LookupTable),S,W,S+W]) || [V,W] <- Successors ],
            
            % send length messages to all successors of this node.
            % inform these nodes that a shorter path has been found.
            [ V ! {lengthMessage,self(),NewD+W,Initiator} || [V,W] <- Successors ],

            % increment Num
            NewNum = Num + length(Successors),
           
            case NewNum==0 of
                true -> NewPred ! {ack,self(),Initiator};
                false -> nil
            end,
            
            nodeActor(loop,{Label,LookupTable,Successors,NewPred,NewD,NewNum});
        
        % Handle length message if S >= D.
        % Received message does not lead to a shorter path, so
        % discard it and just send an ack.
        %
        {lengthMessage,P,S,Initiator} when S>= D, self()/=Initiator ->
            P ! {ack,self(),Initiator};
        
        % Handle ack message.
        %
        {ack,P,Initiator} when Initiator/=self() ->
            % print statements for debugging
            io:format("~p, received ack from ~p, ~p\n",
            [Label,P,dict:fetch(P,LookupTable)]),
            
            % decrement Num
            NewNum = Num - 1,
            case NewNum == 0 of
                true -> Pred ! {ack,self(),Initiator};
                false -> do_nothing
            end,

            nodeActor(loop,{Label,LookupTable,Successors,Pred,D,NewNum});
        
        
        %---------------------------------------------------------------
        % Initialization message for initiator node.
        %---------------------------------------------------------------
       
        % Starts the computing procedure.
        % This nodes is set as initiator and computes all
        % shortest paths to all other nodes.
        %
        {initiator} ->
            % print statements for debugging
            io:format("~p initiates computing, phase 1...\n",[Label]),
            
            % print statements for debugging
            [ io:format("send length message from ~p to ~p, ~p, s: ~p, w: ~p, s+w: ~p\n",
            [Label,V,dict:fetch(V,LookupTable),0,W,0+W]) || [V,W] <- Successors ],
            
            % send length message to all successor nodes
            % and set this node as initiator
            Initiator = self(),
            [ NodeId ! {lengthMessage,self(),W,Initiator} || [NodeId,W] <- Successors],
            nodeActor(loop,{Label,LookupTable,Successors,nil,0,length(Successors)});
       
               
        %---------------------------------------------------------------
        % Phase 1 for process p_j, j = 1, initiator node
        %---------------------------------------------------------------
        
        % Handle length message.
        % Send for each received length messages an ack message.
        %
        {lengthMessage,P,_,Initiator} when self()==Initiator ->
            P ! {ack,self(),Initiator};    
        
        % Handle ack message.
        % Decrement Num counter for each received ack message.
        %
        {ack,P,Initiator} when Initiator==self() ->
            io:format("~p, received ack from ~p, ~p\n",
            [Label,P,dict:fetch(P,LookupTable)]),
            
            NewNum = Num - 1,
            case NewNum==0 of
                true -> io:format("start phase 2\n");
                false -> nothing
            end,
            
            nodeActor(loop,{Label,LookupTable,Successors,Pred,D,NewNum})
            
    end,
    nodeActor(loop,{Label,LookupTable,Successors,Pred,D,Num}).


nodeActor() -> 
    nodeActor(loop,{nil,dict:new(),[],nil,infinity,0}).


%
% Creates a lookup table for translating a node label 
% into a node process pid
%
createLookupTable(Pids,Map) ->
    % associate pids with graph vertices
    Tmp = lists:map(fun({K,{_,L}}) -> {K,L} end, lists:zip(Pids,Map)),
    % make a lookup table for pids and vertices.    
    KeyVal = lists:map(fun({Val,[Key|_]}) -> {Key,Val} end, Tmp),
    dict:from_list(KeyVal).

%
% Creates a lookup table for translating  a process pid into
% a node label.
%
createInverseLookupTable(Pids,Map) ->
    % associate pids with graph vertices
    Tmp = lists:map(fun({K,{_,L}}) -> {K,L} end, lists:zip(Pids,Map)),
    % make a lookup table for pids and vertices.    
    ValKey = lists:map(fun({Val,[Key|_]}) -> {Val,Key} end, Tmp),
    dict:from_list(ValKey).

%
% Translates all node labels in a graph (represented as an adjacency list)
% by using the provided "translation" dictionary / lookup table. 
%
translateGraph(Graph,Dict) ->
    % translate old Graph with lookup table
    GraphN = lists:map(fun([Label,Vs]) -> [ dict:fetch(Label,Dict), lists:map(fun([K,W]) -> [dict:fetch(K,Dict),W] end,Vs) ] end, Graph),
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
