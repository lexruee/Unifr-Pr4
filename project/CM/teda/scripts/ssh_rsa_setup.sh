#!/bin/sh

# Sets up RSA authentication for ssh and scp, so that we don't need to enter
# the password anymore.

# For every remote host in MACHINES (one host per line), puts our public RSA
# key into the remote host's ~/.ssh/authorized_keys.
# In order to backup the previous ~/.ssh/authorized_keys file of the remote
# hosts simply run the script 'ssh_rsa_destroy.sh'.
#
# History: 18.03.2014, Christian Göttel, made POSIX compatible and improved
#          28.03.2014, Christian Göttel, modifications based on student request
#
# Author: Christian Göttel, 15.03.2014
#
# Version: 2.1

LC_ALL=C
export LC_ALL

GENERATE_KEY=0
ID_FILE=~/.ssh/unifr_pr4
MACHINES_FILE=./unifr_machines.txt
PASSPHRASE=
USERNAME=$USER

# usage:
# Prints a help message to standard output if either the number of arguments is
# not correct or '-h' or '--help' was given as argument.
usage(){
  echo "Usage:"
  echo " $0 [-g -h] [-f file] [-i file] [-p passphrase] [-u user]"
  echo
  echo "Description:"
  echo "Sets up RSA authentication for ssh and scp, so that we don't need to \
enter the password anymore."
  echo
  echo "Options:"
  echo "  -f, --file file"
  echo "    A file with the host names of the remote machines. Each line of \
the file "
  echo "    contains one host name. By default the file '${MACHINES_FILE}' \
is used."
  echo
  echo "  -g, --generate"
  echo "    Generate the '${ID_FILE}' of type RSA with protocol version 2."
  echo
  echo "  -h, --help"
  echo "    Prints this usage message."
  echo
  echo "  -i, --id file"
  echo "    File containing private RSA keys to use for authentication with \
remote"
  echo "    hosts. By default the file '${ID_FILE}' is used."
  echo
  echo "  -p, --passphrase passphrase"
  echo "    Secure the private RSA key by an additional passphrase. This \
option is"
  echo "    recommended when using SSH agent."
  echo
  echo "  -u, --user username"
  echo "    User name for all remote machines. By default this is the user \
under which "
  echo "    this script is run."
}

# Parse script arguments
for i; do
  case $1 in
    -h|--help) usage
      exit 0 ;;
    -f|--file) shift
      MACHINES_FILE=$1
      shift ;;
    -g|--generate) GENERATE_KEY=1
      shift ;;
    -i|--id) shift
      ID_FILE=$1
      shift ;;
    -p|--passphrase) shift
      PASSPHRASE=$1
      shift ;;
    -u|--user) shift
      USERNAME=$1
      shift ;;
    *) if [ ! -z "$1" ]; then
	usage
	exit 1
      fi ;;
  esac
done

# Generate private and public RSA key
if [ $GENERATE_KEY -eq 1 ]; then
  if [ -f $ID_FILE ]; then
    echo "Nothing to do: the identity file exist already. Run \ 
'ssh_rsa_destroy.sh' to"
    echo "delete it or choose a new identity file name."
    exit 0
  fi
  ssh-keygen -t rsa -N "$PASSPHRASE" -f $ID_FILE > /dev/null
fi

# Distribute the public RSA key to the remote hosts
while read HOST ; do
  echo -n "${USERNAME}@${HOST} "
  ssh-copy-id -i $ID_FILE ${USERNAME}@${HOST} &> /dev/null
  if [ ! $? -eq 0 ]; then
    echo "Remote setup for host $HOST failed."
  fi
done < $MACHINES_FILE
