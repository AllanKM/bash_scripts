#!/bin/bash
# Generate WAS capacity data continuously for live monitoring - Basically a wrapper for jvmmon.py
# Author:       James Walton
# Contact:      jfwalton@us.ibm.com
# Date:         05 April 2012
#
# Usage: was_monitor.sh [file=</path/to/outputfile.csv>] [cluster=<clustername>] [datasource=<dsname>] [data=memory|threads|all] [sleep=<seconds>] [csv=yes|no] [version=85|70] [role=<WAS.CUST.ENV>]
umask 002

# Load defaults
VERSION="70"
WASLIB="/lfs/system/tools/was/lib"
WASUTIL="-f ${WASLIB}/jvmmon.py"
CSVDIR="/tmp"
PLEX=`lssys -l realm -n | grep realm | sed 's/.*\.\(p.\)/\1/g'`
CLUSTER="${PLEX}_dc_wwsm_search3"
ROLE="WAS.VE.PRD"
DATA="all"
DATASOURCE=""

# Process optional command-line options
until [ -z "$1" ] ; do
    case $1 in
        version=*)	VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VERSION=$VALUE; fi ;;
        cluster=*)	VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CLUSTER=$VALUE; fi ;;
        datasource=*)	VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DATASOURCE=$VALUE; fi ;;
        data=*)		VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DATA=$VALUE; fi ;;
        role=*)		VALUE=${1#*=}; if [ "$VALUE" != "" ]; then ROLE=$VALUE; fi ;;
        file=*)		VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FILE=$VALUE; fi ;;
        sleep=*)	VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SLEEP=$VALUE; fi ;;
        csv=*)		VALUE=${1#*=}; if [ "$VALUE" == "yes" ]; then PARAMS="-csv"; fi ;;
        *)	echo "### Unknown argument: $1"
	        echo "### Usage: was_monitor.sh [file=</path/to/outputfile.csv>] [cluster=<clustername>] [datasource=<dsname>] [data=memory|threads|all] [sleep=<seconds>] [csv=yes|no] [version=61|70]"
            exit 1
            ;;
    esac
    shift
done

NODELIST=`lssys -qe role==${ROLE} realm==g.cs.${PLEX}`
if [[ -z $FILE ]]; then
	FILE="${CSVDIR}/${CLUSTER}_capdata.csv"
fi

# Make sure VERSION is 2-digit, set and check WebSphere binary directory
VERSION=`echo $VERSION | cut -c1-2`
WASDIR="/usr/WebSphere${VERSION}/AppServer"
if [[ -d $WASDIR ]]; then
    WSADMIN="${WASDIR}/bin/wsadmin.sh"
    if [[ ! -f $WSADMIN ]]; then
        echo "WebSphere directory not found for version $VERSION, exiting..."
        exit 1
    fi
    WSADMIN="$WSADMIN -lang jython"
else
    echo "WebSphere directory not found for version $VERSION, exiting..."
    exit 1
fi
LOGDIR="/logs/was${VERSION}"
LOG="-tracefile ${LOGDIR}/jvm_monitor_wsadmin.out"

echo "Populating server list for monitoring..."
SERVERLIST=`su - webinst -c "$WSADMIN -conntype NONE -f ${WASLIB}/cluster.py -action members -cluster $CLUSTER 2>&1|egrep -v '^WASX|sys-package-mgr' |xargs echo|tr ' ' ','"`

PARAMS="$PARAMS -server ${SERVERLIST}"
if [[ -n $DATASOURCE ]]; then PARAMS="$PARAMS -ds ${DATASOURCE}"; fi
if [[ -n $SLEEP ]]; then PARAMS="$PARAMS -sleep ${SLEEP}"; fi

# Find out what data to generate
case $DATA in
    memory)  PARAMS="$PARAMS memory";;
    threads) PARAMS="$PARAMS threads";;
    all) PARAMS="$PARAMS memory threads";;
    *) PARAMS="$PARAMS memory threads";;
esac

echo "Executing: $WSADMIN $LOG $WASUTIL $PARAMS"
if [[ $FILE != "STDOUT" ]]; then
    ## Yes, I used Perl to replace a simple grep | tee, but the piped bash commands cause some weird I/O confusion and the wsadmin script doesn't execute.
    ## Thanks go to jwing for the Perl suggestions
    su - webinst -c "$WSADMIN $LOG $WASUTIL $PARAMS 2>&1" |perl -e 'open (STDOUT, "| tee $ARGV[0]"); shift @ARGV; while (<>) { next if /(^WASX|sys-package-mgr)/; print $_;}' $FILE
    echo "The generated data has been saved to $FILE, which can be imported into Excel or Symphony."
    chmod 660 $FILE
    chgrp eiadm $FILE
else
    su - webinst -c "$WSADMIN $LOG $WASUTIL $PARAMS 2>&1" |egrep -v '^WASX|sys-package-mgr'
fi

