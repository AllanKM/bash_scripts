#!/bin/ksh
add_to_ips() {
	typeset var servername
	typeset var ip
	servername=$1
	shift
	while [ -n "$1" ]; do
		ip=$1
		i=${#ips[*]}
		if [ $i -eq 0 ]; then
			ips[0]="$servername $1"
		else
			i=$((i-1))
			if [[ "${ips[$i]}" != *$ip* ]]; then
				if [[ "${ips[$i]}" = $servername* ]]; then
					ips[$i]="${ips[$i]} $ip"
				else
					i=$((i+1))
					ips[$i]="$servername $ip"
				fi
			fi
		fi
		
		shift
	done
	unset listenip
}
#===============================================================================
#  read config file to pick out ip addresses we can test 
#===============================================================================
read_conf_file() {
	typeset -l line
	typeset var file
	typeset var ip
	file=$1
	if [ ! -r $conf ]; then 
		print -u2 -- "Cannot read \"$file\""
		exit
	else
		[ -n "$debug" ] && print -u2 -- "Reading $conf" 
	fi
	while read line; do
		set -- $line
		case $1 in
			servername)
				[ -n "$debug" ] && print -u2 -- "${BLUE}$line${RESET}"
				if [[ "$file" = *"httpd.conf" ]]; then
					servername="HTTPServer"
				else
					servername=${2%:*}
				fi  
				add_to_ips $servername $listenip
				;;
			
			sslclientauth) 
				if [ "$2" =  "required" ]; then		# need to ignore these ips
					typeset var workvar
					unset workvar
					for ip in ${ips[${#ips[*]}-1]}; do
						if [[ "$lastvhost" = *$ip* ]]; then
							[ -n "$debug" ] && print "${RED}removing $ip${RESET}"
							continue
						else
							[ -n "$debug" ] && print "${RED}keeping $ip${RESET}"
							workvar="$workvar $ip"
						fi
					done
					ips[${#ips[*]}-1]=$workvar  
				fi
				;;
				
			listen)
				[ -n "$debug" ] && print -u2 -- "${BLUE}$line${RESET}"
				if [[ "$2" != *:* ]]; then
					ip="127.0.0.1:$2"
				elif [[ "$2" = \*:* ]]; then
					ip=${2#*:}		
					ip="127.0.0.1:$ip"				 
				else
					ip=$2 
				fi
				is_ip_for_this_plex $ip
				if [ $? -eq 1 ]; then
					if [[ "$ip" = @(127.|10.|9.)* ]]; then
						localip="$localip $ip"
					fi
					listenip="$listenip $ip"
				fi
			;;
			
			\<virtualhost)
				lastvhost=$line;
				
				[ -n "$debug" ] && print -u2 -- "${BLUE}$line${RESET}"
				add_to_ips $servername $listenip			# save whatever we have so far
				
				unset listenip
				shift
				while [ -n "$1" ]; do
					if [[ "$1" = \*:* ]]; then			# wildcard ip address see if we can match a port we should already have a listen for
						i=${#ips[*]}
						i=$((i-1))
						ip=${1#\*:}  # remove the *:
						ip=${ip%\>*}  # remove the >		
						if [[ "${ips[$i]}" = *:$ip* ]]; then		# any ips the that end with the ip
							shift
							continue 
						else
							ip="127.0.0.1:$ip"
						fi
						
					else
						ip=$1 
					fi
					ip=${ip%\>*}
					is_ip_for_this_plex $ip
					if [ $? -eq 1 ]; then
						listenip="$listenip $ip"
					fi
					shift
				done
			;;
			include)
				[ -n "$debug" ] && print -u2 -- "${BLUE}$line${RESET}"
				file=$2
				file=${file#*\"}
				file=${file%\"*}
				if [ -r $file ]; then
					read_conf_file $file
				fi
			;;
		esac
	done <$file
}
#===============================================================================
# 
#===============================================================================
is_ip_for_this_plex() {
	if [[ "$1" = 129.*.*.* ]]; then
		# its a vip 
		if [[ "$1" = *.*.26.* ]]  && [[ $PLEX = 1 ]]; then
			return 1
		elif [[ "$1" = *.*.34.* ]] && [[ $PLEX = 2 ]]; then
			return 1
		elif [[ "$1" = *.*.42.* ]] && [[ $PLEX = 3 ]]; then
			return 1
		else
			[ -n "$debug" ] && print -u2 -- "$1 is not for plex $PLEX"
			return 0
		fi
	else
		# not a vip so assume its local
		return 1
	fi
}

checkStats() {
	dt=$(date "+%T Checking ei-stats over a 7 second interval")
	print "$GREEN$dt${RESET}"
	typeset var ip
	ip=$1
	#	ip=${1#*:}
	$eistats $ip
}

checkSites() {
	typeset var i
	i=0
	dt=$(date "+%T Checking sites")
	print "$GREEN$dt${RESET}"
	
	while [ $i -lt ${#ips[*]} ]; do
		set -- ${ips[$i]}
		servername=${1%%:*}
		shift
		sitetext="$servername"
		#----------------------------------------------------------------------
		# fix search pattern where site.text doesnt contain the expected text
		#----------------------------------------------------------------------
		case $servername in 
			*australian* ) sitetext="($servername|ausopen)";;
			*usopen* ) sitetext="($servername|usopen)";;
			cmusta-odd )  sitetext="usopen.org";;
			m.ibm.com ) sitetext="($servername|wireless)" ;; 
			redirect.w3.ibm.com ) sitetext="($servername|The document has moved)" ;;
			*cnp* ) sitetext="($servername|cnp)" ;;
			mailman* ) sitetext="($servername|Global HTTPServer)" ;;
			*cdt30* ) sitetext="($servername|preview|staging)";;
			*zpap* ) sitetext="($servername|zpap)";;
			*advert.ei* ) sitetext="($servername|advert)";;
			*prd-pre30.ice* ) sitetext="($servername|staging30)";;
			*ibmint-spp* ) sitetext="($servername|ibmint-spp)";;
			*eitadmh* ) sitetext="($servername|tad4dmsghdl)";;
		esac
		
		while [ -n "$1" ]; do
			ip=$1
			proto="http"
			if [[ "$ip" = *":44"[35]* ]] || [[ "$ip" = "10."*":9999"* ]]; then
				proto="https"
			fi
			if [[ "$ip" = *":9999"* ]]; then
				file='sslsite.txt'
			else
				file='site.txt'
			fi
			[ -n "$debug" ] && print -u2 -- "Doing $checkURL "$servername" $proto://$ip/$file $sitetext"
		$checkURL "$servername" $proto://$ip/$file $sitetext
			shift
		done
		i=$((i+1))
	done
	
}

