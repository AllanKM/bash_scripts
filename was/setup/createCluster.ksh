#!/bin/ksh
####################################################################################
# Script Name - createCluster.ksh
# Author - Chris Kalamaras
# Date - 20050222
# Purpose - This script is basically a wrapper for the clusterAction.jacl script.
#           It will create an app cluster in each plex for each app specified at the command line.
#           It will also add each node specified by the wasnodes var as cluster members in the /
#           respective clusters
####################################################################################

if [ `whoami` != "root" ]; then
      echo "You must run this script as root"; exit 1
fi

if [[ $# -lt 4 ]];then
   print "Usage: /lfs/system/tools/was/setup/createCluster.ksh <customer> <prd|spp|dss|pre|cdt> <p1|p3|p5|all|span> <vhost> <nodegroup> <coregroup> <template> <wasversion> <app> [<app2> <app3> ...] "
   print "  example: createCluster.ksh ibmcom prd all ibmcom_host was.ibm.www ibmcom_coregroup ei_template_https 51 app1 app2"
   exit
fi

#VARIABLE DEFINITIONS 
wasuser=webinst
cust=$1
env=$2
plex=$3
vhost=$4
typeset -u nodelist=$5
coregroup=$6
template=$7
version=`echo $8 | sed -e "s/\.//g"`
apps=`echo $* | cut -d' ' -f9-`
set -A appnames $apps
sessid='SESSION_'${cust}${env}
#jaclpath="/lfs/system/tools/was/scripts"
jythonpath="/lfs/system/tools/was/lib/"
wasnodes=`lssys -q -e role==${nodelist}`
coreexists=1

#check if coregroup exists
# $1 = profilename $2 = version
checkCoreGroup() {
  cell=`echo $1 | awk -F"Manager" {'print $1'}`
  if [ -d "/usr/WebSphere${2}/AppServer/profiles/${1}/config/cells/${cell}/coregroups/${coregroup}" ]; then
    coreexists=1
    echo "Coregroup exists"
  else
    coreexists=0
    echo "Coregroup does not exist"
  fi
}

#Set wasbin variable based on version (left case in place for future possible use)
case $version in
	*)	# Search for all profiles, prompt if more than one
		DIR="/usr/WebSphere${version}/AppServer"
		i=0
		for profile in `ls ${DIR}/profiles/`; do
			wasList[$i]="${DIR}/profiles/${profile}"
			i=$(($i+1))
		done
		if [ $i -gt 1 ]; then
			echo "WebSphere environment(s) and profiles:"
			i=0
			while [[ ${wasList[$i]} != "" ]]; do
				echo "        [$i] ${wasList[$i]}"
				i=$(($i+1))
			done
			printf "\nEnter number for the WebSphere environment you want to use: "
			read $choice
			echo "Using: ${wasList[$choice]}"
			PROFILE=$(echo ${wasList[$choice]} |awk '{split($0,profile,"/"); print profile[6]}')
			wasbin="${wasList[$choice]}/bin"
			checkCoreGroup $PROFILE $version
		else
			PROFILE=$(echo ${wasList} |awk '{split($0,profile,"/"); print profile[6]}')
			wasbin="${wasList}/bin"
            checkCoreGroup $PROFILE $version
		fi	
		;;
esac

if [[ $plex == "all" ]]; then
	list="p1 p3 p5"
elif [[ $plex == "span" ]]; then
	list=$plex
elif [[ $plex == p1 || $plex == p3 || $plex == p5 ]]; then
	list=$plex
else
	echo "Invalid value for plex: ${plex}"
	echo "Exiting..."
	exit 1
fi

#DISPLAY CLUSTERS/APPSERVERS TO BE CREATED   
for realm in $list; do
	i=0
	echo "THE FOLLOWING CLUSTER AND MEMBERS WILL BE CREATED FOR "${realm}":"
	while [[ ${appnames[$i]} != "" ]]; do
		if [[ $env == "prd" && $plex != "span" ]]; then
			cluster=${realm}_cluster_${cust}_${appnames[$i]}
		elif [[ $env == "spp" && $plex != "span" ]]; then
			cluster=${realm}_${env}_cluster_${cust}_${appnames[$i]}
        elif [[ $env == "dss" && $plex != "span" ]]; then
            cluster=${realm}_${env}_cluster_${cust}_${appnames[$i]}			
		elif [[ $plex == "all" ]]; then
			cluster=${realm}_${env}_cluster_${cust}_${appnames[$i]}
		elif [[ $plex == "span" ]]; then
			cluster=cluster_${cust}_${appnames[$i]}
		else 
			cluster=${env}_cluster_${cust}_${appnames[$i]}
		fi
		#Set Cookie id
		cookid=${sessid}_${appnames[$i]}
		echo "   CLUSTER: "$cluster
		echo "          VHOST:     "$vhost
		if [[ $coreexists -eq 1 ]]; then
			echo "          COREGROUP: "$coregroup
		else
			echo "          COREGROUP: "$coregroup" - (Will be created)"
		fi
		echo "          TEMPLATE:  "$template
		echo "          CookieID:  "$cookid
		#FOR EACH WASNODE, DETERMINE THE PLEX AND ADD IT AS A MEMBER OF THE RESPECTIVE APP CLUSTERS
		for node in $wasnodes; do
			noderealm=`lssys $node | grep " realm" | awk 'BEGIN { FS = "." } ; { print $3 }'`	
			if [[ $realm == $noderealm || $realm == "span" ]]; then
				member=${node}_${cust}_${appnames[$i]}
				echo "      MEMBER: "$member  
			fi
		done    
		i=$(($i+1))
    done
done


read response?"Enter 'y' if this is correct: "
print ""
if [[ "$response" != "y" ]]; then
    print "Goodbye."
    exit 1  
fi

##CREATE APPLICATION SPECIFIC CLUSTERS FOR EACH PLEX
for realm in $list; do
	i=0
	while [[ ${appnames[$i]} != "" ]]; do
		if [[ $env == "prd" && $plex != "span" ]]; then
			cluster=${realm}_cluster_${cust}_${appnames[$i]}
		elif [[ $env == "spp" && $plex != "span" ]]; then
			cluster=${realm}_${env}_cluster_${cust}_${appnames[$i]}
	    elif [[ $env == "dss" && $plex != "span" ]]; then
            cluster=${realm}_${env}_cluster_${cust}_${appnames[$i]}
		elif [[ $plex == "all" ]]; then
			cluster=${realm}_${env}_cluster_${cust}_${appnames[$i]}
		elif [[ $plex == "span" ]]; then
			cluster=cluster_${cust}_${appnames[$i]}
		else 
			cluster=${env}_cluster_${cust}_${appnames[$i]}
		fi
		#Set Cookie id
		cookid=${sessid}_${appnames[$i]}
		echo "Creating cluster "$cluster"..."
		case $version in
			61|70|85) LOGGING="-tracefile /logs/was${version}/${PROFILE}/wsadmin.${cluster}.traceout" ;;
			*) LOGGING="" ;;
		esac
		#su - $wasuser -c "${wasbin}/wsadmin.sh ${LOGGING} -f ${jaclpath}/clusterAction.jacl -action create -cluster $cluster"
		su - $wasuser -c "${wasbin}/wsadmin.sh -lang jython ${LOGGING} -f ${jythonpath}/cluster.py -action create -cluster $cluster"
		echo "Done"
	
		#FOR EACH WASNODE, DETERMINE THE PLEX AND ADD IT AS A MEMBER OF THE RESPECTIVE APP CLUSTERS
		for node in $wasnodes; do
			noderealm=`lssys $node | grep " realm" | awk 'BEGIN { FS = "." } ; { print $3 }'`
			member=${node}_${cust}_${appnames[$i]}
			if [[ $realm == $noderealm || $realm == "span" ]]; then
				echo "Adding "$node" to "$cluster
				case $version in
					61|70|85) LOGGING="-tracefile /logs/was${version}/${PROFILE}/wsadmin.${member}.traceout" ;;
					*) LOGGING="" ;;
				esac
				#su - $wasuser -c "${wasbin}/wsadmin.sh ${LOGGING} -f ${jaclpath}/clusterAction.jacl -action add -cluster $cluster -member $member -node $node -template $template -vhost $vhost -cookie $cookid"
				su - $wasuser -c "${wasbin}/wsadmin.sh -lang jython ${LOGGING} -f ${jythonpath}/cluster.py -action add -cluster $cluster -member $member -node $node -template $template -vhost $vhost -cookie $cookid -coregroup $coregroup"
				echo "Done"
			fi
		done
		i=$(($i+1))
		## TEMPORARY CORE GROUP ASSIGNMENT CODE -- REMOVE ONCE JYTHON CAN BE USED AGAIN
		## (WAS 6.0 doesn't like jython much, as it is mising optional libraries)
		#if [[ $coregroup != "DefaultCoreGroup" && $version != "51" && $coreexists -eq 1 ]]; then
		#	echo "Moving cluster ${cluster} into core group ${coregroup}..."
		#	/lfs/system/tools/was/setup/manageCoreGroup.sh $version moveCluster $cluster DefaultCoreGroup $coregroup
		#	elif [[ $coregroup != "DefaultCoreGroup" && $version != "51" && $coreexists -eq 0 ]]; then
		#	echo "Creating coregroup ${coregroup}..."
		#	/lfs/system/tools/was/setup/manageCoreGroup.sh $version create $coregroup $PROFILE
		#	echo "Moving cluster ${cluster} into core group ${coregroup}..."
		#	/lfs/system/tools/was/setup/manageCoreGroup.sh $version moveCluster $cluster DefaultCoreGroup $coregroup
		#fi
	done
done
