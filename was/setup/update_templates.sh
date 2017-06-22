#!/bin/bash
#
#   Change History: 
#     Lou Amodeo    03-01-2013  Add support for Websphere 8.5 
#
#Usage: update_templates.sh VERSION [PROFILE]
HOST=`/bin/hostname -s`
FULLVERSION=${1:-70023}
VERSION=`echo $FULLVERSION | cut -c1-2`
if [ "$2" != "" ]; then
	PROFILE=$2									
fi

# Set Globals
case $VERSION in
	61*|70*|85*)
		if [ "$PROFILE" == "" ]; then 
			#Use version specified, search for profiles
			i=0
			DIR="/usr/WebSphere${VERSION}/AppServer"
			for profile in `ls ${DIR}/profiles/`; do
				pList[$i]=${profile}
				i=$(($i+1))
			done
			if [ $i -gt 1 ]; then
				echo "WebSphere environment(s) and profiles:"
				i=0
				while [[ ${pList[$i]} != "" ]]; do
					echo "        [$i] ${DIR}/profiles/${pList[$i]}"
					i=$(($i+1))
				done
				printf "\nEnter number for the WebSphere environment you want to use: "
				read $choice
				echo "Using: ${DIR}/profiles/${pList[$choice]}"
				PROFILE=${pList[$choice]}
			else
				PROFILE=${pList}
			fi
		fi
		WASDIR="/usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}"
		;;
    *)
    	echo "Not configured for version $VERSION -- Versions 5.x and 6.0.x are no longer supported in the EI"
	echo "Exiting..."
        exit 1
	;;
esac

# Unpack the templates to the dmgr
echo "Unpacking WAS v${VERSION} EI Application Server templates to: ${WASDIR}/config/templates"
cd ${WASDIR}/config/templates
tar -xf /lfs/system/tools/was/setup/was${VERSION}_ei_templates.tar
chown -R webinst.eiadm ${WASDIR}/config/templates/servertypes
chmod -R ug+rwx,g+s,o-rwx ${WASDIR}/config/templates/servertypes
