#!/bin/ksh

# This is ran on DATABASE.EVENT.YZ nodes
# (at1006f, dt1206f, gt0806f)
# One server in each site
VERSION=${1:-91}

if [ ! -f /usr/opt/db2_08_01/instance/db2icrt -a ! -f /opt/IBM/db2/V9.1/instance/db2icrt ]; then
    echo "Installing DB2 server code"
    /fs/system/tools/db2/instdb2 -server -$VERSION
fi

echo "Creating filesystems"
if lsvg appvg >/dev/null 2>&1; then
        VG=appvg
else
        VG=rootvg
fi
/lfs/system/tools/configtools/make_filesystem /db2_database 256 $VG
/lfs/system/tools/configtools/make_filesystem /db2_database/wbimbdb 2048 $VG

echo "Creating IDs"
/fs/system/tools/auth/bin/mkeigroup -r local -d "WBIMB Instance admin group" -f wbidb2
/fs/system/tools/auth/bin/mkeiuser  -r local -t apps -d "WBIMB Instance Owner" -f wbimbdb wbidb2 /db2_database/wbimbdb
/fs/system/tools/auth/bin/mkeiuser -x -r local -t apps -d "WBIMB Instance User" -f wbimbus wbidb2

echo "Creating Instance"
if [ "$VERSION" = "91" ]; then
    DBDIR=/opt/IBM/db2/V9.1
else
    DBDIR=/usr/opt/db2_08_01
fi
${DBDIR}/instance/db2icrt -s ese -p 62000 -u wbimbdb wbimbdb
${DBDIR}/instance/db2iauto -on wbimbdb
echo DB2_wbimbdb     62000/tcp >> /etc/services
echo DB2_wbimbdb_1   62001/tcp >> /etc/services
echo DB2_wbimbdb_2   62002/tcp >> /etc/services
echo DB2_wbimbdb_END 62003/tcp >> /etc/services

echo "Prompting for wbimbus password - obtain from the Password store"
passwd wbimbus
pwdadm -c wbimbus

echo "Creating database"
su - wbimbdb -c ". ~/.profile; db2start"
su - wbimbdb -c ". ~/.profile; db2 create database WBRKBKDB"
su - wbimbdb -c ". ~/.profile; db2 update dbm cfg using authentication server_encrypt; db2stop; db2start"
su - wbimbdb -c ". ~/.profile; db2 connect to wbrkbkdb; db2 bind ~/sqllib/bnd/@db2cli.lst grant public CLIPKG 5;  db2 update database configuration for WBRKBKDB using dbheap 900"
su - wbimbdb -c ". ~/.profile; /fs/system/tools/db2/perform_local_db2cops wbimbdb"

echo "Locate password for wbimbus and be prepared to enter it as well your own yellow zone password.  Press return to continue:"
echo
read

echo "Prompting for wbimbus password - obtain from the Password store"
passwd wbimbus
pwdadm -c wbimbus

echo "Gathering db2cops results"
/fs/system/tools/db2/gather_local_db2cops -p wbimbdb $SUDO_USER

