#!/bin/ksh


DEBUG=${debug:-0}
TIMEOUT=${timeout:-20}
cmd="sudo /lfs/system/bin/check_bNimble.sh"
myname=${0:##*/} 			#used to prefix the workfiles in /tmp
fanout=${FANOUT:-64} 	#how many background processes at a time. use environment's $FANOUT or 64

shellprog="ssh -t -x -q -F /tmp/.empty_sshkey.$USER -o NumberOfPasswordPrompts=1 -o UserKnownHostsFile=/tmp/.dssh_known_hosts.$USER 	-o strictHostKeyChecking=no"
	
lockfile="/tmp/$myname.lockfile.$$"
PWDEXP="/usr/bin/pwdexp -s1"
set -A passwd

#------------------------------------------------------------------------
# Read output from check_bNimble build server status
# 1. Find downstream distributors
# 2. Store distributor status 
#------------------------------------------------------------------------
analyse_output() {
	[ "$DEBUG" -gt 0 ] && print -u2 -- "analysing output for hosts $wcoll"
	unset DOWNSTREAM
	
	for host in $wcoll; do
		host=${host%%:*}
		if [ -s /tmp/$myname.$host.$$.out ] ; then
			[ "$DEBUG" -gt 1 ] && cat /tmp/$myname.$host.$$.out 1>&2
			if grep -qi "not running" /tmp/$myname.$host.$$.err; then 
				DISTS[$nextdist]="$host:Not running"
				nextdist=$((nextdist+1))		
			else
			
				{ while read line; do
					[ "$DEBUG" -gt 0 ] && print -u2 -- "$line"
						line=$( print -- "$line" | tr -d "\r" )
						case $line in
							*Checking?Status*)
								name=${line##*/} 
								;;
							*http*)
								url=$(print $line | awk 'BEGIN {OFS=":"} { print $1,$2,$3,$4,$5 }')
								if print $url | grep -q localhost ; then
									after=${url#*localhost}
									before=${url%localhost*}  
									url="$before$host$after"
								fi
								DISTS[$nextdist]="$host:$name:$url"
								nextdist=$((nextdist+1))
								# get downstream server name
								server=${url#*http*://}
								server=${server%%:*}
								if ! print $DOWNSTREAM | grep -q $server && ! print $ALREADY_DONE | grep -q $server; then
									[ "$DEBUG" -gt 0 ] && print -u2 -- "Adding $server to downstream list $DOWNSTREAM"
									DOWNSTREAM="$DOWNSTREAM $server"
								fi
								;;
						esac
					done
				} < /tmp/$myname.$host.$$.out
			fi
			rm -f /tmp/$myname.$host.$$.out
			rm -f /tmp/$myname.$host.$$.err
			
		fi
	done
	
	# Get passwords for downstream servers
	for server in $DOWNSTREAM; do
		[ "$DEBUG" -gt 1 ] && print -u2 -- "get password for $server"
		get_zone_pw $server
		SERVER="$SERVER $server:$zone"
	done				
	
}

get_pw() {
	typeset var i
	typeset var pw
	typeset var zone
	typeset var zonename
	zone=$1
	zonename=$2
	i=0
	unset DISPLAY
	rm -f /tmp/.dssh_known_hosts.$USER >/dev/null 2>&1
   rm -f /tmp/.empty_sshkey.$USER >/dev/null 2>&1
   print PubkeyAuthentication=no > /tmp/.empty_sshkey.$USER
   
	while [ -z "$pw" ] && [ $i -lt 3 ]; do
		print -nu2 -- "Enter $zonename password:"
		stty -echo
		read pw
		stty echo
		if [ -z "$pw" ]; then
			print -u2 -- "###$zone password entered not correct for $USER"
		else
			# try the password out 
			 		
         OKAY=$(echo "$pw" | /usr/bin/pwdexp /usr/bin/ssh -v -t -l $USER -F /tmp/.empty_sshkey.$USER -o NumberOfPasswordPrompts=1 -o UserKnownHostsFile=/tmp/.dssh_known_hosts.$USER -o strictHostKeyChecking=no $server pwd > /dev/null)
         if [ $? -ne 0 ]; then
            print -u2 -- "###$zonename zone password entered not correct for $USER"
            print -u2 -- ""
            print -u2 -- ""
            unset pw
         fi
		fi
		i=$((i+1))
	done
	if [ -n "$pw" ]; then
		print $pw
	else
		print -u2 -- "#### Cannot continue without password for $zonename"
		exit 127
	fi
}

function get_zone_pw {
	server=$1
	zone=$(lssys -l realm -1 $server | cut -c 1)
	case $zone in 
		b) if [ -z "${passwd[0]}" ] ; then
				passwd[0]=$(get_pw b "Blue")
				print -u2 -- ""
			fi
			;;
		g) if [ -z "${passwd[1]}" ]; then 
				passwd[1]=$(get_pw g "Green")
				print -u2 -- ""
			fi
			;;
		y) if [ -z "${passwd[2]}" ]; then
				passwd[2]=$(get_pw y "Yellow")
				print -u2 -- ""
			fi
			;;
		*)	print -u2 -- "Unsupported zone $zone for server $server";;
	esac
}


