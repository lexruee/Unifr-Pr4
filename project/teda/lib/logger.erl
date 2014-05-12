-module(logger).

-compile(export_all).

create(Format) when Format == "console" ->
	global:register_name(logger, spawn(?MODULE, loopConsole, [[], 1])), % register process globally
	global:sync(); % snychronize with all processes known (i.e. creator)

create(Format) when Format == "file" ->
	global:register_name(logger, spawn(?MODULE, loopFile, [[], 1])), % register process globally
	file:write_file("log.txt", ""), % create empty File (overwrite if it already exists)
	global:sync(). % snychronize with all processes known (i.e. creator)

loopConsole(Clocks, GlobalC) ->
	receive
		{attach, Pid} ->
			AlreadyExists = lists:keymember(Pid, 1, Clocks),
			case AlreadyExists of
				true ->
					NewClocks = Clocks;
				false ->
					NewClocks = lists:append(Clocks, [{Pid, 1}])
			end,
			loopConsole(NewClocks, GlobalC);
		{add, Pid, Msg} ->
			{_, C} = lists:keyfind(Pid, 1, Clocks),
			case GlobalC >= C of
				true ->
					NewC = GlobalC + 1;
				false ->
					NewC = C + 1
			end,
			NewClocks = lists:keyreplace(Pid, 1, Clocks, {Pid, NewC}),
			io:format("Pid: ~p, Counter: ~p, Msg: ~s~n", [Pid, NewC, Msg]), % s = string (respects newline etc.)
			loopConsole(NewClocks, GlobalC + 1);
		{detach, Pid} ->
			NewClocks = lists:keydelete(Pid, 1, Clocks),
			loopConsole(NewClocks, GlobalC)
	end.

loopFile(Clocks, GlobalC) ->
	receive
		{attach, Pid} ->
			AlreadyExists = lists:keymember(Pid, 1, Clocks),
			case AlreadyExists of
				true ->
					NewClocks = Clocks;
				false ->
					NewClocks = lists:append(Clocks, [{Pid, 1}])
			end,
			loopFile(NewClocks, GlobalC);
		{add, Pid, Msg} ->
			{_, C} = lists:keyfind(Pid, 1, Clocks),
			case GlobalC >= C of
				true ->
					NewC = GlobalC + 1;
				false ->
					NewC = C + 1
			end,
			NewClocks = lists:keyreplace(Pid, 1, Clocks, {Pid, NewC}),
			file:write_file("log.txt", io_lib:format("Pid: ~p, Counter: ~p, Msg: ~s~n", [Pid, NewC, Msg]), [append]), % append to file
			loopFile(NewClocks, GlobalC + 1);
		{detach, Pid} ->
			NewClocks = lists:keydelete(Pid, 1, Clocks),
			loopFile(NewClocks, GlobalC)
	end.

attach() ->
	global:sync(), % Make sure the logger is known
	global:send(logger, {attach, self()}).

detach() ->
	global:send(logger, {detach, self()}).

add(Msg) ->
	global:send(logger, {add, self(), Msg}).

% same syntax as io:format
add(Msg, Args) ->
	NewMsg = lists:flatten(io_lib:format(Msg, Args)),
	add(NewMsg).
