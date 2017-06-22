#!/bin/ksh

#First use expand_wps_ear.sh to extract wps.ear and exand it to /tmp/wps_expanded
# Update ear in wps_expanded
# Then run update_wps.ear.sh to collapse the changes into a new wps.ear file and deploy the modified ear

if [ ! -d /tmp/wps_expanded ]; then
	print -u2 -- "#### Failed to locate expanded wps.ear under /tmp/wps_expanded.   Exiting..."
	exit 1
fi

cd /tmp

if [ -f /tmp/wps.ear ]; then
	rm /tmp/wps.ear
fi

su - webinst -c " /usr/WebSphere60/AppServer/profiles/*Manager/bin/EARExpander.sh -ear /tmp/wps.ear -operationDir /tmp/wps_expanded -operation collapse"
if [ ! -f /tmp/wps.ear ]; then
	print -u2 -- "#### Failed to collapse /tmp/wps_expanded to /tmp/wps.ear.   Exiting..."
	exit 1
fi

echo "Deploying updated wps.ear file"
su - webinst -c "/usr/WebSphere60/AppServer/profiles/*Manager/bin/wsadmin.sh -c '\$AdminApp install /tmp/wps.ear {-update -appname wps}'"
 /lfs/system/tools/was/setup/was_perms.ksh