#!/bin/sh
#
#   Configures the TIP TCR SSL cert stores    
#     and updates entries to ssl.client.props.
#
#   Usage: tip_tcr_ssl_config.sh  
#              [-tippw <tip_password>]   # Supply tipadmin's password when it is not "tipadmin"
#              [-no_useClientProps]      # do not pass useClientProps
#  
#   Assumes WAS alreasy is running under user webinst. 
# 
#   Example:
#     date=$(date +"%y%m%d%H%M")
#     logs=/logs/was85; lname=tcr_ssl_config_$date.log
#     cd    /lfs/system/tools/tip/setup
#     sudo ./tip_tcr_ssl_config.sh | tee $logs/$lname
#
#   Requiremnts:
#     EI WAS tools in /lfs/system/tools/was
#     EI TIP tools in /lfs/system/tools/tip
#
#   TODO:  
#
#   Change History:
#     MEC  07-24-2014  Initial
######################################################################################################################                     

SCRIPT_VERSION=1.00
SCRIPTNAME=$(basename $0)
DATE=$(date +"%Y%m%d%H%M")
CONTINUE_PROMPTS=y
SCRIPTDIR=/lfs/system/tools/tip/setup
args=$*

# US=netcool; GR=itmusers; WH=/opt/IBM/Netcool/tip; PR=/opt/IBM/Netcool
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
## 
scan_arguments() {
    while [ "$1" != "" ]; do
      case $1 in
        -no_useClientProps|-nucp)
           USE_CLIENT_PROPS="" 
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

CMD="$SCRIPTDIR/tip_was_security_setup_v3.sh ED 85 JazzSMProfile"
CMD="$CMD $USE_CLIENT_PROPS"
# Bypass: permissions, status test-server start, security config, and update soap.clients.props" 
CMD="$CMD -bp     -bsst -bsec -bupw -debug $args"
echo "About to execute: "
echo "$CMD"
prompt_to_continue

$CMD

prompt_to_continue

#Run server status command to test health of certificate and respond to trust prompt  
echo
echo "Now back to $SCRIPTNAME"
echo "Running status command test health of certificate and respond to trust prompt"
echo 
STATUS_CMD="/usr/WebSphere85/AppServer/profiles/JazzSMProfile/bin/serverStatus.sh server1"
su - webinst -c "$STATUS_CMD"
echo "Running status command...complete"

exit 0