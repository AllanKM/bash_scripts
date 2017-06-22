#!/bin/ksh

#-----------------------------------------------------------------------------------------------
# determine where to run the scan
#	single server
#	role
#	individual plex
#  environment px1 px2 px3 ci2 ci3 ecc
# 	all plexes

# kick off the scan
# wait for all processes to finish

# set file permissions
# copy cert files to /fs/scratch on target server
# delete from other places
#-----------------------------------------------------------------------------------------------

myname=${0:##*/}
target=$1
db_server="v10030"
typeset -u tmr

logdir=/fs/scratch/cert_info/logs
server_file="/tmp/${myname}.$$.server"
scan_script="/fs/scratch/cert_info/cert_scan.pl"
script_name=${scan_script:##*/} 

# dynamically generated scripts
tiv_task_script="/tmp/${myname}.$$.scan.sh"
sync_script="/tmp/${myname}.$$.sync.sh"
check_script="/tmp/${myname}.$$.check.sh"
priv_script="/tmp/${myname}.$$.priv.sh"
cleanup_script="/tmp/${myname}.$$.cleanup.sh"
certdb_fails_log=/fs/scratch/cert_info/certdb_fails.txt
rm -f ${certdb_fails_log} >/dev/null 2>&1
#-----------------------------------------------------------------------------------------------
# Functions 
#-----------------------------------------------------------------------------------------------
function tmr4server {
   realm=`lssys -l realm -1 $1`
   # g.ci.p2
   set -- $(IFS="."; set -- ${realm}; print $*)
   plex=`print $3 | tr -d p`
   typeset -u env
   env=$2
   if [ "$env" = "ECC" ] || [ "$3" = "z1" ]; then
      env=ECC
      plex=''
   elif [ "$env" != "CI" ]; then
         env="PX"
   fi
   print ${env}${plex}
}

check_submit() {
	sub_errs=""
   while read line; do
      if print -- "$line" | grep -iq "The task failed to execute."; then
         ep=`print $line | awk '{print $1}'`
         sub_errs="$sub_errs $ep"
         print $line >>/fs/scratch/cert_info/certdb_fails.txt
      fi 
      if print -- "$line" | grep -iq "###############"; then
         stderr=0
      fi
 
      if [[ "$stderr" = 1 ]]; then
         sub_errs="$sub_errs $ep"
         print "$ep $line"  >>${certdb_fails_log}
      fi
      if print -- "$line" | grep -iq "Task Endpoint"; then
         ep=`print $line | awk '{print $3}'`
      fi
      if print -- "$line" | grep -iq "Standard Error Output"; then
         stderr=1
      fi
   done
   if [ -n "$sub_errs" ]; then
      if [[ "$cron" = "1" ]]; then
         /opt/IBM/ITMscripts/ITM_to_Omni -k alert00 -g12 -p300 "Cert scan failed to run on$sub_errs PAGE-0576"
      else
         print -u2 -- "Failures performing cert scan on ($sub_errs )"
      fi
   fi 
}

function test_running {
   print -- "looking for ${script_name}"
   while read line; do
      if print -- "$line" | grep -iq "Task Endpoint"; then
         ep=`print $line | awk '{print $3}'`
      fi
      if print -- "$line" | grep -iq ${script_name}; then
         print -- "##### [ `date +%H:%M` ] still running on $ep"
         active=1;
      fi
   done
}
#-----------------------------------------------------------------------------------------------
# Main code 
#-----------------------------------------------------------------------------------------------
#==============================================================
# Build tiv.task elements based on supplied parm
#==============================================================
typeset -u tmr_parm
typeset -u tmr_list
# analyze command line
while [ $# -gt 0 ]; do
   if [[ $1 = @(at|dt|gt|ac|dc|gc|v10|v20|v30|v50|z10|w10|w20|w30|w50)* ]]; then
      # looks like a server
      if dsls -q system $1 | grep -iq $1; then
         # add server to list
         server_list="$server_list $1"
      else
         print "$1 looked like a server but doesnt exist in dirstore"
      fi
   elif [[ "$1" = +(p1|p2|p3|p5|z1) ]]; then
      # Plex
      case $1 in 
         p1) tmr_parm="$tmr_parm PX1 CI1 ECC";;
         p2) tmr_parm="$tmr_parm PX2 CI2";;
         p3) tmr_parm="$tmr_parm PX3 CI3";;
         p5) tmr_parm="$tmr_parm PX5 CI5";;
         z1) tmr_parm="$tmr_parm ECC";;
      esac
 
   elif [[ "$1" = +(px1|px2|px3|px5|ecc|ci1|ci2|ci3|ci5) ]]; then
      # Environment
      # all servers in the environment
      tmr_parm="$tmr_parm $1"
       
   elif [[ "$1" = "cron" ]]; then
      cron=1
   else
      servers=$(lssys -q -e role==$1)
		if [ -n "$servers" ]; then
			server_list="$server_list $servers"
		else
			print "$1 is not recognised"
		fi
   fi
   shift 
