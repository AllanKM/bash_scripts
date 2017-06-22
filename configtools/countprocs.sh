#!/bin/ksh

OS=`uname`
NUM=$1
GREP1=$2
GREP2=$3
GREP3=$4
GREP4=$5

case $OS in
	AIX)	PS="ps -ef" ;;
	Linux)	PS="ps --cols 1000 -ef" ;;
esac

#$PS | grep -v grep | grep -v countprocs | grep "$GREP1" | grep "$GREP2" | grep "$GREP3" | grep "$GREP4"

if [[ -n "$GREP1" ]]; then

    NUMPROCS=`$PS | grep -v grep | grep -v countprocs | grep -v check | grep "$GREP1" | grep "$GREP2" | grep "$GREP3" | grep "$GREP4" | wc -l | sed s/\ //g`

    echo "$NUMPROCS processes found running"

else
    echo "there is no such PID running"
    exit 1
fi

if [[ "$NUMPROCS" = "0" ]] ; then
	exit 1
else
	exit 0
fi

