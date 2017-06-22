#!/bin/ksh

# Script to clean up installs of applications so box can be recommissioned for other work
# or installation testing can take place with a clean machine

remove_ids ()
{
	echo "=> Removing application user IDs and groups"
	for USER in webinst pubinst mqm mirrd wbimbdb wbimbus; do
		#make sure processes are not running under this userid before removing
		ps -f -u${USER} > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "Failed to stop all processes for the $USER user"
			ps -f -u${USER}
			echo "exiting...."
			exit 1
		fi
		id $USER > /dev/null 2>&1
		if [  $? -eq 0 ]; then
			echo "===> Removing $USER user from the system" 
			rm ~${USER}/.profile > /dev/null 2>&1
			case `uname` in
				AIX)	rmuser -p $USER
				;;
				Linux)	/usr/sbin/userdel -r $USER
				;;
			esac
		fi
	done
	
	for GROUP in apps mqm mqbrkrs wbidb2; do
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
	echo "=> Removing application related filesystems"
	cd /tmp
	for DIR in /logs/was51 /logs/was60 /logs/was61 /logs/wp60 /logs/bNimble /logs/db2 /var/mqsi /usr/HTTPServer /logs/HTTPServer /usr/WebSphere51/AppServer /usr/WebSphere51/DeploymentManager /usr/WebSphere60/AppServer /usr/WebSphere60/PortalServer /usr/WebSphere61/AppServer /usr/WebSphere51 /usr/WebSphere60 /usr/WebSphere61 /var/mqm /var/db2 /usr/opt/db2_08_01 /diskqueue /lfs/system/tools/publish /logs/bNimble /usr/local/spong /projects /opt/IBM/mqsi /db2_database/wbimbdb /db2_datbase /opt/IBM/bNimble2/lib /opt/IBM/daedalus_dikran; do
		if [ -L $DIR ]; then
			echo "====> Skipping removal of $DIR.  It is a link"
			ls -l $DIR
		elif [ -d $DIR ]; then
			echo "===> Removing directory $DIR"
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
				rmdir $DIR
			else
				rm -fr $DIR
			fi
		fi
	done
}


stop_apps ()
{
	echo "=> Stopping applications"	
	#IHS
	echo "==>Checking for http processes"
	/lfs/system/tools/configtools/countprocs.sh 2 httpd 
	if [ $? -eq 0 ]; then
			echo "===>Stopping IHS"
			/etc/apachectl stop 
	fi
	echo "==>Checking for WAS processes"
	/lfs/system/tools/configtools/countprocs.sh 1 nodeagent 
	if [ $? -eq 0 ]; then
			echo "===>Stopping WAS"
			/lfs/system/bin/rc.was stop all 
	fi
	echo "==>Checking for WAS dmgr processes"
	/lfs/system/tools/configtools/countprocs.sh 1 dmgr
	if [ $? -eq 0 ]; then
			echo "===>Stopping Deployment Manager"
			/lfs/system/bin/rc.was stop dmgr 
	fi
	echo "==>Checking for MQSI processes"
	THISNODE=`hostname`
	#convert to uppercase
	typeset -u THISNODE
	BROKER=BR${THISNODE}


	if /lfs/system/tools/configtools/countprocs.sh 1 $BROKER ; then
		echo "Stopping MQSI processes"
		su - mqm -c ". ~/.profile; /opt/IBM/mqsi/6.0/bin/mqsistop $BROKER"
	fi
	
	echo "==>Checking for MQ processes"
	/lfs/system/tools/configtools/countprocs.sh 1  runmqlsr
	
	if [ $? -eq 0 ]; then
			echo "===>Stopping MQ"
			QM=`su - mqm -c "dspmq" | cut -d\( -f2 | cut -d\) -f1`
			su - mqm -c "endmqm $QM"
			sleep 20
			su - mqm -c "endmqlsr -m $QM"
			sleep 10
	fi
	
	ps -fu mqm > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo "Failed to stop MQ"
		ps -fu mqm
		echo "exiting..."
		exit 1
	fi
	
	echo "==>Checking for spong processes"
	/lfs/system/tools/configtools/countprocs.sh 1 spong 
	if [ $? -eq 0 ]; then
			echo "===>Stopping Spong"
			/etc/rc.spong stop 
	fi	
	
	echo "==>Checking for db2 processes"
	/lfs/system/tools/configtools/countprocs.sh 1 db2srvlst
	if [ $? -eq 0 ]; then
			echo "===>Stopping DB2"
			for DBUSER in `ps -ef | grep db2[s]rvlst | cut -f2 -d' ' | sort -u` ; do
				echo "======> for $DBUSER"
				su - $DBUSER -c "db2 force applications all; sleep 3; db2stop force"
			done
	fi	
	
	echo "==>Checking for publishing"
	/lfs/system/tools/configtools/countprocs.sh 1 bNimble
	if [ $? -eq 0 ]; then
			echo "Stop publishing before running remove_all_apps.sh"
			exit 1
	fi		
}

