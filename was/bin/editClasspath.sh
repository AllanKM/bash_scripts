#!/bin/bash
#
# Edit WebSphere appserver classpaths
#    - Basically a wrapper for serverAction.jacl -action modify -server <blah> -attr classpath:.....
#
# Author:	James Walton
# Contact:	jfwalton@us.ibm.com
# Date:		15 Nov 2007
#
#   Usage: editClasspath.sh {61|70} <clustername> /path1 /path2 ... /pathN
#          editClasspath.sh {61|70} <clustername> removeall
#

USER=webinst
FULLVERSION=${1:-70023}
VERSION=`echo $FULLVERSION | cut -c1-2`
CLUSTER=$2
JYDIR=/lfs/system/tools/was/lib
shift; shift
case $1 in
	"removeall")
		CPATH="removeall"
	;;
	*)	CPATH="$1"
		shift
		until [ -z "$1" ]; do
			CPATH="$CPATH:$1"
			shift
		done
	;;
esac

# If not run from a DM node, exit
ISDM=`lssys -n -l role -x csv|grep -v '^#'|awk '{split($0,a,","); print a[2]}'|grep 'WAS\.DM\.'`
if [ -z $ISDM ]; then printf "!! Must be run from the cell DM node !!\n#### Update Failed...\n"; exit 1; fi

WASDIR="/usr/WebSphere${VERSION}/AppServer"

i=0
for profile in `ls ${WASDIR}/profiles/`; do
	wasList[$i]="${WASDIR}/profiles/${profile}"
	i=$(($i+1))
done
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
	PROFILE=$(echo ${wasList[$choice]} |awk '{split($0,profile,"/"); print profile[6]}')
	WSADMIN="${wasList[$choice]}/bin/wsadmin.sh"
else
	PROFILE=$(echo ${wasList} |awk '{split($0,profile,"/"); print profile[6]}')
	WSADMIN="${wasList}/bin/wsadmin.sh"
fi
LOGDIR="/logs/was${VERSION}/${PROFILE}"

if [ ! -x $WSADMIN ]; then
	echo "Failed to locate $WSADMIN ... exiting"
	exit 1
fi

LOGGING="-tracefile ${LOGDIR}/wsadmin.members-${CLUSTER}.traceout"
MEMBERS=$(su - $USER -c "$WSADMIN -conntype NONE $LOGGING -f ${JYDIR}/cluster.py -action members -cluster $CLUSTER 2>&1|grep -v 'WASX'|grep -v 'sys-package-mgr'")
ACTION="-action modify"
ATTR="-attr classpath:$CPATH"
for appsvr in $MEMBERS; do
	SERVER="-server $appsvr"
	nodename=$(echo $appsvr |awk '{split($0,n,"_");print n[1]}')
	NODE="-node $nodename"
	echo "---------------------------------------------------"
	echo " Updating $appsvr classpath..."
	echo " $WSADMIN  -conntype NONE -f ${JYDIR}/server.py $ACTION $NODE $SERVER $ATTR"
	echo "---------------------------------------------------"
	LOGGING="-tracefile ${LOGDIR}/wsadmin.editClasspath-${appsvr}.traceout"
	su - $USER -c "$WSADMIN -conntype NONE $LOGGING -f ${JYDIR}/server.py $ACTION $NODE $SERVER $ATTR 2>&1|grep -v 'WASX'|grep -v 'sys-package-mgr'"
done