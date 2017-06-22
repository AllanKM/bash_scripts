#!/bin/ksh

if [[ $# -lt 3 ]]
  then
    print "Usage: $(basename $0) DBName DBService nodename [nodename2...]"
    exit 1
fi

DB="$1"
DBService="$2"
shift 2
Nodes="$*"



hostname=$(hostname -s  | sed "s/e[01]$//")

#
# Catalog the nodes and DB aliases
#
((c = 0))
for node in $Nodes
  do
    ((c += 1))
    if [[ "$node" = $hostname* ]]
      then
	db2 catalog db $DB as peer$c
      else
	db2 catalog tcpip node $node remote $node server $DBService
	db2 catalog db $DB as peer$c at node $node
    fi
  done
