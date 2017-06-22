#!/bin/bash
USER=webinst
JYDIR=/lfs/system/tools/was/lib

# If not run from a DM node, exit
ISDM=`lssys -n -l role -x csv|grep -v '^#'|awk '{split($0,a,","); print a[2]}'|grep 'WAS\.DM\.'`
if [ -z $ISDM ]; then echo "!! Must be run from the cell DM node !!"; exit 1; fi

#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
		version=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VERSION=$VALUE; fi ;;
		profile=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROFILE=$VALUE; fi ;;
		*) echo "Usage: listAdminGroups.sh [version=<70|etc>] [profile=<profilename>]"
			exit 0 ;;
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
	WSADMIN="${ASROOT}/bin/wsadmin.sh -lang jython"
else
	ASROOT=${wasList}
	WSADMIN="${wasList}/bin/wsadmin.sh -lang jython"
fi

#Double check version/profile are set
if [ -z $VERSION ]; then VERSION=`echo $ASROOT|awk '{split($0,v,"/"); print v[3]}'|cut -c10-`; fi
if [ -z $PROFILE ]; then PROFILE=`echo $ASROOT|awk '{split($0,p,"/"); print p[6]}'`; fi

LOGDIR="/logs/was${VERSION}/${PROFILE}"
LOGGING="-tracefile ${LOGDIR}/wsadmin.listAdminGroups.traceout"
su - $USER -c "$WSADMIN -conntype NONE $LOGGING -f ${JYDIR}/listgroups.py |grep -v '^WASX'"