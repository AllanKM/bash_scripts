#!/bin/ksh
if [ ! -d /db2_database/wpsibmdb/backup ]; then
        mkdir /db2_database/wpsibmdb/backup
fi

#Update db2cli.ini
grep ReturnAliases /db2_database/wpsibmdb/sqllib/cfg/db2cli.ini > /dev/null
if [ $? -ne 0 ]; then
	echo "Updating [COMMON] stanza in db2cli.ini"
	print "\n[COMMON]\nDYNAMIC=1\nReturnAliases=0\n\n" >> /db2_database/wpsibmdb/sqllib/cfg/db2cli.ini
fi

DATABASES="wpsdb lmdb fdbkdb jcrdb"
for dbname in `echo $DATABASES`; do
		echo "Creating $dbname"
        db2 create database $dbname using codeset utf-8 territory us collate using UCA400_NO pagesize 8192
        if [ $? -ne 0 ]; then
                echo "Failed to create database $dbname"
                echo "exiting..."
                exit 1
        else
                echo "Configuring $dbname database"
                db2 update db cfg for $dbname using applheapsz 4096 > /dev/null
                db2 update db cfg for $dbname using app_ctl_heap_sz 1024 > /dev/null
                db2 update db cfg for $dbname using stmtheap 8192 > /dev/null
                db2 update db cfg for $dbname using dbheap 2400 > /dev/null
                db2 update db cfg for $dbname using locklist 1000 > /dev/null
                db2 update db cfg for $dbname using logfilsiz 1000 > /dev/null
                db2 update db cfg for $dbname using logprimary 12 > /dev/null
                db2 update db cfg for $dbname using logsecond 20 > /dev/null
                db2 update db cfg for $dbname using logbufsz 32 > /dev/null
                db2 update db cfg for $dbname using avg_appls 5 > /dev/null
                db2 update db cfg for $dbname using locktimeout 30 > /dev/null
                db2 update db cfg for $dbname using logretain on > /dev/null
                echo "Backing up $dbname"
                db2 backup database $dbname to ~/backup
                db2 connect to $dbname
                db2 grant connect on database to wpsibmus
                /fs/system/tools/db2/grant_select_to_all.ksh $dbname wpsibmus > /dev/null
                db2 disconnect current
        fi

        if [ "$dbname" == "jcrdb" ]; then
                echo "Doing jcrdb specific configuration"
                db2 connect to jcrdb
                db2 create bufferpool JCR8K size 1000 pagesize 8K
                db2 "create tablespace JCR8K_TS pagesize 8K managed by database using (FILE '/db2_database/wpsibmdb/wpsibmdb/NODE0000/SQL00004/JCR8K_TS' 10000) bufferpool JCR8K"
                db2 create bufferpool ICMLSFREQBP4 size 1000 pagesize 4K
                db2 create bufferpool ICMLSVOLATILEBP4 size 8000 pagesize 4K
                db2 create bufferpool ICMLSMAINBP32 size 8000 pagesize 32K
                db2 create bufferpool CMBMAIN4 size 1000 pagesize 4K
                db2 "create regular tablespace ICMLFQ32 pagesize 32K managed by system using ('ICMLFQ32') bufferpool ICMLSMAINBP32"
                db2 "create regular tablespace ICMLNF32 pagesize 32K managed by database using (FILE '/db2_database/wpsibmdb/wpsibmdb/NODE0000/SQL00004/ICMLNF32_TS' 10000) bufferpool ICMLSMAINBP32"
                db2 "create regular tablespace ICMVFQ04 pagesize 4K managed by system using ('ICMVFQ04') bufferpool ICMLSVOLATILEBP4"
                db2 "create regular tablespace ICMSFQ04 pagesize 4k managed by database using (FILE '/db2_database/wpsibmdb/wpsibmdb/NODE0000/SQL00004/ICMSFQ04_TS' 10000) bufferpool ICMLSFREQBP4"
                db2 "create regular tablespace CMBINV04 pagesize 4K managed by database using (FILE '/db2_database/wpsibmdb/wpsibmdb/NODE0000/SQL00004/CMBINV04_TS' 10000) bufferpool CMBMAIN4"
                db2 "create system temporary tablespace ICMLSSYSTSPACE32 pagesize 32K managed by system using ('icmlssystspace32') bufferpool ICMLSMAINBP32"
                db2 "create system temporary tablespace ICMLSSYSTSPACE4 pagesize 4K managed by system using ('icmlssystspace4') bufferpool ICMLSVOLATILEBP4"
                db2 disconnect current
        fi
done

echo "Updating crontab for wpsibmdb"
crontab /lfs/system/tools/portal/conf/wpsibmdb_crontab

echo "Crontab now contains:"
crontab -l


