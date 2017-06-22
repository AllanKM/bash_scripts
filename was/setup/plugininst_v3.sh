#!/bin/bash 

#-------------------------------------------------------------------------
# Install WebSphere Application Server 8.5.x.x HTTP Plugin (run as sudo)  
#-------------------------------------------------------------------------
#
#-------------------------------------------------------------------
#
#  Change History: 
#
#  Lou Amodeo - 04/10/2013 - Initial creation
#  Lou Amodeo - 05/08/2013   Add revised directory structure
#  Lou Amodeo - 12/02/2013   Add 8.5.5.1 fixpack
#  Lou Amodeo - 04/29/2014   Add 8.5.5.2 fixpack
#  Lou Amodeo - 01/08/2015   Add 8.5.5.4 fixpack
#  Lou Amodeo - 09/03/2015   Add 8.5.5.6 fixpack
#
#-------------------------------------------------------------------
#

# USAGE: plugininst_v3.sh  was_version=<VERSION> vg=<volume group>  [ wasinstnum=<instance> toolsdir=<local tools dir> ]

#Verify script is called via sudo
if [[ $SUDO_USER == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "*************   Script plugininst_v3.sh needs         ***********"
   echo "*************         to be run with sudo             ***********"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

# Set umask
umask 002

ERROR=0
FULLVERSION="85500"
VG="appvg1"
INSTANCE=""
TOOLSDIR="/lfs/system/tools"

#Read in libraries
funcs=${TOOLSDIR}/was/lib/was_install_functions_v2.sh
[ -r $funcs ] && . $funcs || echo "#### Cannot read functions file at $funcs"

# Process command-line options
until [[ -z "$1" ]] ; do
   case $1 in
      was_version=*)    VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FULLVERSION=$VALUE; fi ;;
      wasinstnum=*)     VALUE=${1#*=}; if [ "$VALUE" != "" ]; then INSTANCE=$VALUE;    fi ;;
      vg=*)             VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VG=$VALUE;          fi ;;
      toolsdir=*)       VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE;    fi ;;
      *)  echo "#### Unknown argument: $1" 
          echo "#### Usage: ${0}"
          echo "####           was_version=< desired WAS PLigun version >"
          echo "####           vg=< volume group where WAS plugin binaries are to be installed >"
          echo "####           [ wasinstnum=< instance number of the desired WAS Plugin version > ]"
          echo "####           [ toolsdir=< path to ei local tools > ]"
          echo "#### ---------------------------------------------------------------------------"
          echo "####             Defaults:"
          echo "####               was_version   = 85500"
          echo "####               vg            = appvg1"
          echo "####               wasinstnum    = NULL"
          echo "####               toolsdir      = /lfs/system/tools"
          echo "####             Notes:"
          echo "####               1) wasinstnum is used to install"
          echo "####                  multiple WAS plugins"
          exit 1
      ;;
   esac
   shift
done

#---------------------------------------------------------------
# WebSphere HTTP Plugin install according to EI standards
#---------------------------------------------------------------

VERSION=`echo $FULLVERSION | cut -c1-2`
if [ ! $VERSION -eq 85 ]; then
    echo "VERSION $FULLVERSION must be 8.5 or higher"
    exit 1
fi

case `uname` in
    Linux)
        /sbin/vgdisplay -s |grep \"${VG}\" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "Using ${VG} as the volume group"
        else
            # Might be an old node, check for appvg
            /sbin/vgdisplay -s |grep \"appvg\" > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "Using appvg as the volume group"
                VG=appvg
            else
                echo "VG ${VG} and appvg do not exist.  Please specify the correct VG."
                usage
                exit 1
            fi
        fi ;;
    AIX)
        if lsvg ${VG} >/dev/null 2>&1; then
            echo "Using ${VG} as the volume group"
        else
            if lsvg appvg >/dev/null 2>&1; then
                echo "Using appvg as the volume group"
                VG=appvg
            else
                echo "VG ${VG} and appvg do not exist.  Please specify the correct VG."
                usage
                exit 1
            fi
        fi ;;
esac

# Set instance extension if specified
if [ -z ${INSTANCE} ]; then
  EXTENSION=""
