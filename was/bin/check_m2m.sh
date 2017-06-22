#!/bin/ksh  
. /lfs/system/tools/was/lib/check_m2m_functions.sh
default_URI=/servlet/com.ibm.srm.soa.HealthCheck
default_PORT=9044
default_HOST=localhost
default_PROTO=https
default_ROLE=$(lssys -x csv -l role $(hostname) | awk -F, '/'$(hostname)'/ {print $NF}' | awk -F';' '{ for (i=1;i<=NF;i++) { if ( $(i)~/^WAS./ ) { print $(i) ;break } } }')
default_URL="$default_PROTO://$default_ROLE:$default_PORT$default_URI"
sleep=${sleep:-15}
timeout=${timeout:-15}
myPID=${$}


splitURL() {
	myURL=$1
	#this part splices the URL around :// ,  :  and /
	#if the tokens are missing the lower-cased variales are empty
	proto=${myURL%%://*} # Keep the left side of :// on myURL
	role=${myURL##*://}  # Keep right side of :// on myURL
	uri="/${role#*/}" # Keep the right side of  1st / on role
	role=${role%%/*}  # Keep the left side of 1st / on role
	port=${role#*:}  # Keep the right side of : on role
	role=${role%%:*} # Keep the left side of : on role
	#Clean up values that don't make sense
	[ "${port}" == "${role}" ] && unset port
	[ "$proto" == "${myURL%%://*}" ] && unset proto

	#this part either sets the user-given values or the default
	PROTO=${proto:-${default_PROTO}}
	PORT=${port:-${default_PORT}}
	ROLE=${role:-${default_ROLE}}
	URI=${uri:-${default_URI}}

	print $PROTO :// $ROLE : $PORT $URI
}

#=============================
# Process commandline opts
#=============================
while [ $# -ge 1 ] ; do 
	case $1 in 
		http*)	url=$1;;
		role=*) role=${1##role=};;
		app=*) testapp=${1##app=};;
		url=*) url=${1##url=};;
		host=*)	host=${1##host=};;
		from=*)	from=${1##from=};;
		except=*)	except=${1##except=};;
		sleep=*) sleep=${1##sleep=};;
		timeout=*) timeout=${1##timeout=};;
		nodes=*) nodes=$(IFS=", 	"; print ${1##nodes=});; #turns comma/tab/space-separated values into space-separated values
		help) 
cat <<EOF >&2
Usage: ${0##*/} [conjugates ...]

 Keyword parms
 -------------
 The parms may be set as environment variables or supplied following the command eg
       role=was.ibm.prd.gz check_m2m.sh
         or 
       check_m2m.sh role=was.ibm.prd.gz
	
   role= defines the role name used to lookup the servers to check

   url=  defines url to be used in m2m check, this can either specify the exact url that would need
         to be used from the was server to access the application being tested, or a psuedo URL 
         containing the rolename for the WAS servers on which to run the test e.g

            url=http://localhost:9048/app/healthcheck
               or
            url=http://was.ibm.prd.gz:9048/app/healthcheck

         in the first case the list of servers would need to be defined using the role= or nodes= conjugate
         in the second case the role is extracted from the pseudo URl

   host=	specifies the Host in the http header 

   from=	Server name on which to create the initial session. from=ALL can be specified to perform the session
          creation and replication test on each node in the m2m pool

   except= regular expression used to remove nodes from the list eg
           except="at0101a|dt0101a*"

   sleep= wait time in seconds to wait after creating the session before checking it has replicated
             to other servers
   timeout=	wait time in seconds before deciding webserver has not responded
 	
   nodes= A list of comma seperated server names on which to perform the test

 Bareword parms
 --------------
 if used these parameters must follow the command name, eg check_m2m.sh http:\\a.b.c 

  http*		parms starting http will be used as the url to be used in the m2m check
  <appname> a valid application name as defined in check_was.sh 

EOF
		exit 1;;
	*)	
		testapp=${1##app=}
		
		url=$(get_url $testapp $role )
		if [ $? -gt 0 ]; then
			print -u2 -- "Unknown conjugate \"$1\". Try \"help\""; exit 1
		else
			role=${url%%@*}
			url=${url##*@}
		fi
		;;
	esac
	shift 1
done

#======================
# Where is the URL 
#======================
if [ -z "$url" ]; then
	if [ ! -z "$testapp" ]; then
		if [ ! -z "$role" ]; then
			url=$(get_url_for_app $testapp $role)
		else
			url=$(get_url_for_app $testapp)
			if [ $? -eq 1 ]; then
				exit 1
			fi
		fi
	fi

# still have not identified a url ?

	if [ -z "$url" ]; then
cat <<EOF1 >&2
 #### Url must be specified using one of the following 
 
   http(s)://<url>
      or
   url=http(s)://<url>
      or
   an app name defined in check_was.sh and optionally role= if the application is defined to multiple roles

EOF1
			exit 1
		fi
fi
URL=${url:-${URL}} 


set -- `splitURL ${URL:-${default_URL}}`
PROTO=$1; ROLE=$3; PORT=$5; URI=$6
myURL=$(echo $* | tr -d " ")
HOST=${host:-${ROLE}}	# inherit from url= 
ROLE=${role:-${ROLE}}	# allows role= to override the url= setting
[ ${HOST} == ${ROLE} ] && HOST=${host:-${default_HOST}} #if all esle fails

# Use the user-given, the ROLE or localhost
print -n -- "Building collective of nodes from ${ROLE:+"role=\"${ROLE}\", "}${nodes:+"nodes=\"${nodes}\", "}\b\b..."
nodes=${nodes:-$(lssys -qe role==$ROLE nodestatus!=BAD | xargs)}
nodes=${nodes:-localhost}
print -- " using \"$nodes\"."

#===================================================
# If user specified nodes to remove, exclude from list
#===================================================
if [ -n "${except}" ] ; then
except=`print $except | tr ", " "||"`
print -n -- "Removing nodes matching pattern \"${except}\" from collective..."
nodes="$(print -- ${nodes} | xargs -n1 | grep -vE "${except}" | xargs)"
print -- " using \"$nodes\"."
fi


case ${from:-blank} in
ALL|all) 	from=${nodes};;
random|blank)	set -- ${nodes} ; shift $(( ${RANDOM} % ( $# - 1 ) )); from=${1:-localhost};;
esac


lastNode=${from:-${nodes}}; lastNode=${lastNode##* }
for sampleNode in ${from:-${nodes}}; do 
	print -- "Trying to get a session from \"$sampleNode:$PORT\"."
#	print -u2 -- "curl --connect-timeout $timeout  -sI -H\"Host: $HOST\" $PROTO://$sampleNode:$PORT$URI"
	cookie=`curl --connect-timeout $timeout  -sI -H"Host: $HOST" $PROTO://$sampleNode:$PORT$URI | awk '/Set-Cookie/ {print $2}'`
  
	if [ -n "${cookie}" ] ; then 
		cookie=${cookie%;} #remove trailing semi-colon
		cookie=${cookie%%:*} #remove host_identifiers
		cookiename=${cookie%%=*} #save the cookiename (removing everything right of the equal sign)
		session=${cookie##*=????} #save the session (removing the cookiename and the counter)

		print --  "Established session \"${cookiename##SESSION_}\" with value \"$session\" on \"$sampleNode\" through \"$myURL\" "
		print --  "Waiting $sleep seconds to ensure replication happens..."; sleep $sleep
		print --  "Validating session \"$session\" received from \"$sampleNode\" against \"$ROLE\" nodes ($nodes)."

		# Append a unique/non-matching host_identifier to force the appserver to issue a set-cookie header at all times
		# Ensure that the options are terminated in the grep as the session identifier may start with a dash. 

		#set -x
		now=$(date -u "+%D %T")
		for node in $nodes; do 
			 (
				curl --connect-timeout $timeout  -m $timeout -s -b "$cookie:`whoami`" -H"Host: $HOST" -I $PROTO://$node:$PORT$URI -D "/tmp/${0##*/}.${node}.${myPID}.tmp" >/dev/null
				RC=$?
				case $RC in
					# See curl man page for EXIT CODE reference
				7)	# Failed to connect to host.
					print -- "#### $now: Failed to connect to $PROTO://$node:$PORT$URI to validate session."
					;;
				28) # Operation timeout. The specified time-out period was reached according to the conditions.
					print -- "#### $now: Timed out after $timeout seconds waiting for $PROTO://$node:$PORT$URI to validate session." 
					;;
				35) # SSL connect error. The SSL handshaking failed.
					print -- "#### $now: SSL handshake failure for $PROTO://$node:$PORT$URI to validate session." i
					;;
				52) # The server did not reply anything, which here is considered an error.
					print -- "#### $now: Empty reply from for $PROTO://$node:$PORT$URI to validate session." 
					;;
				*)	#print status=$RC
					if [ -s "/tmp/${0##*/}.${node}.${myPID}.tmp" ] ; then 
						if grep -q -- "$session" /tmp/${0##*/}.${node}.${myPID}.tmp 2>/dev/null; then
							print -- "	Session \"$session\" is valid on \"$node:$PORT\" for \"${cookiename##SESSION_}\". Curl RC=$RC."
						else
							print -u2 -- "#### $now:  $PROTO://$node:$PORT$URI cannot find session \"$session\" set by \"${sampleNode}:${PORT}\" in pool \"${cookiename##SESSION_}\". Curl RC=$RC." 
						fi
					fi
				esac
				print -- $RC >> /tmp/${0##*/}.${node}.${myPID}.tmp
			 ) &
			 PIDs="$PIDs $!"
		done
		wait $PIDs
		unset PIDs
		typeset -i cRC=0
		for node in ${nodes}; do
			typeset -i tmpRC="$(tail -1 /tmp/${0##*/}.${node}.${myPID}.tmp 2>/dev/null)"
			cRC=$(( ${cRC:-0} + ${tmpRC:-255} ))
			[ -f "/tmp/${0##*/}.${node}.${myPID}.tmp" ] && rm /tmp/${0##*/}.${node}.${myPID}.tmp  2>/dev/null
		done
		#print -- "Cumulative Return code = ${cRC}"
		set +x

		tty -s && [ "${sampleNode}" != "${lastNode}" ] && read junk?"Press ENTER to continue" # stop if there's a terminal and more nodes to process.
	else
		print -u2 -- "#### Did not receive a session cookie from \"$PROTO://$sampleNode:$PORT$URI\"."
		cRC=255
	fi
done
return ${cRC}
