#!/bin/ksh

# Script to uninstall MQ

remove_ids ()
{
	echo "=> Removing MQ user IDs and groups"
	for USER in mqm; do
	#make sure processes are not running under this userid before removing
		ps -f -u${USER} > /dev/null
		if [ $? -eq 0 ]; then
			echo "Failed to stop all processes for the $USER user"
			ps -f -u${USER}
			echo "exiting...."
			exit 1
		fi
		id $USER > /dev/null 2>&1
		if [  $? -eq 0 ]; then
			echo "===> Removing $USER user from the system" 
			case `uname` in
				AIX)	rmuser -p $USER
				;;
				Linux)	/usr/sbin/userdel -r $USER
				;;
			esac
		fi
	done
	
	for GROUP in mqm mqbrkrs; do
		grep ${GROUP}: /etc/group > /dev/null 2>&1
		if [  $? -eq 0 ]; then
			echo "===> Removing $GROUP group from the system" 
			case `uname` in
				AIX)	rmgroup $GROUP
						;;
				Linux)	/usr/sbin/groupdel --service files $GROUP
						;;
			esac
		fi
	done
}

remove_filesystems ()
{
	echo "=> Removing MQ related filesystems"
	cd /tmp
	for DIR in /var/mqm; do
		if [ -d $DIR ]; then
			echo "===> Removing directory $DIR"
			rm -fr $DIR/*
			mount | grep $DIR > /dev/null
			if [ $? -eq 0 ]; then
				echo "====> Removing filesystem for $DIR"
				case `uname` in
					AIX)
						umount $DIR && rmfs $DIR
						;;
					Linux)
						LV=`grep $DIR /etc/fstab | cut -f1`
						echo "====> Umounting $DIR and removing associated LV: $LV"
						umount $DIR && /sbin/lvremove $LV && \
							grep -v $LV /etc/fstab > /tmp/fstab && cp /tmp/fstab /etc/fstab
						cp /etc/fstab /etc/fstab.bak
						
				esac
			fi
			rm -fr $DIR
		fi
	done
}


stop_apps ()
{
	
	echo "==>Checking for MQ processes"
	/lfs/system/tools/configtools/countprocs.sh 1  runmqlsr
	
	if [ $? -eq 0 ]; then
			echo "===>Stopping MQ"
			QM=`su - mqm -c "dspmq" | cut -d\( -f2 | cut -d\) -f1`
			su - mqm -c "endmqm $QM"
			sleep 10
			su - mqm -c "endmqlsr -m $QM"
			sleep 3
	fi
	
	ps -fu mqm > /dev/null
	if [ $? -eq 0 ]; then
		echo "Failed to stop MQ"
		ps -fu mqm
		echo "exiting..."
		exit 1
	fi	
	
}

uninstall_apps ()
{
	 
    
	/usr/bin/dspmqver > /dev/null 2>&1
	if [ $? -eq 0 ]; then
    	echo "===>Uninstalling MQ"
    	QMGR=`su - mqm -c "dspmq" | grep QMNAME | cut -d\( -f2 | cut -d\) -f1`
    	if [ "$QMGR" != "" ]; then
    		su - mqm -c "dltmqm $QMGR"
    	fi
		case `uname` in 
			AIX)
				installp -u 'mqm.*' 'wemps.*' > /dev/null 2>&1
	        
			;;
			Linux)
				rpm -qa | grep -i MQSeries | xargs rpm --erase    > /dev/null         
			;;
		esac
	fi
	

}

##########################
# MAIN
##########################

stop_apps
uninstall_apps
remove_filesystems
remove_ids
