#!/bin/ksh

#------------------------------------------------------------------------------------------------------
# This script is for customers to use on CDT environments to enable them to update the
# websphere plugin config for themselves. It requires that they have SUDO rights to execute 
# this script on the WebServer and also SUDO rights to execute export_plugin.sh on the DMGr
#
# It expects 2 parameters, the DMGR name or servername, and the WAS cluster to be updated
#
# e.g. sudo upd_cdt_plugin.sh gzcdt61wiibm cdt_cluster_ibm_dynamicnav
# or  upd_cdt_plugin.sh w20064 cdt_cluster_ibm_dynamicnav
#------------------------------------------------------------------------------------------------------
# 
#----------------------------------------------------
# trap ctrl-c and re-enable echoing of input
#----------------------------------------------------
trap "stty echo; exit" 2

GETPLUGIN="/lfs/system/tools/was/bin/export_plugin.sh"
PWDEXP="/usr/bin/pwdexp"
VALIDATE="/lfs/system/tools/was/bin/verify_plugin.pl"
MERGE="/lfs/system/tools/was/bin/merge_plugins.sh"

DEV=0

#------------------------------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------------------------------
function get_answer {
	unset answer
	while [ -z "$answer" ]; do
		read answer?"$1: "
	done
	print $answer
}

#------------------------------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------------------------------
function validate_dmgr {
	# check if it is a server or DNS name supplied
	# if server lssys and see if it has role was.dm.*
	# if DNS get servername using host DMGR or host DMGRmanager

	rc=0
	if print $DMGR | grep -E ^[bgy]z[[:alpha:]]\{1,3\}[[:digit:]]\{2\}[[:alpha:]]\{2\}  >/dev/null 2>&1; then
		#----------------------------------
		# commandline specifies dmgr name
		#----------------------------------
		LSS=`lssys -x csv -l role -e role==WAS.DM.${DMGR}* | grep -v \#`
		if print $LSS | grep WAS.DM >/dev/null 2>&1; then
			SERVER=`print $LSS | cut -d "," -f 1`
			rc=1
		fi
	else
		#----------------------------------
		# commandline specifies DMGR server
		#----------------------------------
		DMGR=$(lssys -1 -l role $DMGR | awk '{for (i=1;i<=NF;i++) {if ($(i)~/^WAS\.DM.[BGY]/) {print $(i)}}}' | cut -d "." -f3 )
		if [ ! -z $DMGR ]; then 
			print $DMGR
			SERVER=`host $DMGR 2>/dev/null | head -1 | awk '{print $1}' | cut -d "." -f1`
			if [ ! -z "$SERVER" ]; then
				rc=1
			fi
		fi
	fi
	if [ $rc == 0 ]; then
		print -u2 -- "#### Invalid DMGR name"
		unset DMGR
	fi
	return $rc
}

#------------------------------------------------------------------------------------------------------
#
#------------------------------------------------------------------------------------------------------
function validate_ihs {
	env=`print $IHS_CLUSTER | cut -c 3-5`
	if [ ! -d /fs/projects/${env}/$IHS_CLUSTER ]; then
		print -u2 -- "#### Invalid IHS cluster"
		unset IHS_CLUSTER
		return 0
	fi
	return 1
}

