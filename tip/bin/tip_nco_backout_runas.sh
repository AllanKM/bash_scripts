#!/bin/sh
######################################################################################################################    
#
#   NCO Backout RunAs to allow TIP to run under root userid   
#   Use for maintenance work.
#  
#   Wrap tip_set_runas.sh; add logging
# 
#   Usage: 
#      cd    /lfs/system/tools/tip/bin
#      sudo ./tip_nco_backout_runas.sh  
#
#   Process...
#   1. Stop WAS
#      sudo rc.tip stop
#   2. Update owner/perms
#      cd /opt/IBM/Netcool
#      sudo chown -R root:itmusers * 
#   3. Run this script
#   4. Start WAS under root
#      sudo  /opt/IBM/Netcool/tip/profiles/TIPProfile/bin/startServer.sh server1
#
#   Requiremnts:
#     EI WAS tools in /lfs/system/tools/was
#     EI TIP tools in /lfs/system/tools/tip
#
#  Reference
#    1.  To change ownership of /opt/IBM/Netcool/ to root:
#          cd /opt/IBM/Netcool
#          sudo chown -R root:itmusers * 
#
#   Change History:
#     MEC  2015-07-14 Initial  
######################################################################################################################                     

SCRIPT_VERSION=1.00b
SCRIPTNAME=$(basename $0)
DATE=$(date +"%Y%m%d%H%M")
SCRIPTDIR=/lfs/system/tools/tip/bin
args=$*
echo "Executing $SCRIPTNAME($SCRIPT_VERSION)"

   wh=/opt/IBM/Netcool/tip
   user=""; group=""
   date=$(date +"%y%m%d%H%M"); logs=/logs/was70; lname=nco_runas_$date.log
   cd  /lfs/system/tools/tip/bin
   cmd="$SCRIPTDIR/tip_set_runas.sh -wh $wh -user root -runas $user/$group $args "
   echo "About to execute"
   echo "   $cmd"
   # $SCRIPTDIR/tip_set_runas.sh -wh $wh -user root -runas $user/$group $args | tee $logs/$lname
   $cmd | tee $logs/$lname
 

echo
echo "WAS TIP needs to be restarted:  run "
echo "    sudo  /opt/IBM/Netcool/tip/profiles/TIPProfile/bin/startServer.sh server1"
echo  
echo "Executing $SCRIPTNAME($SCRIPT_VERSION)...complete"

exit 0