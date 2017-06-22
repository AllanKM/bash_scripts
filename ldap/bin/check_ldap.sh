#!/bin/ksh

# need to be sudo or root to run this
if [[ $SUDO_USER == "" && $USER != "root" ]]; then
	print -u2 -- "This script requires root privileges, use sudo or su to root"
	exit 16
fi

BLACK="\033[30;1;49m"
RED="\033[31;1;49m"
GREEN="\033[32;1;49m"
YELLOW="\033[33;3;49m"
BLUE="\033[34;49;1m"
MAGENTA="\033[35;49;1m"
CYAN="\033[36;49;1m"
WHITE="\033[37;49;1m"
RESET="\033[0m"
[ -f debug_check_ldap ] && debug=1 

credfile='/lfs/system/tools/ldap/etc/check_ldap.conf'

function sslpw {
	zone=$1
	pass=$(grep -i ssl_$zone $credfile )
	if [ -n "$pass" ]; then
		pass=${pass#*:}
		pass=$(print $pass | /usr/local/bin/perl -ne 'use MIME::Base64; print decode_base64($_);' )
		print $pass
	else
		print "${RED} no stored password for $zone ssl keystore${RESET}"
		exit 16
	fi
}

function get_ssl_settings {
	zone=$(grep -i ^realm /usr/local/etc/nodecache | sed -e 's/.*= //' -e 's/\..*//' )
	debug "zone=$zone"
	case $zone in
		g) zone='green'
			;;
		y) zone='yellow' 
			;;
		b) zone='blue' ;;
	esac
	debug "zone=$zone"
	sslkeypass=$( sslpw $zone)
	sslkeyfile=/etc/security/ldap/ei_${zone}_ldap_client.kdb
}

#-------------------------------------------------------------------------------------------------------
# check ldap instances are active
#-------------------------------------------------------------------------------------------------------

#-------------------------------------------------------------------------------------------------------
# Helper functions
#-------------------------------------------------------------------------------------------------------
function debug {
	msg=$@
	[ -n "$debug" ] && print -u2 -- "${CYAN}$msg${RESET}"
}

function check_processes {
	process=$1
	unset slapd
	unset diradm
	debug "looking for processes $process"
	ps -ef | grep $process | grep -iE "ibmslapd|ibmdiradm" | grep -v grep | {
		while read line; do
			case $line in
				*ibmdiradm* ) diradm=1;;
				*ibmslapd* ) slapd=1;;
			esac
		done
	}
	[ -n "$diradm" ] && printf --  "%30s %s\n" "$process Admin Server" ": Running" || print -- "${RED}#### $process Admin Server: Not running${RESET}"
	[ -n "$slapd" ] && printf -- "%30s %s\n" "$process LDAP Server" ": Running" || print -- "${RED}#### $process LDAP Server: Not running${RESET}" 
}

#-------------------------------------------------------------------------------------------------------
# Do a ldapsearch
#-------------------------------------------------------------------------------------------------------
function search {
	type=$1
	shift
	typeset var parms=$@
	unset connected
	unset badcreds
	configmode=1
	

	if [ -z "$starttime" ]; then
		debug ldapsearch $parms  -s base -b cn=monitor objectclass=* 
		ldapsearch $parms -s base -b cn=monitor objectclass=*  2>&1 | {
		while read line; do
			case $line in 
			*credentials* )
				print "${RED}Stored credentials are incorrect, further testing skipped${RESET}"
				badcreds=1
				return
			;;
			*directoryversion* ) 
				version=${line##*=}
				printf "%30s : %s\n" "Version" $version
				;;

			*starttime* ) 
				starttime=${line##*=}
				starttime=$(print $starttime | sed -e 's/T/ /' | sed -e 's/\.[0-9][0-9][0-9][0-9][0-9].*$//' )
				printf "%30s : %s %s UTC\n" "Up since" $starttime
			;;
			*totalconnections* )
				value=${line##*=}
				printf "%30s : %s %s\n" "Total connections" $value
			;;
			*total_ssl_connections* )
				value=${line##*=}
				printf "%30s : %s %s\n" "Total SSL connections" $value
			;;
			*total_tls_connections* )
				value=${line##*=}
				printf "%30s : %s %s\n" "Total TLS connections" $value
			;;
			*currentconnections* )
				value=${line##*=}
				printf "%30s : %s %s\n" "Current connections" $value
			;;
			esac
		done
	}
	fi
	printf  "%30s %s" "$type connections" ": "
	debug ldapsearch $parms  -s base objectclass=* ibm-slapdisconfigurationmode
	ldapsearch $parms -s base objectclass=* ibm-slapdisconfigurationmode 2>&1 | {
		while read line; do
			
			if [[ "$line"  = *credentials* ]]; then
				print "${RED}Stored credentials are incorrect, further testing skipped${RESET}"
				badcreds=1
				return
			fi
			if [[ "$line" = *ibm-slapdisconfigurationmode* ]]; then
				connected=1
				debug $line
				[[ "$line" = *FALSE* ]] &&	unset configmode
			fi
		done
		debug "connected: $connected   configmode: $configmode"
		if [ -n "$configmode" ]; then
				print "${RED}Failed - Config mode only${RESET}"
		elif [ -z "$connected" ]; then
			print "${RED}Failed${RESET}"
		else
				print "OK"
		fi
	}
}
#-------------------------------------------------------------------------------------------------------
# Check server responds to ldap requests
#-------------------------------------------------------------------------------------------------------
function check_requests {
	[ -n "$ldap_parms" ] && search LDAP $ldap_parms
	[ -n "$badcreds" ] && return
	[ -n "$ldaps_parms" ] && search LDAPS $ldaps_parms
}

