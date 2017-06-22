#!/bin/bash
#
# Manage WebSphere core groups
#    - Basically a wrapper for coregroup.py
#
# Author:	James Walton
# Contact:	jfwalton@us.ibm.com
# Date:		25 Sept 2007
#
#   Change History: 
#     Lou Amodeo    03-01-2013  Add support for Websphere 8.5 
#
#
#   Usage: manageCoreGroup.sh {61|70|85} create <coregroupname> [profile]
#          manageCoreGroup.sh {61|70|85} moveCluster <clustername> <srcCoreGroup> <destCoreGroup> [profile]
#          manageCoreGroup.sh {61|70|85} moveServer <servername> <nodename> <srcCoreGroup> <destCoreGroup> [profile]
#          manageCoreGroup.sh {61|70|85} set-coordinators <coregroupname> <numCoordinators> [profile]
#          manageCoreGroup.sh {61|70|85} set-preferred <coregroupname> <comma-separated-list-appservers> [profile]

LIBDIR="/lfs/system/tools/was/lib"
USER=webinst
FULLVERSION=${1:-70023}
VERSION=`echo $FULLVERSION | cut -c1-2`

case $2 in
	"create") ACTION="-action create"
			COREGROUP=$3
			PROFILE=$4
		;;
	"moveServer")	ACTION="-action move"
				APPSRV=$3
				NODE=$4
				SRCCG=$5
				DSTCG=$6
				PROFILE=$7
		;;
	"moveCluster")	ACTION="-action move"
				CLUSTER=$3
				SRCCG=$4
				DSTCG=$5
				PROFILE=$6
		;;
	"set-coordinators") ACTION="-action modify"
			COREGROUP=$3
			SETCOORD="-attr coord:$4"
			PROFILE=$5
		;;
	"set-preferred") ACTION="-action modify"
			COREGROUP=$3
			SETCOORD="-attr pref:$4"
			PROFILE=$5
		;;
esac

case $VERSION in
	61|70|85)
		if [ "$PROFILE" == "" ]; then
			#Grab default profile
			defScript=/usr/WebSphere${VERSION}/AppServer/properties/fsdb/_was_profile_default/default.sh
			DEFPROFILE=$(grep setup $defScript|awk '{split($0,pwd,"WAS_USER_SCRIPT="); print pwd[2]}')
			PROFILE=$(echo $DEFPROFILE|awk '{split($0,profile,"/"); print profile[6]}')
			if [ "$PROFILE" == "" ]; then 
				echo "Failed to find Default Profile, exiting...."
				exit 1
			fi
		fi
		WASDIR="/usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}"
		;;
	*)
		echo "ERROR: Unsupported version of WebSphere provided"
		exit 1
		;;
esac

if [ -x $WASDIR/bin/wsadmin.sh ]; then
	WSADMIN=$WASDIR/bin/wsadmin.sh
else
	echo "Failed to locate $WAS_HOME/bin/wsadmin.sh ... exiting"
	exit 1
fi
echo "---------------------------------------------------"
echo " Performing requested action..."
echo " $WASDIR"
if [[ $COREGROUP != "" && $SETCOORD == "" ]]; then
	LOGGING="-tracefile /logs/was${VERSION}/${PROFILE}/wsadmin.${COREGROUP}.traceout"
	echo " wsadmin.sh -lang jython ${LOGGING} -f ${LIBDIR}/coregroup.py $ACTION -coregroup $COREGROUP"
	echo "---------------------------------------------------"
	su - $USER -c "$WSADMIN -lang jython ${LOGGING} -f ${LIBDIR}/coregroup.py $ACTION -coregroup $COREGROUP|grep -v '^WASX'|grep -v 'sys-package-mgr'"
elif [[ $COREGROUP != "" && $SETCOORD != "" ]]; then
	LOGGING="-tracefile /logs/was${VERSION}/${PROFILE}/wsadmin.mod_${COREGROUP}.traceout"
	echo " wsadmin.sh -lang jython ${LOGGING} -f ${LIBDIR}/coregroup.py $ACTION -coregroup $COREGROUP $SETCOORD"
	echo "---------------------------------------------------"
	su - $USER -c "$WSADMIN -lang jython ${LOGGING} -f ${LIBDIR}/coregroup.py $ACTION -coregroup $COREGROUP $SETCOORD|grep -v '^WASX'|grep -v 'sys-package-mgr'"
elif [ "$CLUSTER" != "" ]; then
	LOGGING="-tracefile /logs/was${VERSION}/${PROFILE}/wsadmin.${DSTCG}.traceout"
	echo " wsadmin.sh -lang jython ${LOGGING} -f ${LIBDIR}/coregroup.py $ACTION -cluster $CLUSTER -src $SRCCG -dest $DSTCG"
	echo "---------------------------------------------------"
	su - $USER -c "$WSADMIN -lang jython ${LOGGING} -f ${LIBDIR}/coregroup.py $ACTION -cluster $CLUSTER -src $SRCCG -dest $DSTCG|grep -v '^WASX'|grep -v 'sys-package-mgr'"
elif [ "$APPSRV" != "" ]; then
	LOGGING="-tracefile /logs/was${VERSION}/${PROFILE}/wsadmin.${DSTCG}.traceout"
	echo " wsadmin.sh -lang jython ${LOGGING} -f ${LIBDIR}/coregroup.py $ACTION -server $APPSRV -node $NODE -src $SRCCG -dest $DSTCG"
	echo "---------------------------------------------------"
	su - $USER -c "$WSADMIN -lang jython ${LOGGING} -f ${LIBDIR}/coregroup.py $ACTION -server $APPSRV -node $NODE -src $SRCCG -dest $DSTCG|grep -v '^WASX'|grep -v 'sys-package-mgr'"
else
	echo " FAILED: No valid object (new coregroup name, appserver, or cluster) was provided to perform action ($ACTION)"
	exit 1
fi
