#!/bin/sh
#
# nco_permsp - wraps tip_perms.sh with specific args for standard NCO 
# Usage:  nco_perms.sh  

#                       
#         All args are passed thru to tip_perms.sh 
#   
#    Examples:
#
#     date=$(date +"%y%m%d%H%M")
#     logs=/logs/was70; lname=nco_perms_$date.log
#     cd /lfs/system/tools/tip/bin
#     sudo ./nco_perms.sh  | tee $logs/$lname
#
# Changes:
# 2014-07-28 MEC Initial
#  
SCRIPT_VERSION=1.00
SCRIPTNAME=$(basename $0)
SCRIPTDIR=/lfs/system/tools/tip/setup

PROJ_HOME=/opt/IBM/Netcool
WASHOME=$PROJ_HOME/tip
TIPPROFILE=$WASHOME/profiles/TIPProfile
NODE=$(hostname -s)
DATE=$(date +"%Y%m%d%H%M")
args=$*
CONTINUE_PROMPTS=y

##
# Check for root access
##
check_root_user() {
    if [ $(id -u) != "0" ]; then
        echo "ERROR: This script requires root access";  exit 1
    fi
}
##
# Scan input arguments 
## 
scan_arguments() {
    while [ "$1" != "" ]; do
      case $1 in
        -ph|-projHome)
           shift
           PROJ_HOME=$1
           WASHOME=$PROJ_HOME/tip
           TIPPROFILE=$WASHOME/profiles/TIPProfile
           ;;  
        *)
           ;;
      esac
      shift  
    done 
    
 }
# Pause 
pause() {
    echo "\nPausing 5 seconds"
    sleep 5
    echo    
}
# Issue prompt to contunue or briefly pause
prompt_to_continue() {
    echo 
    if [ $CONTINUE_PROMPTS == y ]; then
        echo "\nHit any key to continue, or cancel(CNTL-c) to quit"  
        read -r choice 
    else
        pause    
    fi
}

######################################
#  M A I N
######################################
echo "$SCRIPTNAME version $SCRIPT_VERSION executing" 
check_root_user
scan_arguments $*

CMD="$SCRIPTDIR/tip_perms.sh -ph $PROJ_HOME -wh $WASHOME -tipid NCO $args"

echo "About to execute: "
echo "  $CMD"
prompt_to_continue

$CMD
rc=$?

echo "$SCRIPTNAME completed rc=$rc" 

exit $rc
