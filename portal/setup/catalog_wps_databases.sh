#!/bin/ksh


#Ensure wpsNode can be resolved
host wpsNode > /dev/null
if [ $? -ne 0 ]; then
	echo "Update /etc/hosts to resolve wpsNode"
	exit 1
fi

#Ensure db2 client is installed
if [ ! -f /usr/opt/db2_08_01/instance/db2icrt ]; then
    echo "Installing DB2 client code"
    /lfs/system/tools/db2/setup/instdb2 -81
fi

if [ ! -d /db2_database ]; then
	echo "Creating /db2_database filesystem"
	/lfs/system/tools/configtools/make_filesystem /db2_database 100 appvg
fi

id wpsibmdb > /dev/null
if [ $? -ne 0 ]; then
	echo "Creating wpsibmdb user"
	/fs/system/tools/auth/bin/mkeigroup -r local wpsdb2 
	/fs/system/tools/auth/bin/mkeiuser -r local wpsibmdb wpsdb2 /db2_database/wpsibmdb
fi
	
if [ ! -d ~wpsibmdb/sqllib ]; then
	echo "Creating db2 client instance for wpsibmdb"
    /usr/opt/db2_08_01/instance/db2icrt -s client wpsibmdb
    if [ $? -ne 0 ]; then
	print -u2 --  "###Failed to create client instance wpsibmdb"
	exit 1
    fi
fi


echo "Catalog Portal databases"
su - wpsibmdb -c ". ~/.profile; db2 list node directory" | grep -i wpsnode > /dev/null
if [ $? -ne 0 ]; then 
	su - wpsibmdb -c ". ~/.profile; db2 catalog tcpip node wpsnode remote wpsnode server 60000 with WPS_DB"
	if [ $? -ne 0 ]; then
    	print -u2 --  "###Failed to catalog tcpip node"
    	exit 1
	fi
fi

DATABASES="wpsdb lmdb fdbkdb jcrdb"
for dbname in `echo $DATABASES`; do
	su - wpsibmdb -c ". ~/.profile; db2 list database directory" | grep -i $dbname > /dev/null
	if [ $? -ne 0 ]; then 
		echo "Creating catalog entry for $dbname"
		su - wpsibmdb -c ". ~/.profile; db2 catalog database $dbname at node wpsnode"
		if [ $? -ne 0 ]; then
    		print -u2 --  "###Failed to catalog $dbname database"
    		exit 1
		fi
	fi
done

#Add [WPSDB] stanza to db2cli.ini
grep WPSDB /db2_database/wpsibmdb/sqllib/cfg/db2cli.ini > /dev/null
if [ $? -ne 0 ]; then
	echo "Updating [WPSDB] stanza in db2cli.ini"
	print "\n[WPSDB]\ndbalias=WPSDB\nCurrentSchema=WPSIBMDB\nCurrentFunctionPath=\"SYSIBM\",\"SYSFUN\",\"SYSPROC\",\"WPSIBMDB\",\"WPSIBMUS\"\n\n" >> /db2_database/wpsibmdb/sqllib/cfg/db2cli.ini
fi

#update common stanza in db2cli.ini
grep ReturnAliases /db2_database/wpsibmdb/sqllib/cfg/db2cli.ini > /dev/null
if [ $? -ne 0 ]; then
	echo "Updating [COMMON] stanza in db2cli.ini"
	print "\n[COMMON]\nDYNAMIC=1\nReturnAliases=0\n\n" >> /db2_database/wpsibmdb/sqllib/cfg/db2cli.ini
fi

#Ensure webinst runs the .profile for wpsibmdb
id webinst > /dev/null 2>&1
if [  $? -ne 0 ]; then
    /fs/system/tools/auth/bin/mkeigroup -r local -f apps
    /fs/system/tools/auth/bin/mkeiuser  -r local -f webinst apps
fi
grep wpsibmdb ~webinst/.profile > /dev/null
if [ $? -ne 0 ]; then
	print "\n. /db2_database/wpsibmdb/sqllib/db2profile\n" >> ~webinst/.profile
fi

echo "Testing connection to the wpsdb database as the webinst user"
su - webinst  -c ". ~/.profile; db2 connect to wpsdb user wpsibmdb using tmp4now"

 