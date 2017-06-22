#!/bin/bash

#-------------------------------------------------------------------------------
# Install WebSphere Application Server 8.5.x.x HTTP Plugin fixes (run as sudo)
#-------------------------------------------------------------------------------
#
# USAGE: sudo /lfs/system/tools/was/setup/install_plugin_fixes_v3.sh was_version=<version>  fixpackage=<fixpackage name> repository=<repository location> [ wasinstnum=<instance> ihs_version=<version>  ihsinstnum=<instance>  toolsdir=<local tools dir>  nostop=<true|false> ]
#
# Name of the version, fix package, and repository.config location (i.e. 85001, com.ibm.websphere.PLG.v85, /fs/system/images/websphere/8.5/fixes/85001/supplements)
#
#---------------------------------------------------------------
#
#  Change History: 
#
#  Lou Amodeo - 04/10/2013 - Initial creation
#  Lou Amodeo - 05/08/2013 - Add revised directory structure
#  Lou Amodeo - 12/06/2013 - Add function to stop IHS unless nostop=true
#
#---------------------------------------------------------------
#

#Verify script is called via sudo
if [[ $SUDO_USER == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "********** Script install_plugin_fixes_v3.sh needs       ********"
   echo "**********         to be run with sudo                   ********"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

# Set umask
umask 002

FULLVERSION=""
IHSVERSION=""
FIXPACKAGE=""
REPOSITORY=""
INSTANCE=""
IHSINSTANCE=""
TOOLSDIR="/lfs/system/tools"
NOSTOP="false"
SLEEP=15

# Read in libraries
IHSLIBPATH="/lfs/system/tools"
funcs=${IHSLIBPATH}/ihs/lib/ihs_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

funcs=${IHSLIBPATH}/ihs/lib/ihs_install_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

funcs=${IHSLIBPATH}/was/lib/was_install_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

funcs=${IHSLIBPATH}/was/lib/was_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

# Process command-line options
until [[ -z "$1" ]] ; do
   case $1 in
      was_version=*)    VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FULLVERSION=$VALUE;    fi ;;
      ihs_version=*)    VALUE=${1#*=}; if [ "$VALUE" != "" ]; then IHSVERSION=$VALUE;     fi ;;
      fixpackage=*)     VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FIXPACKAGE=$VALUE;     fi ;;
      repository=*)     VALUE=${1#*=}; if [ "$VALUE" != "" ]; then REPOSITORY=$VALUE;     fi ;;
      wasinstnum=*)     VALUE=${1#*=}; if [ "$VALUE" != "" ]; then INSTANCE=$VALUE;       fi ;;
      ihsinstnum=*)     VALUE=${1#*=}; if [ "$VALUE" != "" ]; then IHSINSTANCE=$VALUE;    fi ;;
      toolsdir=*)       VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE;       fi ;;
      nostop=*)         VALUE=${1#*=}; if [ "$VALUE" != "" ]; then NOSTOP=$VALUE;         fi ;;
      *)  echo "#### Unknown argument: $1" 
          echo "#### Usage: ${0}"
          echo "####           was_version=< desired WAS Plugin version >"
          echo "####           ihs_version=< version of IHS to stop >"
          echo "####           fixpackage=< fixpackage name >"
          echo "####           repository=< location of the fix package repository >"
          echo "####           [ wasinstnum=< instance number of the desired WAS Plugin version > ]"
          echo "####           [ ihsinstnum=< instance number of the desired IHS to stop > ]"
          echo "####           [ toolsdir=< path to ei local tools > ]"
          echo "####           [ nostop=< do not stop IHS if true > ]"
          echo "#### ---------------------------------------------------------------------------"
          echo "####             Defaults:"
          echo "####               was_version   = NODEFAULT"
          echo "####               ihs_version   = NULL"
          echo "####               fixpackage    = NODEFAULT"
          echo "####               repository    = NODEFAULT"
          echo "####               wasinstnum    = NULL"
          echo "####               ihsinstnum    = NULL"
          echo "####               toolsdir      = /lfs/system/tools"
          echo "####               nostop        = false"
          echo "####             Notes:  "
          echo "####               1) wasinstnum is used to install"
          echo "####                  multiple of the same version"
          echo "####                  of WAS Plugin"
          echo "####               2) ihsinstnum is used to identify"
          echo "####                  which IHS to stop"
          echo " "
          exit 1
      ;;
   esac
   shift
done

#------------------------------------------------------------------------------
# Stop if was_version was not specified
#------------------------------------------------------------------------------

if [ -z ${FULLVERSION} ]; then
    echo "was_version was not specified, cannot apply a fixpackage"
    exit 1
fi

VERSION=`echo $FULLVERSION | cut -c1-2`
if [ ! $VERSION -eq 85 ]; then
    echo "VERSION $FULLVERSION must be 8.5.x.x"
    exit 1
fi

#------------------------------------------------------------------------------
# Stop if ihs_version was not specified and nostop=false
#------------------------------------------------------------------------------

