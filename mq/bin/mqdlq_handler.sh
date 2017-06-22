#!/bin/ksh

usage(){
  
  echo "please run as: sudo /lfs/system/tools/mq/bin/mqdlq_handler.sh <Queue_Manager> <DeadLetter_Queue>"

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

checkQName() {
 
  QMGR=$1 
  QNAME=$2

  rt=0
  status=`su - mqm -c "echo ""dis ql\($QNAME\) CURDEPTH "" | runmqsc $QMGR 2>&1`
  if  echo $status |grep -i "WebSphere MQ object"|grep -i "not found" > /dev/null ; then
    rt=1
    echo "###Queue Name QNAME not found"
  fi 

  return $rt
}

  qmgr=$1
  qname=$2

  if [[ $SUDO_USER == "" ]]; then
    usage
    exit 1
  fi
  
  if [[ $qmgr == "" || $qname == "" ]]; then
    usage
    exit 1
  fi

  checkQMGR $qmgr
  if [[ $? == 1 ]] ; then
    exit 1
  fi

  checkQName $qmgr $qname
  if [[ $? == 1 ]] ; then
    exit 1
  fi
  
#  rm -f /tmp/.qrule.rul >/dev/null 2>&1  
#  print "INPUTQ($qname) INPUTQM($qmgr) WAIT(NO)" > /tmp/.qrule.rul 
#  print "ACTION(RETRY) RETRY(1)" >> /tmp/.qrule.rul
#  chmod 777 /tmp/.qrule.rul

  su - mqm -c "runmqdlq <<END-OF-TEXT
  INPUTQ($qname) INPUTQM($qmgr) WAIT(NO)
  ACTION(RETRY) RETRY(1)
END-OF-TEXT"

2>&1
