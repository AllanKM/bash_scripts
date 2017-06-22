#!/bin/bash
# Pulls WAS configuration data for comparison
# Author:	James Walton <jfwalton@us.ibm.com>
# Date:		02 Mar 2010
# Usage:    get_cmp_data.sh [version=<60|61>] [profile=<profilename] [dir=<store-datafile-here>] [delete=<yes|no>]

function getEnvVars {
	#WebSphere environment variables
	su - $USER -c "$WSADMIN -f $WASLIB env |$IGNORE"
}

function getJdbcCfg {
	#JDBC Providers and Data sources
	su - $USER -c "$WSADMIN -f $WASLIB jdbcprv |$IGNORE"
	su - $USER -c "$WSADMIN -f $WASLIB jdbcds |$IGNORE"
}

function getJvmCfg {
	#Heap sizes
	#Web container thread pools
	#M2M settings
	#Classpath
	#Custom properties (may have to filter/ignore ITCAM entries)
	#Generic arguments (may have to filter/ignore ITCAM entries)
	su - $USER -c "$WSADMIN -f $WASLIB jvm |$IGNORE"
}

function getMailCfg {
	#Mail Sessions
	su - $USER -c "$WSADMIN -f $WASLIB mail |$IGNORE"
}

function getMQCfg {
	#MQ Connection factories and Queues
	su - $USER -c "$WSADMIN -f $WASLIB mqcf |$IGNORE"
	su - $USER -c "$WSADMIN -f $WASLIB mqq |$IGNORE"
}

function getPorts {
	#Pull each node's list of appserver ports (WC, SOAP, Bootstrap)
	CFGROOT=${ASROOT}/config/cells/${CELL}
	siFiles=`find $CFGROOT -type f -name "serverindex.xml"`
	for si in $siFiles; do
		portList=`/lfs/system/tools/was/lib/getPorts.py $si`
		for port in $portList; do
			#strip out the cell name, and replace delimiter , with |
			pData=`echo $port |sed -e "s/${CELL},//g" |sed -e "s/,/|/g"`
			echo "PORT|$pData"
		done
	done
}

function getSharedLibs {
	#Shared Library names and values
	su - $USER -c "$WSADMIN -f $WASLIB libs |$IGNORE"
}

function selectWasDir {
	i=0
	if [ "$VERSION" != "" ] && [ "$PROFILE" != "" ]; then
		#Use version and profile specified on command line
		wasList[$i]="/usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}"
		i=$(($i+1))
	elif [ "$VERSION" != "" ] && [ "$PROFILE" == "" ]; then
		#Use version specified, search for profiles
		DIR="/usr/WebSphere${VERSION}/AppServer"
		for profile in `ls ${DIR}/profiles/`; do
			wasList[$i]="${DIR}/profiles/${profile}"
			i=$(($i+1))
		done
	elif [ "$VERSION" == "" ] && [ "$PROFILE" != "" ]; then
		#Search for profile given
		DIRLIST=`ls -d /usr/WebSphere*/AppServer/profiles/* | grep $PROFILE`
		for DIR in $DIRLIST; do
			wasList[$i]=$DIR
			i=$(($i+1))
		done
	else
		#No version/profile
		DIRLIST=`find /usr/WebSphere* -type d -name 'AppServer' ! -name . -prune`
		for DIR in $DIRLIST; do
			for profile in `ls ${DIR}/profiles/`; do
				wasList[$i]="${DIR}/profiles/${profile}"
				i=$(($i+1))
			done
		done
	fi
	
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
		ASROOT=${wasList[$choice]}
		WSADMIN="${ASROOT}/bin/wsadmin.sh -lang jython -conntype NONE"
	else
		ASROOT=${wasList}
		WSADMIN="${ASROOT}/bin/wsadmin.sh -lang jython -conntype NONE"
	fi
}
##---- Start Main ----##
USER=webinst
IGNORE="grep -v '^WASX73..I\:'"
DELETE="no"
DATE=`date +'%Y%m%d'`
WASLIB=/lfs/system/tools/was/lib/getCmpData.py
DATAPATH=/tmp
#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
		version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VERSION=$VALUE; fi ;;
		profile=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROFILE=$VALUE; fi ;;
	    dir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DATAPATH=$VALUE; fi ;;
	    delete=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DELETE=$VALUE; fi ;;
		*) echo "Usage:  get_cmp_data.sh [version=<60|61>] [profile=<profilename] [dir=<store-datafile-here>] [delete=<yes|no>]"
			exit 1 ;;
	esac
	shift
done

#Search and select WAS directories, then setup data file.
selectWasDir
PROFILE=`echo $ASROOT|awk '{split($0,p,"/"); print p[6]}'`
CELL=`ls ${ASROOT}/config/cells |grep -v plugin`
DATAFILE="${DATAPATH}/${CELL}_${PROFILE}_${DATE}.cfg"

if [[ -f $DATAFILE && $DELETE != "yes" ]]; then
	printf "Data file $DATAFILE already exists and will be overwritten. Continue? (y/n) "
	read choice
	if [[ $choice == "n" ]]; then
		echo "Exiting. Move/rename existing data file before proceeding."
		exit 1
	fi
fi

#Pull configuration data
echo "Gathering JVM configs..."
getJvmCfg > $DATAFILE
echo "Gathering JDBC configs..."
getJdbcCfg >> $DATAFILE
echo "Gathering MQ configs..."
getMQCfg >> $DATAFILE
echo "Gathering Mail configs..."
getMailCfg >> $DATAFILE
echo "Gathering Library configs..."
getSharedLibs >> $DATAFILE
echo "Gathering Environment variables..."
getEnvVars >> $DATAFILE
echo "Gathering Server ports..."
getPorts >> $DATAFILE
echo "Done!"
echo "Data file generated: $DATAFILE"
