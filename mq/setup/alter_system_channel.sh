#!/bin/ksh

usage(){

  echo "please run as: sudo /lfs/system/tools/mq/setup/alter_system_channel.sh <Queue_Manager_Name> <ENV>"

}

checkQMGR() {
  QMGR=$1

  rt=0
  status=`su - mqm -c "dmpmqaut -m $QMGR -t qmgr 2>&1"`
  if echo $status |grep -i "queue manager" |grep -i "not available" > /dev/null ; then
    rt=1
    echo "###Queue Manager $QMGR is not available###"
  else
    if echo $status |grep -i "The queue manager name is either not valid or not known" > /dev/null; then
      rt=1
      echo "###Queue Manager $QMGR is either not valid or not known"
    fi
  fi

  return $rt
}

  qmgr=$1
  ENV=$2

  if [[ $SUDO_USER == "" ]]; then
    usage
    exit 1
  fi

  if [[ $qmgr == "" ]]; then
    usage
    exit 1
  fi

  checkQMGR $qmgr
  if [[ $? == 1 ]] ; then
    exit 1
  fi


  su - mqm -c "runmqsc $qmgr <<END-OF-TEXT
    alter chl(SYSTEM.DEF.SVRCONN) CHLTYPE(SVRCONN) MCAUSER(NOBODY)
    alter chl(SYSTEM.DEF.RECEIVER) CHLTYPE(RCVR) MCAUSER(NOBODY)
    alter chl(SYSTEM.DEF.REQUESTER) CHLTYPE(RQSTR) MCAUSER(NOBODY)
    alter chl(SYSTEM.AUTO.RECEIVER) CHLTYPE(RCVR) MCAUSER(NOBODY)
    alter chl(SYSTEM.AUTO.SVRCONN) CHLTYPE(SVRCONN) MCAUSER(NOBODY)
    end
END-OF-TEXT"
> /fs/projects/$ENV/$QMGR/config/alter_system_channel.out
#2>&1

