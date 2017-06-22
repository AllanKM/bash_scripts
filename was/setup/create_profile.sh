#!/bin/ksh

# Usage:
#	create_profile.sh [version] [DMGR, profile, or standalone cell name]  
#   DMGR name should include "Manager" and for example gzp51udManager will be the name of the profile
#   and the arguement to this script should be the profile name
#
#
#   Change History: 
#     Lou Amodeo    03-01-2013  Add support for Websphere 8.5 
#     Lou Amodeo    09-17-2013  Omit default and ivt application installs for version 8.5.5 default profile
#   

HOST=`/bin/hostname -s`
TOOLSDIR="/lfs/system/tools/was"
FULLVERSION=${1:-70023}
VERSION=`echo $FULLVERSION | cut -c1-2`
BASEDIR="/usr/WebSphere${VERSION}"
APPDIR="${BASEDIR}/AppServer"
PRODFILE="${APPDIR}/properties/version/WAS.product"

case $2 in
	*anager)
			echo "Creating $2 Deployment Manager profile"
			PROFILE=$2
			#Truncate CELL to gzcdt70ed instead of dmgr profile name gzcdt70edManager ( remove Manager )
			CELL=${PROFILE%%Manager}
			#Override default hostname with dmgr name
			HOST=$PROFILE
			;;
	*-sa|*-sa[123])
			echo "Creating $2 stand alone profile"
			SINGLE=$2
			PROFILE=$HOST
			;;
	*)
			if [ "$2" == "" ]; then				
			      PROFILE=$HOST
            elif [ "$2" == "$HOST" ]; then
                  PROFILE=$2
			else			      
			      PROFILE=${HOST}_${2}									
			fi
            echo "Creating $PROFILE Managed profile"
			;;
esac

PROFDIR=$APPDIR/profiles/${PROFILE}

echo "Checking for compatible WebSphere version..."

grep version\> ${PRODFILE} | cut -d">" -f 2 | cut -d"<" -f 1
if [ $? -ne 0 ]; then
	echo "Compatible WebSphere version could not be found"
	echo "Execute /lfs/system/tools/was/setup/install_was.sh $FULLVERSION $PROFILE before create_profile.sh"
    echo "Exiting...."
  	exit 1
fi

#Do not install the default and ivt applications for 8.5.5 default profiles
if [ "$VERSION" == "85" ]; then
     omitAction=" -omitAction defaultAppDeployAndConfig deployIVTApplication "
else
     omitAction=""
fi

if [ "$CELL" != "" ]; then
	if [ "$VERSION" != "85" ]; then
		TEMPLATE="${APPDIR}/profileTemplates/dmgr"
	else
		TEMPLATE="${APPDIR}/profileTemplates/management"
	fi
	PROFILEARGS="-create -templatePath ${TEMPLATE} -profileName ${PROFILE} -profilePath ${PROFDIR} -hostName ${HOST} -nodeName ${PROFILE} -cellName ${CELL} -isDefault -defaultPorts"
elif [ "$SINGLE" != "" ]; then
	TEMPLATE="${APPDIR}/profileTemplates/default"
	PROFILEARGS="-create -templatePath ${TEMPLATE} -profileName ${PROFILE} -profilePath ${PROFDIR} -hostName ${HOST} -nodeName ${PROFILE} -cellName ${SINGLE} -isDefault ${omitAction}"
else
	TEMPLATE="${APPDIR}/profileTemplates/managed"
	PROFILEARGS="-create -templatePath ${TEMPLATE} -profileName ${PROFILE} -profilePath ${PROFDIR} -hostName ${HOST} -nodeName ${PROFILE} -cellName ${PROFILE} -federateLater -isDefault"
fi

if [ -d ${TEMPLATE} ]; then
	echo "--------------------------------------------"
	echo "Creating profile $PROFILE using bin/manageprofiles.sh ..."
	echo
	echo " Settings: $PROFILEARGS"
	echo
	echo "--------------------------------------------"
	$APPDIR/bin/manageprofiles.sh $PROFILEARGS
else
   echo "Profile Template ${TEMPLATE} could not be found"
fi

echo "Linking log directories..."
mkdir /logs/was${VERSION}/${PROFILE}
cp $PROFDIR/logs/* /logs/was${VERSION}/${PROFILE} 
rm -fr $PROFDIR/logs
ln -s /logs/was${VERSION}/${PROFILE} /$PROFDIR/logs


echo "Setting permissions..." 
/lfs/system/tools/was/setup/was_perms.ksh
