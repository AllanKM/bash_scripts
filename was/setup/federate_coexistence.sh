#!/bin/ksh

# usage:   federate.sh <version> <dmgr> <soap port> [<coregroup>] [<profile>]

# Federates node to the specified DM
#
#   Change History: 
#     Lou Amodeo    03-01-2013  Add support for Websphere 8.5 
#
HOST=`/bin/hostname -s`
FULLVERSION=${1:-70023}
VERSION=`echo $FULLVERSION | cut -c1-2`
DM=$2
SOAPPORT=${3:-8879}
WASENV=`echo $DM |cut -c3-5`
BASEDIR="/usr/WebSphere${VERSION}"
APPDIR="${BASEDIR}/AppServer"
VERSION=`echo $VERSION | cut -c1-2`
REALM=`lssys -1 -l realm -e host==${HOST} | awk 'BEGIN { FS = "." }; { print $3 }'`
echo $4 | grep group
if [ $? -eq 0 ]; then
		COREGROUP=$4
        PROFARG=$5
else
        PROFARG=$4
fi

case $PROFARG in
	*anager) echo "ERROR: You cannot federate a DM to a DM."
			 exit 1
		;;
	*)	if [ "$PROFARG" == "" ]; then
            PROFILE=$HOST
        elif [ "$PROFARG" == "$HOST" ]; then
              PROFILE=$PROFARG
		else
              PROFILE=${HOST}_${PROFARG}
		fi
		;;
esac

PRODFILE="${APPDIR}/properties/version/WAS.product"
PORTFILE="/lfs/system/tools/was/conf/v${VERSION}ports.nodeagent.prop"
CERT="${APPDIR}/profiles/${PROFILE}/etc/ei_*_was.jks"
NEWCELL=${DM%%Manager}
CELL=`grep WAS_CELL= ${APPDIR}/profiles/${PROFILE}/bin/setupCmdLine.sh`

case $VERSION in
	85) AUTH=`echo $NEWCELL|awk -F"85" {'print $2'} | cut -c1-2 |tr "[:lower:]" "[:upper:]"` ;;
    70) AUTH=`echo $NEWCELL|awk -F"70" {'print $2'} | cut -c1-2 |tr "[:lower:]" "[:upper:]"` ;;
	61) AUTH=`echo $NEWCELL|awk -F"61" {'print $2'} | cut -c1-2 |tr "[:lower:]" "[:upper:]"` ;;	
esac

HOST=$PROFILE
WAS_PROFILE_HOME=${APPDIR}/profiles/${PROFILE}

if [ "$COREGROUP" == "" ]; then
	ARGS="$DM $SOAPPORT -profileName $PROFILE -portprops $PORTFILE -noagent"
else
	ARGS="$DM $SOAPPORT -profileName $PROFILE -portprops $PORTFILE -coregroupname $COREGROUP -noagent"
fi

case $WASENV in
	prd|pre|spp|cdt) ;;
	*) #Need to check legacy naming convention
		LEGACYWASENV=`echo $DM |cut -c3`
		case $LEGACYWASENV in
			p) WASENV=prd ;;
			s) WASENV=pre ;;
			t) WASENV=cdt ;;
		esac
	;;
esac

echo "Checking WebSphere version"
grep version\> ${PRODFILE} | cut -d">" -f 2 | cut -d"<" -f 1
if [ $? -ne 0 ]; then
    echo "Install WebSphere before running $0"
    echo "exiting..."
    exit 1
fi	

echo "Checking for EI cert and SSL Security configuration"
ls $CERT 
if [ $? -ne 0 ]; then
    echo "Setting up SSL Security"
    /lfs/system/tools/was/setup/was_ssl_setup.sh $VERSION $AUTH $WASENV $PROFILE
    if [ $? -ne 0 ]; then
		echo "SSL Security configuration failed"
		echo "exiting...."
    fi
fi

echo $CELL | grep $HOST > /dev/null
if [ $? -eq 0 ]; then
    echo "Federating with $DM"
    result=`su - webinst -c "/usr/WebSphere${VERSION}/AppServer/bin/addNode.sh $ARGS"`
    /lfs/system/tools/was/setup/was_perms.ksh
    echo "Starting nodeagent"
	result=`su - webinst -c "$WAS_PROFILE_HOME/bin/startServer.sh nodeagent"`
else
    echo "$HOST is already federated with $CELL"
fi
