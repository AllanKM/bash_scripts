#!/bin/ksh

if [[ $# = 2 ]]
then
  typeset -u LOCAL_DB=$1
  typeset -u LOCAL_SCHEMA=$2
elif [[ $# = 0 && -n $QREP_LOCAL_DB && -n $QREP_SCHEMA ]] 
then
  typeset -u LOCAL_DB=$QREP_LOCAL_DB
  typeset -u LOCAL_SCHEMA=$QREP_SCHEMA
else
  echo "Usage: $0 <localDB> <localSchema>" 
  echo "or set env variables QREP_LOCAL_DB, QREP_SCHEMA"
  exit 50 
fi

ADMIN_GROUP=mqm
if ! id -Gn | grep -w $ADMIN_GROUP 2>/dev/null >/dev/null
then
  echo "You have to be member of the group $ADMIN_GROUP to run this script!" >&2
  exit 2
fi

# alias with 32-bit environment
for ENV_VAR in $QREP_VARS
do
  export $ENV_VAR
done

NO_PROCS=0
echo 
echo "Process-Status Q-Replication $LOCAL_DB"
echo "--------------------------------------"
CAP_PS=$(ps -ef | grep asnqcap | grep -i $LOCAL_DB | grep -v grep)
CAP_ACTIVE=$?
if [[ $CAP_ACTIVE = 0 ]]
then
  echo "1) Capture-Process is active"
  echo $CAP_PS
  (( NO_PROCS += 1 ))
else
  echo "1) Capture-Process is stopped or not running"
fi
echo

APP_PS=$(ps -ef | grep asnqapp | grep -i $LOCAL_DB | grep -v grep)
APP_ACTIVE=$?
if [[ $APP_ACTIVE = 0 ]]
then
  echo "2) Apply-Process is active"
  echo $APP_PS
  (( NO_PROCS += 1 ))
else
  echo "2) Apply-Process is stopped or not running"
fi

echo
#echo "internal  Status  Q-Replikation $LOCAL_DB" 
#echo "-------------------------------------------"
#if [[ $CAP_ACTIVE = 0 ]]
#then
#  echo "1)  Status Capture-Process"
#  asnqccmd capture_server=$LOCAL_DB capture_schema=$LOCAL_SCHEMA status
#else
#  echo "1) Capture-Process is stopped"
#fi
echo
#if [[ $APP_ACTIVE = 0 ]]
#then
#  echo "2)Status Apply-Process"
#  asnqacmd apply_server=$LOCAL_DB apply_schema=$LOCAL_SCHEMA status
#else
#  echo "2) Apply-Prozess is stopped"
#fi
echo

/lfs/system/tools/db2/bin/Qrepdbstatus.sh $LOCAL_DB

/lfs/system/tools/db2/qlatencyreport.ksh $LOCAL_DB

exit $NO_PROCS
