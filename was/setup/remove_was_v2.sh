#!/bin/bash
#---------------------------------------------------------------
# Uninstall WebSphere Application Server (run as sudo)
#---------------------------------------------------------------
#
# USAGE: remove_was_v2.sh [VERSION] [nostop]
#
#---------------------------------------------------------------
#
#  Change History: 
#
#  Lou Amodeo - 03/01/2013 - Initial creation
#  Lou Amodeo - 03/29/2013 - Add support for Java 7
#  Lou Amodeo - 12/12/2013 - change rmfs to /fs/system/bin/eirmfs
#
#
#---------------------------------------------------------------
#

# Which version of WAS is to be removed
FULLVERSION=${1:-85000}
VERSION=`echo $FULLVERSION | cut -c1-2`
NOSTOP=$2
PACKAGE="com.ibm.websphere.ND.v85"
J7PACKAGE="com.ibm.websphere.IBMJAVA.v70"
BASEDIR="/usr/WebSphere${VERSION}"
APPDIR="${BASEDIR}/AppServer"
IMBASEDIR="/opt/IBM/InstallationManager"
PLATFORM=`uname`

if [ ! $VERSION -eq 85 ]; then
    echo "VERSION $FULLVERSION must be 8.5.x.x"
    exit 1
fi

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

#-----------------------------------------------------------------------
# If Java 7 is installed it must be removed separately and first        
#-----------------------------------------------------------------------
JAVA7DIR="${APPDIR}/java_1.7_64"
if [ -d ${JAVA7DIR} ]; then
    echo "Uninstalling (optional) Java 7 prior to WebSphere Application Server"
    $IMBASEDIR/eclipse/tools/imcl uninstall $J7PACKAGE
fi

echo "-----------------------------------------------------------------------------------------"
echo " Uninstalling WebSphere Application Server version: $VERSION package: $PACKAGE           "
echo " Location: $APPDIR                                                                       "
echo
echo "-----------------------------------------------------------------------------------------"
echo

$IMBASEDIR/eclipse/tools/imcl uninstall $PACKAGE
if [ $? -ne 0 ]; then 
    echo "Failed to uninstall package: $PACKAGE.  Exiting...."
    exit 1
fi

if [ -d $APPDIR ]; then
	echo "Removing directory $APPDIR"
	cd /tmp
	rm -rf $APPDIR/*
	rm -fr /logs/was${VERSION}	
	echo "Removing $BASEDIR filesystem"
	/fs/system/bin/eirmfs -f $BASEDIR
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

echo "-------------------------------------------------------------------------------------"
echo " Uninstalled WebSphere successfully                                                   "
echo
echo "--------------------------------------------------------------------------------------"
echo
exit 0
