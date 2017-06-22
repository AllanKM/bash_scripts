#!/bin/bash
#
# Pull relevant status information for m2m from WAS logs
#
# Author:	James Walton
# Contact:	jfwalton@us.ibm.com
# Initial Revision Date:	27 Jan 2009
#
#   Usage: m2m_status.sh [60|61] [all|ODR|<app>] [PROFILE]
#          m2m_status.sh [all|ODR|<app>] [60|61] [PROFILE]
USER=webinst
HOST=`hostname`

case $1 in
	60|61|70)	VERSION=$1
			APPCHECK=${2:-all}
		;;
	*)	APPCHECK=$1
		VERSION=${2:-70}
		;;
esac
PROFILE=$3
if [[ -n $PROFILE ]]; then
	LOGDIR="/logs/was${VERSION}/${PROFILE}"
else
	LOGDIR="/logs/was${VERSION}/${HOST}"
fi

case $APPCHECK in
	"all") # Checking all current appservers (running appservers, logs are rolled nightly), get a list
		APPLIST=`find ${LOGDIR}/${HOST}* -type d -mtime 1|awk '{split($0,dirs,"/"); print dirs[5]}'`
		;;
	"ODR") # Checking all current appservers (running appservers, logs are rolled nightly), get a list
		APPLIST=`find ${LOGDIR}/*ODR* -type d -mtime 1|awk '{split($0,dirs,"/"); print dirs[5]}'`
		;;
	*)	# Checking appserver(s) based on string match
		APPLIST=`find ${LOGDIR}/${HOST}*${APPCHECK}* -type d -mtime 1|awk '{split($0,dirs,"/"); print dirs[5]}'`
		;;
esac

printf "Checking m2m status...\n"
for app in $APPLIST; do
	# Search for m2m cluster status message
	dcsStatus=`grep DCSV8050I ${LOGDIR}/${app}/SystemOut.log|grep cluster|tail -1`
	if [[ -n $dcsStatus ]]; then
		timestamp=`echo $dcsStatus |awk '{print $1" "$2" "$3}'`
		identifier=`echo $dcsStatus |awk '{split($18,a,","); print a[1]}'`
		viewCounts=`echo $dcsStatus |awk '{print $23" "$24" "$25" "$26}'`
		echo "  ## $timestamp $identifier $viewCounts $app"
	fi
done
echo "### Done."
printf "\nChecking for HAMgr failures...\n"
for app in $APPLIST; do
	# Search for HAMgr broken status messages
	hmgrStatus=`grep HMGR0142E ${LOGDIR}/${app}/SystemOut.log|tail -1`
	if [[ -n $hmgrStatus ]]; then
		ebizStatus=`grep 'e-business' ${LOGDIR}/${app}/SystemOut.log|tail -1`
		hmgrTime=`echo $hmgrStatus |awk '{print $1" "$2" "$3}'`
		if [[ -n $ebizStatus ]]; then
			ebizTime=`echo $ebizStatus |awk '{print $1" "$2" "$3}'`
			printf "  ## HAMgr Failure: $hmgrTime $app\n"
			printf "  ## App restarted: $ebizTime $app\n\n"
		else
			printf "  ## HAMgr Failure: $hmgrTime $app\n"
			printf "  ## App restarted: <none> $app\n\n"
		fi
	fi
done
echo "### Done."
