#!/bin/ksh
#-----------------------------------------------------------
# Backup ldap
#-----------------------------------------------------------
if [ -z "$1" ]; then
   print -u2 -- "Must supply LDAP instance name to backup"
   exit 1
fi
instance=$1
group=$(id $instance | cut -f 2 -d" " | cut -d'(' -f 2 | cut -d ')' -f 1)
while read line; do 
   if [[ "$line" = "cn: $INSTANCE"* ]]; then   
      wanted=1
   elif [[ "$line" = "cn: "* ]]; then
      unset wanted
   elif [[ "$line" = "ids-instanceVersion:"* && -n "$wanted" ]]; then
      version=$( set -- $line; print $2 )
   elif [[ "$line" = "ids-instanceLocation:"* && -n "$wanted" ]]; then
      home=$( set -- $line; print $2 )
   fi
done < /opt/IBM/ldap/idsinstinfo/idsinstances.ldif  

if [[ ! -d $home ]]; then
   print -u2 -- "$home $INSTANCE not found"
   exit 1
fi

server=$(hostname -s)
backupdir=/fs/backups/ldap/${server}_${instance}
log=/fs/backups/ldap/${server}_${instance}/backup_$(date +"%Y%m%d").log

if [ ! -d ${backupdir} ]; then 
   mkdir -p $backupdir
   chown -R $instance:$group $backupdir
   chmod 2775 $backupdir
	chmod 775 /fs/backups/ldap
fi

if [ ! -d $backupdir/ldif ]; then
   mkdir -p $backupdir/ldif
   chown -R $instance:eiadm $backupdir/ldif
   chmod 2775 $backupdir/ldif
fi

chmod 775 /fs/backups/ldap
find $backupdir/ldif/ -mtime +14 -exec rm -f {} \;
find $backupdir -name "backup_*.log" -mtime +14 -exec rm -f {} \;

rc=0
/opt/IBM/ldap/V${version}/sbin/idsdbback -I ${instance} -k $backupdir -u -n >${log} 2>&1
rc=$((rc + $? ))

/opt/IBM/ldap/V${version}/sbin/db2ldif -I ${instance} -o $backupdir/ldif/${instance}_$(date +"%Y%m%d").ldif >>${log} 2>&1
rc=$((rc + $? ))
if [ $rc -eq 0 ]; then
	gzip $backupdir/ldif/${instance}_$(date +"%Y%m%d").ldif
fi
chown $instance:$group $log
chmod 770 $backupdir/ldif/*
chmod 770 $log

if [ "$rc" -gt 0 ]; then
   msg="$instance LDAP backup failed, raise SR to Apps team"
   print -u2 -- "$msg"
fi   
