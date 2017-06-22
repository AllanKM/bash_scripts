#!/bin/ksh

# Run after install_portal.sh
# This script sets values in wpconfig.properties and then executes WPSconfig.sh basic-config
	

#globals
BASEDIR=/usr/WebSphere60
CONFDIR="$BASEDIR/PortalServer/config"
HOST=`/bin/hostname -s`
ROLE=`/usr/bin/lssys $HOST | grep role | cut -d= -f2`
CONTEXTROOT=wps
HOMEURI=portal
PERSONALIZEDURI=myportal


#Match node to DM
case $ROLE in 
	*WPS.IBM.TEST*)  	CELL=yzt60ps
						ADMIN=ibmwpt
						ZONE=y
						SERVERNAME="${HOST}_ibmtest_wps"
						VIRTUALHOST=ibm_tst_host
						PORTALADMIN='uid=060001TJFTWI,ou=persons,o=ibm.com'
						PORTALGROUP='cn=IBMWPT Admins,ou=groups,o=ibm.com'
						PORTALPWD=ibmwpt
						CLUSTER=tst_cluster_ibm_wps
						;;
	*WPS.IBM.STAGE*) 	CELL=gzs60udibm 
						ADMIN=ibmwps
						ZONE=g
						SERVERNAME="${HOST}_ibmstage_wps"
						VIRTUALHOST=ibmcom_stg_host
						PORTALADMIN='uid=060001TJFKWI,ou=persons,o=ibm.com'
						PORTALGROUP='cn=IBMWPS Admins,ou=groups,o=ibm.com'
						PORTALPWD=ibmwps
						CLUSTER=stg_cluster_ibm_wps
						;;
	*WPS.IBM.PROD*) 	CELL=gzp60udibm
						ADMIN=ibmwpp
						ZONE=g
						SERVERNAME="${HOST}_ibm_wps"
						VIRTUALHOST=ibmcom_host
						PORTALADMIN='uid=060001TJG6WI,ou=persons,o=ibm.com'
						PORTALGROUP='cn=IBMWPP Admins,ou=groups,o=ibm.com'
						PORTALPWD=ibmwpp
						CLUSTER=cluster_ibm_wps
						;;
				 *) 	print -u2 -- "#### Update $0 to correlate $ROLE to a Deployment Manager.   Exiting..."
						exit 1
						;;
esac

#Label the primary WPS nodes 
case $HOST in
	at0701m) PRIMARY=true ;;
	at0702d) PRIMARY=true ;;
	at1002j) PRIMARY=true ;;
	      *) PRIMARY=false ;;
esac

#Obtain passwords from password store
echo "Looking up keystore password"
encrypted_passwd=$(grep ssl_keystore /lfs/system/tools/was/etc/was_passwd |awk '{split($0,pwd,"ssl_keystore="); print pwd[2]}' |sed -e 's/\\//g')
passwd_string=`/lfs/system/tools/was/bin/PasswordDecoder.sh $encrypted_passwd`
keyPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")

echo "Looking up was admin password"
encrypted_passwd=$(grep global_security /lfs/system/tools/was/etc/was_passwd |awk '{split($0,pwd,"global_security="); print pwd[2]}' |sed -e 's/\\//g')
passwd_string=`/lfs/system/tools/was/bin/PasswordDecoder.sh $encrypted_passwd`
wasPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")

echo "Looking up portal admin password"
encrypted_passwd=$(grep $PORTALPWD /lfs/system/tools/portal/etc/portal_passwd |awk '{split($0,pwd,"ibmwp.="); print pwd[2]}' |sed -e 's/\\//g')
passwd_string=`/lfs/system/tools/was/bin/PasswordDecoder.sh $encrypted_passwd`
adminPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")

MASTER="$BASEDIR/PortalServer/config/wpconfig.properties"
cp $MASTER $MASTER.orig
if [ $? -ne 0 ]; then
	print -u2 -- "#### Failed to backup original copy of wpconfig.properties.  Exiting..."
	exit 1
fi	

echo "Extracting PortalUniqueID from original wpconfig.properties"
id_string=`grep 'PortalUniqueID=' $MASTER`
uniqueID=`echo $id_string | cut -d= -f2`

FILE=/tmp/v60_wpconfig.properties
cp /lfs/system/tools/portal/conf/v60_wpconfig.properties $FILE 
if [ $? -ne 0 ]; then
	print -u2 -- "#### Failed to copy v60_wpconfig.properties to $FILE.  Exiting..."
	exit 1
fi	

echo "Modifying settings in wpsconfig.properties file"

sed -e "s%\[virtual host\]%$VIRTUALHOST%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%\[was password\]%$wasPass%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%\[primary node\]%$PRIMARY%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%\[cluster\]%$CLUSTER%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%\[cell\]%$CELL%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%\[host\]%$HOST%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%\[server name\]%$SERVERNAME%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%\[context root\]%$CONTEXTROOT%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%\[home uri\]%$HOMEURI%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%\[personalized uri\]%$PERSONALIZEDURI%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%\[admin id\]%$PORTALADMIN%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%\[admin password\]%$adminPass%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%\[admin group\]%$PORTALGROUP%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%\[unique id\]%$uniqueID%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%\[key pass\]%$keyPass%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE

cp $FILE $MASTER

echo "commenting out line that generates plugin"
FILE="$BASEDIR/PortalServer/config/wpconfig.xml"
cp $FILE $FILE.orig
sed -e "s%<antcall target=\"action-generate-http-plugin\"/>%<!-- <antcall target=\"action-generate-http-plugin\"/> -->%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%<antcall target=\"action-modify-scheduler-base-properties-cleanup-daemon\"/>%<!-- <antcall target=\"action-modify-scheduler-base-properties-cleanup-daemon\"/> -->%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%<antcall target=\"action-modify-scheduler-custom-properties-cleanup-daemon\"/>%<!-- <antcall target=\"action-modify-scheduler-custom-properties-cleanup-daemon\"/> -->%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE


echo "Commenting out line for pznauthor call that fails on unix"
FILE="$BASEDIR/PortalServer/config/includes/pzn_cfg.xml"
cp $FILE $FILE.orig
sed -e "s%<antcall target=\"action-update-context-pznauthor\"/>%<!-- <antcall target=\"action-update-context-pznauthor\"/> -->%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%<antcall target=\"action-update-context-pznrule\"/>%<!-- <antcall target=\"action-update-context-pznrule\"/> -->%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE


echo "Kicking off basic-config task"
cd $BASEDIR/PortalServer/config
./WPSconfig.sh basic-config

