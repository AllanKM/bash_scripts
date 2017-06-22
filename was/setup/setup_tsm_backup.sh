#!/bin/bash
# Usage:  setup_tsm_backup.sh 61|70|85 [PROFILE]

FULLVERSION=${1:-70025}
PROFILE=$2
VERSION=`echo $FULLVERSION | cut -c1-2`
PLATFORM=`uname`
TSM_OWNER="lamodeo@us.ibm.com"
CUSTTAG=`lssys -x csv -l custtag -n |grep -v '^#'| awk '{split($0,c,","); print c[2]}'`
DIRLIST="/projects /usr/WebSphere${VERSION}"
LOGFILE="/logs/was${VERSION}/was_tsm_setup.log"

#-- Remove any pre-existing old-style backup crons --#
if [ "$PROFILE" == "" ]; then PARAMS="$VERSION"; else PARAMS="$VERSION $PROFILE"; fi
case $PLATFORM in
	AIX)	crontab -l root |grep "was_backup_config.sh" > /dev/null
			if [ $? -eq 0 ]; then
				crontab -l root |grep -v "was_backup_config.sh $PARAMS" |grep -v "wps_backup.sh" > /tmp/crontab.root
				su - root -c "crontab /tmp/crontab.root"
				rm /tmp/crontab.root
			fi
		;;
	Linux)	crontab -l -u root |grep "was_backup_config.sh" > /dev/null
			if [ $? -eq 0 ]; then
				crontab -l -u root |grep -v "was_backup_config.sh $PARAMS" |grep -v "wps_backup.sh" > /tmp/crontab.root
				crontab -u root /tmp/crontab.root
				rm /tmp/crontab.root
			fi
		;;
esac

echo "Installing and setting up TSM backups for WAS/WPS..."
echo "     \"/fs/system/tools/tsm/bin/setup_client $TSM_OWNER $CUSTTAG $DIRLIST 2>&1\""
echo "Please wait while this task completes (takes a few minutes)."
echo "Full progress will output here and in log: $LOGFILE"
# Pause here so the above text is actually readable for a moment
sleep 5
#-- Run TSM client setup --#
/fs/system/tools/tsm/bin/setup_client $TSM_OWNER $CUSTTAG $DIRLIST 2>&1 | tee $LOGFILE

#Output will show successful install, but let's just double check it again
LASTLINES=`tail -2 $LOGFILE`
if [ "$LASTLINES" != "" ]; then
        echo $LASTLINES | grep 'TSM Client Setup completed successfully' > /dev/null
        if [ $? -eq 0 ]; then
        	echo
            echo "Success! TSM client installed and configured."
        else
        	echo
            echo "Failed. Last few lines of log contained:"
            echo "$LASTLINES"
            echo
            echo "Exiting..."
			exit 1
        fi
else
	echo
    echo "Failed to locate log file: $LOGFILE"
    echo "TSM client setup must have failed, exiting..."
    exit 1
fi
