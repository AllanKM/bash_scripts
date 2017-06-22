#!/bin/ksh
#Determine if this node is located in staging or production by looking in /etc/resolv.conf
set -- $(grep search /etc/resolv.conf)

while [[ "$1" != "" ]]; do
	if [[ "$1" = [bgy].*.p?.event.ibm.com ]] 
	 then
  		ENV=`echo "$1" | cut -d. -f3`
	fi
    shift
done
echo "$ENV"