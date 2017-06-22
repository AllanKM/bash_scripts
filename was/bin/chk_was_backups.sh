#!/bin/ksh
max_backup_age=7				# must find a backup created in the last 6 days

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

function findfile {
	for file in $files; do
		if print $file | grep -iEq "\/$1"; then
			print -- `ls -l ${file}`
			return
		fi 
	done
	print -u2 -- "#### missing backup for $1"
}
# get list of backup files

files=`find /fs/backups/was -type f -mtime -${max_backup_age} | sort -r`
# get list of was servers

servers=`lssys -x csv -l nodestatus,role,realm -e role==WAS.* | grep -iE ${realm} | grep -vE ",TEST,|,FLUX,|,BAD,|BACKUP|WAS\.DM" | awk -F"," '{print $1}'`
[ -n "$debug" ] && print -u2 -- "Servers: $servers"
# check all servers have a backup file

for server in $servers; do
  findfile $server
done

dms=$( lssys -x csv -l nodestatus,role,realm -e role==WAS.DM.* | grep -iE ${realm} | grep -vE ",TEST,|,FLUX,|,BAD,|BACKUP" )

for line in $dms; do
	line=${line#*,}        # lose the server name
	line=${line#*,}        # lose the nodestatus
	line=${line%,*}        # lose the realm
		
	for dm in $( IFS=";"; print $line ); do
	   dm=${dm#WAS\.DM\.}
		if [[ $dm = +(G|B|Y)* ]]; then
		  [ -n "$debug" ] && print -u2 -- "dm: $dm"
         findfile "${dm}Manager"
		fi
	done
done 


