#!/bin/sh

echo "Start TIP NCO WebSphere..."

DATE=$(date +"%Y%m%d%H%M")
WAS_HOME=/opt/IBM/Netcool/tip/
TIPPROFILE=$WAS_HOME/profiles/TIPProfile
SERVER1_LOGS=$TIPPROFILE/logs/server1


if [ -f $SERVER1_LOGS/startServer.log ]; then
    mv  $SERVER1_LOGS/startServer.log  $SERVER1_LOGS/startServer.log.$DATE.txt
fi
if [ -f $SERVER1_LOGS/SystemErr.log ]; then
    mv  $SERVER1_LOGS/SystemErr.log  $SERVER1_LOGS/SystemErr.log.$DATE.txt
fi
if [ -f $SERVER1_LOGS/SystemOut.log ]; then
   mv  $SERVER1_LOGS/SystemOut.log  $SERVER1_LOGS/SystemOut.log.$DATE.txt
fi

su - netcool -c "$TIPPROFILE/bin/startServer.sh server1"   
