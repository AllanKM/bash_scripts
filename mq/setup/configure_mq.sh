#!/bin/ksh 

#---------------------------------------------------------------
# Configure MQ  
#---------------------------------------------------------------

# USAGE: configure_mq.sh  [qmgr name] [path to the MQS configuration file]

#Standard names the QMGR as QM<hostname>
HOST=`/bin/hostname`
typeset -u HOST
ENV=${1:-cdt}
QMGRS=$2

# Second argument is the full path to the configuration file
# Standard defines that file as /fs/mqm/<qmgr>/<qmgr>.MQS 
#CONF=${3:-/fs/mqm/${QMGR}/${QMGR}.MQS}

config_mq(){
 
  QMGR="QM${HOST}$1"
  if [[ $DEFAULT -eq 0 ]]; then
    PORT=1414
  else
    PORT=$((PORT+1))
  fi

  DESCRIPTION="QMGR $QMGR on host $HOST"

  #---------------------------------------------------------------
  # Check if MQ is already installed
  #---------------------------------------------------------------
  su - mqm -c "/usr/bin/dspmqver" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "MQ is not installed. Exiting..."
    exit 1
  fi

  #Look to see if a Queue Manager already exists - if one does, then exit
  su - mqm -c "dspmq"  | grep $QMGR > /dev/null
  if [ $? -eq 0 ]; then
    echo "Queue definitions of $QMGR already exist"
    echo "exiting $QMGR creation...."
    return
  fi


  #Determine what plex this node is located by looking in /etc/resolv.conf
  #set -- $(grep search /etc/resolv.conf)

  #while [[ "$1" != "" ]]; do
  #  if [[ "$1" = [bgy].*.p?.event.ibm.com ]]
  #  then
  #    PLEX=`echo "$1" | cut -d. -f3 | cut -c2`
  #  fi
  #  shift
  #done

  echo "Creating QMGR $QMGR with description \"$DESCRIPTION\""
  if [[ $DEFAULT -eq 0 ]]; then
    su - mqm -c "crtmqm -c \"$DESCRIPTION\" -q $QMGR"
  else
    su - mqm -c "crtmqm -c \"$DESCRIPTION\" $QMGR"
  fi

  su - mqm -c "strmqm $QMGR"
  sleep 10 
  su - mqm -c "dspmq -m $QMGR -o status" |grep -i STATUS\(Running\) >/dev/null
  if [[ $? -eq 0 ]]; then
    su - mqm -c "runmqsc $QMGR <<END-OF-TEXT
      define listener(LISTENER_$QMGR) TRPTYPE(TCP) CONTROL(QMGR) PORT($PORT)
      start listener(LISTENER_$QMGR)
      end
END-OF-TEXT"
2>&1

  else
    echo "$QMGR not start yet, stop the configuration of $QMGR"
    return 
  fi
  /lfs/system/tools/mq/setup/mqstandard.sh $QMGR $ENV
  /lfs/system/tools/mq/setup/setup_keyrings.sh $QMGR
  /lfs/system/tools/mq/setup/alter_system_channel.sh $QMGR $ENV

  #if [ -f $CONF ]; then
  #  echo "Using $CONF file to configure MQ.  Sending output to /tmp/qmgr.out"
    #chown mqm $CONF
    #su - mqm -c "runmqsc < $CONF > /tmp/qmgr.out"
  #fi
}

if [[ $SUDO_USER == "" ]]; then
  echo "Please run as \"sudo\""
  exit 1
fi

DEFAULT=0
qmcnt=`echo $QMGRS|awk -F\, '{print NF}'`
if [[ $qmcnt -gt 1 ]]; then
  DEFAULT=1
fi
if [[ $QMGRS == "" ]]; then
  config_mq
else
  for QMGR in `echo $QMGRS|awk -F\, '{for(i=1;i<=NF;i++){print $i}}'`; do
    config_mq $QMGR
    DEFAULT=1
  done
fi

