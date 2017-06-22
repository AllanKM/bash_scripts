#!/bin/sh
#
#   Configures the TIP NCO SSL cert stores    
#     anc adds entries to ssl.client.props.
#
#   Usage: tip_nco_ssl_config.sh  -cf <jks_file_name> -pw <cert_pw>    
#              [-tippw <tip_password>]   # Supply tipadmin's password when it is not "tipadmin"
#              [-no_useClientProps]      # do not pass useClientProps
#  
#           Specify "-pw pw.ini" or do not supply "-pw" to use password from $TIP_TOOLS/etc/passwds.ini
#
#   Typical use: 
# 
#   Example:
#     date=$(date +"%y%m%d%H%M")
#     logs=/logs/was70; lname=nco_ssl_config_$date.log
#     cd    /lfs/system/tools/tip/setup
#     sudo ./tip_nco_ssl_config.sh -cf netcool.omnibusdev.webgui.jks -pw  yCrhwt5D | tee $logs/$lname
#
#   Requiremnts:
#     EI WAS tools in /lfs/system/tools/was
#     EI TIP tools in /lfs/system/tools/tip
#
#   TODO:  
#
#   Change History:
#     MEC  07-23-2014  Initial
######################################################################################################################                     

SCRIPT_VERSION=1.00a
SCRIPTNAME=$(basename $0)
DATE=$(date +"%Y%m%d%H%M")
CONTINUE_PROMPTS=y
SCRIPTDIR=/lfs/system/tools/tip/setup
args=$*

US=netcool; GR=itmusers; WH=/opt/IBM/Netcool/tip; PR=/opt/IBM/Netcool
CERT_FILE=""
CERT_PW="pw.ini"   
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
         -cf)
           shift
           CERT_FILE=$1
           ;;  
         -pw)
           shift
           CERT_PW=$1
           ;;  
        -no_useClientProps|-nucp)
           USE_CLIENT_PROPS="" 
          ;;   
         *)
           ;;
      esac
      shift  
    done 
    
    if [ "$CERT_FILE" == "" ]; then
        echo "ERROR: key/trust store jks file name required"
        echo "   .....tip_nco_ssl_config.sh  -cf <jks_file_name> -pw <cert_pw> "  
        exit 1    	
    fi
    if [ "$CERT_PW" == "" ]; then
        echo "ERROR: key store cert password required"
        echo "   .....tip_nco_ssl_config.sh  -cf <jks_file_name> -pw <cert_pw> "  
        exit 1    	
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

scan_arguments $*

DKTS_override="-DKTS $CERT_FILE $CERT_PW"

CMD="$SCRIPTDIR/tip_was_security_setup_v3.sh ED 70  TIPProfile -projroot $PR -washome $WH"
CMD="$CMD $USE_CLIENT_PROPS"
# Bypass: permissions,status test, security config, and userid/pw soap.clients.props update" 
CMD="$CMD -user $US -group $GR $DKTS_override -tipid NCO -bp -bsst -bsec -bupw -debug $args"
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
STATUS_CMD="/opt/IBM/Netcool/tip/profiles/TIPProfile/bin/serverStatus.sh server1"
su - netcool -c "$STATUS_CMD"
echo "Running status command...complete"

exit 0