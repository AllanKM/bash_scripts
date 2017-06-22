#!/bin/ksh
# Author: Russ Scadden
# Set permissions on /projects/<app_name> directories
# This script should be ran as a "postInstallCmd" for each application sync resource  
# through configtool
#
# USAGE: app_perms.sh [list of applications]
#
# webinst is set as the owner of files under /projects/<app_name>/properties.  
# Also additional group settings and permissions are set
# if the file /projects/<app_name>/config/permlist.cfg is found

if [ "$1" == "" ]; then
	print -u2 "#### Provide the name(s) of the application(s) where permissions on /projects/<app>  will be set"
	exit 1
fi

for APP in $@ ; do
		if [ -d "/projects/${APP}" ]; then
			echo "Setting permission on /projects/${APP}"
			chown root:eiadm /projects/${APP}
			chmod 755 /projects/${APP} 
			chown -R webinst:eiadm /projects/${APP}/*
			find /projects/${APP}/* -follow -type d -exec chmod 770 {} \;
			find /projects/${APP}/* -follow -type f -exec chmod 660 {} \;
		fi
		if [ -d "/projects/${APP}/config" ]; then
		#Config files should be updated in shared file system space where the gold copy resides
			chown -R root:eiadm /projects/${APP}/config
			find /projects/${APP}/config -follow -type d -exec chmod 750 {} \;
			find /projects/${APP}/config -follow -type f -exec chmod 640 {} \;
		fi	
		if [ -d "/projects/${APP}/bin" ]; then
		#Allow root to execute scripts in the bin subdirectory to manage the app
			find /projects/${APP}/bin -follow -type f -exec chmod 740 {} \;
		fi	
		if [ -f "/projects/${APP}/config/permlist.cfg" ]; then
			cat /projects/${APP}/config/permlist.cfg | /lfs/system/tools/configtools/set_permissions.sh 
		fi
done
