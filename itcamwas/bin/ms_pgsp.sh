#!/bin/ksh
#############################################################################################
# ms_pgsp.sh   
#
# Usage: ms_pgsp.sh
#
# 2014-09-22 Initial
#        -23 Add gps
#
#
#############################################################################################

SCRIPTNAME=$(basename $0)
SCRIPTVER=1.01


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
           DEBUG="debug" 
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

# generate an svmon summary report for each major MS compoment 
gen_svmon_rept() {
#echo "gen_svmon_rept - entry"

aa1_line=$( ps -ef | grep aa1.properties | grep -v grep)
aa1_pid=$(  echo $aa1_line | cut -d' ' -f2 )

aa2_line=$( ps -ef | grep aa2.properties | grep -v grep)
aa2_pid=$(  echo $aa2_line | cut -d' ' -f2 )

ps1_line=$( ps -ef | grep ps1.properties | grep -v grep)
ps1_pid=$(  echo $ps1_line | cut -d' ' -f2 )

ps2_line=$( ps -ef | grep ps2.properties | grep -v grep)
ps2_pid=$(  echo $ps2_line | cut -d' ' -f2 )

was_line=$( ps -ef | grep server1 | grep -v grep)
was_pid=$(  echo $was_line | cut -d' ' -f2 )

kl1_line=$( ps -ef | grep kl1.properties | grep KernelManager | grep -v grep)
kl1_pid=$(  echo $kl1_line | cut -d' ' -f2 )

gps_line=$( ps -ef | grep 'GpsServer start' | grep -v grep)
gps_pid=$(  echo $gps_line | cut -d' ' -f2 )

# generate the svmon report
#echo "  generate the svmon report date"
svmon_rept=/tmp/$$_ms_svmon.txt
svmon -P -O sortentity=virtual,unit=auto -t300 > $svmon_rept

# get the svmon report for each MS component
# echo "  get the svmon report for each MS component"
aa1_svmon_line=$(grep $aa1_pid $svmon_rept)
aa2_svmon_line=$(grep $aa2_pid $svmon_rept)
ps1_svmon_line=$(grep $ps1_pid $svmon_rept)
ps2_svmon_line=$(grep $ps2_pid $svmon_rept)
was_svmon_line=$(grep $was_pid $svmon_rept)
kl1_svmon_line=$(grep $kl1_pid $svmon_rept)
gps_svmon_line=$(grep $gps_pid $svmon_rept)


# Display the results
echo 
date
echo "Component Pid      Command          Inuse    Pin      Pgsp     Virtual"
echo "aa1       $aa1_svmon_line" 
echo "aa2       $aa2_svmon_line" 
echo "ps1       $ps1_svmon_line" 
echo "ps2       $ps2_svmon_line" 
echo "kl1       $kl1_svmon_line" 
echo "gps       $gps_svmon_line" 
echo "WAS       $was_svmon_line" 

# delete the report
rm -rf $svmon_rept

#echo "gen_svmon_rept - exit"
}

####################
#  M A I N
#################### 
#echo "Executing script $SCRIPTNAME version $SCRIPTVER."

check_root_user
scan_arguments $*

gen_svmon_rept




exit 0
