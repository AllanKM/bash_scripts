#!/bin/ksh
#---------------------------------------------------------------
# Uninstall WebSphere
#---------------------------------------------------------------
# USAGE: remove_was.sh [VERSION] [nostop]

# Which version of WAS is to be removed
FULLVERSION=${1:-61027}
VERSION=`echo $FULLVERSION | cut -c1-2`
TOOLSDIR="/lfs/system/tools/was"
PLATFORM=`uname`
NOSTOP=$2
BASEDIR="/usr/WebSphere${VERSION}"
APPDIR="${BASEDIR}/AppServer"

echo "Uninstalling WebSphere from $APPDIR"

if [ -z "$NOSTOP" ]; then
	if [ -d ${APPDIR} ]; then
		echo "Executing: \"rc.was stop all\""
		if [ -f /lfs/system/tools/was/bin/rc.was ]; then
			/lfs/system/tools/was/bin/rc.was stop all	  
		fi
	else
		echo "Failed to locate $APPDIR, exiting..."
		exit
	fi
else
	echo "NoStop was specified, proceeding with the assumption that WebSphere${VERSION} is stopped."
fi

if [ -d ${BASEDIR}/PortalServer ]; then
	echo "Uninstalling PortalServer from ${BASEDIR}/PortalServer "
	cd ${BASEDIR}/PortalServer/uninstall
	./uninstall.sh -console
fi

if [ -f ${APPDIR}/uninstall_wxs/uninstall ]; then 
    echo "Removing WXS from $BASEDIR"
    cd ${APPDIR}/uninstall_wxs/
    ./uninstall -silent
fi

if [ -f ${APPDIR}/uninstall/uninstall  ]; then
    echo "Removing WebSphere Application Server from $BASEDIR"
    cd ${APPDIR}/uninstall/
    ./uninstall -silent
    
    if [ -f $BASEDIR/UpdateInstaller/uninstall ]; then
    	echo "Removing WebSphere Update Installer from $BASEDIR"
    	cd $BASEDIR/UpdateInstaller/
    	./uninstall -silent
    fi
    
	if [ -d /fs/system/images/websphere/6.1/aix/base/WAS/installRegistryUtils/bin ]; then
   		cd /fs/system/images/websphere/6.1/aix/base/WAS/installRegistryUtils/bin
   		grep ${BASEDIR} /usr/.ibm/.nif/.nifregistry > /dev/null
   		if [ $? -ne 0 ]; then
   			echo "Using installRegistryUntils.sh to clean up WAS 6.1 entries"
   			./installRegistryUtils.sh -cleanAll
   			grep ${BASEDIR} /usr/.ibm/.nif/.nifregistry > /dev/null
			if [ $? -ne 0 ]; then
				echo "installRegistryUtils.sh -cleanAll failed to remove WAS entry from /usr/.ibm/.nif/.nifregistry"
				echo "Investigate...."
			fi
   		fi
	fi

	echo "Cleaning up vpd.properties file"
	if [ -f /usr/lib/objrepos/vpd.properties ]; then
    	cp /usr/lib/objrepos/vpd.properties /usr/lib/objrepos/vpd.properties.bak
    	grep -v $BASEDIR /usr/lib/objrepos/vpd.properties > /tmp/vpd.properties && cp /tmp/vpd.properties /usr/lib/objrepos/vpd.properties
	fi

	if [ -f /vpd.properties ]; then
    	cp /vpd.properties /vpd.properties.bak
    	grep -v $BASEDIR /vpd.properties > /tmp/vpd.properties && cp /tmp/vpd.properties /usr/lib/objrepos/vpd.properties
	fi	
fi

if [ -d $APPDIR ]; then
	echo "Removing directory $APPDIR"
	cd /tmp
	rm -rf $APPDIR/*
	rm -fr /logs/was${VERSION}
	rm -fr /logs/wp${VERSION}
	rm -fr $BASEDIR/PortalServer > /dev/null
	echo "Removing WebShere $VERSION filesystem"
	umount $BASEDIR
	rmfs $BASEDIR
	if [ -d $BASEDIR ]; then
		rmdir $BASEDIR
	fi
fi

#-- Remove Backup cron --#
case $PLATFORM in
	AIX)	crontab -l root |grep "was_backup_config.sh $VERSION"
			if [ $? -eq 0 ]; then
				echo "Removing WAS $VERSION Backup crontab entry"
				crontab -l root |grep -v "was_backup_config.sh $VERSION $PROFILE" > /tmp/crontab.root
				su - root -c "crontab /tmp/crontab.root"
				rm /tmp/crontab.root
			fi
		;;
	Linux)	crontab -l -u root |grep "was_backup_config.sh $VERSION"
			if [ $? -eq 0 ]; then
				echo "Removing WAS $VERSION Backup crontab entry"
				crontab -l -u root |grep -v "was_backup_config.sh $VERSION $PROFILE" > /tmp/crontab.root
				crontab -u root /tmp/crontab.root
				rm /tmp/crontab.root
			fi
		;;
esac

if [ -f /etc/logrotate.d/was_logs ]; then
	#Only remove was_logs if there are no other WAS installs
	ls -d /usr/WebSphere* > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "Removing WAS logrotate configuration"
		rm -f /etc/logrotate.d/was_logs
	fi
fi
