#!/bin/sh
#
# nco_backup - wraps tip_backup.sh with specific args for standard NCO 
# Usage:  nco_backup.sh {all] [tip} [sync] [fs] [-descr <description>] 
#             tip          back up the TIPProfile 
#             all          back up all but sync   
#             fs|sync      full sync to fixed backup dir for the node 
#             desc|descr   description of the backup  - not applicable with sync  
#                       
#         All args are passed thru to tip_backup.sh 
#   
#    Examples:
#     cd /lfs/system/tools/tip/bin
#     sudo ./nco_backup.sh tip   # backs up TIPProfile
#     sudo ./nco_backup.sh sync  # rsync's/opt/IBM/Netcool     
#
# Changes:
# 2014-07-28 MEC Initial
#
SCRIPT_VERSION=1.00
SCRIPTNAME=$(basename $0)
SCRIPTDIR=/lfs/system/tools/tip/bin

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

CMD="$SCRIPTDIR/tip_backup.sh -ph $PROJ_HOME -wh $WASHOME $args"

echo "About to execute: "
echo "  $CMD"
prompt_to_continue

$CMD
rc=$?

echo "$SCRIPTNAME completed rc=$rc" 

exit $rc
