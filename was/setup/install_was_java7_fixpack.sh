#!/bin/bash

#---------------------------------------------------------------
# WebSphere Java 7 fix package installer (run as sudo)
#---------------------------------------------------------------
#
# USAGE: install_was_java7_fixpack.sh was_version package repository (--skip-perms)
#
# Name of the was_version, fix package, and repository.config location (i.e. 85001, com.ibm.websphere.IBMJAVA.v70, /fs/system/images/websphere/8.5/fixes_java7/7020)
#
#---------------------------------------------------------------
#
#  Change History: 
#
#  Lou Amodeo - 03/29/2013 - Initial creation
#  Lou Amodeo - 10/01/2014 - Install unrestricted JCE policy files
#
#
#---------------------------------------------------------------
#
FULLVERSION=${1:-85001}
FIXPACKAGE=$2
REPOSITORY=$3
SKIPPERMS=$4

VERSION=`echo $FULLVERSION | cut -c1-2`
if [ ! $VERSION -eq 85 ]; then
    echo "Websphere version $FULLVERSION must be 8.5.x.x"
    exit 1
fi

BASEDIR="/usr/WebSphere${VERSION}"
APPDIR="${BASEDIR}/AppServer"
INSTALLDIR="${APPDIR}/java_1.7_64"
IMBASEDIR="/opt/IBM/InstallationManager"

#-----------------------------------------------------------------------
# Stop if installation of WebSphere does not exist                      
#-----------------------------------------------------------------------

if [ ! -d ${APPDIR} ]; then
    echo "$APPDIR directory does not exist"
    echo "Please install WebSphere Application Server 8.5.x.x prior to installing Java 7"
    exit 1
fi

#-----------------------------------------------------------------------
# Stop if Java 7 already is installed                                   
#-----------------------------------------------------------------------

if [ ! -d ${INSTALLDIR} ]; then
    echo "Java 7 is not installed at ${INSTALLDIR}. PLease install Java 7 base prior to installing a Java 7 fixpack"
    exit 1
fi


echo "---------------------------------------------------------------"
echo " Installing Java 7 fix package: $FIXPACKAGE                    "
echo " Repository location: $REPOSITORY                              "
echo
echo " /tmp/IM_J7FIXPACKAGE.log installation details and progress   "
echo
echo "---------------------------------------------------------------"
FIXPACKAGELOGFILE=/tmp/IM_J7FIXPACKAGE.log
  
$IMBASEDIR/eclipse/tools/imcl install $FIXPACKAGE -repositories $REPOSITORY -installationDirectory $APPDIR -log $FIXPACKAGELOGFILE -acceptLicense
if [ $? -ne 0 ]; then
     echo "Installation of fixpackage: $FIXPACKAGE at: $REPOSITORY failed...."
     echo "exiting...."
     exit 1
else
     # Now copy the unrestricted JCE Policy files
     echo "Copying IBM JCE Unrestricted Policy files"
     DATE=`date +"%Y%m%d"`
     cd ${APPDIR}/java_1.7_64/jre/lib/security
     cp -p local_policy.jar local_policy.jar.bak${DATE}
     cp -p /fs/system/images/websphere/unrestricted_jce_policy/local_policy.jar ./
     cp -p US_export_policy.jar US_export_policy.jar.bak${DATE}
     cp -p /fs/system/images/websphere/unrestricted_jce_policy/US_export_policy.jar ./
fi

if [ "$SKIPPERMS" == "--skip-perms" ]; then
    echo "Skipping was_perms.ksh run..."
else
    echo "---------------------------------------------------------------"
    echo " Setting fix package permissions                               "
    echo "---------------------------------------------------------------"
    echo
    /lfs/system/tools/was/setup/was_perms.ksh
fi

echo "------------------------------------------------------------------"
echo " Java 7 fix package $FIXPACKAGE has been installed successfully   "
echo
echo "------------------------------------------------------------------"
echo
exit 0
