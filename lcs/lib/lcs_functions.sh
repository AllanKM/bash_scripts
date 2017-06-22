#!/bin/ksh


checkLCSclient() {
#set -x

	date "+%T Checking LCS client"
        if status=$(/etc/init.d/lcs status |grep "^	" | grep -vi ryd); then
		rc=0
		for tuple in ${status}; do
			(IFS=/ set -- ${tuple}; print $*) |while read name conf PID junk; do
			#stoopid pdksh will not read unless wrappered around a while
#				print -u2 "${tuple}#${PID}#${name}#${conf}"
				if  ps -oargs= -p $PID 2>/dev/null| grep ${conf}.conf >/dev/null ; then
					print "\tFound instance ${conf} at PID=${PID} for ${name}"
				else
					print -u2 -- "### Missing LCS client process for ${name} (${conf})"
					rc=1
				fi
			done
		done
	else
		print -u2 -- "######### LCS not running"
		rc=1 
	fi
	return $rc
}
