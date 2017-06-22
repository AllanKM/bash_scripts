#!/bin/sh

# USAGE: mqchannels.sh [manager|broker]


# Will this be a MANAGER or BROKER install?
TYPE=${1:-BROKER}

typeset -u TYPE


# This command needs to run as mqm
if [ "$USER" != "mqm" ]; then
    echo "Re-run $0 as mqm user"
    echo "exiting...."
    exit 1
fi

THISNODE=`hostname`
host=`hostname`
echo "Enter the password to use when creating the broker: "
read PASSWD?"Enter the password to use when creating the broker: "
read DBPASSWD?"Enter the database password to use when creating the broker: "

#convert to uppercase
typeset -u THISNODE


#---------------------------------------------------------------
# Create Queues
#---------------------------------------------------------------


   crtmqm -c 'Message Broker Queue Manager' -q -u SYSTEM.DEAD.LETTER.QUEUE QM${THISNODE}
   strmqm
   nohup runmqlsr -t tcp -p 1414 -m QM${THISNODE} > /tmp/runmqlsr.out &

if [ "$TYPE" == "BROKER" ]; then
    mqsicreatebroker BR${THISNODE} -i mqm -a $PASSWD -q QM${THISNODE} -n WBRKBKDB -u wbimbus -p $DBPASSWD -l /projects/wbimb/custom/lil/
    mqsichangeproperties BR${THISNODE} -o DynamicSubscriptionEngine -n interbrokerHost -v ${host}
    if [ $? -ne 0 ]; then
        echo "mqsicreatebroker failed to run successfully"
        echo "exiting...."
        exit 1
    fi
    mqsistart BR${THISNODE}
    if [ $? -ne 0 ]; then
        echo "mqsistart failed to run successfully"
        echo "exiting...."
        exit 1
    fi
    print "Using dirstore to figure out Database Server in this plex"
    REALM=`/fs/system/tools/auth/bin/getrealm`
    DB2SERVER=`lssys -q -e "realm==${REALM}" "role==WBIMB.EVENTS.MANAGER"`

    if [ "$DB2SERVER" == "" ]; then
        echo "Failed to obtain WBIMB.EVENTS.MANAGER node in $REALM"
        echo "exiting..."
        exit 1
    fi
    typeset -u DB2SERVER
    # Create channel to cfg mgr node
    echo "DEFINE CHANNEL('${THISNODE}.${DB2SERVER}') CHLTYPE(SDR) TRPTYPE(TCP) CONNAME('${DB2SERVER}(1414)') xmitq(QM${DB2SERVER}) REPLACE" | runmqsc
    echo "define channel(${DB2SERVER}.${THISNODE}) chltype(rcvr) TRPTYPE(TCP) REPLACE " |runmqsc
    echo "define ql(QM${DB2SERVER}) usage(xmitq) trigger trigdata(${THISNODE}.${DB2SERVER}) initq(system.channel.initq) replace " |runmqsc

    echo "start channel(${THISNODE}.${DB2SERVER})" |runmqsc


    # Create channels to all the other broker nodes in this site
    echo "Using dirstore to obtain list of broker nodes in this plex"
    REALM=`/fs/system/tools/auth/bin/getrealm`
    

    for REMOTE_BROKER in `lssys -q -e "realm==${REALM}" "role==WBIMB.EVENTS.BROKER"`; do
        if [ "$THISNODE" != "$REMOTE_BROKER" ]; then
            #Convert to uppercase
            typeset -u REMOTE_BROKER
            echo "Defining channels to/from $REMOTE_BROKER"
            echo "define channel(${THISNODE}.${REMOTE_BROKER}) chltype(sdr) TRPTYPE(TCP) CONNAME('${REMOTE_BROKER}(1414)') xmitq(QM${REMOTE_BROKER}) REPLACE" | runmqsc

            echo "define channel(${REMOTE_BROKER}.${THISNODE}) chltype(rcvr) TRPTYPE(TCP) REPLACE " |runmqsc

            echo "define ql(QM${REMOTE_BROKER}) usage(xmitq) trigger trigdata(${THISNODE}.${REMOTE_BROKER}) initq(system.channel.initq) replace " |runmqsc

            echo "start channel(${THISNODE}.${REMOTE_BROKER})" |runmqsc
         fi
        done
elif [[ "$TYPE" == "MANAGER" ]]; then
    mqsicreateconfigmgr CM${THISNODE} -i mqm -a $PASSWD -q QM${THISNODE}
    mqsistart CM${THISNODE}
    mqsicreateusernameserver -i mqm -a $PASSWD -q QM${THISNODE}
    mqsistart UserNameServer

    # Create channels to all the other broker nodes in this site
    echo "Using dirstore to obtain list of broker nodes in this plex"
    REALM=`/fs/system/tools/auth/bin/getrealm`


    for REMOTE_BROKER in `lssys -q -e "realm==${REALM}" "role==WBIMB.EVENTS.BROKER"`; do
        if [ "$THISNODE" != "$REMOTE_BROKER" ]; then
            #Convert to uppercase
            typeset -u REMOTE_BROKER
            echo "Defining channels to/from $REMOTE_BROKER"
            echo "define channel(${THISNODE}.${REMOTE_BROKER}) chltype(sdr) TRPTYPE(TCP) CONNAME('${REMOTE_BROKER}(1414)') xmitq(QM${REMOTE_BROKER}) REPLACE" | runmqsc

            echo "define channel(${REMOTE_BROKER}.${THISNODE}) chltype(rcvr) TRPTYPE(TCP) REPLACE " |runmqsc

            echo "define ql(QM${REMOTE_BROKER}) usage(xmitq) trigger trigdata(${THISNODE}.${REMOTE_BROKER}) initq(system.channel.initq) replace " |runmqsc

            echo "start channel(${THISNODE}.${REMOTE_BROKER})" |runmqsc
         fi
        done
fi
    
