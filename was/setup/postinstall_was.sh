#!/bin/bash
# Post WAS install configurations
# Usage: posinstall_was.sh VERSION [COREGROUP] [PROFILE]
#
#   Change History: 
#     Lou Amodeo    03-01-2013  Add support for Websphere 8.5 
#

checkCoreGroup() {
  if [ -d "/usr/WebSphere${2}/AppServer/profiles/${1}/config/cells/${3}/coregroups/${4}" ]; then
    coreexists=1
    echo "Coregroup exists"
  else
    coreexists=0
    echo "Coregroup does not exist"
  fi
}

HOST=`/bin/hostname -s`
FULLVERSION=${1:-70023}
VERSION=`echo $FULLVERSION | cut -c1-2`
COREGROUP="DefaultCoreGroup"
coreexists=1
until [ -z "$2" ] ; do
	case $2 in
		*[Cc]ore[Gg]roup) COREGROUP=$2 ;;
		*anager)
				PROFILE=$2
				#Set DMCELL name (remove Manager) for later DM check
				DMCELL=${PROFILE%%Manager}
			;;
		*)
				if [ "$2" == "" ]; then
					PROFILE=$HOST
				else
					PROFILE=$2								
				fi
			;;
	esac
	shift
done

# Set Globals
case $VERSION in
	61*|70*|85*)
		if [ "$PROFILE" == "" ]; then 
			#Grab default profile
			defScript=/usr/WebSphere${VERSION}/AppServer/properties/fsdb/_was_profile_default/default.sh
    		DEFPROFILE=$(grep setup $defScript|awk '{split($0,pwd,"WAS_USER_SCRIPT="); print pwd[2]}')
    		PROFILE=$(echo $DEFPROFILE|awk '{split($0,profile,"/"); print profile[6]}')
			if [ "$PROFILE" == "" ]; then 
    			echo "Failed to find Profile for post install configuration"
    			echo "exiting...."
    			exit 1
			fi
		fi
		PROFSETUP="/usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}/bin/setupCmdLine.sh"
    	WAS_NODE=$(grep WAS_NODE= $PROFSETUP|awk '{split($0,pwd,"WAS_NODE="); print pwd[2]}')
    	WAS_CELL=$(grep WAS_CELL= $PROFSETUP|awk '{split($0,pwd,"WAS_CELL="); print pwd[2]}')
		WAS_HOME="/usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}"
		if [ "$DMCELL" != "" ] || [ -d /usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}/logs/dmgr ]; then
			SERVER=dmgr
			HEAP=heap:512/1024
		elif [ -d /usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}/logs/nodeagent ]; then
			SERVER=nodeagent
			HEAP=heap:128/256
		elif [ -d /usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}/logs/server1 ]; then
			SERVER=server1
			HEAP=heap:128/256
		else 
			echo "Failed to find dmgr or nodeagent for profile: $PROFILE"
			echo "exiting...."
			exit 1
		fi
		checkCoreGroup $PROFILE $VERSION $WAS_CELL $COREGROUP
		;;
    *)
    	echo "Not configured for version $VERSION"
		echo "exiting....."
		exit 1
		;;
esac

echo "Using directory: $WAS_HOME"
NODE=`grep WAS_NODE= $WAS_HOME/bin/setupCmdLine.sh | cut -f2 -d=`
if [ "$NODE" == "" ]; then
	echo "Failed to determine WAS_NODE entry in setupCmdLine.sh ... exiting"
	exit 1
fi

if [ -x $WAS_HOME/bin/wsadmin.sh ]; then
	WSADMIN=$WAS_HOME/bin/wsadmin.sh
else
	echo "Failed to locate $WAS_HOME/bin/wsadmin.sh ... exiting"
	exit 1
fi
SCRIPTS_HOME=/lfs/system/tools/was/scripts
WASLIB=/lfs/system/tools/was/lib
USER=webinst
GROUP=mqm

echo "Checking status of $SERVER ..."
adminStatus=$($WAS_HOME/bin/serverStatus.sh $SERVER |tail -1|grep STARTED)
if [[ -z $adminStatus ]]; then
	echo "Starting $ADMINSERVER ..."
    /lfs/system/bin/rc.was --wasdir ${WAS_HOME}/bin start $SERVER
fi


# Set min/max heap sizes
if [[ -e $WASLIB/server.py ]]; then
    echo "Adjusting min/max heap sizes for $SERVER ...."
	LOGGING="-tracefile /logs/was${VERSION}/${PROFILE}/wsadmin.${SERVER}-heap.traceout"
 	su - webinst -c "$WSADMIN $LOGGING -f $WASLIB/server.py  -action modify -server $SERVER -attr $HEAP" >/dev/null
 	if [ $? -ne 0 ];  then
     	echo "Failed to set min/max heap sizes ... exiting"
    	exit 1
    fi
fi
 

# Set log rotation, webinst/mqm and disable auto-sync for nodeagents
if [[ -e $WASLIB/node.py ]]; then
    echo "Configuring $SERVER with EI Standards ...."
	LOGGING="-tracefile /logs/was${VERSION}/${PROFILE}/wsadmin.${SERVER}-standards.traceout"
 	su - webinst -c "$WSADMIN -f $WASLIB/node.py -action setup -node $NODE -type $SERVER" >/dev/null
 	if [ $? -ne 0 ]; then
       	echo "Failed to configure $SERVER with EI standards ... exiting"
    	exit 1
	fi
