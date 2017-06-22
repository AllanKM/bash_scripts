#!/bin/ksh
##################################################################################
#
# Author: Thad Hinz
# Date  : 06/03/2008
# Issues:
#         - doesn't currently accommodate deployment manager nodes
#         - 05/17/2015 Exclude Appdynamics MachineAgents from WAS process check 
##################################################################################
# used to isolate websphere java procs for sanity check
WASUSR=webinst

HOST=`hostname`

# current versions available. As new versions are added, add the path below 
# and update the case section below

WASPATH="/usr/WebSphere*/AppServer/profiles/${HOST}* /usr/WebSphere*/AppServer/profiles/?[z1-5]*anager /usr/WebSphere*/AppServer/profiles/wpnode*"
WXSPATH="/usr/WebSphere*/eXtremeScale /usr/WebSphere/eXtremeScale*"

condensed=0
LOWLIMIT=15
RANDOM=$$
PIDTRACKER=/tmp/was.pid.tracker.${RANDOM}

# ========= FUNCTIONS ==========
usage () {
  echo
  echo "Usage: `basename $0` [version] [csv]"
  echo "       where [version] = 51, 60, 61 or all"
  echo 
  echo "       * defaults to \"all\" if no argument specified"
  echo
  exit
}

isRunningAppSrv () {
  MYSRV=$1
  if [ "x$MYSRV" == "x" ]; then
    print -u2 -- "#### No instance name provided"
    exit 1
  else
    LOGBASE="${WAS_HOME}/logs"
    # if this is a portal farm node, set LOGBASE appropriately
    [ -d /usr/WebSphere*/portalfs ] && LOGBASE="/usr/WebSphere*/portalfs/logs"
    [ -d /usr/WebSphere/wlp ] && LOGBASE="/logs/wlp"
  fi

  PIDFILE="$LOGBASE/$MYSRV/$MYSRV.pid"
  [ -d /usr/WebSphere/wlp ] && PIDFILE="${LOGBASE}/.pid/${MYSRV}.pid"

  if [ ! -f $PIDFILE ]; then
    #echo "Pid file does not exist: $PIDFILE"
    MYPID=""
    UPSINCE=""
  else
    UPSINCE=`ls -l $PIDFILE | awk '{print $6" "$7" "$8}'`
    PID=$(cat $PIDFILE)
    MYPID=$PID
 fi
  ps -ef | grep -v grep | grep $MYPID > /dev/null 2>&1; RC=$?
  if [ $RC -eq 0 ]; then
    return 0
  else
    return 1
  fi
}

setVersionDir () {
	case $1 in
  		70) WAS_HOME_LIST=$WAS70PATH ;;
  		all|ALL) WAS_HOME_LIST="$WASPATH" ;;
  		*) print -u2 -- "#### Invalid version specified"; usage; exit 1;;
	esac
}

# ======== MAIN ==========

