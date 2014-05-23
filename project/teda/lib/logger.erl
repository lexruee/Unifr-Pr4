-module(logger).

-compile(export_all).

% Author:   Alexander Rüedlinger, Michael Jungo
% Date:     May 2014
% Lecture:  Project 4: Concurrent, Parallel and Distributed Computing

% create():
% Two formats: "console" and "file"
% If chosen console then the tracing is done to a separate file
% because it would be too much to display in the console
% If chosen file then it will write everything into the given file
% if no file is specified then the default log.txt is used.
% @spec create(Format::list()) -> any()
create(Format) when Format == "console" ->
	global:register_name(logger, spawn(?MODULE, loopConsole, [[], 1])), % register process globally
	file:write_file("trace.txt", ""), % create empty File for tracing (overwrite if it already exists)
	global:sync(); % synchronize with all processes known (i.e. creator)

% @spec create(Format::list()) -> any()
create(Format) when Format == "file" ->
	create(Format, "log.txt").
	
% @spec create(Format::list(), File::list()) -> any()
create(Format, File) when Format == "file" ->
	global:register_name(logger, spawn(?MODULE, loopFile, [[], 1, File])), % register process globally
	file:write_file(File, ""), % create empty File (overwrite if it already exists)
	global:sync(). % synchronize with all processes known (i.e. creator)

% loopConsole():
% Loop for logger writing to console
% @spec loopConsole(Clocks::list(), GlobalC::int()) -> any()
loopConsole(Clocks, GlobalC) ->
	receive
		{attach, Pid} ->
			case lists:keymember(Pid, 1, Clocks) of		% if not in list, add it
				true ->
					NewClocks = Clocks;
				false ->
					NewClocks = lists:append(Clocks, [{Pid, 1}])
			end,
			loopConsole(NewClocks, GlobalC);
		{add, Pid, Msg} ->
			%io:format("Clocks: ~p\n", [lists:flatten(Clocks)]),
			case lists:keymember(Pid, 1, Clocks) of		% if Pid is not attached, ignore message
				false ->
					loopConsole(Clocks, GlobalC);
				true ->
					nothing
			end,
			{_, C} = lists:keyfind(Pid, 1, Clocks),
			case GlobalC >= C of
				true ->
					NewC = GlobalC + 1;
				false ->
					NewC = C + 1
			end,
			NewClocks = lists:keyreplace(Pid, 1, Clocks, {Pid, NewC}),
			io:format("~p - ~p~n~s~n", [NewC, Pid, Msg]), % s = string (respects newline etc.)
			loopConsole(NewClocks, NewC);
		{detach, Pid} ->
			NewClocks = lists:keydelete(Pid, 1, Clocks),
			loopConsole(NewClocks, GlobalC);
		{trace, From, To, Msg} ->
			{NewClocks, NewC} = updateCounters(From, To, Clocks, GlobalC),
			%io:format("~p - ~p -> ~p - TRACE~n~s~n", [NewC, From, To, Msg]), % s = string (respects newline etc.)
			file:write_file("trace.txt", io_lib:format("~p - ~p -> ~p - TRACE~n~s~n", [NewC, From, To, Msg]), [append]), % append to file
			loopConsole(NewClocks, NewC)
	end.

% loopFile():
% Loop for logger writing to file
% @spec loopFile(Clocks::list(), GlobalC::int(), File::list()) -> any()
loopFile(Clocks, GlobalC, File) ->
	receive
		{attach, Pid} ->
			case lists:keymember(Pid, 1, Clocks) of		% if not in list, add it
				true ->
					NewClocks = Clocks;
				false ->
					NewClocks = lists:append(Clocks, [{Pid, 1}])
			end,
			loopFile(NewClocks, GlobalC, File);
		{add, Pid, Msg} ->
			case lists:keymember(Pid, 1, Clocks) of		% if Pid is not attached, ignore message
				false ->
					loopFile(Clocks, GlobalC, File);
				true ->
					nothing
			end,
			{_, C} = lists:keyfind(Pid, 1, Clocks),
			case GlobalC >= C of
				true ->
					NewC = GlobalC + 1;
				false ->
					NewC = C + 1
			end,
			NewClocks = lists:keyreplace(Pid, 1, Clocks, {Pid, NewC}),
			file:write_file(File, io_lib:format("~p - ~p~n~s~n", [NewC, Pid, Msg]), [append]), % append to file
			loopFile(NewClocks, NewC, File);
		{detach, Pid} ->
			NewClocks = lists:keydelete(Pid, 1, Clocks),
			loopFile(NewClocks, GlobalC, File);
		{trace, From, To, Msg} ->
			{NewClocks, NewC} = updateCounters(From, To, Clocks, GlobalC),
			file:write_file(File, io_lib:format("~p - ~p -> ~p - TRACE~n~s~n", [NewC, From, To, Msg]), [append]), % append to file
			loopFile(NewClocks, NewC, File)
	end.

