#!/bin/ksh

#---------------------------------------------------------------
# MBIMB install.
#---------------------------------------------------------------

# USAGE: install_wbimb_fp.sh [fix pack number]

#Use the first arg as the fix pack level or default to cf3
CFLEVEL=${1:-3}


#---------------------------------------------------------------
# Check if WIBMB Fixpack is already installed
#---------------------------------------------------------------
grep MQSI_VERSION /opt/IBM/mqsi/6.0/bin/mqsiprofile |grep 6.0.0.${CFLEVEL}
if [ $? -ne 1 ]; then
    echo "WBIMB Fixpack $CFLEVEL is allready Installed"
    echo "exiting..."
    exit 1
fi

#---------------------------------------------------------------
# Stop MQSI brokers
#---------------------------------------------------------------
THISNODE=`hostname`
#convert to uppercase
typeset -u THISNODE
BROKER=BR${THISNODE}


if /lfs/system/tools/configtools/countprocs.sh 1 $BROKER ; then
        echo "Stopping MQSI processes"
        su - mqm -c ". ~/.profile; /opt/IBM/mqsi/6.0/bin/mqsistop $BROKER"
fi


#---------------------------------------------------------------
# Fixpack Install
#---------------------------------------------------------------
echo "Performing MBIMB Fixpack $CFLEVEL installation"
/fs/system/images/websphere/wbimb/6.0/fixes/cf${CFLEVEL}/disk1/setupaix -silent
grep MQSI_VERSION /opt/IBM/mqsi/*/bin/mqsiprofile |grep 6.0.0.${CFLEVEL} > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Failed to install WBIMB Fixpack $CFLEVEL..."
    echo "exiting..."
    exit 1
fi

#---------------------------------------------------------------
# Efix Install
#---------------------------------------------------------------
if [ -d /fs/system/images/websphere/wbimb/6.0/fixes/cf${CFLEVEL}_efix ]; then
        echo "Performing MBIMB cf${CFLEVEL}_efix installation"
        cd /opt/IBM/mqsi/6.0
        cp lib/libimbjplg.a lib/libimbjplg.a.orig
        cp lib/libimbjplg64.a lib/libimbjplg64.a.orig
        cp classes/javacompute.jar classes/javacompute.jar.orig
        /usr/sbin/slibclean
        cp /fs/system/images/websphere/wbimb/6.0/fixes/cf${CFLEVEL}_efix/lib/libimbjplg.a lib/libimbjplg.a
        cp /fs/system/images/websphere/wbimb/6.0/fixes/cf${CFLEVEL}_efix/lib/libimbjplg64.a lib/libimbjplg64.a
        cp /fs/system/images/websphere/wbimb/6.0/fixes/cf${CFLEVEL}_efix/classes/javacompute.jar classes/javacompute.jar
fi
