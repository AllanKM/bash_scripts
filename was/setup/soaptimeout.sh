#!/bin/bash
# Configures the local node's SOAP timeout configuration
# Usage: soaptimeout.sh version [profile]

HOST=`/bin/hostname -s`
VERSION=$1
VERSION=`echo $VERSION | cut -c1-2`
if [ "$2" == "" ]; then
	PROFILE=""
else
	PROFILE=${2}
fi

# Set Globals
APPDIR=/usr/WebSphere$VERSION/AppServer
REQTIMEOUT=6000

# Check for user
if [[ -z `id $USER` ]]; then
  echo "Error: user $USER does not exist."
  exit 1
fi

# Reset permissions
/lfs/system/tools/was/setup/was_perms.ksh

if [[ $VERSION == "60" || $VERSION == "61" ]]; then
	echo "Version 6.x -- setting up variables with profiles"
  	if [[ $PROFILE == "" ]]; then
		echo "Looking up default profile"
		defScript=$APPDIR/properties/fsdb/_was_profile_default/default.sh
		DEFPROFILE=$(grep setup $defScript|awk '{split($0,pwd,"WAS_USER_SCRIPT="); print pwd[2]}')
		PROFILE=$(echo $DEFPROFILE|awk '{split($0,profile,"/"); print profile[6]}')
		echo "$PROFILE"
		WAS_PROPS=$APPDIR/profiles/$PROFILE/properties
  	else
		echo "Using profile $PROFILE specified on the command line"
		WAS_PROPS=$APPDIR/profiles/$PROFILE/properties
	fi
else
	echo "Version 5.1 -- setting up variables"
	#WebSphere version 5.1
	if [[ -d $APPDIR ]]; then
		WAS_NODE=$(grep WAS_NODE= $APPDIR/bin/setupCmdLine.sh |awk '{split($0,pwd,"WAS_NODE="); print pwd[2]}')
		WAS_PROPS=$APPDIR/properties
	elif [[ -d "/usr/WebSphere${VERSION}/DeploymentManager" ]]; then
		APPDIR=/usr/WebSphere${VERSION}/DeploymentManager
		WAS_NODE=$(grep WAS_NODE= $APPDIR/bin/setupCmdLine.sh |awk '{split($0,pwd,"WAS_NODE="); print pwd[2]}')
		WAS_PROPS=$APPDIR/properties
	fi
fi
  
echo "Updating soap.client.props..."
su - $USER -c "cp -p $WAS_PROPS/soap.client.props $WAS_PROPS/soap.client.props.orig"
su - $USER -c "sed -e \"s/requestTimeout=.*/requestTimeout=$REQTIMEOUT/g\" $WAS_PROPS/soap.client.props.orig > $WAS_PROPS/soap.client.props"

echo "Done!"