else
  EXTENSION="_${INSTANCE}"
fi

#---------------------------------------------------------------
# Set install specific properties
#---------------------------------------------------------------

set_install_properties ()
{
    INSTDIR="/fs/system/images/websphere/8.5/supplements"
    PACKAGE="com.ibm.websphere.PLG.v85"

    if [ "$FULLVERSION" == "85000" ]; then
        DOTVER="8.5.0.0"
        FIXPACKAGES=()
        FIXREPOSITORIES=()
    elif [ "$FULLVERSION" == "85001" ]; then
        DOTVER="8.5.0.1"
        FIXPACKAGES=("com.ibm.websphere.PLG.v85")
        FIXREPOSITORIES=("/fs/system/images/websphere/8.5/fixes/85001/supplements")
    elif [ "$FULLVERSION" == "85500" ]; then
        DOTVER="8.5.5.0"
        FIXPACKAGES=("com.ibm.websphere.PLG.v85")
        FIXREPOSITORIES=("/fs/system/images/websphere/8.5/fixes/85500/supplements") 
    elif [ "$FULLVERSION" == "85501" ]; then
        DOTVER="8.5.5.1"
        FIXPACKAGES=("com.ibm.websphere.PLG.v85")
        FIXREPOSITORIES=("/fs/system/images/websphere/8.5/fixes/85501/supplements") 
    elif [ "$FULLVERSION" == "85502" ]; then
        DOTVER="8.5.5.2"
        FIXPACKAGES=("com.ibm.websphere.PLG.v85")
        FIXREPOSITORIES=("/fs/system/images/websphere/8.5/fixes/85502/supplements") 
    elif [ "$FULLVERSION" == "85504" ]; then
        DOTVER="8.5.5.4"
        FIXPACKAGES=("com.ibm.websphere.PLG.v85")
        FIXREPOSITORIES=("/fs/system/images/websphere/8.5/fixes/85504/supplements")
    elif [ "$FULLVERSION" == "85506" ]; then
        DOTVER="8.5.5.6"
        FIXPACKAGES=("com.ibm.websphere.PLG.v85")
        FIXREPOSITORIES=("/fs/system/images/websphere/8.5/fixes/85506/supplements")
    else
	    echo "Not configured to install WAS Plugin version $FULLVERSION"
	    echo "exiting..."
	    exit 1
    fi
}

install_was_aix ()
{   
    OSDIR="aix"
    CHMOD="chmod -h"
    CHMODR="chmod -hR"
    XARGS="xargs -I{} "
    FS_TABLE="/etc/filesystems"
    SYSTEM_GRP="system"
}

install_was_linux_x86 ()
{
    OSDIR="linux"
    CHMOD="chmod "
    CHMODR="chmod -R "
    XARGS="xargs -i{} "
    FS_TABLE="/etc/fstab"
    SYSTEM_GRP="root"

    #java -version hangs on SLES 9 unless the following ulimit command is executed
    # as mentioned at http://www-1.ibm.com/support/docview.wss?uid=swg21182138
    ulimit -s 8196
}

install_was_linux_ppc () 
{
    OSDIR="linuxppc"
    CHMOD="chmod "
    CHMODR="chmod -R "
    XARGS="xargs -i{} "
    FS_TABLE="/etc/fstab"
    SYSTEM_GRP="root"

    #java -version hangs on SLES 9 unless the following ulimit command is executed
    # as mentioned at http://www-1.ibm.com/support/docview.wss?uid=swg21182138
    ulimit -s 8196
}

#Location of this nodes IM install
IMBASEDIR="/opt/IBM/InstallationManager"
#WebSphere plugin installation package groups shared artifacts will be installed in the std IMShared location.
IMSHAREDDIR="/usr/IMShared"
FEATURE="com.ibm.jre.6_64bit"
PLUGDESTDIR=/usr/WebSphere${VERSION}${EXTENSION}/Plugin
PLUGLOGDIR=/logs/WebSphere${VERSION}${EXTENSION}/Plugin
LOGFILE="/tmp/IM_WASPluginInstall.log"

