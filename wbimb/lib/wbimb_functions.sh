#!/bin/ksh

minutesAgo() {
	
	timenow=$(date +%H:%M)
	min=${timenow##*:}	
	hr=${timenow%%:*}
	mintoday=$((hr*60+min))
	agomintoday=$(($mintoday - $1))
	agomin=$(($agomintoday % 60))
	[ $agomin -lt 10 ] && agomin="0${agomin}"
	agohr=$(($agomintoday / 60))
	[ $agohr -lt 10 ] && agohr="0${agohr}"
	print "$agohr:$agomin"
}

checkPaging() {
#	set -x
	threshhold=40
	date "+%T Checking Paging Space"
	case $(uname) in 
		AIX) set -- `/usr/sbin/lsps -s |tail -1 ` ;;
		Linux) set -- `/sbin/swapon -s | awk '/partition/ {totsize=+$3;totused=+$4}; END {printf "%dMB %d%%\n",totsize/1024+.5,totused/totsize*100+0.5}'` ;;
		*) print -u2 "Cannot establish paging space in $(uname)."
	esac
	if [ ${2%%\%} -gt $threshhold ] ; then
		print -u2 "#### Paging space usage is $2 which is above $threshhold%"
	else
		print -u1 "\tPaging space usage is $2 which is below $threshhold%"
	fi	
}

checkXIN() {
#	set -x
	socketCheck=/lfs/system/tools/configtools/socketCheck.pl
	XINhost=localhost
	XINport=8000
	minutes=${1:-2}
	file=/logs/xin/debug.log
	regex="Topic\=events\/hpods\/test"
	role="WBIMB.EVENTS.BROKER"
	begin=$((minutes -1)); 
	end=-1
	#build a regez of all the minutes in the interval from now-minutes till now+nextMinute
	unset j
	i=${begin}
	while [ ${i} -ge ${end} ]; do
		j="${j}|$(minutesAgo ${i}):"
		i=$((${i}-1))
	done
	timespec=${j#?}

	date "+%T Checking XIN procs"
	ps -fu mqm |uniq -c | grep DataFlowEngine || print -u2 -- "#### Missing XIN DataFlowEngine process"

	date "+%T Checking XIN receipt of application-level pings in the last $minutes minutes."
	tail -10000 $file | awk '/'$regex'/ {printf "\tMessage to events/hpods/test topic sent on %s was received at %s\n",$NF,$3}' | egrep "($timespec)" || print -u2 -- "#### Cannot find XIN application-level ping on $file for the last ${minutes} minutes." 
	date "+%T Checking XIN daemon accepting connections."
	if [ -x ${socketCheck} ] ; then
		exec ${socketCheck} -h ${XINhost} -p ${XINport} 2>&1 | grep -q OK && print "\tXIN daemon on ${XINhost} port ${XINport} is responsive." || print -u2 -- "##### Cannot connect to ${XINhost} port ${XINport}."
	else
		print -u2 -- "##### Can't find external utility $socketCheck. Unable to verify XIN daemon receptivity."
	fi
}