done

#-------------------------------------------------------------------------------------
# Show where the scan will run 
#-------------------------------------------------------------------------------------
print "Scan targets:"
if [ -n "$server_list" ]; then
   unset servers
   for server in $server_list; do
      servers="$servers $server"
      print $server >> ${server_file}
      tmr_list="$tmr_list $(tmr4server $server)"
   done
   print "\tservers: $servers"
   server_list=$servers
   if [ -n "$tmr_parm" ]; then
      tmr_list="$tmr_parm"
   fi
   tmr_list=$( 
      ( for tmr in $tmr_list; do
          print "$tmr"
        done ) | sort -u )    
else
   print "\tservers: ALL"
   tmr_list="$tmr_parm"
fi

print -n "\tTMR's:"
for tmr in $tmr_list; do 
   print -n "$tmr "
done
print
if [ -z "$tmr_list" ]; then
	print "No valid targets"
	exit
fi
if [ -e ${server_file} ]; then
   file_parm="-f ${server_file}"
fi
 
 #-==================================================
 # distribute the cert_scan code
 #==================================================
cd /lfs/system/tools/configtools
 if [ ! -d /fs/scratch/cert_info/dist ]; then
	mkdir -p /fs/scratch/cert_info/dist
 fi
 print -u2 -- "Checking scan code is current in all plex"
 tar -cvf /fs/scratch/cert_info/dist/cert_scan.tar cert_scan.pl gskcmd.sh conf/cert_scan.conf >/dev/null 2>&1
 cd /fs/scratch/cert_info/dist
 cat >tpost <<EOF
#!/bin/ksh
cd /fs/scratch/cert_info
tar -xvf dist/cert_scan.tar
chmod +x cert_scan.pl

EOF
#===================================================
# get a list of target servers one per plex/env/zone
#===================================================
lssys -l realm -x csv -e role==gpfs.server.* | sort -u -t , -k 2 | sed -e 's/,.*$//' | sort >servers.txt

#==========================================
# install the code 
#==========================================
/Tivoli/scripts/tiv.install -a -y -f servers.txt /fs/scratch/cert_info/dist /fs/scratch/cert_info/dist >/fs/scratch/cert_info/sync_code.log 2>&1

