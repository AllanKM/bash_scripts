#!/bin/bash
# Usage:  setup_was_crontab.sh 61|70|85 [PROFILE]
#
#   Change History: 
#     Lou Amodeo    03-01-2013  Add support for Websphere 8.5 
#
FULLVERSION=${1:-70023}
VERSION=`echo $FULLVERSION | cut -c1-2`
PLATFORM=`uname`
if [ "$2" != "" ]; then
	case $2 in
		*anager)
			PROFILE=$2
			#Set DMGR to yzt70ps instead of yzt70psManager ( remove Manager )
			DMGR=${PROFILE%%Manager}
			;;
		*)	PROFILE=$2
	esac
fi

if [ "$PROFILE" == "" ]; then
   #Grab default profile
   defScript=/usr/WebSphere${VERSION}/AppServer/properties/fsdb/_was_profile_default/default.sh
   DEFPROFILE=$(grep setup $defScript|awk '{split($0,pwd,"WAS_USER_SCRIPT="); print pwd[2]}')
   PROFILE=$(echo $DEFPROFILE|awk '{split($0,profile,"/"); print profile[6]}')
   if [ "$PROFILE" == "" ]; then 
      echo "Failed to find the default profile."
      echo "exiting...."
      exit 1
   fi
fi

LOGDIR="/logs/was${VERSION}/${PROFILE}"

# Create random hour and minute for cron to run
# RHOUR between 2-4 CUT, RMIN between 0-55 in 5 min increments
RHOUR=$(($RANDOM%3 + 2))
RMIN=$((($RANDOM%55)/5*5))
#-- Install Backup cron --#
if [ "$PROFILE" == "" ]; then
	case $PLATFORM in
		AIX)	crontab -l root |grep -v "was_backup_config.sh $VERSION" > /tmp/crontab.root
			;;
		Linux)	crontab -l -u root |grep -v "was_backup_config.sh $VERSION" > /tmp/crontab.root
			;;
	esac
	echo "${RMIN} ${RHOUR} * * 1-4 /lfs/system/tools/was/bin/was_backup_config.sh $VERSION > $LOGDIR/was_backup_config.log 2>&1" >> /tmp/crontab.root
else
	case $PLATFORM in
		AIX)	crontab -l root |grep -v "was_backup_config.sh $VERSION $PROFILE" > /tmp/crontab.root
			;;
		Linux)	crontab -l -u root |grep -v "was_backup_config.sh $VERSION $PROFILE" > /tmp/crontab.root
			;;
	esac
	echo "${RMIN} ${RHOUR} * * 1-4 /lfs/system/tools/was/bin/was_backup_config.sh $VERSION $PROFILE > $LOGDIR/was_backup_config.log 2>&1" >> /tmp/crontab.root
fi
case $PLATFORM in
	AIX)	su - root -c "crontab /tmp/crontab.root"
		;;
	Linux)	crontab -u root /tmp/crontab.root
		;;
esac
rm /tmp/crontab.root