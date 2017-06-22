#!/bin/ksh
# Create App Servers for each of the Lotus Connection features before installing the product

HOST=`/bin/hostname -s`
WAS_HOME="/usr/WebSphere61/AppServer/profiles/${HOST}"

FEATURES="blogs communities dogear profiles homepage activities"
for feature in `echo $FEATURES`; do
	echo 
	echo "-------------------- $feature ------------------------------"
	echo
	su - webinst -c "${WAS_HOME}/bin/wsadmin.sh  -f /lfs/system/tools/connections/lib/createConnectionsServer.jacl  ${HOST}_connections_${feature}"
done
