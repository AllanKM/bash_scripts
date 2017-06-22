#!/bin/ksh

# This script updates wpconfig.properties to be used when passwords are needed back in the file
# use ./WPSconfig.sh action-delete-passwords-6011 to remove the passwords


#globals
BASEDIR=/usr/WebSphere60
CONFDIR="$BASEDIR/PortalServer/config"
HOST=`/bin/hostname -s`
ROLE=`/usr/bin/lssys $HOST | grep role | cut -d= -f2`



#Match node to DM
case $ROLE in 
	*WPS.IBM.TEST*)  	PORTALPWD=ibmwpt   ;;
	*WPS.IBM.STAGE*) 	PORTALPWD=ibmwps   ;;
	*WPS.IBM.PROD*) 	PORTALPWD=ibmwpp   ;;
				 *) 	print -u2 -- "#### Update $0 to correlate $ROLE to a Deployment Manager.   Exiting..."
						exit 1
						;;
esac

#Obtain passwords from password store
echo "Looking up was admin password"
encrypted_passwd=$(grep global_security /lfs/system/tools/was/etc/was_passwd |awk '{split($0,pwd,"global_security="); print pwd[2]}' |sed -e 's/\\//g')
passwd_string=`/lfs/system/tools/was/bin/PasswordDecoder.sh $encrypted_passwd`
wasPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")

echo "Looking up portal admin password"
encrypted_passwd=$(grep $PORTALPWD /lfs/system/tools/portal/etc/portal_passwd |awk '{split($0,pwd,"ibmwp.="); print pwd[2]}' |sed -e 's/\\//g')
passwd_string=`/lfs/system/tools/was/bin/PasswordDecoder.sh $encrypted_passwd`
adminPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")

echo "Looking up database user password"
encrypted_passwd=$(grep wpsibmus /lfs/system/tools/portal/etc/portal_passwd |awk '{split($0,pwd,"wpsibmus="); print pwd[2]}' |sed -e 's/\\//g')
passwd_string=`/lfs/system/tools/was/bin/PasswordDecoder.sh $encrypted_passwd`
dbPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")



FILE="$BASEDIR/PortalServer/config/wpconfig.properties"
cp $FILE /tmp/wpconfig.properties.nopasswords
if [ $? -ne 0 ]; then
	print -u2 -- "#### Failed to backup a copy of wpconfig.properties.  Exiting..."
	exit 1
fi	

echo "Modifying settings in wpsconfig.properties file"
sed -e "s%WasPassword=ReplaceWithYourPassword%WasPassword=$wasPass%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%PortalAdminPwd=ReplaceWithYourPwd%PortalAdminPwd=$adminPass%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
chown webinst:eiadm $FILE
chmod og+rw $FILE

FILE="$BASEDIR/PortalServer/config/wpconfig_dbdomain.properties"
cp $FILE /tmp/wpconfig_dbdomain.properties.nopasswords
if [ $? -ne 0 ]; then
	print -u2 -- "#### Failed to backup a copy of wpconfig_dbdomain.properties.  Exiting..."
	exit 1
fi	
echo "Modifying settings in wpconfig_dbdomain.properties file"
sed -e "s%DbUser=wpsibmdb%DbUser=wpsibmus%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%DbPassword=tmp4now%DbPassword=$dbPass%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
sed -e "s%DbPassword=ReplaceWithYourPassword%DbPassword=$dbPass%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
chown webinst:eiadm $FILE
chmod og+rw $FILE
