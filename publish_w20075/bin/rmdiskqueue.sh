#!/bin/ksh 
##############################################################################################
#Script will clean out contents of DISTPATH. Using rm alone cannot usually handle the number of files in these dirs
##############################################################################################
DISTPATH='/diskqueue/allisone/toEILocalDist/'
LS=`ls /diskqueue/allisone/toEILocalDist`
for i in $LS ; do
rm $DISTPATH/$i 
done
