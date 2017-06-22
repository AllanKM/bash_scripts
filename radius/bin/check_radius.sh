#!/bin/ksh

# get radius version info
# check process running
# check response

if [[ $SUDO_USER == "" && $USER != "root" ]]; then
	print -u2 -- "This script requires root privileges, use sudo or su to root"
	exit 16
fi

radius=$(ps -ef | grep /usr/sbin/radiusd | grep -v grep )
proc=$(print $radius | awk '{print $2}')
conf_dir=${radius#*-d}
conf_dir=$(print $conf_dir | awk '{print $1}')


print "Freeradius installed in $conf_dir"
rpm -qi freeradius | {
	while read line; do
		if [[ "$line" = *@(Version|Release)* ]];then 
			print $line | sed -e "s/Build.*$//" -e "s/Vendor.*$//"
			installed=1			
		fi 
	done
}

if [ -z "$installed" ]; then 
	print "error: freeradius is not installed"
	exit 16
fi

print "\nChecking processes"
if [ -n "$proc" ]; then 
	print "\tRadiusd process id: $proc"
else
	print "\t#### Radiusd not running"
	exit 16
fi 
print "\tUp since: " $(ps -eo lstart,cmd | grep -v grep | grep radiusd | sed -e 's/\/.*$//')

secret=$(cat $conf_dir/clients.conf | awk '/localhost/,/}/' | awk '/secret/ {print $3}')

print "\nChecking connections"
echo "User-Name = 00000000000R" | radclient -d $conf_dir -t 2 -s localhost:1812 auth $secret 2>&1 | {
	while read line; do
		if [[ "$line" = *"Total lost auths:  1"* ]]; then 
			print "\t#### $line  - server did not respond"
			unset working
		elif [[ "$line" = *"Total denied auths:  1"* ]]; then
			print "\t$line - successful response, server working"
			working=1
			elif [[ "$line" = *"Total approved auths:  1"* ]]; then
			print "\t#### $line - server responded, but should not have approved auth. Check ldap/db2 connections in radius"
			working=1
		#	else
			#print "$line"
		fi 
	done
}
