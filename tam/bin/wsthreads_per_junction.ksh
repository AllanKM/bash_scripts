#!/bin/ksh
# Script will use pdadmin utility to grab thread stats from each WebSEAL node and/or junction
# Usage wsthreads_by_junction.ksh [wshost] [junction]
# Author: Gregg Bollinger
#
# History:
# 2010-09-01 GJB   Initial Version
#
# Revision Date: 20100901

if [ $(whoami) != "root" ]; then
      echo "You must run this script as root"; exit 1
fi

junction=""
wshosts=""

#set -x
if [ "$1" == "-h" -o "$1" == "-?" -o "$1" == "help" -o $# -ge 3 ] ; then
   echo ""
   echo "USAGE: $0 <node> <junction>"
   echo "       will return threads for that junction on that node."
   echo ""
   echo "       $0 <node>"
   echo "       will return threads for all junctions on that node."
   echo ""
   echo "       $0 <junction>"
   echo "       will return threads for that junctions on all nodes."
   echo ""
   exit 1
fi

if [[ $# -ge 1 ]]; then
   if [[ $(echo $1 | cut -c1) == '/' ]] ; then
        junction=$1
   else
        wshosts=$1
   fi
   if [[ $# -eq 2 ]] ; then
        if [[ "$(echo $2 | cut -c1)" == '/' ]] ; then
           junction=$2
        else
           wshosts=$2
        fi
   fi
fi

if [[ "${wshosts}" == "" ]] ; then
   wshosts=$(lssys -q -e role==webseal.sso.prd)
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
loginresp=$(pdadmin -a $wiid -p $pass exit)
if echo "$loginresp" | grep "Authentication failed" > /dev/null 2>&1;then
  echo
  echo "Authenication failed for $wiid. Make sure your password is correct and try again."
  echo
  exit
fi

if [[ "${junction}" == "" ]] ; then
    junction=$(pdadmin -a $wiid -p $pass server task default-webseald-v10017 list | egrep -wv /\|/bounce\|/usrsrvc\|/dummy | sort | xargs)
fi

for host in ${wshosts} ; do
   echo "-----${host}-----"
   for jct in ${junction} ; do
   echo "${jct}"
   pdadmin -a ${wiid} -p ${pass} server task default-webseald-${host} show ${jct} | egrep requests\|"Active worker threads"\|Hostname
   echo "--------------"
   done
   echo ""
done

exit
