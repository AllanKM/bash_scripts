#!/bin/ksh


if [[ $# -lt 2 ]]
  then
    print "Usage: $(basename $0) DBName ApplyQual [TableName1 ...]"
    exit
fi

typeset -u DB AQ Tables

DB="$1"
AQ="$2"
shift 2

if [[ "$1" = "" ]]
  then
    Tables="'$1'"
    shift
    for i in $*
      do
       Tables="$Tables,'$i'"
      done
fi


db2 connect to $DB


if [[ "$Tables" = "" ]]
  then
    db2 "update asn.ibmsnap_register set disable_refresh = 1, source_structure = 7"
  else
    db2 "update asn.ibmsnap_register set disable_refresh = 1, source_structure = 7 where source_table in ($Tables)"
fi

db2 "update asn.ibmsnap_pruncntl set target_structure = 7 where apply_qual = '$AQ'"


db2 terminate
