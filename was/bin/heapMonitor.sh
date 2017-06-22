#!/bin/bash
#
# Script to be executed via Tivoli to monitor heap size utilization.
#    - Basically a wrapper for heapMonitor.py
#
# Author:	James Walton
# Contact:	jfwalton@us.ibm.com
# Date:		17 July 2009
#
#   Usage: heapMonitor.sh {70|61} <server> [profile]

LIBDIR="/lfs/system/tools/was/lib"
USER=webinst
FULLVERSION=${1:-70023}
VERSION=`echo $FULLVERSION | cut -c1-2`
SERVER=$2
PROFILE=$3

if [ "$PROFILE" == "" ]; then
	#Grab default profile
	defScript=/usr/WebSphere${VERSION}/AppServer/properties/fsdb/_was_profile_default/default.sh
	DEFPROFILE=$(grep setup $defScript|awk '{split($0,pwd,"WAS_USER_SCRIPT="); print pwd[2]}')
	WASNODE=$(grep WAS_NODE= $DEFPROFILE|awk '{split($0,pwd,"WAS_NODE="); print pwd[2]}')
	PROFILE=$(echo $DEFPROFILE|awk '{split($0,profile,"/"); print profile[6]}')
	if [ "$PROFILE" == "" ]; then 
		echo "Failed to find a valid WAS profile, exiting...."
		exit 1
	fi
else
	PROFENV=/usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}/bin/setupCmdLine.sh
	WASNODE=$(grep WAS_NODE= $PROFENV|awk '{split($0,pwd,"WAS_NODE="); print pwd[2]}')
fi
WASDIR="/usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}"

if [ -x $WASDIR/bin/wsadmin.sh ]; then
	WSADMIN="$WASDIR/bin/wsadmin.sh -lang jython"
else
	echo "Failed to locate $WASDIR/bin/wsadmin.sh ... exiting"
	exit 1
fi

# Versions 6.0 and older didn't support -tracefile, they are gone, so now "Everybody gets a tracefile!"
LOGGING="-tracefile /logs/was${VERSION}/${PROFILE}/wsadmin.heapMonitor-${SERVER}.traceout"
SOAPPORT=`/lfs/system/tools/was/bin/portreport.sh 70 |grep ${WASNODE} |grep ${SERVER} |grep SOAP |awk '{split($0,p,","); print p[5]}'`
su - $USER -c "$WSADMIN -host $WASNODE -port $SOAPPORT $LOGGING -f ${LIBDIR}/heapMonitor.py $WASNODE $SERVER|grep -v '^WASX'|grep -v '^\*sys-package'"