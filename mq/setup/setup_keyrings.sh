#!/bin/ksh

usage(){

  echo "please run as: sudo /lfs/system/tools/mq/setup/setup_keyrings.sh <Queue_Manager_Name>"

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
  QMGR=$1
  typeset -u QMGR
  typeset -l qmgr
  if [[ $SUDO_USER == "" ]]; then
    usage
    exit 1
  fi
  if [[ $QMGR == "" ]]; then
    usage
    exit 1
  fi
  checkQMGR $QMGR
  if [[ $? == 1 ]] ; then
    exit 1
  fi

# sync keyrings from golden copy at0101a to local

  zone=`lssys -n|grep -i realm|cut -f2 -d =|cut -c2`
case $zone in
    y) qzone="MQYELLOW"  
        ;;
    b) qzone="MQBLUE"  
        ;;
    g) qzone="MQGREEN"
        ;;
    *) echo "Get wrong Zone, exiting ..."
       exit 1
       ;;
esac
echo "qzone: $qzone  zone:$zone"

#  echo "sync $QMGR keyrings from golden copy at0101a to local..."
#  rsync -tzave ssh at0101a:/fs/system/security/certauth/KEYRINGS/$qzone /fs/system/security/certauth/KEYRINGS/$qzone
#  sleep 10
  echo "copy keyrings /fs/system/security/certauth/KEYRINGS/$qzone/$qmgr.* to /var/mqm/qmgrs/$QMGR/ssl/ ..."
  cp /fs/system/security/certauth/KEYRINGS/$qzone/$qmgr.* /var/mqm/qmgrs/$QMGR/ssl/
  if [[ $? == 1 ]]; then
    exit 1
  fi
  chmod 660 /var/mqm/qmgrs/$QMGR/ssl/$qmgr.*

  su - mqm -c "runmqsc $QMGR <<END-OF-TEXT
    alter qmgr SSLKEYR('/var/mqm/qmgrs/$QMGR/ssl/$qmgr')
    refresh security type(ssl)
    end
END-OF-TEXT"
