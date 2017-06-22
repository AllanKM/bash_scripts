#!/bin/ksh

##########################################################################################
# Script Name - wi_conn.ksh
# Author - Chris Kalamaras
# Purpose - This script will check for connectivity to the WI servers by calling socketCheck.pl
##########################################################################################

CFGHOME=/lfs/system/tools/configtools
case $1 in
	cdt|pre)	WIFILE=/lfs/system/tools/was/conf/wi_ait_hosts ;;
	*)	WIFILE=/lfs/system/tools/was/conf/wi_hosts ;;
esac
CONN_CHECK=$CFGHOME/socketCheck.pl

###############################################################
#Check if WI entries exist in /etc/hosts. If not append them  #
###############################################################
echo "Checking for WI entries in /etc/hosts and appending them if necessary..."
{ while read myline; do
  WIHOST=`echo $myline | cut -f2 -d " "`
  SEARCH=`grep -c $WIHOST /etc/hosts`
   if [ $SEARCH -eq 0 ] ; then
      echo "Appending Web Identity host entry " $myline " to /etc/hosts file..."
      print $myline >> /etc/hosts
   else
      echo "Entry for " $myline " already exists...skipping"
   fi
done } < $WIFILE
echo "Updates to /etc/hosts completed."

##############################################################
#Check connectivity to WI Servers                            #
##############################################################
echo "Checking connectivity to Web Identity Servers..."
count=0
for i in `cut -f1 $WIFILE|grep -v '^#'` ; do
   $CONN_CHECK -h $i -p 636 | grep "OK"
   if [ $? -eq 0 ] ; then
        count=$(($count+1))
   fi
done

if [[ $count -lt 1 ]] ; then
  echo "Unable to connect to ANY of the listed WI servers."
  echo "Please ensure that the ldaps ports have been opened on the firewalls."
else
echo "Connectivity to atleast one WI server was successful."
fi
