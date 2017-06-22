#!/bin/bash
#---------------------------------------------------------------------------
# Uninstall WebSphere Application Server 8.5.x.x HTTP Plugin (run as sudo)  
#---------------------------------------------------------------------------
#
# USAGE: remove_plugin_v3.sh  was_version=<version> [ wasinstnum=<instance> ]
#
#---------------------------------------------------------------
#
#  Change History: 
#
#  Lou Amodeo - 04/11/2013 - Initial creation
#  Lou Amodeo - 05/10/2013 - Add revised directory structure
#  Lou Amodeo - 12/12/2013 - change rmfs to /fs/system/bin/eirmfs
#
#---------------------------------------------------------------
#
#Verify script is called via sudo
if [[ $SUDO_USER == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "********** Script remove_plugin_v3.sh needs              ********"
   echo "**********         to be run with sudo                   ********"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

FULLVERSION="85000"
INSTANCE=""
EXTENSION=""

# Process command-line options
until [[ -z "$1" ]] ; do
   case $1 in
      was_version=*)    VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FULLVERSION=$VALUE; fi ;;
      wasinstnum=*)     VALUE=${1#*=}; if [ "$VALUE" != "" ]; then INSTANCE=$VALUE;    fi ;;
      *)  echo "#### Unknown argument: $1"
          echo "#### Usage: ${0}"
          echo "####           was_version=< desired WAS Plugin version >"         
          echo "####           [ wasinstnum=< instance number of the desired WAS Plugin version > ]"
          echo "#### ---------------------------------------------------------------------------"
          echo "####             Defaults:"
          echo "####               was_version   = 85000"
          echo "####               wasinstnum    = NULL"
          echo "####             Notes:"
          echo "####               1) wasinstnum is used to remove a specific"
          echo "####                  instance when multiple WAS plugins were installed"
          exit 1
      ;;
   esac
   shift
done

VERSION=`echo $FULLVERSION | cut -c1-2`
if [ ! $VERSION -eq 85 ]; then
    echo "--------------------------------------------------------------"
    echo "VERSION $FULLVERSION must be 8.5 or higher                    "
    echo "--------------------------------------------------------------"
    exit 1
fi

if [ ! -z ${INSTANCE} ]; then
    EXTENSION="_${INSTANCE}"
fi

PACKAGE="com.ibm.websphere.PLG.v85"
PLUGDESTDIR=/usr/WebSphere${VERSION}${EXTENSION}/Plugin
PLUGLOGDIR=/logs/WebSphere${VERSION}${EXTENSION}/Plugin
IMBASEDIR="/opt/IBM/InstallationManager"

#------------------------------------------------------------------------------------------------
# Stop if previous installation of WebSphere Plugin does not exist                               
#------------------------------------------------------------------------------------------------

if [ ! -d ${PLUGDESTDIR} ]; then
    echo "$PLUGDESTDIR directory does not exist, cannot remove"
    exit 1
fi

#------------------------------------------------------------------------------------------------
# Stop if Installation Manager is not installed                                                  
#------------------------------------------------------------------------------------------------

if [ ! -d $IMBASEDIR/eclipse/tools ]; then 
   echo "Installation Manager must be installed to remove the plugin"
   echo "exiting...."
   exit 1
fi

echo "-----------------------------------------------------------------------------------------"
echo " Uninstalling WebSphere Application Server Plugin version: $VERSION package: $PACKAGE    "
echo " Location: $PLUGDESTDIR                                                                  "
echo ""
echo "-----------------------------------------------------------------------------------------"
echo ""

$IMBASEDIR/eclipse/tools/imcl uninstall $PACKAGE -installationDirectory ${PLUGDESTDIR}
if [ $? -ne 0 ]; then 
    echo "Failed to uninstall package: $PACKAGE.  Exiting...."
    exit 1
fi

if [ -d $PLUGDESTDIR ]; then
	echo "Removing $PLUGDESTDIR directory and filesystem "
	cd /tmp
    /fs/system/bin/eirmfs -f $PLUGDESTDIR
    if [ -d $PLUGDESTDIR ]; then
        rmdir $PLUGDESTDIR
    fi
    typeset -i numFiles=`find /usr/WebSphere${VERSION}${EXTENSION} -type f | wc -l`
    if [[ $numFiles == 0 ]]; then
       rmdir /usr/WebSphere${VERSION}${EXTENSION}
    fi 
fi

if [ -d $PLUGLOGDIR ]; then
    echo "Removing directory $PLUGLOGDIR"
    cd /tmp
    rm -rf $PLUGLOGDIR
    typeset -i numFiles=`find /logs/WebSphere${VERSION}${EXTENSION} -type f | wc -l`
    if [[ $numFiles == 0 ]]; then
       rmdir /logs/WebSphere${VERSION}${EXTENSION}
    fi 
fi

echo "----------------------------------------------------------------------------------------"
echo " Uninstalled WebSphere Plugin successfully                                           ---"
echo ""
echo "----------------------------------------------------------------------------------------"
echo ""
exit 0