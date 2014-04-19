#!/bin/sh

# - Starts an Erlang node on each of a desired number of remote hosts
# - Copies and compiles an Erlang source file on each host
# - Writes the identifiers of the created nodes in the file enodes.txt in the
#   working directory of the local host
# - enodes.txt is supposed to be used as input for a distributed Erlang program
#   (e.g. cmtd.erl)
# This program is based on setup.sh and shutdown.sh written by Daniel Weibel 
# 17.05.2013
#
# History: 18.03.2014, Christian Göttel, made POSIX compatible and improved
#          29.03.2014, Christian Göttel, modifications based on student request
#          31.03.2014, Christian Göttel, detect correctly the SSH agent
#          09.04.2014, Christian Göttel, detect whether DNS or mDNS is used
#          11.04.2014, Christian Göttel, use new machine file format
#
# Author: Christian Göttel, 15.03.2014
#
# Version: 2.2-TEDA

LC_ALL=C
export LC_ALL

CLEANUP=0
COOKIE=abc
ENODES_FILE=./enodes.txt
FCT=
ID_FILE=~/.ssh/unifr_pr4
NB_MACHINES=1

# Do NOT change the value of the following variable
APP=${PWD##*/}
APP_DIR=$PWD
SSH_ARGS=
TEDA_DIR=$(dirname $(dirname $PWD))
LIB_DIR=${TEDA_DIR}/lib
MACHINES_FILE=${TEDA_DIR}/conf/hosts.txt

# usage
# Prints a help message to standard output if either the number of arguments is
# not correct or '-h' or '--help' was given as argument.
usage(){
  echo "Usage:"
  echo " $0 [-h -l] [-c cookie] [-f machines] [-i id] [-n number]"
  echo "               [-t module:function]"
  echo
  echo "Description:"
  echo " - Starts an Erlang node on a given number of remote machines"
  echo " - Copies to and compiles an Erlang source file on the remote machines"
  echo " - Writes the identifiers of the created Erlang nodes in the file \
'${ENODES_FILE}'"
  echo
  echo "Options:"
  echo "  -c, --cookie name"
  echo "    A name for the magic cookie. By default '${COOKIE}' is used as \
magic cookie."
  echo
  echo "  -f, --file machines"
  echo "    A file with the host names of the remote machines. Each line of \
the file "
  echo "    contains one host name. By default the file '${MACHINES_FILE}' \
is used."
  echo
  echo "  -h, --help"
  echo "    Prints this usage message."
  echo
  echo "  -i, --id file"
  echo "    File containing private RSA keys to use for authentication with \
remote"
  echo "    hosts. By default the file '${ID_FILE}' is used."
  echo
  echo "  -l, --cleanup"
  echo "    Deletes the application fold and its content from the hosts after \
remote"
  echo "    executing them. By default cleanup is not enabled."
  echo
  echo "  -n, --number integer"
  echo "    The number of remote hosts that is needed to execute the \
distributed"
  echo "    application. By default one remote node is launched."
  echo
  echo "  -t, --function module:function"
  echo "    Erlang function with parameters that will be executed on the \
master node"
  echo "    (localhost). This function will read the '${ENODES_FILE}' file and \
spawn the"
  echo "    other nodes."
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
    -f | --file ) shift
      MACHINES_FILE=$1
      shift ;;
    -i | --id ) shift
      ID_FILE=$1
      shift ;;
    -l | --cleanup ) CLEANUP=1
      shift ;;
    -n | --number ) shift
      NB_MACHINES=$1
      shift ;;
    -t | --function ) shift
      FCT=$1
      shift ;;
    * ) if [ ! -z "$1" ]; then
	usage
	exit 1
      fi ;;
  esac
done

rm -f $ENODES_FILE *.beam
sed -e 's/^#.*//' -e '/^$/d' $MACHINES_FILE > .hosts.tmp

# Checking host availability
echo "Checking availability of remote hosts"
I=0
while read HOST NB_NODES NB_PROCS USERNAME; do
  echo -n "  ${HOST}... "
  ping -q -c1 $HOST > /dev/null
  if [ $? -eq 0 ] ; then
    echo "available"
    append HOSTS "${HOST}:${NB_NODES}:${NB_PROCS}:${USERNAME}"
    I=$((${I}+1))
    if [ $I -eq $NB_MACHINES ]; then break ; fi
  else echo "not available"
  fi