#---------------------------------------------------------------
# Commands that run on all platforms
#---------------------------------------------------------------

if [ ! -d /fs/system ]; then
	echo "Shared filesystem not mounted .. attempting to fix"
	ls -l /fs | grep nfs > /dev/null
	if [ $? -eq 0 ]; then
		mount /nfs
	fi
	if [ ! -d /fs/system ]; then
		echo "#### Shared filesystem is not mounted"
		exit 1
	else
		echo "Mounted /nfs"
	fi
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
# Stop if previous installation of WebSphere Plugin at the same version exists 
#------------------------------------------------------------------------------

if [ -d ${PLUGDESTDIR} ]; then
	echo "$PLUGDESTDIR directory already exists"
	echo "Remove previous installation and directories using the remove_plugin_v3.sh script before proceeding"
	exit 1
fi

#-----------------------------------------------------------------------
# Stop if Installation Manager has not been installed
#-----------------------------------------------------------------------

if [ ! -d $IMBASEDIR/eclipse/tools ]; then 
   echo "Installation Manager must be installed prior to installing WebSphere Plugin"
   echo "exiting...."
   exit 1
fi

#---------------------------------------------------------------
# Setup Plugins Filesystem
#---------------------------------------------------------------

echo "Setting up filesystems according to the EI standards for a WebSphere Application Server HTTP Plugin"
df -mP $PLUGDESTDIR > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Creating filesystem $PLUGDESTDIR"
    /fs/system/bin/eimkfs $PLUGDESTDIR 1024M $VG Plugins${VERSION}${EXTENSION}lv
    rm -R $PLUGDESTDIR/*
else
    fsize=`df -mP $PLUGDESTDIR|tail -1|awk '{split($2,s,"."); print s[1]}'`
    if [ "$fsize" -lt 1024 ]; then
        echo "Increasing $PLUGDESTDIR filesystem size to 1024MB"
        /fs/system/bin/eichfs $PLUGDESTDIR 1024M
    else
        echo "Filesystem $PLUGDESTDIR already larger than 1024MB, making no changes."
    fi
fi

#---------------------------------------------------------------------------
# Install based on platform----                                             
#---------------------------------------------------------------------------
case `uname` in 
    AIX) install_was_aix ;;
    Linux)
        case `uname -i` in
            ppc*)   install_was_linux_ppc ;;
            x86*)   install_was_linux_x86 ;;
        esac
    ;;
    *)
        echo "${0}: `uname` not supported by this install script."
        exit 1
    ;;
esac
set_install_properties

echo "----------------------------------------------------------------------"
echo " Installing WebSphere Application Server Plugin version: $FULLVERSION "
echo ""
echo " /tmp/IM_WASPluginInstall.log installation details and progress"
echo "----------------------------------------------------------------------"

$IMBASEDIR/eclipse/tools/imcl install $PACKAGE,$FEATURE -repositories $INSTDIR/repository.config -installationDirectory $PLUGDESTDIR -sharedResourcesDirectory $IMSHAREDDIR -log $LOGFILE -accessRights admin -acceptLicense

# Verify that something was installed
if [[ -f ${PLUGDESTDIR}/bin/mod_was_ap22_http.so ]]; then
   echo "Failed to install WebSphere Plugin $DOTVER.  Exiting...."
   exit 1
fi

echo "---------------------------------------------------------------"
echo " Installing WebSphere Application Server Plugin fixes          "
echo ""
echo "---------------------------------------------------------------"

let IDX=0 
for FIXPACKAGE in ${FIXPACKAGES[@]}
do
    REPOS=${FIXREPOSITORIES[${IDX}]}    
    echo "Installing fixpackage: ${FIXPACKAGE} at: ${REPOS}"
    ${TOOLSDIR}/was/setup/install_plugin_fixes_v3.sh was_version=${VERSION} fixpackage=${FIXPACKAGE} repository=${REPOS} wasinstnum=${INSTANCE} nostop=true
    if [ $? -ne 0 ]; then
	echo "Installation of fixpackage: ${FIXPACKAGE} at: ${REPOS} failed."
	echo "exiting...."
	exit 1
    fi
    let IDX="IDX += 1"
done

# The PLG.product will contain the $DOTVER requested after any fixpackages have been applied. 
PRODFILE="PLG.product"
echo "Checking $PRODFILE file for $DOTVER"
grep version\>${DOTVER} ${PLUGDESTDIR}/properties/version/${PRODFILE}
if [ $? -ne 0 ]; then 
    echo "Failed to install WebSphere Plugin $DOTVER.  Exiting...."
    exit 1
fi

#------------------------------------------------------------------------------------
#
#  Setup log directory
#
#------------------------------------------------------------------------------------

echo "---------------------------------------------------------------"
echo "Setting up WAS Plugin log directory according to the"
echo "  EI standards for an IHS webserver"
echo "---------------------------------------------------------------"
echo ""

# V85 does not create log directory during install since IM performs the install 
if [[ ! -d ${PLUGDESTDIR}/logs ]]; then
   mkdir ${PLUGDESTDIR}/logs 
fi

if [[ -d ${PLUGDESTDIR}/logs && ! -L ${PLUGDESTDIR}/logs ]]; then
   if [ ! -d ${PLUGLOGDIR} ]; then
      echo "    Creating ${PLUGLOGDIR}"
      mkdir -p ${PLUGLOGDIR}
      if [[ $? -gt 0 ]]; then
         echo "    Creation of WAS Plugin log directory"
         echo "      Failed"
         echo ""
         ERROR=1
      fi
   fi

   #Preserve the value of the EI_FILESYNC_NODR env variable
   #Set it to 1 for these syncs
   NODRYRUN_VALUE=`echo $EI_FILESYNC_NODR`
   export EI_FILESYNC_NODR=1

   if [[ -d ${PLUGLOGDIR} ]]; then
      echo "    Rsync over ${PLUGDESTDIR}/logs directory"
      ${TOOLSDIR}/configtools/filesync ${PLUGDESTDIR}/logs/ ${PLUGLOGDIR}/ avc 0 0
      if [[ $? -gt 0 ]]; then
         echo "    WAS Plugin log filesync"
         echo "      Failed"
         ERROR=1
      else
         echo ""
         echo "    Replacing ${PLUGDESTDIR}/logs "
         echo "      with a symlink to ${PLUGLOGDIR}"
         rm -r ${PLUGDESTDIR}/logs
         if [[ $? -gt 0 ]]; then
            echo "    Removal of old WAS Plugin log directory"
            echo "      Failed"
            error_message_plug 2 
         else
            ln -s ${PLUGLOGDIR} ${PLUGDESTDIR}/logs
            if [[ $? -gt 0 ]]; then
               echo "    Creation of link for WAS Plugin logs"
               echo "      Failed"
               error_message_plug 2
            fi
         fi
      fi
   fi
   echo ""
   #Restoring env variable EI_FILESYNC_NODR to previous value
   export EI_FILESYNC_NODR=$NODRYRUN_VALUE
elif [[ -L ${PLUGDESTDIR}/logs ]]; then
   echo "    This is not a fresh WAS Plugin install"
   echo "    Check script output for details"
   echo ""
   error_message_plug 2
else
   echo "    Can not find any WAS Plugin logs"
   echo "    Aborting the install"
   echo ""
   error_message_plug 2
fi

echo "---------------------------------------------------------------"
echo " Setting plugin permissions                                    "
echo "---------------------------------------------------------------"
#
${TOOLSDIR}/ihs/setup/ihs_perms_v3.sh plugin_level=${VERSION} plugininstnum=${INSTANCE} subproduct=plugin toolsdir=${TOOLSDIR}

echo ""
echo "---------------------------------------------------------------"
echo "       Running Plugin Installed Version Report"
echo "---------------------------------------------------------------"
echo ""
${TOOLSDIR}/ihs/setup/verify_versions_installed_v3.sh serverroot=${PLUGDESTDIR} product=plugin

echo ""
echo "----------------------------------------------------------------------"
echo " WebSphere Application Server Plugin version: $DOTVER installation    "
echo " was successful.                                  -------             "
echo ""
echo "----------------------------------------------------------------------"
exit 0
