#!/usr/bin/ksh 

#
# mksitetxt.ksh: Script to create site.txt for the specified event
#			and push to appropriate directory
#

case $1 in
	check)
		EVENT=$2
	;;
	*)
		EVENT=$1
	;;
esac


RC=0
TMPFILE=/tmp/site.txt.$$
TARGET=/projects/$EVENT/content/site.txt

echo $EVENT > $TMPFILE
hostname >> $TMPFILE

if $(cmp $TMPFILE $TARGET) ; then
	rm $TMPFILE
	return 0
elif [ "$1" == "check" ]; then
	print -u2 "$TARGET seems out of date for $EVENT on `hostname`"
	rm $TMPFILE
	return 1
else
	cp $TMPFILE /projects/$EVENT/content/site.txt 
	RC=$(($RC+$?))
	chmod 644 /projects/$EVENT/content/site.txt
	RC=$(($RC+$?))
        chown pubinst.apps /projects/$EVENT/content/site.txt
        RC=$(($RC+$?))
	rm $TMPFILE
	RC=$(($RC+$?))
	return $RC
fi
