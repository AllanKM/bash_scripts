#!/bin/ksh
#---------------------------------------------------------------
# This script has been reduced to just looking for a dirlist.txt file
# and creating the directories located in that script

if [ -d /usr/HTTPServer ]; then
	IHSDIR="/usr/HTTPServer"
else
	echo "Failed to find IHS Install Directory:  /usr/HTTPServer"
	exit 1
fi

DIRLIST=none
EVENT=none
EVENTLONG=none
CUSTENV=none
CUSTTAG=none

#process command-line options
until [ -z "$1" ] ; do
	case $1 in
		event=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then EVENT=$VALUE; fi ;;
		eventshort=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then EVENT=$VALUE; fi ;;
		eventlong=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then EVENTLONG=$VALUE; fi ;;
		dirlist=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DIRLIST=$VALUE; fi ;;
		custenv=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTENV=$VALUE; fi ;;	
		custtag=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTTAG=$VALUE; fi ;;
		*) 	print -u2 -- "#### Unknown argument: $1" 
			print -u2 -- "#### Usage: $0 [ dirlist=<full path to dirlist.txt file> ]"
			exit 1
			;;
        esac
        shift
done

echo "Checking for active http processes"
/lfs/system/tools/configtools/countprocs.sh 2 httpd 
if [ $? -eq 0 ]; then
	echo "Stopping IHS"
	/etc/apachctl stop
	sleep 3 
fi

id pubinst > /dev/null 2>&1
if [  $? -ne 0 ]; then
    /fs/system/tools/auth/bin/mkeiuser -r local -f pubinst apps
fi

if [ -f $DIRLIST ]; then
	DIRLIST="/fs/${EVENT}/config/dirlist.txt"
elif [ -f /fs/${EVENT}/config/dirlist.txt ]; then
	DIRLIST="/fs/${EVENT}/config/dirlist.txt"
elif [ -f /fs/${CUSTTAG}/${CUSTENV}/config/dirlist.txt ]; then
	DIRLIST="/fs/${CUSTTAG}/${CUSTENV}/config/dirlist.txt"
elif [ -f /fs/projects/${CUSTENV}/${CUSTTAG}/config/dirlist.txt ]; then
	DIRLIST="/fs/projects/${CUSTENV}/${CUSTTAG}/config/dirlist.txt"
fi

if [ "$DIRLIST" != "" ]; then
	echo "Creating directories for $EVENT using $DIRLIST"
	cat $DIRLIST | /lfs/system/tools/configtools/create_directories
fi
