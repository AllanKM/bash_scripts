#!/bin/ksh
#############################################################################################
# rc.tip.sh  TIP Tivoli Integrated Portal stop,start,status,restart tool
#            It is intended to be run standalone, where it can discover well-known TIP apps   
#            or called by TIP application specific caller scripts
#            that supply the WASHOME, USER, and start-stop commands as needed.
#        
#                
# Usage: rc.tip.sh start|stop|status|restart|install 
#                    [-washome|-wh <dir>] [-user|-u <userid>] 
#                    [-adminuser|-au <id>] [-adminpw|-pw <pw>] [-debug] [-help]
#                    [-cmdStart|-cs cmd] [-cmdStop|-cp <cmd>] [-bypassYN|-byn] 
#                    [-jaz|jaz]
# 1. -user is command execution userid  
# 2. -bypassYN bypasses yn agent stop, starts, abd restart
#
# 2014-06-10 Support JazzSM with profile JazzSMProfile
# 2014-08-12 On Jazz nodes without standard TIP, do not require the jaz argument. 
#            If a well known TIP not installed, recognize Jazz as a well known environment.
#
#############################################################################################

SCRIPTNAME=$(basename $0)
SCRIPTVER=1.02

# Default input parameters based on a standard WAS7 EI standalone install
# Default app is TAD 
USER=webinst                 # userid under which the WAS commands execute 
USER_OVERRIDE="n"
WASHOME=/usr/WebSphere70/AppServer  
WASHOME_OVERRIDE="n"         # Has WAS_HOME been overriden by an argument?  
TIPID=tad 
PROFILE=TIPProfile
WAS_PROFILE_HOME=$WASHOME/profiles/TIPProfile
ADMINUSER=""                 # tipadmin
ADMINPW=""                   # tipadmin's password
ACTION=${1:-"status"}  
DEBUG=""
BYPASS_YN="n"                # Bypass start-stop of yn 
SILENT=n   
JAZZ=n

# These commands can be overriden by arguments, as in the case of TCR
CMD_START="$WAS_PROFILE_HOME/bin/startServer.sh server1"
CMD_STOP="$WAS_PROFILE_HOME/bin/stopServer.sh server1"
CMD_STATUS="$WAS_PROFILE_HOME/bin/serverStatus.sh server1"

ADMINUSERPW=""
CMD_START_OVERRIDE=""  
CMD_STOP_OVERRIDE=""
YN_RUNNING="n"

TADUSER=webinst
TCRUSER=webinst
NCOUSER=netcool
JAZUSER=webinst     
TIPDIR=/lfs/system/tools/tip     
      
# Display usage 
usage() {
    echo "Usage: rc.tip status|start|stop|restart|install "   
    echo "          [-washome|-wh <dir>] [-user|-u <userid>] [-silent|-s]"
    echo "          [-adminuser|-au <id>] [-adminpw|-pw <pw>] [-debug] [-help] "
    echo "          [-cmdStart|-cs <cmd>] [-cmdStop|-cp <cmd>] [-bypassYN|-byn] " 
    echo "          [-jaz|jaz]"
    echo "Details: "
    echo "  -user is command execution userid "  
    echo "  -bypassYN bypasses yn agent stop-start " 
} 

# Check root user
check_root_user() {
    if [ $(id -u) != 0 ]; then
        echo "ERROR: This script requires root access."
        exit 1
    fi
}

# Scan arguments
# Locate the floating arguments 
# WAS home examples:   -wh /usr/WebSphere70/AppServer
#                      -wh /opt/IBM/TCR/tip 
scan_arguments() {
    args_list=$*  
    while [ "$1" != "" ]; do
      case $1 in
        start|stop|status|restart|install)
           ;;        
        -debug)
           DEBUG="debug" 
           ;;  
        -help|-h|-usage)
           usage
           exit 
           ;;
        -user|-execuser|-u)
           shift 
           USER=$1
           USER_OVERRIDE="y"
           ;;  
        -washome|-wh)
           shift 
           WASHOME=$1
           WASHOME_OVERRIDE="y"    
           ;; 
        -cmdStart|-cs)
           shift 
           CMD_START_OVERRIDE=$1  
           ;; 
        -cmdStop|-cp)
           shift 
           CMD_STOP_OVERRIDE=$1  
           ;; 
        -adminuser|-auser|-au)
           shift 
           ADMINUSER=$1
           ;;
        -adminpw|-apw)
           shift 
           ADMINPW=$1
           ;; 
        -bypassYN|-byn)    
           BYPASS_YN="y"  
           ;;  
        -silent|-s)    
           SILENT="y"  
           ;;   
        -verbose|-v)    
           SILENT="n"  
           ;;   
        -jaz|jaz|-jazz|jazz)    
           JAZZ=y 
           WASHOME=/usr/WebSphere85/AppServer
           WASHOME_OVERRIDE="y" 
           PROFILE=JazzSMProfile  
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

