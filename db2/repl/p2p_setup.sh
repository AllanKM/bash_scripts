#!/bin/ksh

DIR=$(dirname $0)

if [[ $# -lt 2 ]]
  then
    print "Usage: $(basename 0) DBName ApplyQual [TableName1 ...]"
    exit
fi

DB="$1"
AQ="$2"
shift 2
Tables="$*"

$DIR/p2p_src.sh  $DB $AQ $Tables
$DIR/p2p_ctrl.sh $DB $AQ 
