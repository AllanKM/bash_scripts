#!/bin/sh
#
# Usage: msrept_servers.sh [-d] [-bs]
#          -d   			  debug
#          -bs   				bypass sql call
#          -bks|-bk     bypass Kl1 Status call
#          -xo          run the extended only version merging itcam_info data
#                        to show unconnected reason 
#
# Ex:
# 
# Location: /lfs/system/tools/itcamwas/bin
#  
# 2015-02-03 Initial
# 2015-02-22 Beef up.
# 2015-03-05 Improve perms.
#     -10-05 If kl1 status call fails with rc!=0, exit 1. Correct excessing runtime logging in generate_kernel_status_rept
#            
#
#############################################################################################
#
# Sidebars
#  db2dir=/db2_database/itcamdb/sqllib/bin
#  $db2dir/db2 connect to OCTIGATE
#  ADMIN_SERVER='gzprewiwp.wpnode'
#  APP_SERVER='WebSphere_Portal(wpnode)'
#  sqlcmd="$db2dir/db2 select IP_ADDRESS, CONTROLLERID, ADMIN_SERVER from ITCAMUS.SERVERS \
#      where ADMIN_SERVER='$ADMIN_SERVER' and APP_SERVER='$APP_SERVER'"
#  sqlcmd="$db2dir/db2 select IP_ADDRESS, CONTROLLERID, ADMIN_SERVER from ITCAMUS.SERVERS \
#      where  APP_SERVER='$APP_SERVER'"
#
#############################################################################################

SCRIPTNAME=$(basename $0)
SCRIPTVER=1.03c

USER_itcamus_PW=uFD19s8t

NODE=$(hostname -s)
OS=$(uname)
ADMIN_SERVER=""    # ex 'gzprdwiwp.wpnode'
APP_SERVER=""      # ex 'WebSphere_Portal(wpnode)'
db2dir=/db2_database/itcamdb/sqllib/bin
map_updates=""

ITCAMMS_DIR=/projects/itcamms
ITCAMMS_REPTS_DIR=$ITCAMMS_DIR/reports
SQL_OUTPUT=$ITCAMMS_REPTS_DIR/servers_sqlrept_$NODE.txt
KL1_STATUS_OUTPUT=$ITCAMMS_REPTS_DIR/kl1_status_$NODE.txt

REPT1_OUTPUT=$ITCAMMS_REPTS_DIR/msrept_servers_$NODE.csv
REPT2_OUTPUT=$ITCAMMS_REPTS_DIR/msrept_servers_$NODE.sorted.csv

REPT1_NC_OUTPUT=$ITCAMMS_REPTS_DIR/msrept_servers_${NODE}_NC.csv
REPT2_NC_OUTPUT=$ITCAMMS_REPTS_DIR/msrept_servers_${NODE}_NC.sorted.csv

DEBUG=""
BYPASS_SQL=n
BYPASS_KS1_STATUS=n
GEN_EXT_REPT_ONLY=n

cnt_not_connected=0
cnt_connected=0

# Moved here manually for now
ITCAM_INFO_REPT=$ITCAMMS_REPTS_DIR/itcamdc_all.log
# Extended reporting 
REPT3_NC_OUTPUT=$ITCAMMS_REPTS_DIR/msrept_servers_${NODE}_NC.sorted_ext.csv

# Check root user
check_root_user() {
    if [ $(id -u) != 0 ]; then
        echo "ERROR: This script requires root access."
        exit 1
    fi
}

# Scan arguments
#    -ads and -aps are not used 
scan_arguments() {
    args_list=$*  
    while [ "$1" != "" ]; do
      case $1 in
         -debug|-d)
            DEBUG="-debug"
            ;;
         -ads)
            shift 
            ADMIN_SERVER=$1
            ;;    
         -aps)
            shift 
            APP_SERVER=$1
            ;;   
         -bypassSQL|-bsql|-bs)
             BYPASS_SQL=y
            ;;       
         -bypassKl1Status|-bks|-bk)
             BYPASS_KS1_STATUS=y
            ;; 
         -extendedOnly|-xo)
            GEN_EXT_REPT_ONLY=y
            ;;         
         *)
          if [ "$1" != "" ] ; then
              echo "Invalid argument supplied: $1 - Correct and resubmit."
              usage
              exit 1
          fi  
          ;;
      esac
      shift  
    done
}

