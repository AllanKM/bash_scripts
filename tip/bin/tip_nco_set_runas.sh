#!/bin/sh
######################################################################################################################    
#
#   NCO Update RunAs to EI-standard userid netcool:itmusers   
#     
#   Wrap tip_set_runas.sh for use by NCO/ITNM; add logging
# 
#   Usage: 
#      cd    /lfs/system/tools/tip/bin
#      sudo ./tip_nco_set_runas.sh  
#
#   Requiremnts:
#     EI WAS tools in /lfs/system/tools/was
#     EI TIP tools in /lfs/system/tools/tip
#
#   TODO:  
#
#   Change History:
#     MEC  2015-04-13 Initial
#     MEC  2015-07-14 Fix  
######################################################################################################################                     

SCRIPT_VERSION=1.01
SCRIPTNAME=$(basename $0)
DATE=$(date +"%Y%m%d%H%M")
SCRIPTDIR=/lfs/system/tools/tip/bin
args=$*
echo "Executing $SCRIPTNAME($SCRIPT_VERSION)"

   wh=/opt/IBM/Netcool/tip               # washome
   user=netcool; group=itmusers
   date=$(date +"%y%m%d%H%M"); logs=/logs/was70; lname=nco_runas_$date.log; log=$logs/$lname
   $SCRIPTDIR/tip_set_runas.sh -wh $wh -user netcool -runas $user/$group  $args | tee $log

echo
echo "WAS TIP needs to be restarted: run  sudo rc.tip start"
echo  
echo "Executing $SCRIPTNAME($SCRIPT_VERSION)...complete"

exit 0