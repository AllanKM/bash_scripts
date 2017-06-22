#!/bin/ksh
# Uses expect to perform rsyncs across plexes 

# First argument should be the directory/file to rsync across plexes
DIR=$1
echo $DIR | grep "/fs" > /dev/null
if [ $? -ne 0 ]; then
	print -u2 -- "#### Only use this script with directories/files under /fs"
	exit 1
fi

realm=`lssys -n -lrealm | grep realm | cut -c21-`
if [[ "$realm" != 'g.ei.p3' ]]; then
	print -u2 -- "#### Only use this script from the y.ei.p1 realm where the GOLD copies of files are stored"
	exit 1
fi



if `echo $DIR | grep images >/dev/null`; then
	echo "Working with image related directory"
	STD_RSYNC_OPTS="--delete -pogauv -e ssh"
else
	STD_RSYNC_OPTS="--delete -av  --exclude RCS/ -e ssh "
fi
# Add the arg:  --dry-run to STD_RSYNC_OPTS to not actually transfer any files the first time around
DRYRUN_RSYNC_OPTS="--dry-run $STD_RSYNC_OPTS"

#Second argument should be a comma separated list of any combination of blue,green,yellow specifying 
# which zones should be involved in the sync.  Default is all of them.
ZONES=${2:-blue,green,yellow}

funcs=/lfs/system/tools/configtools/lib/check_functions.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

USER=$(whoami)

print "Syncing $DIR to $ZONES zones"

cd /tmp
ulimit -c 10

echo $ZONES | grep -i yellow > /dev/null
if [ $? -eq 0 ]; then
		YZPLEX1=`lssys -q -e role==CWS.CSM.AIX realm==y.ei.p1 | head -1`
		YZPLEX2=`lssys -q -e role==CWS.CSM.AIX realm==y.ei.p2 | head -1`
		YZPLEX3=`lssys -q -e role==CWS.CSM.AIX realm==y.ei.p3 | head -1`
		YZSTAGE=`lssys -q -e role==CWS.CSM.AIX realm==y.st.p1 | head -1`
		HOSTS="$HOSTS $YZPLEX1 $YZPLEX2 $YZPLEX3 $YZSTAGE"
        get_y_passwd
fi
echo $ZONES | grep -i green > /dev/null
if [ $? -eq 0 ]; then
		GZPLEX1=`lssys -q -e role==CWS.CSM.AIX realm==g.ei.p1 | head -1`
		GZPLEX2=`lssys -q -e role==CWS.CSM.AIX realm==g.ei.p2 | head -1`
		GZPLEX3=`lssys -q -e role==CWS.CSM.AIX realm==g.ei.p3 | head -1`
		GZSTAGE=`lssys -q -e role==CWS.CSM.AIX realm==g.st.p1 | head -1`
		HOSTS="$HOSTS $GZPLEX1 $GZPLEX2 $GZPLEX3 $GZSTAGE"
		get_g_passwd
fi
echo $ZONES | grep -i blue > /dev/null
if [ $? -eq 0 ]; then
		BZPLEX1=`lssys -q -e role==CWS.CSM.AIX realm==b.ei.p1 | head -1`
		BZPLEX2=`lssys -q -e role==CWS.CSM.AIX realm==b.ei.p2 | head -1`
		BZPLEX3=`lssys -q -e role==CWS.CSM.AIX realm==b.ei.p3 | head -1`
		HOSTS="$HOSTS $BZPLEX1 $BZPLEX2 $BZPLEX3"
		get_b_passwd
fi

realm=`lssys -n -lrealm | grep realm | cut -c21- | cut -d. -f1`
case $realm in
	y) if [ "$y_passwd" = "" ]; then get_y_passwd; fi; passwd=$y_passwd ;;
    g) if [ "$g_passwd" = "" ]; then get_g_passwd; fi; passwd=$g_passwd ;;
    b) if [ "$b_passwd" = "" ]; then get_b_passwd; fi; passwd=$b_passwd ;;
    *) print -u2 -- "Failed to determine realm for this host" 
    	exit 1 ;;
