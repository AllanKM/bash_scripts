#!/bin/bash 

#------------------------------------------------------------------------
# Java 7 for WebSphere Application Server 8.5.x.x install  (run as sudo) 
#------------------------------------------------------------------------
#
#---------------------------------------------------------------
#
#  Change History: 
#
#  Lou Amodeo - 03/29/2013 - Initial creation
#  Lou Amodeo - 12/02/2013 - Add 7.0.5.0 fixpack
#  Lou Amodeo - 04/29/2014 - Add 7.0.6.1 fixpack
#  Lou Amodeo - 01/08/2015 - Add 7.0.8.0 fixpack
#  Lou Amodeo - 09/03/2015 - Add 7.0.9.0 fixpack
#
#
#---------------------------------------------------------------
#

# USAGE: install_was_java7.sh WAS_VERSION JAVA_VERSION [PROFILE]

# Which version of Java 7 is to be installed

function usage {
  echo "Usage:"
  echo ""
  echo " $0 WAS_VERSION JAVA_VERSION [PROFILE]"
  echo ""
}

FULLWASVERSION=${1:-85500}
WASVERSION=`echo $FULLWASVERSION | cut -c1-2`
if [ ! $WASVERSION -eq 85 ]; then
    echo "Websphere VERSION $FULLWASVERSION must be 8.5.x.xx or higher"
    exit 1
fi

FULLVERSION=${2:-7041}
VERSION=`echo $FULLVERSION | cut -c1-4`
if [ ! $VERSION -gt 7000 ]; then
    echo "Java 7 VERSION $FULLVERSION must be 7.0.1.0 or higher"
    exit 1
fi

BASEDIR="/usr/WebSphere${WASVERSION}"
IMBASEDIR="/opt/IBM/InstallationManager"
#WebSphere java installation package groups shared artifacts will be installed in the std IMShared filesystem.
IMSHAREDDIR="/usr/IMShared"
APPDIR="${BASEDIR}/AppServer"
INSTALLDIR="${APPDIR}/java_1.7_64"
TOOLSDIR="/lfs/system/tools/was"
LOGFILE="/tmp/IM_J7INSTALL.log"
HOST=`/bin/hostname -s`
NOPROFILE="false"

case $3 in
	*anager)
              PROFILE=$3
              #Set DMGR to yzt85ps instead of yzt85psManager ( remove Manager )
              DMGR=${PROFILE%%Manager}
            ;;
    *-sa|*-sa[123])
              PROFILE=$HOST
              STANDALONE=$PROFILE
            ;;
    *)
              if [ "$3" == "" ]; then
                    PROFILE=$HOST
              elif [ "$3" == "$HOST" ]; then
                    PROFILE=$3
              else
                    PROFILE=${HOST}_${3}
              fi
              FED=$PROFILE
           ;;
esac

