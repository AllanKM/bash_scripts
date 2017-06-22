#!/bin/ksh
#----------------------------------------------------------------
# take backup of dp domain, scp to local and mv to 
# /projects/espre/content/datapower/backups
#----------------------------------------------------------------
me=${0##.*\/}

if [ -z "$1" ]; then
	print "Syntax: $me <dp_device1> <dp_device2> ... <dp_devicen>"
	print "\tor $me ivt"
	print "\tor $me prd"
	print "\tor $me ivt prd"
	print "\tor $me ivt <dp_device>"
	exit
fi

if [[ $SUDO_USER != "" ]]; then
	print "Don't use sudo with this script\n";
	exit
fi
date=$(date +'%Y%m%d')
eiuser=$(whoami)
# get intranet id
user=$(dsls -l mail -e person uid==${eiuser} | grep mail | awk '{print $3}')

srv=$(lssys -l hostenv -x csv -e role==datapower custtag==esc nodestatus==live )

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
	if print $srv | grep -q $1 ; then
		backup="$backup $1"
	elif [ "$1" = "ivt" ] || [ "$1" = "pre" ]; then
		for dp in $srv; do
			if [[ $dp = *PRE ]]; then
				dp=${dp%,*}
				backup="$backup $dp"
			fi
		done
	elif [ "$1" = "prd" ]; then
		for dp in $srv; do
			if [[ $dp = *PRD ]]; then
				dp=${dp%,*}
				backup="$backup $dp"
			fi
		done
	else
		print "$1 is not a valid datapower device name"
	fi
	shift
done
if [ -z "$backup" ]; then
	print "No valid backups requested"
	exit
fi

#=============================================
# Prompt for intranet password
#=============================================
trap "stty echo && exit" 2
if [ -z "$intranet_pw" ]; then
	date=`date +"%Y%m%d"`
	print -n "Enter password for ${user}: " >&2
	# Disable character echo to hide password during entry
	stty -echo
	read intranet_pw
	# Reenable character echo
	stty echo
	print "" >&2
fi

#=============================================
# Prompt for ei server password
#=============================================
if [ -z "$yzpw" ]; then
	print -n "Enter Yellow zone password: " >&2
	# Disable character echo to hide password during entry
	stty -echo
	read yzpw
	# Reenable character echo
	stty echo
	print "" >&2
fi

set -- $(print $backup)
while [ -n "$1" ]; do
	dp=$1
	if [[ "$srv" = *"$1,PRD"* ]]; then
		domain="support_websvc_eci_prod"
	else
		domain="support_websvc_eci_ivt"
	fi
	#==============================================
	# ssh to the dp and perform the backup
	#==============================================
	cat <<EOF | ssh $dp
$user
$intranet_pw
$domain
top
co
backup ${dp}_backup_$date.zip 
copy export:///${dp}_backup_$date.zip scp://$eiuser@$myip/${dp}_backup_$date.zip
$yzpw
delete export:///${dp}_backup_$date.zip
exit
EOF

	#====================================================
	# move the backup to the datapower backup dir
	#====================================================
	if [ -e ~/${dp}_backup_$date.zip ];then
		print $yzpw | /usr/bin/pwdexp -v sudo mv ~/${dp}_backup_$date.zip /projects/espre/content/datapower/backups/
		print "${BLUE}============================================================${RESET}"
		print "${BLUE}= $dp backup complete${RESET}"
		print "${BLUE}============================================================${RESET}"
	else
		print "${RED}#### Backup failed for $dp${RESET}"
		print "${RED}#### aborting backups, check correct passwords used and try again ${RESET}"
		exit
	fi
	shift
done
