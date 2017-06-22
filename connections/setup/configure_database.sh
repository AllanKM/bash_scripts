#!/bin/ksh

DESCRIPTION="IBMCOM Lotus Connections"
OWNERID=lcibmdb
GROUP=lcibmdb2
APPID=lcuser

if lsvg appvg2 >/dev/null 2>&1; then
	VG=appvg2
elif lsvg appvg >/dev/null 2>&1; then
	VG=appvg
else
	VG=rootvg
fi


/opt/IBM/db2/V9.1/install/db2ls -q 2>/dev/null | grep BASE_DB2_ENGINE > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Use create_database_instance.sh to install DB2 server code"
    exit 1
fi

/opt/IBM/db2/V9.1/instance/db2ilist | grep $OWNERID >/dev/null
if [ $? -ne 0 ]; then
	echo "Use create_database_instance.sh to creating DB2 server instance"
	exit 1
fi
	
if [ ! -d /db2_database/${OWNERID}/scripts ]; then
	echo "Creating scripts subdirectory: /db2_database/${OWNERID}/scripts"
	mkdir /db2_database/${OWNERID}/scripts
	chown ${OWNERID}:$GROUP /db2_database/${OWNERID}/scripts
	chmod 755 /db2_database /db2_database/${OWNERID}/scripts
fi

if [ ! -d /db2_database/${OWNERID}/bin ]; then
	echo "Creating bin subdirectory: /db2_database/${OWNERID}/bin"
	cp -Rp /fs/system/config/db2/instance_owner_config/bin /db2_database/${OWNERID}
	chown -R ${OWNERID}:$GROUP /db2_database/${OWNERID}/bin
	chmod -R 755 /db2_database /db2_database/${OWNERID}/bin
fi

if [ ! -d /db2_database/${OWNERID}/backup ]; then
	echo "Creating /db2_database/${OWNERID}/backup filesystem"
	/lfs/system/tools/configtools/make_filesystem /db2_database/${OWNERID}/backup 2048 $VG
    chown  ${OWNERID}:$GROUP /db2_database/${OWNERID}/backup
	chmod  0700 /db2_database/${OWNERID}/backup
	umount /db2_database/${OWNERID}/backup
	chown  ${OWNERID}:$GROUP /db2_database/${OWNERID}/backup
	chmod  0700  /db2_database/${OWNERID}/backup
	mount  /db2_database/${OWNERID}/backup
	
fi	

if [ -d /db2_database/${OWNERID}/${OWNERID} ]; then
	chmod -R o-rwx /db2_database/${OWNERID}/${OWNERID}
fi

DATABASES="DOGEAR BLOGS HOMEPAGE SNCOMM OPNACT PEOPLEDB"
for dbname in `echo $DATABASES`; do
	su - $OWNERID -c ". ~/.profile; db2 list database directory" | grep $dbname >/dev/null
	if [ $? -ne 0 ]; then
		echo "Use the dbWizard.sh script provided by Lotus Connections to create the $dbname database"
		echo "After databases are created then run this scipt to do post configurations" 
	else
		echo "Performing backup for $dbname"
		su - ${OWNERID} -c ". ~/.profile; db2 update db cfg for $dbname using logretain on"	
		su - ${OWNERID} -c ". ~/.profile; db2 backup database $dbname to /db2_database/${OWNERID}/backup"		
	fi
done

if [ ! -f /etc/logrotate.d/db2diag.log ]; then
	echo "Creating db2diag.log stanza"
	cp /lfs/system/tools/connections/conf/db2diag /etc/logrotate.d/
	chown root:system /etc/logrotate.d/db2diag
	chmod 444 /etc/logrotate.d/db2diag
fi

if [ ! -f /etc/logrotate.d/db2maint ]; then
	echo "Creating db2maint stanza"
	cp /lfs/system/tools/connections/conf/db2maint /etc/logrotate.d/
	chown root:system /etc/logrotate.d/db2maint
	chmod 444 /etc/logrotate.d/db2maint
fi

echo "Saving local instance configuration information"
su - ${OWNERID} -c ". ~/.profile; /lfs/system/tools/db2/bin/get_db2_local_instance_cfg ${OWNERID}"
ls -l /db2_database/${OWNERID}/cfg

echo "Updating crontab for $OWNERID"
su - $OWNERID -c "crontab /lfs/system/tools/connections/conf/lcibmdb_crontab"

echo "Crontab now contains:"
su - $OWNERID -c "crontab -l"

echo "Running DB2 Cops"
su - $OWNERID -c ". ~/.profile; /fs/system/tools/db2/perform_local_db2cops ${OWNERID}"

