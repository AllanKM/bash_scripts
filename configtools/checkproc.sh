#!/bin/ksh

# check for running processes

CHECKSTRING=$1
CHECKNUM=$2

# assume 1 proc if not specified
if [[ $CHECKNUM -lt 1 ]] ; then
	CHECKNUM=1
fi

OS=`uname`
PS="/bin/ps"
if [[ "$OS" = "Linux" ]] ; then
        PS="ps --cols 1000"
fi

ACTUALNUM=`$PS -ef | grep $1 | grep -v grep | grep -v checkproc.sh | wc -l`
#echo "Got $ACTUALNUM, looking for $CHECKNUM.."

if [[ $ACTUALNUM -lt $CHECKNUM ]]
then
	#echo "FAILED"
	exit 1;
else
	#echo "PASSED"
	exit 0;
fi


