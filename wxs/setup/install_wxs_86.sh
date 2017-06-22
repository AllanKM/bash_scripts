#!/bin/bash

#----------------------------------------------------------------------------
# WebSphere eXtremeScale 8.6.x.x install  (run as sudo)
#----------------------------------------------------------------------------
#
#---------------------------------------------------------------
#
#  Change History: 
#
#  Lou Amodeo - 06/18/2013 - Initial creation
#  Lou Amodeo - 08/02/2013 - Update for revised fixpack repository structure
#  Lou Amodeo - 12/03/2013 - Update for 8.6.0.4
#  Lou Amodeo - 05/21/2014 - Update for 8.6.0.4 iFix IFPI16288
#  Lou Amodeo - 04/13/2015 - Add support for 8.6.0.7 and WAS7CLIENT installs
#  Lou Amodeo - 09/03/2015 - Add support for 8.6.0.8
#
#
#---------------------------------------------------------------
#

# USAGE: install_wxs_86.sh wxs=<wxsversion> pkgtype=<CLIENT|WASCLIENT|WAS7CLIENT|STANDALONE> [was=<wasversion>] [augprofiles=<name1>[,<name2>,<nameN>]] [vg=<volumegroup>] [nostop] [sharedResourcesDirectory=<directory>]

usage ()
{
  echo "Usage:"
  echo ""
  echo " $0 wxs=<wxsversion> pkgtype=<CLIENT|WASCLIENT|WAS7CLIENT|STANDALONE> [was=<wasversion>] [augprofiles=<name1>[,<name2>,<nameN>]] [vg=<volumegroup>] [nostop] [sharedResourcesDirectory=<directory>]"
  echo ""
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

set_install_properties ()
{  
    INSTDIR="/fs/system/images/websphere/wxs/8.6/WXS_8602"
    
    if [ ${PKGTYPE} == "STANDALONE" ]; then 
          PACKAGE="com.ibm.websphere.WXS.v86"
    elif [ ${PKGTYPE} == "WASCLIENT" ]; then 
          PACKAGE="com.ibm.websphere.WXSCLIENT.was8.v86"
    elif [ ${PKGTYPE} == "WAS7CLIENT" ]; then 
          PACKAGE="com.ibm.websphere.WXSCLIENT.was7.v86"      
    elif [ ${PKGTYPE} == "CLIENT" ]; then 
          PACKAGE="com.ibm.websphere.WXSCLIENT.v86"
    else
       echo "Invalid Package type specified: ${PKGTYPE}"
       exit 1
    fi
 
#
# Note: We need a way to specify the package type for fixpacks and also a generic iFix package.
#       The process we will use is to add a PACKAGE placeholder for fixpacks and override during
#       the fixpack install later with $PACKAGE. For an iFix just use the iFix package name if it
#       turns out its different.  We won't know until we actually see one.
#
    if [ "$FULLVERSION" == "86020" ]; then
        DOTVER="8.6.0.2"
        FIXPACKAGES=()
        FIXREPOSITORIES=()
    elif [ "$FULLVERSION" == "86030" ]; then          
          DOTVER="8.6.0.3"
          FIXPACKAGES=("PACKAGE")
          FIXREPOSITORIES=("/fs/system/images/websphere/wxs/8.6/fixes/WXS_8603/$PKGTYPE/8603")
    elif [ "$FULLVERSION" == "86040" ]; then          
          DOTVER="8.6.0.4"
          FIXPACKAGES=("PACKAGE" "8.6.0.4-WS-WXSAll-IFPI16288")
          FIXREPOSITORIES=("/fs/system/images/websphere/wxs/8.6/fixes/WXS_8604/$PKGTYPE/8604" "/fs/system/images/websphere/wxs/8.6/fixes/8.6.0.4-WS-WXSAll-IFPI16288.zip")
    elif [ "$FULLVERSION" == "86070" ]; then          
          DOTVER="8.6.0.7"
          FIXPACKAGES=("PACKAGE")
          FIXREPOSITORIES=("/fs/system/images/websphere/wxs/8.6/fixes/WXS_8607/$PKGTYPE/8607")
    elif [ "$FULLVERSION" == "86080" ]; then          
          DOTVER="8.6.0.8"
          FIXPACKAGES=("PACKAGE")
          FIXREPOSITORIES=("/fs/system/images/websphere/wxs/8.6/fixes/WXS_8608/$PKGTYPE/8608")
    else
        echo "Not configured to install WebSphere eXtremeScale version $FULLVERSION"
        echo "exiting..."
        exit 1
    fi
}

#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
        wxs=*)         VALUE=${1#*=}; if [ "$VALUE" != "" ];      then FULLVERSION=$VALUE; fi ;;
        was=*)         VALUE=${1#*=}; if [ "$VALUE" != "" ];      then WASFULLVER=$VALUE;  fi ;;
        pkgtype=*)     VALUE=${1#*=}; if [ "$VALUE" != "" ];      then PKGTYPE=$VALUE;     fi ;;
        vg=*)          VALUE=${1#*=}; if [ "$VALUE" != "" ];      then VG=$VALUE;          fi ;;
        augprofiles=*) VALUE=${1#*=}; if [ "$VALUE" != "" ];      then PROFILES=$VALUE;    fi ;;
        nostop)        VALUE=${1#*=}; if [ "$VALUE" != "" ];      then NOSTOP="nostop";    fi ;;
        sharedResourcesDirectory=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SHAREDRESDIR="$VALUE"; fi ;;
        *)  echo "#### Unknown argument: $1"
            echo "#### Usage: install_wxs_86.sh wxs=<wxsversion> pkgtype=<CLIENT|WASCLIENT|WAS7CLIENT|STANDALONE> [was=<wasversion>] [augprofiles=<name1>[,<name2>,<nameN>]] [vg=<volumegroup>] [nostop] [sharedResourcesDirectory=<directory>]"
            exit 1
            ;;
    esac
    shift
