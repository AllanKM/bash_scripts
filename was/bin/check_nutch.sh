#!/bin/bash
# Used on a nutch indexer node to validate whether the index is valid
#
# Note: Can only be run from a SEARCH.EVENTS.INDEX.P6 node or 
# v20055 if you specify test
#
# Usage:
#       sudo check_nutch.sh <0.9 | 1.0> <event-odd|even>
#
validhosts=('v20054' 'v20055') 
if ! echo ${validhosts[*]} |grep -q `hostname`; then 
# Host is not valid
  echo "Valid Hosts: ${validhosts[*]}"
  exit 0
fi
ver=$1
event=$2
search='ibm'
nutchdir=/projects/events/search/nutch-${ver}/${event}/
id=`whoami`
if [ $id != 'root' ]; then
  echo "Run as root or with sudo"
  exit 0
fi
if [ $# -lt 2 ]; then
  echo "Usage:"
  echo "       sudo ./check_nutch.sh <0.9 | 1.0> <event-year>"
  exit 0
fi
if [ ! -d $nutchdir ]; then
  echo "Nutch $ver is not configured for $event"
  exit 0
fi
count=`ps -ef |grep ${event} |grep -c nutch-${ver}|grep -v grep`
if [ $count -gt 0 ]; then
  echo "Nutch is running, index verification will not work while nutch is running"
  exit 0
fi

curdir=`pwd`
export JAVA_HOME=/usr/java6/jre
cd ${nutchdir}
results=`../bin/nutch org.apache.nutch.searcher.NutchBean $search |grep -i "total" |awk -F": " {'print $2'}`
if [ $results -gt 0 ]; then
  echo "PASS"
else
  echo "FAIL"
fi
cd ${curdir}