set_install_properties ()
{   
    INSTDIR="/fs/system/images/websphere/8.5/java7"
    PACKAGE="com.ibm.websphere.IBMJAVA.v70"
    
    if [ "$FULLVERSION"   == "7010" ]; then
        DOTVER="7.0.1.0"
        FIXPACKAGES=()
        FIXREPOSITORIES=()
    elif [ "$FULLVERSION" == "7041" ]; then
        DOTVER="7.0.4.1"
        FIXPACKAGES=("com.ibm.websphere.IBMJAVA.v70")
        FIXREPOSITORIES=("/fs/system/images/websphere/8.5/fixes_java7/${FULLVERSION}")
    elif [ "$FULLVERSION" == "7050" ]; then
        DOTVER="7.0.5.0"
        FIXPACKAGES=("com.ibm.websphere.IBMJAVA.v70")
        FIXREPOSITORIES=("/fs/system/images/websphere/8.5/fixes_java7/${FULLVERSION}")
    elif [ "$FULLVERSION" == "7061" ]; then
        DOTVER="7.0.6.1"
        FIXPACKAGES=("com.ibm.websphere.IBMJAVA.v70")
        FIXREPOSITORIES=("/fs/system/images/websphere/8.5/fixes_java7/${FULLVERSION}")
    elif [ "$FULLVERSION" == "7080" ]; then
        DOTVER="7.0.8.0"
        FIXPACKAGES=("com.ibm.websphere.IBMJAVA.v70")
        FIXREPOSITORIES=("/fs/system/images/websphere/8.5/fixes_java7/${FULLVERSION}")
    elif [ "$FULLVERSION" == "7090" ]; then
        DOTVER="7.0.9.0"
        FIXPACKAGES=("com.ibm.websphere.IBMJAVA.v70")
        FIXREPOSITORIES=("/fs/system/images/websphere/8.5/fixes_java7/${FULLVERSION}")
    else
       echo "Not configured to install Java 7 version $FULLVERSION"
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

if [ -d ${INSTALLDIR} ]; then
    echo "Java 7 is already installed at ${INSTALLDIR}"
    exit 1
fi

#-----------------------------------------------------------------------
# Make sure at least 2 GB is available in $BASEDIR filesystem
#-----------------------------------------------------------------------

fsize=`df -mP $BASEDIR|tail -1|awk '{split($3,s,"."); print s[1]}'`
if [ "$fsize" -lt 2048 ]; then
    let size=(2048-$fsize) 
	echo "Increasing $BASEDIR filesystem size by ${size}MB to 2048MB"
	/fs/system/bin/eichfs $BASEDIR +$size"M"
else
	echo "Filesystem $BASEDIR has $fsize MB free , making no changes."
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
		 "${0}: `uname` not supported by this install script."
		exit 1
	;;
esac
set_install_properties

echo "--------------------------------------------------------------------------"
echo " Installing Java 7 version: $DOTVER"
echo ""
echo " /tmp/IM_J7INSTALL.log installation details and progress"
echo "--------------------------------------------------------------------------"

$IMBASEDIR/eclipse/tools/imcl install $PACKAGE -repositories $INSTDIR/repository.config -installationDirectory $APPDIR -sharedResourcesDirectory $IMSHAREDDIR -log $LOGFILE -accessRights admin -acceptLicense

echo "Checking for: IBM_Runtime_Environment_Java_Technology_Edition.1.7.0.swtag file"
grep ProductVersion\>1.7.0 ${INSTALLDIR}/properties/version/IBM_Runtime_Environment_Java_Technology_Edition.1.7.0.swtag
if [ $? -ne 0 ]; then 
    echo "Failed to install base Java 7 version: $IMVERSION.  Exiting...."
    exit 1
fi

/lfs/system/tools/was/setup/was_perms.ksh

echo "---------------------------------------------------------------"
echo " Enable WebSphere configuration to use Java 7                  "
echo "---------------------------------------------------------------"
echo

#   Rules:
#          DMGR:       DMGR Must be stopped
#          Fed Node :  DMGR must be running
#                      Fed node must be stopped
#                      syncNode required post-install
#          Standalone: Server Must be stopped
#

if [ -d ${APPDIR}/profiles/${PROFILE} ]; then
    if [ -n "$DMGR" ]; then
         echo "Stopping the deployment manager"
         /lfs/system/tools/was/bin/rc.was --noprompt stop dmgr
    else
         if [ -n "$STANDALONE" ]; then
             echo "Stopping the standalone application server"
             /lfs/system/tools/was/bin/rc.was --noprompt stop all
         else
             echo "Stopping the node"
             echo "The deployment manager must be running if this node has already been federated" 
             /lfs/system/tools/was/bin/rc.was --noprompt stop all
         fi
    fi
fi

#
#  Note: I suspect a bug in the Java 7 install process. I think 
#        it requires a node sync immediately after the Java7 
#        install prior to the managesdk.sh -enableProfile.
#
#       This occurs in the scenario where you have a pre-existing
#       federated node that you are switching to Java 7.
#       It does not occur for a managed node prior to federation.
#
#       This node sync resolves the following error:
#
#CWSDK0009E: Unexpected exception com.ibm.websphere.management.exception.AdminException: com.ibm.websphere.management.exception.AdminException:
#CWLCA0012E: The sdk 1.7_64 is not available on node z10016 CWSDK1018I: Profile z10016 could not be enabled to use SDK 1.7_64. 
# CWSDK1002I: The requested managesdk task failed. See previous messages.
#

if [ -d ${APPDIR}/profiles/${PROFILE} ]; then
    if [ -n "$FED" ]; then
        echo "---------------------------------------------------------------"
        echo " Performing post-install node sync on federated node           "
        echo "---------------------------------------------------------------"
        echo ""
        cellName=`grep WAS_CELL= ${APPDIR}/profiles/${PROFILE}/bin/setupCmdLine.sh | cut -d= -f2`
        result=`su - webinst -c "${APPDIR}/bin/syncNode.sh ${cellName}Manager" 2>&1`
        echo $result
    fi
fi

echo "---------------------------------------------------------------"
echo " Enabling Java 7 for profile: ${PROFILE}"
echo "---------------------------------------------------------------"

if [ -d ${APPDIR}/profiles/${PROFILE} ]; then
    result=`su - webinst -c "${APPDIR}/bin/managesdk.sh -enableProfile -profileName ${PROFILE} -sdkname 1.7_64 -enableServers"  2>&1`
    echo $result
    if [[ `echo ${result}|grep CWSDK1017I` == "" ]]; then
        echo "managesdk.sh failed to enableProfile"
        exit 1 
    fi
else
    echo " Skipping profile enablement. Profile ${PROFILE} does not exist"
fi

result=`su - webinst -c "${APPDIR}/bin/managesdk.sh -setNewProfileDefault -sdkname 1.7_64" 2>&1`
result=`su - webinst -c "${APPDIR}/bin/managesdk.sh -getNewProfileDefault" 2>&1`
echo $result
if [[ `echo ${result}|grep CWSDK1007I` == "" ]]; then
    echo "WARNING: managesdk.sh failed to setNewProfileDefault"
fi

result=`su - webinst -c "${APPDIR}/bin/managesdk.sh -setCommandDefault -sdkname 1.7_64" 2>&1`
result=`su - webinst -c "${APPDIR}/bin/managesdk.sh -getCommandDefault" 2>&1`
echo $result
if [[ `echo ${result}|grep CWSDK1006I` == "" ]]; then
    echo "WARNING: managesdk.sh failed to setCommandDefault"
fi

echo "---------------------------------------------------------------"
echo " Installing Java 7 fixes                                       "
echo ""
echo "---------------------------------------------------------------"

let IDX=0 
for FIXPACKAGE in ${FIXPACKAGES[@]}
do
    REPOS=${FIXREPOSITORIES[${IDX}]}    
    echo "Installing fixpackage: ${FIXPACKAGE} from: ${REPOS}"
    /lfs/system/tools/was/setup/install_was_java7_fixpack.sh $WASVERSION $FIXPACKAGE $REPOS    
    if [ $? -ne 0 ]; then
	     echo "Installation of fixpackage: ${FIXPACKAGE} at: ${REPOS} failed."
	     echo "exiting...."
	     exit 1
    fi
    let IDX="IDX += 1"
done

# The IBMJAVA7.product will contain the $DOTVER requested after fix packages have been applied. 
PRODFILE="IBMJAVA7.product"
echo "Checking $PRODFILE file for $DOTVER"
grep version\>${DOTVER} ${APPDIR}/properties/version/${PRODFILE}
if [ $? -ne 0 ]; then 
    echo "Failed to install requested Java 7 version: ${DOTVER}.  Exiting...."
    exit 1
fi

echo "---------------------------------------------------------------"
echo " Setting permissions                                           "
echo "---------------------------------------------------------------"
echo ""
/lfs/system/tools/was/setup/was_perms.ksh

if [ -d ${APPDIR}/profiles/${PROFILE} ]; then
    if [ -n "$FED" ]; then
        echo "---------------------------------------------------------------"
        echo " Performing post managesdk.sh node sync on federated node      "
        echo "---------------------------------------------------------------"
        echo ""
        cellName=`grep WAS_CELL= ${APPDIR}/profiles/${PROFILE}/bin/setupCmdLine.sh | cut -d= -f2`
        result=`su - webinst -c "${APPDIR}/bin/syncNode.sh ${cellName}Manager" 2>&1`
        echo $result
    fi
fi

echo "---------------------------------------------------------------"
echo " Java7 version: $DOTVER installation was successful.           "
echo ""
echo " You must manually start WebSphere servers, if required        "
echo "---------------------------------------------------------------"
exit 0