done

VERSION=`echo $FULLVERSION | cut -c1-2`
if [ ! $VERSION == 86 ]; then
    echo "WXS VERSION $FULLVERSION must be 8.6 or higher"
    exit 1
fi

if [ "$PKGTYPE" != "CLIENT" -a "$PKGTYPE" != "WASCLIENT" -a "$PKGTYPE" != "WAS7CLIENT" -a "$PKGTYPE" != "STANDALONE" ]; then
    echo "Invalid package type of ${PKGTYPE} was found. Specifiy a valid package type."
    exit 1
fi

if [ "$PKGTYPE" == "WASCLIENT" -a -z "$WASFULLVER" ]; then
   echo "WebSphere Application Server version must be specified for a WASCLIENT package install.  Specifiy was="
   exit 1
fi

if [ "$PKGTYPE" == "WAS7CLIENT" -a -z "$WASFULLVER" ]; then
   echo "WebSphere Application Server version must be specified for a WAS7CLIENT package install.  Specifiy was="
   exit 1
fi

WASVERSION=`echo $WASFULLVER | cut -c1-2`
if [ "$PKGTYPE" == "WASCLIENT" ]; then
   if [ ! $WASVERSION == 85 ]; then
       echo "WAS VERSION $WASFULLVER must be 8.5 or higher"
       exit 1
   fi
fi
if [ "$PKGTYPE" == "WAS7CLIENT" ]; then
   if [ ! $WASVERSION == 70 ]; then
       echo "WAS VERSION $WASFULLVER must be 7.0 for the WAS7 Client"
       exit 1
   fi
fi

VG=${VG:-appvg1}
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

if [ "$PKGTYPE" == "WASCLIENT" -o "$PKGTYPE" == "WAS7CLIENT" ]; then
    BASEDIR="/usr/WebSphere${WASVERSION}"
    APPDIR="${BASEDIR}/AppServer"
    INSTVERSION=${WASVERSION}
else
    BASEDIR="/usr/WebSphere${VERSION}"
    APPDIR="${BASEDIR}/eXtremeScale"
    INSTVERSION=${VERSION}
fi

IMBASEDIR="/opt/IBM/InstallationManager"

