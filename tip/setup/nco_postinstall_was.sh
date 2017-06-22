#!/bin/sh
#
#   Configures the TIP NCO EI post-install     
#   Wraps tip_postinstall_was_v3.sh with NCO specific agguments.
#
#   Usage: nco_postinstall_was.sh [-wh $WASHOME]
#            -wh $WASHOME    override the default WAS_HOME /opt/IBM/Netcool/tip            
#          All arguments can be passed to nco_was_security_setup_v3.sh 
#          
#   Typical use: 
# 
#   Example:
#     date=$(date +"%y%m%d%H%M")
#     logs=/logs/was70; lname=nco_postinstall_was_$date.log; log=$logs/$lname
#     cd    /lfs/system/tools/tip/setup
#     sudo ./nco_postinstall_was.sh | tee $log
#
#   Requiremnts:
#     EI WAS tools in /lfs/system/tools/was
#     EI TIP tools in /lfs/system/tools/tip
#
#   TODO:  
#
#   Change History:
#     MEC  07-29-2014  Initial
######################################################################################################################                     

SCRIPT_VERSION=1.00
SCRIPTNAME=$(basename $0)
DATE=$(date +"%Y%m%d%H%M")
CONTINUE_PROMPTS=y
SCRIPTDIR=/lfs/system/tools/tip/setup
args=$*

# Define arguments specifiC to standard NCO
WH=/opt/IBM/Netcool/tip  # WAS_HOME
  
USE_CLIENT_PROPS="-useClientProps" 
# -no_useClientProps


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
# Contains a placeholder for future use 
## 
scan_arguments() {
    while [ "$1" != "" ]; do
      case $1 in
         -wh)
           shift
           WH=$1
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
check_root_user

scan_arguments $*


# CMD="$CMD $USE_CLIENT_PROPS"  # ??????

CMD="$SCRIPTDIR/tip_postinstall_was_v3.sh 70  -wh $WH -heap 512 1024  -debug"
CMD="$CMD $args"

echo "About to execute: "
echo "$CMD"
prompt_to_continue
echo "...executing $CMD"
$CMD
rc=$?

echo "$SCRIPTNAME...complete  rc=$rc"

exit $rc