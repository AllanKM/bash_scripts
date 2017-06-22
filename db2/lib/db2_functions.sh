#!/bin/ksh

checkReplicationDB2() {

	DB=${1:-DB2}
	CAPTURE_STRING=${2:-none}
	APPLY_STRING=${3:-none}
	
	date "+%T Checking $DB replication"
	
	if [ "$CAPTURE_STRING" != "none" ]; then
		if ps -eoargs= | grep $CAPTURE_STRING ; then
			rc=0
		else
			print -u2 -- "####### $DB capture is not running"
			rc=1
		fi
	fi
	
	if [ "$APPLY_STRING" != "none" ]; then
		if ps -eoargs= | grep $APPLY_STRING ; then
			rc=0
		else
			print -u2 -- "####### Apply for $DB is not running"
			rc=1
		fi
	fi
}