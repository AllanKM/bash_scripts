#!/bin/ksh
##########################################################################################
#
# jaz_postinstall_was.sh   
#
# Usage:   jaz_postinstall_was.sh
# Wraps a call of  more generic tip post install script.
# Run under sudo
# 
# 2014-06-12 Initial version.
#
##########################################################################################   

VERSION=1.00
SCRIPTNAME=$(basename $0)
scriptdir=/lfs/system/tools/tip/setup
args="$@" 

echo "$SCRIPTNAME version $VERSION  executing with args: $args" 

WH=/usr/WebSphere85/AppServer   
PR=JazzSMProfile
NODE=JazzSMNode01

cmd="$scriptdir/tip_postinstall_was_v3.sh 85 -wh $WH -pr $PR -node $NODE  -heap 512 2048  -debug $args"
echo "Executing $cmd"
$cmd
rc=$?

echo "$SCRIPTNAME completed rc=$rc" 
exit $rc