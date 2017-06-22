#!/bin/ksh

PWDEXP="/usr/bin/pwdexp"
USER=$(whoami)
HOST=`/bin/hostname -s`

getRoles() {
	# Try the live dirstore first, then fall back to using /usr/local/etc/nodecache
	ROLES=$(lssys -lrole ${HOST} | grep role | cut -d= -f2 | tr -d ';')
	if [ "$ROLES" == "" ]; then
		ROLES=$(grep role /usr/local/etc/nodecache | cut -d= -f2 | tr -d ';')
	elif [ "$ROLES" == "" ]; then
		print -u2 -- "#### No roles found in /usr/local/etc/nodecache or by quering the dirstore"
	else
		echo "node roles: $ROLES"
	fi
}


getPlex() {
	#Determine if this node is located in p1, p2 or p3 by looking in /etc/resolv.conf
	set -- $(grep search /etc/resolv.conf)

	while [[ "$1" != "" ]]; do
		if [[ "$1" = [bgy].*.p?.event.ibm.com ]] 
	 	then
  			PLEX=`echo "$1" | cut -d. -f3`
		fi
    	shift
	done
	if [ "$PLEX" == "" ]; then
		print -u2 -- "#### Unable to determine environment form /etc/resolv.conf"
	else
		echo "$PLEX"
	fi
}


getZone() {
	#Determine if this node is located in yellow, green or blue zone by looking in /etc/resolv.conf
	set -- $(grep search /etc/resolv.conf)

	while [[ "$1" != "" ]]; do
		if [[ "$1" = [bgy].*.p?.event.ibm.com ]] 
	 	then
  			ZONE=`echo "$1" | cut -d. -f1`
		fi
    	shift
	done
	if [ "$ZONE" == "" ]; then
		print -u2 -- "#### Unable to determine zone form /etc/resolv.conf"
	else
		echo "$ZONE"
	fi
}

getEnv() {
	#Determine if this node is located in staging, production, cs or ci by looking in /etc/resolv.conf
	set -- $(grep search /etc/resolv.conf)

	while [[ "$1" != "" ]]; do
		if [[ "$1" = [bgy].*.p?.event.ibm.com ]] 
	 	then
  			ENV=`echo "$1" | cut -d. -f2`
		fi
    	shift
	done
	if [ "$ENV" == "" ]; then
		print -u2 -- "#### Unable to determine environment form /etc/resolv.conf"
	else
		echo "$ENV"
	fi
}

get_zone_server() {
	zone=`echo $1 | cut -c 1`
	plex=$(getPlex)
	server=`lssys -q -e role==nfs* nodestatus==live realm==$zone.*.$plex | head -1`
	if [ ! -z "$server" ]; then
		echo "$server"
	else
		print -u2 -- "#### Unable to find server to verify password" 1>&2
		exit
	fi
}

get_y_passwd() {
		  server=$(get_zone_server Yellow\ Zone)
        y_passwd=$(get_passwd $server Yellow\ Zone)
        if [ $? -ne 0 ] 
        then
                exit 1
        fi
}

get_g_passwd() {
		  server=$(get_zone_server Green\ Zone)
        g_passwd=$(get_passwd $server Green\ Zone)
        if [ $? -ne 0 ] 
        then
                exit 1
        fi
}

get_b_passwd() {
		  server=$(get_zone_server Blue\ Zone)
        b_passwd=$(get_passwd $server Blue\ Zone)
        if [ $? -ne 0 ] 
        then
                exit 1
        fi
}

get_passwd() {
        host=$1
        zone=$2
        trap 'stty echo && exit' INT
        stty -echo
        read in_passwd?"Enter your $zone password: "
        stty echo
        print ""
        if [[ "$in_passwd" = "" ]]
        then
        print "Error: no password entered"
        exit 1
        fi
        unset DISPLAY
        rm -f /tmp/.dssh_known_hosts.$USER >/dev/null 2>&1 
        rm -f /tmp/.empty_sshkey.$USER >/dev/null 2>&1 
        print PubkeyAuthentication=no > /tmp/.empty_sshkey.$USER 

        OKAY=$(echo "$in_passwd" |$PWDEXP /usr/bin/ssh -v -t -l $USER -F /tmp/.empty_sshkey.$USER -o NumberOfPasswordPrompts=2 -o UserKnownHostsFile=/tmp/.dssh_known_hosts.$USER -o strictHostKeyChecking=no $host pwd > /dev/null)
        if [ $? -ne 0 ]
        then
        print -u2 -- "###$zone password entered not correct for $USER"
        exit 1
        fi
		  print -u2 -- "Password accepted"
        print $in_passwd
}

