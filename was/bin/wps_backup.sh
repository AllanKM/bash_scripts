#!/bin/bash

# Script to backup WPS instances

# To insert into crontab with a randomized time (to avoid overloading GPFS), run this script with the "install" argument:
# sudo /lfs/system/tools/was/bin/wps_backup.sh install

# Rolling 14-day basis (to match the WAS backups)
# Full backup taken on a Monday every 2 weeks and incrementals in-between. Files older than a month are cleared up every day.

# To restore a backup to the latest point:
# for file in $( ls -rt *.tar.gz); do gtar --incremental -zxvf $file;done
# Note that leading /'s are stripped meaning you should untar whilst sat in / (or untar to a temp directory and move what you need)

# To restore to point in time, untar the earliest full backup followed by the daily incrementals until the point you need

# Keith White/UK/IBM - February 2011

# check we're running as root
if [[ `whoami` != "root" ]]; then
   echo "This script must be run using sudo."
   exit
fi

# setup some variables
VERSION="70"
HOST=`hostname`
DATE=`date +"%F"`
BASE_WPS_DIR="/usr/WebSphere${VERSION}"
ARCHIVE_DIR="/fs/backups/wps"

# if run with the install parameter, put a semi-randomized entry in cron (based on /lfs/system/tools/was/setup/install_was_crontab.sh)
if [[ $1 == "install" ]]; then
   echo "Installing to crontab using a semi-randomized time..."
   # create random hour and minute for cron to run - RHOUR between 2-4 CUT, RMIN between 0-55 in 5 min increments
   RHOUR=$(($RANDOM%3 + 2))
   RMIN=$((($RANDOM%55)/5*5))
   # install backup cron
   PLATFORM=`uname`
   case $PLATFORM in
      AIX)	crontab -l root |grep -v "wps_backup.sh" > /tmp/crontab.root
      ;;
      Linux)	crontab -l -u root |grep -v "wps_backup.sh" > /tmp/crontab.root
      ;;
   esac
   echo "${RMIN} ${RHOUR} * * * /lfs/system/tools/was/bin/wps_backup.sh >> /logs/was${VERSION}/wps_backup.log 2>&1" >> /tmp/crontab.root
   case $PLATFORM in
      AIX)	su - root -c "crontab /tmp/crontab.root"
      ;;
      Linux)	crontab -u root /tmp/crontab.root
      ;;
   esac
   echo "Added the following line to crontab, replacing any existing wps_backup.sh entry:"
   echo "   ${RMIN} ${RHOUR} * * * /lfs/system/tools/was/bin/wps_backup.sh >> /logs/was${VERSION}/wps_backup.log 2>&1"
   rm /tmp/crontab.root
else
   # otherwise, run the backup process
   echo "--------------------------------------------------------------------------"
   echo "$0 on $HOST starting on ${DATE} at `date +'%H:%M:%S'`"
   
   # check if WPS is installed where we expect
   if ls -d $BASE_WPS_DIR/PortalServer >/dev/null; then
      echo "Backing up ${BASE_WPS_DIR}/AppServer and ${BASE_WPS_DIR}/PortalServer to ${ARCHIVE_DIR}/${HOST}"
   else
      echo "*** ERROR *** ${BASE_WPS_DIR} does not exist, perhaps WPS is not installed."
      exit 1
   fi
   
   # create the backup directory if it doesn't already exist
   ls $ARCHIVE_DIR/${HOST} >/dev/null 2>&1
   if [ $? -ne 0 ]; then
      mkdir -p $ARCHIVE_DIR/${HOST}
      chgrp -R eiadm $ARCHIVE_DIR
      chmod -R g+rwxs,o-rwx $ARCHIVE_DIR
   fi
   
   # now let's work out where in the backup cycle we are - if it's a Monday, and it's two weeks since the last backup, it's full backup time
   # which simply means deleting the snapshot file
   if [[ $(date +%u) -eq 1 ]] ; then
      # it's a Monday, let's check if the last full backup was done more than 13 days ago
      if test `find $ARCHIVE_DIR/${HOST} -type f -name "${HOST}_last_full_backup.txt" -mtime +13`; then
         echo "It's Monday and the last full backup was done more than 2 weeks ago"
         echo "Removing snapshot file to force a full backup"
         rm -rf $ARCHIVE_DIR/${HOST}/${HOST}_wps_backup_snapshot.snar
      fi
   fi
   
   # log what kind of backup we're performing
   ls $ARCHIVE_DIR/${HOST}/${HOST}_wps_backup_snapshot.snar >/dev/null 2>&1
   if [ $? -ne 0 ]; then
      echo "No snapshot file exists - this backup will be a full dump"
      echo "The last full backup of WPS on ${HOST} was taken on ${DATE}" > $ARCHIVE_DIR/${HOST}/${HOST}_last_full_backup.txt
   else
      echo "Snapshot file exists - this will be a daily incremental backup"
   fi
   
   # now perform the backup
   
   # we will create a gzipped tarball of AppServer and PortalServer, excluding logs and temp dirs using gtar (as tar doesn't handle filenames > 99 chars)
   # ${HOST}_wps_backup_snapshot.snar is a snapshot file containing metadata about the files that have changed since the last backup
   gtar -czf $ARCHIVE_DIR/${HOST}/${HOST}-${DATE}.tar.gz --listed-incremental=$ARCHIVE_DIR/${HOST}/${HOST}_wps_backup_snapshot.snar \
   ${BASE_WPS_DIR}/PortalServer/ ${BASE_WPS_DIR}/AppServer/ \
   --exclude={${BASE_WPS_DIR}/AppServer/temp/*,${BASE_WPS_DIR}/AppServer/profiles/*/wstemp/*,${BASE_WPS_DIR}/AppServer/profiles/*/temp/*,${BASE_WPS_DIR}/AppServer/profiles/*/logs/*}
   
   # check that something was actually created and change permissions
   if [ -f "$ARCHIVE_DIR/${HOST}/${HOST}-${DATE}.tar.gz" ]; then
      chgrp eiadm $ARCHIVE_DIR/${HOST}/${HOST}-${DATE}.tar.gz
      chmod g+rw,o-rw $ARCHIVE_DIR/${HOST}/${HOST}-${DATE}.tar.gz
   else
      echo "*** ERROR *** File not created - please investigate."
      rm -rf $ARCHIVE_DIR/${HOST}/${HOST}_last_full_backup.txt
      exit 1
   fi
   
   # remove backups older than 28 days
   echo "Removing backups older than 28 days"
   find $ARCHIVE_DIR/${HOST} -type f -name "*.tar.gz" -mtime +28 -exec rm -f {} \;
   
   # finish up
   echo "Backup (${DATE}) finished at `date +'%H:%M:%S'`"
   echo "Done."
   echo "--------------------------------------------------------------------------"
fi
