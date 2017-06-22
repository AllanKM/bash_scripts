#!/bin/bash
# Author: James Walton <jfwalton@us.ibm.com>
# Initial Revision: 04 Sep 2010
# Usage: configure_wxs_catalog.sh [version=<61|70|85>] [profile=<name>] cluster=<cluster> [clientport=<port>] [peerport=<port>]

getWasRoot() {
	i=0
	if [ -n "$VERSION" ] && [ -n "$PROFILE" ]; then
		#Use version and profile specified on command line
		wasList[$i]="/usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}"
		i=$(($i+1))
	elif [ -n "$VERSION" ] && [ -z "$PROFILE" ]; then
		#Use version specified, search for profiles
		DIR="/usr/WebSphere${VERSION}/AppServer"
		for profile in `ls ${DIR}/profiles/`; do
			wasList[$i]="${DIR}/profiles/${profile}"
			i=$(($i+1))
		done
	elif [ -z "$VERSION" ] && [ -n "$PROFILE" ]; then
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
		ASROOT=${wasList[$choice]}
	else
		ASROOT=${wasList}
	fi
	if [ -z "$VERSION" ]; then VERSION=`echo ${ASROOT#*/WebSphere}|cut -c1-2`; fi
	if [ -z "$PROFILE" ]; then PROFILE=${ASROOT#*/profiles/}; fi
}

parseServerInfo() {
	cNode=`echo $1 |awk '{split($0,s,","); print s[2]}'`
	cServ=`echo $1 |awk '{split($0,s,","); print s[3]}'`
	cPort=`echo $1 |awk '{split($0,s,","); print s[5]}'`
}

#Set defaults
HOST=`/bin/hostname -s`
WXSLIB="/lfs/system/tools/wxs/lib"
USER=webinst
CLIENTPORT=6600
PEERPORT=6601

#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
		version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FULLVERSION=$VALUE; fi ;;
    	profile=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROFILE=$VALUE; fi ;;
		cluster=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CLUSTER=$VALUE; fi ;;
		clientport=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CLIENTPORT=$VALUE; fi ;;
    	peerport=*)    VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PEERPORT=$VALUE; fi ;;
		*)	echo "#### Unknown argument: $1"
			echo "#### Usage: Usage: configure_wxs_catalog.sh [version=<61|70>] [profile=<name>] cluster=<cluster> [clientport=<port>] [peerport=<port>]"
			exit 1
			;;
	esac
	shift
done

getWasRoot $VERSION $PROFILE
echo "Using: $ASROOT"
CELL=$(grep WAS_CELL= ${ASROOT}/bin/setupCmdLine.sh|awk '{split($0,a,"WAS_CELL="); print a[2]}')
if [ -x ${ASROOT}/bin/wsadmin.sh ]; then
	WSADMIN="${ASROOT}/bin/wsadmin.sh"
	if [ `echo $PROFILE|grep Manager` ]; then
		WSPARAMS="-lang jython -conntype NONE"
	else
		WSPARAMS="-lang jython"
	fi
fi

#Parse cluster(s)
appstring=${CLUSTER#*cluster_}
serverList=`/lfs/system/tools/was/bin/portreport.sh |grep "_${appstring},BOOTSTRAP"`
CATALOGPROP=""
PROPOUTPUT=""
for appsrv in $serverList; do
	parseServerInfo $appsrv
	if [ -n "$CATALOGPROP" ]; then CATALOGPROP="${CATALOGPROP},"; PROPOUTPUT="${PROPOUTPUT},"; fi
	PROPOUTPUT="${PROPOUTPUT}${CELL}\\${cNode}\\${cServ}:${cNode}:${CLIENTPORT}:${PEERPORT}:${cPort}"
	#Need to swap \ for / to get Jython to process it properly, it will get swapped back
	CATALOGPROP="${CATALOGPROP}${CELL}/${cNode}/${cServ}:${cNode}:${CLIENTPORT}:${PEERPORT}:${cPort}"
done
echo "-----------------------------------------------------------"
echo " Generated custom property string:"
echo "   $PROPOUTPUT"
echo "-----------------------------------------------------------"
LOGFILE="/logs/was${VERSION}/${PROFILE}/wsadmin.${CELL}_wxs-catalog.traceout"
LOGGING="-tracefile $LOGFILE"
IGNORE1="grep -v '^WASX73..I:'"
IGNORE2="grep -v 'sys-package-mgr'"
echo "-----------------------------------------------------------"
echo " Performing requested action(s)..."
echo " Log available at: $LOGFILE"
echo "   wsadmin.sh $WSPARAMS -f ${WXSLIB}/cellprop.py catalog.services.cluster $CATALOGPROP"
echo "-----------------------------------------------------------"
su - $USER -c "$WSADMIN $WSPARAMS $LOGGING -f ${WXSLIB}/cellprop.py catalog.services.cluster $CATALOGPROP |$IGNORE1 |$IGNORE2"
