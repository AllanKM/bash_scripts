#!/bin/bash

#----------------------------------------------------------------------------
# WebSphere eXtremeScale profile augmentation/de-augmentation   (run as sudo)
#----------------------------------------------------------------------------
#
#---------------------------------------------------------------
#
#  Change History: 
#
#  Lou Amodeo - 06/21/2013 - Initial creation
#
#
#---------------------------------------------------------------
#

# USAGE: augment_profile_wxs_86.sh was=<wasversion> [profiles=<name1>[,<name2>,<nameN>]] [unaugment] [nostop]

usage ()
{
  echo "Usage:"
  echo ""
  echo " $0 was=<wasversion> [profiles=<name1>[,<name2>,<nameN>]] [unaugment] [nostop]"
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

#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
        was=*)       VALUE=${1#*=}; if [ "$VALUE" != "" ];      then WASFULLVER=$VALUE;     fi ;;
        profiles=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ];      then PROFILES=$VALUE;       fi ;;
        unaugment)   VALUE=${1#*=}; if [ "$VALUE" != "" ];      then UNAUGMENT="unaugment"; fi ;;
        nostop)      VALUE=${1#*=}; if [ "$VALUE" != "" ];      then NOSTOP="nostop";       fi ;;
        *)  echo "#### Unknown argument: $1"
            echo "#### Usage: augment_profile_wxs_86.sh was=<wasversion> [profiles=<name1>[,<name2>,<nameN>]] [unaugment] [nostop]"
            exit 1
            ;;
    esac
    shift
done

WASVERSION=`echo $WASFULLVER | cut -c1-2`
if [ $WASVERSION == 70 -o $WASVERSION == 85 ]; then
   echo "Augmenting profile for WAS VERSION $WASFULLVER"
else
   echo "WAS VERSION $WASFULLVER is not supported"
   exit 1  
fi

if [ -z $PROFILES ]; then
    echo "At least one profile must be specified"
    exit 1
fi

BASEDIR="/usr/WebSphere${WASVERSION}"
APPDIR="${BASEDIR}/AppServer"
TOOLSDIR="/lfs/system/tools/wxs"

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

#---------------------------------------------------------------------------------
# Stop if WebSphere Application Server is not installed
#---------------------------------------------------------------------------------
if [ ! -d $APPDIR ]; then 
    echo "WebSphere Application Server must be installed prior to profile augmentation"
    echo "exiting...."
    exit 1
fi

#---------------------------------------------------------------------------------
# Stop if eXtremScale is not installed
#---------------------------------------------------------------------------------
if [ ! -e $APPDIR/properties/version/WXS.product ]; then 
    echo "WebSphere eXtremeScale is not installed at this WebSphere Application Server location: $APPDIR"
    echo "exiting...."
    exit 1
fi

#---------------------------------------------------------------------------------
# WebSphere must be stopped to install the WASCLIENT
#---------------------------------------------------------------------------------
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
    echo "Nostop was specified, proceeding with the assumption that WebSphere is stopped."
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

echo "---------------------------------------------"
if [ -z $UNAUGMENT ]; then
    AUGPARM="augment"
    IGNORESTACK=""
    echo "Augmenting profiles"
else
    AUGPARM="unaugment"
    IGNORESTACK=" -ignoreStack"
    echo "Unaugmenting profiles"
fi
echo "---------------------------------------------"
echo ""

PROFILEAUG=""
PROFILELIST=`echo $PROFILES | sed 's/,/ /g'`

for profile in $PROFILELIST
 do
   case $profile in
    *anager)
            profileType="management"
            ;;
    *-sa|*-sa[123])
            profileType="default"
            ;;
    *)
            profileType="managed"
            ;;
   esac
   
   if [ -d $APPDIR/profiles/$profile ]; then
      $APPDIR/bin/manageprofiles.sh -$AUGPARM $IGNORESTACK -templatePath $APPDIR/profileTemplates/xs_augment/$profileType -profileName $profile
      echo "Profile $AUGPARM completed for $profileType profile $profile"
      PROFILEAUG="true"
   else
      echo "Profile $profile does not exist, cannot $AUGPARM. Please specify a valid profile."
   fi
   
 done

#Set normal WAS permissions
if [ "$PROFILEAUG" == "true" ]; then
   /lfs/system/tools/was/setup/was_perms.ksh
fi

echo "---------------------------------------------------------------"
echo " WebSphere eXtremeScale profile augmentation/de-augmentation   "
echo " completed.                                                    "
echo ""
echo "---------------------------------------------------------------"
exit 0