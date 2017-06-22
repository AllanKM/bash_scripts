#!/bin/ksh
#   Usage: was_backup_config.sh [VERSION] [PROFILE]"
HOST=`hostname`
DATE1=`date +"%F"`
PROFILE=$2
FULLVERSION=${1:-51111}
VERSION=`echo $FULLVERSION | cut -c1-2`
BASEWASDIR="/usr/WebSphere${VERSION}"
#ARCHIVEDIR="/fs/site/was"
ARCHIVEDIR="/fs/backups/was"

if ls -d $BASEWASDIR/AppServer 2>/dev/null; then
	WAS_HOME="$BASEWASDIR/AppServer"
elif ls -d $BASEWASDIR/DeploymentManager 2>/dev/null; then
	WAS_HOME="$BASEWASDIR/DeploymentManager"
else
	echo "Failed to determine WAS_HOME"
	exit 1
fi

if [ $VERSION == "60" ] || [ $VERSION == "61" ] || [ $VERSION == "70" ]; then
	if [ "$PROFILE" == "" ]; then 
		#Grab default profile
		defScript=/usr/WebSphere${VERSION}/AppServer/properties/fsdb/_was_profile_default/default.sh
		DEFPROFILE=$(grep setup $defScript|awk '{split($0,pwd,"WAS_USER_SCRIPT="); print pwd[2]}')
		WAS_NODE=$(grep WAS_NODE= $DEFPROFILE|awk '{split($0,pwd,"WAS_NODE="); print pwd[2]}')
		PROFILE=$(echo $DEFPROFILE|awk '{split($0,profile,"/"); print profile[6]}')
		if [ "$PROFILE" == "" ]; then 
			echo "Failed to find the default profile"
			echo "exiting...."
			exit 1
		else
			WAS_HOME=${WAS_HOME}/profiles/$PROFILE
		fi
	else
		WAS_HOME=${WAS_HOME}/profiles/$PROFILE
		WAS_NODE=$PROFILE
	fi
else
	WAS_NODE=$HOST
fi

WAS_CELL=`grep WAS_CELL= ${WAS_HOME}/bin/setupCmdLine.sh | cut -d= -f2`

ls $ARCHIVEDIR/${WAS_CELL} >/dev/null 2>&1
if [ $? -ne 0 ]; then
	mkdir -p $ARCHIVEDIR/${WAS_CELL}
	chgrp -R eiadm $ARCHIVEDIR/${WAS_CELL}
	chmod -R g+rwxs,o-rwx $ARCHIVEDIR/${WAS_CELL}
fi

#Backup WAS configs
${WAS_HOME}/bin/backupConfig.sh $ARCHIVEDIR/${WAS_CELL}/${WAS_NODE}-${DATE1}.zip -nostop -logfile /logs/was${VERSION}/wasbackup.log
if [ -f "$ARCHIVEDIR/${WAS_CELL}/${WAS_NODE}-${DATE1}.zip" ]; then
	chgrp eiadm $ARCHIVEDIR/${WAS_CELL}/${WAS_NODE}-${DATE1}.zip
	chmod g+rw,o-rw $ARCHIVEDIR/${WAS_CELL}/${WAS_NODE}-${DATE1}.zip
fi

#Backup specific modified files
if [ ! -f "$ARCHIVEDIR/${WAS_CELL}/${WAS_NODE}-props-${DATE1}.tar" ]; then
	if [ "$VERSION" == "61" ] || [ $VERSION == "70" ]; then
		tar -cf $ARCHIVEDIR/${WAS_CELL}/${WAS_NODE}-props-${DATE1}.tar ${WAS_HOME}/bin/setupCmdLine.sh ${WAS_HOME}/properties/wsadmin.properties ${WAS_HOME}/properties/soap.client.props ${WAS_HOME}/properties/ssl.client.props
	else
		tar -cf $ARCHIVEDIR/${WAS_CELL}/${WAS_NODE}-props-${DATE1}.tar ${WAS_HOME}/bin/setupCmdLine.sh ${WAS_HOME}/properties/wsadmin.properties ${WAS_HOME}/properties/soap.client.props
	fi
	chgrp eiadm $ARCHIVEDIR/${WAS_CELL}/${WAS_NODE}-props-${DATE1}.tar
	chmod g+rw,o-rw $ARCHIVEDIR/${WAS_CELL}/${WAS_NODE}-props-${DATE1}.tar
fi

#Remove config/file backups older than 60 days
find $ARCHIVEDIR/${WAS_CELL} -type f -name "*.zip" -mtime +14 -exec rm -f {} \;
find $ARCHIVEDIR/${WAS_CELL} -type f -name "*.tar" -mtime +14 -exec rm -f {} \;