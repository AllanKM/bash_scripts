#!/bin/ksh
#---------------------------------------------------------------------------------
#
# Change History: 
#
#  Lou Amodeo     11-08-2013  Follow symbolic links for chown of /usr/WebSphere*  
#  Lou Amodeo     08-26-2013  Add support for shared customer permissions
#
#
#---------------------------------------------------------------------------------

echo "Setting ownership and permissions for WebSphere..."
chown -RL webinst:eiadm /usr/WebSphere* > /dev/null 2>&1
chown -R  webinst:eiadm /logs/was* /logs/wp*  > /dev/null 2>&1
chmod g+s /usr/WebSphere* /logs/was* /logs/wp* > /dev/null 2>&1
chmod -R ug+rwx,o-rwx /usr/WebSphere* /logs/was* /logs/wp* > /dev/null 2>&1
find /usr/WebSphere*/AppServer/bin/ -type f -exec chmod g-x {} \;  > /dev/null 2>&1
find /usr/WebSphere*/AppServer/profiles/*/bin/ -type f -exec chmod g-x {} \; > /dev/null 2>&1
chmod g-x /usr/WebSphere*/DeploymentManager/bin/* > /dev/null 2>&1
chmod g-x /usr/WebSphere*/PortalServer/bin/* > /dev/null 2>&1

echo "...Complete"

#Look for /projects/<app>/config/permlist.cfg and set permissions accordingly
for PERMS in `ls /projects/*/config/permlist.cfg 2>/dev/null`; do
	echo "Setting permission as outlined in $PERMS"
	if [ -f "$PERMS" ]; then
		cat $PERMS | /lfs/system/tools/configtools/set_permissions.sh 
	fi
done
for PERMS in `ls /projects/*/config/waspermlist.cfg 2>/dev/null`; do
	echo "Setting permission as outlined in $PERMS"
	if [ -f "$PERMS" ]; then
		cat $PERMS | /lfs/system/tools/configtools/set_permissions.sh 
	fi
done
for PERMS in `ls /projects/shared/config/sharedwaspermlist.cfg 2>/dev/null`; do
    echo "Setting permission as outlined in $PERMS"
    if [ -f "$PERMS" ]; then
        cat $PERMS | /lfs/system/tools/configtools/set_permissions.sh 
    fi
done
exit 0
