#!/bin/ksh
##########################################################################################
#
# jaz_update_pw.sh
#
# Usage:   sudo jaz_update_pw.sh <args>
# Wraps a call of more generic tip update_pw.sh 
#
# Example:
#    sudo ./jaz_update_pw.sh  -newpw  testpw  -d 
#
# 2014-06-12 Initial version.
#
##########################################################################################   

VERSION=1.00
SCRIPTNAME=$(basename $0)
scriptdir=/lfs/system/tools/tip/bin
args="$@" 

echo "$SCRIPTNAME version $VERSION  executing with args: $args" 

cmd="$scriptdir/tip_update_pw.sh jaz $args"
echo "Executing $cmd"
$cmd
rc=$?

echo "$SCRIPTNAME completed rc=$rc" 
exit $rc


