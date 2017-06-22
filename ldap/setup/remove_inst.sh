#!/bin/bash

# remove LDAP instance and associated databases

inst=$1
if [ ! -d /db2_database/$inst ]; then
	echo $inst instance does not exist
	exit
fi
echo /opt/IBM/ldap/V6.1/sbin/idsslapd -I ${inst} -k
/opt/IBM/ldap/V6.1/sbin/idsslapd -I ${inst} -k  
while ps -ef | grep "ibmslapd -I ${inst}" | grep -v grep >/dev/null; do
	sleep 1
	echo "slapd running"
done

echo /opt/IBM/ldap/V6.1/sbin/idsidrop -I ${inst} -n  
/opt/IBM/ldap/V6.1/sbin/idsidrop -I ${inst} -n  -r
rm -rf /db2_database/$inst/*
