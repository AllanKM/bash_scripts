#!/bin/bash

#---------------------------------------------------------------
# WebSphere fix package installer (run as sudo)
#---------------------------------------------------------------
#
# USAGE: install_was_fixpack_v2.sh [version] [package] [repository] (--skip-perms)
#
# Name of the version, fix package, and repository.config location (i.e. 85001, com.ibm.websphere.ND.v85, /fs/system/images/websphere/8.5/fixes/85001/base)
#
#---------------------------------------------------------------
#
#  Change History: 
#
#  Lou Amodeo - 03/01/2013 - Initial creation
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
    echo "VERSION $FULLVERSION must be 8.5.x.x"
    exit 1
fi

BASEDIR="/usr/WebSphere${VERSION}"
APPDIR="${BASEDIR}/AppServer"
IMBASEDIR="/opt/IBM/InstallationManager"

echo "---------------------------------------------------------------"
echo " Installing fix package: $FIXPACKAGE                              "
echo " Repository location: $REPOSITORY                              "
echo
echo " /tmp/IM_WASFIXPACKAGE.log installation details and progress   "
echo
echo "---------------------------------------------------------------"
FIXPACKAGELOGFILE=/tmp/IM_WASFIXPACKAGE.log
  
$IMBASEDIR/eclipse/tools/imcl install $FIXPACKAGE -repositories $REPOSITORY -installationDirectory $APPDIR -log $FIXPACKAGELOGFILE -acceptLicense
if [ $? -ne 0 ]; then
     echo "Installation of fixpack: $FIXPACKAGE at: $REPOSITORY failed...."
     echo "exiting...."
     exit 1
else
     # Now copy the unrestricted JCE Policy files
     echo "Copying IBM JCE Unrestricted Policy files"
     DATE=`date +"%Y%m%d"`
     cd ${APPDIR}/java/jre/lib/security
     cp -p local_policy.jar local_policy.jar.bak${DATE}
     cp -p /fs/system/images/websphere/unrestricted_jce_policy/local_policy.jar ./
     cp -p US_export_policy.jar US_export_policy.jar.bak${DATE}
     cp -p /fs/system/images/websphere/unrestricted_jce_policy/US_export_policy.jar ./
fi

# Check whether EI WAS adminconsole lock was removed
# Both the eilock.js file and the modified prop must exist, if either are missing, re-apply
grep eilock /usr/WebSphere${VERSION}/AppServer/systemApps/isclite.ear/isclite.war/WEB-INF/classes/com/ibm/isclite/common/Messages_en.properties > /dev/null
if [ $? -ne 0 ] || [ ! -f /usr/WebSphere${VERSION}/AppServer/systemApps/isclite.ear/isclite.war/scripts/eilock.js ]; then
	echo "Applying EI WebSphere administration console lockout for the primary admin user."
	/lfs/system/tools/was/setup/install_was_lock.sh $VERSION
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

echo "---------------------------------------------------------------"
echo " Fix package $FIXPACKAGE has beeen installed successfully      "
echo
echo "---------------------------------------------------------------"
echo
exit 0
