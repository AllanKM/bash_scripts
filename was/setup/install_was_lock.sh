#!/bin/bash
# Usage: install_was_lock.sh [VERSION]
FULLVERSION=${1:-70023}
VERSION=`echo $FULLVERSION | cut -c1-2`
PLATFORM=`uname`
ASROOT="/usr/WebSphere${VERSION}/AppServer"

case $PLATFORM in
	AIX)	TAR="/opt/freeware/bin/tar" ;;
	*)	TAR="tar" ;;
esac

echo "* Installing WAS admin console lock..."
echo "=================================================================="
cd ${ASROOT}
${TAR} -zxvf /lfs/system/tools/was/setup/v${VERSION}consolelock.tar.gz
echo "* 	Fixing permissions on WAS admin console files..."
echo "=================================================================="
chown -R webinst.eiadm ${ASROOT}/systemApps
chmod -R 770 ${ASROOT}/systemApps
echo "Done."
echo -e '\e[1;31m***********************************************************************************************\e[0m'
echo -e '\e[1;31m!!!\e[0m The Administrative Console server \e[1;31mMUST\e[0m be restarted for the console lock to take effect \e[1;31m!!!\e[0m'
echo -e '\e[1;31m***********************************************************************************************\e[0m'
