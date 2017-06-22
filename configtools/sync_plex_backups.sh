#!/bin/ksh
sync_servers=$(lssys -q -e role==gpfs.server.sync realm!=*ecc*)
sync_dirs="was mq fs_projects_rcs fs_system_security_certauth fs_system_src_cvsroot wps"
zones="b g y"
user=`whoami`
here=$(hostname -s)
print -u2 -- "Running on $here"
for server in $sync_servers; do
	if [ "$here" != "$server" ]; then
		print -u2 -- "Syncing from $server"
		for dir in $sync_dirs; do
			for zone in $zones; do
				if [ -d /gpfs/backups/${zone}/$dir ]; then
					# clear some space
					find /gpfs/backups/${zone}/$dir -mtime +14 -type f -exec rm -f {} \;
					ssh $server "find /gpfs/backups/${zone}/${dir} -mtime +14 -type f -exec rm -f {} \;"
					rsync -aubv --exclude "*.zip~*" --exclude "*.zip.*" --include "*.tar.gz" --exclude "*.tar.*" --exclude "*.snar~*" -e ssh "${user}@${server}:/gpfs/backups/${zone}/${dir}/" "/gpfs/backups/${zone}/${dir}/"
					# make sure source server didnt have any old file
					find /gpfs/backups/${zone}/$dir -mtime +14 -type f -exec rm -f {} \;
				fi
			done
		done
	fi
done

