#!/bin/sh

#
# TIP permissions updater 
# Usage:   tip_perms.sh [-xwas]   
# 
# 1. Should we be creating the WAS TIPProfile logs symlink here? 
# 
# This script:
#  1. Creates WAS logs directory and symlink if needed
#  2. Creates $TIPPROFILE/logs symlink to /logs/was70/TIPProfile 
#  3  Updates WAS permissions and ownership by calling /lfs/system/tools/was/setup/was_perms.ksh
#

SCRIPTNAME=$(basename $0)
WASHOME=/usr/WebSphere70/AppServer
TIPPROFILE=$WASHOME/profiles/TIPProfile
WASLOGS=/logs/was70/TIPProfile 
DATE=$(date +"%Y%m%d%H%M")
BYPASS_WAS="n" 
 
echo "$SCRIPTNAME executing"
#if [ $(id -u) != 0 ]; then
#    echo "This script requires root access"
#    exit 1
#fi

#   Determine destination/target node  
if [ $# -gt 0 ]; then
    bypassparm=$1  
    if [ $bypassparm == "-exclude_was" -o  $bypassparm == "-xwas" ]; then
        BYPASS_WAS="y"   
    fi   
fi    

# 1. Create WAS logs directory and symlink if needed
if [ ! -d $WASLOGS ]; then
    echo "Creating and setting ownership and permissions for directory $WASLOGS" 
    mkdir -m 770 /logs/was70/TIPProfile 
    chown webinst:eiadm /logs/was70/TIPProfile
fi  

# TODO - improve this. Be able to recognize a directory symlink.  
if [ -L $TIPPROFILE/logs ]; then
    echo "TIPProfile is already a symlink"  
else  
    echo "renaming WAS TIPProfile/logs directory to logs.$DATE"  
    mv $TIPPROFILE/logs $TIPPROFILE/logs.$DATE 
    echo "Creating symlink for $TIPPROFILE/logs" 
    ln -s  $WASLOGS  $TIPPROFILE/logs 
fi   

# 2. Update WAS permissions 
#    The WAS script will set perms to 770 and ownership to webinst:eiadm 
if [ $BYPASS_WAS == "n" ]; then
    echo "Updating WAS permissions and ownership"
    echo "   Executing /lfs/system/tools/was/setup/was_perms.ksh"
    /lfs/system/tools/was/setup/was_perms.ksh
fi


 


echo "$SCRIPTNAME completed" 

exit 0
