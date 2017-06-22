#!/bin/bash 

#---------------------------------------------------------------
# Installation Manager install.  (run as sudo)
#---------------------------------------------------------------
#
# USAGE: sudo /lfs/system/tools/was/setup/install_im.sh 1.6.2 [VOLUMEGROUP]
#
#---------------------------------------------------------------
#
#  Change History: 
#
#  Lou Amodeo - 03/01/2013 - Initial creation
#  Lou Amodeo - 09/06/2013 - Add dedicated filesystems for install and agent data directories
#  Lou Amodeo - 03/11/2014 - Add support for 1.7.1 driven by Worklight
#
#
#---------------------------------------------------------------
#
function usage {
  echo "Usage:"
  echo ""
  echo " $0 [IMVERSION] [VOLUMEGROUP]"
  echo ""
}

IMVERSION=$1
VG=${2:-appvg1}
PACKAGE="com.ibm.cic.agent"
INSTALLDIR="/opt/IBM/InstallationManager"
DATADIR="/var/ibm/InstallationManager"
IMSHAREDDIR="/usr/IMShared"
LOGFILE="/tmp/IM_INSTALL.log"

install_im_aix ()
{
    export OSDIR="aix"  
}

install_im_linux_x86 ()
{
    #java -version hangs on SLES 9 unless the following ulimit command is executed
    # as mentioned at http://www-1.ibm.com/support/docview.wss?uid=swg21182138
    ulimit -s 8196

    OSDIR="linux"   
}

install_im_linux_ppc ()
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
# Setup environment
#---------------------------------------------------------------

case `uname` in 
	AIX) install_im_aix ;;
	Linux)
		case `uname -i` in
			ppc*)	install_im_linux_ppc ;;
			x86*)	install_im_linux_x86 ;;
		esac
	;;
	*)
		echo "${0}: `uname` not supported by this install script."
		exit 1
	;;
esac

if [ "$IMVERSION"   == "1.5.2" ]; then                     
	REPOSITORY="/fs/system/images/installmgr/${IMVERSION}/${OSDIR}"
elif [ "$IMVERSION" == "1.5.3" ]; then       
	REPOSITORY="/fs/system/images/installmgr/${IMVERSION}/${OSDIR}"
elif [ "$IMVERSION" == "1.6.2" ]; then       
    REPOSITORY="/fs/system/images/installmgr/${IMVERSION}/${OSDIR}"
elif [ "$IMVERSION" == "1.7.1" ]; then       
    REPOSITORY="/fs/system/images/installmgr/${IMVERSION}/${OSDIR}"    
else
	echo "Not configured to install Installation Manager version $IMVERSION"
	echo "exiting..."
	exit 1
fi

