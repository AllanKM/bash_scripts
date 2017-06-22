#!/bin/ksh
#Check the health of WebSphere MQ
#Usage:
#         check_mq.sh  [
#To look for just errors, run:  check_mq.sh | grep \#

mq_funcs=/lfs/system/tools/mq/lib/mq_functions.sh
[ -r $mq_funcs ] && . $mq_funcs || print -u2 -- "#### Can't read functions file at $mq_funcs"


cd /var/mqm/qmgrs
if [ $? -ne 0 ]; then
	print -u2 -- "######### Unable to list qmgrs in /var/mqm/qmgrs directory"
    exit 1
fi
        
for QMGR in `ls | grep -v @SYSTEM`; do
	echo $QMGR | grep -i dummy > /dev/null
	if [ $? -eq 0 ]; then
		echo "Skipping DUMMY QMGR: [$QMGR]"
	else
		echo 
		echo "------------------- $QMGR -------------------------"
		checkMQlistener $QMGR
		checkQmgrs $QMGR
		checkMQchannel $QMGR
		checkQdepth $QMGR
		echo "---------------------------------------------------"
		echo
	fi
done