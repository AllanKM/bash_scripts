#!/bin/bash
#
# Manage WebSphere applications -- install, update, or list.
#    - Basically a wrapper for appAction.jacl
#
# Author:	James Walton
# Contact:	jfwalton@us.ibm.com
# Date:		04 Apr 2007
#
#   Usage: manageapp.sh {61|70} install <appname> <ear file> <cluster> <virtualhost> [profile]
#          manageapp.sh {61|70} update <appname> <ear file> <virtualhost> [profile]
#          manageapp.sh {61|70} list [-server <servername> | -cluster <clustername> | -node <nodename>] [profile]
#          manageapp.sh {61|70} start|stop|restart <appname> <servername> [-node <nodename>] [profile]

JYDIR="/lfs/system/tools/was/lib"
USER=webinst
FULLVERSION=${1:-70023}
VERSION=`echo $FULLVERSION | cut -c1-2`

case $2 in
	"install")
		ACTION="-action install"
		APPNAME="-app $3"
		EARFILE="-ear $4"
		CLUSTER="-cluster $5"
		VHOST="-vhost $6"
		PROFILE=$7
		;;
	"update")
		ACTION="-action update"
		APPNAME="-app $3"
		EARFILE="-ear $4"
		VHOST="-vhost $5"
		PROFILE=$6
		;;
	"export")
		ACTION="-action export"
		APPNAME="-app $3"
		EARFILE="-ear $4"
		PROFILE=$5
		;;
	"list")
		ACTION="-action list"
		if [ `echo $3|grep '^-'` ]; then
			OPTARGS="$3 $4"
			PROFILE=$5
		else
			PROFILE=$3
		fi
		;;
	"vhost")
		ACTION="-action vhost"
		APPNAME="-app $3"
		VHOST="-vhost $4"
		PROFILE=$5
		;;
	"start"|"stop"|"restart")
		ACTION="-action $2"
		APPNAME="-app $3"
		if [ `echo $4|grep '^-'` ]; then
			OPTARGS="-server $4 $5 $6"
			PROFILE=$7
		else
			OPTARGS="-server $4"
			PROFILE=$5
		fi
		;;
	*) 
		echo "Usage: manageapp.sh {61|70} install <appname> <ear file> <cluster> <virtualhost> [profile]"
		echo "       manageapp.sh {61|70} update <appname> <ear file> <virtualhost> [profile]"
		echo "       manageapp.sh {61|70} export <appname> <ear file> [profile]"
		echo "       manageapp.sh {61|70} list [-server <servername> | -cluster <clustername> | -node <nodename>] [profile]"
		echo "       manageapp.sh {61|70} vhost <appname> <virtualhost> [profile]"
		echo "       manageapp.sh {61|70} start|stop|restart <appname> <servername> [-node <nodename>] [profile]"
		exit 1
		;;
esac

if [ "$PROFILE" == "" ]; then
	#Grab default profile
	defScript=/usr/WebSphere${VERSION}/AppServer/properties/fsdb/_was_profile_default/default.sh
	DEFPROFILE=$(grep setup $defScript|awk '{split($0,pwd,"WAS_USER_SCRIPT="); print pwd[2]}')
	WAS_NODE=$(grep WAS_NODE= $DEFPROFILE|awk '{split($0,pwd,"WAS_NODE="); print pwd[2]}')
	PROFILE=$(echo $DEFPROFILE|awk '{split($0,profile,"/"); print profile[6]}')
	if [ "$PROFILE" == "" ]; then 
		echo "Failed to find Profile for post install configuration"
		echo "exiting...."
		exit 1
	fi
fi
WASDIR="/usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}"

if [ -x $WASDIR/bin/wsadmin.sh ]; then
	WSADMIN=$WASDIR/bin/wsadmin.sh
else
	echo "Failed to locate $WASDIR/bin/wsadmin.sh ... exiting"
	exit 1
fi
echo "---------------------------------------------------"
echo " Performing requested action..."
echo " $WASDIR"
echo " wsadmin.sh -lang jython -f ${JYDIR}/application.py $ACTION $OPTARGS $APPNAME $EARFILE $CLUSTER $VHOST"
echo " Please be patient, jython packages might need processing the first time..."
echo "---------------------------------------------------"
LOGGING="-tracefile /logs/was${VERSION}/${PROFILE}/wsadmin.app-${2}-${3}.traceout"
su - $USER -c "$WSADMIN -lang jython $LOGGING -f ${JYDIR}/application.py $ACTION $OPTARGS $APPNAME $EARFILE $CLUSTER $VHOST|grep -v '^WASX'|grep -v 'sys-package-mgr'"