# return plex number server is part of
get_plex() {
	typeset var PLEX
	set -- $(grep search /etc/resolv.conf)
	while [[ -n "$1" ]]; do
		if [[ "$1" = [bgy].*.p?.event.ibm.com ]]; 	then
        		PLEX=`echo "$1" | cut -d. -f3 | cut -c2`
     	fi
   		shift
	done
	print $PLEX
}

checkVhosts() {

	if [[ "$1" = *"httpd.conf" ]]; then
		# find include files and extract vhost ips
    	includes=$(grep -iE "^[[:space:]]*include" $1| awk '{print $2}' | tr -d \" )
    	typeset -l vhost
    	for config in $includes; do
    		unset vips
        	vhosts=$(grep -iE "^[[:space:]]*<virtualhost" $config)
        	for vhost in $vhosts; do
            	if [[ "$vhost" != "<virtual"* ]]; then
            		vhost=${vhost%:*}
            		if ! print $vips | grep -q $vhost; then
            			vips="$vips $vhost"
            		fi
            	fi
        	done
        	checkVIPs $vips
		done
	else
		vips=$(grep "129.*" $file)
		vips=${vips#* }	
		vips=${vips%:*}
		checkVIPs $vips
	fi
	
	return
#		SERVERNAMES=`grep -i servername $cfg | awk '{print $2}'`
#		for server in $SERVERNAMES; do 
#		# only internal IP's can be accessed so ignore servers that resolve ot external addresses
#		    servern=${server%%:*}
#		    
#		    if host $servern | grep -q "[[:blank:]]129\." ; then  
#			   $checkURL $SITE http://$server/site.txt $3
#			 else
#			   print "\t$servern points to external address"
#			   host $servern | while read a; do
#			      print "\t\t$a"
#			   done
#			 fi  
#		done
#		for vip in $VIPS; do
#			plex=`echo $vip | awk -F'.' '{print $3}'`
#			case $plex  in
#				26) plex=p1;;
#				34) plex=p2;;
#				42) plex=p3;;
#				*) plex=Unknown;;
#			esac
#			server=`echo $server | awk -F':' '{print $1}'`
#			$checkURL ${server}_${plex}_vhost:$vip http://$vip/site.txt $3
#		done
#	done
}

checkConf() {
	typeset var conf
	typeset var line
	conf=$1
	
	dt=$(date "+%T Checking IHS config file $conf")
	print "$GREEN$dt${RESET}"
	
	/etc/apachectl -t -f $conf 2>&1 | while read line; do print "\t$line"; done
#	if ! /etc/apachectl -t > /dev/null 2>&1 ; then 
#		print -u2 -- "#### Failed to parse IHS config file. Check permission and syntax of config file."
#	fi	
}

checkVIPs() {
	# check VIP ip address are defined to loopback on this server
#	set -x
	dt=$(date "+%T Checking VIPS defined to loopback adapter")
	print "${GREEN}$dt${RESET}"
		
	if [ -f /sbin/ifconfig ]; then
		IFCONFIG=/sbin/ifconfig
	elif [ -f /usr/sbin/ifconfig ]; then
		IFCONFIG=/usr/sbin/ifconfig
	fi
	
	unset checked_vips
	i=0
	while [ $i -lt ${#ips[*]} ]; do
		set -- ${ips[$i]}
		servername=$1
		servername=${servername%%:*}
		shift
		while [ -n "$1" ]; do
			vip=${1%%:*}
			if [[ "$vip" = 129.* ]]; then 		 
				if [[ "$checked_vips" != *"$vip"* ]]; then
					$IFCONFIG -a 2>/dev/null | grep -q ${vip}
					if [ $? -eq 0 ]; then
						print "\tFound VIP ${vip} for ${servername}" 
					else 
						print -u2 -- "##### Missing VIP ${vip} for ${name} on loopback adapter."
					fi
					checked_vips="$check_vips $vip"
				fi
			fi
			shift
		done
		i=$((i+1))
	done
}

checkIHS() {
	
	dt=$(date "+%T Checking IHS process")
	print "$GREEN$dt${RESET}"
	typeset var ip
	ip=${1%:*}
	port=${1#*:}
	
	typeset var statusline
	if [ -n "$ip" ]; then
		# look for a process listening on the port
		if netstat -na | grep -i listen | grep -qE "$ip\.$port|\*\.$port|$ip:$port|\*:$port|:::$port"; then
			lynx --dump http://$ip/server-status | head -n 12 | while read statusline; do 
						print "\t$statusline"
			done
			return 0
		else
			print "HTTP daemon not runnning for $ip:$port"
			return 4
		fi
	else
		print -u2 -- "#### Error couldnt identify ip address to connect to server on"
		return 4
	fi
	
}

pollURL() {
	#takes three arguments Name, URL, GoodStatus
	#returns 0 if good
	if [ $# -eq 3 ] ; then
		Name=$1
		URL=$2
		GoodStatus=$3
		if /lfs/system/tools/configtools/GET $URL | grep -q "$GoodStatus" ; then
			RC=0
			print "\t$Name status: Good"
		else
			RC=1
			print -u2 "#### Unexpected $Name status while checking $URL"
		fi
	else
		print -u2 "##### pollURL requires three args:  Name, URL, and \"Good status string\""
		RC=128
	fi
	return $RC
}

base_ihs_version_61 ()
{
   typeset FIXLEVEL BITS SERVERROOT=$1
   typeset -l OUTPUT=$2

   if [[ $SERVERROOT == "" ]]; then
      echo "Function base_ihs_version_61 needs SERVERROOT defined"
      exit 1
   fi

   if [[ -f ${SERVERROOT}/bin/httpd ]]; then
      if [[ -f ${SERVERROOT}/uninstall/version.txt ]]; then
         BITS=`cat ${SERVERROOT}/uninstall/version.txt | grep Architecture | awk -F : '{print substr($2, length($2) - 1, length($2))}'` 
      fi
      if [[ -f ${SERVERROOT}/version.signature ]]; then
         FIXLEVEL=`cat ${SERVERROOT}/version.signature | awk '{print $4}'`
         if [[ ( $BITS == "32" || $BITS == "64" ) && $OUTPUT != "short" ]]; then
            echo "Installed from a $BITS Bit Supplement"
         fi
         echo "Base IHS version is $FIXLEVEL"
      else
         echo "Can not determine Base IHS version"
         return 2
      fi
   else
      echo "Base IHS is not installed"
      return 2
   fi
}
 
base_ihs_version_70 ()
{
   typeset FIXLEVEL BITS SERVERROOT=$1
   typeset -l OUTPUT=$2

   if [[ $SERVERROOT == "" ]]; then
      echo "Function base_ihs_version_70 needs SERVERROOT defined"
      exit 1
   fi

   if [[ -f ${SERVERROOT}/bin/httpd ]]; then
      if [[ -f ${SERVERROOT}/uninstall/version.txt ]]; then
         BITS=`cat ${SERVERROOT}/uninstall/version.txt | grep Architecture | awk -F : '{print substr($2, length($2) - 1, length($2))}'`
      fi
      if [[ -f ${SERVERROOT}/version.signature ]]; then
         FIXLEVEL=`cat ${SERVERROOT}/version.signature | awk '{print $4}'`
         if [[ ( $BITS == "32" || $BITS == "64" ) && $OUTPUT != "short" ]]; then
            echo "Installed from a $BITS Bit Supplement"
         fi
         echo "Base IHS version is $FIXLEVEL"
      else
         echo "Can not determine Base IHS version"
         return 2
      fi
   else
      echo "Base IHS is not installed"
      return 2
   fi
}

base_ihs_version_85 ()
{
   typeset FIXLEVEL BITS SERVERROOT=$1
   typeset -l OUTPUT=$2

   if [[ $SERVERROOT == "" ]]; then
      echo "Function base_ihs_version_85 needs SERVERROOT defined"
      exit 1
   fi

   if [[ -f ${SERVERROOT}/bin/httpd ]]; then      
      if [[ -f ${SERVERROOT}/version.signature ]]; then
         FIXLEVEL=`cat ${SERVERROOT}/version.signature | awk '{print $4}'`
         echo "Base IHS version is $FIXLEVEL"
      else
         echo "Can not determine Base IHS version"
         return 2
      fi
   else
      echo "Base IHS is not installed"
      return 2
   fi
}

updateinstaller_version_61 ()
{
   typeset FIXLEVEL BITS SERVERROOT=$1
   typeset -l OUTPUT=$2

   if [[ $SERVERROOT == "" ]]; then
      echo "Function updateinstaller_version_61 needs SERVERROOT defined"
     exit 1
   fi

   if [[ -f ${SERVERROOT}/UpdateInstaller/update.sh ]]; then
      if [[ -f ${SERVERROOT}/UpdateInstaller/uninstall/version.txt ]]; then
         BITS=`cat ${SERVERROOT}/UpdateInstaller/uninstall/version.txt | grep Architecture | awk -F : '{print substr($2, length($2) - 1, length($2))}'`
      fi
      if [[ -f ${SERVERROOT}/UpdateInstaller/version.txt ]]; then
         FIXLEVEL=`cat ${SERVERROOT}/UpdateInstaller/version.txt| grep Version: | awk {'print $2'}`
         if [[ ( $BITS == "32" || $BITS == "64" ) && $OUTPUT != "short" ]]; then
            echo "Installed from a $BITS Bit Supplement"
         fi
         echo "UpdateInstaller version is $FIXLEVEL"
      else
         echo "Can not determine UpdateInstaller version"
         return 2
      fi
   else
      echo "UpdateInstaller is not installed"
      return 2
   fi
}

updateinstaller_version_70 ()
{
   typeset FIXLEVEL BITS SERVERROOT=$1
   typeset -l OUTPUT=$2

   if [[ $SERVERROOT == "" ]]; then
      echo "Function updateinstaller_version_70 needs SERVERROOT defined"
     exit 1
   fi

   if [[ -f ${SERVERROOT}/UpdateInstaller/update.sh ]]; then
      if [[ -f ${SERVERROOT}/UpdateInstaller/uninstall/version.txt ]]; then
         BITS=`cat ${SERVERROOT}/UpdateInstaller/uninstall/version.txt | grep Architecture | awk -F : '{print substr($2, length($2) - 1, length($2))}'`
      fi
      if [[ -f ${SERVERROOT}/UpdateInstaller/version.txt ]]; then
         FIXLEVEL=`cat ${SERVERROOT}/UpdateInstaller/version.txt| grep Version: | awk {'print $2'}`
         if [[ ( $BITS == "32" || $BITS == "64" ) && $OUTPUT != "short" ]]; then
            echo "Installed from a $BITS Bit Supplement"
         fi
         echo "UpdateInstaller version is $FIXLEVEL"
      else
         echo "Can not determine UpdateInstaller version"
         return 2
      fi
   else
      echo "UpdateInstaller is not installed"
      return 2
   fi
}

updateinstaller_sdk_version_61 ()
{
   typeset FIXLEVEL SERVERROOT=$1

   if [[ $SERVERROOT == "" ]]; then
      echo "Function updateinstaller_sdk_version_61 needs SERVERROOT defined"
      exit 1
   fi

   if [[ -f ${SERVERROOT}/UpdateInstaller/java/jre/bin/java ]]; then
      FIXLEVEL=`${SERVERROOT}/UpdateInstaller/java/jre/bin/java -fullversion 2>&1`
      echo "UpdateInstaller SDK version is $FIXLEVEL"
   else
      echo "UpdateInstaller SDK is not installed"
      return 2
   fi
}

updateinstaller_sdk_version_70 ()
{
   typeset FIXLEVEL SERVERROOT=$1

   if [[ $SERVERROOT == "" ]]; then
      echo "Function updateinstaller_sdk_version_61 needs SERVERROOT defined"
      exit 1
   fi

   if [[ -f ${SERVERROOT}/UpdateInstaller/java/jre/bin/java ]]; then
      FIXLEVEL=`${SERVERROOT}/UpdateInstaller/java/jre/bin/java -fullversion 2>&1`
      echo "UpdateInstaller SDK version is $FIXLEVEL"
   else
      echo "UpdateInstaller SDK is not installed"
      return 2
   fi
}

base_ihs_sdk_version_61 ()
{
   typeset FIXLEVEL SERVERROOT=$1

   if [[ $SERVERROOT == "" ]]; then
      echo "Function base_ihs_sdk_version_61 needs SERVERROOT defined"
      exit 1
   fi

   if [[ -f ${SERVERROOT}/java/jre/bin/java ]]; then
      FIXLEVEL=`${SERVERROOT}/java/jre/bin/java -fullversion 2>&1`
      echo "Base IHS SDK version is $FIXLEVEL"
   else
      echo "Base IHS SDK is not installed"
      return 2
   fi
}
 
base_ihs_sdk_version_70 ()
{
   typeset FIXLEVEL SERVERROOT=$1

   if [[ $SERVERROOT == "" ]]; then
      echo "Function base_ihs_sdk_version_70 needs SERVERROOT defined"
      exit 1
   fi

   if [[ -f ${SERVERROOT}/java/jre/bin/java ]]; then
      FIXLEVEL=`${SERVERROOT}/java/jre/bin/java -fullversion 2>&1`
      echo "Base IHS SDK version is $FIXLEVEL"
   else
      echo "Base IHS SDK is not installed"
      return 2
   fi
}

base_ihs_sdk_version_85 ()
{
   typeset FIXLEVEL SERVERROOT=$1

   if [[ $SERVERROOT == "" ]]; then
      echo "Function base_ihs_sdk_version_85 needs SERVERROOT defined"
      exit 1
   fi

   if [[ -f ${SERVERROOT}/java/jre/bin/java ]]; then
      FIXLEVEL=`${SERVERROOT}/java/jre/bin/java -fullversion 2>&1`
      echo "Base IHS SDK version is $FIXLEVEL"
   else
      echo "Base IHS SDK is not installed"
      return 2
   fi
}

httpd_version_61 ()
{
   typeset SERVERROOT=$1

   if [[ $SERVERROOT == "" ]]; then
      echo "Function httpd_version_61 needs SERVERROOT defined"
      exit 1
   fi

   if [[ -f ${SERVERROOT}/bin/httpd ]]; then
      echo "Executing httpd -V command"
      . ${SERVERROOT}/bin/envvars
      ${SERVERROOT}/bin/httpd -V
   else
      echo "Base IHS is not installed"
      return 2
   fi
}

httpd_version_70 ()
{
   typeset SERVERROOT=$1

   if [[ $SERVERROOT == "" ]]; then
      echo "Function httpd_version_70 needs SERVERROOT defined"
      exit 1
   fi

   if [[ -f ${SERVERROOT}/bin/httpd ]]; then
      echo "Executing httpd -V command"
      . ${SERVERROOT}/bin/envvars
      ${SERVERROOT}/bin/httpd -V
   else
      echo "Base IHS is not installed"
      return 2
   fi
}

httpd_version_85 ()
{
   typeset SERVERROOT=$1

   if [[ $SERVERROOT == "" ]]; then
      echo "Function httpd_version_85 needs SERVERROOT defined"
      exit 1
   fi

   if [[ -f ${SERVERROOT}/bin/httpd ]]; then
      echo "Executing httpd -V command"
      . ${SERVERROOT}/bin/envvars
      ${SERVERROOT}/bin/httpd -V
   else
      echo "Base IHS is not installed"
      return 2
   fi
}

installed_versions_61 ()
{
   typeset SERVERROOT=$1
   typeset SYSTEMTYPE=`/usr/bin/lssys -l systemtype -1n 2> /dev/null`
   typeset OSLEVEL=`/usr/bin/lssys -l oslevel -1n 2> /dev/null`
   typeset NODE=`uname -n`

   if [[ $SYSTEMTYPE == "" ]]; then
      SYSTEMTYPE=`cat /usr/local/etc/nodecache | grep systemtype | awk -F "=" '{print $NF}' 2> /dev/null`
   fi

   if [[ $OSLEVEL == "" ]]; then
      OSLEVEL=`cat /usr/local/etc/nodecache | grep oslevel | awk -F "=" '{print $NF}' 2> /dev/null`
   fi

   if [[ $SERVERROOT == "" ]]; then
      echo "Function installed_versions_61 needs SERVERROOT defined"
      exit 1
   fi

   if [[ -d ${SERVERROOT} ]]; then
      echo "//////////////////////////////////////////////////////////////////"
      echo "                    Begin IHS Install"
      echo "------------------------------------------------------------------"
      echo ""
      echo "Server Root: $SERVERROOT"
      echo "Host:        $NODE"
      echo "System Type: $SYSTEMTYPE"
      echo "OS Level:    $OSLEVEL"
      echo ""
      echo "               ---------------------------------"
      echo "               Summary of installed IHS products"
      echo "               ---------------------------------"
      echo ""
      base_ihs_version_61 $SERVERROOT
      base_ihs_sdk_version_61 $SERVERROOT
      echo ""
      echo "                         ###########"
      echo ""
      updateinstaller_version_61 $SERVERROOT
      updateinstaller_sdk_version_61 $SERVERROOT
      echo ""
      echo "                         ###########"
      echo ""

      PLUGINROOT_LIST=`ls -d ${SERVERROOT}/Plugins* 2> /dev/null`
      if [[ $PLUGINROOT_LIST == "" ]]; then
         PLUGINROOT_LIST="${SERVERROOT}/Plugins"
      fi

      for PLUGINROOT in $PLUGINROOT_LIST
      do
         BASELEVEL=`echo $PLUGINROOT | awk '{print substr($1, length($1)-1,length($1))}'`
         case $BASELEVEL in
            61|ns)
               was_plugin_version_61 $PLUGINROOT
               was_plugin_sdk_version_61 $PLUGINROOT
            ;;
            70)
               was_plugin_version_70 $PLUGINROOT
               was_plugin_sdk_version_70 $PLUGINROOT
            ;;
            *)
               echo "This script does not support the location"
               echo "the plugin was detected installed in"
               echo "therefore can not determine version"
            ;;
         esac
         echo ""
         echo "                         ###########"
         echo ""
      done
      httpd_version_61 $SERVERROOT
      echo ""
      echo "------------------------------------------------------------------"
      echo "                     End IHS Install"
      echo "//////////////////////////////////////////////////////////////////"
      echo ""
   else
      echo "$SERVERROOT directory does not exist"
      return 2
   fi
}

installed_versions_70 ()
{
   typeset SERVERROOT=$1
   typeset SYSTEMTYPE=`/usr/bin/lssys -l systemtype -1n 2> /dev/null`
   typeset OSLEVEL=`/usr/bin/lssys -l oslevel -1n 2> /dev/null`
   typeset NODE=`uname -n`

   if [[ $SYSTEMTYPE == "" ]]; then
      SYSTEMTYPE=`cat /usr/local/etc/nodecache | grep systemtype | awk -F "=" '{print $NF}' 2> /dev/null`
   fi

   if [[ $OSLEVEL == "" ]]; then
      OSLEVEL=`cat /usr/local/etc/nodecache | grep oslevel | awk -F "=" '{print $NF}' 2> /dev/null`
   fi

   if [[ $SERVERROOT == "" ]]; then
      echo "Function installed_versions_70 needs SERVERROOT defined"
      exit 1
   fi

   if [[ -d ${SERVERROOT} ]]; then
      echo "//////////////////////////////////////////////////////////////////"
      echo "                    Begin IHS Install"
      echo "------------------------------------------------------------------"
      echo ""
      echo "Server Root: $SERVERROOT"
      echo "Host:        $NODE"
      echo "System Type: $SYSTEMTYPE"
      echo "OS Level:    $OSLEVEL"
      echo ""
      echo "               ---------------------------------"
      echo "               Summary of installed IHS products"
      echo "               ---------------------------------"
      echo ""
      base_ihs_version_70 $SERVERROOT
      base_ihs_sdk_version_70 $SERVERROOT
      echo ""
      echo "                         ###########"
      echo ""
      updateinstaller_version_70 $SERVERROOT
      updateinstaller_sdk_version_70 $SERVERROOT
      echo ""
      echo "                         ###########"
      echo ""
      PLUGINROOT_LIST=`ls -d ${SERVERROOT}/Plugins* 2> /dev/null`
      if [[ $PLUGINROOT_LIST == "" ]]; then
         PLUGINROOT_LIST="${SERVERROOT}/Plugins"
      fi

      for PLUGINROOT in $PLUGINROOT_LIST
      do
         BASELEVEL=`echo $PLUGINROOT | awk '{print substr($1, length($1)-1,length($1))}'`
         case $BASELEVEL in
            61|ns)
               was_plugin_version_61 $PLUGINROOT
               was_plugin_sdk_version_61 $PLUGINROOT
            ;;
            70)
               was_plugin_version_70 $PLUGINROOT
               was_plugin_sdk_version_70 $PLUGINROOT
            ;;
            *)
               echo "This script does not support the location"
               echo "the plugin was detected installed in"
               echo "therefore can not determine version"
            ;;
         esac
         echo ""
         echo "                         ###########"
         echo ""
      done
      httpd_version_70 $SERVERROOT
      echo ""
      echo "------------------------------------------------------------------"
      echo "                     End IHS Install"
      echo "//////////////////////////////////////////////////////////////////"
      echo ""
   else
      echo "$SERVERROOT directory does not exist"
      return 2
   fi
}

