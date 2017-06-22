#!/bin/ksh
# Script will use pdbackup utility to backup webseal configurations on each webseal.sso.prd node
# Usage wsbackup.ksh
# Author: Christopher Kalamaras
# Revision Date: 20090417

if [ `whoami` != "root" ]; then
      echo "You must run this script as root"; exit 1
fi

outfile=/tmp/msg__pdbackup.log
backuplist=/opt/pdweb/etc/amwebbackup.lst
#backupdir=/fs/projects/prd/sso/backups
backupdir=/fs/backups/tam/sso
backupfile=ws-`hostname -s`-`date +%Y%m%d`

#Clean out backup files not modified in past 30 days
find $backupdir -type f -mtime +30 | xargs rm

#Perform the backup
/usr/bin/pdbackup -action backup -list $backuplist -path $backupdir -file $backupfile

if [ $? -eq 0 ]; then
	exit 0
else
    echo "Backup process failed! Please check $outfile for details."
fi