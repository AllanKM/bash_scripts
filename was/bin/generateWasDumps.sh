#!/bin/bash
# Usage: generateWasDumps.sh [version=<61|70|85>] [profile=<wasprofile>] <jvm> [<jvm2> ... <jvmN>] 

USER=webinst
#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
		version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VERSION=$VALUE; fi ;;
		profile=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROFILE=$VALUE; fi ;;
		help) echo "Usage: 	generateWasDumps.sh [version=<61|70>] [profile=<wasprofile>] <jvm> [<jvm2> ... <jvmN>]"
			exit 0 ;;
		*)	if [ ${#CLUSTERS} -eq 0 ]; then
				JVMS=$1
		    else
		    	JVMS="$JVMS $1"
			fi
			;;
	esac
	shift
done

i=0
if [ "$VERSION" != "" ] && [ "$PROFILE" != "" ]; then
	#Use version and profile specified on command line
	wasList[$i]="/usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}"
	i=$(($i+1))
elif [ "$VERSION" != "" ] && [ "$PROFILE" == "" ]; then
	#Use version specified, search for profiles
	DIR="/usr/WebSphere${VERSION}/AppServer"
	for profile in `ls ${DIR}/profiles/`; do
		wasList[$i]="${DIR}/profiles/${profile}"
		i=$(($i+1))
	done
elif [ "$VERSION" == "" ] && [ "$PROFILE" != "" ]; then
	#Search for profile given
	DIRLIST=`ls -d /usr/WebSphere*/AppServer/profiles/* | grep $PROFILE`
	for DIR in $DIRLIST; do
		wasList[$i]=$DIR
		i=$(($i+1))
	done
else
	#No version/profile
	DIRLIST=`find /usr/WebSphere* -type d -name 'AppServer' ! -name . -prune`
	for DIR in $DIRLIST; do
		for profile in `ls ${DIR}/profiles/`; do
			wasList[$i]="${DIR}/profiles/${profile}"
			i=$(($i+1))
		done
	done
fi

if [ $i -gt 1 ]; then
	echo "WebSphere environment(s) and profiles:"
	i=0
	while [[ ${wasList[$i]} != "" ]]; do
		echo "        [$i] ${wasList[$i]}"
		i=$(($i+1))
	done
	printf "\nEnter number for the WebSphere environment you want to use: "
	read choice
	echo "Using: ${wasList[$choice]}"
	ASROOT=${wasList[$choice]}
else
	ASROOT=${wasList}
fi
PROFILE=${ASROOT##*/}

for jvm in $JVMS; do
	# Generate WAS heap dump
	/lfs/system/tools/was/bin/forceHeapDump.sh $VERSION $jvm $PROFILE
	# Generate javacore (kill -3 <pid>)
	PID=`ps -ef |grep $jvm |grep -v generateWasDumps |grep -v grep |awk '{print $2}'`
	kill -3 $PID
done

dumpfiles=`find ${ASROOT} -name "heapdump*" -o -name "javacore*" -mmin -10`
read -p "Do you want to SCP the dumps somewhere? "
if [[ "$REPLY" == [Yy] ]]; then
	read -p "Where? (node:/location/)  " DEST
	for dump in $dumpfiles; do
		scp -p $dump ${SUDO_USER}@${DEST}/
	done
	read -p "Delete the local dump files? "
	if [[ "$REPLY" == [Yy] ]]; then
		for dump in $dumpfiles; do
			rm $dump
		done
	fi
else
	echo "WAS Dump files created:"
	for dump in $dumpfiles; do
		echo "     $dump"
	done
fi