% tracer():
% Loop of the system tracer
% Ignore messages to and from logger
% Filter out io_ and code_ messages
% Transmit informations to logger
% @spec tracer() -> any()
tracer() ->
	receive
		{seq_trace, _, SeqTraceInfo} ->
			{_, _, From, To, Message} = SeqTraceInfo,
			case global:whereis_name(logger) of		% filter out messages to/from logger
				To ->
					tracer();
				From ->
					tracer();
				_ ->
					nothing
			end,		
			Token = lists:flatten(io_lib:format("~p", [element(1, Message)])),	% get first element from tuple
			case re:run(Token, "io_.*") of	% filter out io_ messages
				{match, _} ->
					tracer();
				_ ->
					nothing
			end,
			case re:run(Token, "code_.*") of	% filter out code_ messages
				{match, _} ->
					tracer();
				_ ->
					nothing
			end,
			Msg = lists:flatten(io_lib:format("~p", [Message])),
			global:send(logger, {trace, From, To, Msg}),
			tracer()
	end.

% attach():
% Attach the process to the logger
% Create system tracer process if not already existant
% Set token 'receive' to true for tracing
% @spec attach() -> any()
attach() ->
	global:sync(), % Make sure the logger is known
	global:send(logger, {attach, self()}),
	case seq_trace:get_system_tracer() of
		false ->
			Tracer = spawn(?MODULE, tracer, []),	% create system_tracer process
			global:send(logger, {attach, Tracer}),
			seq_trace:set_system_tracer(Tracer);
		_ ->
			nothing
	end,
	seq_trace:set_token('receive', true).

% detach():
% Detach the process from the logger
% @spec detach() -> any()
detach() ->
	global:send(logger, {detach, self()}),
	seq_trace:set_token('receive', false).

% add():
% Add a message to the log
% Set token 'receive' to true for the tracing
% @spec add(Msg::list()) -> any()
add(Msg) ->
	global:send(logger, {add, self(), Msg}),
	seq_trace:set_token('receive', true).
	
% add():
% Add a message to the log
% same syntax as io:format
% @spec add(Msg::list(), Args::list()) -> any()
add(Msg, Args) ->
	NewMsg = lists:flatten(io_lib:format(Msg, Args)),
	add(NewMsg).


% getCounters():
% Get counters of the given Pids.
% @spec getCounters(Pid1::pid(), Pid2::pid(), Clocks::list()) -> {C1::int(), C2::int()}
getCounters(Pid1, Pid2, Clocks) ->
	%io:format("Clocks: ~p\n", [lists:flatten(Clocks)]),
	case lists:keymember(Pid1, 1, Clocks) of
		false ->
			C1 = 0;
		true ->
			{_, C1} = lists:keyfind(Pid1, 1, Clocks)
	end,
	case lists:keymember(Pid2, 1, Clocks) of
		false ->
			C2 = 0;
		true ->
			{_, C2} = lists:keyfind(Pid2, 1, Clocks)
	end,
	{C1, C2}.

% updateCounters():
% Update counters of the given Pids.
% @spec updateCounters(Pid1::pid(), Pid2::pid(), Clocks::list(), GlobalC::int()) -> {NewClocks::list(), NewC::int()}
updateCounters(Pid1, Pid2, Clocks, GlobalC) ->
	{C1, C2} = getCounters(Pid1, Pid2, Clocks),
	case C2 >= C1 of
		true ->
			Temp = C2;
		false ->
			Temp = C1
	end,
	case GlobalC >= Temp of
		true ->
			NewC = GlobalC + 1;
		false ->
			NewC = Temp + 1
	end,
	TempList = lists:keyreplace(Pid1, 1, Clocks, {Pid1, NewC}),
	NewClocks = lists:keyreplace(Pid2, 1, TempList, {Pid2, NewC}),
	{NewClocks, NewC}.
	
