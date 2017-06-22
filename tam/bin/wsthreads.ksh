#!/bin/ksh
# Script will use pdadmin utility to grab thread stats from each WebSEAL node
# Usage wsthreads.ksh [wshost]
# Author: Christopher Kalamaras
#
# History:
# 2009-04-07 CGK   Initial Version
# 2010-01-19 GJB   Add WI login test
#
# Revision Date: 20100119

if [ `whoami` != "root" ]; then
      echo "You must run this script as root"; exit 1
fi

if [[ $# -ge 1 ]]; then
   wshosts=$1
else
   wshosts=`lssys -q -e role==webseal.sso.prd`
fi

print "Please note, if your WI ID has not been added as a WebSEAL administrator, please see DOC-1848CGK for instructions."
print ""
read wiid?"Please enter your WI ID: "
print ""

stty -echo
read pass?"Please enter your WI password: "
stty echo
print ""

# test login so password doesn't get locked out when action is performed
loginresp=`pdadmin -a $wiid -p $pass exit`
if echo "$loginresp" | grep "Authentication failed" > /dev/null 2>&1;then
  echo
  echo "Authenication failed for $wiid. Make sure your password is correct and try again."
  echo
  exit
fi

for i in $wshosts; do
   echo "-----${i}-----"
   echo "Default Instance"
   pdadmin -a $wiid -p $pass server task default-webseald-${i} stats get pdweb.threads
   echo ""
   echo "Secondary Instance"
   pdadmin -a $wiid -p $pass server task secondary-webseald-${i} stats get pdweb.threads
   echo "--------------"
   echo ""
done

exit
