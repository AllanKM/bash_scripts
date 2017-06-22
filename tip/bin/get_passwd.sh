#!/bin/sh

#
# Obtains the tipadmin password from soap.client.props, decodes it, and returns the result.
# Supports an optional  WASHOME argument if the default is not sufficient
#
# Usage   get_passwd.sh [-washome <washome>] [-debug]
# Returns
#    If success:  unencoded password   
#    If error:    exit status non-zero 
# Writes debug info to a debug log in /tmp, $DEBUG_LOG 
#
# Ex: pw=$($TIP_TOOLS/bin/get_passwd.sh ) 
#     if [ $? -ne 0 ]; then
#         echo "ERROR: $pw"
#         exit 16
#     fi 
#
# 
                        
#---------------------------------------------------------------------------------
# Change History: 
# 2013-11-25 MEC Initial
#---------------------------------------------------------------------------------
#
SCRIPTNAME=$(basename $0)
SCRIPTVER=1.00

password=""
encoded_password=""
clear_password=""
WASHOME="/usr/WebSphere70/AppServer"      
DEBUG=""
DEBUG_LOG=/tmp/debug_get_passwd.log
TIP_TOOLS=/lfs/system/tools/tip
 
DECODE_CMD="$TIP_TOOLS/bin/Passwd_wrapper.sh decode $password_enc $WASHOME"

# Check root user
check_root_user() {
    if [ $(id -u) != 0 ]; then
        echo "ERROR: This script requires root access."
        exit 16
    fi
}

scan_arguments() {
    args_list=$*  
    while [ "$1" != "" ]; do
      case $1 in
        -debug)
           DEBUG="-debug" 
           ;;  
        -washome|-wh)
           shift 
           WASHOME=$1
           ;; 
        *)
          if [ "$1" != "" ] ; then
              echo "ERROR: Invalid argument supplied: $1 - Correct and resubmit."
              usage
              exit 16
          fi  
          ;;
      esac
      shift  
    done
}

init() {
    rm -f $DEBUG_LOG 2>&1 
    touch $DEBUG_LOG
    chown root:eiadm $DEBUG_LOG 
    chmod 770 $DEBUG_LOG  
}

############  
# M A I N   
############
check_root_user

# Clear any existing debug log
init

scan_arguments $*
[ -n "$DEBUG" ] && echo "\nExecuting $SCRIPTNAME version $SCRIPTVER. WASHOME=$WASHOME" >> $DEBUG_LOG

WAS_PROFILE_HOME="$WASHOME/profiles/TIPProfile" 

# 1. Locate encoded pw from soap.client.props
#    Careful- the encoded password congtains a trailing "="  
soap_client_props_path=$WAS_PROFILE_HOME/properties/soap.client.props
[ -n "$DEBUG" ] && echo "soap_client_props_path=$soap_client_props_path" >> $DEBUG_LOG
  
props_logon_pwd_enc_line=$(grep '^com.ibm.SOAP.loginPassword=' $soap_client_props_path)   #  | cut -d'=' -f 2) 
props_logon_pwd_enc=$(echo $props_logon_pwd_enc_line | sed -e "s/^com.ibm.SOAP.loginPassword=//")

if [ "$props_logon_pwd_enc" == "" ]; then
    echo "ERROR: Password not located in $soap_client_props_path"
    exit 16
fi    
[ -n "$DEBUG" ] && echo "props_logon_pwd_enc=$props_logon_pwd_enc" >> $DEBUG_LOG

# 2. De-code it  
       #CMD="$TIP_TOOLS/bin/Passwd_wrapper.sh decode $enc_pw $WASHOME"
decoded_pw=$($TIP_TOOLS/bin/Passwd_wrapper.sh decode $props_logon_pwd_enc  $WASHOME)
if [ $? -ne 0 ]; then
    echo "ERROR: Passwd_wrapper.sh failed - $decoded_pw"
    exit 16
fi    
[ -n "$DEBUG" ] && echo "Result: $decoded_pw" >> $DEBUG_LOG    
echo "$decoded_pw"

exit 0
   
     
 
 
