#!/bin/sh
#
#    
#   rsync_images.sh  -userid <userid> [-delete]
#      -delete deletes extraneous files from dest dirs 
# 
#   Objective: rsync specific image directories to the GPFS nodes
#     1.  /fs/system/images/lfs_tools/tip/etc
#
#   Runs on and uses v10146 as the gold copy     
#   Example:
#        rsync_images.sh  -userid user1
#   Change log:
#   2014-08-08 Initial
#
SCRIPT_VERSION=1.00
SCRIPT_DATE=2014-08-08

SCRIPTNAME=$(basename $0)
HOST=$(hostname -s)
USERID=""
DEBUG=""
DELETE_EXTRA=""      
# Test for root user
test_root_access() {
 if [ $(id -u) != 0 ]; then
    echo "ERROR: This script requires root access"
    exit 1
 fi
}

######################################################
# M A I N
######################################################

# Locate all arguments
i=0
while [ $i -le $# ]; do
  i=$(expr $i + 1)
  eval parm=\${$i:-}
  case "$parm" in
    -userid)
       i=$(expr $i + 1)
       eval USERID=\${$i:-}
       ;;
   -delete)
       DELETE_EXTRA="--delete"
       ;;     
    -debug|debug)
       DEBUG="y"
       ;;  
    *)
       ;;
  esac
done

echo
echo "Executing $SCRIPTNAME with userid $USERID, $DELETE_EXTRA, version $SCRIPT_VERSION"
echo 
sleep 1

#if [ $HOST != "v10146" ]; then 
#    echo "This script designed to run on v10146"
#    exit 1

#fi  
if [ "$USERID" == "" ]; then
  echo "userid(-userid) must be supplied"
  exit 1
fi
 
echo "Locating GPFS servers list from dirstore" 
gpfs_servers_dirstor=$(lssys -q -e role==GPFS.SERVER.SYNC | paste -d, -s -)
gpfs_servers_dirstor=$(echo $gpfs_servers_dirstor | tr ',' ' ')
for node in $gpfs_servers_dirstor; do
    x=$(echo $node | grep '^z')
    if   [ "$x" != "" -o  $node == $HOST ]; then
          echo "  bypassing $node"
          continue
    fi      
    if [ "$GPFS_servers" == "" ]; then GPFS_servers=$node;
         else GPFS_servers="$GPFS_servers $node"       
    fi         
done  
echo "  GPFS servers to use: $GPFS_servers" 
sleep 2

# 1 TIP etc  directory
DIR_LFS_TIP_ETC=/fs/system/images/lfs_tools/tip/etc
DIR_LFS_TIP=/fs/system/images/lfs_tools/tip
echo "*********************************************"
echo "*** 1. RSYNC $DIR_LFS_TIP_ETC   "
echo "*********************************************"
    for node in $GPFS_servers; do
      echo "Start--------------------------------------------------------"
        realm=$(lssys $node | grep  'realm' | grep -v 'authrealm')
        echo "rsync to node **$node**, $realm"
          dir=$DIR_LFS_TIP_ETC
        dirtd=$DIR_LFS_TIP
        echo " ...$dir"  
        echo "Executing sudo rsync -av $DELETE_EXTRA -e ssh $dir  $USERID@$node:$dirtd  "
        sudo rsync -av $DELETE_EXTRA -e ssh $dir  $USERID@$node:$dirtd 
        rc=$?     
        echo "end -------------------------------------------------------"
    done   


echo "$SCRIPTNAME completd rc=$rc"
exit $rc

 
 
    