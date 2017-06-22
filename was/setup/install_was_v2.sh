#!/bin/bash 

#---------------------------------------------------------------
# WebSphere Application Server 8.5.x.x install  (run as sudo)   
#---------------------------------------------------------------
#
#---------------------------------------------------------------
#
#  Change History: 
#
#  Lou Amodeo - 03/01/2013 - Initial creation
#  Lou Amodeo - 12/02/2013 - Add 8.5.5.1 fixpack
#  Lou Amodeo - 04/29/2014 - Add 8.5.5.2 fixpack
#  Lou Amodeo - 01/08/2015 - Add 8.5.5.4 fixpack
#  Lou Amodeo - 09/03/2015 - Add 8.5.5.6 fixpack
#
#
#---------------------------------------------------------------
#

# USAGE: install_was_v2.sh [VERSION] [PROFILE] [VOLUMEGROUP]

# Which version of WAS is to be installed

function usage {
  echo "Usage:"
  echo ""
  echo " $0 [VERSION] [PROFILE] [VOLUMEGROUP]"
  echo ""
}
FULLVERSION=${1:-85500}
# If this install is for a Deployment Manager then provide the DM name as the second argument

VG=${3:-appvg1}
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

VERSION=`echo $FULLVERSION | cut -c1-2`
if [ ! $VERSION -eq 85 ]; then
    echo "VERSION $FULLVERSION must be 8.5 or higher"
    exit 1
fi

BASEDIR="/usr/WebSphere${VERSION}"
IMBASEDIR="/opt/IBM/InstallationManager"
#WebSphere installation package groups shared artifacts will be installed in the std IMShared filesystem.
IMSHAREDDIR="/usr/IMShared"
APPDIR="${BASEDIR}/AppServer"
TOOLSDIR="/lfs/system/tools/was"
LOGFILE="/tmp/IM_WASINSTALL.log"
HOST=`/bin/hostname -s`
NOPROFILE="false"

case $2 in
	*anager)
				PROFILE=$2
				#Set DMGR to yzt85ps instead of yzt85psManager ( remove Manager )
				DMGR=${PROFILE%%Manager}
			;;
	*)
				if [ "$2" == "" ]; then
					PROFILE=$HOST
				elif [ "$2" == "--no-profile" ]; then
					NOPROFILE="true"
				elif [ "$2" == "$HOST" ]; then
					PROFILE=$2
				else
					PROFILE=${HOST}_${2}									
				fi
			;;
esac

set_install_properties ()
{  
    INSTDIR="/fs/system/images/websphere/8.5/base"
    PACKAGE="com.ibm.websphere.ND.v85"
     
    if [ "$FULLVERSION" == "85000" ]; then
        DOTVER="8.5.0.0"
        FIXPACKAGES=()
        FIXREPOSITORIES=()
    elif [ "$FULLVERSION" == "85001" ]; then
        DOTVER="8.5.0.1"
        FIXPACKAGES=("com.ibm.websphere.ND.v85" "8.5.0.1-WS-WAS-IFPM77213")
        FIXREPOSITORIES=("/fs/system/images/websphere/8.5/fixes/85001/base" "/fs/system/images/websphere/8.5/ifixes/ifpm77213") 
    elif [ "$FULLVERSION" == "85500" ]; then
        DOTVER="8.5.5.0"
        FIXPACKAGES=("com.ibm.websphere.ND.v85")
        FIXREPOSITORIES=("/fs/system/images/websphere/8.5/fixes/85500/base")
    elif [ "$FULLVERSION" == "85501" ]; then
        DOTVER="8.5.5.1"
        FIXPACKAGES=("com.ibm.websphere.ND.v85")
        FIXREPOSITORIES=("/fs/system/images/websphere/8.5/fixes/85501/base")
    elif [ "$FULLVERSION" == "85502" ]; then
        DOTVER="8.5.5.2"
        FIXPACKAGES=("com.ibm.websphere.ND.v85")
        FIXREPOSITORIES=("/fs/system/images/websphere/8.5/fixes/85502/base")
    elif [ "$FULLVERSION" == "85504" ]; then
        DOTVER="8.5.5.4"
        FIXPACKAGES=("com.ibm.websphere.ND.v85")
        FIXREPOSITORIES=("/fs/system/images/websphere/8.5/fixes/85504/base")
    elif [ "$FULLVERSION" == "85506" ]; then
        DOTVER="8.5.5.6"
        FIXPACKAGES=("com.ibm.websphere.ND.v85")
        FIXREPOSITORIES=("/fs/system/images/websphere/8.5/fixes/85506/base")
    else
        echo "Not configured to install WAS version $FULLVERSION"
        echo "exiting..."
        exit 1
    fi
}

