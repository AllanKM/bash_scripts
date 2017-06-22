#!/bin/bash
# Author: James Walton <jfwalton@us.ibm.com>
# Initial Revision: 23 Sep 2010
# Usage: spliceapp.sh [version=<61|70|85>] ear=</path/to/file.ear> file=</path/to/splicer.properties>

getWasDir() {
	i=0
	if [ -n "$VERSION" ]; then
		#Use version specified on command line
		wasList[$i]="/usr/WebSphere${VERSION}/AppServer"
		i=$(($i+1))
	else
		#Populate version list
		DIRLIST=`ls -d /usr/WebSphere*/AppServer`
		for DIR in $DIRLIST; do
			wasList[$i]=$DIR
			i=$(($i+1))
		done
	fi
	if [ $i -gt 1 ]; then
		echo "WebSphere environments:"
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
}

#Set defaults
HOST=`/bin/hostname -s`
DATE=`date +"%Y%m%d"`

#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
		version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FULLVERSION=$VALUE; fi ;;
		ear=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then EARFILE=$VALUE; fi ;;
    	file=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SPLICER=$VALUE; fi ;;
		*)	echo "#### Unknown argument: $1"
			echo "#### Usage: spliceapp.sh [version=<61|70>] ear=</path/to/file.ear> file=</path/to/splicer.properties>"
			exit 1
			;;
	esac
	shift
done

getWasDir $VERSION
echo "Using: $ASROOT"

#Check that EAR exists
if [ ! -f $EARFILE ]; then
	echo "#### ERROR: Application EAR $EARFILE does not exist."
	exit 1
fi
#Check that splicer file exists
if [ ! -f $SPLICER ]; then
	echo "#### ERROR: File $SPLICER does not exist."
	exit 1
fi
#Make backup of EAR
cp -p $EARFILE ${EARFILE}.bak-${DATE}
echo "-----------------------------------------------------------"
echo " Modifying $EARFILE with WXS grid session filters..."
echo " Using: $SPLICER"
echo " Backup of EAR: ${EARFILE}.bak-${DATE}"
echo "-----------------------------------------------------------"
cd ${ASROOT}/optionalLibraries/ObjectGrid/session/bin
./addObjectGridFilter.sh $EARFILE $SPLICER

#Set permissions on EAR
if [ -z $SUDO_USER ]; then
        chown $USER $EARFILE
else
        chown $SUDO_USER $EARFILE
fi
chmod 664 $EARFILE
