#!/bin/bash 

#---------------------------------------------------------------
# Installation Manager uninstall.  (run as sudo)
#---------------------------------------------------------------
#
# USAGE: remove_im.sh
#
#---------------------------------------------------------------
#
#  Change History: 
#
#  Lou Amodeo - 03/01/2013 - Initial creation
#  Lou Amodeo - 09/06/2013 - Add dedicated filesystems for install and agent data directories
#  Lou Amodeo - 12/12/2013 - change rmfs to /fs/system/bin/eirmfs
# 
#
#
#---------------------------------------------------------------
#

function usage {
  echo "Usage:"
  echo ""
  echo " $0 "
  echo ""
}

INSTALLDIR="/opt/IBM/InstallationManager"
DATADIR="/var/ibm/InstallationManager"
IMSHAREDDIR="/usr/IMShared"
LOGFILE="/tmp/IM_REMOVE.log"

#-----------------------------------------------------------------------
# Verify that Installation Manager is installed
#-----------------------------------------------------------------------

if [ ! -d ${INSTALLDIR} ]; then
	echo "Installation Manager is not installed at $INSTALLDIR"	
	exit 1
fi

echo "---------------------------------------------------------------"
echo "Removing Installation Manager"
echo 
echo
echo " Tail /tmp/IM_REMOVE.log for removal details and progress"
echo "---------------------------------------------------------------"

echo ""
$DATADIR/uninstall/uninstallc -log ${LOGFILE}

echo ""
if [ -d $INSTALLDIR ]; then
    echo "Removing $INSTALLDIR filesystem"
    /fs/system/bin/eirmfs -f $INSTALLDIR
    if [ -d $INSTALLDIR ]; then
        rmdir $INSTALLDIR
    fi
fi

echo ""
if [ -d $DATADIR ]; then
    echo "Removing $DATADIR filesystem"
    /fs/system/bin/eirmfs -f $DATADIR
    if [ -d $DATADIR ]; then
        rmdir $DATADIR
    fi
fi

echo ""
if [ -d $IMSHAREDDIR ]; then
    echo "Removing $IMSHAREDDIR filesystem"
    /fs/system/bin/eirmfs -f $IMSHAREDDIR
    if [ -d $IMSHAREDDIR ]; then
        rmdir $IMSHAREDDIR
    fi
fi

echo "Completed removal of Installation Manager"
exit 0
