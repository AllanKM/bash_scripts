#!/bin/ksh

if [ `whoami` != "root" ]; then
      echo "You must run this script as root"; exit 1
fi

if [ $# -gt 0 ]
  then
    echo "USAGE:  $0"
    exit 2
fi
 
PRODUCT=WAS
TEMP_FILE=/tmp/node_ear_list.`date +'%Y%m%d'`

cat /dev/null > $TEMP_FILE

get_host_info()
{
    hardware=$(lssys -l systemtype ${host} | grep -v ${host} | awk '{print $3}' | cut -f2-3 -d.)
    cust=$(lssys -l custtag ${host} | grep -v ${host} | awk '{print $3}')
    zone=$(lssys -l realm ${host} | grep -v ${host} | awk '{print $3}' | cut -f1 -d.)z
    if [ "$(lssys -l realm ${host}  | grep -v ${host} | awk '{print $3}' | cut -f2 -d.)" = "st" ]
      then
			is_staging="staging"
	else
		is_staging=""
    fi
}

print_host_info()
{
    printf "%-10s %-30s %-8s %-8s %-8s %-8s %-4s %-10s %-15s\n" ${PRODUCT}_${VERSION} ${EARINST} ${cust} ${host} ${os} ${hardware} $(echo ${zone} ${is_staging} ${DMGR} | awk '{print toupper($1),$2,$3}') 
}

host=`uname -n`
case $host in
        *e0) 
                host=`echo $host | sed "s/e0$/e1/"`
                ;;
        [adg][ct][0-9][0-9][0-9][0-9]?e1)
                HOST=`echo $host | sed "s/e1$//"`
                ;;
        rdu*|stl*|den*)
                host="${host}e1"
                ;;              
esac

SITE=$(echo ${host} | cut -c1-2)

is_staging=""

#set -x

os=$(uname -s)
if [ "${os}" = "AIX" ]
  then
	get_host_info
    if [ -d /usr/W*/[AD]*/ ]
      then
			ear_list=`find /usr/WebSp* -name "deployment.xml" | grep /config/ | grep -vE "/PortalServer/|/backup/|systemApps" | awk 'BEGIN { FS = "/" }; { if ($5 == "profiles") { gsub(/ /,"++",$11);print "/"$2"/"$3"/"$4";"$9";"$11} else { gsub(/ /,"++",$9);print "/"$2"/"$3"/"$4";"$7";"$9} }'`
			for ear in $ear_list; do
		   	INSTANCE=`echo $ear | cut -f1 -d";"`
				if [ -f ${INSTANCE}/properties/version/BASE.product ]; then
				  VERSION=`grep "<version>" ${INSTANCE}/properties/version/BASE.product 2>/dev/null | sed "s/[^0-9]//g"`
				elif [ -f ${INSTANCE}/properties/version/WAS.product ]; then
				  VERSION=`grep "<version>" ${INSTANCE}/properties/version/WAS.product 2>/dev/null | sed "s/[^0-9]//g"`
          fi
			 EARINST=`echo $ear | cut -f3 -d";"`
			 DMGR=`echo $ear | cut -f2 -d";"`
			 print_host_info
        done
    fi

fi

exit
