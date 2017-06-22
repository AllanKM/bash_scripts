#!/bin/ksh

# USAGE: build_broker_domain.sh [manager|broker]


# Will this be a MANAGER or BROKER install?
TYPE=${1:-BROKER}
VERSION=${2:-91}
DBHOST=$3

if [ "$DBHOST" = "" ]; then
    echo $required argument DBHOST missing
    exit 99
fi


typeset -u TYPE

# MQ is the first thing to install
su mqm -c "/usr/bin/dspmqver 2>/dev/null" | grep "6.0" > /dev/null
if [ $? -eq 0 ]; then
    echo "MQ Server previously installed."
else
    echo "Installing MQ Server..."
    /lfs/system/tools/mq/setup/install_mq.sh server 6.0.2.3
    su mqm -c "/usr/bin/dspmqver 2>/dev/null" | grep "6.0"
    if [ $? -ne 0 ]; then
        echo "Failed to install MQ server"
        echo "exiting..."
        exit 1
    fi
fi

# Install DB2
if [[ "$TYPE" == "BROKER" ]]; then
    if [ -f /usr/opt/db2_08_01/instance/db2icrt -o -f /opt/IBM/db2/V9.1/instance/db2icrt ]; then
        echo "DB2 Client previously installed"
    else
        echo "Installing DB2 client..."
        /fs/system/tools/db2/instdb2 -$VERSION
        if [ ! -f /usr/opt/db2_08_01/instance/db2icrt -a ! -f /opt/IBM/db2/V9.1/instance/db2icrt ]; then
            echo "Failed to install DB2 client"
            echo "exiting..."
            exit 1
        fi
    fi
elif [[ "$TYPE" == "MANAGER" ]]; then
    if [ -f /usr/opt/db2_08_01/instance/db2icrt -o -f /opt/IBM/db2/V9.1/instance/db2icrt ]; then
        echo "DB2 server previously installed"
    else
        echo "Installing DB2 server..."
        /fs/system/tools/db2/instdb2 -server -$VERSION
        if [ ! -f /usr/opt/db2_08_01/instance/db2icrt -a ! -f /opt/IBM/db2/V9.1/instance/db2icrt ]; then
            echo "Failed to install DB2 server"
            echo "exiting..."
            exit 1
        fi
    fi
else
    echo "Don't know how to build broker of type $TYPE"
    echo "exiting...."
    exit 1
fi

# Install WBIMB
if [ -f /opt/IBM/mqsi/*/bin/mqsiprofile ]; then
     echo "WBIMB already installed"
else
    /lfs/system/tools/wbimb/setup/install_wbimb.sh
        if [ ! -f /opt/IBM/mqsi/*/bin/mqsiprofile ]; then
        echo "Failed to configure WBIMB"
        echo "exiting...."
        exit 1
    fi
fi

# Install fixes for WBIMB
CFLEVEL=7
grep MQSI_VERSION /opt/IBM/mqsi/*/bin/mqsiprofile |grep 6.0.0.${CFLEVEL} > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "WBIMB fixpack $CFLEVEL already installed"
else
    /lfs/system/tools/wbimb/setup/install_wbimb_fp.sh $CFLEVEL
    grep MQSI_VERSION /opt/IBM/mqsi/*/bin/mqsiprofile |grep 6.0.0.${CFLEVEL} > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Failed to install fixpack $CFLEVEL for WBIMB"
        echo "exiting...."
        exit 1
    fi
fi

#Filesystem creation
if lsvg appvg >/dev/null 2>&1; then
        VG=appvg
else
        VG=rootvg
fi
/lfs/system/tools/configtools/make_filesystem /projects 500 $VG
mkdir -p /projects/wbimb/custom/lil
chown -R mqm:eiadm /projects/wbimb
chmod -R o-rwx /projects/wbimb
mkdir -p /logs/xin
chown -R mqm:mqm /logs/xin

# Configuration work
if [[ "$TYPE" == "BROKER" ]]; then
    #Broker configuration work
        su - mqm -c ". ~/.profile; db2 list node directory" | grep DB2_wbimbdb > /dev/null
    if [ $? -ne 0 ]; then
                /lfs/system/tools/wbimb/setup/db2_client_for_wbimb.sh $VERSION $DBHOST
    fi
        su - mqm -c ". ~/.profile; dspmq " | grep 'QMNAME(QM' > /dev/null
#       ls /var/mqsi/registry/ | grep BR > /dev/null
    if [ $? -ne 0 ]; then
        chuser nofiles=25000 mqm
                su - mqm -c ". ~/.profile; /lfs/system/tools/wbimb/setup/mqchannels.sh broker"
    fi
    grep "BROKER=BR" ~mqm/.profile > /dev/null
    if [ $? -ne 0 ]; then
       /fs/system/images/xin/InstallXIN.sh
    else
       echo "InstallXIN.sh script already configured"
    fi
elif [[ "$TYPE" == "MANAGER" ]]; then
    su - wbimbdb -c ". ~/.profile; db2 connect to WBRKBKDB" | grep "Database server" > /dev/null
    if [ $? -ne 0 ]; then
                /lfs/system/tools/wbimb/setup/db2_server_for_wbimb.sh
    fi
    su - mqm -c ". ~/.profile; dspmq " | grep 'QMNAME(QM' > /dev/null
    if [ $? -ne 0 ]; then
                su - mqm -c ". ~/.profile; /lfs/system/tools/wbimb/setup/mqchannels.sh manager"
    fi
fi

# Put logrotate file in place
cp /fs/system/images/xin/scripts/xin /etc/logrotate.d/xin


echo "This is the end of the script.   Hit ^C if you don't get the command prompt back"

#! Need to generate ssh keys used for ITM modules that collects stats