#=========================================================
# Send out all the scan requests
#=========================================================
cat >${tiv_task_script} <<-END_SCRIPT
#!/bin/ksh

   if [ ! -d /fs/scratch/cert_info/logs ]; then 
      mkdir -p /fs/scratch/cert_info/logs
      chgrp eiadm /fs/scratch/cert_info
      chmod -R 2775 /fs/scratch/cert_info
   fi
	if [ ! -e /fs/scratch/cert_info/cert_scan.pl ]; then
		print -u2 -- "cert_scan not in /fs/scratch/cert_info"
		print -- "cert_scan not in /fs/scratch/cert_info" >/fs/scratch/cert_info/logs/\`hostname -s\`.log
		exit
	fi

   export DEBUG=0
   nohup ${scan_script} >/fs/scratch/cert_info/logs/\`hostname -s\`.log 2>/fs/scratch/cert_info/\`hostname -s\`_fails.txt & 
END_SCRIPT

chmod 775 ${tiv_task_script}


task_tmrs=$tmr_list

for tmr in $tmr_list; do
   print "Submitting to $tmr" 
  /Tivoli/scripts/tiv.task -t 300 -l ${tmr} ${file_parm} ${tiv_task_script} 2>&1 | tee ${logdir}/${tmr}_scan.log | check_submit  
done

#=========================================================
# now we need to wait until all the scans have completed
#=========================================================
cat >${check_script} <<END_CHECK_SCRIPT
#!/bin/ksh
ps -eo "%a" | grep ${script_name} | grep -v grep
END_CHECK_SCRIPT
chmod 775 ${check_script}

 active=1
max=50
 print "Waiting for scans to complete"
 while [[ $active -eq 1 ]]; do
   sleep 300
   active=0
   
   for tmr in $tmr_list; do
      print "Checking $tmr"
      /Tivoli/scripts/tiv.task -t 300 -l ${tmr} ${file_parm} ${check_script} 2>&1 | test_running
   done
   max=$((max-1))
   if [ $max -eq 0 ]; then
   	# after 4 hours abort waiting and carry on. Log the failing node
   	active=0
   	print -u2 -- "###### Possible hung scan" >>${certdb_fails_log}
   	lastlog=$(ls -rt /fs/scratch/cert_info/logs/certdb_update*.log | tail -n 1)
   	running=$(grep -i "still running" $lastlog | tail -n 1 )
   	print -u2 -- $running >>${certdb_fails_log}
	fi
 done

#=========================================================
# Final step copy the files to the db server /fs/scratch
#=========================================================

cat >${sync_script} <<-END_SYNC_SCRIPT
#!/usr/bin/ksh

   HOST=\`hostname -s\`
   db_zone=`lssys -l realm -1 $db_server | cut -c 1`
   gpfs=\`lssys -q -e role==gpfs.server.sync\`
	gpfs="\$gpfs z10048"
   for server in \$gpfs; do
      for zone in b g y; do
			if [[ "\$server" = "z"* && "\$zone" == "y" ]]; then 
		      print "skipping \$server \${zone}z ECC only has a bz and gz "
		   elif [[ "\$zone" = "\$db_zone" ]] && [[ \$server = \$HOST ]]; then
		      print "Not synching \$server \${zone}z as thats the target"
         else  
		      print "synching \${server}:/gpfs/scratch/\${zone}/cert_info/*.txt"
				if [[ \$server = \$HOST ]]; then
				  cp -R /gpfs/scratch/\${zone}/cert_info/*.txt /gpfs/scratch/\${db_zone}/cert_info/
				else
					rsync -av -e ssh \${server}:/gpfs/scratch/\${zone}/cert_info/*.txt /gpfs/scratch/\${db_zone}/cert_info/
				fi
         fi
      done 
   done
END_SYNC_SCRIPT

chmod 775 ${sync_script}

#---------------------------------------------------------------
# get gpfs server for the realm dbserver is in
#---------------------------------------------------------------
realm=`lssys -l realm -1 $db_server | awk -F"." '{ print "*."$2"."$3}'`

gpfs_server=`lssys -q -e role==gpfs.server.sync realm==$realm`
print "Sync data to $db_server /fs/scratch on the gpfs server $gpf_server" 

tmr=$(tmr4server $gpfs_server)

print $gpfs_server >${server_file}

print /Tivoli/scripts/tiv.task -t 300 -l ${tmr} -f ${server_file} ${sync_script} 2>&1 
/Tivoli/scripts/tiv.task -t 300 -l ${tmr} -f ${server_file} ${sync_script} >${logdir}/${tmr}_sync.log 2>&1 

#===========================================================================================
# set file access rights on db server
#===========================================================================================
print $db_server >${server_file}

cat >${priv_script} <<-END_PRIV_SCRIPT
#!/usr/bin/ksh
   touch /fs/scratch/cert_info/do_import.txt
   chown -R eidesdb /fs/scratch/cert_info 
   chmod -R 775 /fs/scratch/cert_info
END_PRIV_SCRIPT

chmod +x ${priv_script}

print /Tivoli/scripts/tiv.task -t 300 -l ${tmr} -f ${server_file} ${priv_script} 2>&1 
/Tivoli/scripts/tiv.task -t 300 -l ${tmr} -f ${server_file} ${priv_script} >${logdir}/${tmr}_priv.log 2>&1 

#===========================================================================================
# Cleanup cert_info dir on source servers
#===========================================================================================
lssys -q -e "role==gpfs.server.sync" >${server_file}

cat >${cleanup_script} <<-END_CLEANUP_SCRIPT
#!/usr/bin/ksh
   HOST=\`hostname -s\`
   
   db_zone=`lssys -l realm -1 $db_server | cut -c 1`
   print "Leaving files on $gpfs_server \$db_zone zone"
   for zone in b g y; do
      if [[ \$zone = \$db_zone ]] && [[ "\$HOST" = "$gpfs_server" ]]; then
         continue
      else        
         print -u2 -- "$HOST rm -f /gpfs/scratch/\${zone}/cert_info/*.txt"
         rm -f /gpfs/scratch/\${zone}/cert_info/*.txt
      fi
   done 
   
END_CLEANUP_SCRIPT

chmod +x ${cleanup_script}

for tmr in $task_tmrs; do
   print /Tivoli/scripts/tiv.task -t 300 -l ${tmr} -f ${server_file} ${cleanup_script} 2>&1 
   /Tivoli/scripts/tiv.task -t 300 -l ${tmr} -f ${server_file} ${cleanup_script} >${logdir}/${tmr}_cleanup.log 2>&1 
done

rm -f ${priv_script} >/dev/null 2>&1
rm -f ${server_file} >/dev/null 2>&1
rm -f ${tiv_task_script} >/dev/null 2>&1
rm -f ${check_script} >/dev/null 2>&1
rm -f ${sync_script} >/dev/null 2>&1
rm -f ${cleanup_script} >/dev/null 2>&1 
