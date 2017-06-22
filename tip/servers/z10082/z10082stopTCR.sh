#!/bin/ksh

# 06-27-2013 Removed userid/pw. Not needed after userid/pw added to soap.client.props
# 
TCR_HOME=/opt/IBM/TCR1/tipComponents/TCRComponent
echo Stopping TCR 
#@CMD="su - webinst -c \"$TCR_HOME/bin/stopTCRserver.sh tipadmin tipadmin\""
#echo Executing $CMD

#$CMD
su - webinst -c "$TCR_HOME/bin/stopTCRserver.sh"