init() {
	  init_dir $ITCAMMS_DIR
    init_dir $ITCAMMS_REPTS_DIR
    if [ $BYPASS_SQL == n ]; then
        init_file $SQL_OUTPUT 
    fi    
    init_file $REPT1_OUTPUT 
    init_file $REPT2_OUTPUT 
    
    init_file $REPT1_NC_OUTPUT 
    init_file $REPT2_NC_OUTPUT 
    
    init_file $REPT3_NC_OUTPUT 
    
    if [ $BYPASS_KS1_STATUS == n ]; then
        init_file $KL1_STATUS_OUTPUT
    fi    
    
}	

init_dir() {
    dir=$1
    if [ ! -d $dir ]; then
    	  echo "Creating directory $dir"
        mkdir -m 775 $dir	
        chmod g+s $dir
        chown root:itmusers $dir
    fi    
}		  	
init_file() {
	  file=$1
	  if [ "$file" == "" ]; then return 1; fi
	  if [ -f $file ]; then
	  	  echo "Clearing file $file"
	      echo "" > $file 
	  else 		
	      echo "Creating  $file"
    		touch $file	
    		chmod 775 $file	
    		chown root:itmusers $file
    fi 		
}	

cleanup() {
	   ..   
     #if [ -f "$SQL_OUTPUT" ]; then 
     #    rm -rf $SQL_OUTPUT
     #fi
}             	
     	
# locate_node
#   To use:  	locate_node $ip_addr
#   Returns 	ei_node  ( node name)
# 	rc = 0 lookup success
#   	 = 1 lookup failed 
locate_node() { 
   local ip
   ip=$1
   [ -n "$DEBUG" ] && echo  "  locating ei_node for ip=$ip"
   ei_node=""
   nodee0=$(nslookup $ip | grep event.ibm.com | cut -d'=' -f2 | cut -d'.' -f1 )
   if [ "$nodee0" == "" ]; then
       echo "ERROR: nslookup failed for ip=$ip...continuing"	
       return 1 
   fi	 
   # remove the training e0
   ei_node=$( echo $nodee0  | sed 's/e0$//g'  ) 
   [ -n "$DEBUG" ] && echo "   result:   $ei_node"
   return 0
}


check_input() {
    # if [ "$APP_SERVER"   == "" ]; then echo "ERROR: App server not supplied.. terminating"; exit 1; fi
    # if [ "$ADMIN_SERVER" == "" ]; then echo "ERROR: ADMIN_SERVER not supplied.. terminating"; exit 1; fi
    echo " "
}


###
# get_dirstore
#
# Input:  $1 node
# Output:
#          DS_CUSTTAG
#          DS_PLEX_ENV
#          DS_STATUS
#          DS_OS  
###
DS_CUSTTAG=""
DS_PLEX_ENV=""
DS_STATUS=""
DS_OS="" 
first=y
get_dirstore() {
    local node ds_rept 
    node=$1
    [ -n "$DEBUG" ] && echo  "  DIRSTORE lookup for node=$node"
    DS_CUSTTAG=
    DS_PLEX_ENV=""
    DS_STATUS=""
    if [ $first == y ]; then
        echo "    clearing all /tmp/itcam_dsrept_*.txt"
        rm -rf 	/tmp/itcam_dsrept_*.txt
        echo "    clearing all /tmp/itcam_dsrept_*.txt...done"
        first=n
    fi	
    ds_rept=/tmp/itcam_dsrept_$node.txt 
    if [ ! -f $ds_rept ]; then 
    	  #echo "    issuing lssys for $node creating $ds_rept"
    	  touch $ds_rept
    	  chmod 775 $ds_rept
        lssys $node >>  $ds_rept 
        #echo "    issuing lssys for $node creating $ds_rept...complete"
        sleep 1
    fi    
    plx=$(  grep realm $ds_rept    | grep -v authrealm  | cut -d'=' -f2  | cut -d '.' -f3 )   
    renv=$( grep realm $ds_rept    | grep -v authrealm  | cut -d'=' -f2  | cut -d '.' -f2 )  
    # a blank preceeds AIX, linux etc
    os=$(   grep oslevel $ds_rept  |                      cut -d'=' -f2  | cut -d ' ' -f2 )          
    DS_PLEX_ENV="${plx}_${renv}"    
    DS_STATUS=$(  grep nodestatus $ds_rept        | cut -d'=' -f2 | tr  -d ' '  ) 
    DS_CUSTTAG=$( grep custtag    $ds_rept        | cut -d'=' -f2 | tr  -d ' '  ) 
    DS_OS=$os
    [ -n "$DEBUG" ] && echo "    dirstore result: $DS_PLEX_ENV, $DS_PLEX_ENV, $DS_STATUS, $DS_OS" 
} 

