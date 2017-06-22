#!/bin/ksh
typeset -u TMR
typeset -u PLEX
if [ -z "$1" ]; then
	TMR="ECC CI1 PX1 CI3 PX3 PX5"
else 
	while [ -n "$1" ]; do
		PLEX=$1
		if [[ "$PLEX" = @(ECC|CI1|PX1|CI3|PX3|PX5) ]]; then	
			TMR="$TMR $PLEX"
		else
			print -u2 "Ignoring $PLEX"
		fi
		shift
	done
fi
if [ -z "$TMR" ]; then 
	print -u2 "No valid targets to scan"
	exit
fi
if [[ $(hostname -s) != v10062 ]]; then 
    print -u2 -- "Must run from v10062"
	exit 4
fi
if [[ "$SUDO_USER" = "" ]]; then
	print -u2 -- "Need to use sudo"
	exit;
fi

function filter_output {
	while read line; do
	  if [[ "$line" = *"Task Endpoint:"* ]]; then
		print -- $line
		fi
     if [[ "$line" = *"##################"* ]]; then
			unset printon
     fi
	  if [[ -n "$printon" ]]; then
		print -- "\t$line"
		fi
     if [[ "$line" = *"------Standard Error Output------"* ]]; then
			printon=1
     fi
	done
	}

lssys -q -e role==ldap.* role!=ldap.sso* > /tmp/$$_ldap_itcs104_servers.txt
for plex in $TMR ; do
	print "Checking $plex ldap nodes"
	/Tivoli/scripts/tiv.task -f /tmp/$$_ldap_itcs104_servers.txt -t 90 -l $plex /lfs/system/tools/ldap/bin/ldap_itcs104_check.pl 2>&1 | filter_output
done

mth=$(date +"%b%Y")
print "Copy reports to p1 /fs/scratch"


#================================================================================
# copy the files to the gpfs server in the same zone this script is running from
#================================================================================
sync_script=/tmp/$$_ldap_itcs104_sync.sh
myrealm=$(sed -n '/realm/s/^.*= //p' /usr/local/etc/nodecache)
mygpfs=$(lssys -q -e role==gpfs.server.sync realm==$myrealm)

cat >${sync_script} <<-END_SYNC_SCRIPT
#!/bin/ksh
host=\$(hostname -s)
mth=\$(date +"%b%Y")
   for dir in /gpfs/scratch/*/ldap_itcs104/$mth; do

		if [[ "$\host" = $mygpfs ]]; then
         if  [[ \$dir != */g/* ]]; then
            print "Copying \$dir"
            cp -r \$dir /gpfs/scratch/g/
         fi
      else
         print "Rsync \$dir"
			rsync -avc -e ssh \${dir} $mygpfs:/gpfs/scratch/g/ldap_itcs104/
      fi
   done
END_SYNC_SCRIPT

chmod 775 ${sync_script}

lssys -q -e role==gpfs.server.sync > /tmp/$$_ldap_itcs104_servers.txt
for plex in $TMR ; do
	print "Sync $plex results to p1"
	/Tivoli/scripts/tiv.task -f /tmp/$$_ldap_itcs104_servers.txt -t 90 -l $plex ${sync_script} >/dev/null 2>&1
done

audit_dir=/fs/system/audit/ldap/$mth
rundate=$(date +"%Oe%b%Y" | tr -d " ")
if [ ! -e $audit_dir ]; then
	print "Make $mth audit directory"
	mkdir -p $audit_dir
fi
print "Move reports to audit $audit_dir directory"
mv /fs/scratch/ldap_itcs104/$mth/* $audit_dir/
chown -R root:eiadm $audit_dir
chmod -R 775 $audit_dir

print "Total reports:"
grep -i overall $audit_dir/*$rundate*
grep -i overall $audit_dir/*$rundate* | wc -l
print "Passing ITCS:"
grep -i "Overall Status: Compliant" $audit_dir/*$rundate* | wc -l
print "Failing ITCS:"
grep -i "Overall Status: Non Compliant" $audit_dir/*$rundate* | wc -l


