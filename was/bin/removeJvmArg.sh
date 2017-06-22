#!/bin/bash
#
# Edit WebSphere appserver classpaths
#    - Basically a wrapper for removeHeapArg.py
#
# Author:	James Walton
# Contact:	jfwalton@us.ibm.com
# Date:		10 Mar 2010
#
#   Usage: removeJvmArg.sh {60|61} <clustername> Xmx|Xms

USER=webinst
FULLVERSION=${1:-61025}
VERSION=`echo $FULLVERSION | cut -c1-2`
WASDIR="/usr/WebSphere${VERSION}/AppServer"
CLUSTER=$2
LIBDIR=/lfs/system/tools/was/lib
ARG=$3

# If not run from a DM node, exit
ISDM=`lssys -n -l role -x csv|grep -v '^#'|awk '{split($0,a,","); print a[2]}'|grep 'WAS\.DM\.'`
if [ -z $ISDM ]; then printf "!! Must be run from the cell DM node !!\n#### Update Failed...\n"; exit 1; fi

case $VERSION in
	60|61)
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
			WSADMIN="${wasList[$choice]}/bin/wsadmin.sh -lang jython"
		else
			PROFILE=$(echo ${wasList} |awk '{split($0,profile,"/"); print profile[6]}')
			WSADMIN="${wasList}/bin/wsadmin.sh -lang jython"
		fi
		LOGDIR="/logs/was${VERSION}/${PROFILE}"
		;;
	*) 
		echo "Unsupported version."
		exit 1 ;;
esac

if [ ! -x $WASDIR/bin/wsadmin.sh ]; then
	echo "Failed to locate $WASDIR/bin/wsadmin.sh ... exiting"
	exit 1
fi

case $VERSION in
	61) LOGGING="-tracefile ${LOGDIR}/wsadmin.members-${CLUSTER}.traceout" ;;
	*) LOGGING="" ;;
esac
MEMBERS=$(su - $USER -c "$WSADMIN -conntype NONE $LOGGING -f ${LIBDIR}/cluster.py -action members -cluster $CLUSTER|grep -v '^WASX'")
for appsvr in $MEMBERS; do
	nodename=$(echo $appsvr |awk '{split($0,n,"_");print n[1]}')
	echo "---------------------------------------------------"
	echo " Updating $appsvr classpath..."
	echo " $WSADMIN -conntype NONE -f ${LIBDIR}/removeHeapArg.py $nodename $appsvr $ARG"
	echo "---------------------------------------------------"
	case $VERSION in
		61) LOGGING="-tracefile ${LOGDIR}/wsadmin.removeHeapArg-${appsvr}.traceout" ;;
		*) LOGGING="" ;;
	esac
	su - $USER -c "$WSADMIN -conntype NONE $LOGGING -f ${LIBDIR}/removeHeapArg.py $nodename $appsvr $ARG|grep -v '^WASX'"
done