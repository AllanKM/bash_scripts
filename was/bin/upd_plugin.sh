#!/bin/ksh
 # 

trap "stty echo; exit" 2

GETPLUGIN="/lfs/system/tools/was/bin/export_plugin.sh"
# Usage:    export_plugin.sh [version=<60|61>] [profile=<profilename] <clustername> <clustername2> ... <clusternameN>
PWDEXP="/usr/bin/pwdexp"
VALIDATE="/lfs/system/tools/was/bin/verify_plugin.pl"
MERGE="/lfs/system/tools/was/bin/merge_plugins.sh"

DEV=0

function get_answer {
	unset answer
	while [ -z "$answer" ]; do
		read answer?"$1: "
	done
	print $answer
}

function validate_dmgr {
	# check if it is a server or DNS name supplied
	# if server lssys and see if it has role was.dm.*
	# if DNS get servername using host DMGR or host DMGRmanager

	rc=0
	if print $DMGR | grep -E ^[bgy]z[[:alpha:]]\{1,3\}[[:digit:]]\{2\}[[:alpha:]]\{2\}  >/dev/null 2>&1; then
    #-----------------------------------------------------------------
      # commandline specifies dmgr name need to work out server name
      #----------------------------------------------------------------
      # see is it is defined to DNS
      SERVER=`host ${DMGR}`
      if [ $? -eq 0 ]; then
         SERVER=${SERVER%%.*}
			rc=1
      fi

	else
		#----------------------------------
		# commandline specifies DMGR server
		#----------------------------------
		set -A roles $(lssys -1 -l role $DMGR | awk '{for (i=1;i<=NF;i++) {if ($(i)~/^WAS\.DM.[BGY]/) {print $(i)}}}' | cut -d "." -f3 )
		ans=0
		if [ ${#roles[*]} -gt 1 ]; then
			unset ans
			print "$DMGR has multiple DMGR roles"
			 i=0
			 while [ $i -lt ${#roles[*]} ]; do
				 print "\t$i\t${roles[$i]}"
				 (( i=i+1 ))
			 done
		 print "Select # for DMGR to use"
		 while [ -z "$ans" ]; do
			ans=$(get_answer)
			if [ $ans -ge ${#roles[*]} ] || [ $ans -lt 0 ]; then 
				unset ans
			fi
			if [ -z "$ans" ]; then 
				print "Invalid response"
			fi
		 done
	    fi
		 DMGR=${roles[$ans]}

		if [ ! -z $DMGR ]; then 
			print $DMGR
			SERVER=`host $DMGR 2>/dev/null | head -1 | awk '{print $1}' | cut -d "." -f1`
			if [ ! -z "$SERVER" ]; then
			
				rc=1
			fi
		fi
	fi
	if [ $rc == 0 ]; then
		print -u2 -- "#### Invalid DMGR name: $DMGR"
		unset DMGR
	fi
	return $rc
}

function validate_ihs {

	env=`print $IHS_CLUSTER | cut -c 3-5`
	if [ ! -d /fs/projects/${env}/$IHS_CLUSTER ]; then
		print -u2 -- "#### Invalid IHS cluster"
		unset IHS_CLUSTER
		return 0
	fi
	return 1
}
if [[ $SUDO_USER != "" ]]; then

	print -u2 -- "#### Do not use SUDO when running this script"
	exit 1
fi

zone=$(lssys -1 -l realm -n | cut -d'.' -f1)
if [ "$zone" != "g" ]; then
	print -u2 -- "#### This script must be run from a p3 gz server"
	exit 1
fi
 # Get options 


while [[ $# -gt 0 ]]; do
	if print $1 | grep -E ^[[:alpha:]]\{2\}[[:digit:]]\{4\}[[:alpha:]]\{1\} >/dev/null 2>&1 ; then
		# old style server names
		DMGR=$1

	elif print $1 | grep -E ^[vw]\{1\}[[:digit:]]\{5\}  >/dev/null 2>&1 ; then
		# new style server names
		DMGR=$1

	elif print $1 | grep -E ^[bgy]z[[:alpha:]]\{1,3\}[[:digit:]]\{2\}[[:alpha:]]\{2\}  >/dev/null 2>&1; then
		# dmgr name
		DMGR=$1

	elif print $1 | grep -E ^[bgy]z[[:alpha:]]\{1,3\}cl[[:digit:]]\{3\}  >/dev/null 2>&1 ; then
		# IHS cluster name
		IHS_CLUSTER=$1

	else
		# WAS cluster name
		WAS_CLUSTER=$1
	fi
	shift
done

while [ -z "$WAS_CLUSTER" ]; do 
	WAS_CLUSTER=$(get_answer "Name of the WAS application cluster" )
done

while [ -z "$DMGR" ] || validate_dmgr ; do
	DMGR=$(get_answer "Which DMGR manages the cluster ")
done

while [ -z "$IHS_CLUSTER" ] || validate_ihs; do
	typeset -l IHS_CLUSTER=$(get_answer "Name of the IHS cluster" )
done

SERVER=`print $SERVER | sed -e s/[[:alpha:]][[:digit:]]$//1`;

# ========================================================================
# check DMGR and IHS clusters match ie environments are at least the same
# ========================================================================
if print $DMGR | grep -Ei ^[bgy]z[[:alpha:]][[:digit:]]\{2\}[[:alpha:]]\{2\}; then
	ENV=`print $DMGR | cut -c 3`
	version=`print $DMGR | cut -c 4-5`;
	case $ENV in
	P) ENV="PRD" ;;
	S) ENV="PRE" ;;
	T) ENV="CDT" ;;
	*) ENV="UNKNOWN";;
	esac
else
	ENV=`print $DMGR | cut -c 3-5`
	version=`print $DMGR | cut -c 6-7`;
fi
typeset -l ENV=$ENV

if ! print $IHS_CLUSTER | grep -i $ENV 2>&1 1>/dev/null; then
	print -u2 -- "#### DMGR and IHS Cluster environments do not match check this is correct dmgr for the plugin"
	exit 1
fi

print "Generating $WAS_CLUSTER plugin from dmgr $DMGR on $SERVER for Webserver $IHS_CLUSTER"

# Find zone for dmgr and prompt for password
ZONE=$(lssys -1 -l realm $SERVER | awk -F'.' '{print $1}')

case $ZONE in
	b) ZONE="Blue" ;;
	g) ZONE="Green" ;;
	y) ZONE="Yellow" ;;
	*) ZONE="Invalid";;