# Rebuild variables because WASHOME to use is not the script default 
# Rebuild WASHOME, USER, start/stop/status commands 
#   $1 -   WASHOME   
#   $2 -   TIP type = tad, tcr, nco, tcr31
# Type tcr31 is jaz, where profile name is not the TIP standard 
rebuild_vars() {
  WASHOME=$1
  TIPID=$2
  [ -n "$DEBUG" ] && echo "*DEBUG* rebuild_vars entry: WASHOME=$WASHOME, TIPID=$TIPID"
  
  # 1.1 WASHOME
  #     Special case FOR Jazz.. profile name is different
  if [ $TIPID == "tcr31" ]; then
      JAZZ=y	
      PROFILE=JazzSMProfile  
  fi
  WAS_PROFILE_HOME=$WASHOME/profiles/$PROFILE
 
  # 2 USER if not supplied in args
  if [ $USER_OVERRIDE == "n" ]; then
      USER=webinst
      if  [ $TIPID == "nco" ]; then USER=$NCOUSER; fi  
  fi
  # 3 Commands if not overridden. 
  CMD_STATUS="$WAS_PROFILE_HOME/bin/serverStatus.sh server1" 
  if [ "$CMD_START_OVERRIDE" == "" ]; then 
      CMD_START="$WAS_PROFILE_HOME/bin/startServer.sh server1"
      if [ $TIPID == "tcr" ]; then    
          work=$(echo $WASHOME | sed -e "s/tip$//")     
          TCRHOME=${work}/tipComponents/TCRComponent
          CMD_START=$TCRHOME/bin/startTCRserver.sh 
      fi 
  fi 
  if [ "$CMD_STOP_OVERRIDE" == "" ] ;then 
      CMD_STOP="$WAS_PROFILE_HOME/bin/stopServer.sh server1 "
      if [ $TIPID == "tcr"  ]; then     
          work=$(echo $WASHOME | sed -e "s/tip$//")     
          TCRHOME=${work}/tipComponents/TCRComponent
          CMD_STOP=$TCRHOME/bin/stopTCRserver.sh
      fi 
  fi 
  [ -n "$DEBUG" ] && echo "*DEBUG* rebuild_vars exit: USER=$USER"    
  [ -n "$DEBUG" ] && echo "*DEBUG*   CMD_START=$CMD_START"
  [ -n "$DEBUG" ] && echo "*DEBUG*   CMD_STOP=$CMD_STOP"  
}
 
###  
# Determine WAS home and TIP type
# 2014-08-12 - Support jaz as a well-known environment, when TIP not installed
###
#WAS7="/usr/WebSphere70/AppServer:tad"   #WAS7 is the default 
WAS8="/usr/WebSphere80/AppServer:tad"    #WAS v8 not running TAD yet
TCR1="/opt/IBM/TCR1/tip:tcr" 
TCR="/opt/IBM/TCR/tip:tcr" 
NCO="/opt/IBM/Netcool/tip:nco"
TCR31="/usr/WebSphere85/AppServer:tcr31"   # TCR31 is special case. 
#known_applist="$WAS8 $TCR1 $TCR $NCO"
known_applist="$WAS8 $TCR1 $TCR $NCO $TCR31"

test_set_WASHOME() {
	 [ -n "$DEBUG" ] && echo "*DEBUG* test_set_WASHOME entry " 
    match=n
    if [ $WASHOME_OVERRIDE == "n" ]; then
        # If default WAS cannot be located 
        #  scan for supported environments 
        if [ ! -d $WASHOME ]; then
            echo " Default WASHOME not found; looking for other well-known locations"  
            # Output:  $WASHOME
            #          $TIPID
            for entry in $known_applist; do
                #echo ...entry=$entry
                dir=$(echo  $entry | cut -d':' -f1)
                type=$(echo $entry | cut -d':' -f2)
                #echo ...     dir=$dir type=$type
                if [ -d $dir ]; then
                    WASHOME=$dir
                    TIPID=$type
                    match=y
                    echo " WASHOME to use: $WASHOME, TIPID: $TIPID"
                    break
                fi
            done
            if [ $match == n ]; then echo "ERROR - No known WASHOME found. Supply -washome and rerun."
                exit 1
            fi
            rebuild_vars $WASHOME $TIPID
        fi
    fi
    [ -n "$DEBUG" ] && echo "*DEBUG* test_set_WASHOME exit  "     
}       
 
