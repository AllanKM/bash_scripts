#!/bin/ksh

checkPubStatus() {
	LOGFILE=$1
	STATUSROOT=${2:-/projects/publish/}
	PUBSTATUS_CONF="/usr/local/etc/pubstatus.conf"

	date "+%T Checking Publishing Status"
	[ -r "${LOGFILE}" ] || print -u2 -- "#### Unable to read ${LOGFILE}. "
	[ -r "${PUBSTATUS_CONF}" ] || print -u2 -- "#### Unable to read ${PUBSTATUS_CONF}. "
	[ -r "${LOGFILE}" ] && \
	#gather received status files
	for i in $(awk '/pubstatus/ || /apps_status/ {print $5}'  ${LOGFILE} |sort -u |xargs echo ); do 
		[ -f ${STATUSROOT}/${i#/*/} ] && ls -lLi ${STATUSROOT}/${i#/*/} |awk '{print $NF,$0}'>>/tmp/$$~
	done
	#gather monitored files
	[ -r "${PUBSTATUS_CONF}" ] && \
		awk '!/^#/ {print $3}' ${PUBSTATUS_CONF} |xargs ls -ldi |awk '{print $NF,$0 }' >>/tmp/$$~~ || \
		print -u2 -- "##### No publishing status files being monitored"
	#display results
	cat /tmp/$$~  2>/dev/null |while read filespec inum  mode link own group size date time time2 file; do
		[ "${filespec}" == "${file}" ] && time="${time} ${time2}" # handles date with spaces
		grep -q "$inum" /tmp/$$~~ 2>/dev/null && print "Monitored\t$date $time $filespec" || print "\t\t$date $time $filespec"
	done
	cat /tmp/$$~~  2>/dev/null |while read filespec inum  mode link own group size date time time2 file; do
		[ "${filespec}" == "${file}" ] && time="${time} ${time2}" # handles date with spaces
		grep -q "$inum" /tmp/$$~~ 2>/dev/null && print "Monitored\t$date $time $filespec" || print "\t\t$date $time $filespec"
	done
#	cat /tmp/$$~ 
#	print -- "-----"
#	cat /tmp/$$~~
	rm /tmp/$$~ /tmp/$$~~ 2>/dev/null
}

checkbNimble() {
	date "+%T Checking bNimble"
	/lfs/system/tools/configtools/countprocs.sh 1 bNimble || print -u2 -- "##### bNimble not running"
}

checkDaedalus() {
        date "+%T Checking Daedalus"
	PROCS=`ps -eoargs= |awk '/di[k]ran/ {print $1,$NF}' | grep java`
	if echo $PROCS | grep -qi config ; then
        	print "$PROCS"
	else
       		 print -u2 -- "##### Daedalus not running"
        	exit 1
	fi

}


printQueues(){
# Prints the received lines prepended by blank or ### and to either stdout/stderr if the queues are backed up. 
	awk '/Target URL|\-\-\-\-/ {print "    ",$0}; 
	/http/ && ( $2 != "UP" || $NF != 0 ) {print "####",$0 | "cat 1>&2" };
	/http/ && ( $2 == "UP" && $NF == 0 ) {print "    ",$0   };' 

}

checkQueues() {

	if [ $# -eq 0 ]; then
		print -u2 -- "#### call checkQueues() with a list of queue urls to probe"
		RC=1
	else
		for URL in $* ; do

			if ps -eoargs= |awk '/b[Nn]imble/ {print $1,$NF}' |grep -q java ; then
				date "+%T Checking for backed-up endpoint Queues using $URL)"
				curl -s $URL | printQueues \
				|| print -u2 -- "#### Problem querying queue status using $URL"
				RC=$?
			else
				print -u2 -- "##### bNimble not running"
				RC=1
			fi
		done
	fi
	return $RC
}

checkStatus() {
	
	PUBTOOL2=/lfs/system/tools/bNimble/bin/pubtool2

	if [ $# -eq 0 ]; then
		print -u2 -- "#### call checkStatus() with a list of queue urls to probe"
		RC=1
	else
		for URL in $* ; do
					#Check to see if this argument is a keystore and not a URL
			echo $URL | grep kdb >/dev/null
			if [ $? -eq 0 ]; then
				KEYSTORE=$URL
			fi
			#Check to see if this argument is a stashfile and not a URL
			echo $URL | grep sth >/dev/null
			if [ $? -eq 0 ]; then
				STASH=$URL
			fi
			if  [[ "$KEYSTORE" != ""   &&   "$STASH" !=  "" ]] ; then
				CERTARG="-keyfile $KEYSTORE -stashfile $STASH"
			fi
			echo $URL | grep http >/dev/null
			if [ $? -eq 0 ]; then
				if ps -eoargs= |awk '/b[Nn]imble/ {print $1,$NF}' |grep -q java ; then
					date "+%T Checking Status of Distributor using $URL"
					$PUBTOOL2  -action status $CERTARG -distributor $URL | printQueues \
					|| print -u2 -- "#### Problem querying queue status using $URL"
					RC=$?
				else
					print -u2 -- "##### bNimble not running"
					RC=1
				fi
			fi
		done
	fi
	return $RC
	
	
}

