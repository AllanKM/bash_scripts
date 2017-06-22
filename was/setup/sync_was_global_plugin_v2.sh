#! /bin/ksh

######################################################################
#
#  sync_was_global_plugin_v2.sh - Script used to sync plugin-cfg.xml 
#            in a global webserver with vhosts and set 
#            up environment.
#
#---------------------------------------------------------------------
#
#  Todd Stephens - 05/27/2011 - Initial creation based on old 
#                     sync_was_plugin.sh script
#
######################################################################

# Set umask
umask 002

# Default Values
keyStore=""
KEYSTORE_YZ=ei_yz_plugin
KEYSTORE_GZ=ei_gz_plugin
KEYSTORE_BZ=ei_bz_plugin
TOOLSDIR=/lfs/system/tools
DESTDIR=/usr/HTTPServer
CUSTENV=""
STACK="distribute"

#process command-line options
until [ -z "$1" ] ; do
   case $1 in
      custtag=*)     VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTTAG=$VALUE; fi ;;
      env=*)         VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTENV=$VALUE; fi ;;
      stack=*)       VALUE=${1#*=}; if [ "$VALUE" != "" ]; then STACK=$VALUE; fi ;;
      serverroot=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DESTDIR=$VALUE; fi ;;
      toolsdir=*)    VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
      *)  print  -u2 -- "#### Unknown argument: $1"
          print  -u2 -- "#### Usage: ${0:##*/} [ serverroot = < IHS install root directory > ]"
          print  -u2 -- "####           [ custtag = < Tag associated with customer > ]"
          print  -u2 -- "####           [ env = < EI Environment site is located in > ]"
          print  -u2 -- "####           [ stack=< distribute or straight > ]"
          print  -u2 -- "####           [ toolsdir = < path to ihs scripts > ]"
          print  -u2 -- "#### ---------------------------------------------------------------------------"
          print  -u2 -- "####             Defaults:"
          print  -u2 -- "####               serverroot    = /usr/HTTPServer"
          print  -u2 -- "####               custtag       = NODEFAULT"
          print  -u2 -- "####               env           = NODEFAULT"
          print  -u2 -- "####               stack         = distribute"
          print  -u2 -- "####               toolsdir      = /lfs/system/tools"
          exit 1
      ;;
   esac
   shift
done

echo "Checking if cluster has been built"
HTTPDIR=`echo ${DESTDIR} | cut -d"/" -f3`
if [[ ! -d /projects/${HTTPDIR} ]]; then
   echo "   Cluster needs to be built before plugin is sync'd"
   echo 2
fi

echo "Checking if was_plugin is installed"
if [[ ! -d ${DESTDIR}/Plugins ]]; then
  echo "   WAS Plugin code is not installed on this node, aborting"
  exit 2
fi 

echo "Checking if /projects exist"
if [[ ! -d /projects ]]; then
  echo "   /projects directory does not exist on this node, aborting"
  exit 2
fi

# Set global base
GLOBAL_BASE="/fs/projects/${CUSTENV}/${CUSTTAG}"

echo "Determine which plex we are in or what node we are on for suffix value"
if [[ ${STACK} = "straight" ]]; then
   SUFFIX=`hostname`
else
   SUFFIX=`${TOOLSDIR}/configtools/get_plex.sh`
fi

echo "Sync plugin-cfg.xml"
${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/HTTPServer/conf/ /projects/${HTTPDIR}/conf/ "avc --include=plugin-cfg*.xml.${SUFFIX} --exclude=*" 1 0

LS_COUNT=`ls -l /projects/${HTTPDIR}/conf/plugin-cfg*.xml.${SUFFIX}|wc -l`
if [[ $LS_COUNT -eq 1 ]]; then
   echo "Create appropriate symlink to the plex specific plugin config"
   PLUGIN_CONF=`ls -l /projects/${HTTPDIR}/conf/plugin-cfg*.xml.${SUFFIX}|awk {'print $NF'}`
   ln -sf $PLUGIN_CONF /projects/${HTTPDIR}/conf/plugin-cfg.xml
else
   echo "There is more than one plugin-cfg.xml available --- create symlink manually"
fi

echo "Determine zone we are in to determine which plugin keyring to use"
ZONE=`grep realm /usr/local/etc/nodecache|tail -n 1|awk '{split($3,zone,".");print zone [1]}'`
case $ZONE in
                y)      keyStore=$KEYSTORE_YZ
                echo "   plugin to be configured with EI YZ keystore..." ;;
                g)      keyStore=$KEYSTORE_GZ
                echo "   plugin to be configured with EI GZ keystore..." ;;
                b)      keyStore=$KEYSTORE_BZ
                echo "   plugin to be configured with EI BZ keystore..." ;;
                *) echo "   Error: Unrecognized realm [$zone] found when determining zone keystore." ;;
esac

if [[ $keyStore != "" ]]; then
  if [[ -f ${TOOLSDIR}/was/etc/${keyStore}.kdb ]]; then
    echo "Copy appropriate keystore to localdisk"
    ${TOOLSDIR}/configtools/filesync ${TOOLSDIR}/was/etc/ /projects/${HTTPDIR}/etc/ "avc --include=${keyStore}* --exclude=*" 1 0
  else
    echo "$keyStore does not exist in ${TOOLSDIR}/was/etc"
    echo "Get latest copy of lfs_tools"
  fi
fi

echo "Update logrotate stanza for the http_plugin.log"
${TOOLSDIR}/configtools/filesync ${TOOLSDIR}/was/conf/http_plugin /etc/logrotate.d/ "avc" 0 0
