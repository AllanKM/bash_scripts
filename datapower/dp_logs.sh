#!/bin/ksh
#=========================================================================
# copy default-log and domain/default-log to home dir
#=========================================================================
rm -f ~/p*dpa0*.log

me=${0##.*\/}


if [ -z "$1" ]; then
	print "Syntax: $me <dp_device1> <dp_device2> ... <dp_devicen>"
	print "\tor $me ivt"
	print "\tor $me prd"
	print "\tor $me ivt prd"
	print "\tor $me ivt <dp_device>"
	exit
fi

date=$(date +'%Y%m%d')
eiuser=$(whoami)
user=$(dsls -l mail -e person uid==${eiuser} | grep mail | awk '{print $3}')

myip=$(ifconfig -a | grep inet | head -n 1 | cut -f 2 -d' ')
#---------------------------------------------------------
# color codes
#---------------------------------------------------------
BLACK="\033[30;1;49m"
RED="\033[31;1;49m"
GREEN="\033[32;1;49m"
YELLOW="\033[33;1;49m" 
BLUE="\033[34;49;1m"
MAGENTA="\033[35;49;1m"
CYAN="\033[36;49;1m"
WHITE="\033[37;49;1m"
RESET="\033[0m"

while [ -n "$1" ]; do
	if [[ $1 = p[1-3]dpa0[1-2] ]]; then
		backup="$backup $1"
	elif [[ $1 = p2dpa0[3-4] ]]; then
		backup="$backup $1"
	elif [ "$1" = "ivt" ]; then
		backup="$backup p2dpa03 p2dpa04"
	elif [ "$1" = "prd" ]; then
		backup="$backup p1dpa01 p1dpa02 p2dpa01 p2dpa02 p3dpa01 p3dpa02"
	else
		print "$1 is not a valid datapower device name"
	fi
	shift
done

if [ -z "$backup" ]; then
	print "No valid backups requested"
	exit
fi

trap "stty echo && exit" 2
#=============================================
# Prompt for intranet password
#=============================================
if [ -z "$intranet_pw" ]; then
	date=`date +"%Y%m%d"`
	print -n "Enter password for ${user}: "
	# Disable character echo to hide password during entry
	stty -echo
	read intranet_pw
	# Reenable character echo
	stty echo
	print ""
fi

#=============================================
# Prompt for ei server password
#=============================================
if [ -z "$yzpw" ]; then
	print -n "Enter Yellow zone password: "
	# Disable character echo to hide password during entry
	stty -echo
	read yzpw
	# Reenable character echo
	stty echo
	print ""
fi

set -- $(print $backup)
while [ -n "$1" ]; do
	dp=$1
	if [[ "$1" = p[1-3]dpa0[1-2] ]]; then
		domain="support_websvc_eci_prod"
	elif [[ "$1" = p2dpa0[3-4] ]]; then
		domain="support_websvc_eci_beta"
	else
		print "dunno how $dp slipped thru, but I dont know the domain for that"
		shift
		continue
	fi
	#==============================================
	# ssh to the dp and perform the backup
	#==============================================
	cat <<EOF | ssh $dp
$user
$intranet_pw
default
top
co
copy logtemp:///default-log scp://$eiuser@${myip}/${dp}_default-log_$date.log
$yzpw
copy logtemp:///${domain}/default-log scp://$eiuser@${myip}/${dp}_${domain}_default-log_$date.log
$yzpw
exit
EOF
	print ""
	shift
done
