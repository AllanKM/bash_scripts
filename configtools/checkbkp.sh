#!/bin/ksh

# Check backups of RCS files successful
 
function check_backup {
	NOTIFY=`print $NOTIFY | tr "," " "`
	
	TO=${NOTIFY%% *}
	CC=${NOTIFY#* }
	if [ "$CC" != "$TO" ]; then
		CC="-c \"$CC\""
	fi
	
	BACKUP_GROUP=`echo $SOURCE_DIR | cut -d "/" -f2- | tr "/" "_"`
	BACKUP_FILE="${BACKUP_GROUP}_`date +'%Y%m%d'`.tar.gz"
	MD5_FILE="${BACKUP_DIR}/${BACKUP_FILE}.md5"
	
	#================================================
	# delete old backups
	#================================================
	find $BACKUP_DIR -name "${BACKUP_GROUP}*" -mtime +${GENERATIONS} -exec rm -f {} \;
	
	# check file created in last 60mins 

	if  ! find $BACKUP_DIR -name $BACKUP_FILE -cmin -600 | grep $BACKUP_FILE 1>/dev/null 2>&1 ; then
		msg="RCS backup failed to be copied to `hostname -s`:${BACKUP_DIR}/$BACKUP_FILE"
		print $msg | mail -s "$BACKUP_DIR backup failed on `hostname -s`" $CC $TO
		print -u2 "RCS backup $BACKUP_FILE failed to copy"
		# send alert
		/opt/IBM/ITMscripts/ITM_to_Omni -k alert$count-g12 -p300 "$msg - PAGE-0577"
		return
	fi

	# check file md5 matches

	MD5=`md5sum "${BACKUP_DIR}/${BACKUP_FILE}" | awk '{print $1}'`

	if ! grep $MD5 $MD5_FILE 1>/dev/null 2>&1; then
		msg="RCS backup failed MD5 check on `hostname -s`:${BACKUP_DIR}/$BACKUP_FILE"
		print $msg | mail -s "$BACKUP_DIR backup failed on `hostname -s`" $CC $TO
		print -u2 "RCS backup $BACKUP_FILE failed MD5 check"
		# send alert
		/opt/IBM/ITMscripts/ITM_to_Omni -k alert$count -g12 -p300 "$msg - PAGE-0577"
		return
	fi
}
count=0
cat /fs/system/config/apps_backups/apps_backups.conf | while read key; do
	if [ ! -z "$key" ]; then
		keyword=${key%%=*}
		if [ "$keyword" != "TARGETS" ] && [ "$keyword" != "GENERATIONS" ] && [ "$keyword" != "NOTIFY" ]; then
			eval isset=\$$keyword
		fi	
	
		if [[ ! -z "$isset" ]]; then
			check_backup
			count=$((count +1))
			unset BACKUP_DIR
		fi
		eval $key
	fi
	unset isset
done
if [ ! -z "$SOURCE_DIR" ]; then
   check_backup
fi

