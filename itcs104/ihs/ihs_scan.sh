#!/bin/ksh
HOST=`hostname -s`
if [[ -f /usr/HTTPServer/bin/httpd ]]; then
	if [[ ! -d /logs/audit/ihs ]]; then
		mkdir -p /logs/audit/ihs
	fi
	nohup /lfs/system/tools/itcs104/ihs/ihs_itcs.sh >/logs/audit/ihs/$HOST.dat &
fi
