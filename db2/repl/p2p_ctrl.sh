#!/bin/ksh


if [[ $# -ne 2 ]]
  then
    print "Usage: $(basename 0) DBName ApplyQual"
    exit
fi

typeset -u DB AQ

DB="$1"
AQ="$2"


db2 connect to $DB


# This is not needed when using db2cc.
#db2 "delete from asn.ibmsnap_subs_set where apply_qual = '$AQ' and whos_on_first = 'F'"

db2 "update asn.ibmsnap_subs_set set whos_on_first = 'F' where apply_qual = '$AQ'"

db2 "update asn.ibmsnap_subs_membr set whos_on_first = 'F', target_structure = 7 where apply_qual = '$AQ'"

db2 "update asn.ibmsnap_subs_cols set whos_on_first = 'F' where apply_qual = '$AQ'"


db2 terminate
