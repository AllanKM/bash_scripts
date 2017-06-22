#!/bin/ksh

#---------------------------------------------------------------
# MBIMB install.
#---------------------------------------------------------------

# USAGE: install_wbimb.sh


#---------------------------------------------------------------
# Check if MQ is already installed
#---------------------------------------------------------------
su - mqm -c "/usr/bin/dspmqver" | grep "6.0"
if [ $? -ne 0 ]; then
    echo "Install MQ Server before WBIMB"
    echo "exiting..."
    exit 1
fi

#---------------------------------------------------------------
# Check if DB2 client is installed
#---------------------------------------------------------------
if [ ! -f /usr/opt/db2_08_01/instance/db2icrt -a ! -f /opt/IBM/db2/V9.1/instance/db2icrt ]; then
    echo "Install DB2 before WBIMB"
    echo "exiting ..."
    exit 1
fi



#---------------------------------------------------------------
# Filesystems
#---------------------------------------------------------------
/lfs/system/tools/configtools/make_filesystem /var/mqsi 2048 appvg

chown -R mqm:mqbrkrs /var/mqsi


#---------------------------------------------------------------
# Main Install
#---------------------------------------------------------------


echo "Performing WBIMB installation and configuration"
/fs/system/images/websphere/wbimb/6.0/aix/messagebroker_runtime1/setupaix -silent
if [ ! -d /opt/IBM/mqsi/6.0/bin ]; then
    echo "setupaix script failed"
    echo "exiting..."
    exit 1
fi
echo "Adding execution of mqsiprofile to ~mqm/.profile"
cd /opt/IBM/mqsi/6.0/bin
cp mqsistart mqsistart.orig
sed -e "s/bucket_size_factor:8/bucket_size_factor:16/" mqsistart > /tmp/mqsistart && mv /tmp/mqsistart  mqsistart
echo . /opt/IBM/mqsi/6.0/bin/mqsiprofile >> ~mqm/.profile