uninstall_apps ()
{
	#java -version hangs on sles 9 unless the following ulimit command is executed
    # as mentioned at http://www-1.ibm.com/support/docview.wss?uid=swg21182138
    ulimit -s 8196
	
	echo "=> Uninstalling applications"
	if [ -d /usr/WebSphere*/PortalServer ]; then
		echo "Uninstalling PortalServer from ${BASEDIR}/PortalServer "
		cd /usr/WebSphere*/PortalServer/uninstall
		./uninstall.sh -console
	fi

	if [ -f /usr/WebSphere51/AppServer/_uninstWBISF/uninstall ]; then 
    	echo "Removing WBISF using"
    	ls  /usr/WebSphere51/AppServer/_uninstWBISF/uninstall
    	cd /usr/WebSphere51/AppServer/_uninstWBISF/
    	./_wbisfuinst -silent
	fi
	
	if [ -f /usr/WebSphere51/DeploymentManager/_uninstWBISF/uninstall ]; then 
    	echo "Removing WBISF using"
    	ls  /usr/WebSphere51/DeploymentManager/_uninstWBISF/uninstall
    	cd /usr/WebSphere51/DeploymentManager/_uninstWBISF/
    	./_wbisfuinst -silent
	fi
	

	if [ -f /usr/WebSphere*/AppServer/*uninst*/uninstall  ]; then
    	echo "Removing WebSphere Application Server using:"
    	ls /usr/WebSphere*/AppServer/*uninst*/uninstall
    	cd /usr/WebSphere*/AppServer/*uninst*/
    	./uninstall -silent
	fi
	
	if [ -f /usr/WebSphere*/AppServer/_uninst/uninstall  ]; then
    	echo "Removing WebSphere Application Server using:"
    	ls /usr/WebSphere*/AppServer/_uninst/uninstall
    	cd /usr/WebSphere*/AppServer/_uninst/
    	./uninstall -silent
	fi
	
		
	if [ -f /usr/WebSphere51/DeploymentManager/_uninst/uninstall  ]; then
    	echo "Removing WebSphere DeploymentManager using:"
    	ls /usr/WebSphere51/DeploymentManager/_uninst/uninstall
    	cd /usr/WebSphere*/DeploymentManager/_uninst/
    	./uninstall -silent
	fi

	if [ -d /fs/system/images/websphere/6.1/aix/base/WAS/installRegistryUtils/bin  ]; then
    	cd /fs/system/images/websphere/6.1/aix/base/WAS/installRegistryUtils/bin
    	./installRegistryUtils.sh -listProducts | grep AppServer > /dev/null 2>&1
    	if [ $? -eq 0 ]; then
    		echo "===>Using installRegistryUntils.sh to clean up WAS 6.1 entry"
    		./installRegistryUtils.sh -cleanAll
    	fi
	fi
	
	if [ -f /usr/.ibm/.nif/.nifregistry.xml  ]; then
		echo "===>Removing nifregistry.xml file"
		cp /usr/.ibm/.nif/.nifregistry.xml /tmp/nifregistry.xml
    	rm /usr/.ibm/.nif/.nifregistry.xml
	fi
	
	if [ -f /usr/lib/objrepos/vpd.properties ] && [ -d /usr/WebSphere* ]; then
		echo "===>Cleaning up vpd.properties file"
    	cp /usr/lib/objrepos/vpd.properties /usr/lib/objrepos/vpd.properties.bak
    	grep -v /usr/WebSphere /usr/lib/objrepos/vpd.properties > /tmp/vpd.properties && cp /tmp/vpd.properties /usr/lib/objrepos/vpd.properties
	fi

	if [ -f /vpd.properties ] && [ -d /usr/WebSphere* ]; then
    	cp /vpd.properties /vpd.properties.bak
    	grep -v /usr/WebSphere /vpd.properties > /tmp/vpd.properties && cp /tmp/vpd.properties /usr/lib/objrepos/vpd.properties
	fi
	
	unset JAVA
    for java in /usr/bin/java /opt/IBMJava*/bin/java /usr/java14/jre/bin/java /usr/lib/IBMJava2/jre/bin/java; do
        test -x "$java"  && $java -fullversion 2>&1 |grep -q IBM && JAVA=$java
    done
    JAVA_COMMAND=$JAVA
    if [ -f /usr/HTTPServer/Plugins/uninstall/uninstall ]; then
		cd /usr/HTTPServer/Plugins/uninstall
		echo "====>Uninstalling WebSphere Plugin for IHS"
		./uninstall -silent
    fi
	if [ -f /usr/HTTPServer/_uninst/uninstall.jar ]; then
           cd /usr/HTTPServer/_uninst/
           echo "===>Uninstalling IHS"
           $JAVA_COMMAND -jar uninstall.jar -silent
    elif [ -f /usr/HTTPServer/uninstall/uninstall ]; then
           cd /usr/HTTPServer/uninstall/
           echo "===>Uninstalling IHS"
           ./uninstall -silent
    fi	
    
    if [ -f /opt/IBM/mqsi/*/_uninst_runtime/uninstaller ]; then
    	echo "===>Uninstalling WBIMB"
    	cd /opt/IBM/mqsi/*/_uninst_runtime && ./uninstaller -silent && cd / && rm -fr /opt/IBM/mqsi   	
    fi

	if [ -f /usr/opt/db2_*/instance/db2icrt ]; then
		echo "===>Uninstalling DB2"
		#Look for various clients and clean them up first
    	for DB2INST in mqm webinst; do
			if [ ! -d ~${DB2INST}/sqllib ]; then
    			/usr/opt/db2_*/instance/db2idrop $DB2INST > /dev/null
			fi
    	done
		case `uname` in 
			AIX)
				installp -u 'db2*' > /dev/null 2>&1        
			;;
			Linux)
				rpm -qa | grep -i DB2 | xargs rpm --erase    > /dev/null         
			;;
		esac
	fi

    
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
if [ -f /logs/configtool.log ]; then
	rm /logs/configtool.log
fi

