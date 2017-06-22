#!/bin/bash
#
# Edit WebSphere appserver web server plugin properties
#    - Basically a wrapper for server.py -action modify -server <blah> -attr plugin:.....
#
# Author:	James Walton
# Contact:	jfwalton@us.ibm.com
# Date:		17 Nov 2009
#
#   Usage: editPluginProps.sh [version=<60|61>] [profile=<profilename>] cluster=<clustername> Prop1=value Prop2=value ...
#
USER=webinst
JYDIR=/lfs/system/tools/was/lib

# If not run from a DM node, exit
ISDM=`lssys -n -l role -x csv|grep -v '^#'|awk '{split($0,a,","); print a[2]}'|grep 'WAS\.DM\.'`
if [ -z $ISDM ]; then printf "!! Must be run from the cell DM node !!\n#### Update Failed...\n"; exit 1; fi

#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
		version=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VERSION=$VALUE; fi ;;
		profile=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROFILE=$VALUE; fi ;;
		cluster=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CLUSTER=$VALUE; fi ;;
		help) echo "Usage: editPluginProps.sh [version=<60|61>] [profile=<profilename>] cluster=<clustername> Prop1=value Prop2=value ..."
			exit 0 ;;
		*)	if [ ${#PLGPropMods} -eq 0 ]; then
				PLGPropMods=$1
			else
				PLGPropMods="${PLGPropMods},$1"
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
	WSADMIN="${ASROOT}/bin/wsadmin.sh -lang jython"
else
	ASROOT=${wasList}
	WSADMIN="${wasList}/bin/wsadmin.sh -lang jython"
fi

#Double check version/profile are set
if [ -z $VERSION ]; then VERSION=`echo $ASROOT|awk '{split($0,v,"/"); print v[3]}'|cut -c10-`; fi
if [ -z $PROFILE ]; then PROFILE=`echo $ASROOT|awk '{split($0,p,"/"); print p[6]}'`; fi

LOGDIR="/logs/was${VERSION}/${PROFILE}"
case $VERSION in
	61) LOGGING="-tracefile ${LOGDIR}/wsadmin.members-${CLUSTER}.traceout" ;;
	*) LOGGING="" ;;
esac
MEMBERS=$(su - $USER -c "$WSADMIN -conntype NONE $LOGGING -f ${JYDIR}/cluster.py -action members -cluster $CLUSTER|grep -v '^WASX'")
ACTION="-action modify"
ATTR="-attr plugin:$PLGPropMods"
for appsvr in $MEMBERS; do
	SERVER="-server $appsvr"
	nodename=$(echo $appsvr |awk '{split($0,n,"_");print n[1]}')
	NODE="-node $nodename"
	echo "---------------------------------------------------"
	echo " Updating $appsvr web server plugin properties..."
	echo " $WSADMIN -conntype NONE -f ${JYDIR}/server.py $ACTION $NODE $SERVER $ATTR"
	echo "---------------------------------------------------"
	case $VERSION in
		61) LOGGING="-tracefile ${LOGDIR}/wsadmin.editPluginProps-${appsvr}.traceout" ;;
		*) LOGGING="" ;;
	esac
	su - $USER -c "$WSADMIN -conntype NONE $LOGGING -f ${JYDIR}/server.py $ACTION $NODE $SERVER $ATTR|grep -v '^WASX'"
done