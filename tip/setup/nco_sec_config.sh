#!/bin/sh
#
#   Configures the TIP NCO security config - runs the security config step of security setup 
#
#   Usage: nco_sec_config.sh  [-tippw <tip_pw>] [-useClientProps]   
#            These are args to tip_was_security_setup  applicable here
#              [-tippw <tip_password>]   # Supply tipadmin's password when it is not "tipadmin"
#              [-useClientProps]         # No userid/pw needed to wsadmnin when it is supplied in soap.client.props
#
# 
#   Example:
#     date=$(date +"%y%m%d%H%M")
#     logs=/logs/was70; lname=nco_sec_config_$date.log
#     cd    /lfs/system/tools/tip/setup
#     sudo ./nco_sec_config.sh | tee $logs/$lname
#
#   Requiremnts:
#     EI WAS tools in /lfs/system/tools/was
#     EI TIP tools in /lfs/system/tools/tip
#
#   TODO:  
#
#   Change History:
#     MEC  08-01-2014  Initial
######################################################################################################################                     

SCRIPT_VERSION=1.00
SCRIPTNAME=$(basename $0)
DATE=$(date +"%Y%m%d%H%M")
CONTINUE_PROMPTS=y
SCRIPTDIR=/lfs/system/tools/tip/setup
args=$*


##
# Check for root access
##
check_root_user() {
    if [ $(id -u) != "0" ]; then
        echo "ERROR: This script requires root access";  exit 1
    fi
}
##
# Scan input arguments - placeholders for future
## 
scan_arguments() {
    while [ "$1" != "" ]; do
      case $1 in
         -arg1)
           shift
           arg1=$1
           ;;  
         -arg2)
           arg2=y 
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

# Bypass steps: perms, ssl config, status test, update password 
# Append other arguments supplied
CMD="$SCRIPTDIR/nco_was_security_setup.sh -bp -bssl -bsst  -bupw -debug $args"

echo "About to execute: "
echo "$CMD"
prompt_to_continue
echo "...executing"
$CMD
rc=$?

echo
echo "Now back to $SCRIPTNAME"
echo "...complete rc=$rc"

exit $rc