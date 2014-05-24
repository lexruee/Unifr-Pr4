#! /bin/sh

# author:   Alexander Rüedlinger, Michael Jungo
# date:     2014

HOST=$(uname -n)
ssh "$1" "cd $2 && erl +P $3 -name $4 -setcookie $5 -detached"