done < .hosts.tmp

echo
if [ $I -lt $NB_MACHINES ]; then
  echo "Only $I machines instead of your requested $NB_MACHINES are \
available."
  echo "Terminating."
  exit 2
fi

echo "We got $I machines for you. Yay!"

# Setup SSH agent
if [ -S $SSH_AUTH_SOCK ]; then
  ssh-add $ID_FILE &> /dev/null
else
  SSH_ARGS="-2 -i $ID_FILE"
fi

HOST=$(uname -n)
NODE="master"
if [ -z "$(cat .hosts.tmp | grep .local)" ]; then
  NODE_ID=${NODE}@${HOST}
else
  NODE_ID=${NODE}@${HOST}.local
fi
echo \'${NODE_ID}\'. > $ENODES_FILE
rm -f .hosts.tmp

# Copy/compile source code, start node, write output
for I in $HOSTS ; do
  HOST=$(echo $I | cut -d : -f 1)
  NB_NODES=$(echo $I | cut -d : -f 2)
  NB_PROCS=$(echo $I | cut -d : -f 3)
  USERNAME=$(echo $I | cut -d : -f 4)
  echo
  echo $HOST
  echo " - Uploading ${APP}.zip..."
  cd ../..
  zip -r ${APP}.zip ./${APP_DIR#$TEDA_DIR}/* ./${LIB_DIR#$TEDA_DIR}/* -x \
\*.beam \*.dump \*enodes.txt &> /dev/null
  scp -q $SSH_ARGS ${APP}.zip ${USERNAME}@${HOST}:~
  rm -f ${APP}.zip
  cd ${APP_DIR}
  echo " - Unpacking ${APP}.zip..."
  ssh $SSH_ARGS ${USERNAME}@${HOST} "mkdir ~/teda &> /dev/null && unzip \
~/${APP}.zip -d ~/teda &> /dev/null && rm -f ~/${APP}.zip"
  echo " - Compiling ${APP}...	"
  ssh $SSH_ARGS ${USERNAME}@${HOST} "cd ~/teda/${APP_DIR#$TEDA_DIR} && erl \
-noshell -eval 'make:all(),init:stop().' &> /dev/null"
  for (( i = 1 ; i <= $NB_NODES ; i++ )) ; do
    NODE=$RANDOM
    NODE_ID=${NODE}@${HOST}
    echo " - Starting Erlang node(s) ${NODE_ID}..."
    if [ "$NB_PROCS" = "default" ]; then
      NB_PROCS=$(ssh $SSH_ARGS ${USERNAME}@${HOST} "erl -noshell -eval \
'io:format(\"~p~n\",[erlang:system_info(process_limit)]),init:stop().'")
    fi
    ssh $SSH_ARGS ${USERNAME}@${HOST} "cd ~/teda/${APP_DIR#$TEDA_DIR} && erl \
+P $NB_PROCS -name $NODE_ID -setcookie $COOKIE -detached"
  done
  echo \'${NODE_ID}\'. >> $ENODES_FILE
done

erl -noshell -eval 'make:all(),init:stop().' &> /dev/null
HOST=$(uname -n)
NODE="master"
NODE_ID=${NODE}@${HOST}
echo
echo "Creating $NODE_ID with cookie '${COOKIE}'"
erl -name $NODE_ID -setcookie $COOKIE -noshell -eval "${FCT},init:stop()."

# Shutdown nodes and clean up environment
while read LINE
do
  append CMD "rpc:call(${LINE%%.},init,stop,[]),"
done < $ENODES_FILE

append CMD "init:stop()."
echo "Terminating nodes"
NODE="terminator"
NODE_ID=${NODE}@${HOST}
erl -name $NODE_ID -setcookie $COOKIE -noshell -eval "$CMD"
echo "Shutting down Erlang Port Mapper Daemons (epmd)..."

if [ $CLEANUP -eq 1 ]; then
  CMD="epmd -kill && rm -fR ~/teda"
else
  CMD="epmd -kill"
fi

for I in $HOSTS ; do
  HOST=$(echo $I | cut -d : -f 1)
  USERNAME=$(echo $I | cut -d : -f 4)
  echo -n "  ${HOST}... "
  ssh $SSH_ARGS ${USERNAME}@${HOST} "$CMD"
done

echo -n "  $(uname -n)... "
epmd -kill
