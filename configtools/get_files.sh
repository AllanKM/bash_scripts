#!/bin/ksh
# uses expect to scp and grab files from nodes

#First argument should a file containing a list of hosts (one per line) to grab the files from
HOSTLIST=$1
if [ "$HOSTLIST" == "" ]; then
   print -u2 -- "#### Supply a file containing a list of hosts as the first argument"
fi

#Second argument should be a list of files  (one per line) to grab from each server.
#You can use the wildcard '*' in the file name.
FILELIST=`echo $2 | awk '{ FS = "/" } ; {print $NF}'`
if [ "$FILELIST" == "" ]; then
   print -u2 -- "#### Supply a file containing a list of files as the second argument"
fi

funcs=/lfs/system/tools/configtools/lib/check_functions.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"
if [ -n "$debug" ]; then
   exp_debug="-d $debug"
fi

check() {
   while read line; do
      if [ -n "$debug" ]; then
         print "$host: $line"
      fi
   done
}
USER=$(whoami)

ulimit -c 10

PSCP="/fs/system/bin/pscp"
PWDEXP=/lfs/system/tools/configtools/pwdexp

for host in `cat $1`; do
   if [ "$host" != "" ]; then
      echo "$host"
      if [ ! -d $host ]; then
         echo "    Creating subdirectory for $host"
         mkdir $host
      fi
      realm=`lssys $host | grep realm | grep -v authrealm | cut -c21- | cut -d. -f1`
      case $realm in
         y) if [ "$y_passwd" = "" ]; then get_y_passwd; fi; passwd=$y_passwd ;;
         g) if [ "$g_passwd" = "" ]; then get_g_passwd; fi; passwd=$g_passwd ;;
         b) if [ "$b_passwd" = "" ]; then get_b_passwd; fi; passwd=$b_passwd ;;
         *) print -u2 -- "Failed to determine realm for host [$host]" ;;
      esac
      echo ""
      datestamp=`date +%Y%m%d-%H%M%S-%Z`
      #first scp the file containing the list of files to gather to the target host
      print "$passwd" | $PWDEXP /usr/bin/scp $2 $USER@$host:/tmp/${FILELIST}.${datestamp} >/dev/null
      #Next zip the desired files on the remote host
      rm -f /tmp/.dssh_known_hosts.$USER >/dev/null 2>&1
      print PubkeyAuthentication=no > /tmp/.empty_sshkey.$USER
      
      scpopts="-F /tmp/.empty_sshkey.$USER -o NumberOfPasswordPrompts=1 -o UserKnownHostsFile=/tmp/.dssh_known_hosts.$USER -o strictHostKeyChecking=no"
      sshopts="$scpopts -t"

      print "$passwd" | $PWDEXP $exp_debug /usr/bin/ssh $sshopts $USER@$host 'cat /tmp/'${FILELIST}'.'${datestamp}' | xargs -i bash -c "ls -1 {}" | sudo /usr/bin/zip -r /fs/scratch/'${host}'_'${datestamp}'.zip -@ && sudo /bin/chown '$USER':eiadm /fs/scratch/'${host}'_'${datestamp}'.zip' | check 

      #scp the archive file over
      print "$passwd" | $PWDEXP $exp_debug /usr/bin/scp $scpopts $USER@$host:/fs/scratch/${host}_${datestamp}.zip $host/
      ls -l $host/${host}_${datestamp}.zip >/dev/null 2>&1
      if [ $? -ne 0 ]; then
         print  -u2 -- "!!!Failed to grab files from [$host]"
      else
         #Remove the temp .zip file from the remote host
         print "$passwd" | $PWDEXP $exp_debug /usr/bin/ssh $sshopts $USER@$host "rm /fs/scratch/${host}_${datestamp}.zip" >/dev/null
         #Uncomment the next few lines if you want extract the files on the drop node
         #current_dir=$PWD
         #cd $host && /usr/bin/unzip -uq ${host}_${datestamp}.zip
         #cd $current_dir
         #rm $host/${host}_${datestamp}.zip
         echo "Collection complete!"
      fi
   fi
done
