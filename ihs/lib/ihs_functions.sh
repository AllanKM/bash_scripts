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
    		if [[ "$1" = [bgy].*.p?.event.ibm.com ]]
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


set_vhost_perms()
{

  VHOST="$1"
  
  if [[ -d /logs/${VHOST} ]]; then
	echo "Setting permissions on /logs/${VHOST}"
    chmod -R 0750 /logs/${VHOST}
    find /logs/${VHOST} -follow -type d -exec chown -R webinst.eiadm {} \;
    find /logs/${VHOST} -follow -type d -exec chmod g+s {} \;
    chmod -R o-rwx /logs/${VHOST}
  fi
  if [[ -L /logs/${VHOST} ]]; then
     REALDIR=`ls -l /logs/${VHOST} | awk {'print $NF'}`
     echo "/logs/${VHOST} is a symlink to $REALDIR"
     echo "Setting permissions on $REALDIR"
     chmod -R 0750 $REALDIR
     find $REALDIR -follow -type d -exec chown -R webinst.eiadm {} \;
     find $REALDIR -follow -type d -exec chmod g+s {} \;
     chmod -R o-rwx $REALDIR
  fi
  if [[ -d /projects/${VHOST} ]]; then
	echo "Setting permissions on  /projects/${VHOST}"
	chown root.eiadm /projects/${VHOST}
	chmod 775 /projects/${VHOST}
	if [[ -d /projects/${VHOST}/content ]]; then 
		id pubinst > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			chown pubinst.apps /projects/${VHOST}/content
                        chmod 755 /projects/${VHOST}/content
		else
			chown root.eiadm /projects/${VHOST}/content
                        chmod 775 /projects/${VHOST}/content
		fi
                if [ -d /projects/${VHOST}/content/Admin ]; then
                        chown -R root.eiadm /projects/${VHOST}/content/Admin
                        find /projects/${VHOST}/content/Admin -type d -exec chmod 775 {} \;
                        find /projects/${VHOST}/content/Admin -type f -exec chmod 664 {} \;
                fi
                if [ -f /projects/${VHOST}/content/site.txt ]; then
                        chown root.eiadm /projects/${VHOST}/content/site.txt
                        chmod 664 /projects/${VHOST}/content/site.txt
                fi
                if [ -h /projects/${VHOST}/content/sslsite.txt ]; then
                        chown -h root.eiadm /projects/${VHOST}/content/sslsite.txt
                fi
	fi
        if [[ -d /projects/${VHOST}/htdocs ]]; then
                id pubinst > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                        chown pubinst.apps /projects/${VHOST}/htdocs
                        chmod 755 /projects/${VHOST}/content
                else
                        chown root.apps /projects/${VHOST}/htdocs
                        chmod 775 /projects/${VHOST}/content
                fi
        fi
        if [[ -d /projects/${VHOST}/config ]]; then
               for FILE in `ls /projects/${VHOST}/config/*conf 2>/dev/null`; do
                      grep "eiRotate" $FILE > /tmp/line
		      			if [[ $? -eq 0 ]]; then
  							grep umask /tmp/line > /dev/null
                        	if [[ $? -ne 0 ]]; then
                           		print -u2 -- "#### Update $FILE to use -umask 027 with eiRotate"
                        	fi
                     	fi
                done
                chown -R root.eiadm /projects/${VHOST}/config
                find /projects/${VHOST}/config -type d -exec chmod 770 {} \;
                find /projects/${VHOST}/config -type f -exec chmod 660 {} \;
		find /projects/${VHOST}/config -name "*passwd" -exec chgrp apps {} \;
	fi
	if [[ -d /projects/${VHOST}/conf ]]; then
               for FILE in `ls /projects/${VHOST}/conf/*conf 2>/dev/null`; do
                      grep "eiRotate" $FILE > /tmp/line
                      if [[ $? -eq 0 ]]; then
                        grep umask /tmp/line > /dev/null
                        if [[ $? -ne 0 ]]; then
                           echo "    Adding umask line to eiRotate stanzas in $FILE"
                           cp $FILE ${FILE}.bak
                           sed -e "s/\/eiRotate/\/eiRotate -umask 027/" $FILE > /tmp/httpd.conf && mv /tmp/httpd.conf  $FILE
                        fi
                     fi
                done
                chown -R root.eiadm /projects/${VHOST}/conf
                find /projects/${VHOST}/conf -type d -exec chmod 770 {} \;
                find /projects/${VHOST}/conf -type f -exec chmod 660 {} \;
		find /projects/${VHOST}/conf -name "*passwd" -exec chgrp apps {} \;
        fi
        if [[ -d /projects/${VHOST}/cgi-bin ]]; then
        	chown root.eiadm /projects/${VHOST}/cgi-bin
        	chmod 775 /projects/${VHOST}/cgi-bin
		fi
        if [[ -d /projects/${VHOST}/fcgi-bin ]]; then
        	chown root.eiadm /projects/${VHOST}/fcgi-bin
        	chmod 775 /projects/${VHOST}/fcgi-bin
	fi
	if [[ -d /projects/${VHOST}/etc ]]; then
                id pubinst > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                        chown pubinst.apps /projects/${VHOST}/etc
                else
                        chown root.apps /projects/${VHOST}/etc
                fi

        	chmod 750 /projects/${VHOST}/etc
	fi
        if [[ -d /projects/${VHOST}/data ]]; then
                id pubinst > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                        chown pubinst.apps /projects/${VHOST}/data
                        chmod 755 /projects/${VHOST}/data
                else
                        chown root.eiadm /projects/${VHOST}/data
                        chmod 775 /projects/${VHOST}/data
                fi
	fi
  else
  # /projects/{$VHOST} didn't exist so lets look in /www/${VHOST}
        if [[ -d /www/${VHOST} ]]; then
        echo "Setting permissions on  /www/${VHOST}"
		chown root.eiadm /www/${VHOST}
		chmod 775 /www/${VHOST}
	fi
        if [[ -d /www/${VHOST}/htdocs ]]; then
                id pubinst > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                        chown pubinst.apps /www/${VHOST}/htdocs
                        chmod 755 /www/${VHOST}/htdocs
                else
                        chown root.eiadm /www/${VHOST}/htdocs
                        chmod 775 /www/${VHOST}/htdocs
                fi
        fi
        if [[ -d /www/${VHOST}/config ]]; then
               for FILE in `ls /www/${VHOST}/config/*conf`; do
                      grep "eiRotate" $FILE > /tmp/line
                      if [[ $? -eq 0 ]]; then
                        grep umask /tmp/line > /dev/null
                        if [[ $? -ne 0 ]]; then
                           echo "    Adding umask line to eiRotate stanzas in $FILE"
                           cp $FILE ${FILE}.bak
                           sed -e "s/\/eiRotate/\/eiRotate -umask 027/" $FILE > /tmp/httpd.conf && mv /tmp/httpd.conf  $FILE
                        fi
                     fi
                done
                chown -R root.eiadm /www/${VHOST}/config
                find /www/${VHOST}/config -type d -exec chmod 770 {} \;
                find /www/${VHOST}/config -type f -exec chmod 660 {} \;
	fi
        if [[ -d /www/${VHOST}/cgi-bin ]]; then
        	chown root.eiadm /www/${VHOST}/cgi-bin
        	chmod 775 /www/${VHOST}/cgi-bin
	fi
  fi
  # if permlist.cfg file exists .. .then call set_permissions.sh
  if [ -f "/projects/${VHOST}/config/permlist.cfg" ]; then
     cat /projects/${VHOST}/config/permlist.cfg | /lfs/system/tools/configtools/set_permissions.sh
  fi
  # if vhostpermlist.cfg file exists .. .then call set_permissions.sh
  if [ -f "/projects/${VHOST}/config/vhostpermlist.cfg" ]; then
     cat /projects/${VHOST}/config/vhostpermlist.cfg | /lfs/system/tools/configtools/set_permissions.sh
  fi
}