if [ -z "$SHAREDRESDIR" ]; then
    IMSHAREDDIR="/usr/IMShared"
else
    IMSHAREDDIR="${SHAREDRESDIR}"
fi

TOOLSDIR="/lfs/system/tools/was"
LOGFILE="/tmp/IM_WXSINSTALL.log"

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

#-----------------------------------------------------------------------
# Stop if Installation Manager has not been installed
#-----------------------------------------------------------------------

if [ ! -d $IMBASEDIR/eclipse/tools ]; then 
   echo "Installation Manager must be installed prior to installing WebSphere eXtremeScale"
   echo "exiting...."
   exit 1
fi

#-----------------------------------------------------------------------
# Stop if previous installation exists at the same version exists
#-----------------------------------------------------------------------
if [ ${PKGTYPE} == "STANDALONE" -o ${PKGTYPE} == "CLIENT" ]; then
    if [ -d ${APPDIR} ]; then
        echo "$APPDIR directory already exists"
        echo "Remove previous installation and directories using the remove_wxs_86.sh script before proceeding"
        exit 1
    fi
fi

#---------------------------------------------------------------------------------
# Stop if installing a WASCLIENT and WebSphere Application Server is not installed
#---------------------------------------------------------------------------------
if [ ${PKGTYPE} == "WASCLIENT" -o ${PKGTYPE} == "WAS7CLIENT" ]; then 
    if [ ! -d $APPDIR ]; then 
       echo "WebSphere Application Server must be installed prior to installing WebSphere eXtremeScale WAS Client"
       echo "exiting...."
       exit 1
    fi
fi

#---------------------------------------------------------------------------------
# Stop if installing a WASCLIENT and eXtremScale is already installed
#---------------------------------------------------------------------------------
if [ ${PKGTYPE} == "WASCLIENT" -o ${PKGTYPE} == "WAS7CLIENT" ]; then 
    if [ -d $APPDIR/properties/version/WXS.product ]; then 
       echo "WebSphere eXtremeScale is already installed at this WebSphere Application Server location: $APPDIR"
       echo "exiting...."
       exit 1
    fi
fi

#---------------------------------------------------------------------------------
# WebSphere must be stopped to install the WASCLIENT
#---------------------------------------------------------------------------------
if [ ${PKGTYPE} == "WASCLIENT" -o ${PKGTYPE} == "WAS7CLIENT" ]; then
    if [ -z "$NOSTOP" ]; then
        if [ -d ${APPDIR} ]; then
            echo "Executing: \"rc.was stop all\""
            if [ -f /lfs/system/tools/was/bin/rc.was ]; then
                /lfs/system/tools/was/bin/rc.was stop all
            fi
        else
            echo "Failed to locate $APPDIR, exiting..."
            exit
        fi
    else
        echo "NoStop was specified, proceeding with the assumption that WebSphere is stopped."
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

#---------------------------------------------------------------
# Setup Filesystems
#---------------------------------------------------------------