installed_versions_85 ()
{
   typeset SERVERROOT=$1
   typeset SYSTEMTYPE=`/usr/bin/lssys -l systemtype -1n 2> /dev/null`
   typeset OSLEVEL=`/usr/bin/lssys -l oslevel -1n 2> /dev/null`
   typeset NODE=`uname -n`

   if [[ $SYSTEMTYPE == "" ]]; then
      SYSTEMTYPE=`cat /usr/local/etc/nodecache | grep systemtype | awk -F "=" '{print $NF}' 2> /dev/null`
   fi

   if [[ $OSLEVEL == "" ]]; then
      OSLEVEL=`cat /usr/local/etc/nodecache | grep oslevel | awk -F "=" '{print $NF}' 2> /dev/null`
   fi

   if [[ $SERVERROOT == "" ]]; then
      echo "Function installed_versions_85 needs SERVERROOT defined"
      exit 1
   fi

   if [[ -d ${SERVERROOT} ]]; then
      echo "//////////////////////////////////////////////////////////////////"
      echo "                    Begin IHS Install"
      echo "------------------------------------------------------------------"
      echo ""
      echo "Server Root: $SERVERROOT"
      echo "Host:        $NODE"
      echo "System Type: $SYSTEMTYPE"
      echo "OS Level:    $OSLEVEL"
      echo ""
      echo "               ---------------------------------"
      echo "               Summary of installed IHS products"
      echo "               ---------------------------------"
      echo ""
      base_ihs_version_85     $SERVERROOT
      base_ihs_sdk_version_85 $SERVERROOT
      echo ""
      echo "                         ###########"
      echo ""      
      httpd_version_85 $SERVERROOT
      echo ""
      echo "------------------------------------------------------------------"
      echo "                     End IHS Install"
      echo "//////////////////////////////////////////////////////////////////"
      echo ""
   else
      echo "$SERVERROOT directory does not exist"
      return 2
   fi
}

