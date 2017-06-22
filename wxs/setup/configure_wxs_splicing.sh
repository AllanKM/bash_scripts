#!/bin/bash
# Author: James Walton <jfwalton@us.ibm.com>
# Initial Revision: 05 Sep 2010
# Usage: configure_wxs_splicing.sh app=<application> file=</path/to/splicer.properties> [version=<61|70|85>] [profile=<name>]

getWasRoot() {
	i=0
	if [ -n "$VERSION" ] && [ -n "$PROFILE" ]; then
		#Use version and profile specified on command line
		wasList[$i]="/usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}"
		i=$(($i+1))
	elif [ -n "$VERSION" ] && [ -z "$PROFILE" ]; then
		#Use version specified, search for profiles
		DIR="/usr/WebSphere${VERSION}/AppServer"
		for profile in `ls ${DIR}/profiles/`; do
			wasList[$i]="${DIR}/profiles/${profile}"
			i=$(($i+1))
		done
	elif [ -z "$VERSION" ] && [ -n "$PROFILE" ]; then
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
		ASROOT=${wasList[$choice]}
	else
		ASROOT=${wasList}
	fi
	if [ -z "$VERSION" ]; then VERSION=`echo ${ASROOT#*/WebSphere}|cut -c1-2`; fi
	if [ -z "$PROFILE" ]; then PROFILE=${ASROOT#*/profiles/}; fi
}

#Set defaults
HOST=`/bin/hostname -s`
WXSLIB="/lfs/system/tools/wxs/lib"
USER=webinst

#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
		version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FULLVERSION=$VALUE; fi ;;
		profile=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROFILE=$VALUE; fi ;;
		app=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then APP=$VALUE; fi ;;
		file=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SPLICER=$VALUE; fi ;;
		*)	echo "#### Unknown argument: $1"
			echo "#### Usage: configure_wxs_splicing.sh app=<application> file=</path/to/splicer.properties> [version=<61|70>] [profile=<name>]"
			exit 1
			;;
	esac
	shift
done

getWasRoot $VERSION $PROFILE
echo "Using: $ASROOT"
CELL=$(grep WAS_CELL= ${ASROOT}/bin/setupCmdLine.sh|awk '{split($0,a,"WAS_CELL="); print a[2]}')
if [ -x ${ASROOT}/bin/wsadmin.sh ]; then
	WSADMIN="${ASROOT}/bin/wsadmin.sh"
	WSPARAMS="-conntype NONE -javaoption -Dcom.ibm.websphere.management.configservice.validatePropNames=false"
fi

echo "-----------------------------------------------------------"
echo " Configuring $APP specific cell custom property..."
echo " Using: $SPLICER"
echo "-----------------------------------------------------------"
#Check that application exists
if [ ! -d ${ASROOT}/config/cells/*/applications/*.ear/deployments/${APP} ]; then
	echo "#### ERROR: Application $APP does not exist."
	exit 1
fi
#Check that splicer file exists
if [ ! -f $SPLICER ]; then
	echo "#### ERROR: File $SPLICER does not exist."
	exit 1
fi
LOGFILE="/logs/was${VERSION}/${PROFILE}/wsadmin.${APP}_wxs-splicer.traceout"
LOGGING="-tracefile $LOGFILE"
IGNORE1="grep -v '^WASX73..I:'"
IGNORE2="grep -v 'sys-package-mgr'"
CELLPROP="${APP},com.ibm.websphere.xs.sessionFilterProps"
echo "-----------------------------------------------------------"
echo " Performing requested action..."
echo " Log available at: $LOGFILE"
echo "   wsadmin.sh $WSPARAMS -f ${WXSLIB}/cellprop.py $CELLPROP $SPLICER"
echo "-----------------------------------------------------------"
su - $USER -c "$WSADMIN $WSPARAMS $LOGGING -f ${WXSLIB}/cellprop.py $CELLPROP $SPLICER |$IGNORE1 |$IGNORE2"
