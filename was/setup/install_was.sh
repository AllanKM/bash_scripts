#!/bin/ksh 

#---------------------------------------------------------------
# WAS silent install.  
#---------------------------------------------------------------

# USAGE: install_was.sh [VERSION] [PROFILE] [VOLUMEGROUP]

# Which version of WAS is to be installed

function usage {
  echo "Usage:"
  echo ""
  echo " $0 [VERSION] [PROFILE] [VOLUMEGROUP]"
  echo ""
}
FULLVERSION=${1:-61029}
# If this install is for a Deployment Manager then provide the DM name as the second arguement
# In WAS 6.0, the deployment manager is created with another script, create_profile.sh, after base WAS is installed

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
BASEDIR="/usr/WebSphere${VERSION}"
HOST=`/bin/hostname -s`
NOPROFILE="false"
case $2 in
	*anager)
				PROFILE=$2
				#Set DMGR to yzt60ps instead of yzt60psManager ( remove Manager )
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

APPDIR="${BASEDIR}/AppServer"
TOOLSDIR="/lfs/system/tools/was"

install_was_aix ()
{
	if [ "$FULLVERSION" == "70023" ]; then
        export OSDIR="aix"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WAS-AixPPC32-FP0000023 7.0.0-WS-WASSDK-AixPPC32-FP0000023 7.0.0.23-WS-WAS-IFPM71296"
    elif [ "$FULLVERSION" == "70023_64" ]; then
        export OSDIR="aix-64"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WAS-AixPPC64-FP0000023 7.0.0-WS-WASSDK-AixPPC64-FP0000023 7.0.0.23-WS-WAS-IFPM71296"
	elif [ "$FULLVERSION" == "70025" ]; then
        export OSDIR="aix"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WAS-AixPPC32-FP0000025 7.0.0-WS-WASSDK-AixPPC32-FP0000025"
    elif [ "$FULLVERSION" == "70025_64" ]; then
        export OSDIR="aix-64"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WAS-AixPPC64-FP0000025 7.0.0-WS-WASSDK-AixPPC64-FP0000025"
	elif [ "$FULLVERSION" == "70029" ]; then
        export OSDIR="aix"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WAS-AixPPC32-FP0000029 7.0.0-WS-WASSDK-AixPPC32-FP0000029"
    elif [ "$FULLVERSION" == "70029_64" ]; then
        export OSDIR="aix-64"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WAS-AixPPC64-FP0000029 7.0.0-WS-WASSDK-AixPPC64-FP0000029"
    elif [ "$FULLVERSION" == "70031" ]; then
        export OSDIR="aix"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WAS-AixPPC32-FP0000031 7.0.0-WS-WASSDK-AixPPC32-FP0000031"
    elif [ "$FULLVERSION" == "70031_64" ]; then
        export OSDIR="aix-64"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WAS-AixPPC64-FP0000031 7.0.0-WS-WASSDK-AixPPC64-FP0000031"
    elif [ "$FULLVERSION" == "70035" ]; then
        export OSDIR="aix"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WAS-AixPPC32-FP0000035 7.0.0-WS-WASSDK-AixPPC32-FP0000035"
    elif [ "$FULLVERSION" == "70035_64" ]; then
        export OSDIR="aix-64"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WAS-AixPPC64-FP0000035 7.0.0-WS-WASSDK-AixPPC64-FP0000035"
	else
		echo "Not configured to install WAS version $FULLVERSION"
		echo "exiting..."
		exit 1
	fi
}

install_was_linux_x86 ()
{
    #java -version hangs on SLES 9 unless the following ulimit command is executed
    # as mentioned at http://www-1.ibm.com/support/docview.wss?uid=swg21182138
    ulimit -s 8196
    
	if [ "$FULLVERSION" == "70023" ]; then
        export OSDIR="linux"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WASSDK-LinuxX32-FP0000023 7.0.0-WS-WAS-LinuxX32-FP0000023 7.0.0.23-WS-WAS-IFPM71296"
    elif [ "$FULLVERSION" == "70023_64" ]; then
        export OSDIR="linux-64"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WASSDK-LinuxX64-FP0000023 7.0.0-WS-WAS-LinuxX64-FP0000023 7.0.0.23-WS-WAS-IFPM71296"
    elif [ "$FULLVERSION" == "70025" ]; then
        export OSDIR="linux"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WASSDK-LinuxX32-FP0000025 7.0.0-WS-WAS-LinuxX32-FP0000025"
    elif [ "$FULLVERSION" == "70025_64" ]; then
        export OSDIR="linux-64"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WASSDK-LinuxX64-FP0000025 7.0.0-WS-WAS-LinuxX64-FP0000025"
	elif [ "$FULLVERSION" == "70029" ]; then
        export OSDIR="linux"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WASSDK-LinuxX32-FP0000029 7.0.0-WS-WAS-LinuxX32-FP0000029"
    elif [ "$FULLVERSION" == "70029_64" ]; then
        export OSDIR="linux-64"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WASSDK-LinuxX64-FP0000029 7.0.0-WS-WAS-LinuxX64-FP0000029"
    elif [ "$FULLVERSION" == "70031" ]; then
        export OSDIR="linux"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WASSDK-LinuxX32-FP0000031 7.0.0-WS-WAS-LinuxX32-FP0000031"
    elif [ "$FULLVERSION" == "70031_64" ]; then
        export OSDIR="linux-64"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WASSDK-LinuxX64-FP0000031 7.0.0-WS-WAS-LinuxX64-FP0000031"
    elif [ "$FULLVERSION" == "70035" ]; then
        export OSDIR="linux"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WASSDK-LinuxX32-FP0000035 7.0.0-WS-WAS-LinuxX32-FP0000035"
    elif [ "$FULLVERSION" == "70035_64" ]; then
        export OSDIR="linux-64"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WASSDK-LinuxX64-FP0000035 7.0.0-WS-WAS-LinuxX64-FP0000035"
    else
		echo "Not configured to install WAS version $FULLVERSION"
		echo "exiting..."
		exit 1
    fi 
}

