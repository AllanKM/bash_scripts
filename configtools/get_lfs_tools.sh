#!/bin/ksh
# IP for cvs.opensource.ibm.com is set in  /etc/hosts

# usage: get_lfs_tools

# Call this script before push_lfs_tools.sh to obtain the latest
# versions of the scripts from the IIOSB
# Run get_lfs_tools on v10062 ( Master Tivoli TMR Server )


HOST=`/bin/hostname -s`
SCRATCH=/fs/scratch

if [ "$HOST" != "v10062" ]; then
	echo "Run get_lfs_tools on v10062 only"
	echo "exiting...."
	exit 1
fi

env | grep CVSROOT | grep 'cvs.opensource.ibm.com' >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
	echo "export the following environment variables before running $0"
	echo "export CVS_RSH=ssh"
	echo "export CVSROOT=:ext:<IIOSB user id>@cvs.opensource.ibm.com:/cvsroot/hpodstools"
	echo "Name resolution for cvs.opensource.ibm.com is done by an entry in /etc/hosts"
    exit 1
fi

echo "Obtaining latest copy of Local Filesystem tools  from the IIOSB"
echo "Placing them in $SCRATCH/$USER to be tar'ed up and distributed"
echo "Enter your Intranet password last used to log into the  IIOSB website"
echo "Could be an old Intranet password if you have not logged into the IIOSB recently"


rm -fr $SCRATCH/$USER/lfs_tools 2>/dev/null
rm -fr $SCRATCH/$USER/configtool 2>/dev/null
rm -fr $SCRATCH/$USER/system 2>/dev/null

mkdir -p $SCRATCH/$USER
cd $SCRATCH/$USER && cvs export -D today lfs_tools

if [[ $? -ne 0 ]]; then
        echo "Failed to obtain copy of the lfs tools from the IIOSB, exiting.."
        exit 1
fi

echo "----------------------------------------------------------"
echo
echo
echo "Obtaining latest copy of configtool from the IIOSB"
echo "Enter your Intranet password again"
cd $SCRATCH/$USER && cvs export -D today configtool

if [[ $? -ne 0 ]]; then
	echo "Failed to obtain copy of configtool from the IIOSB, exiting.."
	exit 1
fi

echo
echo "----------------------------------------------------------"
echo
echo "Obtaining lastest copy of utilities not stored in IIOSB"
echo "but are stored in /fs/system/images/lfs_tools"
echo

RETURN_CODE=0

cp /fs/system/images/publishing/bNimble2/lib/Transmit.jar $SCRATCH/$USER/lfs_tools/bNimble/lib
RETURN_CODE=${RETURN_CODE}+$?

