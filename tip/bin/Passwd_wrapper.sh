#!/bin/sh

# Passwd_wrapper.sh
# Wraps the Password Encoder and PasswordDecoder scripts so awk code is not needed to extract results.
# Supports an optional WASHOME argument in cases where needed. 
#
# Usage   Passwd_wrapper.sh encode  <clear password>    [washome]
#         Passwd_wrapper.sh decode  <endoded password>  [washome]
# Ex:     Passwd_wrapper.sh decode {xor}PhQwGBxmDGw=
#         Passwd_wrapper.sh encode pass1wd 
# Returns
#    If success:  pw-or-encoded-pw, exit status is zero   
#    If error:    exit status is non-zero 
# 
# Examples how to use:
#    pw=aKoGC9S3
#    echo "1  encode test_  $pw .................................."
#    CMD="$TIP_TOOLS/bin/Passwd_wrapper.sh encode $pw $WASHOME"
#    pw_enc=$($CMD) 
#    echo $pw_enc 
#
#    enc_pw="{xor}PhQwGBxmDGw="
#    echo "2  decode test_  $enc_pw= .................................."
#    CMD="$TIP_TOOLS/bin/Passwd_wrapper.sh decode $enc_pw $WASHOME"
#    pw=$($CMD) 
#    echo  $pw 
#   
                        
#---------------------------------------------------------------------------------
# Change History: 
# E Coley 2013-10-08 Initial
#         2013-11-25 Improvements 
#---------------------------------------------------------------------------------
#
password=""
encoded_password=""
clear_password=""
ACTION="decode"
WASHOME=""      # optional argument 
DEBUG=""
TIP_TOOLS=/lfs/system/tools/tip
 
decode_password() {
    password_encoded=$1
    CMD="$TIP_TOOLS/bin/PasswordDecoder.sh $password_encoded $WASHOME"
    pw_dec_rept=$($CMD)
    pw=$(echo $pw_dec_rept | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
    echo "$pw"
    exit 0
}  

encode_password() {
    password_clear=$1
    CMD="$TIP_TOOLS/bin/PasswordEncoder.sh $password_clear $WASHOME"
    pw_encoded_rept=$($CMD)
    #echo $pw_encoded_rep
    pw_encoded=$(echo $pw_encoded_rept | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
    echo  "$pw_encoded"
    exit 0
}  

if   [ $# -lt 2 ]; then
    echo "ERROR: # args less then two -  USAGE Passwd_wrapper.sh <action> <password>  [washome]"  
    exit 16
elif [ $# -eq 2 ]; then
    ACTION=$1
    password=$2   
elif [ $# -eq 3 ]; then
    ACTION=$1
    password=$2  
    WASHOME=$3   
else
    echo "ERROR: Invalid # of arguments USAGE- PasswordDecoder.sh <action> <password> [<WASHOME>]"  
    exit 16     
fi
  
if [ "$password" == "" ]; then
    echo "ERROR: password not supplied"
    exit 16  
fi

case "$ACTION" in
  encode)
    encode_password $password 
    ;;
  decode)
    decode_password $password 
    ;;
  *)
    echo "ERROR: Invalid action supplied: $parm  must be \"decode\" or \"encode\" "
    exit 16
    ;;
esac

exit
   
     
 
 
