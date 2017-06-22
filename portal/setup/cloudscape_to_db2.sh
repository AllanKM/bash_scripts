#!/bin/ksh

#Migrate Portal from cloudscape to db2

#globals
BASEDIR=/usr/WebSphere60

FILE="$BASEDIR/PortalServer/config/wpconfig_dbdomain.properties"
if [ ! -f "$FILE.orig" ]; then
	echo "Backing up original wpconfig_dbdomain.properties file"
	cp $FILE $FILE.orig
fi
cp /lfs/system/tools/portal/conf/wpconfig_dbdomain.properties $FILE
if [ $? -ne 0 ]; then
	print -u2 -- "#### Failed to find template wpconfig_dbdomain.properties file.  Exiting..."
	exit 1
fi

FILE="$BASEDIR/PortalServer/config/wpconfig_dbtype.properties"
if [ ! -f "$FILE.orig" ]; then
	echo "Backing up original wpconfig_dbtype.properties file"
	cp $FILE $FILE.orig
fi
cp /lfs/system/tools/portal/conf/wpconfig_dbtype.properties $FILE
if [ $? -ne 0 ]; then
	print -u2 -- "#### Failed to find template wpconfig_dbtype.properties file.  Exiting..."
	exit 1
fi

echo "Checking whether this node is a primary portal server for secondary"
PRIMARY=`grep PrimaryNode= $BASEDIR/PortalServer/config/wpconfig.properties`
echo "$PRIMARY"
case $PRIMARY in
	*true)
			grep "DbSafeMode=false" $FILE
			if [ $? -ne 0 ]; then
				print -u2 -- "#### Failed to set DbSafeMode=true on secondary portal server.  Exiting..."
				exit 1
			fi
			cd $BASEDIR/PortalServer/config
			./WPSconfig.sh database-transfer
			;;
	
	*false)
			echo "Modifing wpconfig_dbtype.properties file to set DbSafeMode=true"
			sed -e "s%DbSafeMode=false%DbSafeMode=true%" ${FILE}  > ${FILE}.custom && mv ${FILE}.custom  $FILE
			grep "DbSafeMode=true" $FILE
			if [ $? -ne 0 ]; then
				print -u2 -- "#### Failed to set DbSafeMode=true on secondary portal server.  Exiting..."
				exit 1
			fi
			cd $BASEDIR/PortalServer/config
			./WPSconfig.sh validate-database-driver
			if [ $? -ne 0 ]; then
				print -u2 -- "#### Failed to validate database drivers and connectivity.  Exiting..."
				exit 1
			fi
			./WPSconfig.sh connect-database
			;;
esac