install_was_linux_ppc ()
{
    #java -version hangs on SLES 9 unless the following ulimit command is executed
    # as mentioned at http://www-1.ibm.com/support/docview.wss?uid=swg21182138
    ulimit -s 8196
    
	if [ "$FULLVERSION" == "70029" ]; then
        export OSDIR="linuxppc"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WASSDK-LinuxPPC32-FP0000029 7.0.0-WS-WAS-LinuxPPC32-FP0000029"
    elif [ "$FULLVERSION" == "70029_64" ]; then
        export OSDIR="linuxppc-64"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WASSDK-LinuxPPC64-FP0000029 7.0.0-WS-WAS-LinuxPPC64-FP0000029"
    elif [ "$FULLVERSION" == "70031" ]; then
        export OSDIR="linuxppc"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WASSDK-LinuxPPC32-FP0000031 7.0.0-WS-WAS-LinuxPPC32-FP0000031"
    elif [ "$FULLVERSION" == "70031_64" ]; then
        export OSDIR="linuxppc-64"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WASSDK-LinuxPPC64-FP0000031 7.0.0-WS-WAS-LinuxPPC64-FP0000031"
    elif [ "$FULLVERSION" == "70035" ]; then
        export OSDIR="linuxppc"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WASSDK-LinuxPPC32-FP0000035 7.0.0-WS-WAS-LinuxPPC32-FP0000035"
    elif [ "$FULLVERSION" == "70035_64" ]; then
        export OSDIR="linuxppc-64"
        export INSTDIR="/fs/system/images/websphere/7.0/${OSDIR}/base"
        export DOTVER="7.0"
        export FIXES="7.0.0-WS-WASSDK-LinuxPPC64-FP0000035 7.0.0-WS-WAS-LinuxPPC64-FP0000035"
    else
		echo "Not configured to install WAS version $FULLVERSION"
		echo "exiting..."
		exit 1
    fi
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
		print -u2 -- "#### Shared filesystem is not mounted"
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
	echo "Remove previous installation and directories using the remove_was.sh script before proceeding"
	exit 1
fi

#---------------------------------------------------------------
# Setup Filesystems
#---------------------------------------------------------------

echo "Setting up filesystems according to the EI standards for a WebSphere Application Server"
df -m $BASEDIR > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Creating filesystem $BASEDIR"
	/fs/system/bin/eimkfs $BASEDIR 3072M $VG
else
	fsize=`df -Pm $BASEDIR|tail -1|awk '{split($2,s,"."); print s[1]}'`
	if [ "$fsize" -lt 3072 ]; then
		echo "Increasing $BASEDIR filesystem size to 3072MB"
		/fs/system/bin/eichfs $BASEDIR 3072M
	else
		echo "Filesystem $BASEDIR already larger than 3072MB, making no changes."
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
		print -u2 -- "${0:##*/}: `uname` not supported by this install script."
		exit 1
	;;
esac

if [ $VERSION -eq 61 ] && [ "$DMGR" != "" ]; then
	if [ ! -f ${TOOLSDIR}/responsefiles/v${VERSION}silent.dmgr.script ]; then
		echo "File ${TOOLSDIR}/responsefiles/v${VERSION}silent.dmgr.script does not exist"
    	echo "Use Tivoli SD tools to push /lfs/system/tools/was files to this server"
    	echo "Exiting..."
    	exit 1
	else
		FILE=v${VERSION}silent.dmgr.script
		cp ${TOOLSDIR}/responsefiles/${FILE} /tmp 
		cd /tmp
		sed -e "s/<profilename>/${DMGR}Manager/g" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
		sed -e "s/<cellname>/${DMGR}/g" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
		cd ${INSTDIR}/WAS
		if [ ! -f install ]; then
    		echo "Failed to find \"install\" comamnd in ${INSTDIR}/WAS"
    		echo "Exiting..."
    		exit 1
		fi
	fi
elif [ $VERSION -eq 70 ] && [ "$DMGR" != "" ]; then
        if [ ! -f ${TOOLSDIR}/responsefiles/v${VERSION}silent.dmgr.script ]; then
                echo "File ${TOOLSDIR}/responsefiles/v${VERSION}silent.dmgr.script does not exist"
        echo "Use Tivoli SD tools to push /lfs/system/tools/was files to this server"
        echo "Exiting..."
        exit 1
        else  
                FILE=v${VERSION}silent.dmgr.script
                cp ${TOOLSDIR}/responsefiles/${FILE} /tmp
                cd /tmp
                sed -e "s/<profilename>/${DMGR}Manager/g" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
                sed -e "s/<cellname>/${DMGR}/g" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
                cd ${INSTDIR}/WAS
                if [ ! -f install ]; then
                echo "Failed to find \"install\" comamnd in ${INSTDIR}/WAS"
                echo "Exiting..."
                exit 1
                fi    
        fi
else
	if [ ! -f ${TOOLSDIR}/responsefiles/v${VERSION}silent.stacked.script ]; then
    	echo "File ${TOOLSDIR}/responsefiles/v${VERSION}silent.stacked.script does not exist"
    	echo "Use Tivoli SD tools to push /lfs/system/tools/was files to this server"
    	echo "Exiting..."
    	exit 1
	else
		FILE=v${VERSION}silent.stacked.script

		cp ${TOOLSDIR}/responsefiles/${FILE} /tmp 
		if [ $VERSION -eq 61 ] || [ $VERSION -eq 70 ]; then
			cd /tmp
			sed -e "s/<profilename>/${PROFILE}/g" -e "s/<host>/${HOST}/g" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
			if [ "$NOPROFILE" == "true" ]; then
				echo "Configuring WAS install without a profile."
				sed -e "s/profileType=.*/profileType=\"none\"/g" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
			fi
			cd ${INSTDIR}/WAS
			if [ ! -f install ]; then
	    		echo "Failed to find \"install\" comamnd in ${INSTDIR}/WAS"
	    		echo "Exiting..."
	    		exit 1
			fi
		else
		# Must be installing WebSphere v6.0
			cd ${INSTDIR}/WAS
		fi
	fi
fi

echo "---------------------------------------------------------------"
echo " Installing WebSphere $VERSION"
echo 
echo
echo "Tail /tmp/ismp*/*tmp for installation details and progress"
echo "---------------------------------------------------------------"

# For some reason WAS 6.0 install failed if this file doesn't exist
touch /tmp/.aix_ISMP_lock____
./install -options /tmp/$FILE -silent

#WebSphere v6.0/v6.1/v7.0
PRODFILE="WAS.product"

echo "Checking $PRODFILE file for $DOTVER"
grep version\>${DOTVER} ${APPDIR}/properties/version/${PRODFILE}
if [ $? -ne 0 ]; then 
    echo "Failed to install WebSphere $DOTVER.  Exiting...."
    exit 1
fi

echo " Creating /logs/was${VERSION} "
mv ${APPDIR}/logs ${APPDIR}/logs.orig
ln -s /logs/was${VERSION} ${APPDIR}/logs
chmod g+s $BASEDIR /logs/was${VERSION}
mv ${APPDIR}/logs.orig/* /logs/was${VERSION}
rm -fr ${APPDIR}/logs.orig
if [ $VERSION -eq 61 ] || [ $VERSION -eq 60 ] || [ $VERSION -eq 70 ] && [ $NOPROFILE != "true" ]; then
	for PROF in "`ls ${APPDIR}/profiles/`"; do
		PROFDIR=${APPDIR}/profiles/${PROF}
		mkdir /logs/was${VERSION}/${PROF}
		mv ${PROFDIR}/logs ${PROFDIR}/logs.orig
		ln -s /logs/was${VERSION}/${PROF} ${PROFDIR}/logs
		chmod g+s $PROFDIR /logs/was${VERSION}/${PROF}
		mv ${PROFDIR}/logs.orig/* /logs/was${VERSION}/${PROF}
		rm -fr ${PROFDIR}/logs.orig
	done
fi
chown -R webinst:eiadm /logs/was${VERSION}
chmod -R ug+rwx,o-rwx $BASEDIR /logs/was${VERSION}

for FIX in $FIXES
do
    /lfs/system/tools/was/setup/install_was_fixpack.sh $FIX
    if [ $? -ne 0 ]; then
	echo "Installation of $FIX failed...."
	echo "exiting...."
	exit 1
    fi
done

echo " Setting Permissions "
/lfs/system/tools/was/setup/was_perms.ksh
