#!/bin/ksh
HOST=`hostname -s`
if [[ -f /usr/HTTPServer/bin/httpd ]]; then
	print "retrieving ihs scan results"
	cat /logs/audit/ihs/$HOST.dat 
fi