esac
valid_pw=0
count=0
while [ $valid_pw -lt 1 ] && [ $count -lt 3 ]; do
	while [ -z "$in_passwd" ]; do
		 stty -echo
		in_passwd=$(get_answer "Enter your $ZONE zone password")
		stty echo
		
	done
	print -u2 -- "Validating password"
	unset DISPLAY
	rm -f /tmp/.dssh_known_hosts.$USER >/dev/null 2>&1
	rm -f /tmp/.empty_sshkey.$USER >/dev/null 2>&1
   print PubkeyAuthentication=no > /tmp/.empty_sshkey.$USER
   if [ "$DEV" != "1" ]; then
   	OKAY=$(echo "$in_passwd" |$PWDEXP /usr/bin/ssh -v -t -l $USER -F /tmp/.empty_sshkey.$USER -o NumberOfPasswordPrompts=1 -o UserKnownHostsFile=/tmp/.dssh_known_hosts.$USER -o strictHostKeyChecking=no $SERVER pwd )   	
   fi
	if [ $? -ne 0 ]; then
		print -u2 -- "#### Invalid password"
		unset in_passwd
		let "count=$count+1"
	else
		valid_pw=1
	fi
done
print -u2 -- "Generating plugin on $SERVER"
typeset -l dmgr="${DMGR}"
profile="${dmgr}Manager"
if [ "$DEV" != "1" ]; then
	print $in_passwd | $PWDEXP -t 60 -T 60 -d 1 /usr/bin/ssh -t -t -o NumberOfPasswordPrompts=1 -o strictHostKeyChecking=no -l $USER $SERVER sudo  $GETPLUGIN version=$version profile=$profile $WAS_CLUSTER 2>&1 | grep -vi "debug:"
