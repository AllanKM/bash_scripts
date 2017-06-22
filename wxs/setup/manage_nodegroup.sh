#!/bin/bash
# Usage: manage_nodegroup.sh version=<61|70|85> group=<groupname> [nodes=<node1>[,<node2>,<nodeN>]] [profile=<name>]
HOST=`/bin/hostname -s`
WXSLIB="/lfs/system/tools/wxs/lib"
USER=webinst

checkNodeGroup() {
	group=$1
	for ng in `ls ${PROFROOT}/config/cells/${CELL}/nodegroups/`; do
		if [[ $group == $ng ]]; then
			return 1
		fi
	done
	return 0
}

createNodeGroup() {
	group=$1
	ACTION="-action create"
	LOGGING="-tracefile /logs/was${VERSION}/${PROFILE}/wsadmin.create-${group}.traceout"
	echo "Executing: $WSADMIN -f ${WXSLIB}/nodegroup.py $ACTION -group $group"
	echo "----------------------------------------------------------------------------------"
	su - $USER -c "$WSADMIN ${LOGGING} -f ${WXSLIB}/nodegroup.py $ACTION -group $group|grep -v '^WASX'|grep -v 'sys-package-mgr'"
}

addNodeToGroup() {
	node=$1
	group=$2
	ACTION="-action add"
	LOGGING="-tracefile /logs/was${VERSION}/${PROFILE}/wsadmin.add-${node}-${group}.traceout"
	echo "Executing: $WSADMIN -f ${WXSLIB}/nodegroup.py $ACTION -node $node -group $group"
	echo "----------------------------------------------------------------------------------"
	su - $USER -c "$WSADMIN ${LOGGING} -f ${WXSLIB}/nodegroup.py $ACTION -node $node -group $group|grep -v '^WASX'|grep -v 'sys-package-mgr'"
}

#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
		version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FULLVERSION=$VALUE; fi ;;
		group=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then NODEGROUP=$VALUE; fi ;;
		nodes=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then NODES=$VALUE; fi ;;
		profile=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROFILE=$VALUE; fi ;;
		*)	echo "#### Unknown argument: $1"
			echo "#### Usage: manage_nodegroup.sh version=<61|70|85> group=<groupname> [nodes=<node1>[,<node2>,<nodeN>]] [profile=<name>]"
			exit 1
			;;
	esac
	shift
done
VERSION=`echo $FULLVERSION | cut -c1-2`
ASROOT="/usr/WebSphere${VERSION}/AppServer"
if [ -z $PROFILE ]; then
	#Search for profiles
	i=0
	for profile in `ls ${ASROOT}/profiles/`; do
		profList[$i]="${profile}"
		i=$(($i+1))
	done
	#If more than one profile exists, prompt user to specify via command-line
	if [ $i -gt 1 ]; then
		echo "#### Please specify which profile to work with via command-line"
		echo "#### Usage: manage_nodegroup.sh version=<61|70|85> group=<groupname> [nodes=<node1>[,<node2>,<nodeN>]] [profile=<name>]"
		exit 1
	fi
	PROFILE=${profList}
fi
PROFROOT=${ASROOT}/profiles/${PROFILE}
CELL=$(grep WAS_CELL= ${PROFROOT}/bin/setupCmdLine.sh|awk '{split($0,a,"WAS_CELL="); print a[2]}')

#Set node list to profile if no node was specified
if [ -z $NODES ]; then
	NODES=$PROFILE
fi

if [ -x ${PROFROOT}/bin/wsadmin.sh ]; then
	WSADMIN="${PROFROOT}/bin/wsadmin.sh -lang jython -conntype NONE"
fi

#Verify node group is properly named for WXS
if [ `expr match "$NODEGROUP" '^ReplicationZone'` -eq 0 ]; then
	echo "#### Node group specified does not match the naming requirements for WebSphere eXtreme Scale."
	echo "#### Name must start with the string ReplicationZone"
	exit 1
else
	echo "Valid node group name: $NODEGROUP"
fi

#Check to see if group exists, if not create it.
checkNodeGroup $NODEGROUP
if [ $? -ne 1 ]; then
	echo "Node group $NODEGROUP does NOT exist - creating."
	createNodeGroup $NODEGROUP
else
	echo "Node group $NODEGROUP exists."
fi

#Add node(s) to group
nodeList=$(echo $NODES|sed -e 's/,/ /g')
for n in $nodeList; do
	addNodeToGroup $n $NODEGROUP
done

#Set normal WAS permissions
/lfs/system/tools/was/setup/was_perms.ksh