if [ ${NOSTOP} == "false" ]; then
    if [ -z ${IHSVERSION} ]; then
        echo "ihs_version was not specified and is required unless nostop=true is specified"
        exit 1
    fi
fi

if [ -z ${INSTANCE} ]; then
   EXTENSION=""
else
   EXTENSION="_${INSTANCE}"
fi

IMBASEDIR="/opt/IBM/InstallationManager"
IMSHAREDDIR="/usr/IMShared"
PLUGDESTDIR=/usr/WebSphere${VERSION}${EXTENSION}/Plugin
PLUGLOGDIR=/logs/WebSphere${VERSION}${EXTENSION}/Plugin

#------------------------------------------------------------------------------
# Stop if previous installation of WebSphere Plugin does not exist             
#------------------------------------------------------------------------------

if [ ! -d ${PLUGDESTDIR} ]; then
    echo "$PLUGDESTDIR directory does not exist, cannot apply a fixpackage"
    exit 1
fi

#------------------------------------------------------------------------------
# Stop if fixpackage id was not specified
#------------------------------------------------------------------------------

if [ -z ${FIXPACKAGE} ]; then
    echo "fixpackage id was not specified, cannot apply a fixpackage"
    exit 1
fi

#-----------------------------------------------------------------------
# Stop if fixpackage repository does not exist
#-----------------------------------------------------------------------

if [ ! -d $REPOSITORY ]; then 
   echo "Fixpackage repository $REPOSITORY does not exist"
   echo "exiting...."
   exit 1
fi

#-----------------------------------------------------------------------
# Stop if Installation Manager has not been installed
#-----------------------------------------------------------------------

if [ ! -d $IMBASEDIR/eclipse/tools ]; then 
   echo "Installation Manager must be installed prior to installing WebSphere Plugin fixpackage"
   echo "exiting...."
   exit 1
fi

#------------------------------------------------------------------------------
# Stop if tools are not available  
#------------------------------------------------------------------------------

if [[ ! -d $TOOLSDIR ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Tools Directory $TOOLSDIR does not exist"
   echo "      on this node"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

#------------------------------------------------------------------------------
# Stop IHS unless nostop=true was specified  
#------------------------------------------------------------------------------
if [ ${NOSTOP} == "false" ]; then

    IHSLEVEL=`echo $IHSVERSION | cut -c1-2`
    if [[ ! $IHSLEVEL == 85 ]]; then
        echo "/////////////////////////////////////////////////////////////////////"
        echo "************    Base IHS Version $IHSVERSION not supported  *******"
        echo "************         by this install script                 *******"
        echo "//////////////////////////////////////////////////////////////////////"
        echo ""
        exit 1
    fi

    DESTDIR="/usr/WebSphere${IHSLEVEL}/HTTPServer"

    if [[ $IHSINSTANCE == "0" ]]; then
         DESTDIR="${DESTDIR}"
    elif [[ $IHSINSTANCE != "" ]]; then
           IHSEXTENSION="_${IHSINSTANCE}"
           DESTDIR="/usr/WebSphere${IHSLEVEL}${IHSEXTENSION}/HTTPServer"
    fi

    if [[ ! -d ${DESTDIR} ]]; then
      echo "An IHS Server root for ${DESTDIR} was not detected."
      echo "Specify nostop=true if IHS is not installed on this node."
      echo "Aborting Plugin fixpackage install"
      exit 1
    fi

    stop_httpd_verification_85 $DESTDIR $TOOLSDIR $SLEEP plug
    function_error_check stop_httpd_verification_85 plug     
fi

echo "---------------------------------------------------------------"
echo " Installing fix package: $FIXPACKAGE                           "
echo " Repository location: $REPOSITORY                              "
echo
echo " /tmp/IM_WASPluginFIXPACKAGE.log installation details and progress "
echo
echo "---------------------------------------------------------------"
FIXPACKAGELOGFILE=/tmp/IM_WASPluginFIXPACKAGE.log
  
$IMBASEDIR/eclipse/tools/imcl install $FIXPACKAGE -repositories $REPOSITORY -installationDirectory $PLUGDESTDIR -log $FIXPACKAGELOGFILE -acceptLicense
if [ $? -ne 0 ]; then
     echo "Installation of fixpack: $FIXPACKAGE at: $REPOSITORY failed...."
     echo "exiting...."
     exit 1
fi

echo "---------------------------------------------------------------"
echo " Setting fix package permissions                               "
echo "---------------------------------------------------------------"
echo
${TOOLSDIR}/ihs/setup/ihs_perms_v3.sh plugin_level=${VERSION} plugininstnum=${INSTANCE} subproduct=plugin toolsdir=${TOOLSDIR}

echo ""
echo "---------------------------------------------------------------"
echo "       Running Plugin Installed Version Report"
echo "---------------------------------------------------------------"
echo ""
${TOOLSDIR}/ihs/setup/verify_versions_installed_v3.sh serverroot=${PLUGDESTDIR} product=plugin

echo "---------------------------------------------------------------"
echo " Fix package $FIXPACKAGE has been installed successfully      "
echo
echo "---------------------------------------------------------------"
echo
exit 0
