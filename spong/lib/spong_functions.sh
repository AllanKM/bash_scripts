#!/bin/ksh

checkSpongClient() {
	date "+%T Checking Spong"
	if ps -eoargs= |sort |uniq -c |grep sp[o]ng\- ; then 
		return 0
	else
		print -u2 -- "####### Spong not running"
		return 1
	fi
}