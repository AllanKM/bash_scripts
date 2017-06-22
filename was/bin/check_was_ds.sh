#!/bin/ksh
#Check the health of WebSphere Application Server
#Usage:
#         check_was.sh  [list of applications]
#Example: check_was.sh guestbook netpoll
#If no arguements are passed then roles associated with the node are used to determine apps
#All errors messages begin the line with "###"
#To look for just errors, run:  check_was.sh | grep \#

# To look for 3 occurrences of the word "SUCCEEDED" the the html generated from a health 
# check use the following perl regular expression:
# (?s)(SUCCEEDED.*){3,}?
# where (?s) tells perl to match newlines as well as any character and space for '.*'
# and {3,}? tells perl to look for 3 or more occurrences of SUCCEEDED in the HTML


was_funcs=/lfs/system/tools/was/lib/was_functions.sh
[ -r $was_funcs ] && . $was_funcs || print -u2 -- "#### Can't read functions file at $was_funcs"

checkURL=/lfs/system/tools/ihs/bin/chk_url.pm
ARGS=$*
user=`whoami`
#Call various functions defined in was/lib/was_functions.sh
checkWASapps

if [ $# -eq 0 ]; then

  #no args passed, lets look for WAS related roles
  funcs=/lfs/system/tools/configtools/lib/check_functions.sh
  [ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"
  getRoles
  for ROLE in $ROLES; do
    typeset -l ROLE
    if [[ "$ROLE" = "was"* || "$ROLE" = "wps"* ]]; then 
      case $ROLE in
        WAS.DM.*)
          /lfs/system/tools/configtools/countprocs.sh 1 $MYPID > /dev/null && echo "$APP OK"
          /lfs/system/tools/configtools/countprocs.sh 1 $MYPID > /dev/null || print -u2 --  "####Failed to find dmgr running" ;;
        *)
          /lfs/system/tools/was/bin/hcls -r $ROLE|grep -i instances > /tmp/.dsls_${user}.tmp
          while read -r URL
          do
            APP=`echo "${URL}"|cut -d "=" -f2|awk -F "@@" '{print $1}'`
            PASS_PARAM=`echo "${URL}"|awk -F "@@" '{print $3}'`
echo "aaaaa:${PASS_PARAM}"
            URL=`echo "${URL}"|awk -F "@@" '{print $2}'`
            TIMEOUT=`echo "${URL}"|awk -F "@@" '{print $4}'`
            export CHK_DELAY=${TIMEOUT}
            $checkURL "${APP}" "${URL}" "${PASS_PARAM}"
            unset CHK_DELAY
          done < /tmp/.dsls_${user}.tmp
          ;;
      esac
    fi
  done
else
  for ARG in $ARGS; do
    typeset -l ARG
    /lfs/system/tools/was/bin/hcls -a $ARG|grep -i instances > /tmp/.dsls_${user}.tmp
    while read -r URL
    do
      PASS_PARAM=`echo "${URL}"|awk -F "@@" '{print $3}'`
      APP=`echo "${URL}"|cut -d "=" -f2|awk -F "@@" '{print $1}'`
      URL=`echo "${URL}"|awk -F "@@" '{print $2}'`
      TIMEOUT=`echo "${URL}"|awk -F "@@" '{print $4}'`
      export CHK_DELAY=${TIMEOUT}
      $checkURL "${APP}" "${URL}" "${PASS_PARAM}"
      unset CHK_DELAY
    done < /tmp/.dsls_${user}.tmp
  done
fi


echo "###### $0 Done"