esac
			
print "Changing permissions on the local filesystem"
print "$passwd" | $PWDEXP sudo find $DIR -type f -exec chmod g+r {} \;
print "$passwd" | $PWDEXP sudo find $DIR -type d -exec chmod g+rx {} \;
print "$passwd" | $PWDEXP sudo chgrp -R eiadm $DIR


for host in $HOSTS; do
	if [ "$host" != "" ]; then
		echo
		echo "---------------------------------------------------------------------"
    	echo "$host"
    	echo "---------------------------------------------------------------------"
        realm=`lssys $host | grep realm | cut -c21- | cut -d. -f1`
        case $realm in
        	y) if [ "$y_passwd" = "" ]; then get_y_passwd; fi; passwd=$y_passwd ;;
            g) if [ "$g_passwd" = "" ]; then get_g_passwd; fi; passwd=$g_passwd ;;
            b) if [ "$b_passwd" = "" ]; then get_b_passwd; fi; passwd=$b_passwd ;;
            *) print -u2 -- "Failed to determine realm for host [$host]" 
            	exit 1 ;;
        esac
        #Make sure we are not trying to rsync to the same NFS server this box uses for /fs
        datestamp=`date +%Y%m%d-%H%M%S-%Z`
        rm ${HOME}/samecell  2>/dev/null
        touch /fs/scratch/junk_${datestamp}
        if [ $? -ne 0 ]; then
           	print -u2 -- "Failed to create test file .. exiting"
           	exit 1
        fi
        print "$passwd" | $PWDEXP /usr/bin/scp $USER@$host:/fs/scratch/junk_${datestamp} ${HOME}/samecell >/dev/null
        rm /fs/scratch/junk_${datestamp}

        if [ -f ${HOME}/samecell ]; then
          	echo "Skipping $host as this is the local NFS server"
        else
           	PARENTDIR=${DIR%/*}
           	print "$passwd" | $PWDEXP /usr/bin/ssh $USER@$host "sudo mkdir -p $PARENTDIR && sudo chgrp -R eiadm $PARENTDIR && sudo find $PARENTDIR -type f -exec chmod g+rw {} \; && sudo find $PARENTDIR -type d -exec chmod g+rwx {} \;" 2>&1 > /dev/null
           	if [ -d $DIR ]; then
           		#Remove final "/" for directory if specified on the command line as we will add an ending "/" for the rsync
           		REMOVESLASH=${DIR%/}
           		print "$passwd" | $PWDEXP rsync $DRYRUN_RSYNC_OPTS  ${REMOVESLASH}/ $host:${REMOVESLASH}/
          		echo
          		echo
          		echo "Type \"yes\" to accept the output of the dry run and transfer the files for real"
          		read RESPONSE
          		echo
          		if [[ "$RESPONSE" == "yes" ]]; then
          			print "$passwd" | $PWDEXP rsync $STD_RSYNC_OPTS  ${REMOVESLASH}/ $host:${REMOVESLASH}/
          		else
          			print -u2 -- "#### Exiting... Address concerns with the dryrun and run again"
          			exit 1
          		fi
          	else
          		# We are not working with a directory but a file - don't add a "/" for the rsync
          		print "$passwd" | $PWDEXP rsync $STD_RSYNC_OPTS ${DIR} $host:${DIR}
			fi
            OKAY=`print "$passwd" | $PWDEXP  /usr/bin/ssh $USER@$host "ls -ld ${DIR}"`
      		echo $OKAY
      		echo $OKAY | grep "does not exist" > /dev/null 2>&1
      		if [[ $? -eq 0 ]]; then
          		print "Rsync failed .. not continuing with the other realms"
          		exit 1
      		fi
        fi
	fi
done
