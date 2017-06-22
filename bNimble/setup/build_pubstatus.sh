#!/bin/ksh 
# by Mauro Marzorati 3/21/2005
# takes the input of the form
# (check|build) <file1-tuple> <file2-tuple> ... <fileN-tuple>
# where each tuple is <YellowSecs <RedSecs> <stastus_file>
# 
CHECKFILE="/tmp/pubstatus_check.conf"
CONFFILE="/usr/local/etc/pubstatus.conf"

# store the action and split by three
ACTION=$1
shift 1
echo $* |xargs -n3 echo >$CHECKFILE
chmod 644 $CHECKFILE

case $ACTION in 
	check)
		cmp $CHECKFILE $CONFFILE
		RC=$?
		rm $CHECKFILE;;
	build)	
		[ -s $CHECKFILE ] && mv $CHECKFILE $CONFFILE
		RC=$?;;
	*)	
		print -u2 "unknown action $ACTION"
		rm $CHECKFILE
		RC=127;;
esac
exit $RC