#------------------------------------------------------------------------------------------------------
# Main code starts here
#------------------------------------------------------------------------------------------------------
if [[ $SUDO_USER != "" ]]; then

	#-----------------------------------------------------------------
	# check running on a CDT webserver
	#-----------------------------------------------------------------
	if ! lssys -l role -n | grep -qi webserver\.cluster\.[y,b]zcdtcl; then
		print -u2 -- "This script cannot be run on this server, it willl only execute on a CDT webserver"
		exit 1
	fi

   #get IHS cluster name
	# 
	typeset -l IHS_CLUSTER=`lssys -l role -n | grep role | awk '{ for (i=3;i<=NF;i++) { if ( $(i)~/WEBSERVER.CLUSTER/ ) { print $(i) } } }' | tr -d ";" | cut -d "." -f 3`

	#-------------------------
	# Get commandline options 
	# 	dmgr name
	# 	IHS cluster name
	#	app name
	#-------------------------
	while [[ $# -gt 0 ]]; do
		if print $1 | grep -E ^[[:alpha:]]\{2\}[[:digit:]]\{4\}[[:alpha:]]\{1\} >/dev/null 2>&1 ; then
			# old style server names e.g at0906a
			DMGR=$1

		elif print $1 | grep -E ^[vw]\{1\}[[:digit:]]\{5\}  >/dev/null 2>&1 ; then
			# new style server names e.g v20064 
			DMGR=$1

		elif print $1 | grep -E ^[bgy]z[[:alpha:]]\{1,3\}[[:digit:]]\{2\}[[:alpha:]]\{2\}  >/dev/null 2>&1; then
			# dmgr name e.g gzcdt61wi
			DMGR=$1

		else
			# WAS cluster name whats left must be the app name
			WAS_CLUSTER=$1
		fi
		shift
	done
 
	#---------------------------------------------------------------
	# If required fields still empty then prompt for them
	#---------------------------------------------------------------
	while [ -z "$WAS_CLUSTER" ]; do 
		WAS_CLUSTER=$(get_answer "Name of the WAS application cluster" )
	done

	while [ -z "$DMGR" ] || validate_dmgr ; do
		DMGR=$(get_answer "Which DMGR manages the cluster ")
	done

	while [ -z "$IHS_CLUSTER" ] || validate_ihs; do
		typeset -l IHS_CLUSTER=$(get_answer "Name of the IHS cluster" )
	done

	#-----------------------------------------
	# SERVER is DMGR servername
	#-----------------------------------------
	SERVER=`print $SERVER | sed -e s/[[:alpha:]][[:digit:]]$//1`;

	# ========================================================================
	# check DMGR and IHS clusters match ie environments are at least the same
	# ========================================================================
	if print $DMGR | grep -Ei ^[bgy]z[[:alpha:]][[:digit:]]\{2\}[[:alpha:]]\{2\}; then
		ENV=`print $DMGR | cut -c 3`
		case $ENV in
			P) ENV="PRD" ;;
			S) ENV="PRE" ;;
			T) ENV="CDT" ;;
			*) ENV="UNKNOWN";;
		esac
	else
		ENV=`print $DMGR | cut -c 3-5`
	fi
	typeset -l ENV=$ENV
	
	if [ "$ENV" != "cdt" ]; then
		print -u2 -- "#### This script may only be used on CDT environments"
		exit
	fi

	if ! print $IHS_CLUSTER | grep -i $ENV 2>&1 1>/dev/null; then
		print -u2 -- "#### DMGR and IHS Cluster environments do not match check this is correct dmgr for the plugin"
		exit 1
	fi

	plugin_file=$(grep -iE "^[[:space:]]*webspherepluginconfig" /projects/HTTPServer/conf/httpd.conf | awk '{print $2}')

	while [ -L "$plugin_file" ]; do
		plugin_file=$(ls -l /projects/HTTPServer/conf/plugin-cfg.xml | awk '{print $(NF)}')
	done
	print "Using $plugin_file"

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
		rm -f /tmp/.dssh_known_hosts.$SUDO_USER >/dev/null 2>&1
		rm -f /tmp/.empty_sshkey.$SUDO_USER >/dev/null 2>&1
		print PubkeyAuthentication=no > /tmp/.empty_sshkey.$SUDO_USER
		if [ "$DEV" != "1" ]; then
			OKAY=$(echo "$in_passwd" |$PWDEXP /usr/bin/ssh -v -t -l $SUDO_USER -F /tmp/.empty_sshkey.$SUDO_USER -o NumberOfPasswordPrompts=1 -o UserKnownHostsFile=/tmp/.dssh_known_hosts.$SUDO_USER -o strictHostKeyChecking=no $SERVER pwd )   	
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
	if [ "$DEV" != "1" ]; then
		print $in_passwd | $PWDEXP -t 60 -T 60 -d 1 /usr/bin/ssh -t -t -o NumberOfPasswordPrompts=1 -o strictHostKeyChecking=no -l $SUDO_USER $SERVER sudo  $GETPLUGIN $WAS_CLUSTER 2>&1 | grep -vi "debug:"
	else
		sleep 3
	fi
	mkdir /tmp/$SUDO_USER 1>/dev/null 2>&1
	NEWXML=/tmp/$SUDO_USER/${WAS_CLUSTER}_plugin-cfg.xml

	print -u2 -- "Retrieving plugin"
	print $in_passwd | $PWDEXP -t 35 -T 35 /usr/bin/scp -o NumberOfPasswordPrompts=1 -o strictHostKeyChecking=no  $SUDO_USER@$SERVER:/tmp/${WAS_CLUSTER}_plugin-cfg.xml $NEWXML

	if [ ! -f "$NEWXML" ]; then
		print "Plugin generation failed"
		exit 1
	fi

	OLDXML=$plugin_file

	cd /tmp/$SUDO_USER
	chown $SUDO_USER *
	chmod 755 *
	print $MERGE $OLDXML $NEWXML
	$MERGE $OLDXML $NEWXML
	print "Validating"
	merged_xml="merged_${OLDXML##/*/}"
	$VALIDATE $merged_xml $IHS_CLUSTER


	while [ -z "$answer" ] ; do
			  read answer?"Deploy updated plugin_file or \"e\" to edit it ? (y/n/e): "
		if [ "$answer" == "e" ]; then
			vi $merged_xml
			$VALIDATE $merged_xml $IHS_CLUSTER
			answer=""
		elif [ "$answer" != "y" ] && [ "$answer" != "n" ]; then
			print "$answer is an invalid response"
			answer=""
		fi
	done

	if [ "$answer" == "y" ]; then
		cp /tmp/$SUDO_USER/$merged_xml ${OLDXML}
		diff /fs/projects/cdt/$IHS_CLUSTER/HTTPServer/conf/${OLDXML##/*/}  /tmp/$SUDO_USER/$merged_xml >/dev/null
		if [ $? -gt 0 ]; then
			print "####################################################################"
			print "# Warning: the current config contains changes that are not in the #"
			print "# master config. These changes will be lost if EI apps team        #"
			print "# redeploy from the master config.                                 #"
			print "####################################################################"
		fi
		print "\n\nRestart IHS to activate the new plugin config\n\n"
	fi
else
	print -u2 -- "#### This script requires the use of SUDO"
	exit 1
fi
