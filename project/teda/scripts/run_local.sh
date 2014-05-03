#!/bin/bash

# Creates Erlang nodes on the local machine in the current working directory.
# Writes the identifiers of the created nodes in the file enodes.txt.
# This program is based on setup_local.sh and shutdown.sh written by Daniel 
# Weibel 17.05.2013
#
# History: 29.03.2014, Christian Göttel, improved argument parsing
#          22.04.2014, Christian Göttel, fixed non-POSIX compatible loop thanks
#                                        to Alexander Rüedlinger
#          29.04.2014, Christian Göttel, fixed non-POSIX redirection thanks to
#                                        Jocelyn Thode and Simon Brulhart
#
# Author: Christian Göttel, 15.03.2014
#
# Version: 1.2-TEDA

LC_ALL=C
export LC_ALL

COOKIE=abc
ENODES_FILE=./enodes.txt
FCT=
HOST=$(uname -n)
NB_NODES=1

usage(){
  echo "Usage:"
  echo "  $0 [-h] [-c name] [-f module:function] [-n integer]"
  echo
  echo "Description:"
  echo "  Creates Erlang nodes in the current directory of the local machine"
  echo "  and writes their identifiers by default in '${ENODES_FILE}'."
  echo
  echo "Options:"
  echo "  -c, --cookie name"
  echo "    The magic cookie for the nodes. By default '${COOKIE}' is used."
  echo
  echo "  -f, --function module:function"
  echo "    Erlang function with parameters that will be executed on the \
master node"
  echo "    (localhost). This function will read the '${ENODES_FILE}' file and \
spawn the"
  echo "    other nodes."
  echo
  echo "  -n, --number integer"
  echo "    The number of Erlang nodes to be created excluding master node. By \
default"
  echo "    ${NB_NODES} node(s) will be launched."
}

append(){
  var=$1
  shift
  eval "$var=\"\$$var $*\""
}

# Parse script arguments
for i; do
  case $1 in
    -h | --help ) usage
      exit 0 ;;
    -c | --cookie ) shift
      COOKIE=$1
      shift ;;
    -f | --function ) shift
      FCT=$1
      shift ;;
    -n | --number ) shift
      NB_NODES=$1
      shift ;;
    * ) if [ ! -z "$1" ]; then
	usage
	exit 1
      fi ;;
  esac
done

rm -f $ENODES_FILE *.beam

NODE="master"
NODE_ID=${NODE}@${HOST}
echo \'${NODE_ID}\'. > $ENODES_FILE

NODE=0
while [ $NODE -lt $NB_NODES ];
do
  NODE_ID=${NODE}@${HOST}
  echo "Creating $NODE_ID with cookie '${COOKIE}'"
  erl -sname $NODE -setcookie $COOKIE -detached
  echo \'${NODE_ID}\'. >> $ENODES_FILE
  NODE=$(($NODE+1))
done

erl -noshell -eval 'make:all(),init:stop().' >& /dev/null
NODE="master"
NODE_ID=${NODE}@${HOST}
echo "Creating $NODE_ID with cookie '${COOKIE}'"
erl -sname $NODE -setcookie $COOKIE -noshell -eval "${FCT},init:stop()."

while read LINE
do
  if [ "$LINE" = "'master@${HOST}'." ]; then
    continue
  fi
  append CMD "rpc:call(${LINE%%.},init,stop,[]),"
done < $ENODES_FILE

append CMD "init:stop()."
echo "Terminating nodes"
erl -sname "terminator" -setcookie $COOKIE -noshell -eval "$CMD"
echo -n "Shutting down Erlang Port Mapper Daemon (epmd)... "
epmd -kill
