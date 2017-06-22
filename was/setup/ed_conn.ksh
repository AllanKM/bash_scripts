#!/bin/ksh

##########################################################################################
# Script Name - ed_conn.ksh
# Author - James Walton (based on Chris Kalamaras' ud_conn.ksh)
# Purpose - This script check for connectivity to the ED servers by calling socketCheck.pl
##########################################################################################
#
#   Change History: 
#     Lou Amodeo    03-01-2013  Add support for Websphere 8.5 
#
CFGHOME=/lfs/system/tools/configtools
EDHOST=bluepages.ibm.com
CONN_CHECK=$CFGHOME/socketCheck.pl

##############################################################
#Check connectivity to ED Server                             #
##############################################################
echo "Checking connectivity to Enterprise Directory Server..."
$CONN_CHECK -h $EDHOST -p 636 | grep "OK"

if [[ $? -ne 0 ]] ; then
  echo "Unable to connect to the ED server."
  echo "Please ensure that the ldaps ports have been opened on the firewalls."
else
echo "Connectivity to the ED server was successful."
fi
