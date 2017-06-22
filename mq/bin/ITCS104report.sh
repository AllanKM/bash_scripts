#!/bin/bash
echo ITCS104 Report
hostname
echo

NUMBER=`dspmq | wc -l`
echo Number of Queue Manager: $NUMBER
echo
echo Information protection $ confidentiality
echo Encryption Type: Transmission
echo
cd /var/mqm/qmgrs
   if [ "$NUMBER" -eq "1" ]
   then
     QMGR1=`ls | grep -v @SYSTEM | head -n 1` ; echo $QMGR1
     echo "dis channel(*) sslciph"|runmqsc $QMGR1 | grep -E 'CHANNEL|SSLCIPH'| grep -v 'SSLCIPH( )'| grep -v SYSTEM
   elif [ "$NUMBER" -eq "2" ]
   then
     QMGR1=`ls | grep -v @SYSTEM | head -n 1`; QMGR2=`ls | grep -v @SYSTEM | tail -n 1` ;
     echo $QMGR1
     echo "dis channel(*) sslciph"|runmqsc $QMGR1 | grep -E 'CHANNEL|SSLCIPH'| grep -v 'SSLCIPH( )'| grep -v SYSTEM
     echo $QMGR2
     echo "dis channel(*) sslciph"|runmqsc $QMGR2 | grep -E 'CHANNEL|SSLCIPH'| grep -v 'SSLCIPH( )'| grep -v SYSTEM
   elif [ "$NUMBER" -eq "3" ]
   then
     QMGR1=`ls | grep -v @SYSTEM | head -n 1`; QMGR3=`ls | grep -v @SYSTEM | tail -n 1` ; QMGR2=`ls | grep -v @SYSTEM | tail -n 2 | head -n1` 
     echo $QMGR1
     echo "dis channel(*) sslciph"|runmqsc $QMGR1 | grep -E 'CHANNEL|SSLCIPH'| grep -v 'SSLCIPH( )'| grep -v SYSTEM
     echo $QMGR2
     echo "dis channel(*) sslciph"|runmqsc $QMGR2 | grep -E 'CHANNEL|SSLCIPH'| grep -v 'SSLCIPH( )'| grep -v SYSTEM
     echo $QMGR3
     echo "dis channel(*) sslciph"|runmqsc $QMGR3 | grep -E 'CHANNEL|SSLCIPH'| grep -v 'SSLCIPH( )'| grep -v SYSTEM
   else
   echo "Please check if Qmgrs are deployed, or if there are more then 3 ..."
   fi