# set default version to ALL if none specified
if [ $# -lt 1 ];then
	setVersionDir "ALL"
   condensed=0
elif [ $# -eq 1 ]; then
  	if [ $1 = "csv" ]; then
		setVersionDir "ALL"
   	condensed=1
  	else
   	setVersionDir $1
  	fi
elif [ $# -eq 2 ]; then
	setVersionDir $1
  	condensed=1
fi

TOTRUNCOUNT=0

if [ -f $PIDTRACKER ];then
	rm -f $PIDTRACKER
fi

GREPPATT=""
INDENT="    "

if [ $condensed -ne 1 ]; then
	echo 
	echo "---------------------------"
	echo "   HOST: $HOST" 
	echo "---------------------------"
fi

for WAS_HOME in $WAS_HOME_LIST; do
	# skip over directories that don't exist 
  	if [ ! -d $WAS_HOME ];then
   	continue
  	fi

  	# make a grep pattern for running against ps command (to find only those was procs for specified version)
  	WASVER=`echo $WAS_HOME | awk -F"/" '{print $3}'`
  	if [[ $GREPPATT == "" ]];then
   	GREPPATT="$WASVER"
  	else
   	GREPPATT="${GREPPATT}|${WASVER}"
  	fi
  
  	echo $WAS_HOME | grep -i manager >/dev/null
  	if [ $? -eq 0 ]; then
  		SERVPATH="$WAS_HOME/config/cells/*/nodes/*anager/servers"
  	else
		SERVPATH="$WAS_HOME/config/cells/*/nodes/${HOST}*/servers"
  	fi
  	# set SERVPATH appropriately if this is a portal farm node
    [ -d $WAS_HOME/config/cells/*/nodes/wpnode/servers ] && SERVPATH="$WAS_HOME/config/cells/*/nodes/wpnode/servers"
  	SERVBASE=${SERVPATH%%profiles*}/properties/version/WAS.product
  	[[ $WAS_HOME == "/usr/WebSphere/wlp" ]] && SERVPATH="$WAS_HOME/usr/servers"
  	echo
  	echo "${INDENT}--------------------------------------------------------------------"
  	echo "${INDENT} APP SERVERS UNDER: $WAS_HOME"
    if [[ $WAS_HOME == "/usr/WebSphere/wlp" ]]; then
        /usr/WebSphere/wlp/bin/productInfo version
    else
  	( while read line; do
		if [[ "$line" = *"<product"* ]]; then
			name=${line#*name=\"}
			name=${name%%\"*}
		fi
		if [[ "$line" = *"<version"* ]]; then
			version=${line#*\>}
			version=${version%%\<*}
		fi
		if [[ "$line" = *"date=\""* ]]; then
			date=${line#*date=\"}
			date=${date%%\"*}
		fi
		if [[ "$line" = *"level=\""* ]]; then
			level=${line#*level=\"}
			level=${level%%\"*}
		fi
		if [[ "$line" = *"</product"* ]]; then
			print "${INDENT} version: $version  build date: $date  level: $level"
		fi
	 done ) < $SERVBASE
    fi
  	if [ $condensed -ne 1 ]; then
  		echo "${INDENT}--------------------------------------------------------------------"
  	fi

  	MYSERVS=`ls -1 ${SERVPATH}`

  	# first find out what column 1 size should be since app server names vary
  	HOLDSZ=$LOWLIMIT
  	HIGHNUMB=0
  	for SERV in $MYSERVS; do
    	CHARCNT=`echo ${SERV} | wc -c`
    	if [ ! $CHARCNT -le $HOLDSZ ]; then
      	HOLDSZ=$CHARCNT
    	fi 
  	done

  # column 1 size is dynamic
  	COL0SZ=4
  	COL1SZ=$(($HOLDSZ+1))
  	COL2SZ=12
  	COL3SZ=8
  	COL4SZ=12

  	if [ $condensed -ne 1 ]; then
  		echo
  		printf "%-${COL0SZ}s %-${COL1SZ}s %-${COL2SZ}s %-${COL3SZ}s %-${COL4SZ}s\n" \
          "" "SERVER NAME" "STATE" "PID" "UP SINCE"
  		printf "%-${COL0SZ}s %-${COL1SZ}s %-${COL2SZ}s %-${COL3SZ}s %-${COL4SZ}s\n" "" "--------------" "-------" "-------" "------------"
  	fi

  	SERVCNT=0
  	RUNCOUNT=0
  	for SERV in $MYSERVS; do
   	[[ -n "$debug" ]] && print "doing $SERV"
	 	if [[ "$SERV" = `hostname -s`* ]]; then
			APP=${SERV#*_}
    	else 
			APP=${SERV}
	 	fi

    	SERVCNT=$(($SERVCNT+1))
    	# check server state
    	if isRunningAppSrv ${SERV}; then
      	if grep  "$APP$" /lfs/system/tools/was/conf/disabled_appserver 1>/dev/null 2>&1; then
         	STATE="## SHOULD NOT BE RUNNING ##"
      	else
         	STATE="RUNNING"
      	fi
      	RUNCOUNT=$(($RUNCOUNT+1))
      	TOTRUNCOUNT=$(($TOTRUNCOUNT+1))
      	RUNPID=$MYPID
      	echo "#$MYPID#" >> $PIDTRACKER
    	else
			if grep "$APP$" /lfs/system/tools/was/conf/disabled_appserver 1>/dev/null 2>&1; then
				STATE="## DO NOT START ##"
      	else
         	STATE="##STOPPED##"
      	fi
      	MYPID=''
      	UPSINCE=''
    	fi

    	if [ $condensed -ne 1 ]; then
      	printf "%-${COL0SZ}s %-${COL1SZ}s %-${COL2SZ}s %-${COL3SZ}s %-${COL4SZ}s\n" "" "${SERV}" "${STATE}" "${MYPID}" "${UPSINCE}"
    	else
      	echo "${SERV},${STATE},${MYPID},${UPSINCE},${HOST}"
    	fi 
  	done
  
  
  	if [ $condensed -ne 1 ]; then
  		echo
  		echo "${INDENT}SERVER COUNT  = $SERVCNT"
  		echo "${INDENT}RUNNING COUNT = $RUNCOUNT"
  		echo
  	fi

	if [ $SERVCNT -gt $RUNCOUNT ]; then
  		print -u2 -- "### Not all defined WAS servers are running"
  	fi
  
done

# sanity check, compare total run count to a total of all java procs run by $WASUSR
if [[ $GREPPATT != "" ]];then
	[[ -n "$debug" ]] && ps -ef | grep -v grep | grep java | grep $WASUSR | egrep "$GREPPATT " | grep -v "MachineAgent"
  ACTUALCOUNT=`ps -ef | grep -v grep | grep java | grep $WASUSR | egrep "$GREPPATT" | grep -v "MachineAgent" | wc -l | sed 's/ //g'`
  [[ -n "$debug" ]] && ps -ef | grep -v grep | grep java | grep $WASUSR | egrep "$GREPPATT" | grep -v "MachineAgent" | awk '{print $2}'
  ACTPIDLIST=`ps -ef | grep -v grep | grep java | grep $WASUSR | egrep "$GREPPATT" | grep -v "MachineAgent" | awk '{print $2}'`
  UNKPIDLIST=""
  if [ $TOTRUNCOUNT -ne $ACTUALCOUNT ]; then
    for i in $ACTPIDLIST; do
      grep "#${i}#" $PIDTRACKER > /dev/null 2>&1; RC=$?
      if [ $RC -ne 0 ];then
		  proc=$(ps -ef | grep ${i} | grep -v grep)
		  if [[ "$proc" = *ServerStop* ]]; then
			 UNKPIDLIST="$UNKPIDLIST ${i}"$(print $proc | awk '{print "(stop server "$(NF)")"}')
		  elif [[ "$proc" = *ServerStart* ]]; then
			 UNKPIDLIST="$UNKPIDLIST ${i}"$(print $proc | awk '{print "(start server "$(NF)")"}')
		  elif [[ "$proc" = *WsServer* ]]; then
			 UNKPIDLIST="$UNKPIDLIST ${i}"$(print $proc | awk '{print "(server "$(NF)")"}')
		  else
          UNKPIDLIST="$UNKPIDLIST ${i}"
		  fi
      fi 
    done
    if [[ -n "$UNKPIDLIST" ]]; then
    print -u2 -- "${INDENT}#--------------------------- NOTICE ---------------------------------------------------#"
    print -u2 -- "${INDENT}#                                                                                      #" 
    print -u2 -- "${INDENT}#    Extra java process found running under the $WASUSR id than those defined in WAS.  #"
    print -u2 -- "${INDENT}#    You might want to ensure that process is not a server listed as STOPPED.          #"
    print -u2 -- "${INDENT}#    Also check for a hung or runaway wsadmin.sh process                               #"
    print -u2 -- "${INDENT}#                                                                                      #" 
    print -u2 -- "${INDENT}#--------------------------- NOTICE ---------------------------------------------------#"
    echo
    print -u2 -- "${INDENT}# Unaccounted for java PIDS: $UNKPIDLIST"
    echo
    fi
  fi
else
  echo 
  print -u2 -- "${INDENT}# Directory not found: $WAS_HOME"
  echo 
fi
rm -f $PIDTRACKER
#
# Find and report on any running WXS servers 
#
echo
echo

for WXS_HOME in $WXSPATH; do
  # skip over directories that don't exist 
  if [ ! -d $WXS_HOME ];then
    continue
  fi
 
  SERVBASE=$WXS_HOME/properties/version/WXS.product 
  echo
  echo "${INDENT}--------------------------------------------------------------------"
  echo "${INDENT} WXS SERVERS UNDER: $WXS_HOME"
  ( while read line; do
    if [[ "$line" = *"<product"* ]]; then
        name=${line#*name=\"}
        name=${name%%\"*}
    fi
    if [[ "$line" = *"<version"* ]]; then
        version=${line#*\>}
        version=${version%%\<*}
    fi
    if [[ "$line" = *"date=\""* ]]; then
        date=${line#*date=\"}
        date=${date%%\"*}
    fi
    if [[ "$line" = *"level=\""* ]]; then
        level=${line#*level=\"}
        level=${level%%\"*}
    fi
    if [[ "$line" = *"</product"* ]]; then
        print "${INDENT} version: $version  build date: $date  level: $level"
    fi
     done ) < $SERVBASE
  if [ $condensed -ne 1 ]; then
      echo "${INDENT}--------------------------------------------------------------------"
  fi
  
  COL0SZ=4
  COL1SZ=24
  COL2SZ=12
  COL3SZ=8
  COL4SZ=10
  COL5SZ=12
  
  # Example Output:
  #
  # SERVER NAME             STATE    PID       START      ELAPSED TIME
  # z10005_wxs_catalog      Running  13959348  19:06:58   154-21:49:06
  # z10005_ecc_grid         Running  13959348  19:06:58   154-21:49:06

  if [ $condensed -ne 1 ]; then
      echo
      printf "%-${COL0SZ}s %-${COL1SZ}s %-${COL2SZ}s %-${COL3SZ}s %-${COL4SZ}s %-${COL5SZ}s\n"\
          "" "SERVER NAME            " "STATE       " "PID     " "START     " "ELAPSED TIME"
      printf "%-${COL0SZ}s %-${COL1SZ}s %-${COL2SZ}s %-${COL3SZ}s %-${COL4SZ}s %-${COL5SZ}s\n"\
          "" "-----------------------" "------------" "--------" "----------" "------------"
  fi

  RUNCOUNT=0 
 
  WXSCTLGLIST=`ps -ef | grep ${HOST}_wxs.*_catalog | grep java | grep -i $WXS_HOME | awk '{print  $2}'`
  WXSGRIDLIST=`ps -ef | grep ${HOST}_.*_grid     | grep java | grep -i $WXS_HOME | awk '{print  $2}'`
  PIDLIST="${WXSCTLGLIST} ${WXSGRIDLIST}"
  
  for PID in $PIDLIST; do
    [[ -n "$debug" ]] && print "doing $PID"
    
    PIDARGS=`ps -o args= -p $PID`
    
    echo $WXS_HOME | grep -i eXtremeScale71 >/dev/null
    if [ $? -eq 0 ]; then
        SERV=`echo $PIDARGS | awk '{startpos=index($0,"InitializationService"); endpos=index($0,"-serverProps"); lth=(endpos-(startpos+22)); s=substr($0,(startpos+22),lth); print s}'`
    else
        SERV=`echo $PIDARGS | awk '{startpos=index($0,"InitializationService"); endpos=index($0,"-transport"); lth=(endpos-(startpos+22)); s=substr($0,(startpos+22),lth); print s}'`
    fi
    
    STATE="RUNNING"
    MYPID=$PID
    START=`ps -o start=   -p $PID`
    ELAPSED=`ps -o etime= -p $PID`
    RUNCOUNT=$(($RUNCOUNT+1))

    if [ $condensed -ne 1 ]; then
      printf "%-${COL0SZ}s %-${COL1SZ}s %-${COL2SZ}s %-${COL3SZ}s %-${COL4SZ}s %-${COL5SZ}s\n"\
          "" "${SERV}" "${STATE}" "${MYPID}" "${START}" "${ELAPSED}"
    else
        echo "${SERV},${STATE},${MYPID},${START},${ELAPSED}"
    fi 
  done
  
  if [ $condensed -ne 1 ]; then
  echo

  echo "${INDENT}WXS RUNNING COUNT = $RUNCOUNT"
  echo
  fi

done