set_global_server_perms ()
{

   if [[ ! -f /etc/apachectl ]]; then
        echo "/etc/apachectl not found. Please ensure IHS has been installed"
        echo "Exiting..."
        exit 1
   elif [[ -h /etc/apachectl ]]; then
        HTTPDIR=`ls -al /etc/apachectl | cut -d">" -f2 | cut  -d"/" -f3`
        DESTDIR=`ls -al /etc/apachectl | cut -d">" -f2 | cut  -d"/" -f1-3| sed 's/ //g'`
   fi

   FIXLEVEL=`cat ${DESTDIR}/version.signature | awk '{print $4}'`

   if [[ -d /projects/${HTTPDIR} ]]; then
        echo "Setting permissions on  /projects/${HTTPDIR}"
        chown root.eiadm /projects/${HTTPDIR}
        chmod 775 /projects/${HTTPDIR}
        if [[ -d /projects/${HTTPDIR}/content ]]; then
                chown -R root.eiadm /projects/${HTTPDIR}/content
                find /projects/${HTTPDIR}/content -type d -exec chmod 775 {} \;
                find /projects/${HTTPDIR}/content -type f -exec chmod 664 {} \;
        fi
        if [[ -d /projects/${HTTPDIR}/conf ]]; then
               for FILE in `ls /projects/${HTTPDIR}/conf/*conf 2>/dev/null`; do
                      grep "eiRotate" $FILE > /tmp/line
                      if [[ $? -eq 0 ]]; then
                        grep umask /tmp/line > /dev/null
                        if [[ $? -ne 0 ]]; then
                           echo "    Adding umask line to eiRotate stanzas in $FILE"
                           cp $FILE ${FILE}.bak
                           sed -e "s/\/eiRotate/\/eiRotate -umask 027/" $FILE > /tmp/httpd.conf && mv /tmp/httpd.conf  $FILE
                        fi
                     fi
                done
                chown -R root.eiadm /projects/${HTTPDIR}/conf
                find /projects/${HTTPDIR}/conf -type f -name "plugin*" -exec chgrp apps {} \; 
                find /projects/${HTTPDIR}/conf -type f -name "*.map" -exec chgrp apps {} \; 
                find /projects/${HTTPDIR}/conf -type d -exec chmod 775 {} \;
                find /projects/${HTTPDIR}/conf -type f -exec chmod 660 {} \;
                find /projects/${HTTPDIR}/conf -type f -name "plugin*" -exec chmod 640 {} \;
                find /projects/${HTTPDIR}/conf -type f -name "*.map" -exec chmod 640 {} \;
        fi
        if [[ -d /projects/${HTTPDIR}/etc ]]; then
                chown root.eiadm /projects/${HTTPDIR}/etc
                chmod 775 /projects/${HTTPDIR}/etc
                find /projects/${HTTPDIR}/etc -type d -exec chown root.eiadm {} \;
                find /projects/${HTTPDIR}/etc -type f -exec chown root.apps {} \;
                find /projects/${HTTPDIR}/etc -type d -exec chmod 775 {} \;
                find /projects/${HTTPDIR}/etc -type f -exec chmod 640 {} \;
        fi
   fi
   # if permlist.cfg file exists .. .then call set_permissions.sh
   if [ -f "/projects/${HTTPDIR}/conf/permlist.cfg" ]; then
      cat /projects/${HTTPDIR}/conf/permlist.cfg | /lfs/system/tools/configtools/set_permissions.sh
   fi
   # if globalpermlist.cfg file exists .. .then call set_permissions.sh
   if [ -f "/projects/${HTTPDIR}/conf/globalpermlist.cfg" ]; then
      cat /projects/${HTTPDIR}/conf/globalpermlist.cfg | /lfs/system/tools/configtools/set_permissions.sh
   fi
} 