install_was_aix ()
{  
    OSDIR="aix"
}

install_was_linux_x86 ()
{
    #java -version hangs on SLES 9 unless the following ulimit command is executed
    # as mentioned at http://www-1.ibm.com/support/docview.wss?uid=swg21182138
    ulimit -s 8196    
    OSDIR="linux"
}

install_was_linux_ppc ()
{
    #java -version hangs on SLES 9 unless the following ulimit command is executed
    # as mentioned at http://www-1.ibm.com/support/docview.wss?uid=swg21182138
    ulimit -s 8196
    OSDIR="linuxppc"
}

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

#---------------------------------------------------------------
# IDs
#---------------------------------------------------------------

id webinst > /dev/null 2>&1
if [  $? -ne 0 ]; then
    /fs/system/tools/auth/bin/mkeigroup -r local -f apps
    /fs/system/tools/auth/bin/mkeigroup -r local -f mqm
    /fs/system/tools/auth/bin/mkeiuser  -r local -f webinst apps
    /usr/sbin/usermod -g mqm webinst
fi

#-----------------------------------------------------------------------
# Stop if previous installation of WebSphere at the same version exists
#-----------------------------------------------------------------------

if [ -d ${APPDIR} ]; then
	echo "$APPDIR directory already exists"
	echo "Remove previous installation and directories using the remove_was_v2.sh script before proceeding"
	exit 1
fi

#-----------------------------------------------------------------------
# Stop if Installation Manager has not been installed
#-----------------------------------------------------------------------

if [ ! -d $IMBASEDIR/eclipse/tools ]; then 
   echo "Installation Manager must be installed prior to installing WebSphere"
   echo "exiting...."
   exit 1
fi

#---------------------------------------------------------------
# Setup Filesystems
#---------------------------------------------------------------

echo "Setting up filesystems according to the EI standards for a WebSphere Application Server"
df -m $BASEDIR > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Creating filesystem $BASEDIR"
	/fs/system/bin/eimkfs $BASEDIR 4192M $VG WAS${VERSION}lv
else
	fsize=`df -Pm $BASEDIR|tail -1|awk '{split($2,s,"."); print s[1]}'`
	if [ "$fsize" -lt 4192 ]; then
		echo "Increasing $BASEDIR filesystem size to 4192MB"
		/fs/system/bin/eichfs $BASEDIR 4192M
	else
		echo "Filesystem $BASEDIR already larger than 4192MB, making no changes."
	fi
fi

if [[ ! -d /logs/was${VERSION} ]]; then 
    mkdir /logs/was${VERSION}
fi

fsize=`df -Pm /tmp|tail -1|awk '{split($2,s,"."); print s[1]}'`
if [ "$fsize" -lt 1024 ]; then
	echo "Increasing /tmp filesystem size to 1024MB"
	/fs/system/bin/eichfs /tmp 1024M
else
	echo "Filesystem /tmp already larger than 1024MB, making no changes."
fi

df -m /projects > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Creating filesystem /projects"
	/fs/system/bin/eimkfs /projects 1024M $VG
else
	fsize=`df -Pm /projects|tail -1|awk '{split($2,s,"."); print s[1]}'`
	if [ "$fsize" -lt 1024 ]; then
		echo "Increasing /projects filesystem size to 1024MB"
		/fs/system/bin/eichfs /projects 1024M
	else
		echo "Filesystem /projects already larger than 1024MB, making no changes."
	fi
fi

