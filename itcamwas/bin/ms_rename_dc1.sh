#!/bin/ksh
#############################################################################################
# ms_rename_dc1.sh   
#
# Usage:  ms_rename_dc1.sh  -ads "<admin_server>"  -aps "<app_servcer>"  
#       -ads is optional { future } 
#
# Ex:
#      # Run for a specific admin_server and app_server
#      ms_rename_dc1.sh -ads "gzprdwiwp.wpnode" -aps "WebSphere_Portal(wpnode)"
#      ms_rename_dc1.sh -ads "gzcdtwiwp.wpnode" -aps "WebSphere_Portal(wpnode)"
#      ms_rename_dc1.sh -ads "gzprewiwp.wpnode" -aps "WebSphere_Portal(wpnode)"
#      
#      {future} # Run for all admin_servers for a specified app_server
#                 ms_rename_dc1.sh  -aps "WebSphere_Portal(wpnode)"
# 

#  
# 2014-11-18 Initial
#
#
# TO DO: 
# 1. Automatically update dc map file.
# 2. Support supplying only app server  
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
SCRIPTVER=1.00


ADMIN_SERVER=""    # ex 'gzprdwiwp.wpnode'
APP_SERVER=""      # ex 'WebSphere_Portal(wpnode)'
db2dir=/db2_database/itcamdb/sqllib/bin
map_updates=""

SQL_REPT=~/sqlrept_$$.txt
DEBUG=""

# Check root user
check_root_user() {
    if [ $(id -u) != 0 ]; then
        echo "ERROR: This script requires root access."
        exit 1
    fi
}


# Scan arguments
scan_arguments() {
    args_list=$*  
    while [ "$1" != "" ]; do
      case $1 in
         -debug)
            DEBUG="-more debug" 
            ;;
         -ads)
            shift 
            ADMIN_SERVER=$1
            ;;    
         -aps)
            shift 
            APP_SERVER=$1
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

# returns ei_node
# rc = 0 lookup success
#    = 1 lookup failed 
locate_node() { 
   local ip
   ip=$1
   [ -n "$DEBUG" ] && echo  "  locating ei_node for ip=$ip"
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
    if [ "$APP_SERVER"   == "" ]; then echo "ERROR: App server not supplied.. terminating"; exit 1; fi
    if [ "$ADMIN_SERVER" == "" ]; then echo "ERROR: ADMIN_SERVER not supplied.. terminating"; exit 1; fi

}


####################
#  M A I N
#################### 
echo "Executing script $SCRIPTNAME version $SCRIPTVER."

scan_arguments $*

check_input

echo "Looking up ADMIN_SERVER=$ADMIN_SERVER, APP_SERVER=$APP_SERVER"


$db2dir/db2 connect to OCTIGATE  USER itcamus using uFD19s8t
if [ $? -ne 0 ]; then
    echo "Connection failed.. terminating"
    exit 1
fi 

sqlcmd="$db2dir/db2 select IP_ADDRESS, CONTROLLERID, ADMIN_SERVER from ITCAMUS.SERVERS \
     where ADMIN_SERVER='$ADMIN_SERVER' and APP_SERVER='$APP_SERVER' \
     ORDER BY ADMIN_SERVER "
sqlcmd_all_admins="$db2dir/db2 select IP_ADDRESS, CONTROLLERID, ADMIN_SERVER from ITCAMUS.SERVERS \
     where APP_SERVER='$APP_SERVER' \
     ORDER BY ADMIN_SERVER "
     

echo "generating sql output to ~/sqlrept_$$.txt"
if [ "$ADMIN_SERVER" == "" ]; then 
    $sqlcmd  > $SQL_REPT
else
    $sqlcmd_all_admins  > $SQL_REPT
fi         
sql_rc=$?
chmod 775 $SQL_REPT
if [ $sql_rc -ne 0 ]; then echo "SQL failed...terminating"; exit 1; fi


echo "scanning that output"
cat $SQL_REPT | while read line; do
    # 10.111.48.15         114d83a3-37dc-e301-39b8-3bc58eaffeea     gzprewiwp.wpnode
    x=$( echo $line | grep  $ADMIN_SERVER) 
    if [ "$x" == "" ]; then continue; fi
    ip=$( echo $line | cut -d' ' -f1) 
    id=$( echo $line | cut -d' ' -f2) 
    ads=$(echo $line | cut -d' ' -f3) 
    [ -n "$DEBUG" ] && echo "  ip=$ip, id=$id, ads=$ads"
    
    # locate_node returns $node 
    locate_node $ip
    if [ $? -ne 0 ]; then continue; fi

    # Format the line 
    # d079ac32-4664-e401-14f3-569ecd4d3a8d=gzprewiwp.wpnode:WebSphere_Portal(wpnode)_w30197
    dc_map_line="$id=${ADMIN_SERVER}:${APP_SERVER}_$ei_node"
    [ -n "$DEBUG" ] && echo "   dc_map_line=$dc_map_line" 
    map_updates="$map_updates $dc_map_line"
done 

echo
echo "###################################################"
echo "Updates needed to  dcServerNameMap.properties file "
echo "###################################################"
echo
for line in $map_updates; do
    echo "$line"
done

# delete the report
# rm -rf ~/sqlrept_$$.txt"

echo 
echo "Script $SCRIPTNAME completed"

exit 0
