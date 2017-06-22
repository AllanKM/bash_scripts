#!/bin/bash

#---------------------------------------------------------------
# WebSphere eXtremeScale fix package installer (run as sudo)
#---------------------------------------------------------------
#
# USAGE: install_wxs_fixpack_86.sh wxs=<wxsversion> [was=<wasversion>] package=<package> pkgtype=<CLIENT|STANDALONE|WASCLIENT|WAS7CLIENT> repos=<repository> 
#
# Name of the version, fix package, and repository.config location (i.e. wxs=86 package=com.ibm.websphere.WXS.v86 pkgtype=STANDALONE repos=/fs/system/images/websphere/wxs/8.6/fixes/WXS_8603/STANDALONE/8603
#
#---------------------------------------------------------------
#
#  Change History: 
#
#  Lou Amodeo - 06/19/2013 - Initial creation
#  Lou Amodeo - 12/04/2013 - Fix return code bug introduced with tee
#  Lou Amodeo - 04/13/2015 - Support WAS7CLIENT Installs
#
#
#---------------------------------------------------------------
#
#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
        wxs=*)       VALUE=${1#*=}; if [ "$VALUE" != "" ];      then FULLVERSION=$VALUE; fi ;;
        was=*)       VALUE=${1#*=}; if [ "$VALUE" != "" ];      then WASFULLVER=$VALUE;  fi ;;
        package=*)   VALUE=${1#*=}; if [ "$VALUE" != "" ];      then FIXPACKAGE=$VALUE;  fi ;;
        pkgtype=*)   VALUE=${1#*=}; if [ "$VALUE" != "" ];      then PKGTYPE=$VALUE;     fi ;;
        repos=*)     VALUE=${1#*=}; if [ "$VALUE" != "" ];      then REPOSITORY=$VALUE;  fi ;;
        *)  echo "#### Unknown argument: $1"
            echo "#### Usage: install_wxs_fixpack_86.sh wxs=<wxsversion> [was=<wasversion>] package=<package> pkgtype=<CLIENT|STANDALONE|WASCLIENT> repos=<repository>"
            exit 1
            ;;
    esac
    shift
done

VERSION=`echo $FULLVERSION | cut -c1-2`
if [ ! $VERSION -eq 86 ]; then
    echo "WXS VERSION $FULLVERSION must be 8.6.x.x"
    exit 1
fi

if [ -z ${FIXPACKAGE} ]; then
   echo  "package= must be specified"
   exit 1
fi

if [ -z ${PKGTYPE} ]; then
   echo  "pkgtype= must be specified"
   exit 1
fi

if [ -z ${REPOSITORY} ]; then
   echo  "repos= must be specified"
   exit 1
fi

# WASCLIENT gets installed in WebSphere directory tree, other clients in eXtremeScale tree
if [ ${PKGTYPE} == "WASCLIENT" -o ${PKGTYPE} == "WAS7CLIENT" ]; then
    if [ -z ${WASFULLVER} ]; then
        echo  "was= must be specified"
        exit 1
    fi
    WASVERSION=`echo $WASFULLVER | cut -c1-2`
    BASEDIR="/usr/WebSphere${WASVERSION}"
    APPDIR="${BASEDIR}/AppServer"
else
    BASEDIR="/usr/WebSphere${VERSION}"
    APPDIR="${BASEDIR}/eXtremeScale"
fi

if [ ! -d $APPDIR ]; then
   echo "WebSphere eXtremeScale is not installed at $APPDIR"
   exit 1
fi

IMBASEDIR="/opt/IBM/InstallationManager"

echo "---------------------------------------------------------------"
echo " Installing fix package: $FIXPACKAGE                           "
echo " Repository location: $REPOSITORY                              "
echo
echo " /tmp/IM_WXSFIXPACKAGE.log installation details and progress   "
echo " /tmp/IM_WXSFIXPACKAGE-verbose.log verbose details (usefuller than the other)"
echo
echo "---------------------------------------------------------------"
FIXPACKAGELOGFILE=/tmp/IM_WXSFIXPACKAGE.log
FIXPACKAGEVERBOSELOGFILE=/tmp/IM_WXSFIXPACKAGE-verbose.log
  
$IMBASEDIR/eclipse/tools/imcl install $FIXPACKAGE -repositories $REPOSITORY -installationDirectory $APPDIR -log $FIXPACKAGELOGFILE -acceptLicense -showVerboseProgress | tee -a $FIXPACKAGEVERBOSELOGFILE
if [ ${PIPESTATUS[0]} -ne 0 ]; then
     echo "Installation of fixpack: $FIXPACKAGE at: $REPOSITORY failed...."
     echo "exiting...."
     exit 1
fi

echo "---------------------------------------------------------------"
echo " Setting fix package permissions                               "
echo "---------------------------------------------------------------"
echo
/lfs/system/tools/was/setup/was_perms.ksh

echo "---------------------------------------------------------------"
echo " Fix package $FIXPACKAGE has been installed successfully      "
echo
echo "---------------------------------------------------------------"
echo
exit 0