if [ "$PKGTYPE" == "STANDALONE" -o  "$PKGTYPE" == "CLIENT"  ]; then
    echo "Setting up filesystems according to the EI standards for WebSphere eXtremeScale"
    df -mP $APPDIR > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Creating filesystem $APPDIR"
        /fs/system/bin/eimkfs $APPDIR 2048M $VG wxs${VERSION}lv
        rm -R $APPDIR/*
    else
        fsize=`df -mP $APPDIR|tail -1|awk '{split($2,s,"."); print s[1]}'`
        if [ "$fsize" -lt 2048 ]; then
            echo "Increasing $APPDIR filesystem size to 2048MB"
            /fs/system/bin/eichfs $APPDIR 2048M
        else
            echo "Filesystem $APPDIR already larger than 2048MB, making no changes."
        fi
    fi
fi

fsize=`df -mP /tmp|tail -1|awk '{split($2,s,"."); print s[1]}'`
if [ "$fsize" -lt 1024 ]; then
    echo "Increasing /tmp filesystem size to 1024MB"
    /fs/system/bin/eichfs /tmp 1024M
else
    echo "Filesystem /tmp already larger than 1024MB, making no changes."
fi

df -mP /projects > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Creating filesystem /projects"
    /fs/system/bin/eimkfs /projects 1024M $VG
else
    fsize=`df -mP /projects|tail -1|awk '{split($2,s,"."); print s[1]}'`
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

echo "----------------------------------------------------------------------------"
echo " Installing WebSphere eXtremeScale version: $FULLVERSION "
echo
echo " /tmp/IM_WXSINSTALL.log installation details and progress"
echo "----------------------------------------------------------------------------"

$IMBASEDIR/eclipse/tools/imcl install $PACKAGE -repositories $INSTDIR/repository.config -installationDirectory $APPDIR -sharedResourcesDirectory $IMSHAREDDIR -log $LOGFILE -accessRights admin -acceptLicense

# The WXS.product will contain 8.6.0.2 after the base level has been installed. 
PRODFILE="WXS.product"
echo "Checking $PRODFILE file for 8.6.0.2"
grep version\>8.6.0.2 ${APPDIR}/properties/version/${PRODFILE}
if [ $? -ne 0 ]; then 
    echo "Failed to install WebSphere eXtremeScale 8.6.0.2.  Exiting...."
    exit 1
fi

echo "---------------------------------------------------------------"
echo " Installing WebSphere WebSphere eXtremeScale fixes             "
echo ""
echo "---------------------------------------------------------------"

let IDX=0 
for FIXPACKAGE in ${FIXPACKAGES[@]}
do
    REPOS=${FIXREPOSITORIES[${IDX}]}
    if [ "$FIXPACKAGE" == "PACKAGE" ]; then
        FIXPACKAGE=$PACKAGE
    fi
    echo "Installing fixpackage: ${FIXPACKAGE} at: ${REPOS}"
    /lfs/system/tools/wxs/setup/install_wxs_fixpack_86.sh wxs=$VERSION was=$WASVERSION package=$FIXPACKAGE pkgtype=$PKGTYPE repos=$REPOS
    if [ $? -ne 0 ]; then
	echo "Installation of fixpackage: ${FIXPACKAGE} at: ${REPOS} failed."
	echo "exiting...."
	exit 1
    fi
    let IDX="IDX += 1"
done

# The WXS.product will contain the $DOTVER requested after fix packages have been applied. 
echo "Checking $PRODFILE file for $DOTVER"
grep version\>${DOTVER} ${APPDIR}/properties/version/${PRODFILE}
if [ $? -ne 0 ]; then 
    echo "Failed to install WebSphere eXtremeScale $DOTVER.  Exiting...."
    exit 1
fi

echo "---------------------------------------------------------------"
echo " Redirecting Logs: ${APPDIR}/logs                              "
echo "             To: /logs/wxs${VERSION}                           "
echo ""
echo "---------------------------------------------------------------"

if [ "$PKGTYPE" == "STANDALONE"  ]; then    
    WXSLOGS="/logs/wxs${VERSION}"   
    if [[ ! -d $WXSLOGS ]]; then
        echo "Creating $WXSLOGS"
        mkdir $WXSLOGS
        chown webinst.eiadm $WXSLOGS
        chmod u+rwx,g+rwsx,o-rwx $WXSLOGS
    fi
    ln -s $WXSLOGS ${APPDIR}/logs
    chmod g+s $APPDIR $WXSLOGS    
fi

#Set normal WAS permissions
/lfs/system/tools/was/setup/was_perms.ksh

# Augment WebSphere profiles if requested
if [ "$PKGTYPE" == "WASCLIENT" -o  "$PKGTYPE" == "WAS7CLIENT" ]; then
    if [ ! -z "$PROFILES" ]; then
        /lfs/system/tools/wxs/setup/augment_profile_wxs_86.sh was=$WASVERSION profiles=$PROFILES nostop
    fi
fi

echo "---------------------------------------------------------------"
echo " WebSphere eXtremeScale $PKGTYPE version: $DOTVER installation "
echo " was successful.                                               "
echo ""
echo "---------------------------------------------------------------"
exit 0
