#!/bin/ksh

###################################################################
#
# sync_httpserver_v2.sh -- This script performs all the steps to 
#                            sync the global webserver.  It also 
#                            creates the appropriate symlinks
#
#------------------------------------------------------------------
#
#  Todd Stephens - 06/17/12 - This is a clean up function
#  Todd Stephens - 04/16/12 - Setting this up for the new ihs7 
#                                 standards
#
###################################################################

# Verify script is called via sudo or ran as root
if [[ $SUDO_USER == "" && $USER != "root" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "********       Script sync_httpserver_v2.sh needs        ********"
   echo "********              to be ran with sudo                ********"
   echo "********                   or as root                    ********"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

# Set umask"
umask 002

# Set default values
CLUSTER=""
CUSTENV=""
DESTDIR="/projects/HTTPServer"
TOOLSDIR=/lfs/system/tools

# Process command-line options
until [ -z "$1" ] ; do
   case $1 in
      cluster=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CLUSTER=$VALUE; fi ;;
      env=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTENV=$VALUE; fi ;;
      root=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DESTDIR=$VALUE; fi ;;
      toolsdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
      *)  print -u2 -- "#### Unknown argument: $1"
          print -u2 -- "#### Usage: ${0:##*/}"
          print -u2 -- "####           cluster=< label for the ihs cluster >" 
          print -u2 -- "####           env=< environment for this install >"
          print -u2 -- "####           [ root=< directory where you want to install global configs in >" 
          print -u2 -- "####           [ toolsdir=< path to  ei local tools ]"
          print -u2 -- "#### ---------------------------------------------------
------------------------"
          print  -u2 -- "####             Defaults:"
          print  -u2 -- "####               cluster     = NODEFAULT"
          print  -u2 -- "####               env         = NODEFAULT"
          print  -u2 -- "####               root        = /projects/HTTPServer"
          print  -u2 -- "####               toolsdir    = /lfs/system/tools" 
          exit 1
      ;;
   esac
   shift
done

if [[ $CLUSTER == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Must specify a cluster"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $CUSTENV == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Must specify an Environment for this server "
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [ ! -d $TOOLSDIR ]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Tools Directory $TOOLSDIR does not exist"
   echo "      on this node"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

case `uname` in
   AIX) PLATFORM="aix" ;;
   Linux) 
      uname -a | grep ppc
      if [[ "$?" -eq 0 ]]; then
         PLATFORM="linuxppc"
      else
         PLATFORM="linux"
      fi
   ;;
   *)
      echo ""
      echo "/////////////////////////////////////////////////////////////////"
      echo"  `uname` not supported by this install script."
      echo "/////////////////////////////////////////////////////////////////"
      echo ""
      return 2
   ;;
esac

# Determine if global master exist
if [ -d /fs/projects/${CUSTENV}/${CLUSTER} ]; then
   GLOBAL_BASE="/fs/projects/${CUSTENV}/${CLUSTER}"
else
   echo "Can not find global master base directory"
   echo "Aborting httpserver sync"
   exit 1
fi

echo "Checking if IHS is installed"
IHSINSTALLROOT=`grep -i serverroot ${GLOBAL_BASE}/HTTPServer/conf/httpd.conf | awk '{print $NF}'`
if [[ ! -f ${IHSINSTALLROOT}/bin/httpd ]]; then
   echo "   IHS code is not installed at $IHSINSTALLROOT"
   echo "   on this node, aborting"
   exit 2
fi

echo "Checking if /projects exist"
if [[ ! -d /projects ]]; then
   echo "   /projects does not exist on this node, aborting"
   exit 2
fi

# Determine GLOBAL Dir
GLOBALDIR=`echo ${DESTDIR} | cut -d"/" -f3`

if [[ ! -d /projects/${GLOBALDIR} ]]; then
   # Create local global server dir
   mkdir /projects/${GLOBALDIR}
fi

echo "Sync'ing global server directories"
echo ""
echo "   bin dir ...."
${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/HTTPServer/bin/ /projects/${GLOBALDIR}/bin/ "avc --exclude=RCS" 1 1

if [ -d ${GLOBAL_BASE}/HTTPServer/lib ]; then 
   echo ""
   echo "   lib dir ...."
   ${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/HTTPServer/lib/ /projects/${GLOBALDIR}/lib/ "avc --exclude=RCS" 1 1
fi

echo ""
echo "   config dir ...."
${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/HTTPServer/conf/ /projects/${GLOBALDIR}/conf/ "avc --exclude=RCS --exclude=plugin-cfg*.xml* --exclude=kht-httpd.conf" 1 1

if [ -d ${GLOBAL_BASE}/HTTPServer/etc/ ]; then
   echo ""
   echo "   etc dir ...."
   ${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/HTTPServer/etc/ /projects/${GLOBALDIR}/etc/ "avc --exclude=RCS" 1 0
fi

if [ -d ${GLOBAL_BASE}/HTTPServer/key ]; then
   echo ""
   echo "   key dir ...."
   ${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/HTTPServer/key/ /projects/${GLOBALDIR}/key/ "avc --exclude=RCS" 1 0
fi

echo ""
echo "   modules dir ...."
if [ -d ${GLOBAL_BASE}/HTTPServer/modules/$PLATFORM ]; then
   ${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/HTTPServer/modules/${PLATFORM}/ /projects/${GLOBALDIR}/modules/ "avc --exclude=RCS" 1 1
else
   ${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/HTTPServer/modules/ /projects/${GLOBALDIR}/modules/ "avc --exclude=RCS" 1 1
fi
 
echo ""
echo "   content dir ...."
${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/HTTPServer/content/ /projects/${GLOBALDIR}/content/ "avc --exclude=RCS --exclude=site.txt --exclude=sslsite.txt" 1 1

echo ""
if [ ! -f /projects/${GLOBALDIR}/content/site.txt ]; then
   # Call the site.txt creation script
   ${TOOLSDIR}/ihs/setup/mksitetxt_apps_v2.ksh sitetag=${GLOBALDIR} name=${GLOBALDIR}
fi

if [ ! -d /logs/$GLOBALDIR ]; then
   echo "Setup Global Webserver log directory"
   mkdir /logs/$GLOBALDIR
   echo ""
fi

echo "Create symlink from /projects/ihscluster to the shared global directory"
echo "for the webserver cluster"
case `uname` in
   AIX)
      ln -sf $GLOBAL_BASE /projects/ihscluster
   ;;
   Linux)
      ln -sfn $GLOBAL_BASE /projects/ihscluster
   ;;
esac

echo "Set the IHS version flag"
IHS_LEVEL=`echo ${IHSINSTALLROOT} | cut -c 16,17`
if [[ $IHS_LEVEL == "" ]]; then
   IHS_LEVEL="61"
fi
if [ -f /projects/${GLOBALDIR}/.ihs_level_* ]; then
   rm /projects/${GLOBALDIR}/.ihs_level_*
fi
touch /projects/${GLOBALDIR}/.ihs_level_$IHS_LEVEL

echo "Set the IHS install dir flag"
if [ -f /projects/${GLOBALDIR}/.HTTPServer* ]; then
   rm /projects/${GLOBALDIR}/.HTTPServer*
fi
HTTPDIR=`echo ${IHSINSTALLROOT} | cut -d"/" -f3`
touch /projects/${GLOBALDIR}/.${HTTPDIR}