case `uname` in 
	AIX) install_was_aix ;;
	Linux)
		case `uname -i` in
			ppc*)	install_was_linux_ppc ;;
			x86*)	install_was_linux_x86 ;;
		esac
	;;
	*)
		echo "${0}: `uname` not supported by this install script."
		exit 1
	;;
esac
set_install_properties

echo "---------------------------------------------------------------"
echo " Installing WebSphere Application Server version: $FULLVERSION "
echo
echo " /tmp/IM_WASINSTALL.log installation details and progress"
echo "---------------------------------------------------------------"

$IMBASEDIR/eclipse/tools/imcl install $PACKAGE -repositories $INSTDIR/repository.config -installationDirectory $APPDIR -sharedResourcesDirectory $IMSHAREDDIR -log $LOGFILE -accessRights admin -acceptLicense

# The WAS.product will contain 8.5.5.0 after the base level has been installed. 
PRODFILE="WAS.product"
echo "Checking $PRODFILE file for 8.5.0.0"
grep version\>8.5.0.0 ${APPDIR}/properties/version/${PRODFILE}
if [ $? -ne 0 ]; then 
    echo "Failed to install base WebSphere 8.5.0.0.  Exiting...."
    exit 1
fi

echo "---------------------------------------------------------------"
echo " Installing WebSphere Application Server fixes                 "
echo 
echo "---------------------------------------------------------------"

let IDX=0 
for FIXPACKAGE in ${FIXPACKAGES[@]}
do
    REPOS=${FIXREPOSITORIES[${IDX}]}    
    echo "Installing fixpackage: ${FIXPACKAGE} at: ${REPOS}"     
    /lfs/system/tools/was/setup/install_was_fixpack_v2.sh $VERSION $FIXPACKAGE $REPOS    
    if [ $? -ne 0 ]; then
	echo "Installation of fixpackage: ${FIXPACKAGE} at: ${REPOS} failed."
	echo "exiting...."
	exit 1
    fi
    let IDX="IDX += 1"
done

# The WAS.product will contain the $DOTVER requested after fix packages have been applied. 
PRODFILE="WAS.product"
echo "Checking $PRODFILE file for $DOTVER"
grep version\>${DOTVER} ${APPDIR}/properties/version/${PRODFILE}
if [ $? -ne 0 ]; then 
    echo "Failed to install WebSphere $DOTVER.  Exiting...."
    exit 1
fi

echo "---------------------------------------------------------------"
echo " Redirecting Logs: ${APPDIR}/logs                              "
echo "             To: /logs/was${VERSION}                           "  
echo
echo "---------------------------------------------------------------"  

mv ${APPDIR}/logs ${APPDIR}/logs.orig
ln -s /logs/was${VERSION} ${APPDIR}/logs
chmod g+s $BASEDIR /logs/was${VERSION}
mv ${APPDIR}/logs.orig/* /logs/was${VERSION}
rm -fr ${APPDIR}/logs.orig

# Create Profile if requested.
if [ $NOPROFILE == "true" ]; then
     echo "---------------------------------------------------------------"
     echo " Skipping profile creation                                     "
     echo 
     echo "---------------------------------------------------------------" 
     /lfs/system/tools/was/setup/was_perms.ksh   
else
     echo "---------------------------------------------------------------"
     echo " Creating  $PROFILE profile "
     echo
     echo "---------------------------------------------------------------"    
     #create_profile.sh will set file permissions, ownership, and redirect logs.
     /lfs/system/tools/was/setup/create_profile.sh $VERSION $PROFILE     

     # The profileRegistry.xml will contain the $PROFILE if manageprofiles.sh completed successfully. 
     echo "Checking profileRegistry.xml file for $PROFILE"
     grep name=\"$PROFILE\" ${APPDIR}/properties/profileRegistry.xml
     if [ $? -ne 0 ]; then 
          echo "Failed to create the profile for $PROFILE.  Exiting...."
          exit 1
     fi
fi

echo "---------------------------------------------------------------"
echo " WebSphere Application Server version: $DOTVER installation    "
echo " was successful.                                               "
echo
echo "---------------------------------------------------------------"
exit 0
