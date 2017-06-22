#!/bin/ksh

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

if lslpp -l | grep -qi mq ; then
	sysinfo=$(lssys -x csv -n -l systemtype,custtag,realm | grep -v "^#")
	hardware=$(print $sysinfo | awk -F "," '{print $2}')
	cust=$(print $sysinfo | awk -F "," '{print $3}')
	zone=$(print $sysinfo | awk -F "," '{print substr($4,0,1)"z"}')
	os=$(uname -s)
	
	unset  LIBPATH
	unset  LD_LIBRARY_PATH
	
	mqver=`/usr/bin/dspmqver | grep -E "Version"`
   mqver=${mqver##* }
	mqver=${mqver:-UNK}
	
	mqname=`/usr/bin/dspmqver | grep -E "Name"`
	mqname=${mqname#Name:        }
	mqname=${mqname:-UNK}
	mqname=`print $mqname | tr " " "_"`

	echo "dis channel(*)" > /tmp/channels.in
	echo "end" >> /tmp/channels.in
	chmod 755 /tmp/channels.in
	
	set -A QMGRS  `su - mqm -c 'dspmq`
	if [ ${#QMGRS[*]} -lt 1 ]; then
		print "MQCLIENT_${mqname}_${mqver} Client_Connection ${cust} ${host} ${os} ${hardware} ${zone}"
	else 
		i=0
		while [[ $i -lt ${#QMGRS[*]} ]]; do
			if  print ${QMGRS[$i]} | grep -iEq "QMNAME|STATUS" ; then
				QMGR=${QMGRS[$i]}
				QMGR=${QMGR#*\(}
				QMGR=${QMGR%%\)*}
			
				((i=i+1))
				STATUS=${QMGRS[$i]}
				STATUS=${STATUS#*STATUS\(}
				STATUS=${STATUS%%\)*}
			
				((i=i+1))	
			
				if ! print $QMGR | grep -iq dummy ; then
					if print $STATUS | grep -iq "running" ; then	    
						su - mqm -c "runmqsc ${QMGR} < /tmp/channels.in" > /tmp/channels.out
						INSTANCE_LIST=`grep "CHANNEL(" /tmp/channels.out | grep -v "(SYSTEM" | grep -v "CLNTCONN" | tr -d " "`
						for instance in ${INSTANCE_LIST}; do
							print "MQM_"${mqname}"_"${mqver} "QMGR("${QMGR}")"${instance} ${cust} ${host} ${os} ${hardware} ${zone} ${STATUS}
						done
					else
						print "MQM_"${mqname}"_"${mqver} "QMGR_STOPPED" ${cust} ${host} ${os} ${hardware} ${zone} ${STATUS}
					fi
				else
					print "Dummy queue manager ignored"
				fi
			else
				((i=i+1))
			fi
		done
	fi
fi
