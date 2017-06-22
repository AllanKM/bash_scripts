#! /bin/ksh

######################################################################
#
#  sync_was_site_plugin_v2.sh - Script used to sync plugin-cfg.xml 
#            in a global webserver with vhosts and set 
#            up environment.
#
#---------------------------------------------------------------------
#
#  Todd Stephens - 05/27/2011 - Initial creation based on  
#                     sync_was_gloabl_plugin.sh script
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
DESTDIR=""
CUSTENV=""
STACK="distribute"

#process command-line options
until [ -z "$1" ] ; do
   case $1 in
      sitetag=*)     VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SITETAG=$VALUE; fi ;;
      env=*)         VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTENV=$VALUE; fi ;;
      stack=*)       VALUE=${1#*=}; if [ "$VALUE" != "" ]; then STACK=$VALUE; fi ;;
      toolsdir=*)    VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
      *)  print  -u2 -- "#### Unknown argument: $1"
          print  -u2 -- "#### Usage: ${0:##*/} [ sitetag = < Tag associated with website > ]"
          print  -u2 -- "####           [ env = < EI Environment site is located in > ]"
          print  -u2 -- "####           [ stack = < distribute or straight > ]"
          print  -u2 -- "####           [ toolsdir = < path to ihs scripts > ]"
          print  -u2 -- "#### ---------------------------------------------------------------------------"
          print  -u2 -- "####             Defaults:"
          print  -u2 -- "####               sitetag       = NODEFAULT"
          print  -u2 -- "####               env           = NODEFAULT"
          print  -u2 -- "####               stack         = distribute"
          print  -u2 -- "####               toolsdir      = /lfs/system/tools"
          exit 1
      ;;
   esac
   shift
done

echo "Checking if website has been built"
if [[ ! -d /projects/${SITETAG} ]]; then
   echo "   Website needs to be built before plugin is sync'd"
   echo 2
fi

echo "Checking if was_plugin is installed"
DESTDIR=`grep -i serverroot /fs/projects/sws/${CUSTENV}/${SITETAG}/conf/${SITETAG}.conf | awk '{print $NF}'`
PLUGIN=`grep -i "LoadModule.*was_ap.*_module" /fs/projects/sws/${CUSTENV}/${SITETAG}/conf/${SITETAG}.conf | awk '{print $NF}'`

#Based on whether the plugin path is absolute or relative check if its installed
POS1=`echo ${PLUGIN} | cut -c1`
if [[ ${POS1} == "/" ]]; then
   if [[ ! -f ${PLUGIN} ]]; then
      echo "   Could not find ${PLUGIN}"
      echo "   WAS Plugin code is not installed on this node, aborting"
      exit 2
   fi
else
   if [[ ! -f ${DESTDIR}/${PLUGIN} ]]; then
      echo "   Could not find ${DESTDIR}/${PLUGIN}"
      echo "   WAS Plugin code is not installed on this node, aborting"
      exit 2
   fi
fi 

# Set global base
GLOBAL_BASE="/fs/projects/sws/${CUSTENV}/${SITETAG}"

echo "Determine which plex we are in or what node we are on for suffix value"
if [[ ${STACK} = "straight" ]]; then
   SUFFIX=`hostname`
else
   SUFFIX=`${TOOLSDIR}/configtools/get_plex.sh`
fi

echo ""
echo "Sync Plugin Config"
${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/conf/ /projects/${SITETAG}/conf/ "avc --include=plugin-cfg*.xml.${SUFFIX} --exclude=*" 1 0

LS_COUNT=`ls -l /projects/${SITETAG}/conf/plugin-cfg*.xml.${SUFFIX}|wc -l`
if [[ $LS_COUNT -eq 1 ]]; then
   echo ""
   echo "Create appropriate symlink to the plex specific plugin config"
   PLUGIN_CONF=`ls -l /projects/${SITETAG}/conf/plugin-cfg*.xml.${SUFFIX}|awk {'print $NF'}`
   ln -sf $PLUGIN_CONF /projects/${SITETAG}/conf/plugin-cfg.xml
else
   echo ""
   echo "There is more than one plugin-cfg.xml available --- create symlink manually"
fi

echo ""
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
  echo ""
  if [[ -f ${TOOLSDIR}/was/etc/${keyStore}.kdb ]]; then
    echo "Copy appropriate keystore to localdisk"
    ${TOOLSDIR}/configtools/filesync ${TOOLSDIR}/was/etc/ /projects/${SITETAG}/key/ "avc --include=${keyStore}* --exclude=*" 1 0
  else
    echo "$keyStore does not exist in ${TOOLSDIR}/was/etc"
    echo "Get latest copy of lfs_tools"
  fi
fi

if [[ ! -d /logs/${SITETAG}/Plugins ]]; then
   echo "Create Plugins log dir"
   mkdir /logs/${SITETAG}/Plugins
fi

if [[ -f /etc/logrotate.d/http_plugin ]]; then
   if [[ `cat /etc/logrotate.d/http_plugin| grep $SITETAG/Plugins` == "" ]]; then
      echo ""
      echo "Add logrotate entry for site $SITETAG/Plugins"
      echo "/logs/${SITETAG}/Plugins/http_plugin.log" >> /etc/logrotate.d/http_plugin
      echo "{  daily" >> /etc/logrotate.d/http_plugin
      echo "   copytruncate" >> /etc/logrotate.d/http_plugin
      echo "   rotate 1" >> /etc/logrotate.d/http_plugin
      echo "   compress" >> /etc/logrotate.d/http_plugin
      echo "   missingok" >> /etc/logrotate.d/http_plugin
		if [ `uname` =   "Linux" ] ; then
		  echo   "   su webinst eiadm " >> /etc/logrotate.d/http_plugin
		fi
      echo "}" >> /etc/logrotate.d/http_plugin
      echo "" >> /etc/logrotate.d/http_plugin
   else
      echo ""
      echo "Logrotate entry for site $SITETAG already exist"
   fi
else
   echo ""
   echo "Add logrotate entry for site $SITETAG/Plugins"
   echo "/logs/${SITETAG}/Plugins/http_plugin.log" > /etc/logrotate.d/http_plugin
   echo "{  daily" >> /etc/logrotate.d/http_plugin
   echo "   copytruncate" >> /etc/logrotate.d/http_plugin
   echo "   rotate 1" >> /etc/logrotate.d/http_plugin
   echo "   compress" >> /etc/logrotate.d/http_plugin
   echo "   missingok" >> /etc/logrotate.d/http_plugin
	if [ `uname` =   "Linux" ] ; then
	  echo   "   su webinst eiadm " >> /etc/logrotate.d/http_plugin
  fi
   echo "}" >> /etc/logrotate.d/http_plugin
   echo "" >> /etc/logrotate.d/http_plugin
fi
