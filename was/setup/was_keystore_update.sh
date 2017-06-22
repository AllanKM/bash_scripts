#!/bin/bash

#
# Moves the latest JKS keystore file from LFS to the WAS directory tree.
#
# Usage: was_keystore_update.sh

# Set Globals
LFSWASETC=/lfs/system/tools/was/etc
USER=webinst
GROUP=eiadm

# Check for user
if [[ -z `id $USER` ]]; then
  echo "Error: user $USER does not exist."
  exit 1
fi

for WASDIR in `ls /usr|grep WebSphere`; do
	# Find the directory where the keystores resides
	if [[ -d /usr/${WASDIR}/DeploymentManager ]]; then
		WASETC=/usr/${WASDIR}/DeploymentManager/etc
	elif [[ -d /usr/${WASDIR}/AppServer ]]; then
		WASETC=/usr/${WASDIR}/AppServer/etc
	fi
	echo "Checking $WASETC ..."
	#Find and update all EI keystores
	for keystore in `cd ${WASETC}; ls ei*.jks`; do
		echo "   Updating $keystore ..."
		cp ${LFSWASETC}/$keystore ${WASETC}/$keystore
		chown $USER.$GROUP ${WASETC}/$keystore
		chmod 660 ${WASETC}/$keystore
	done
done
echo "Done!"
