#!/bin/ksh
#   Usage: was_restore_config.sh <date> [VERSION] [PROFILE]"
#			Date format: YYYY-MM-DD

echo $1 | grep '[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]' > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Please specify the date you wish to restore in the format: YYYY-MM-DD"
	echo "exiting..."
	exit 1
else
	DATE1=$1
fi
HOST=`hostname`
PROFILE=$3
FULLVERSION=${2:-51111}
VERSION=`echo $FULLVERSION | cut -c1-2`
BASEWASDIR="/usr/WebSphere${VERSION}"
#ARCHIVEDIR="/fs/site/was"
ARCHIVEDIR="/fs/backups/was"

if ls -d $BASEWASDIR/AppServer 2>/dev/null; then
	WAS_HOME="$BASEWASDIR/AppServer"
elif ls -d $BASEWASDIR/DeploymentManager 2>/dev/null; then
	WAS_HOME="$BASEWASDIR/DeploymentManager"
else
	echo "Failed to determine WAS_HOME"
	exit 1
fi

if [ $VERSION == "60" ] || [ $VERSION == "61" ] || [ $VERSION == "70" ]; then
	if [ "$PROFILE" == "" ]; then 
		#Grab default profile
		defScript=/usr/WebSphere${VERSION}/AppServer/properties/fsdb/_was_profile_default/default.sh
		DEFPROFILE=$(grep setup $defScript|awk '{split($0,pwd,"WAS_USER_SCRIPT="); print pwd[2]}')
		WAS_NODE=$(grep WAS_NODE= $DEFPROFILE|awk '{split($0,pwd,"WAS_NODE="); print pwd[2]}')
		PROFILE=$(echo $DEFPROFILE|awk '{split($0,profile,"/"); print profile[6]}')
		if [ "$PROFILE" == "" ]; then 
			echo "Failed to find the default profile"
			echo "exiting..."
			exit 1
		else
			WAS_HOME=${WAS_HOME}/profiles/$PROFILE
		fi
	else
		WAS_HOME=${WAS_HOME}/profiles/$PROFILE
		WAS_NODE=$PROFILE
	fi
else
	WAS_NODE=$HOST
fi
WAS_CELL=`grep WAS_CELL= ${WAS_HOME}/bin/setupCmdLine.sh | cut -d= -f2`

#Check that archive directory exists for cell.
if [ ! -d $ARCHIVEDIR/${WAS_CELL} ]; then
	echo "Archives for the cell - ${WAS_CELL} - were not found!"
	echo "exiting..."
	exit 1
fi

#Check if the backup exists for the given node/profile and date
if [ -f "$ARCHIVEDIR/${WAS_CELL}/${WAS_NODE}-${DATE1}.zip" ]; then
	echo "WARNING ** The WAS configs restore script will stop all application servers before acting."
	print "Do you wish to proceed? [Y|n] "
	read goRestore
	case $goRestore in
		Y*|y*)	${WAS_HOME}/bin/restoreConfig.sh $ARCHIVEDIR/${WAS_CELL}/${WAS_NODE}-${DATE1}.zip -logfile /logs/was${VERSION}/wasrestore.log ;;
		*)	echo "Restore of WAS configs aborted, exiting..."
			exit 0 ;;
	esac
else
	echo "Config archive for the given node/profile and date was not found!"
	echo "Please verify that the file $ARCHIVEDIR/${WAS_CELL}/${WAS_NODE}-${DATE1}.zip exists."
	echo "exiting..."
	exit 1
fi

#Check if the properties file tarball exists for the given node/profile and date
if [ -f "$ARCHIVEDIR/${WAS_CELL}/${WAS_NODE}-props-${DATE1}.tar" ]; then
	echo "WARNING ** The restore script is about to unpack key properties files and setupCmdLine.sh."
	print "Do you wish to proceed? [Y|n] "
	read goUntar
	case $goUntar in
		Y*|y*)	tar -xvf $ARCHIVEDIR/${WAS_CELL}/${WAS_NODE}-props-${DATE1}.tar ;;
		*)	echo "Restore of WAS properties files aborted, exiting..."
			exit 0 ;;
	esac
else
	echo "Properties archive for the given node/profile and date was not found!"
	echo "Please verify that the file $ARCHIVEDIR/${WAS_CELL}/${WAS_NODE}-props-${DATE1}.tar exists."
	echo "exiting..."
	exit 1
fi

#Reset WAS permissions
/lfs/system/tools/was/setup/was_perms.ksh

echo "Restoration from backup complete!"