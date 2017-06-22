#!/bin/bash
#
# Port Listing Script
#
# Requirements:
#
#   Requires the getPorts.py script 
#     - Modify ports_script variable to reflect location
#
# Description:
#   When run from a Deployment Manager server, it will print the ports being
# utilized by each jvm.  If multiple Deployment Managers exist, each one
# will be parsed as part of the output.
# Supports: WAS 5.1, 6.0 and 6.1
#
# Output:
#   Script output will be as follows:
# 
#     <cell>,<node>,<jvm>,<portname>,<port>
#     ......
#     'Applications',<cell>,<node>,<jvm>,<appname1>
#     'Applications',<cell>,<node>,<jvm>,<appname2>
#     'Applications',<cell>,<node>,<jvm>,<appname#>
#
#  g2prd70wive,v20053,p2_dc_wwsm_masters_reg_v20053_2,WC_defaulthost_secure,9054
#  g2prd70wive,v20053,p2_dc_wwsm_masters_reg_v20053_2,SIP_DEFAULTHOST,5080
#  g2prd70wive,v20053,p2_dc_wwsm_masters_reg_v20053_2,SIP_DEFAULTHOST_SECURE,5081
#  g2prd70wive,v20053,p2_dc_wwsm_masters_reg_v20053_2,IPC_CONNECTOR_ADDRESS,9643
#  g2prd70wive,v20053,p2_dc_wwsm_masters_reg_v20053_2,SIB_ENDPOINT_ADDRESS,7296
#  g2prd70wive,v20053,p2_dc_wwsm_masters_reg_v20053_2,SIB_ENDPOINT_SECURE_ADDRESS,7297
#  g2prd70wive,v20053,p2_dc_wwsm_masters_reg_v20053_2,SIB_MQ_ENDPOINT_ADDRESS,5568
#  g2prd70wive,v20053,p2_dc_wwsm_masters_reg_v20053_2,SIB_MQ_ENDPOINT_SECURE_ADDRESS,5588
#  g2prd70wive,v20053,p2_dc_wwsm_masters_reg_v20053_2,OVERLAY_UDP_LISTENER_ADDRESS,11031
#  g2prd70wive,v20053,p2_dc_wwsm_masters_reg_v20053_2,OVERLAY_TCP_LISTENER_ADDRESS,11032
#  Applications,g2prd70wive,v20053,p2_dc_wwsm_masters_reg_v20053_2,masters_tickets
#
# Usage:
#
#  ./portreport.sh [hostname] [cell]
#
# Authors:
# 
#   Marjan Gjoni <mgjoni@us.ibm.com> Thad Hinz <thadhinz@us.ibm.com>
#
# Date Created:
#
#   06/08/2008
#
# Change history:
#
#   06/14/2015    mgjoni Add liberty support
#   11/10/2014    mgjoni Add support to specifiy a node name to search
#   03/06/2013    lamodeo  Add support foir WebSphere 8.5  
#   07/27/2012    James Walton <jfwalton@us.ibm.com> Merged my custom edits into the script.  If you give one or more version arguments (61 70 80) it print ports for just those versions, regardless of whether you run it from a DM node or not.  Also removed the was51 and was60 references.
#
#
#
if [[ ! -z "$1" ]]; then
	echo "Searching for Host: ${1}..."
	f=`grep -rli $1 /fs/system/config/was/*.csv`
        if [ $? -ne 0 ]; then  
		echo "Host: $1 not found"
		exit
        elif [ "$f" != '' ]; then
		if [[ -z "$2" ]]; then
		  GREP='YES'	
		else
		  GREP='NO'
		fi
		for i in $f; do
		echo
		echo "Filename: $i"
		if [ $GREP = 'YES' ]; then
	    	  cat $i |sort |grep -i $1
		else
	    	  cat $i |sort 
		fi
		echo
		done
        fi
	exit 0
fi
was70='/usr/WebSphere70/AppServer'
was85='/usr/WebSphere85/AppServer'
wlp='/usr/WebSphere/wlp/usr/servers'
wlp_sde='/usr/WebSphere/liberty/wlp/usr/servers'


if [ -d "$was70" -o -d "$was85" ]; then
   :
elif [ -d "$wlp" ]; then
   :
elif [ -d "$wlp_sde" ]; then
   :
else   
   echo "WebSphere is not installed on this system."
   exit 1 
fi

ports_script='/lfs/system/tools/was/lib/getPorts.py'
wlp_ports_script='/lfs/system/tools/was/lib/getWLPPorts.py'
hostname=`hostname`
roles=`lssys -x csv -l role $hostname | awk -F, {'print $2'}`
function wasPorts-OLD-2008Version
{
  was=${version}/profiles/
  profiledir=$(ls -d ${was}*/)
  for profile in $profiledir; do
    celldir=$(ls -d ${profile}config/cells/*/)
    for file in $celldir; do
      wasconfig=$(ls -d ${file}nodes/*/)
      for node in $wasconfig; do 
	if [ $1='apps' ]; then
          $ports_script ${node}serverindex.xml |grep 'Applications'
	else
          $ports_script ${node}serverindex.xml 
	fi
      done
    done
  done  
}

function wasPorts
{
  was=${version}/profiles/
  IFS='
'
  wasconfig=$(find ${was} -name 'serverindex.xml' |grep -v temp|grep -v dynamiccluster |grep -v backup)
  for node in $wasconfig; do
    $ports_script $node
  done
}

function wlpPorts
{
  IFS='
'
  wlpservers=$(find ${1} -name 'server.xml')
  for server in $wlpservers; do
    jvm=`echo $server | awk -F'/server.xml' {'print $1'} | awk -F'servers/' {'print $2'}`
    $wlp_ports_script $server $jvm `hostname`
  done
}

if [ -d "$was70" ]; then
    version=$was70
    wasPorts $version
fi 

if [ -d "$was85" ]; then
    version=$was85
    wasPorts $version
fi     

if [ -d "$wlp" ]; then
   wlpPorts $wlp 
elif [ -d "$wlp_sde" ]; then
   wlpPorts $wlp_sde
fi
