#!/bin/bash
# Generate WAS Capacity Data - Basically a wrapper for jvmStats.py
# Author:	James Walton
# Contact:	jfwalton@us.ibm.com
# Date:		27 Aug 2009
#
# Usage: genCapacityData.sh version=<70|61> file=</path/to/outputfile.csv> [node=<nodename>] [server=<servername>] [dataSources] [j2c] data=[memory|threads|all]
#        genCapacityData.sh version=<70|61> file=</path/to/outputfile.csv> [node=<nodename>] [dataSources] [j2c] data=[memory|threads|all]
#        genCapacityData.sh version=<70|61> file=</path/to/outputfile.csv> [cluster=<clustername>] [dataSources] [j2c] data=[memory|threads|all]
#        genCapacityData.sh version=<70|61> file=</path/to/outputfile.csv> [cell [filter=<stringmatch>]] [dataSources] [j2c] data=[memory|threads|all]

umask 002
WASLIB="/lfs/system/tools/was/lib"
#process command-line options
until [ -z "$1" ] ; do
    case $1 in
		version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VERSION=$VALUE; fi ;;
		node=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then NODE=$VALUE; fi ;;
		server=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SERVER=$VALUE; fi ;;
		cluster=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CLUSTER=$VALUE; fi ;;
	    filter=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FILTER=$VALUE; fi ;;
        data=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DATA=$VALUE; fi ;;	  
	    file=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FILE=$VALUE; fi ;;
		cell)  CELL=$1;;
		dataSources) DATASOURCES="true";;
		j2c) J2C="true";;
		*)	echo "#### Unknown argument: $1"
            echo "#### Usage: genCapacityData.sh version=<70|61> file=</path/to/outputfile.csv> [node=<nodename>] [server=<servername>] [dataSources] [j2c] data=[memory|threads|all]"
            echo "####        genCapacityData.sh version=<70|61> file=</path/to/outputfile.csv> [node=<nodename>] [dataSources] [j2c] data=[memory|threads|all]"
            echo "####        genCapacityData.sh version=<70|61> file=</path/to/outputfile.csv> [cluster=<clustername>] [dataSources] [j2c] data=[memory|threads|all]"
            echo "####        genCapacityData.sh version=<70|61> file=</path/to/outputfile.csv> [cell [filter=<stringmatch>]] [dataSources] [j2c] data=[memory|threads|all]"
			exit 1
			;;
	esac
	shift
done

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
	echo "Found WebSphere${VERSION} wsadmin.sh..."
else
	echo "WebSphere directory not found for version $VERSION, exiting..."
	exit 1
fi

WASUTIL="-f ${WASLIB}/jvmStats.py"

#Comma separated format is not supported with DataSource or J2C information

if [[ -n "$DATASOURCES" ]]; then
    echo "Found -dataSources -- generating DataSource information..."
    PARAMS="$PARAMS -dataSources"
fi

if [[ -n "$J2C" ]]; then
    echo "Found -j2c -- generating J2C Connection information..."
    PARAMS="$PARAMS -j2c"
fi

if [ -n "$DATASOURCES" -o -n "$J2C" ]; then
    CSV=""
else
    CSV="true"
    PARAMS="-csv"
fi

# Heirarchy of parameters for processing cell > cluster > server (+/-node) > node
# Filter only applies to limiting full cell output, node is last due to its ability to help constrain servers.
if [[ -n $CELL ]]; then
	echo "Found scope: cell -- ignoring any cluster/server/node parameters..."
	PARAMS="$PARAMS -cell"
	if [[ -n $FILTER ]]; then
		echo "Found scope filter($FILTER), limiting output to matches..."
		PARAMS="$PARAMS -filter $FILTER"
	fi
elif [[ -n $CLUSTER ]]; then
	echo "Found scope: cluster($CLUSTER) -- ignoring any server/node parameters..."
	PARAMS="$PARAMS -cluster $CLUSTER"
elif [[ -n $SERVER ]]; then
	if [[ -n $NODE ]]; then
		echo "Found scope: server($SERVER), node($NODE) ..."
		PARAMS="$PARAMS -node $NODE -server $SERVER"
	else
		echo "Found scope: server($SERVER) ..."
		PARAMS="$PARAMS -server $SERVER"
	fi
elif [[ -n $NODE ]]; then
	echo "Found scope: node($NODE) ..."
	PARAMS="$PARAMS -node $NODE"
fi

# Find out what data to generate
case $DATA in
	memory)  PARAMS="$PARAMS memory";;
	threads) PARAMS="$PARAMS threads";;
	all) PARAMS="$PARAMS memory threads";;
	*)	echo "#### Unknown data request: $DATA"
        echo "#### Data types:"
        echo "####      memory   JVM memory heap statistics"
        echo "####     threads   JVM web container and ORB thread pool statistics"
        echo "####         all   Both memory and thread statistics"
		exit 1
		;;
esac

if [[ $FILE != "STDOUT" ]]; then
	echo "Executing: su - webinst -c \"$WSADMIN $WASUTIL $PARAMS > $FILE\""
	su - webinst -c "$WSADMIN $WASUTIL $PARAMS |grep -v '^WASX' > $FILE"
	if [[ -n $CSV ]]; then
	    echo "The generated data has been saved in $FILE, which can be imported into Excel or Symphony."
	else
	    echo "The generated data has been saved in $FILE."
	fi
	chmod 660 $FILE
	chgrp eiadm $FILE
else
	echo "Executing: su - webinst -c \"$WSADMIN $WASUTIL $PARAMS\""
	su - webinst -c "$WSADMIN $WASUTIL $PARAMS |grep -v '^WASX'"
fi	