cp -R /fs/system/images/lfs_tools/* $SCRATCH/$USER/lfs_tools
RETURN_CODE=${RETURN_CODE}+$?

if [[ $RETURN_CODE -ne 0 ]]; then
	echo "Content copied from nfs did not complete, exiting.."
	exit 1
fi

cp -R $SCRATCH/$USER/configtool/* $SCRATCH/$USER/lfs_tools/configtools

if [[ $? -ne 0 ]]; then
	echo "Failed to populate configtools under $SCRATCH/$USER/lfs_tools"
	exit 1
fi

mkdir -p $SCRATCH/$USER/system/bin
mkdir -p $SCRATCH/$USER/system/tools
cp -r $SCRATCH/$USER/lfs_tools/* $SCRATCH/$USER/system/tools/
echo
echo "----------------------------------------------------------"
echo "Creating symlinks for common commands"
chmod 755 $SCRATCH/$USER/system
chmod 775 $SCRATCH/$USER/system/bin
chgrp eiadm $SCRATCH/$USER/system/bin

cd $SCRATCH/$USER/system/bin
ln -sf /lfs/system/tools/portal/bin/eiConfigEngine.sh
ln -sf /lfs/system/tools/configtools/bin/configtool_ds
ln -sf /lfs/system/tools/was/bin/rc.was
ln -sf /lfs/system/tools/was/bin/rc.wlp
ln -sf /lfs/system/tools/was/bin/hc.sh
ln -sf /lfs/system/tools/wxs/bin/rc.wxs
ln -sf /lfs/system/tools/bNimble/bin/rc.bNimble
ln -sf /lfs/system/tools/daedalus/bin/rc.daedalus
ln -sf /lfs/system/tools/bNimble/bin/check_bNimble.sh
ln -sf /lfs/system/tools/bNimble/bin/pubstatus.sh
ln -sf /lfs/system/tools/db2/bin/check_db2.sh
ln -sf /lfs/system/tools/ihs/bin/check_ihs.sh
ln -sf /lfs/system/tools/lcs/bin/check_lcs.sh
ln -sf /lfs/system/tools/spong/bin/check_spong.sh
ln -sf /lfs/system/tools/was/bin/check_was.sh
ln -sf /lfs/system/tools/was/bin/check_m2m.sh
ln -sf /lfs/system/tools/wxs/bin/check_grid.sh
ln -sf /lfs/system/tools/wxs/bin/check_catalog.sh
ln -sf /lfs/system/tools/mq/bin/check_mq.sh
ln -sf /lfs/system/tools/wbimb/bin/check_wbimb.sh
ln -sf /lfs/system/tools/mq/bin/saveqmgr.aix
ln -sf /lfs/system/tools/configtools/check.sh
ln -sf /lfs/system/tools/bNimble/bin/pubtool2
ln -sf /lfs/system/tools/ihs/bin/whatic
ln -sf /lfs/system/tools/ihs/bin/rc.ihs
ln -sf /lfs/system/tools/configtools/lockcvs.sh lockcvs
ln -sf /lfs/system/tools/configtools/checkcvs.sh checkcvs
ln -sf /lfs/system/tools/configtools/commitcvs.sh commitcvs
ln -sf /lfs/system/tools/mq/bin/rc.mq
ln -sf /lfs/system/tools/ldap/bin/rc.ldap
ln -sf /lfs/system/tools/wbimb/bin/rc.wbimb

echo
echo "----------------------------------------------------------"
echo
echo "Using sudo now to prepare files for distribution"
echo "Enter your greenzone password if sudo prompts for it"
sudo touch /Tivoli/sd/lfs_tools/lfs_tools_nodes
sudo chown root:eiadm /Tivoli/sd/lfs_tools/lfs_tools_nodes
sudo chmod 770 /Tivoli/sd/lfs_tools/lfs_tools_nodes

sudo mkdir /Tivoli/sd/lfs_tools/distribute 
sudo cp -rh  $SCRATCH/$USER/system/* /Tivoli/sd/lfs_tools/distribute
if [ -d /Tivoli/sd/lfs_tools/distribute/tools/lfs_tools ]; then
	print "Error creating distribute dir /Tivoli/sd/lfs_tools/distribute/tools/lfs_tools exists"
	exit 4
fi
sudo chown -R root:eiadm /Tivoli/sd/lfs_tools
sudo chmod -R 775 /Tivoli/sd/lfs_tools
sudo find /Tivoli/sd/lfs_tools/distribute/tools/*/etc -type f  | xargs -I {} sudo chmod 440 {} 
sudo find /Tivoli/sd/lfs_tools/distribute/tools/*/etc -type d | xargs -I {} sudo chmod 770 {} 
sudo chmod 664 /Tivoli/sd/lfs_tools/distribute/tools/bNimble/lib/*

cd /Tivoli/sd/lfs_tools/distribute && sudo tar -cf /Tivoli/sd/lfs_tools/lfs_tools.tar ./*

if [[ $? -ne 0 ]]; then
        echo "Failed to create tar of lfs_tools to distribute"
        exit 1
fi
cd /Tivoli/sd/lfs_tools

# cleanup fs scratch 
rm -fr $SCRATCH/$USER/lfs_tools 2>/dev/null
rm -fr $SCRATCH/$USER/configtool 2>/dev/null
rm -fr $SCRATCH/$USER/system 2>/dev/null

if [ -f /Tivoli/sd/lfs_tools/distribute/tools/configtools/tpost ]; then
	echo "Updating /Tivoli/sd/lfs_tools/push_lfs_tools.sh, tpost, and get_lfs_tools.sh from the IIOSB's gold copy"
	sudo cp /Tivoli/sd/lfs_tools/distribute/tools/configtools/tpost /Tivoli/sd/lfs_tools/tpost
	sudo cp /Tivoli/sd/lfs_tools/distribute/tools/configtools/push_lfs_tools.sh /Tivoli/sd/lfs_tools/push_lfs_tools.sh
	sudo cp /Tivoli/sd/lfs_tools/distribute/tools/configtools/get_lfs_tools.sh /Tivoli/sd/lfs_tools/get_lfs_tools.sh 
	sudo chown root:eiadm /Tivoli/sd/lfs_tools/*
	sudo chmod 770 /Tivoli/sd/lfs_tools/*
	sudo rm -fr /Tivoli/sd/lfs_tools/distribute
fi
