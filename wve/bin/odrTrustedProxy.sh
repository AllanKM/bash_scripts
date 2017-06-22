#!/bin/bash
# Usage: odrTrustedProxy.sh action=act plex=plex/env proxy=ip/fqhostname [version=wasversion] [profile=wasprofile]
# Author: James Walton <jfwalton@us.ibm.com>	2012-03-29

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
		WSADMIN="${ASROOT}/bin/wsadmin.sh"
	else
		ASROOT=${wasList}
		WSADMIN="${ASROOT}/bin/wsadmin.sh"
	fi
}

##---- Start Main ----##
USER=webinst
WVELIB=/lfs/system/tools/wve/lib
WASLIB=/lfs/system/tools/was/lib
# Process command-line options
until [ -z "$1" ] ; do
    case $1 in
		version=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VERSION=$VALUE; fi ;;
		profile=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROFILE=$VALUE; fi ;;
    	action=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then ACTION=$VALUE; fi ;;
    	plex=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PLEX=$VALUE; fi ;;
		proxy=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROXY=$VALUE; fi ;;
		*) echo "odrTrustedProxy.sh action=<add|remove> plex=<p1|p2|p3|pre|cdt> proxy=ip/fqhostname [version=wasversion] [profile=wasprofile]"
			exit 0 ;;
	esac
	shift
done
selectWasDir

if [ ! -f $WSADMIN ]; then
	echo "Failed to locate $WSADMIN ... exiting"
	exit 1
fi
su - $USER -c "$WSADMIN -f ${WVELIB}/odrtrust.py $ACTION $PLEX $PROXY |grep -v '^WASX[0-9][0-9][0-9][0-9]I:'|grep -v sys-package"