# Output: $SQL_OUTPUT
lookup_servers() {
	echo "Looking up servers..."  
	$db2dir/db2 connect to OCTIGATE  USER itcamus using $USER_itcamus_PW
	if [ $? -ne 0 ]; then
   	 echo "Connection failed.. terminating"
     exit 1
	fi 
	sqlcmd="$db2dir/db2 select IP_ADDRESS, ADMIN_SERVER, APP_SERVER, \
                       	     ISPORTAL, ISCONFIGURED, DCVERSION, STARTTIME \
                        	   PROBEID,  CONTROLLERID  \
                 	    from ITCAMUS.SERVERS   \
                      ORDER BY ADMIN_SERVER, APP_SERVER  "
	echo "  generating sql output to $SQL_OUTPUT"   
	$sqlcmd  > $SQL_OUTPUT
	sql_rc=$?
	echo "  generating sql output to $SQL_OUTPUT...completed rc=$sql_rc"
	if [ $sql_rc -ne 0 ]; then echo "SQL failed...terminating"; exit 1; fi
	echo "Looking up servers...complete...with $SQL_OUTPUT"  
}	

# Output : $KL1_STATUS_OUTPUT
# Correctly support use case where we cannot run this report. 
#   Original code had a bug 
generate_kernel_status_rept() {
    kl1_stat_cmd="su - webinst -c /opt/IBM/ITCAM/bin/amctl.sh kl1 status "
    klstat_rc=0
    echo "Generating kernel status"  
    $kl1_stat_cmd  > $KL1_STATUS_OUTPUT
    klstat_rc=$?
    if [ $klstat_rc -ne 0 ]; then
        echo "   kernel status cmd failed rc=$klstat_rc ...terminating"
        exit 1
    fi
    is_rept_ended=""
    sleep_count=0
    while [  "$is_rept_ended" == "" ]
    do  
        echo "  2 secs  pausing while report is being formatted"
        sleep_count=$((sleep_count=sleep_count+1))
        if [ $sleep_count -gt 30 ]; then 
        	 echo "   unable to complete report written to $KL1_STATUS_OUTPUT"   	
        	 echo "   terminating"
        	 exit 1
        fi
        sleep 2
        is_rept_ended=$(grep '^-- END --' $KL1_STATUS_OUTPUT)
    done
    # Up to a max number
    echo "Generating kernel status...complete...with $KL1_STATUS_OUTPUT"   	
}	

# Is the server connected.. 
#    that is, is the controller id associated with the server connected to the kernel?
# In KL1_STATUS_OUTPUT
is_server_connected() {
    controller=$1
    [ "$DEBUG" != "" ] && echo "DEBUG:is_server_connected using:  controller=\"$controller\""
    [ "$DEBUG" != "" ] && echo     KL1_STATUS_OUTPUT=\"$KL1_STATUS_OUTPUT\"    
     
    is_connected=$( grep $controller $KL1_STATUS_OUTPUT )
 
    #  is=$(grep $ctl $KL1_STATUS_OUTPUT)
    if [ "$is_connected" == "" ]; then
    	  #echo "..no match"
    	  return 1
    else  
        #echo match
        return 0
    fi
}	