function query_status {
	wcoll=$@
	started=0
	finished=0
	FINISHED=0
	typeset var PIDlist
	
	# turn off ssh key support 
	
	unset DISPLAY
	rm -f /tmp/.dssh_known_hosts.$USER >/dev/null 2>&1
   rm -f /tmp/.empty_sshkey.$USER >/dev/null 2>&1
   print PubkeyAuthentication=no > /tmp/.empty_sshkey.$USER
   
	print -u2 -- "Retrieving status from $wcoll"
	for host in $wcoll; do
		zone=${host#*:}
		host=${host%%:*}
		if ! print $ALREADY_DONE | grep -q $host ; then
			ALREADY_DONE="$ALREADY_DONE $host"
				
			case $zone in
				b) pw=${passwd[0]} ;;
				g) pw=${passwd[1]} ;;
				y) pw=${passwd[2]} ;; 
			esac
			
			[ "$DEBUG" -gt 1 ]  && print -u2 "print $pw | $PWDEXP $shellprog $host \"$cmd\" > /tmp/$myname.$host.$$.out 2> /tmp/$myname.$host.$$.err"
			[ "${fanout}" -eq "1"  ] && $shellprog $host "$cmd" 2>&1 | f1output $host   
			[ "${fanout}" -gt "1"  ] && print $pw | $PWDEXP $shellprog $host "$cmd" > /tmp/$myname.$host.$$.out 2> /tmp/$myname.$host.$$.err &
			PIDs="$PIDs $!"
			files="$files /tmp/$myname.$host.$$.out /tmp/$myname.$host.$$.err"
			PIDlist=$PIDlist${PIDlist:+","}$! #put comma if PIDlist is set
			let started=$started+1
			let running=$started-$finished
			print -nu2 "\rSTRT:$started RUN:$running FIN:$finished    "
			while [ $running -ge $fanout ]  ; do  
				oldrunning=$running
				newrunning=$(ps -p$PIDlist -opid= |wc -w )
				running=${newrunning:-${oldrunning}}
				finished=$(($started - $running))
				sleep 1
			done
		fi		
	done
	
	#all spawned, now waiting for completions
	elapsed=0
	while [ $started -gt $finished ] && [ $elapsed -lt $TIMEOUT ]; do
		oldrunning=$running
		[ -z "$iflag" ] && print -nu2 "\rSTRT:$started RUN:$running FIN:$finished    "
		newrunning=$(ps -p$PIDlist -opid= |wc -w |tr -d "[:space:]" )
		if [ $newrunning -eq 0 ]; then
			break 
		fi 
		running=${newrunning:-${oldrunning}}
		finished=$(($started - $running))
		sleep 1
		elapsed=$((elapsed+1))
		if [ $elapsed -eq $TIMEOUT ]; then
			print -u2 -- "Timeout waiting for response"
			print -u2 -- "$(ps -p$PIDlist -opid=) is hanging"
			kill -9 $PIDs 1>/dev/null 2>&1
			break
		fi
	done
	print -u2 -- ""
}

