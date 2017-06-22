#!/bin/bash
# Manage WebSphere Environment Variables (wrapper for variable.py)
# Author:	James Walton <jfwalton@us.ibm.com>
# Date:		01 Sept 2010#
#
#   Change History: 
#     Lou Amodeo    03-01-2013  Add support for Websphere 8.5 
#
#   Usage: manageVariables.sh version={61|70|85} [profile=<profilename>] create scope=<type>:<name> <variablename>=<value> [<variablename2>=<value2> ...]
#          manageVariables.sh version={61|70|85} [profile=<profilename>] modify scope=<type>:<name> <variablename>=<value> [<variablename2>=<value2> ...]
#          manageVariables.sh version={61|70|85} [profile=<profilename>] delete scope=<type>:<name> <variablename> [<variablename2> ...]
#
#   Scope Types: cell, cluster, server, node

LIBDIR="/lfs/system/tools/was/lib"
USER=webinst
#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
    	create|modify|delete) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then ACT=$VALUE; fi ;;
		version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VERSION=$VALUE; fi ;;
		profile=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROFILE=$VALUE; fi ;;
    	scope=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SCOPE=$VALUE; fi ;;
		help) echo "Usage: 	manageVariables.sh version={61|70|85} [profile=<profilename>] create scope=<type>:<name> <variablename>=<value> [<variablename2>=<value2> ...]"
			echo "       	manageVariables.sh version={61|70|85} [profile=<profilename>] modify scope=<type>:<name> <variablename>=<value> [<variablename2>=<value2> ...]"
			echo "       	manageVariables.sh version={61|70|85} [profile=<profilename>] delete scope=<type>:<name> <variablename> [<variablename2> ...]"
			exit 0 ;;
		*)	if [ ${#ENVVARS} -eq 0 ]; then
				ENVVARS=$1
		    else
		    	ENVVARS="$ENVVARS $1"
			fi
			;;
	esac
	shift
done
ACTION="-action $ACT"
SCOPETYPE=${SCOPE%:*}
SCOPEARG="-$SCOPETYPE"
SCOPENAME=${SCOPE#*:}

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
else
	ASROOT=${wasList}
fi

if [ -z $PROFILE ]; then
	PROFILE=${ASROOT#*/profiles/}
fi

if [ -x $ASROOT/bin/wsadmin.sh ]; then
	WSADMIN="${ASROOT}/bin/wsadmin.sh"
	if [ `echo $PROFILE|grep Manager` ]; then
		WSPARAMS="-lang jython -conntype NONE"
	else
		WSPARAMS="-lang jython"
	fi
else
	echo "Failed to locate $ASROOT/bin/wsadmin.sh ... exiting"
	exit 1
fi
echo "-----------------------------------------------------------"
echo " Performing requested action(s)..."
echo " $ASROOT"
for enVar in $ENVVARS; do
	LOGFILE="/logs/was${VERSION}/${PROFILE}/wsadmin.${SCOPENAME}_${ACT}-variable.traceout"
	LOGGING="-tracefile $LOGFILE"
	IGNORE1="grep -v '^WASX73..I:'"
	IGNORE2="grep -v 'sys-package-mgr'"
	echo "-----------------------------------------------------------"
	echo " Log available at: $LOGFILE"
	echo "   wsadmin.sh $WSPARAMS -f ${LIBDIR}/variable.py $ACTION $SCOPEARG $SCOPENAME -var $enVar"
	echo "-----------------------------------------------------------"
	su - $USER -c "$WSADMIN $WSPARAMS $LOGGING -f ${LIBDIR}/variable.py $ACTION $SCOPEARG $SCOPENAME -var $enVar |$IGNORE1 |$IGNORE2"
done

