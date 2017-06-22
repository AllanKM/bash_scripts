#!/bin/ksh
# Calls xmlaccess.sh to import a portal configuration file 
# Use export_portal_configuration.sh to obtain an xml file of one portal environment .. like that in staging
# Build a release file comparing two environments using:
# sudo /usr/WebSphere60/PortalServer/bin/releasebuilder.sh -inOld /tmp/production.xml  -inNew /tmp/staging.xml -out /tmp/newrelease.xml
#
# Usage:
#        import_portal_configuration.sh <name of release file>

#Globals
WAS_TOOLS=/lfs/system/tools/was
PORTAL_TOOLS=/lfs/system/tools/portal
PORTAL_PASSWD=$PORTAL_TOOLS/etc/was_passwd
HOST=`/bin/hostname -s`
INFILE=${1:-/tmp/newrelease.xml}
ROLE=`/usr/bin/lssys -n -lrole | grep role | cut -d= -f2`

if [ ! -f $INFILE ]; then
	print -u2 -- "#### Failed to locate xml file to use as input: $INFILE"
	exit 1
fi

#Match node to DM
case $ROLE in 
	*WPS.IBM.TEST*)  	PORTALID=ibmwpt   ;;
	*WPS.IBM.STAGE*) 	PORTALID=ibmwps   ;;
	*WPS.IBM.PROD*) 	PORTALID=ibmwpp   ;;
				 *) 	print -u2 -- "#### Update $0 to correlate $ROLE to a Deployment Manager.   Exiting..."
						exit 1
						;;
esac

echo "Looking up portal admin password"
encrypted_passwd=$(grep $PORTALID /lfs/system/tools/portal/etc/portal_passwd |awk '{split($0,pwd,"ibmwp.="); print pwd[2]}' |sed -e 's/\\//g')
passwd_string=`/lfs/system/tools/was/bin/PasswordDecoder.sh $encrypted_passwd`
adminPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")


echo "Importing config from: $INFILE"
/usr/WebSphere60/PortalServer/bin/xmlaccess.sh -in $INFILE -user ${PORTALID}@events.ihost.com -password $adminPass  -url http://localhost:9080/account/config