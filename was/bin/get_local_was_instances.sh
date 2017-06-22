#!/bin/ksh

host=`uname -n`

typeset -u roles
typeset -u zone
typeset var line 

while read -r line; do
	case $line in
		role*) roles=${line#*= };;
		systemtype* ) hw=${line#*=};;
  		custtag* ) cust=${line#*=};;
  		realm* )
  			zone=${line#*= }
  			zone=${zone%%\.*}Z
    		;;
  	esac
done < /usr/local/etc/nodecache 

cdt=0
wps=0
if [[ "$roles" = *"WPS."* ]]; then
	wps=1	
fi
if [[ "$roles" = *".CDT"* ]]; then
	cdt=1
fi

os=$(uname -s)
# add a filter to search Linux OS for apptracker report by Raymond 20090828
if [ "${os}" = "AIX" ]  || [ "${os}" = "Linux" ]; then
	#	WASDIRS=`ls -d /usr/WebSph* 2>/dev/null`
	for DIR in /usr/WebSphere*; do
		if [ -f $DIR/AppServer/bin/startServer.sh ]; then
			[ -n "$debug" ] && print -u2 -- $DIR
			# get version of WAS
			if [ -f ${DIR}/AppServer/properties/version/BASE.product ]; then
				VERSION=`grep "<version>" ${DIR}/AppServer/properties/version/BASE.product 2>/dev/null | sed "s/[^0-9]//g"`
			elif [ -f ${DIR}/AppServer/properties/version/WAS.product ]; then
				VERSION=`grep "<version>" ${DIR}/AppServer/properties/version/WAS.product 2>/dev/null | sed "s/[^0-9]//g"`
			else
				VERSION="????"
			fi
			
			version="WAS_$VERSION"
			[ -n "$debug" ] && print -u2 -- "using version $version"
			# Get dmgr 
			[ -n "$debug" ] && print -u2 -- "find vhosts"
			dmgr=`find ${DIR}/AppServer/profiles/*/config/cells -name "virtualhosts.xml" | grep "/config/cells" | grep -vi "template" | awk -F"/" '{print $(NF-1)}'`
			[ -n "$debug" ] && print -u2 -- "done"
			if [ "$dmgr" = "$host" ]; then
				[ -n "$debug" ] && print -u2 -- "Not a dmgr"
				dmgr="N/A"
			fi

			index=`find $DIR/AppServer/profiles/*/config/cells -name "serverindex.xml" | grep "/config/cells/" | grep -E "/nodes/${host}.*/serverindex"`
			if [ ! -z "$index" ]; then
				[ -n "$debug" ] && print -u2 -- "$index"
				while read -r index_line; do 
					if [[ "$index_line" = *"APPLICATION_SERVER"* ]]; then
						jvm=${index_line#*serverName=\"}
						jvm=${jvm%%\"*}
						[ -z "$wps" ] && unset ears
						unset soap

					elif [[ "$index_line" = *deployedApplications* ]]; then
						ear=${index_line#*deployedApplications\>}
						ear=${ear%%\<*}
						ear=${ear%%/*}
						ear=$(print $ear | tr " " "_")
						ears="${ears}${ear};"
						
					elif [[ "$index_line" = *"SOAP"* ]] && [ -n "$jvm" ]; then
						soap=1
					elif [ -n "$soap" ]; then
						port=${index_line#*port=\"}
						port=${port%%\"*}
						unset soap
						status=0
						[ -n "$debug" ] && print -u2 -- "Is $port active"
						if netstat -na | grep -i "$port.*LISTEN" >/dev/null 2>&1; then
							status="1"
						fi
						print "$version $cust $host $dmgr $os $hw $zone $jvm $status {$ears} $cdt $wps"
						unset ears
					fi 
				done < $index
			fi
		fi
	done
fi