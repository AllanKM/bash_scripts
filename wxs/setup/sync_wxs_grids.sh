#! /bin/ksh
###########################################################################
#  sync_wxs_grids.sh - Script used to sync WXS grid xml
#-------------------------------------------------------------------------
#  James Walton - 8/4/2011 - Initial creation, based on sync_was_plugin.sh
###########################################################################

# Set umask
umask 002

# Default Values
TOOLSDIR=/lfs/system/tools
CUSTENV=""
CUSTTAG=""

#process command-line options
until [ -z "$1" ] ; do
	case $1 in
		cust=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTTAG=$VALUE; fi ;;
		env=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTENV=$VALUE; fi ;;
		toolsdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
		--no-dry-run) export EI_FILESYNC_NODR=1 ;;
		*)  print -u2 -- "#### Unknown argument: $1"
			print -u2 -- "#### Usage: $0 [ cust=< label given the customer > ] [ env =< Environment for this install > ]"
			print -u2 -- "####          [ toolsdir=< location of ei local tools directory > ]"
			exit 1
			;;
	esac
	shift
done

echo "Checking if WXS is installed"
if [[ "$(find /usr/WebSphere*/eXtremeScale* -name license.xs)" == "" ]]; then
	echo "   WXS stand-alone not installed on this node, aborting"
	exit 2
fi

echo "Checking if WXS grid directory exists"
if [[ ! -d /projects/wxs/grids ]]; then
	mkdir -p /projects/wxs/grids
fi 

GLOBAL_BASE="/fs/projects/${CUSTENV}/${CUSTTAG}"
echo "Sync grid xml files"
${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/wxs/grids/ /projects/wxs/grids/ "avc --include=*.xml --exclude=*" 1 0

echo "Setting permissions"
chown -R root.eiadm /projects/wxs/grids
chmod 664 /projects/wxs/grids/*.xml