fi

# Create JDBC variables for cell if dmgr
DB2JDBC="DB2UNIVERSAL_JDBC_DRIVER_PATH"
DB2JDBCN="DB2UNIVERSAL_JDBC_DRIVER_NATIVEPATH"
if [ "$SERVER" == "dmgr" ]; then
	echo "Creating cell-scoped JDBC driver environment variables ..."
	DB2JVAR="$DB2JDBC=/home/webinst/sqllib/java"
	DB2NVAR="$DB2JDBCN=/home/webinst/sqllib/java"
	/lfs/system/tools/was/setup/manageVariables.sh version=$VERSION profile=$PROFILE create scope=cell:$WAS_CELL $DB2JVAR $DB2NVAR
fi

# Configure the Core Group coordinators if a nodeagent, also remove JDBC variables
if [ "$SERVER" == "nodeagent" ]; then
	if [ $coreexists -eq 0 ]; then
		echo "Creating core group $COREGROUP"
		/lfs/system/tools/was/setup/manageCoreGroup.sh $VERSION create $COREGROUP $PROFILE
	fi
	# Check if nodeagent is already in the core group
	grep '<coreGroupServers' ${WAS_HOME}/config/cells/${WAS_CELL}/coregroups/${COREGROUP}/coregroup.xml |grep $WAS_NODE |grep nodeagent > /dev/null
	if [ $? -eq 1 ]; then
		echo "Stopping nodeagent for core group move ..."
		/lfs/system/bin/rc.was --wasdir ${WAS_HOME}/bin stop $SERVER
		/lfs/system/tools/was/setup/manageCoreGroup.sh $VERSION moveServer $SERVER $WAS_NODE DefaultCoreGroup $COREGROUP $PROFILE
		echo "Starting nodeagent ..."
		/lfs/system/bin/rc.was --wasdir ${WAS_HOME}/bin stop $SERVER
	else
		echo "$WAS_NODE nodeagent already a member of $COREGROUP, no move required."
	fi
	echo "Configuring all current nodeagents as preferred coordinators for $COREGROUP ..."
	/lfs/system/tools/was/setup/manageCoreGroup.sh $VERSION set-preferred $COREGROUP nodeagent
	if [[ $COREGROUP =~ ^p[123]_* ]] || [[ $COREGROUP =~ ^pre_* ]] || [[ $COREGROUP =~ ^cdt_* ]] || [[ $COREGROUP =~ ^dss_* ]] ; then
		echo "Leaving $COREGROUP at default 1 coordinator ..."
	else
		echo "Configuring $COREGROUP for 3 coordinators ..."
		/lfs/system/tools/was/setup/manageCoreGroup.sh $VERSION set-coordinators $COREGROUP 3
	fi
	echo "Removing node-scoped JDBC driver environment variables ..."
	/lfs/system/tools/was/setup/manageVariables.sh version=$VERSION profile=$PROFILE delete scope=node:$WAS_NODE $DB2JDBC $DB2JDBCN
	
fi

if [[ $SERVER == "dmgr" ]]; then
	# Unpack the templates to the dmgr
	echo "Unpacking WAS $VERSION EI Application Server templates ...."
	cd ${WAS_HOME}/config/templates
	case $VERSION in
		61) tar -xf /lfs/system/tools/was/setup/was61_ei_templates.tar ;;
		70) tar -xf /lfs/system/tools/was/setup/was70_ei_templates.tar ;;
		85) tar -xf /lfs/system/tools/was/setup/was85_ei_templates.tar ;;
	esac
        # Set templates ownership and permissions
        chown -R webinst:eiadm ${WAS_HOME}/config/templates/servertypes
        chmod -R ug+rwx,g+s,o-rwx ${WAS_HOME}/config/templates/servertypes
	# Install adminconsole lock
	echo "Installing EI WebSphere administration console lockout for the primary admin user."
	/lfs/system/tools/was/setup/install_was_lock.sh $VERSION
fi

# Syncronize the changes with the node
if [ "$SERVER" == "nodeagent" ]; then
	echo "Syncing $NODE with the Deployment Manager ...."
 	su - webinst -c "$WSADMIN -f $WASLIB/node.py -action refresh -node $NODE -type $SERVER" >/dev/null
 	if [ $? -ne 0 ]; then
       	echo "Failed to syncronize $NODE with the Deployment Manager ... exiting"
    	exit 1
    fi
fi

# Restart
echo "Restarting $SERVER"
/lfs/system/bin/rc.was --wasdir ${WAS_HOME}/bin restart $SERVER

# Setup WAS TSM backup
echo "Setting up TSM backup for WAS ...."
if [ "$PROFILE" == "" ]; then
	/lfs/system/tools/was/setup/setup_tsm_backup.sh $VERSION
else
	/lfs/system/tools/was/setup/setup_tsm_backup.sh $VERSION $PROFILE
fi
## TSM backups now, no more config zips that would overlap
##if [ "$SERVER" == "dmgr" ]; then
##	echo "!! *** If this is NOT the primary dmgr, you must comment out the config backup crontab entry *** !!"
##fi

# Setup WAS logrotate
echo "Installing the logrotate configuration for WAS logs..."
/lfs/system/tools/was/setup/install_was_logrotate.sh
