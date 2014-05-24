#! /bin/sh

# author:   Alexander Rüedlinger, Michael Jungo
# date:     2014

HOST=$(uname -n)
erl -name "master@$HOST" -setcookie "$1" -noshell -eval "$2,init:stop()."
