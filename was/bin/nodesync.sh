#!/bin/bash
#
# Synchronize WebSphere nodes
#    - Basically a wrapper for node.py
#
# Author:	James Walton
# Contact:	jfwalton@us.ibm.com
# Date:		07 Sept 2007
#
#   Usage: nodesync.sh {85|70|61} [sync|refresh [profile]]
#
#---------------------------------------------------------------------------------
#
# Change History: 
#
#  Lou Amodeo     03-12-2013  Add support for WebSphere V8.5
#
#
#---------------------------------------------------------------------------------
#
JYDIR="/lfs/system/tools/was/lib"
USER=webinst
FULLVERSION=${1:-70023}
VERSION=`echo $FULLVERSION | cut -c1-2`
PROFILE=$3

if [ "$PROFILE" == "" ]; then
	#Grab default profile
	defScript=/usr/WebSphere${VERSION}/AppServer/properties/fsdb/_was_profile_default/default.sh
	DEFPROFILE=$(grep setup $defScript|awk '{split($0,pwd,"WAS_USER_SCRIPT="); print pwd[2]}')
	WASNODE=$(grep WAS_NODE= $DEFPROFILE|awk '{split($0,pwd,"WAS_NODE="); print pwd[2]}')
	PROFILE=$(echo $DEFPROFILE|awk '{split($0,profile,"/"); print profile[6]}')
	if [ "$PROFILE" == "" ]; then 
		echo "Failed to find Profile for post install configuration"
		echo "exiting...."
		exit 1
	elif [ "$(echo $PROFILE|grep Manager)" ]; then
		echo "ERROR: You can't sync a Deployment Manager, it is the master configuration repository."
		exit 1
	fi
fi
WASDIR="/usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}"

case $2 in
	"refresh") ACTION="-action refresh" ;;
	*)	ACTION="-action sync" ;;
esac
NODE="-node $WASNODE"

if [ -x $WASDIR/bin/wsadmin.sh ]; then
	WSADMIN="$WASDIR/bin/wsadmin.sh -lang jython"
else
	echo "Failed to locate $WASDIR/bin/wsadmin.sh ... exiting"
	exit 1
fi
echo "---------------------------------------------------"
echo " Performing requested action..."
echo " $WASDIR"
echo " wsadmin.sh -f ${JYDIR}/node.py $ACTION $NODE"
echo "---------------------------------------------------"
LOGGING="-tracefile /logs/was${VERSION}/${PROFILE}/wsadmin.nodesync.traceout"
su - $USER -c "$WSADMIN $LOGGING -f ${JYDIR}/node.py $ACTION $NODE -type nodeagent|grep -v '^WASX'|grep -v '^\*sys-package'"