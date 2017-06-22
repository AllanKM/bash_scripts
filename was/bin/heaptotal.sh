#!/bin/bash
# Total up the maximum memory usage of JVM heaps on a WAS/WPS node
#    - A wrapper script for heaptotal.py
#
# Author:	James Walton <jfwalton@us.ibm.com>
# Date:		09 April 2013
# Usage: 	heaptotal.sh [version=70|85] [profile=<profilename>] [node=<nodename>] [data=config|runtime]

USER=webinst
VERSION="70"
WASLIB="/lfs/system/tools/was/lib"
WASUTIL="${WASLIB}/heaptotal.py"
DATA="config"
#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
		version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VERSION=$VALUE; fi ;;
		profile=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROFILE=$VALUE; fi ;;
    	node=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then NODE=$VALUE; fi ;;
    	data=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DATA=$VALUE; fi ;;
		help) echo "Usage: 	heaptotal.sh [version=70|85] [profile=<profilename>] [node=<nodename>] [data=config|runtime]"
			exit 0 ;;
		*)	echo "You lost me there... try again"; exit 1 ;;
	esac
	shift
done

i=0
if [ "$VERSION" != "" ] && [ "$PROFILE" != "" ]; then
	wasList[$i]="/usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}"
	i=$(($i+1))
elif [ "$VERSION" != "" ] && [ "$PROFILE" == "" ]; then
	DIR="/usr/WebSphere${VERSION}/AppServer"
	for profile in `ls ${DIR}/profiles/`; do wasList[$i]="${DIR}/profiles/${profile}"; i=$(($i+1)); done
elif [ "$VERSION" == "" ] && [ "$PROFILE" != "" ]; then
	DIRLIST=`ls -d /usr/WebSphere*/AppServer/profiles/* | grep $PROFILE`
	for DIR in $DIRLIST; do wasList[$i]=$DIR; i=$(($i+1)); done
else
	DIRLIST=`find /usr/WebSphere* -type d -name 'AppServer' ! -name . -prune`
	for DIR in $DIRLIST; do
		for profile in `ls ${DIR}/profiles/`; do wasList[$i]="${DIR}/profiles/${profile}"; i=$(($i+1)); done
	done
fi

if [ $i -gt 1 ]; then
	echo "WebSphere environment(s) and profiles:"
	i=0
	while [[ ${wasList[$i]} != "" ]]; do echo "        [$i] ${wasList[$i]}"; i=$(($i+1)); done
	printf "\nEnter number for the WebSphere environment you want to use: "
	read choice
	echo "Using: ${wasList[$choice]}"
	ASROOT=${wasList[$choice]}
else
	ASROOT=${wasList}
fi

if [ -x ${ASROOT}/bin/wsadmin.sh ]; then
	WSADMIN="${ASROOT}/bin/wsadmin.sh -lang jython"
else
	echo "Failed to locate ${ASROOT}/bin/wsadmin.sh ... exiting"
	exit 1
fi

case $DATA in
	"config") WSADMIN="$WSADMIN -conntype NONE" ;;
	"runtime") WSADMIN="$WSADMIN -conntype SOAP" ;;
	*) echo "Oh, he says it's nothing, sir. Merely a malfunction, old data."; exit 1 ;;
esac

LOGDIR="/logs/was${VERSION}"
LOG="${LOGDIR}/heaptotal.out"
echo "Generating $DATA heap report..."
su - webinst -c "$WSADMIN -tracefile $LOG -f $WASUTIL $NODE $DATA 2>&1 |egrep -v '^WASX|sys-package-mgr'"
