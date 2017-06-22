#!/bin/bash
#---------------------------------------------------------------
# Portal install.
#---------------------------------------------------------------
# USAGE: sudo ./install_portal.sh [volume group]
#
# Prerequisites:
#   WAS 6.1.0.15
#   FS: /usr/WebSphere61 - expandable to 7gigs
#

if [ `whoami` != "root" ]; then
  echo "Please run as root"
  exit 0
fi
# GLOBALS
BASEDIR=/usr/WebSphere61
RESPONSEFILE=/fs/system/images/portal/responsefiles/wps61.txt
HOST=`hostname`
RFTMP="/tmp/wps61${HOST}.txt"
WASVER="/usr/WebSphere61/AppServer/bin/versionInfo.sh"
WPSINSTALL="/fs/system/images/portal/6.1/install.sh"
VG=${1:-appvg1}

function prepare_rf {
  echo "prepare_rf"
  cat ${RESPONSEFILE} | sed "s/<hostname>/${HOST}/g" > ${RFTMP}
  if_failure $? "creating responsefile"
}

function check_fs {
  echo "Checking filesystems"
  /lfs/system/tools/configtools/make_filesystem $BASEDIR 7168 ${VG}
  if_failure $? "creating/extending filesystem"
}

function check_was {
  echo "Current WebSphere Version:"
  if [ -f ${WASVER} ]; then 
    ${WASVER} -componentDetail |grep "Maintenance Package ID" |awk -F"ID   " {'print $2'} |sort -u |grep WS-WAS- | grep -i `uname` | grep -v RP |sort -r |head -1
  else
    echo "WAS is not installed"
    exit 0
  fi
}

function if_failure {
  if [ $1 -ne 0 ]; then
    echo "Failure" $2
    exit 0
  fi
}
	
function check_profile {
  if [ -d ${BASEDIR}/AppServer/profiles/${HOST} ]; then
    ${BASEDIR}/AppServer/bin/manageprofiles.sh -delete -profileName ${HOSTNAME}
    if_failure $? "removing profile"
  fi
  if [ -d ${BASEDIR}/AppServer/profiles/${HOST} ]; then
    rm -rf ${BASEDIR}/AppServer/profiles/${HOST}
    if_failure $? "removing profiles dir"
  fi
} 

function install_wps {
  echo "Installng WPS - tail /tmp/wpinstalllog.txt for status"
  ${WPSINSTALL} -options ${RFTMP}
}

prepare_rf
check_fs
check_was
check_profile
install_wps
