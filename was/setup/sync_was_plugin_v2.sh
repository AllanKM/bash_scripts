#! /bin/ksh

######################################################################
#
#  sync_was_plugin.sh - Script used to sync plugin-cfg.xml and set up
#            environment.
#
#---------------------------------------------------------------------
#
#  Todd Stephens - 8/29/2007 - Initial creation
#  Todd Stephens - 4/25/2008 - Remove the check for filesystem for 
#                     /projects but only check that the directory
#                     exist.
#  Todd Stephens - 05/28/2008 - Modified logic for finding global dirs
#                     and added logic to do straight down serving on
#                     stacked nodes
#  Lou Amodeo      05/15/2013   Initial WAS 8.5 tolerance
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
STACK=""

#process command-line options
until [ -z "$1" ] ; do
        case $1 in
                cluster=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTTAG=$VALUE; fi ;;
                env=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTENV=$VALUE; fi ;;
                stack=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then STACK=$VALUE; fi ;;
                toolsdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
                *)      print -u2 -- "#### Unknown argument: $1"
                        print -u2 -- "#### Usage: $0 [ cluster=< Cluster Name > ] [ env =< Environment for this install > ]"
                        print -u2 -- "####           [ stack=< distribute or straight > ]"
                        print -u2 -- "####           [ toolsdir=< location of ei local tools directory > ]"
                        exit 1
                        ;;
        esac
        shift
done

# Determine which standard to follow
if [[ -d /fs/${CUSTTAG} && ${CUSTENV} = "" ]]; then
   GLOBAL_BASE="/fs/${CUSTTAG}"
elif [[ -d /fs/projects/${CUSTENV}/${CUSTTAG} && ${CUSTENV} != "" ]]; then
   GLOBAL_BASE="/fs/projects/${CUSTENV}/${CUSTTAG}"
else
   echo "Can not find global master base directory"
   echo "Aborting was plugin sync"
   exit 1
fi

echo "Checking if was_plugin is installed"
IHSINSTALLROOT=`grep -i serverroot ${GLOBAL_BASE}/HTTPServer/conf/httpd.conf | awk '{print $NF}'`
PLUGIN=`grep -i "LoadModule.*was_ap.*_module" ${GLOBAL_BASE}/HTTPServer/conf/httpd.conf | awk '{print $NF}'`

#Based on whether the plugin path is absolute or relative check if its installed
POS1=`echo ${PLUGIN} | cut -c1`
if [[ ${POS1} == "/" ]]; then
   if [[ ! -f ${PLUGIN} ]]; then
    echo "   Could not find ${PLUGIN}"
    echo "   WAS Plugin code is not installed on this node, aborting"
    exit 2
   fi 
else
   if [[ ! -f ${IHSINSTALLROOT}/${PLUGIN} ]]; then
    echo "   Could not find ${IHSINSTALLROOT}/${PLUGIN}"
    echo "   WAS Plugin code is not installed on this node, aborting"
    exit 2
   fi 
fi 

echo "Checking if /projects exist"
if [[ ! -d /projects ]]; then
  echo "   /projects directory does not exist on this node, aborting"
  exit 2
fi

# Determine HTTP Dir
HTTPDIR=`echo ${DESTDIR} | cut -d"/" -f3`

if [[ ! -d /projects/${HTTPDIR} ]]; then
   # Create local global server dir
   mkdir /projects/${HTTPDIR}
fi

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

if [[ ! -d /logs/HTTPServer/Plugins ]]; then
   echo "Create Plugin logdir"
   mkdir /logs/HTTPServer/Plugins
fi

echo "Update logrotate stanza for the http_plugin.log"
if [[ -f /etc/logrotate.d/http_plugin ]]; then
   if [[ `cat /etc/logrotate.d/http_plugin| grep "/logs/HTTPServer/Plugins"` == "" ]]; then
      echo ""
      echo "Add logrotate entry for HTTPServer/Plugin"
      echo "/logs/HTTPServer/Plugins/http_plugin.log" >> /etc/logrotate.d/http_plugin
      echo "{  daily" >> /etc/logrotate.d/http_plugin
      echo "   copytruncate" >> /etc/logrotate.d/http_plugin
      echo "   rotate 1" >> /etc/logrotate.d/http_plugin
      echo "   compress" >> /etc/logrotate.d/http_plugin
      echo "   missingok" >> /etc/logrotate.d/http_plugin
         if [ `uname` =   "Linux " ] ; then
            echo   "   su webinst eiadm " >> /etc/logrotate.d/http_plugin
         fi
      echo "}" >> /etc/logrotate.d/http_plugin
      echo "" >> /etc/logrotate.d/http_plugin
   else
      echo ""
      echo "Logrotate entry HTTPServer/Plugins already exists"
   fi
else
   echo ""
   echo "Add logrotate entry for HTTPServer/Plugin"
   echo "/logs/HTTPServer/Plugins/http_plugin.log" >> /etc/logrotate.d/http_plugin
   echo "{  daily" >> /etc/logrotate.d/http_plugin
   echo "   copytruncate" >> /etc/logrotate.d/http_plugin
   echo "   rotate 1" >> /etc/logrotate.d/http_plugin
   echo "   compress" >> /etc/logrotate.d/http_plugin
   echo "   missingok" >> /etc/logrotate.d/http_plugin
      if [ `uname` =   "Linux " ] ; then
         echo   "   su webinst eiadm " >> /etc/logrotate.d/http_plugin
      fi
   echo "}" >> /etc/logrotate.d/http_plugin
   echo "" >> /etc/logrotate.d/http_plugin
fi
