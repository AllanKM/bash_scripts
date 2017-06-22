#!/bin/bash 

usage () {
  echo "USAGE: ${0##*/} -p <plex>  [-v] [-S <m|j>] [-P <m|j>] [-r <port>]"
  echo
  echo "OPTIONS:"
  echo "  -p <plex>  :  plex to be tested - p1|p2|p3|pre|ecc"
  echo "  -v         :  verbose output"
  echo "  -P         :  set publishing method to either (j)ms or (m)qtt [default JMS]"
  echo "  -S         :  set subscription method to either (j)ms or (m)qtt [default MQTT]"
  echo "  -r         :  remote port to connect to for subscription [default 8000 for non SSL or 443 for SSL]"
  echo "  -R         :  remote port to connect to for publishing [default 1500 for non SSL or 1543 for SSL]"
  echo "  -z         :  use TLS on subscription connection"
  echo "  -Z         :  use TLS on publishing connection"
  echo
  exit 1
}

APP_PATH=${0%/*}
PUB_METHOD=JMS
SUB_METHOD=MQTT
SSLARG=""

while getopts Zzp:vP:S:R:r: opt; do
  case $opt in
  r)
    SUBPORT=$OPTARG
    ;;

  R)
    PUBPORT=$OPTARG
    ;;

  p)
    case $OPTARG in
    p1|p3|p5|P1|P3|P5|pre|PRE|ecc|ECC|s1|S1|s2|S2|s3|S3|s4|S4|s5|S5|s6|S6|cdt|CDT)
      #plex=$OPTARG
      plex=$(echo $OPTARG | tr '[:upper:]' '[:lower:]')
      ;;

    *)
      echo "Must specify p1|p2|p3|p5|s1|s2|s3|s4|s5|s6|pre|ecc"
      echo
      usage
      exit 2
      ;;
    esac
    ;;

  v)
    DEBUG="y"
    ;;

  P)
    case $OPTARG in
    [jJ])
      PUB_METHOD=JMS
      ;;

    [mM])
      PUB_METHOD=MQTT
      ;;

    *)
      usage
      exit 1
      ;;
    esac
    ;;

  S)
    case $OPTARG in
    [jJ])
      SUB_METHOD=JMS
      ;;

    [mM])
      SUB_METHOD=MQTT
      ;;

    *)
      usage
      exit 1
      ;;
    esac
    ;;

  z)
    SUBSSLARG="-z"
    SUBJAVAARG="-Djavax.net.ssl.trustStore=$APP_PATH/cacerts"
    PAUSE=7
    ;;

  Z)
    PUBSSLARG="-z"
    PUBJAVAARG="-Djavax.net.ssl.trustStore=$APP_PATH/cacerts"
    ;;

  *)
    usage
    exit 1
    ;;
  esac
done

[[ -z $SUBPORT ]] && [[ -z $SUBSSLARG ]] && SUBPORT=8000
[[ -z $SUBPORT ]] && [[ -n $SUBSSLARG ]] && SUBPORT=443
[[ -z $PUBPORT ]] && [[ -z $PUBSSLARG ]] && PUBPORT=1500
[[ -z $PUBPORT ]] && [[ -n $PUBSSLARG ]] && PUBPORT=1543

IMAPATH=$APP_PATH/ImaClient/jms
MQTTPATH=$APP_PATH/MQTTClient/
JMS_CLASSPATH=$IMAPATH/lib/imaclientjms.jar:$IMAPATH/lib/jms.jar:$IMAPATH/lib/jmssamples.jar:$IMAPATH
MQTT_CLASSPATH=$MQTTPATH/com.ibm.micro.client.mqttv3.jar:$MQTTPATH/org.eclipse.paho.client.mqttv3.jar:$MQTTPATH


OS=`uname`

case "$OS" in
  AIX)
    JAVA="/usr/java7/jre/bin/java" 
    ;;

  Linux)
    JAVA="/usr/bin/java"
    ;;

  *)
    echo "Unknown OS type $OS. Exiting."
    exit 1
    ;;
esac

TIMEOUT=10
DATE=$(date +"%Y_%m_%d")
MESSAGE="Probe test : $DATE : $$"
FAILCOUNT=0

case $plex in
  p1|p3|p5)
    boxes=$(eilssys -qe role==MESSAGESIGHT systemtype==APPLIANCE.MESSAGESIGHT hostenv==PRD realm==y.ei.$plex)

    for box in $boxes
    do
      pub_sub_connections="$pub_sub_connections ${box}e3:${box}e1 ${box}e3:${box}e2"
    done
    ;;

  pre)
    pub_sub_connections="s41012e1:s41012e1"
    #SUBEPS1="p3msa03e1 p3msa03e2"
    #PUBEPS1="p3msa03e3"
    ;;

  cdt)
    pub_sub_connections="p3msa03e3:p3msa01e1 p3msa03e3:p3msa01e2"
    #SUBEPS1="p3msa03e1 p3msa03e2"
    #PUBEPS1="p3msa03e3"
    ;;

  s1|s2|s3|s4|s5)
    boxes=$(eilssys -qe role==MESSAGESIGHT.SL systemtype==APPLIANCE.MESSAGESIGHT hostenv==PRD|grep $plex)

    for box in $boxes
    do
      pub_sub_connections="$pub_sub_connections ${box}e1:${box}e1"
    done

    ;;
    

  ecc)
    SUBEPS1="9.27.183.81 9.27.183.82"
    PUBEPS1="9.27.183.81 9.27.183.82"
    ;;

  *)
    usage
    exit 1
    ;;

esac

test_publishing() {
  [[ -z $PAUSE ]] && PAUSE=5
  #PAUSE=5
  pub=$1
  sub=$2

  PUBLOG="/tmp/${0##*/}.pub.$$.$pub.$sub"
  SUBLOG="/tmp/${0##*/}.sub.$$.$pub.$sub"

  printf "\n\n===========================================================\n"
  printf "TESTING Site << $plex >>\n" 
  printf "Publisher: $pub\n"
  printf "Subscriber: $sub\n"
  printf "===========================================================\n"

  if [[ $PUB_METHOD == "MQTT" ]] ; then
    PUBCMD="$JAVA $PUBJAVAARG -classpath $MQTT_CLASSPATH EIMQTTClient $PUBSSLARG -a publish -t events/hpods/test/MSe2eprobe -s 0 -b $pub -p $PUBPORT -u r00t$ -P BF7r4AKs6X537aL -m \"$MESSAGE\""
  elif [[ $PUB_METHOD == "JMS" ]] ; then
    PUBCMD="$JAVA $PUBJAVAARG -classpath $JMS_CLASSPATH com.ibm.ima.samples.jms.JMSSample $PUBSSLARG -v -s tcp://$pub:$PUBPORT -a publish -t events/hpods/test/MSe2eprobe -u r00t$ -p BF7r4AKs6X537aL -m \"$MESSAGE\""
  fi

  if [[ $SUB_METHOD == "MQTT" ]] ; then
    SUBCMD="$JAVA $SUBJAVAARG -classpath $MQTT_CLASSPATH EIMQTTClient $SUBSSLARG -a subscribe -t events/hpods/test/MSe2eprobe -s 0 -b $sub -p $SUBPORT -u scoreboard -P PA16h9lD3J7F1d2 -c 1"
  elif [[ $SUB_METHOD == "JMS" ]] ; then
    SUBCMD="$JAVA $SUBJAVAARG -classpath $JMS_CLASSPATH com.ibm.ima.samples.jms.JMSSample $SUBSSLARG -v -s ssl://$sub:$SUBPORT -a subscribe -t events/hpods/test/MSe2eprobe -u scoreboard -p PA16h9lD3J7F1d2 -n 1 -x $TIMEOUT"
  fi

  if [[ -n $DEBUG ]] ; then printf "\nDEBUG:: $SUBCMD\n\n"; fi

  $SUBCMD | tee $SUBLOG &
  sub_pid=$!

  echo "Subscriber starting. Pausing for $PAUSE seconds"

  sleep $PAUSE

  echo "Publisher starting."

  if [[ -n $DEBUG ]] ; then printf "\nDEBUG:: $PUBCMD\n\n"; fi

  eval $PUBCMD|tee $PUBLOG

  wait $sub_pid
  rc=$?

  if [[ $rc -ne 0 ]] ; then
    echo "Subscriber failed"
    FAILCOUNT=$((FAILCOUNT + 1))
  else
    grep -i "Exception" $SUBLOG > /dev/null

    if [[ $? -eq 0 ]] ; then
      echo "Subscriber failed:"
      cat $SUBLOG
    else
      grep "$MESSAGE" $SUBLOG > /dev/null

      if [[ $? -eq 0 ]] ; then
        echo
        echo "SUCCESS"
        echo

        rm $PUBLOG
        rm $SUBLOG
      else
        FAILCOUNT=$((FAILCOUNT + 1))
        printf "\n\n ##### FAILED #####"
        printf "\nReview log files:\n $PUBLOG\n $SUBLOG\n\n" 
      fi
    fi
  fi
}

