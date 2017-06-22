#!/bin/ksh


funcs=/lfs/system/tools/configtools/lib/check_functions.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

#globals
BASEDIR=/usr/WebSphere60
getZone

echo "Check out WMM configuration files from the deployment manager"
cd $BASEDIR/PortalServer/config
./WPSconfig.sh check-out-wmm-cfg-files-from-dmgr
if [ $? -ne 0 ]; then
	print -u2 -- "#### Failed to check out WMM configuration files.  Exiting..."
	exit 1
fi

#Obtain passwords from password store
echo "Looking up keystore password"
encrypted_passwd=$(grep ssl_keystore /lfs/system/tools/was/etc/was_passwd |awk '{split($0,pwd,"ssl_keystore="); print pwd[2]}' |sed -e 's/\\//g')
passwd_string=`/lfs/system/tools/was/bin/PasswordDecoder.sh $encrypted_passwd`
keyPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")


FILE="$BASEDIR/PortalServer/wmm/wmm_LDAP.xml"
if [ ! -f "$FILE.orig" ]; then
	echo "Backing up original wmm_LDAP.xml file"
	cp $FILE $FILE.orig
fi
cp /lfs/system/tools/portal/conf/v60_wmmUD.xml $FILE
if [ $? -ne 0 ]; then
	print -u2 -- "#### Failed to find template v60_wmmUD.xml file.  Exiting..."
	exit 1
fi

if [ "$ZONE" = "y" ]; then
		echo "Setting keystore to ei_yz_was.jks"
		sed -e "s%ei_gz_was%ei_yz_was%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
fi
sed -e "s%\[key pass\]%$keyPass%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE

echo "Checking Edits to $FILE"
grep "sslTrustStore=" $FILE | grep $BASEDIR
if [ $? -ne 0 ]; then
	print -u2 -- "#### Failed to update $FILE.  Exiting..."
	exit 1
fi

FILE="$BASEDIR/PortalServer/wmm/wmmLDAPAttributes.xml"
if [ ! -f "$FILE.orig" ]; then
	echo "Backing up original wmmLDAPAttributes.xml file"
	cp $FILE $FILE.orig
fi
cp /lfs/system/tools/portal/conf/v60_wmmLDAPAttributes.xml $FILE
if [ $? -ne 0 ]; then
	print -u2 -- "#### Failed to find v60_wmmLDAPAttributes.xml file.  Exiting..."
	exit 1
fi

echo "Checking edits to $FILE"
grep "authenid" $FILE
if [ $? -ne 0 ]; then
	print -u2 -- "#### Failed to update $FILE.  Exiting..."
	exit 1
fi

echo "Check in WMM configuration files to the deployment manager"
cd $BASEDIR/PortalServer/config
./WPSconfig.sh check-in-wmm-cfg-files-to-dmgr
if [ $? -ne 0 ]; then
	print -u2 -- "#### Failed to check in WMM configuration files.  Exiting..."
	exit 1
fi

echo "Updating PumaService.properties"
FILE="$BASEDIR/PortalServer/config/properties/PumaService.properties"
if [ ! -f "$FILE.orig" ]; then
	echo "Backing up original PumaService.properties file"
	cp $FILE $FILE.orig
fi
cp /lfs/system/tools/portal/conf/PumaService.properties $FILE
if [ $? -ne 0 ]; then
	print -u2 -- "#### Failed to find PumaService.properties template file.  Exiting..."
	exit 1
fi

echo "Checking edits to $FILE"
grep "authenid" $FILE
if [ $? -ne 0 ]; then
	print -u2 -- "#### Failed to update $FILE.  Exiting..."
	exit 1
fi

FILE="$BASEDIR/PortalServer/shared/app/config/services/PumaService.properties"
if [ ! -f "$FILE" ]; then
	cp /lfs/system/tools/portal/conf/PumaService.properties $FILE
	if [ $? -ne 0 ]; then
		print -u2 -- "#### Failed to find PumaService.properties template file.  Exiting..."
		exit 1
	fi
fi

echo "Executing the LDAP enablement task"
cd $BASEDIR/PortalServer/config
./WPSconfig.sh secure-portal-ldap
if [ $? -ne 0 ]; then
	print -u2 -- "#### secure-portal-ldap task failed.  Exiting..."
	exit 1
