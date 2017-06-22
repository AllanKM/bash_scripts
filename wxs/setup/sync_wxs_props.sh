#! /bin/ksh
###########################################################################
#  sync_wxs_props.sh - Script used to sync WXS server properties
#-------------------------------------------------------------------------
#  James Walton - 8/04/2011 - Initial creation, based on sync_was_plugin.sh
#  Lou Amodeo   - 9/23/2014 - Create symbolic link if plex specific splicer
#                             property file is present.
###########################################################################

# Set umask
umask 002

# Default Values
TOOLSDIR=/lfs/system/tools
CUSTENV=""
CUSTTAG=""
PROPS="all"

#process command-line options
until [ -z "$1" ] ; do
	case $1 in
		cust=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTTAG=$VALUE; fi ;;
		env=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTENV=$VALUE; fi ;;
		toolsdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
		props=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROPS=$VALUE; fi ;;
		--no-dry-run) export EI_FILESYNC_NODR=1 ;;
		*)  print -u2 -- "#### Unknown argument: $1"
			print -u2 -- "#### Usage: $0 [ cust=< label given the customer > ] [ env =< Environment for this install > ]"
			print -u2 -- "####          [ toolsdir=< location of ei local tools directory > ] [ props =<grid|client|catalog>]"
			exit 1
			;;
	esac
	shift
done

echo "Checking if WXS is installed"
if [ "$(find /usr/WebSphere*/eXtremeScale* -name license.xs)" == "" ] && [ "$(find /usr/WebSphere*/AppServer -name license.xs)" == "" ]; then
	echo "   WXS not installed on this node, aborting"
	exit 2
fi

echo "Checking if WXS properties directory exists"
if [ ! -d /projects/wxs/properties ]; then
	mkdir -p /projects/wxs/properties
fi 

GLOBAL_BASE="/fs/projects/${CUSTENV}/${CUSTTAG}"

echo "Determine which plex we are in"
SUFFIX=`${TOOLSDIR}/configtools/get_plex.sh`

if [[ $PROPS == "catalog" || $PROPS == "all" ]]; then
	echo "Sync wxs_catalog.properties"
	${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/wxs/properties/ /projects/wxs/properties/ "avc --include=wxs_catalog.properties.${SUFFIX} --exclude=*" 1 0
	echo "Creating symlink to the plex specific wxs_catalog.properties"
	ln -sf /projects/wxs/properties/wxs_catalog.properties.${SUFFIX} /projects/wxs/properties/wxs_catalog.properties
fi
if [[ $PROPS == "client" || $PROPS == "all" ]]; then
	echo "Sync objectGridClient.properties"
	${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/wxs/properties/ /projects/wxs/properties/ "avc --include=objectGridClient.properties.${SUFFIX} --exclude=*" 1 0
	echo "Creating symlink to the plex specific objectGridClient.properties"
	ln -sf /projects/wxs/properties/objectGridClient.properties.${SUFFIX} /projects/wxs/properties/objectGridClient.properties
fi
if [[ $PROPS == "grid" || $PROPS == "all" ]]; then
	echo "Sync *_grid.properties"
	${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/wxs/properties/ /projects/wxs/properties/ "avc --include=*_grid.properties.${SUFFIX} --exclude=*" 1 0
	echo "Creating symlink(s) to the plex specific *_grid.properties file(s)"
	for gridPropFile in `ls /projects/wxs/properties/*_grid.properties.${SUFFIX}`; do
		linkName=${gridPropFile##*/}
		linkName=${linkName%.${SUFFIX}}
		ln -sf $gridPropFile /projects/wxs/properties/$linkName 
	done
	echo "Sync any optional WXS server conf files"
	${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/wxs/properties/ /projects/wxs/properties/ "avc --include=*.conf --exclude=*" 1 0
fi
if [[ $PROPS == "splicer" || $PROPS == "all" ]]; then
	echo "Sync *_splicer.properties"
	${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/wxs/properties/ /projects/wxs/properties/ "avc --include=*_splicer.properties --include=*_splicer.properties.${SUFFIX} --exclude=*" 1 0
	echo "Creating symlink(s) to the plex specific *_splicer.properties file(s) if found"
    for splicerPropFile in `ls /projects/wxs/properties/*_splicer.properties.${SUFFIX} 2>/dev/null`; do
        linkName=${splicerPropFile##*/}
        linkName=${linkName%.${SUFFIX}}
        ln -sf $splicerPropFile /projects/wxs/properties/$linkName 
    done
fi

echo "Setting permissions"
chown -R root.eiadm /projects/wxs/properties
chmod 664 /projects/wxs/properties/*.properties*
