#!/bin/sh
#
#   Cacks up security.xml      
#
#   Usage: nco_bkup_security_xml.sh  
#   
#   Change History:
#   MEC    07-25-2014  Initial
                     
SCRIPT_VERSION=1.00a
SCRIPTNAME=$(basename $0)
DATE=$(date +"%Y%m%d%H%M")
CONTINUE_PROMPTS=y
US=netcool

##
# Check for root access
##
check_root_user() {
    if [ $(id -u) != "0" ]; then
        echo "ERROR: This script requires root access";  exit 1
    fi
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

CMD="$CMD -user $US -group $GR $DKTS_override -tipid NCO -bp -bsst -bsec -debug $args"
echo "About to execute: "
echo "$CMD"
prompt_to_continue

$CMD



exit 0