select_node() {
	node=$1
	distname=$2
	#print -u2 -- "selecting server $node and dist $distname"
	( for dist in ${DISTS[*]}; do
		if print $dist | grep -q "^$node:$distname:"; then 
			print $dist
		fi
	done ) | sort -t/ -k4
}

node_status() {
	
	typeset var node
	typeset var indent
	typeset var target
	typeset var tabs
	typeset var stats
	typeset var nodes
	typeset var name
	typeset vat i 
	node=$1
	
	indent=$2
	#print -u2 -- "node_status called with $node $indent"
	
	name=${node##*/}							# distribution name including DIST/LDIST prefix
	name=${name%%:*}
	#print -u2 -- "node_status: name is now $name"
	distname=${name#*-}						# distribution name minus prefix
	#print -u2 -- "distname is $distname"
	server=${node%%:*}						# server files coming from						
	
	target=${node#*//}
	target=${target%%:*}						# server files going to
	stats=${node##*/}							# queue info
	stats=${stats#*:}
	i=0
	while [ "$i" -lt $indent ]; do
		tabs="$tabs\t"
		i=$((i+1))
	done
	print "$tabs$server->$target $name $stats"
	nodes="$( select_node $target $name )"
	if [ -z "$nodes" ]; then
		print "$tabs\t$target ENDPOINT"
	else
		for node in $nodes; do
			node_status $node $((indent+1))
		done
	fi
	#print "node_status exit"
}



output() {
	rm ~/dists.txt 2>/dev/null
	for dist in ${DISTS[*]}; do
		print $dist >>~/dists.txt
	done
	for hubnode in $PUBHUB; do
		hubnode=${hubnode%%:*}
		hubdists="$( select_node $hubnode ".*" )"			# select all hubnode records
		indent=0
	
		for dist in $hubdists; do
			lastname=$name
			name=${dist#*:}
			name=${name%%:*}
	#		print -u2 -- "output: name is now $name"
			if [ "$name" != "$lastname" ]; then
	#			print -u2 -- " $name is not the same as $lastname"
				print "\nDistribution name $name"
			fi
			
			node_status $dist $((indent+1))
		
		done
	done
	cleanupFiles
}

#-------------------------------------------------------
# cleanup previous run's leftover files if any, 
# take care that they are not from another current instance
#-------------------------------------------------------
cleanup_previous() {

	ls  /tmp/$myname.lockfile.* 2>/dev/null |  while read filespec; do
		prevPID=${filespec:##/tmp/$myname.lockfile.}
		if $(ps -p${prevPID} >/dev/null); then
			print -u2 -- "Detected another instance is running under PID=${prevPID}. Will compensate."
		else
			print -u2 -- "Found orphaned files, cleaning up before proceeding."
			rm /tmp/${myname}.lockfile.${prevPID} /tmp/${myname}.*.${prevPID}.out /tmp/${myname}.*.${prevPID}.err 2>/dev/null
		fi
	done
}

cleanupFiles() {
	[ "$DEBUG" -gt 0 ] && print -u2 -- "cleaning up files"
	 
	ls /tmp/$myname.*.$$.{err,out} 2>/dev/null | while read filespec; do 
		[ -w /tmp/$filespec ] &&  rm /tmp/$file 
		done
	[ -f $lockfile ] && rm $lockfile
	
}
#-------------------------------------------------------
# identify hub server for role
#-------------------------------------------------------

function pub_hub_for_role {
	[ "$DEBUG" -gt 0 ] && print -u2 -- "Finding HUB for $1"
	typeset -u PUB_ROLE
	PUB_ROLE=$1

	case $PUB_ROLE in
		PUB.BZPRTL.*) 
			hub=$(host eibzpub.event.ibm.com | awk '{print $3}' | tr -d "," | xargs -I {} host {} | cut -d "." -f 1)
			hub=${hub%%e0}
		;;
		PUB.ESC.*) hub=$(lssys -q -e role==pub.esc.hub.main );;
		PUB.EVENTS.*) 
			hub=$(host pub.events.ihost.com | awk '{print $3}' | tr -d "," | xargs -I {} host {} | cut -d "." -f 1)
			hub=${hub%%e0}
		;;
		PUB.IBM.*) hub=$(lssys -q -e role==pub.ibm.dist | head -n 1 ) ;;
		PUB.ICE.*) hub=$(lssys -q -e role==pub.ice.hub.main ) ;;
		PUB.STG.*) hub=$(lssys -q -e role==pub.stg.hub.main ) ;;
		*) print -u2 -- "Unable to identify main hub for $1"
			return
		;;
	esac
	print $hub
} 

