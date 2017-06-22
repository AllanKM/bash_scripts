#!/bin/bash
# Manage Shared Libraries - A wrapper for sharedlib.py
# 2013-04-14 | James Walton <jfwalton@us.ibm.com>
# 
# Usage: managelib.sh add|replace|clear|show lib=<libname> [cp="/class/path;/values/here.jar"] [scope=(cell|cluster:<name>|node:<name>)] [version=61|70] [profile=<name>]

VERSION="85"
WASLIB="/lfs/system/tools/was/lib"
WASUTIL="${WASLIB}/sharedlib.py"

# Process command-line opts
until [ -z "$1" ] ; do
    case $1 in
		version=*)	VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VERSION=$VALUE; fi ;;
		profile=*)	VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROFILE=$VALUE; fi ;;
		scope=*)	SCOPE=$1 ;;
		lib=*)	SLIBRARY=$1 ;;
		cp=*)	CPATH=$1 ;;
		*)	LIBACTION=$1 ;;
    esac
    shift
done

# Make sure VERSION is 2-digit, set and get WebSphere profile directory
VERSION=`echo $VERSION | cut -c1-2`
${WASLIB}/getWasDir.sh | tee /tmp/getWasDir.out
ASROOT=`cat /tmp/getWasDir.out |tail -1 |awk '{print $2}'`
rm /tmp/getWasDir.out
WSADMIN="${ASROOT}/bin/wsadmin.sh"
if [[ ! -f $WSADMIN ]]; then
    echo "ERROR: WebSphere directory or wsadmin.sh not found for version $VERSION, exiting..."; exit 1
fi
LOGDIR="/logs/was${VERSION}"
LOG="${LOGDIR}/sharedlib_${LIBACTION}_wsadmin.out"
echo "*******************************************************************************************"
echo "* Profile  : $ASROOT"
echo "* Log file : $LOG"
echo "* wsadmin  : $WASUTIL $PARAMS"
echo "*******************************************************************************************"
su - webinst -c "$WSADMIN -tracefile $LOG -f $WASUTIL $LIBACTION $SLIBRARY $SCOPE $CPATH 2>&1 |egrep -v '^WASX|sys-package-mgr'"