else
	sleep 3
fi
mkdir /tmp/$USER 1>/dev/null 2>&1
NEWXML=/tmp/$USER/${WAS_CLUSTER}_plugin-cfg.xml

print -u2 -- "Retrieving plugin"
if [ "$DEV" != "1" ]; then
	print $in_passwd | $PWDEXP -t 35 -T 35 /usr/bin/scp -o NumberOfPasswordPrompts=1 -o strictHostKeyChecking=no  $USER@$SERVER:/tmp/${WAS_CLUSTER}_plugin-cfg.xml $NEWXML
else
	cp /root/tmp/${WAS_CLUSTER}_plugin-cfg.xml $NEWXML
	sleep 3
fi

if [ ! -f "$NEWXML" ]; then
	print "Plugin generation failed"
	exit 1
fi

# now have a local copy of the plugin data
# determine which plex it is for by looking at the servers defined in it
set -A plex $(grep -i hostname $NEWXML | awk '{ gsub(/dt/,"v2");gsub(/at/,"v1");gsub(/gt/,"v3"); split($0,a,"Hostname=\""); print substr(a[2],0,2) }' | sort -u)
if [ ${#plex[*]} -gt 1 ]; then
   print -u2 -- "#### Cluster is configured for multiple plexes, please handle updates manually"
   print -u2 -- "#### exported xml is $NEWXML"
   exit

else
	case ${plex[0]} in
		*1|at )
			plex=p1
			;;
		*2|dt )
			plex=p2
			;;
		*3|gt )
			plex=p3
			;;
		*5 )
			plex=p5
			;;

		*) print -u2 -- "#### Unable to determine which plex this plugin is for"
			print -u2 -- "\tupdate will need to be handled manually\n"
			exit;
		;;
	esac
fi

print "Plugin is for $plex plex"
OLDXML=plugin-cfg.xml.$plex
# checkout the affected master plugin
cd /fs/projects/$env/$IHS_CLUSTER/HTTPServer/conf


if ! rlog -L -R -l${USER} RCS/* | grep -q "$OLDXML"  ; then
	print "Checking out $OLDXML from RCS"
	co -l $OLDXML
fi
if [ -w $OLDXML ]; then
	cp $OLDXML /tmp/$USER/
else
	print -u2 -- "#### Failed to checkout master plugin file $OLDXML, ensure file is not locked by another user"
	exit 1
fi
 
cd /tmp/$USER
chown $USER *
chmod 755 *
print $MERGE $OLDXML $NEWXML
$MERGE $OLDXML $NEWXML

$VALIDATE merged_${OLDXML} $IHS_CLUSTER


while [ -z "$answer" ] ; do
		  read answer?"Check updated file into RCS or \"e\" to edit it ? (y/n/e): "
	if [ "$answer" == "e" ]; then
		vi merged_${OLDXML}
		$VALIDATE merged_${OLDXML} $IHS_CLUSTER
		answer=""
	elif [ "$answer" != "y" ] && [ "$answer" != "n" ]; then
		print "$answer is an invalid response"
		answer=""
	fi
done

if [ "$answer" == "y" ]; then
	cd /fs/projects/$env/$IHS_CLUSTER/HTTPServer/conf
	cp /tmp/$USER/merged_${OLDXML} ${OLDXML}
	ci -u ${OLDXML}
else
	print -u2 -- "/tmp/$USER/merged_${OLDXML} failed validation, RCS check in aborted"
	cd /fs/projects/$env/$IHS_CLUSTER/HTTPServer/conf
	ci -u ${OLDXML}
fi