echo
#echo "************************************************************"
#echo "** Test Device #1 with:"
#echo "** Publishing Endpoints: $PUBEPS1" 
#echo "** Subscription Endpoints: $SUBEPS1" 
#echo "** Publishing Method: $PUB_METHOD"
#echo "** Subscription Method: $SUB_METHOD"
#echo "************************************************************"

for pub_sub in $pub_sub_connections
do
  PUBEP=$(echo $pub_sub|cut -d: -f1)
  SUBEP=$(echo $pub_sub|cut -d: -f2)

  test_publishing $PUBEP $SUBEP
done

#for pub_ep in $PUBEPS1
#do
#  for sub_ep in $SUBEPS1
#  do
#    test_publishing $pub_ep $sub_ep
#  done
#done


#if [[ -n $PUBEPS2 ]] ; then
#  echo "************************************************************"
#  echo "** Test device #2 with:"
#  echo "** Publishing Endpoints: $PUBEPS2" 
#  echo "** Subscription Endpoints: $SUBEPS2" 
#  echo "** Publishing Method: $PUB_METHOD"
#  echo "** Subscription Method: $SUB_METHOD"
#  echo "************************************************************"
#
#  for pub_ep in $PUBEPS2
#  do
#    for sub_ep in $SUBEPS2
#    do
#      test_publishing $pub_ep $sub_ep
#    done
#  done
#fi

