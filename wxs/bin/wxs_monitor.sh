#!/bin/bash
WXSDIR=`ls -d /usr/WebSphere/eXtremeScale* |tail -1`
CSV=0
interval=300
until [ -z "$1" ] ; do
    case $1 in
		"-csv")	CSV=1 ;;
		[0-9]*)	interval=$1 ;;
	esac
	shift
done

if [ $CSV -eq 1 ]; then
	echo "date,time,srvname,heapmax,heapalloc,heapfree,orbmax,orbfree,orbused"
else
	printf "%-20s\t%-20s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\n" "Date" "WXS" "Heap" "Heap" "Heap" "ORB" "ORB" "ORB"
	printf "%-20s\t%-20s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\n" "Time" "Server" "Max" "Alloc" "Free" "Max" "Free" "Used"
	echo "==============================================================================================="
fi

if [ ! -d /tmp/wxsmon ]; then mkdir /tmp/wxsmon; fi
while :; do
	pidlist=`ps -ef |grep eXtremeScale|grep -v grep|awk '{print $2}'`
	for wxspid in $pidlist; do
		kill -3 $wxspid
		DATE=`date +"%Y%m%d.%H%M"`
		# Pause here, make sure javacore is created
		sleep 1
		javacore=`ls ${WXSDIR}/javacore.${DATE}*.${wxspid}.*.txt`
		jcfile=${javacore##*/}
		mv $javacore /tmp/wxsmon/
		javacore="/tmp/wxsmon/$jcfile"
		heapFreeHEX=`grep 1STHEAPFREE $javacore |awk '{print $7}'`
		heapAllocHEX=`grep 1STHEAPALLOC $javacore |awk '{print $7}'`
		heapfree=$(((0x${heapFreeHEX})/1024/1024))
		heapalloc=$(((0x${heapAllocHEX})/1024/1024))
		heapMax=`ps -ef |grep $wxspid |grep -v grep |awk '{split($0,h,"Xmx"); split(h[2],m," "); print m[1]}'`
		orbMax=`grep 3XMTHREADINFO $javacore |grep OGORB |wc -l |awk '{print $1}'`
		orbFree=`grep 3XMTHREADINFO $javacore |grep OGORB |grep 'state:P' |wc -l |awk '{print $1}'`
		orbUsed=$(($orbMax - $orbFree))
		srvName=`grep 2CIUSERARG $javacore |grep Initialization |awk '{print $3}'`
		rm $javacore
		
		#output data
		if [ $CSV -eq 1 ]; then
			pDATE=`date +"%Y-%m-%d,%H:%M:%S"`
			echo "$pDATE,$srvname,$heapMax,$heapalloc,$heapfree,$orbMax,$orbFree,$orbUsed"
		else
			pDATE=`date +"%Y-%m-%d %H:%M:%S"`
			printf "%-20s\t%-20s\t%5s\t%5s\t%5s\t%5s\t%5s\t%5s\n" "$pDATE" $srvName $heapMax $heapalloc $heapfree $orbMax $orbFree $orbUsed
		fi
	done
	sleep $interval
done