# In   REPT2_NC_OUTPUT
#      ITCAM_INFO_REPT=$ITCAMMS_REPTS_DIR/itcamdc_all.log
# Out  REPT3_NC_OUTPUT
generate_rept_extented() {
	 echo "Generating $REPT3_NC_OUTPUT by reading $REPT2_NC_OUTPUT"
  # title_line="aMSNode,Node,PlexEnv,Custtag,Status,Ip_addr,AdminServer,AppServer,DCv,Portal,Isconfig,OS,JVM_AGENTLIB_STATUS"

  cat $REPT2_NC_OUTPUT | while read line; do
      agentlib_status=""
      if [ "$line" == "" ]; then continue; fi
      title=$( echo $line  | grep  'aMSNode')
      if [ "$title"    != "" ]; then 
    	    # Write title line of csv report
    	    echo "$title,JVM_AGENTLIB_STATUS"  >> $REPT3_NC_OUTPUT
    	    continue
      fi
      node=$( echo $line | cut -d',' -f2 )
      as=$(   echo $line | cut -d',' -f8  | cut -d'(' -f1    ) 
      
      xas=$( grep "^$node: ITCAMDC" $ITCAM_INFO_REPT | grep as=$as: )  #  | grep JVM_AGENTLIB_STATUS= )
      if [ -n "$xas" ]; then
      	  # we often get two lines returned here:
          xags=$( grep "^$node: ITCAMDC" $ITCAM_INFO_REPT | grep as=$as: | grep JVM_AGENTLIB_STATUS= | cut -d':' -f4 | sed 's/^ //' ) 
      	  agentlib_status=$( echo $xags | cut -d'=' -f2 )
      else
          agentlib_status="AS_NOT_FOUND"
      fi	 
      echo  "$line,$agentlib_status" >> $REPT3_NC_OUTPUT
  done 
  echo "Generating $REPT3_NC_OUTPUT...complete"
}

####################
#  M A I N
#################### 
echo "Executing script $SCRIPTNAME version $SCRIPTVER."
scan_arguments $*
check_input

#Extended report only
if [ $GEN_EXT_REPT_ONLY == y ]; then
	  init_file $REPT3_NC_OUTPUT 
    generate_rept_extented
    echo
    echo "...report ending after the extended report" 
    exit 0    	
fi
	
init

# generate $SQL_OUTPUT
if [ $BYPASS_SQL == n ]; then 
    lookup_servers
fi    

# generate $KL1_STATUS_OUTPUT
if [ $BYPASS_KS1_STATUS == n ]; then
		generate_kernel_status_rept
fi		

