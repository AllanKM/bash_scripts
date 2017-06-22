#!/bin/ksh

# Expand the WPS ear on deployment manager for theme updates or for updates from Portal fixpacks

BASEDIR=/usr/WebSphere60

if [ ! -d $BASEDIR/AppServer/profiles/*Manager ]; then
		print -u2 -- "#### Failed to locate Deployment Manager directory on this server.  Exiting..."
		exit 1
fi


if [ -f /tmp/wps.ear ]; then
	echo "Removing existing /tmp/wps.ear"
	rm /tmp/wps.ear
fi

echo "Exporting wps.ear to /tmp/wps.ear"
su - webinst -c "/usr/WebSphere60/AppServer/profiles/*Manager/bin/wsadmin.sh -c '\$AdminApp export wps /tmp/wps.ear'"
if [ ! -f /tmp/wps.ear ]; then
	print -u2 -- "#### Failed to export wps.ear to /tmp/wps.ear.   Exiting..."
	exit 1
fi

if [ -d /tmp/wps_expanded ]; then
	echo "Removing previous /tmp/wps_expanded directory"
	rm -fr /tmp/wps_expanded
fi

echo "Expanding wps.ear to /tmp/wps_expanded"
su - webinst -c " /usr/WebSphere60/AppServer/profiles/*Manager/bin/EARExpander.sh -ear /tmp/wps.ear -operationDir /tmp/wps_expanded -operation expand"
if [ ! -d /tmp/wps_expanded ]; then
	print -u2 -- "#### Failed to expand wps.ear.   Exiting..."
	exit 1
fi

chgrp -R eiadm /tmp/wps_expanded
chmod -R g+rwx /tmp/wps_expanded

