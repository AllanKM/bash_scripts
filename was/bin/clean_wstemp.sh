#!/bin/ksh
#   Usage: clean_wstemp.sh [VERSION] [PROFILE]"
HOST=`hostname`
DATE1=`date +"%F"`
PROFILE=$2
FULLVERSION=${1:-70023}
VERSION=`echo $FULLVERSION | cut -c1-2`
BASEWASDIR="/usr/WebSphere${VERSION}"

if ls -d $BASEWASDIR/AppServer 2>/dev/null; then
	WASHOME="$BASEWASDIR/AppServer"
else
	echo "Failed to determine WAS_HOME"
	exit 1
fi

if [ "$PROFILE" == "" ]; then 
	#Grab default profile
	defScript=${WASHOME}/properties/fsdb/_was_profile_default/default.sh
	DEFPROFILE=$(grep setup $defScript|awk '{split($0,pwd,"WAS_USER_SCRIPT="); print pwd[2]}')
	PROFILE=$(echo $DEFPROFILE|awk '{split($0,profile,"/"); print profile[6]}')
	if [ "$PROFILE" == "" ]; then 
		echo "Failed to find the default profile"
		echo "exiting...."
		exit 1
	else
		WASHOME=${WASHOME}/profiles/${PROFILE}
	fi
else
	WASHOME=${WASHOME}/profiles/${PROFILE}
fi

WSTEMP=${WASHOME}/wstemp
echo "[`date +%F_%T`] Removing all files/folders older than 45 days from: $WSTEMP"
if [[ -d ${WSTEMP} ]]; then
	cd ${WSTEMP}
	# Remove the temp files and folders older than 45 days
	find ./ -type f -mtime +45 -depth -exec rm {} \;
	find ./ -type d -mtime +45 -depth -exec rm -r {} \;
	
	# Refresh permissions
	echo "[`date +%F_%T`] Resetting defult permissions (/lfs/system/tools/was/setup/was_perms.ksh)"
	/lfs/system/tools/was/setup/was_perms.ksh
else
	echo "ERROR: The variable WSTEMP ($WSTEMP) is not a valid directory. Exiting."
fi

echo "[`date +%F_%T`] Done"