#-----------------------------------------------------------------------
# Make sure at least 512MB is allocated for $INSTALLDIR filesystem
#-----------------------------------------------------------------------
INSTSIZE=512
df -mP $INSTALLDIR > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Creating filesystem $INSTALLDIR"
    /fs/system/bin/eimkfs $INSTALLDIR ${INSTSIZE}M $VG IMInstlv
    rm -R $INSTALLDIR/*
else
    fsize=`df -mP $INSTALLDIR|tail -1|awk '{split($2,s,"."); print s[1]}'`
    if [ "$fsize" -lt ${INSTSIZE} ]; then
        echo "Increasing $INSTALLDIR filesystem size to ${INSTSIZE}MB"
        /fs/system/bin/eichfs $INSTALLDIR ${INSTSIZE}M
    else
        echo "Filesystem $INSTALLDIR already larger than ${INSTSIZE}MB, making no changes."
    fi
fi
echo ""

#-----------------------------------------------------------------------
# Make sure at least 512MB is allocated for $DATADIR filesystem
#-----------------------------------------------------------------------
DATASIZE=512
df -mP $DATADIR > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Creating filesystem $DATADIR"
    /fs/system/bin/eimkfs $DATADIR ${DATASIZE}M $VG IMDatalv
    rm -R $DATADIR/*
else
    fsize=`df -mP $DATADIR|tail -1|awk '{split($2,s,"."); print s[1]}'`
    if [ "$fsize" -lt ${DATASIZE} ]; then
        echo "Increasing $DATADIR filesystem size to ${DATASIZE}MB"
        /fs/system/bin/eichfs $DATADIR ${DATASIZE}M
    else
        echo "Filesystem $DATADIR already larger than ${DATASIZE}MB, making no changes."
    fi
fi
echo ""

#--------------------------------------------------------------------------------
# Install Installation Manager base or refresh pack if applicable
#--------------------------------------------------------------------------------
if [ ! -d "${INSTALLDIR}/properties/version/" ]; then
	echo "---------------------------------------------------------------"
	echo "Installing Installation Manager $IMVERSION"
	echo 
	echo
	echo " Tail /tmp/IM_INSTALL.log for installation details and progress"
	echo "---------------------------------------------------------------"

	echo ""
	echo "Installing Installation Manager base version: ${IMVERSION}"
	${REPOSITORY}/installc -log ${LOGFILE} -acceptLicense -dataLocation ${DATADIR} -installationDirectory ${INSTALLDIR}/eclipse
else
	NEWVER=`echo $IMVERSION | sed -e "s/\.//g"`
	SWTAG=`ls ${INSTALLDIR}/properties/version/IBM_Installation_Manager.*.swtag`
	OLDVER=`echo $SWTAG |awk '{split($0,v,"."); print v[2]v[3]v[4]}'`
	if [ $NEWVER -gt $OLDVER ]; then
		echo "---------------------------------------------------------------"
		echo "Updating Installation Manager" 
		echo "       Update version: $IMVERSION"
		echo "       package: $PACKAGE"     
		echo "       repository: $REPOSITORY" 
		echo " Tail /tmp/IM_REFRESH.log for installation details and progress"
		echo "---------------------------------------------------------------"

		${REPOSITORY}/tools/imcl install $PACKAGE -repositories $REPOSITORY/repository.config -preferences offering.service.repositories.areUsed=false -installationDirectory ${INSTALLDIR} -acceptLicense -log ${LOGFILE}
	else
		echo "ERROR! Requested version ($IMVERSION) is not newer than the installed InstallationManager"
		echo "   Installed Version: ${SWTAG##*/}"
		exit 1
	fi
fi
echo ""

echo "Checking IBM_Installation_Manager.${IMVERSION}.swtag file"
grep ProductVersion\>${IMVERSION} ${INSTALLDIR}/properties/version/IBM_Installation_Manager.${IMVERSION}.swtag 
if [ $? -ne 0 ]; then 
	echo "Failed to install Installation Manager $IMVERSION.  Exiting...."
	exit 1
fi
echo ""

echo "Setting up IMShared filesystem according to the EI standards for IM"

# To conserve space we use a smaller IM filesystem size for IHS roles than WAS.
HOST=`/bin/hostname -s`
isWebServerRole=`lssys $HOST | grep role | grep WEBSERVER.`
IMSIZE=4096
if [ -z "${isWebServerRole}" ]; then
   IMSIZE=4096
else
   IMSIZE=3072
fi

df -mP $IMSHAREDDIR > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Creating filesystem $IMSHAREDDIR"
    /fs/system/bin/eimkfs $IMSHAREDDIR ${IMSIZE}M $VG IMSHAREDlv
    rm -R $IMSHAREDDIR/*
else
    fsize=`df -mP $IMSHAREDDIR|tail -1|awk '{split($2,s,"."); print s[1]}'`
    if [ "$fsize" -lt ${IMSIZE} ]; then
        echo "Increasing $IMSHAREDDIR filesystem size to ${IMSIZE}MB"
        /fs/system/bin/eichfs $IMSHAREDDIR ${IMSIZE}M
    else
        echo "Filesystem $IMSHAREDDIR already larger than ${IMSIZE}MB, making no changes."
    fi
fi
echo ""

echo "Setting ownership and permissions for Installation Manager..."
chown -R root:eiadm ${INSTALLDIR} > /dev/null 2>&1
chmod -R ug+rwx,o-rwx ${INSTALLDIR} > /dev/null 2>&1
chown -R root:eiadm ${DATADIR} > /dev/null 2>&1
chmod -R ug+rwx,o-rwx ${DATADIR} > /dev/null 2>&1
chown -R root:eiadm ${IMSHAREDDIR} > /dev/null 2>&1
chmod -R ug+rwx,o-rwx ${IMSHAREDDIR} > /dev/null 2>&1

echo "Completed Installation of Installation Manager"
exit 0