echo
echo Operating System Resources
echo Display SSLKEYR access should be xx0 for MQServers SSLKEYR
ls -latr /var/mqm/qmgrs/*/ssl/
echo
echo System Value Parameter MCAUSER=NOBODY
echo
if [ "$NUMBER" -eq "1" ]
   then
     echo $QMGR1
     echo "dis channel(SYSTEM.DEF.SVRCONN) mcauser" |runmqsc $QMGR1 |grep -E 'CHANNEL|MCAUSER'
     echo "dis channel(SYSTEM.DEF.RECEIVER) mcauser" |runmqsc $QMGR1 |grep -E 'CHANNEL|MCAUSER'
     echo "dis channel(SYSTEM.DEF.REQUESTER) mcauser" |runmqsc $QMGR1 |grep -E 'CHANNEL|MCAUSER'

   elif [ "$NUMBER" -eq "2" ]
   then
     echo $QMGR1
     echo "dis channel(SYSTEM.DEF.SVRCONN) mcauser" |runmqsc $QMGR1 |grep -E 'CHANNEL|MCAUSER'
     echo "dis channel(SYSTEM.DEF.RECEIVER) mcauser" |runmqsc $QMGR1 |grep -E 'CHANNEL|MCAUSER'
     echo "dis channel(SYSTEM.DEF.REQUESTER) mcauser" |runmqsc $QMGR1 |grep -E 'CHANNEL|MCAUSER'

     echo $QMGR2
     echo "dis channel(SYSTEM.DEF.SVRCONN) mcauser" |runmqsc $QMGR2 |grep -E 'CHANNEL|MCAUSER'
     echo "dis channel(SYSTEM.DEF.RECEIVER) mcauser" |runmqsc $QMGR2 |grep -E 'CHANNEL|MCAUSER'
     echo "dis channel(SYSTEM.DEF.REQUESTER) mcauser" |runmqsc $QMGR2 |grep -E 'CHANNEL|MCAUSER'

elif [ "$NUMBER" -eq "3" ]
   then
     echo $QMGR1
     echo "dis channel(SYSTEM.DEF.SVRCONN) mcauser" |runmqsc $QMGR1 |grep -E 'CHANNEL|MCAUSER'
     echo "dis channel(SYSTEM.DEF.RECEIVER) mcauser" |runmqsc $QMGR1 |grep -E 'CHANNEL|MCAUSER'
     echo "dis channel(SYSTEM.DEF.REQUESTER) mcauser" |runmqsc $QMGR1 |grep -E 'CHANNEL|MCAUSER'

     echo $QMGR2
     echo "dis channel(SYSTEM.DEF.SVRCONN) mcauser" |runmqsc $QMGR2 |grep -E 'CHANNEL|MCAUSER'
     echo "dis channel(SYSTEM.DEF.RECEIVER) mcauser" |runmqsc $QMGR2 |grep -E 'CHANNEL|MCAUSER'
     echo "dis channel(SYSTEM.DEF.REQUESTER) mcauser" |runmqsc $QMGR2 |grep -E 'CHANNEL|MCAUSER'

     echo $QMGR3
     echo "dis channel(SYSTEM.DEF.SVRCONN) mcauser" |runmqsc $QMGR3 |grep -E 'CHANNEL|MCAUSER'
     echo "dis channel(SYSTEM.DEF.RECEIVER) mcauser" |runmqsc $QMGR3 |grep -E 'CHANNEL|MCAUSER'
     echo "dis channel(SYSTEM.DEF.REQUESTER) mcauser" |runmqsc $QMGR3 |grep -E 'CHANNEL|MCAUSER'

   fi
echo
echo System Value Parameter either CHADEXIT is set or MCAUSER=NOBODY
echo
if [ "$NUMBER" -eq "1" ]
   then
     echo $QMGR1
     echo "dis qmgr CHADEXIT" |runmqsc $QMGR1 |grep -E 'QMNAME'
     echo "dis channel(SYSTEM.AUTO.RECEIVER) mcauser" |runmqsc $QMGR1 |grep -E 'CHANNEL|MCAUSER'
     echo "dis channel(SYSTEM.AUTO.SVRCONN) mcauser" |runmqsc $QMGR1 |grep -E 'CHANNEL|MCAUSER'
   
   elif [ "$NUMBER" -eq "2" ]
   then
     echo $QMGR1
     echo "dis qmgr CHADEXIT" |runmqsc $QMGR1 |grep -E 'QMNAME'
     echo "dis channel(SYSTEM.AUTO.RECEIVER) mcauser" |runmqsc $QMGR1 |grep -E 'CHANNEL|MCAUSER'
     echo "dis channel(SYSTEM.AUTO.SVRCONN) mcauser" |runmqsc $QMGR1 |grep -E 'CHANNEL|MCAUSER'

     echo $QMGR2
     echo "dis qmgr CHADEXIT" |runmqsc $QMGR2 |grep -E 'QMNAME'
     echo "dis channel(SYSTEM.AUTO.RECEIVER) mcauser" |runmqsc $QMGR2 |grep -E 'CHANNEL|MCAUSER'
     echo "dis channel(SYSTEM.AUTO.SVRCONN) mcauser" |runmqsc $QMGR2 |grep -E 'CHANNEL|MCAUSER'

elif [ "$NUMBER" -eq "3" ]
   then
     echo $QMGR1
     echo "dis qmgr CHADEXIT" |runmqsc $QMGR1 |grep -E 'QMNAME'
     echo "dis channel(SYSTEM.AUTO.RECEIVER) mcauser" |runmqsc $QMGR1 |grep -E 'CHANNEL|MCAUSER'
     echo "dis channel(SYSTEM.AUTO.SVRCONN) mcauser" |runmqsc $QMGR1 |grep -E 'CHANNEL|MCAUSER'

     echo $QMGR2
     echo "dis qmgr CHADEXIT" |runmqsc $QMGR2 |grep -E 'QMNAME'
     echo "dis channel(SYSTEM.AUTO.RECEIVER) mcauser" |runmqsc $QMGR2 |grep -E 'CHANNEL|MCAUSER'
     echo "dis channel(SYSTEM.AUTO.SVRCONN) mcauser" |runmqsc $QMGR2 |grep -E 'CHANNEL|MCAUSER'

     echo $QMGR3
     echo "dis qmgr CHADEXIT" |runmqsc $QMGR3 |grep -E 'QMNAME'
     echo "dis channel(SYSTEM.AUTO.RECEIVER) mcauser" |runmqsc $QMGR3 |grep -E 'CHANNEL|MCAUSER'
     echo "dis channel(SYSTEM.AUTO.SVRCONN) mcauser" |runmqsc $QMGR3 |grep -E 'CHANNEL|MCAUSER'

   fi

echo
echo SVRCONN channels/MCAUSER
echo MCAUSER of SVRCONN channel should not be set to mqm or any userID of mqm group unless SSL is configured:
if [ "$NUMBER" -eq "1" ]
   then
     echo $QMGR1
     echo "dis channel(*) chltype(SVRCONN)" | runmqsc $QMGR1 | grep CHANNEL | grep -v SYSTEM | cut -f2 -d\( | cut -f1 -d\) |
while read channel_name
  do
    echo ${channel_name}
    echo "dis channel(${channel_name}) chltype(SVRCONN) sslciph mcauser" | runmqsc $QMGR1 | egrep CHANNEL\|MCAUSER
  done
     echo
   elif [ "$NUMBER" -eq "2" ]
   then
     echo $QMGR1
 echo "dis channel(*) chltype(SVRCONN)" | runmqsc $QMGR1 | grep CHANNEL | grep -v SYSTEM | cut -f2 -d\( | cut -f1 -d\) |
while read channel_name
  do
    echo ${channel_name}
    echo "dis channel(${channel_name}) chltype(SVRCONN) sslciph mcauser" | runmqsc $QMGR1 | egrep CHANNEL\|MCAUSER
  done    
     echo
     echo $QMGR2
     echo "dis channel(*) chltype(SVRCONN)" | runmqsc $QMGR2 | grep CHANNEL | grep -v SYSTEM | cut -f2 -d\( | cut -f1 -d\) |
while read channel_name
    do
    echo ${channel_name}
    echo "dis channel(${channel_name}) chltype(SVRCONN) sslciph mcauser" | runmqsc $QMGR2 | egrep CHANNEL\|MCAUSER
    done
   elif [ "$NUMBER" -eq "3" ]
   then
    echo $QMGR1
    echo "dis channel(*) chltype(SVRCONN)" | runmqsc $QMGR1 | grep CHANNEL | grep -v SYSTEM | cut -f2 -d\( | cut -f1 -d\) |
while read channel_name
    do
    echo ${channel_name}
    echo "dis channel(${channel_name}) chltype(SVRCONN) sslciph mcauser" | runmqsc $QMGR1 | egrep CHANNEL\|MCAUSER
    done
     echo
     echo $QMGR2
     echo "dis channel(*) chltype(SVRCONN)" | runmqsc $QMGR2 | grep CHANNEL | grep -v SYSTEM | cut -f2 -d\( | cut -f1 -d\) |
while read channel_name
    do
    echo ${channel_name}
    echo "dis channel(${channel_name}) chltype(SVRCONN) sslciph mcauser" | runmqsc $QMGR2 | egrep CHANNEL\|MCAUSER
    done
    echo $QMGR3
    echo "dis channel(*) chltype(SVRCONN) sslciph mcauser" | runmqsc $QMGR3 | grep CHANNEL | grep -v SYSTEM | cut -f2 -d\( | cut -f1 -d\) |
while read channel_name
    do
    echo ${channel_name}
    echo "dis channel(${channel_name}) chltype(SVRCONN) sslciph mcauser" | runmqsc $QMGR3 | egrep CHANNEL\|MCAUSER
    done
fi

echo
echo SYSTEM.ADMIN.COMMAND.QUEUE
echo Default groups such as nobody, staff or users should not be in the access list for this queue

if [ "$NUMBER" -eq "1" ]
   then
     echo $QMGR1
     dmpmqaut -m $QMGR1 -n SYSTEM.ADMIN.COMMAND.QUEUE 
     echo
   elif [ "$NUMBER" -eq "2" ]
   then
    echo $QMGR1
    dmpmqaut -m $QMGR1 -n SYSTEM.ADMIN.COMMAND.QUEUE 
    echo
    echo $QMGR2
    dmpmqaut -m $QMGR2 -n SYSTEM.ADMIN.COMMAND.QUEUE
    echo
   elif [ "$NUMBER" -eq "3" ]
   then
    echo $QMGR1
    dmpmqaut -m $QMGR1 -n SYSTEM.ADMIN.COMMAND.QUEUE 
    echo
    echo $QMGR2
    dmpmqaut -m $QMGR2 -n SYSTEM.ADMIN.COMMAND.QUEUE
    echo
    echo $QMGR3
    dmpmqaut -m $QMGR3 -n SYSTEM.ADMIN.COMMAND.QUEUE
fi

echo
echo Service integrity and availability
echo If MQSNOAUT or OAM are found, value will be displayed here
echo
env |grep MQSNOAUT
egrep OAM /var/mqm/qmgrs/*/qm.ini
echo
echo Secutiry and system administrative authority
echo mqm groupid
grep mqm /etc/group
echo
echo END OF REPORT