fi

#The wmm.xml file needs to be updated again in order for  SSL connections to LDAP to take palce 
#The following error will be seen in SystemOut.log if wmm.xml has "sslEnabled="false"  in it:
#[2/2/07 16:18:18:259 UTC] 0000000a WSMM Message  E com.ibm.ws.wmm.ldap.LdapConnectionImpl void initialize(Map envProperties) Initialization failed. Root cause is: "javax.naming.CommunicationException: Request: 1 cancelled".
#[2/2/07 16:18:18:279 UTC] 0000000a WSMM Message  E com.ibm.ws.wmm.objectimpl.MemberServiceBeanBase ejbCreate() java.lang.NullPointerException


echo "Putting a few files back in place that are overwritten by the WPSconfig.sh run of secure-portal-ldap"
echo "Check out WMM configuration files from the deployment manager"
cd $BASEDIR/PortalServer/config
./WPSconfig.sh check-out-wmm-cfg-files-from-dmgr
if [ $? -ne 0 ]; then
	print -u2 -- "#### Failed to check out WMM configuration files.  Exiting..."
	exit 1
fi

FILE="$BASEDIR/PortalServer/wmm/wmmLDAPAttributes.xml"
cp /lfs/system/tools/portal/conf/v60_wmmLDAPAttributes.xml $FILE
if [ $? -ne 0 ]; then
	print -u2 -- "#### Failed to find v60_wmmLDAPAttributes.xml file.  Exiting..."
	exit 1
fi
echo "Checking edits to $FILE"
grep "authenid" $FILE
if [ $? -ne 0 ]; then
	print -u2 -- "#### Failed to update $FILE.  Exiting..."
	exit 1
fi
echo "wmm.xml is using wmmLDAPServerAttributes.xml.  Updating this file"
cp $FILE $BASEDIR/PortalServer/wmm/wmmLDAPServerAttributes.xml

#FILE="$BASEDIR/PortalServer/wmm/wmm.xml"
#if [ ! -f "$FILE.orig" ]; then
#	echo "Backing up original wmm.xml file"
#	cp $FILE $FILE.orig
#fi
#cp /lfs/system/tools/portal/conf/v60_wmmUD.xml $FILE
#if [ $? -ne 0 ]; then
#	print -u2 -- "#### Failed to find template v60_wmmUD.xml file.  Exiting..."
#	exit 1
#fi

#if [ "$ZONE" = "y" ]; then
#		echo "Setting keystore to ei_yz_was.jks"
#		sed -e "s%ei_gz_was%ei_yz_was%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
#fi
#sed -e "s%\[key pass\]%$keyPass%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE

#echo "Checking Edits to $FILE"
#grep "sslTrustStore=" $FILE | grep $BASEDIR
#if [ $? -ne 0 ]; then
#	print -u2 -- "#### Failed to update $FILE.  Exiting..."
#	exit 1
#fi

#Review  wmm.xml and make sure the following lines are set like this:
#	sslEnabled="true"
#	sslTrustStore="/usr/WebSphere60/AppServer/etc/ei_gz_was.jks"   ( if installing in yellowzone use ei_yz_was.jks )
#	sslTrustStorePassword="<put clear text password for ei_gz_was.jks here>

echo "Check in WMM configuration files to the deployment manager"
cd $BASEDIR/PortalServer/config
./WPSconfig.sh check-in-wmm-cfg-files-to-dmgr
if [ $? -ne 0 ]; then
	print -u2 -- "#### Failed to check in WMM configuration files.  Exiting..."
	exit 1
fi

echo "Ensuring PumaService.properties file still has desired updates"
FILE="$BASEDIR/PortalServer/config/properties/PumaService.properties"
echo "Checking edits to $FILE"
grep "authenid" $FILE
if [ $? -ne 0 ]; then
	echo "Edits lost in $FILE.  Updating from template"
	cp /lfs/system/tools/portal/conf/PumaService.properties $FILE
fi

FILE="$BASEDIR/PortalServer/shared/app/config/services/PumaService.properties"
echo "Checking edits to $FILE"
grep "authenid" $FILE
if [ $? -ne 0 ]; then
	echo "Edits lost in $FILE.  Updating from template"
	cp /lfs/system/tools/portal/conf/PumaService.properties $FILE
fi