# Update after scanning arguments
update_post_scan() {
    [ -n "$DEBUG" ] && echo "*DEBUG* update_post_scan entry - WASHOME_OVERRIDE=$WASHOME_OVERRIDE" 
    # Check WASHOME  - are the defaults good?
    if [ $WASHOME_OVERRIDE == "n" ]; then
        test_set_WASHOME
    else   
        WAS_PROFILE_HOME=$WASHOME/profiles/$PROFILE
        # redefine commands now that WAS home has changed 
        CMD_START="$WAS_PROFILE_HOME/bin/startServer.sh server1"
        CMD_STOP="$WAS_PROFILE_HOME/bin/stopServer.sh server1"
        CMD_STATUS="$WAS_PROFILE_HOME/bin/serverStatus.sh server1"
    fi  
     
    if [ "$CMD_START_OVERRIDE" != "" ]; then
        CMD_START=$CMD_START_OVERRIDE
    fi
    if [ "$CMD_STOP_OVERRIDE" != "" ]; then
        CMD_STOP=$CMD_STOP_OVERRIDE
    fi
    if [ "$ADMINUSER" != "" -a "$ADMINPW" != "" ]; then
        ADMINUSERPW=" -username $ADMINUSER -password $ADMINPW "
        CMD_START="$CMD_START $ADMINUSERPW" 
        CMD_STOP="$CMD_STOP   $ADMINUSERPW"  
        CMD_STATUS="$CMD_STATUS $ADMINUSERPW"   
    fi  
    [ -n "$DEBUG" ] && echo "*DEBUG* update_post_scan exit with" 
    [ -n "$DEBUG" ] && echo "*DEBUG*   ACTION=$ACTION"
    [ -n "$DEBUG" ] && echo "*DEBUG*   USER=$USER,ADMINUSER=$ADMINUSER,ADMINPW=$ADMINPW"
    [ -n "$DEBUG" ] && echo "*DEBUG*   WASHOME=$WASHOME"  
    [ -n "$DEBUG" ] && echo "*DEBUG*   CMD_START=$CMD_START"  
    [ -n "$DEBUG" ] && echo "*DEBUG*   CMD_STOP=$CMD_STOP" 
}

confirm_input() {
  if [ $ACTION == "install" ]; then
    return 0  
  fi      
  echo 
  echo "###############"
  echo "Confirm input: "
  echo "###############"
  echo "..Action:              $ACTION" 
  echo "..WebSphere home(-wh): $WASHOME"    
  echo "..WAS profile home:    $WAS_PROFILE_HOME"   
  echo "..User(-u):            $USER" 
  if   [ $ACTION == "start" -o $ACTION == "restart" ]; then
     echo "..Start command:       $CMD_START"
  fi   
  if  [ $ACTION == "stop" -o $ACTION == "restart" ]; then 
     echo "..stop command:        $CMD_STOP"
  fi   
  if [ $ACTION == "status" ]; then    
     echo "..Status command:      $CMD_STATUS"
  fi  
  echo "..Bypass yn agent:     $BYPASS_YN" 
  echo 
  if [ $SILENT == "n" ]; then 
      echo "Hit enter to continue, or cancel CNTL-c to quit"  
      read -r choice  
  fi
}

