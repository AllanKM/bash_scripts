#!/bin/sh
#
#   Configures the TIP NCO EI security    
#
#   Usage: nco_was_security_setup.sh 
#            
#          All arguments can be passed to nco_was_security_setup_v3.sh 
#           Specify "-pw pw.ini" or do not supply "-pw" to use password from $TIP_TOOLS/etc/passwds.ini
#
#           DKTS_override="-DKTS netcool.omnibusdev.webgui.jks  pw.ini"
#   Typical use: 
# 
#   Example:
#     date=$(date +"%y%m%d%H%M")
#     logs=/logs/was70; lname=nco_was_sec_$date.log
#     cd    /lfs/system/tools/tip/setup
#     ?? sudo ./tip_nco_ssl_config.sh -cf netcool.omnibusdev.webgui.jks -pw  yCrhwt5D | tee $logs/$lname
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

SCRIPT_VERSION=1.00
SCRIPTNAME=$(basename $0)
DATE=$(date +"%Y%m%d%H%M")
CONTINUE_PROMPTS=y
SCRIPTDIR=/lfs/system/tools/tip/setup
args=$*

# Define arguments specifiC to standard NCO
US=netcool; GR=itmusers; WH=/opt/IBM/Netcool/tip; PR=/opt/IBM/Netcool
CERT_FILE=""
CERT_PW="pw.ini"   
USE_CLIENT_PROPS="-useClientProps" 
# -no_useClientProps
BYPASS_SSL=n 

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
        -bssl)
           BYPASS_SSL=y 
           ;; 
        *)
           ;;
      esac
      shift  
    done 
    
    # If we are not bypassing ssl config, the cert info is required!
    if [ $BYPASS_SSL == n ]; then 
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
US=netcool; GR=itmusers; WH=/opt/IBM/Netcool/tip; PR=/opt/IBM/Netcool


CMD="$CMD $USE_CLIENT_PROPS"  # ??????

CMD="$SCRIPTDIR/tip_was_security_setup_v3.sh ED 70 TIPProfile "
CMD="$CMD  -projroot $PR -washome $WH "
CMD="$CMD -user $US -group"
CMD="$CMD $GR DKTS_override=\"-DKTS netcool.omnibusdev.webgui.jks  pw.ini\" -tipid NCO $args"

echo "About to execute: "
echo "$CMD"
prompt_to_continue

$CMD
rc=$?

echo "$SCRIPTNAME...complete  rc=$rc"

exit $rc