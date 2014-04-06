-module(proc_sieve).
-compile(export_all).
%
% author  & source: http://manudatta.net/wp/?p=117
%

%
% Receives a list X::list() and concatenates the head N::int() to X.
% @spec sieve(N::int(),ReqPid::int(),gather::atom()) -> any()
%
sieve(N,ReqPid,gather) ->
  receive 
    X -> ReqPid ! [N|X]
  end.

%
% This funcion matches two cases:
% 1) sieve(N::int(),NextPid::pid()) -> any()
% 2) sieve(N::int(),nil::atom()) -> any()
%
% Case 1: If it receives the done message it delegates 
% the done message it to its successor.
% If it receives an N::int() it runs sieve(N::int(),NextPid::pid()).
%
% Case 2: If it receives the done message it delegates it to its
% successor and runs sive(N::int(),ReqPid::pid(),gather::atom()).
% If it receives a N::int() it runs sieve(N::int(),NextPid::pid())
%	
% @spec sieve(N::int(),NextPid::pid()| nil::atom()) -> any()
%
sieve(N,nil)->
  receive
    {done,ReqPid} -> ReqPid ! [N] ;
    Num when is_number(Num) -> NextPid = case Num rem N of
      0 -> nil ; 
      _ -> Pid = spawn(proc_sieve,sieve,[])
          , Pid ! Num
          , Pid
      end,
      sieve(N,NextPid)
  end;

sieve(N,NextPid)->
  receive
    {done,ReqPid} -> NextPid ! {done,self()} 
      ,sieve(N,ReqPid,gather)  ;
    Num -> case Num rem N of
      0 -> nil ; 
      _ -> NextPid ! Num 
      end,
     sieve(N,NextPid)
    end.

%
% "Waits" until it receives an _N::int() 
% and runs sieve(_N::int(),nil::atom())
%
% @spec sieve() -> any()
%
sieve()->
  receive
    _N -> sieve(_N,nil)
  end.
  
%
% Generates a sieve for primes between 2 and MaxN
% and prints the resulting list.
%
% @spec generate(MaxN::int()) -> any()
%
generate(MaxN)->
  Pid = spawn(?MODULE,sieve,[])
  ,[ Pid ! X || X <- lists:seq(2,MaxN) ]
  , Pid ! {done,self()}
  , receive 
      L -> io:format("~p~n",[L])
  end.
