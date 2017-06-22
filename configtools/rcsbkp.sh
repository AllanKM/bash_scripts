#!/bin/ksh
# 
# Runs as a root cronjob to create tar file of RCS directories under /fs/projects
#

function perform_backup {

		print -u2 "Backing up $SOURCE_DIR to $BACKUP_DIR with filter $FILTER"
		print -u2 "Generations to keep $GENERATIONS"
		print -u2 "Targets $TARGETS"
		print -u2 "NOTIFY: $NOTIFY"

		if [ ! -d "$BACKUP_DIR" ] || [ -z "$BACKUP_DIR" ]; then
			print -u2 "Error ! backup dir not set"
			return
		fi
		mkdir -p $BACKUP_DIR 2>/dev/null
		chmod 755 $BACKUP_DIR

		BACKUP_FILE=`echo $SOURCE_DIR | cut -d "/" -f2- | tr "/" "_"`
		#=========================================
		# remove old backups
		#=========================================
		
		find $BACKUP_DIR -name "$BACKUP_FILE*" -mtime +${GENERATIONS} -exec rm -f {} \;
		BACKUP_FILE="${BACKUP_FILE}_`date +'%Y%m%d'`"
		#=========================================
		# Create new backup
		#=========================================
		TARFILE=$BACKUP_DIR/${BACKUP_FILE}.tar
		FILELIST=$BACKUP_DIR/${BACKUP_FILE}.txt
		MD5FILE=$BACKUP_DIR/${BACKUP_FILE}.tar.md5

		# Find files to be archived
		cd $SOURCE_DIR
		if [[ ! -z $FILTER ]]; then
			find . -type f | grep -v "\.$" |  grep -i "$FILTER" >$FILELIST
		else
			find . -type f | grep -v "\.$" >$FILELIST
		fi

		# create tar file and md5sum file
		print -u2 -- "tar -cvpf $TARFILE -T $FILELIST | xargs -I '{}' md5sum '{}' >$MD5FILE" 
		tar -cvpf $TARFILE -T $FILELIST | xargs -I '{}' md5sum '{}' >$MD5FILE 

		# verify the contents

		cd $BACKUP_DIR
		mkdir tmp 2>/dev/null
		cd tmp
		OIFS="$IFS"
		IFS=$'\n'
		for FILE in `tar -tf $TARFILE | grep -v 'symbolic link to`; do
			tar -xf $TARFILE $FILE
			if [[ -f $FILE ]]; then 
				orig_md5=`grep -F "$FILE" $MD5FILE | grep $FILE'$' | awk '{print $1}'`
				new_md5=`md5sum $FILE | awk '{print $1}'`
				if [[ $orig_md5 != $new_md5 ]]; then
					print -u2 "$FILE md5 not matched \"$orig_md5\" - \"$new_md5\""
				fi
			fi
			rm -rf * 2>&1 1>/dev/null
		done
		IFS="$OIFS"

		# compress to save space
	 	gzip -qf $TARFILE

		# create md5 for the gzipped file
		md5sum ${TARFILE}.gz > ${TARFILE}.gz.md5
		cd ..
		rm -rf tmp

		#chown rcsbkp *

		# Distribute to other plexes
		for TARGET in $TARGETS; do
			if [[ $TARGET != `hostname -s` ]]; then
				ssh ${TARGET} "mkdir $BACKUP_DIR 2>/dev/null; chmod 755 $BACKUP_DIR"
				scp ${TARFILE}.gz ${TARGET}:$BACKUP_DIR 
				scp ${TARFILE}.gz.md5 ${TARGET}:$BACKUP_DIR
			fi
		done
}
i=0
cat /fs/system/config/apps_backups/apps_backups.conf | while read key; do
	CONFIG[$i]=$key
	i=$((i+1))
done

j=0
while [ j -lt $i ]; do
	key=${CONFIG[$j]}
	j=$((j+1))
	print "Config: $key	"
	if [ ! -z "$key" ]; then
		keyword=${key%%=*}
		if [ "$keyword" != "TARGETS" ] && [ "$keyword" != "GENERATIONS" ] && [ "$keyword" != "NOTIFY" ]; then
			eval isset=\$$keyword
		fi
	
		if [[ ! -z "$isset" ]]; then
			if [ ! -z "$BACKUP_DIR" ] && [ ! -z "$SOURCE_DIR" ] && [ -d "$SOURCE_DIR" ]; then
				print -u2 "calling backup_dirs with $SOURCE_DIR to $BACKUP_DIR with filter $FILTER"
				perform_backup
				unset SOURCE_DIR
				unset FILTER
				unset BACKUP_DIR
			elif [ ! -d "$SOURCE_DIR" ]; then
				print -u2 "Source directory ( $SOURCE_DIR ) does not exist, skipping!"
				unset SOURCE_DIR
				unset FILTER
				unset BACKUP_DIR
			else
				print -u2 "Unset vars !"
				print -u2 "Backing up $SOURCE_DIR to $BACKUP_DIR with filter $FILTER"
			fi
		fi
		eval $key
	fi
	unset isset
done
if [ ! -z "$SOURCE_DIR" ] && [ -d "$SOURCE_DIR" ]; then
	print -u2 "Backing up $SOURCE_DIR to $BACKUP_DIR with filter $FILTER"
	perform_backup
fi

exit