#-------------------------------------------------------
# Find the pub.* roles assigned to the current server
#-------------------------------------------------------
function get_pub_roles {
	[ "$DEBUG" -gt 0 ] && print -u2 -- "Identifying pub roles for server $1"
	lssys -l role $1 | grep role | awk '{
			for ( i=3;i<=NF;i++ ) { 
				print $(i) 
			}
		}' | grep ^PUB | tr -d ";"
}

###################################################################################
#	Main code starts here. Determine what parms were passed
###################################################################################
typeset -l parm
while [ $# -ge 1 ] ; do 
	parm=$1
	case $parm in 
		pub.*) ROLE=$parm ;;
		v*|w*|at*|dt*|gt*) SERVER=$parm	;;
		*)	DISTNAME=$parm ;;	
	esac
	shift 1
done  

[ -n "$SERVER" ] &&	ROLE=$(get_pub_roles $SERVER) 

[ "$DEBUG" -gt 0 ] && print -u2 -- "role=$ROLE server=$SERVER dist=$DISTNAME"

if [ -n "$ROLE" ]; then
	PUBHUB=$(pub_hub_for_role $ROLE)
else
	print "Unable to identify main HUB"
	exit 1
fi 

if [ -z "$PUBHUB" ]; then
	exit 1
fi

print "Analysing publishing tree starting from main hub"

[ "$DEBUG" -gt 0 ] && print -u2 -- "\tUsing main HUB $PUBHUB"

cleanup_previous
touch $lockfile

# Allow to break out from wait and continue
trap "cleanupFiles" 0
trap "print -u2 Interrupt! ;            stty echo;  output; cleanupFiles; kill -9 $PIDSs; exit" 2 
trap "print -u2 QUIT! ;stty ech;  output" 3
trap "print -u2 STOP!; stty echo; kill -QUIT $PIDs" 15 19 20 21 22
#trap "showProcs" 3

#-------------------------------------------------------------------------
# Get password for main hub
#-------------------------------------------------------------------------
HUBS=$PUBHUB
PUBHUB=""
for hub in $HUBS; do
	get_zone_pw $hub
	PUBHUB="$PUBHUB $hub:$zone"
done
nextdist=0

#-------------------------------------------------------------------------
# Get bNimble status from main hub(s)
#-------------------------------------------------------------------------
query_status "$PUBHUB"

#-------------------------------------------------------------------------
# check if downstream servers and get status if there are
# Max depth of 4 levels
#-------------------------------------------------------------------------
distdepth=0
while [ $distdepth -lt 4 ]; do
	[ "$DEBUG" -gt 0 ] && print -u2 -- "Distributor depth $distdepth"
	unset SERVER
	analyse_output						# sets SERVER var
	
	if [ -z "$SERVER" ]; then
		break
	else
		query_status $SERVER
	fi
	distdepth=$((distdepth+1))
done

# now have all the status in local files
output