#-------------------------------------------------------------------------------------------------------
# Check replication is working
#-------------------------------------------------------------------------------------------------------
function check_replication {
	[ -n "$badcreds" ] && return
	if [ -n "$configmode" ]; then 
		print "Replication not active in config only mode"
		return
	fi 
	[ -n "$ldap_parms" ] && parms=$ldap_parms || parms=$ldaps_parms
	
	debug ldapsearch $parms -b "$base" -s sub ibm-replicaserverid=$serverid dn
	ra=$(ldapsearch $parms -b "$base" -s sub ibm-replicaserverid=$serverid dn)
	if [ -n "$ra" ]; then
		printf "%30s %s\n" "replication status " " "
		

		typeset -l line
		ldapsearch $parms  -b "$ra" "objectclass=ibm-replicationagreement" ibm-replicationstate ibm-replicationpendingchangecount ibm-replicationLastResult ibm-replicaURL ibm-replicationonhold | {
			while read line; do
				debug $line
				if [[ $line = "ibm-replicationonhold=true" ]]; then
					held="true"
					print -u2 -- "$RED#### Replication has been suspended by administrator action$RESET"
				elif [[ "$line" = "ibm-replicaurl="* ]]; then 
					debug ">>>>>>> $line"
					url=$line
				elif [[ "$line" = "ibm-replicationstate="* ]]; then
					state=${line##*=}
					[[ "$state" != "ready" ]] && print -u2 -- "$RED#### Replication is not in ready state$RESET"
	
				elif [[ "$line" = "ibm-replicationpendingchangecount="* ]]; then
					count=${line##*=}
					[ $count -gt 0 ] && print -u2 -- "$RED#### Replication has $count updates queued$RESET"
			
				elif [[ "$line" = "ibm-replicationlastresult="* ]]; then
					set -- $(print $line)
					failedid=$2
					error=$3
					debug "id: $failedid error: $error"
				elif [ -z "$line" ]; then
					debug "state: $state url: $url count: $count held: $held"
					to=${url#*://}
					to=${to%%\.*}
					printf "%30s %s" "To $to" ": "
					if [ "$held" = "true" ] || [ $count -gt 0 ] || [ "$state" != "ready" ]; then 
						print "Failed"
					else
						print "OK"
					fi 
				fi
			done
			to=${url#*://}
			to=${to%%\.*}
			printf "%30s %s" "To $to" ": "
			if [ "$held" = "true" ] || [ $count -gt 0 ] || [ "$state" != "ready" ]; then 
				print "Failed"
			else
				print "OK"
			fi
		}
	else
		print "\tNot part of a replication group"
	fi
}
#-------------------------------------------------------------------------------------------------------
# Read ibmslapd.conf for relevant info
# ldap port
# ldaps port
# serverid
#-------------------------------------------------------------------------------------------------------
function get_ldap_settings {
	instance=$1
	name=${instance#*idsslapd-}
	name=${name%/etc*}
	typeset -l line
	while read line; do
			if [[ "$line" = "dn: "* ]]; then
      		if [[ "$line" = "dn: cn=ssl"* ]]; then
         		gotstanza=1
         	elif [[ "$line" = "dn: cn=configuration"* ]]; then
         		gotstanza=1
      		else
         		unset gotstanza
      		fi
      	elif [[ "$line" = "ibm-slapdsecureport:"* && -n "$gotstanza" ]]; then
      		ldaps_port=$(set -- $line; print $2)
   		elif [[ "$line" = "ibm-slapdport:"* && -n "$gotstanza" ]]; then
      		ldap_port=$(set -- $line; print $2)
   		elif [[ "$line" = "ibm-slapdipaddress:"* ]]; then
      		host=$( set -- $line; print $2 )
   		elif [[ "$line" = "ibm-slapdserverid:"* ]]; then
      		serverid=$( set -- $line; print $2 )
      	elif [[ "$line" = "ibm-slapdallowanon:"* ]]; then
      		allowanon=$( set -- $line; print $2 )
      	elif [[ "$line" = "ibm-slapdsecurity:"* ]]; then
      		security=$( set -- $line; print $2 )
   		fi
   		
         if [[ "$line" = *"ibm-slapdsuffix:"* ]] then
              if [[ "$line" = *@(localhost|ibmpolicies|deleted objects) ]]; then
                   continue
              else
                  base=${line#*: }
                  base=$(print $base | sed -e 's/, */,/g')
              fi
         fi
	done < $instance/etc/ibmslapd.conf
	debug "name: $name\nallowanon: $allowanon\nldap_port: $ldap_port\nldaps_port: $ldaps_port\nhost: $host\nserverid: $serverid\nbase: $base\nsecurity: $security"

	#----------------------------------------------------------------
	# get id/pw
	#----------------------------------------------------------------
	creds=$(grep $name $credfile)
	if  [ -n "$creds" ]; then
		debug $creds
		creds=${creds#*:}		# lose the role
		debug $creds
		creds=${creds#*:}		# lose the db name
		debug $creds
		ldap_user=${creds%%:*}
		ldap_pass=${creds#*:}
		ldap_user=$(print $ldap_user | /usr/local/bin/perl -ne 'use MIME::Base64; print decode_base64($_);' )
		ldap_pass=$(print $ldap_pass | /usr/local/bin/perl -ne 'use MIME::Base64; print decode_base64($_);' )
		debug $ldap_user     $ldap_pass
	else
		print "${RED}missing entry in $credfile for $name${RESET}"
		exit 16
	fi 


	# build ldapsearch command line
	if [ "$allowanon" != true ]; then
		debug "Anonymous binds denied, adding id/pw"
		common="-D $ldap_user -w $ldap_pass "
	else 
		debug "Anonymous binds allowed"
	fi
	debug "ssl security setting: $security"
	if [[ "$security" = @(none|ssl) ]]; then
		debug "non-ssl binds permitted"
		ldap_parms="$common -p $ldap_port"
	fi
	if [[ "$security" != none ]]; then
		debug "ssl binds permitted"
		get_ssl_settings 
		ldaps_parms="$common -K $sslkeyfile -P $sslkeypass -p $ldaps_port"
	fi

}

#-------------------------------------------------------------------------------------------------------
# Main processing
#-------------------------------------------------------------------------------------------------------
ldapdirs="/db2_database"
testinstance=$@
instance_dirs=''
# find ldap instances
for dir in $ldapdirs; do
	debug "looking for idsslapd in $dir"
	dirs=$(find $dir -type d -name "idsslapd-*")
	instance_dirs="$instance_dirs $dirs"
done

debug "Found $instance_dirs"

for instance in $instance_dirs; do
	wantinstance=1
	unset starttime
	if [ -n "$testinstance" ]; then
		unset wantinstance
		for inst in $testinstance; do
			[[ $instance = *$inst* ]] && wantinstance=1
		done
	fi
	if [ -n "$wantinstance" ]; then
		get_ldap_settings $instance
		print "*****************************************************"
		print "                $name"
		print "*****************************************************"
		check_processes $name 
		if [ -n "$slapd" ]; then
			check_requests $name
			check_replication $name
		fi
		print
	fi 
done