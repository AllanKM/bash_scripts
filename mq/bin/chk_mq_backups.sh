#!/bin/ksh
# This script check if the backup files for MQ backups are stored in /fs/backups/mq
# its is designed to be run daily as part of the backups daily_check routine

realm=$( lssys -l realm -n -1 | sed -e 's/\./\\./g' -e 's/././' )
plex=${realm##*\.}
# check for split ci/cs gpfs
if lssys -l realm -e role==gpfs.server.sync realm==*.ci.$plex | grep -q  $plex; then 
	# there is a CI gpfs server so handle the split env
	if [[ "$realm" = *\\.ei\\.* ]] || [[ "$realm" = *\\.cs\\.* ]] ; then
        realm_alt=` print $realm | sed -e 's/\.ei\\\./\\.cs\\\./'`
			realm="$realm|$realm_alt"
   else 
	   realm=$(print $realm | sed -e 's/.\./.\\./')
	fi
else
	realm=".\..*\.$plex"
fi

for server in `lssys -x csv -l nodestatus,role,realm -o -e role==WBIBM.* role==MQ.* | grep -iE $realm | grep -viE ",FLUX,|\.TRAIN|,BAD,|CLIENT|TRAIN|TOOLKIT" | awk -F"," '{print $1}'`; do
zone=$(lssys -1 -l realm $server | cut -c 1 )
	if [ -f /gpfs/backups/${zone}/mq/${server}_qm_ini_`date +"%Y%m%d"`.tar ]; then
		ls -la /gpfs/backups/${zone}/mq/${server}_qm_ini_`date +"%Y%m%d"`.tar
		QMS=`tar -tf /gpfs/backups/${zone}/mq/${server}_qm_ini_\`date +"%Y%m%d"\`.tar | awk -F"/" '{print $2}'`
		for QM in $QMS; do
			if ! print $QM | grep -qi DUMMY; then
					  if [ ! -f /gpfs/backups/${zone}/mq/${server}_${QM}_`date +%Y%m%d`.mqs ]; then
						  print -u2 -- "#### Missing MQ backup for $server QM $QM"
					  else
						  ls -la /gpfs/backups/${zone}/mq/${server}_${QM}_`date +%Y%m%d`.mqs
					  fi
			fi
		done
	else
		print -u2 -- "#### Missing MQ backup for ${server}"
	fi
done

