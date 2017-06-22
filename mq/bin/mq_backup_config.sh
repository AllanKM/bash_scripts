#!/bin/ksh
HOSTNAME=`hostname -s`
print "QM status"
dspmq
print -- "-----"
QMS=`dspmq | grep -i running | awk '{print $1}'`

print "Running QM: $QMS"

for QM in $QMS; do
	QM=${QM##*\(}
	QM=${QM%%\)}
	print "Backing up $QM"
	rc=2
	i=1
	while [[ $rc -eq 2 ]] && [[ $i -lt 5 ]]; do
		su - mqm -c "/lfs/system/tools/mq/bin/saveqmgr.aix -m $QM -f /fs/backups/mq/${HOSTNAME}_${QM}_`date +\"%Y%m%d\"`.mqs" 
		rc=$?
		print "return code $rc"
		if [[ $rc -eq 2 ]]; then
			sleep 15
			print "retrying .... attempt $i"
		else
			i=4
		fi
		let i=$i+1
	done
done
cd /var/mqm/qmgrs
find . -name "qm.ini" >/tmp/mq_backup_ini.txt
tar -cvf /fs/backups/mq/${HOSTNAME}_qm_ini_`date +"%Y%m%d"`.tar -L /tmp/mq_backup_ini.txt
chmod 770 /fs/backups/mq/*
chown mqm:eiadm /fs/backups/mq/*
find /fs/backups/mq/ -mtime +14 -exec rm -f {} \;