# Is yn agent running?
is_yn_running() {
    YN_RUNNING="n"
    #yn_line=$(ps -ef | grep 'yn/bin/kynagent' | grep -v 'grep')
    yn_line=$(/etc/rc.itm status | grep ' yn ' | grep 'running' | grep -v 'grep')
    if [ "$yn_line" != "" ]; then
        YN_RUNNING="y"
    fi 
    [ -n "$DEBUG" ] && echo "*DEBUG* YN_RUNNING=$YN_RUNNING"
}
yn_start() {
    if [ $BYPASS_YN == "y" ]; then return 0; fi
    echo "############################# " 
    echo " Starting  yn agent"
    echo "############################# " 
    /etc/rc.itm start yn      
}
yn_stop() {
    if [ $BYPASS_YN == "y" ]; then return 0; fi
    echo "############################# " 
    echo " Stopping yn agent"
    echo "############################# " 
    /etc/rc.itm stop yn      
}
was_start() {
    echo "################################ " 
    echo " Starting WebSphere Appserver  "
    echo "################################ " 
    echo "Executing under $USER: \"$CMD_START\""
    su - $USER -c "$CMD_START"  
}
was_stop() {
    echo "################################ " 
    echo " Stopping WebSphere Appserver "
    echo "################################ " 
    echo "Executing under $USER:  \"$CMD_STOP\""
    su - $USER -c "$CMD_STOP" 
}

# Start WAS 
#  1.  stop yn if running  
#  2.  start WAS app server
#  3.  start yn if we stopped it 
start_was() {
    ynstop=n
    echo "Start WAS server1."     
    # 1 stop yn if running
    is_yn_running
    if [ $YN_RUNNING == "y" ]; then yn_stop; ynstop="y"; fi   
    # 2 start WAS 
    was_start
    # 3. start yn if we stopped it 
    if [ $ynstop == y ]; then yn_start; fi  
    echo "Start WAS server1...complete."      
}
# Stop WAS
#  1.  stop yn agent if running 
#  2.  stop WAS app server
#  3.  start yn if we stopped it 
stop_was() {
    ynstop=n
    echo "Stop WAS server1."    
    # 1. stop yn if running
    is_yn_running
    if [ $YN_RUNNING == "y" ]; then yn_stop; ynstop=y; fi  
    # 2. stop WAS app server
    was_stop
    # 3. start yn if we stopped it 
    if [ $ynstop == y ]; then yn_start; fi 
    echo "Stop WAS server1...complete."      
} 
# Status   
status_was() {
    echo "Executing under $USER: \"$CMD_STATUS\""
    su - $USER -c "$CMD_STATUS" 
    is="is"
    is_yn_running
    if [ $YN_RUNNING == "n" ]; then is="is not"; fi  
    echo
    echo "ITCAM for WebSphere yn agent $is running." 
   
}
# Restart WAS
restart_was() {
    ynstop=n
    echo "Restart WAS server1 using $USER"  
    # 1.  stop yn agent if running 
    is_yn_running
    if [ $YN_RUNNING == "y" ]; then yn_stop; ynstop=y; fi  
    # 2. Stop WAS
    was_stop
    # 3. start WAS 
    was_start
    # 3. start yn if we stopped it 
    if [ $ynstop == "y" ]; then yn_start; fi  
    echo
    echo "Restart WAS server1...complete." 
}     
 
# If action not supplied, and we supply arguments, need to reset ACTION to "status" 
test_action() {
    echo $ACTION | grep '-'  
    if [ $? == 0 ]; then ACTION="status"; fi  
} 

install() {
    echo "#########################" 
    echo " Installing /etc/rc.tip" 
    echo "#########################" 
    if [ ! -f $TIPDIR/bin/rc.tip.sh ]; then
        echo "ERROR - Script not found: $TIPDIR/bin/rc.tip.sh"
        exit 1
    fi    
    if [ -L /etc/rc.tip -o -f /etc/rc.tip ]; then
        work=$(ls -l /etc/rc.tip)
        echo " rc.tip  already defined"
        echo "  $work"
        echo " No action taken"
        return 16
    fi  
    ln -sf   $TIPDIR/bin/rc.tip.sh /etc/rc.tip
    if [ $? -ne 0 ]; then 
        echo "ERROR: Link command failed; install failed"   
        
        exit 1
    else
        echo " Install complete"    
    fi           
}    
####################
#
#  M A I N
# 
#################### 
echo "Executing script $SCRIPTNAME version $SCRIPTVER."

check_root_user

test_action

scan_arguments $*

update_post_scan

echo "... using user $USER and WASHOME $WASHOME"
if [ $BYPASS_YN == "y" ]; then echo "... yn agent processing will be bypassed."; fi

confirm_input

case "$ACTION" in
  install)
     install
     ;;
  start)
     start_was
     ;;
  stop)
     stop_was
     ;;
  status)
     status_was
     ;;   
  restart)
     restart_was
     ;;      
  *)
     echo "ERROR: Action $ACTION not supported."
     usage
     exit 1
     ;;
  esac

exit 0
