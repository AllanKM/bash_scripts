#!/bin/ksh
VERSION=${1:-91}
DBHOST=$2

if [ "$DBHOST" = "" ]; then
    echo $required argument DBHOST missing
    exit 99
fi

if [ ! -f /usr/opt/db2_08_01/instance/db2icrt -a ! -f /opt/IBM/db2/V9.1/instance/db2icrt ]; then
    echo "Installing DB2 client code"
    /fs/system/tools/db2/instdb2 -$VERSION
fi

if [ ! -d ~mqm/sqllib ]; then
    if [ $VERSION = '91' ]; then
        /opt/IBM/db2/V9.1/instance/db2icrt -s client mqm
    else
        /usr/opt/db2_08_01/instance/db2icrt -s client mqm
    fi
    if [ $? -ne 0 ]; then
        echo "Failed to create client instance mqm"
        echo "exiting..."
        exit 1
    fi
fi

grep DB2_wbimbdb /etc/services
if [ $? -ne 0 ]; then
    echo DB2_wbimbdb     62000/tcp >> /etc/services
    echo DB2_wbimbdb_1   62001/tcp >> /etc/services
    echo DB2_wbimbdb_2   62002/tcp >> /etc/services
    echo DB2_wbimbdb_END 62003/tcp >> /etc/services
fi

mkdir /logs/db2
chown -R mqm:mqm /logs/db2

print "Using dirstore to figure out Database Server in this plex"
REALM=`/fs/system/tools/auth/bin/getrealm`
#DB2SERVER=`lssys -q -e "realm==${REALM}" "role==WBIMB.EVENTS.MANAGER"`
DB2SERVER=$DBHOST

if [ "$DB2SERVER" == "" ]; then
    echo "Failed to obtain WBIMB.EVENTS.MANAGER node in $REALM"
    echo "exiting..."
    exit 1
fi

print "Cataloging WBRKBRKDB on $DB2SERVER"
su - mqm -c ". ~/.profile; db2 catalog tcpip node domain remote $DB2SERVER server DB2_wbimbdb"
su - mqm -c ". ~/.profile; db2 catalog database WBRKBKDB at node domain authentication SERVER_ENCRYPT"

su - mqm -c ". ~/.profile; db2 list node directory" | grep DB2_wbimbdb > /dev/null
if [ $? -ne 0 ]; then
    echo "Failed to catalog database WBRKBRDB at $DB2SERVER"
    echo "exiting...."
fi

echo "Creating /var/mqm/odbc.ini"
echo export ODBCINI=/var/mqm/odbc.ini >> ~mqm/.profile

echo    "[ODBC Data Sources]" >> /var/mqm/odbc.ini
echo    "WBRKBKDB=IBM DB2 ODBC Driver" >> /var/mqm/odbc.ini

echo    "[WBRKBKDB]" >> /var/mqm/odbc.ini
echo    "Driver=/var/mqm/sqllib/lib/libdb2.a" >> /var/mqm/odbc.ini
echo    "Description=WBRKBKDB DB2 ODBC Database" >> /var/mqm/odbc.ini
echo    "Database=WBRKBKDB" >> /var/mqm/odbc.ini

echo    "[ODBC]" >> /var/mqm/odbc.ini
echo    "Trace=0" >> /var/mqm/odbc.ini
echo    "TraceFile=/logs/db2/odbctrace.out" >> /var/mqm/odbc.ini
echo    "TraceDll=/usr/opt/db2_08_01/merant/lib/odbctrac.so" >> /var/mqm/odbc.ini
echo    "InstallDir=/usr/opt/db2_08_01/merant" >> /var/mqm/odbc.ini
echo    "UseCursorLib=0" >> /var/mqm/odbc.ini
echo    "IANAAppCodePage=4" >> /var/mqm/odbc.ini

chown mqm:mqm /var/mqm/odbc.ini
