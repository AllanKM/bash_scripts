#!/bin/bash
#---------------------------------------------------------------
# Portal efix/fixpack installer
#---------------------------------------------------------------
# 
#   "Usage:"
#   "sudo ./install_portal_fixpack.sh <6.0|6.1> <efix or fixpack search string>
#
#
VERSION=$1
VERSHORT=`echo $VERSION | sed -e "s/\.//g"`
WASHOME="/usr/WebSphere${VERSHORT}/AppServer"
PORTALDIR="/usr/WebSphere${VERSHORT}/PortalServer"
UIDIR="${PORTALDIR}/update"
FIX=$2
FIXDIR=''
FIXPACKDIR="/fs/system/images/portal/${VERSION}/Fixpack"
UPDI="${UIDIR}/updatePortal.sh"
UITAR=''
TMPDIR="/fs/scratch/fixpacktmp-`date +%Y%h%m-%H%M%S`"
FULLVER=''
CURDIR=`pwd`
FIXNAME=''

echo $2 |grep -q -e PK -e PM
test $? -eq 0 && TYPE='fix' || TYPE='fixpack'
if [ `whoami` != "root" ]; then
  echo "Please run as root or with sudo"
  exit 0
fi

function throw_error {
   echo "Error: $1"
   usage
}

function usage {
   echo ""
   echo "Usage:"
   echo "  sudo $0 <6.0|6.1> <efix or fixpack search string> "
   exit 1
}

function setupCmdLine {
   echo "Setting up commandline"
   cd ${WASHOME}/profiles/`hostname`/bin
   . ./setupCmdLine.sh
}

function check_args {
   echo "Processing commandline arguments:"
   if [ $# -lt 2 ]; then throw_error "Not enough arguments - $# supplied"; fi
   echo $VERSION | egrep -q [0-9]\.[0-9]
   if [ $? -ne 0 ]; then
     throw_error "Version syntax is incorrect"
   fi
   echo "...complete"
}

function find_wps {
   test -d "$PORTALDIR" && get_version ${PORTALDIR} || echo "WPS Version ${VERSION} not found"
}

function get_version {
   echo "Obtaining version information:"
   FULLVER=`${1}/bin/WPVersionInfo.sh | egrep ^Version |egrep [0-9]\.[0-9]\.[0-9]\.[0-9]+ |uniq |awk {'print $2'}`
   echo "...WPS ${FULLVER} found."
   FIXDIR="/fs/system/images/portal/${VERSION}/Fixes"
   UITAR="/fs/system/images/portal/updi/PortalUpdateInstaller${VERSHORT}.tar"
}

function update_portal {
   test $TYPE = 'fix' && ARGS="-fix -fixDir ${TMPDIR} -fixes ${FIXID}" || ARGS="-fixpack -fixpackDir ${TMPDIR} -fixpackID ${FIXID}"
   ${UPDI} -install -installDir ${PORTALDIR} ${ARGS}
}

function prepare_fix {
   declare -a fixlist=(`ls -1 $FIXDIR | grep ${FIX}`)
   if [[ ${#fixlist[@]} -lt 1 ]]; then
     throw_error "Fix ${FIX} not found" 
   fi
   test ${#fixlist[*]} -gt 1 && throw_error "More than one file found ${fixlist[*]}"
   echo ${fixlist[*]} |grep -q -e PK -e PM
   test $? -ne 0 && TYPE='fixpack' || TYPE='fix'
   echo ""
   echo "Preparing ${TYPE} ${FIX}"
   echo "...File ${fixlist[*]} found."
   echo ""
   echo "Unzipping file ${fixlist[*]} to ${TMPDIR}"
   mkdir -p ${TMPDIR}
   test $? -eq 0 || throw_error "Failed to create ${TMPDIR}"
   cd ${TMPDIR}
   unzip ${FIXDIR}/${fixlist[*]}
   test $? -eq 0 || throw_error "Failed to unzip ${fixlist[*]}"
   FIXID=`ls *.jar |awk -F. {'print $1'}`
}

function cleanup {
   echo "Cleaning up temp directory"
   cd ${CURDIR}
   rm -rf ${TMPDIR}
   /lfs/system/tools/was/setup/was_perms.ksh
}

function grab_update_installer {
   echo "Installing latest update installer to ${UIDIR}"
   test -d ${UIDIR} && rm -rf ${UIDIR}
   mkdir ${UIDIR} 
   cd ${UIDIR}
   tar xf ${UITAR}
}

check_args $@
find_wps
setupCmdLine
prepare_fix
grab_update_installer
update_portal $TYPE
cleanup