#echo "--------------------------------------------"
#echo "$KL1_STATUS_OUTPUT"
#cat   $KL1_STATUS_OUTPUT
#echo "--------------------------------------------"
echo "Generating $REPT1_OUTPUT by scanning servers table output"
title_line="aMSNode,Node,PlexEnv,Custtag,Status,Ip_addr,AdminServer,AppServer,DCv,Portal,Isconfig,OS"
# IP_ADDRESS, ADMIN_SERVER, APP_SERVER, ISPORTAL, ISCONFIGURED, DCVERSION, STARTTIME \
cat $SQL_OUTPUT | while read line; do
    title=$( echo $line  | grep  'IP_ADDRESS')
    uline=$( echo $line  | grep  '^-')
    sel_line=$( echo $line | grep  'record(s) selected' ) 
     
    if [ "$title"    != "" ]; then 
    	  # Write title line of csv report
    	  echo $title_line >> $REPT1_OUTPUT
    	  echo $title_line >> $REPT1_NC_OUTPUT
    	  continue
    fi
    if [ "$uline"    != "" ]; then continue; fi
    if [ "$sel_line" != "" ]; then continue; fi
    ip=$(  echo $line | cut -d' ' -f1) 
    if [ "$ip" == "" ]; then continue; fi
    sqlcmd="$db2dir/db2 select IP_ADDRESS, ADMIN_SERVER, APP_SERVER,ISPORTAL, ISCONFIGURED, DCVERSION, PROBEID, CONTROLLERID  \
                 	    from ITCAMUS.SERVERS   \
                      ORDER BY ADMIN_SERVER, APP_SERVER  "
                         
    # IP_ADDRESS, ADMIN_SERVER, APP_SERVER, ISPORTAL, ISCONFIGURED, DCVERSION,  PROBEID, CONTROLLERID
    ads=$( echo $line | cut -d' ' -f2)   # ADMIN_SERVER
    aps=$( echo $line | cut -d' ' -f3 | cut -d'^' -f1    )   # 
    isp=$( echo $line | cut -d' ' -f4) 
    isc=$( echo $line | cut -d' ' -f5) 
    dcv=$( echo $line | cut -d' ' -f6) 
    pid=$( echo $line | cut -d' ' -f7) 
    cid=$( echo $line | cut -d' ' -f8) 
    
    IP_ADDRESS=$ip; ADMIN_SERVER=$ads; APP_SERVER=$aps; ISPORTAL=$isp; ISCONFIGURED=$isc; DCVERSION=$dcv; 
    PROBEID=$pid, CONTROLLERID=$cid
    # [ -n "$DEBUG" ] && echo "  ip=$ip, ads=$ads, aps=$aps, isp=$isp, isc=$isc, dcv=$dcv, pid=$pid, cid=$cid"
    # [ -n "$DEBUG" ] && echo "  ip=$ip, ads=$ads, aps=$aps, cid=$cid"
    
    # locate_node returns $ei_node 
    locate_node $ip
    if [ $? -ne 0 ]; then 
          echo "  INVALID_IP: $ADMIN_SERVER: $APP_SERVER: $CONTROLLERID"
    	    continue
    fi

    [ -n "$DEBUG" ] && echo "Connected: $ei_node $ADMIN_SERVER $APP_SERVER="

    # Locate dirstore info 
    #   DS_CUSTTAG
    #   DS_PLEX_ENV
    #   DS_STATUS
    #   DS_OS
    get_dirstore $ei_node
   
    # Create csv
    #  
    # Write report line
    #   
    out="$NODE,$ei_node,$DS_PLEX_ENV,$DS_CUSTTAG,$DS_STATUS,$IP_ADDRESS,$ADMIN_SERVER,$APP_SERVER,$DCVERSION,$ISPORTAL,$ISCONFIGURED,$DS_OS"
    [ -n "$DEBUG" ] && echo "  Output csv=$out"
    
    #
    # Connected or not-connected
    #  Is the server currently connected ? based on the kl1 status 
    #
    is_server_connected  $CONTROLLERID 
    if [ $? -ne 0 ]; then
        cnt_not_connected=$((cnt_not_connected + 1))	
        echo $out >> $REPT1_NC_OUTPUT
        if [ $? -ne 0 ]; then
        		echo "ERROR: generating report REPT1_NC_OUTPUT failed...terminating"
        		exit 1
    		fi   
		else
				cnt_connected=$((cnt_connected + 1))	
	   	  echo $out >> $REPT1_OUTPUT
	   	  if [ $? -ne 0 ]; then
        		echo "ERROR: generating report REPT1_OUTPUT failed...terminating"
    		 		exit 1
   		 fi   
    fi
    
done 
echo "Generating $REPT1_OUTPUT...complete"
echo "Generating $REPT1_NC_OUTPUT...complete"

# Need to sort by the first two fields
# CONNECTED SORTED REPORT
echo "Generating sorted report...$REPT2_OUTPUT"
sort -t, -k1,14  $REPT1_OUTPUT  >  $REPT2_OUTPUT
if [ $? -ne 0 ]; then
   echo "ERROR: generating sorted report REPT2_OUTPUT failed...terminating"
   exit 1
else
	echo "Generating sorted report...completed" 
fi  

# CONNECTED NON-SORTED REPORT   	
echo "Generating sorted NC report...$REPT2_NC_OUTPUT"
sort -t, -k1,14  $REPT1_NC_OUTPUT  >  $REPT2_NC_OUTPUT
if [ $? -ne 0 ]; then
   echo "ERROR: generating sorted NC report REPT2_NC_OUTPUT failed...terminating"
   exit 1
else
	 echo "Generating sorted NC report...completed" 
fi  


# Cleanup
#  Cleanup lssys reportd ?

echo 
echo "MS $NODE totals:"
echo "....total connected app servers:     $cnt_connected"
echo "....total not-connected app servers: $cnt_not_connected"	
echo	
echo "Script $SCRIPTNAME completed"

exit 0
