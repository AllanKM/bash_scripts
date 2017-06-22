#!/bin/sh

echo "Stop NCO TIP without userid and password.."

DATE=$(date +"%Y%m%d%H%M")
WAS_HOME=/opt/IBM/Netcool/tip/
TIPPROFILE=$WAS_HOME/profiles/TIPProfile
SERVER1_LOGS=$TIPPROFILE/logs/server1

su - netcool -c "$TIPPROFILE/bin/stopServer.sh server1"   
