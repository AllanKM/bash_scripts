#!/bin/sh
#
#   Configures the TIP NCO SSL cert stores    
#     and adds entries to ssl.client.props.
#
#   Usage: nco_ssl_config.sh  -cf <jks_file_name> -pw <cert_pw>  
#              [-cf <jks_file_name|file.ini> ] # default is file.ini
#              [-pw <cert_pw|pw.ini > ]        # detailt is pw.ini  
#              xx [-tippw <tip_password>]      # Not used - Supply tipadmin's password when it is not "tipadmin"
#              xx [-no_useClientProps]         # Not used - do not pass useClientProps
# 
#           Supply "-cf file.ini" or do not supply "-cf": to use file name from $TIP_TOOLS/etc/node_jks.ini  
#           Specify  "-pw pw.ini" or do not supply "-pw": to use password  from $TIP_TOOLS/etc/passwds.ini
#
#   NCO WebGUI has not been using the EI WAS standard certificate, so these TIP scripts provide 
#   the DKTS override to specify the NCO certs.
# 
#
#   Typical use: 
# 
#   Example:
#     date=$(date +"%y%m%d%H%M")
#     logs=/logs/was70; lname=nco_ssl_config_$date.log; log=$logs/$lname
#     cd    /lfs/system/tools/tip/setup
#     sudo ./nco_ssl_config.sh -cf netcool.omnibusdev.webgui.jks -pw  yCrhwt5D | tee $log
#
#     or if the .ini files are used to supply the jks file name and password
#     sudo ./nco_ssl_config.sh | tee $log
#
#     
#   Requiremnts:
#     EI WAS tools in /lfs/system/tools/was
#     EI TIP tools in /lfs/system/tools/tip
#
#   TODO:  
#
#   Change History:
#     MEC  08-01-2014  Initial, from tip_nco_ssl_config.sh
#                      Support file name and pw etc lookups  
#
######################################################################################################################                     

SCRIPT_VERSION=1.00b
SCRIPTNAME=$(basename $0)
DATE=$(date +"%Y%m%d%H%M")
CONTINUE_PROMPTS=y
SCRIPTDIR=/lfs/system/tools/tip/setup
TIP_WAS_SECURITY_SETUP=tip_was_security_setup_v3.sh
args=$*

US=netcool; GR=itmusers; WH=/opt/IBM/Netcool/tip; PR=/opt/IBM/Netcool

CERT_FILE="file.ini"   # default file.ini -->  look in node_jks.ini for jks file name to use
CERT_PW="pw.ini"       # default pw.ini   -->  look in passwds.ini  for cert encoded password    
## USE_CLIENT_PROPS="-useClientProps" 
USE_CLIENT_PROPS=""
DEBUG="-debug"
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
        -nd|-nodebug)
           DEBUG=""
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

CMD="$SCRIPTDIR/$TIP_WAS_SECURITY_SETUP ED 70  TIPProfile -projroot $PR -washome $WH"
# CMD="$CMD $USE_CLIENT_PROPS"
CMD="$CMD $DEBUG"

# Bypass: permissions,status test, security config, and userid/pw soap.clients.props update
# pass the arguments received above
CMD="$CMD -user $US -group $GR $DKTS_override -tipid NCO -bp -bsst -bsec -bupw $args"

echo "About to execute: "
echo "$CMD"
prompt_to_continue

$CMD
rc=$?

if [ $rc -ne 0 ]; then
	  echo " ...exiting rc=$rc"
    exit $rc	
fi	
echo
echo "Now back to $SCRIPTNAME"
echo "Run server status command to test health of certificate and respond to trust prompt"
echo
prompt_to_continue
echo "Running status command test health of certificate and respond to trust prompt"
echo 
STATUS_CMD="/opt/IBM/Netcool/tip/profiles/TIPProfile/bin/serverStatus.sh server1"
su - netcool -c "$STATUS_CMD"
echo "Running status command...complete"

exit 0