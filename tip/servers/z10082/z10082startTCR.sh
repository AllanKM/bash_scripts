#!/bin/ksh

DATE=$(date +"%Y%m%d%H%M")
WAS_HOME=/opt/IBM/TCR1/tip   
TCR_HOME=/opt/IBM/TCR1/tipComponents/TCRComponent
SERVER1_LOGS=/opt/IBM/TCR1/tip/profiles/TIPProfile/logs/server1

if [ -f $SERVER1_LOGS/SystemErr.log ]; then
    mv  $SERVER1_LOGS/SystemErr.log  $SERVER1_LOGS/SystemErr.log.$DATE.txt
fi
if [ -f $SERVER1_LOGS/SystemOut.log ]; then
    mv  $SERVER1_LOGS/SystemOut.log  $SERVER1_LOGS/SystemOut.log.$DATE.txt
fi

CMD="su - webinst -c \"$TCR_HOME/bin/startTCRserver.sh\""  
echo "Executing $CMD"
$CMD

