#!/bin/sh

# Destroys RSA authentication for ssh and scp, so that we have to enter the
# password again.

# For every remote host in MACHINES (one host per line), removes the public
# RSA key on the remote host's ~/.ssh/authorized_keys and restores the
# previous ~/.ssh/authorized_keys file if it exists. It further deletes the
# private RSA key.
#
# History: 28.03.2014, Christian Göttel, modifications based on student request
#          31.03.2014, Christian Göttel, detect correctly the SSH agent
#          29.04.2014, Christian Göttel, fixed non-POSIX redirection thanks to
#                                        Jocelyn Thode and Simon Brulhart
#
# Author: Christian Göttel 18.03.2014
#
# Version: 1.2

LC_ALL=C
export LC_ALL

ID_FILE=~/.ssh/unifr_pr4
MACHINES_FILE=../conf/unifr_machines.txt
USERNAME=$USER

# Do NOT change the value of the following variable
SSH_ARGS=

# usage:
# Prints a help message to standard output if either the number of arguments is
# not correct or '-h' or '--help' was given as argument.
usage(){
  echo "Usage:"
  echo " $0 [-h] [-f file] [-i file] [-u user]"
  echo
  echo "Description:"
  echo "Destroys RSA authentication for ssh and scp, so that we have to enter \
the "
  echo "password again. Removes public keys on remote hosts and private key on \
local "
  echo "host."
  echo
  echo "Options:"
  echo "  -f, --file file"
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
  echo "  -u, --user username"
  echo "    User name for all remote machines. By default this is the user \
under which "
  echo "    this script is run."
}

# Parse script arguments
for i; do
  case $1 in
    -h | --help ) usage
      exit 0 ;;
    -f | --file ) shift
      MACHINES_FILE=$1
      shift ;;
    -i | --id ) shift
      ID_FILE=$1
      shift ;;
    -u | --user ) shift
      USERNAME=$1
      shift ;;
    * ) if [ ! -z "$1" ]; then
	usage
	exit 1
      fi ;;
  esac
done

# Setup SSH agent
if [ -S $SSH_AUTH_SOCK ]; then
  ssh-add $ID_FILE >& /dev/null
else
  SSH_ARGS="-2 -i $ID_FILE"
fi

KEY=$(sed -e 's/\//\\\//g' ${ID_FILE}.pub)

# Remove public RSA from remote hosts and delete public and private RSA key 
# from local host
while read HOST ; do
  ssh $SSH_ARGS ${USERNAME}@${HOST} "if [ -f ~/.ssh/authorized_keys ]; then \
sed -e 's/${KEY}//g' ~/.ssh/authorized_keys > ~/.ssh/ak; mv ~/.ssh/ak \
~/.ssh/authorized_keys; fi"
done < $MACHINES_FILE

ssh-add -d $ID_FILE >& /dev/null
rm -f ${ID_FILE}*
