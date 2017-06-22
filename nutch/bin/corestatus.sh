#!/usr/bin/env bash
usage () {
  echo
  echo "sudo /lfs/system/tools/nutch/bin/corestatus.sh <pre|prd> [role] [port]"
  echo
}
if [[ $EUID -ne 0 ]]; then
  echo "You are not root. Bye."
  exit
fi

case $1 in
pre|PRE)
  ENV=$1
;;
prd|PRD)
  ENV=$1
;;
*)
  usage
  exit
esac

# Run from a search.events.index node, not a search.events.index.p6
THISHOST=`hostname`
THISNODEROLE=`lssys -x csv -l role,hostenv ${THISHOST} |grep -v '#'`
echo $THISNODEROLE |grep -v P6 |grep SEARCH.EVENTS.INDEX |grep -qi $ENV
if [ $? != 0 ];then
  echo 
  echo "You should run this from a SEARCH.EVENTS.INDEX node in ${ENV}"
  echo 
  exit
fi


LFSTOOLS='/lfs/system/tools'
WASBIN="${LFSTOOLS}/was/bin"
PORTREPORT="${WASBIN}/portreport.sh"
encpass=`grep clientauth_yz ${LFSTOOLS}/was/etc/was_passwd`
encpass=${encpass#*yz=}
dcpass=`openssl enc -base64 -d <<< $encpass`
ROLE="WAS.VE.${ENV}"
NODES=`lssys -qe role==${2:-$ROLE}`
SOLRJVM="wwsm_search4"
HTTPTRANSPORT="WC_defaulthost_secure"

getport () {
  $PORTREPORT $1 |grep ${SOLRJVM} |grep ${HTTPTRANSPORT} |awk -F, {'print $NF'}
  echo $port
}

godoit () {
 HOST=$1
 PORT=`getport ${HOST}`
 EVENT=${3:-all}
 curl -s -k --cert /lfs/system/tools/was/etc/ei.yz.was.client.pem --pass $dcpass "https://${HOST}:${2:-$PORT}/slsearch/admin/cores?action=STATUS" | python /lfs/system/tools/nutch/bin/solrstatus.py - ${HOST} ${EVENT} 
 if [ ${4:-nodebug} = 'debug' ]; then
   curl -s -k --cert /lfs/system/tools/was/etc/ei.yz.was.client.pem --pass $dcpass "https://${HOST}:${2:-$PORT}/slsearch/admin/cores?action=STATUS" 
 fi 
}

for h in $NODES; do
  node_status=`lssys -x csv -l nodestatus $h | grep -v ^# |awk -F',' {'print $2'}` 
  if [ $node_status != 'BAD' ]; then
  godoit $h $3 $4 $5
  fi
done
