#!/bin/bash
# Poll WXS Catalog Service for status and grid data
# Usage: check_catalog.sh [-command [-arg1 -arg2 ...]]
#        Commands: -quorumstatus, -routetable, -containers, -mapsizes, etc....
#		 Basically a simple wrapper to make the initial xsadmin.sh command easier to use
#        See http://publib.boulder.ibm.com/infocenter/wxsinfo/v7r1/topic/com.ibm.websphere.extremescale.admin.doc/txsxsadmin.html 

#--- Function definitions ---#
print_usage () {
	echo "Usage: check_catalog.sh [-command [-arg1 -arg2 ...]]"
	echo "  Commands: -quorumstatus, -routetable, -containers, -mapsizes, etc...."
	echo "  This is a simple wrapper to make the initial xsadmin.sh command easier to use"
	echo "  See http://publib.boulder.ibm.com/infocenter/wxsinfo/v7r1/topic/com.ibm.websphere.extremescale.admin.doc/txsxsadmin.html"
	echo "  or run xsadmin.sh with no arguments for more options."
}

build_catalog_list () {
	catalogNodes=""
	for cce in $catalogClusterEndPoints; do
		cceNode=`echo $cce|awk '{split($0,c,":"); print c[2]}'`
		if [ "$catalogNodes" == "" ]; then
			catalogNodes=$cceNode
		else
			catalogNodes="$catalogNodes $cceNode"
		fi
	done
}

#--- Global variables ---#
USER=webinst
WXSTOOLS=/lfs/system/tools/wxs

# Use the v8.6 eXtremeScale install if its present, if not default to v7.1
if [ -d /usr/WebSphere86/eXtremeScale ]; then
    WXSDIR=/usr/WebSphere86/eXtremeScale
else
    WXSDIR=/usr/WebSphere/eXtremeScale71
fi

if [ ! -d "$WXSDIR" ]; then
   echo "eXtremScale is not installed on this node at $WXSDIR"
   exit 1
fi

OGBIN=${WXSDIR}/ObjectGrid/bin
PROPDIR=/projects/wxs/properties
GRIDDIR=/projects/wxs/grids
HOST=`hostname -s`

if [ -z "$1" ] || [ "$1" == "help" ]; then
	print_usage
	exit 1
fi
COMMANDS=$*

#--- Find catalog prop file ---#
#PROPFILE="${PROPDIR}/wxs_catalog.properties"
#PROPFILES=`ps -ef |grep \-serverProps |awk -F'serverProps' {'print $2'} |awk {'print $1'} |grep catalog`
PROPFILES=`ls ${PROPDIR}/wxs*catalog.properties`
if [[ -z $PROPFILES ]]; then
	echo "ERROR: Server properties file not found. ($PROPFILE)"
	#echo "ERROR: There are no running catalog processes."
	exit 1
fi

getStatus(){
PROPFILE=$1
#--- Get catalog list, check if local node is catalog ---#
cceLine=`grep '^catalogClusterEndPoints=' $PROPFILE`
catalogClusterEndPoints=`echo ${cceLine#*=} |sed -e "s/,/ /g"`
build_catalog_list
echo $catalogNodes|grep $HOST > /dev/null 2>&1
if [ $? -ne 0 ]; then
	#-- use plex-local catalog --#
	plex=`lssys -n -l realm |tail -1 |awk '{split($3,p,"."); print p[3]}' |cut -c2`
	for node in $catalogNodes; do
		nplex=`echo $node|cut -c2`
		if [ "$nplex" == "$plex" ]; then
			catalogNode=$node
			break
		fi
	done
	echo "Using local plex catalog ($catalogNode)"
else
	catalogNode=$HOST
	echo "Using local host catalog ($catalogNode)"
fi

#--- Pull necessary ports ---#
listenerPortLine=`grep '^listenerPort=' $PROPFILE`
jmxPortLine=`grep '^JMXServicePort=' $PROPFILE`
listenerPort=${listenerPortLine#*=}
jmxPort=${jmxPortLine#*=}

echo "------------------------------------------------------------------------"
${OGBIN}/xsadmin.sh -ch $catalogNode -bp $listenerPort -p $jmxPort $COMMANDS |grep -v 'sample only' |grep -v 'fully supported'
}

for PROPFILE in $PROPFILES; do 
  getStatus $PROPFILE
  echo
done
