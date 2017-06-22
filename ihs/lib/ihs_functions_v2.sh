#!/bin/ksh

checkConf() {
	date "+%T Checking IHS config file"
	/etc/apachectl -t 2>&1 | while read line; do print "\t$line"; done
	if ! /etc/apachectl -t > /dev/null 2>&1 ; then 
		print -u2 -- "#### Failed to parse IHS config file. Check permission and syntax of config file."
	fi	
}

checkVIPs() {
#	set -x
	VIP_FOR_PLEX1=$1
	VIP_FOR_PLEX2=$2
	VIP_FOR_PLEX3=$3
	if [ -f /sbin/ifconfig ]; then
		IFCONFIG=/sbin/ifconfig
	elif [ -f /usr/sbin/ifconfig ]; then
		IFCONFIG=/usr/sbin/ifconfig
	fi
	if [ "$VIP_FOR_PLEX1" != "" ]; then
		
		
		unset foundVIPs
		#Determine what plex this node is located by looking in /etc/resolv.conf
		set -- $(grep search /etc/resolv.conf)

		while [[ "$1" != "" ]]; do
    		if [ "$1" = [bgy].*.p?.event.ibm.com ]
      			then
        			PLEX=`echo "$1" | cut -d. -f3 | cut -c2`
     			fi
    		shift
		done
	
		case $PLEX in 
			1) localnet=$VIP_FOR_PLEX1;;
			2) localnet=$VIP_FOR_PLEX2;;
			3) localnet=$VIP_FOR_PLEX3;;
		esac

		date "+%T Checking aliases for VIP: $localnet"
		/etc/apachectl -S 2>&1 |awk '$1 ~ /'${localnet}'/ {print $0}' |sort -u | while read addr name conf; do
			IP=${addr%:*}
			$IFCONFIG -a 2>/dev/null | grep -q ${IP}
			if [ $? -eq 0 ]; then
				echo "\tFound VIP ${IP} for ${name}" 
			else 
				print -u2 -- "##### Missing VIP ${IP} for ${name} on loopback adapter."
			fi
		done 
	fi
}

checkIHS() {
	date "+%T Checking IHS process"
	if ps -eoargs= |sort |uniq -c |grep h[t]tpd ; then
		/etc/apachectl status | head -12 | while read line; do print "\t$line"; done
		return 0
	else
		print -u2 -- "########## httpd not running"
		return 1
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

function base_ihs_version_61
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
 
function base_ihs_version_70
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

function base_ihs_version_85
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
 
function updateinstaller_version_61
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

function updateinstaller_version_70
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

function updateinstaller_sdk_version_61
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

function updateinstaller_sdk_version_70
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

function base_ihs_sdk_version_61
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
 
function base_ihs_sdk_version_70
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

function base_ihs_sdk_version_85
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

function httpd_version_61
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

function httpd_version_70
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

function httpd_version_85
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

function installed_versions_61
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
         BASELEVEL=`echo ${PLUGINROOT%%_*} | awk '{print substr($1, length($1)-1,length($1))}'`
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

function installed_versions_70
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
         BASELEVEL=`echo ${PLUGINROOT%%_*} | awk '{print substr($1, length($1)-1,length($1))}'`
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

function installed_versions_85
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

function installed_versions_plugin_85
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
      echo "                  Begin WAS Plugin Install"
      echo "------------------------------------------------------------------"
      echo ""
      echo "Server Root: $PLUGINROOT"
      echo "Host:        $NODE"
      echo "System Type: $SYSTEMTYPE"
      echo "OS Level:    $OSLEVEL"
      echo ""
      echo "               ----------------------------------------"
      echo "               Summary of installed WAS Plugin products"
      echo "               ----------------------------------------"
      echo ""
      echo "                         ###########"
      echo ""
      was_plugin_version_85     $PLUGINROOT
      was_plugin_sdk_version_85 $PLUGINROOT
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