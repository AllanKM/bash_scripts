#!/bin/bash 

while getopts p:v opt; do
  case $opt in
  p)
    plex=$OPTARG
    if [[ $plex != "p1" && $plex != "P1" && $plex != "p2" && $plex != "P2" && $plex != "p3" && $plex != "P3" && $plex != "pre" && $plex != "PRE" ]] ; then
      echo "Must specify p1|p2|p3|pre"
      exit 2
    fi
    ;;

  v)
    DEBUG="y"
    ;;

  *)
    echo "USAGE: ${0##*/} -p <plex>"
    exit 1
    ;;
  esac
done

IMAPATH=$HOME/MessageSight/ImaClient/jms
CLASSPATH=$IMAPATH/lib/imaclientjms.jar:$IMAPATH/lib/jms.jar:$IMAPATH/lib/jmssamples.jar

JAVA=/usr/java7/jre/bin/java
TIMEOUT=10
MESSAGE="Probe test"
FAILCOUNT=0

case $plex in
  p1)
    SUBEPS1="10.111.8.251 10.111.8.252"
    PUBEPS1="10.111.8.249"
    SUBEPS2="10.111.8.253 10.111.8.254"
    PUBEPS2="10.111.8.250"
    ;;

  p2)
    SUBEPS1="10.111.72.251 10.111.72.252"
    PUBEPS1="10.111.72.249"
    SUBEPS2="10.111.72.253 10.111.72.254"
    PUBEPS2="10.111.72.250"
    ;;

  p3)
    SUBEPS1="10.111.136.251 10.111.136.252"
    PUBEPS1="10.111.136.249"
    SUBEPS2="10.111.136.253 10.111.136.254"
    PUBEPS2="10.111.136.250"
    ;;

  pre)
    SUBEPS1="10.111.160.252 10.111.160.253"
    PUBEPS1="10.111.160.251"
    ;;

  *)
    echo "USAGE: ${0##*/} -p <plex> [-v]"
    exit 1
    ;;

esac

test_publishing() {
  PAUSE=5
  pub=$1
  sub=$2

  PUBLOG="/tmp/${0##*/}.pub.$$.$pub.$sub"
  SUBLOG="/tmp/${0##*/}.sub.$$.$pub.$sub"

  printf "\n\n===========================================================\n"
  printf "TESTING: Publisher - $pub ; Subscriber - $sub\n"

  SUBCMD="$JAVA -classpath $CLASSPATH com.ibm.ima.samples.jms.JMSSample -v -s tcp://$sub:8000 -a subscribe -t events/hpods/test/MSe2eprobe -u scoreboard -p PA16h9lD3J7F1d2 -n 1 -x $TIMEOUT"
  PUBCMD="$JAVA -classpath $CLASSPATH com.ibm.ima.samples.jms.JMSSample -v -s tcp://$pub:1500 -a publish -t events/hpods/test/MSe2eprobe -u r00t$ -p BF7r4AKs6X537aL -m \"$MESSAGE\""

  if [[ -n $DEBUG ]] ; then printf "\nDEBUG:: $SUBCMD\n\n"; fi

  $SUBCMD |tee $SUBLOG &
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
    grep "JMSException" $SUBLOG > /dev/null

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



for pub_ep in $PUBEPS1
do
  for sub_ep in $SUBEPS1
  do
    test_publishing $pub_ep $sub_ep
  done
done

for pub_ep in $PUBEPS2
do
  for sub_ep in $SUBEPS2
  do
    test_publishing $pub_ep $sub_ep
  done
done