installed_versions_plugin_85 ()
{
   typeset PLUGINROOT=$1
   typeset SYSTEMTYPE=`/usr/bin/lssys -l systemtype -1n 2> /dev/null`
   typeset OSLEVEL=`/usr/bin/lssys -l oslevel -1n 2> /dev/null`
   typeset NODE=`uname -n`

   if [[ $SYSTEMTYPE == "" ]]; then
      SYSTEMTYPE=`cat /usr/local/etc/nodecache | grep systemtype | awk -F "=" '{print $NF}' 2> /dev/null`
   fi

   if [[ $OSLEVEL == "" ]]; then
      OSLEVEL=`cat /usr/local/etc/nodecache | grep oslevel | awk -F "=" '{print $NF}' 2> /dev/null`
   fi

   if [[ $PLUGINROOT == "" ]]; then
      echo "Function installed_versions_plugin_85 needs PLUGINROOT defined"
      exit 1
   fi

   if [[ -d ${PLUGINROOT} ]]; then
      echo "//////////////////////////////////////////////////////////////////"
      echo "                    Begin WAS Plugin Install"
      echo "------------------------------------------------------------------"
      echo ""
      echo "Plugin Root: $PLUGINROOT"
      echo "Host:        $NODE"
      echo "System Type: $SYSTEMTYPE"
      echo "OS Level:    $OSLEVEL"
      echo ""
      echo "               ---------------------------------"
      echo "                Summary of installed WAS Plugins"
      echo "               ---------------------------------"
      echo ""
      echo "                         ###########"
      echo ""
      was_plugin_version_85     $PLUGINROOT
      was_plugin_sdk_version_85 $PLUGINROOT
      echo ""
      echo "                         ###########"
      echo ""
      echo "------------------------------------------------------------------"
      echo "                     End WAS Plugin Install"
      echo "//////////////////////////////////////////////////////////////////"
      echo ""
   else
      echo "$PLUGINROOT directory does not exist"
      return 2
   fi
}