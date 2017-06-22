#!/bin/ksh
if [[ $SUDO_USER != "" ]]; then
	if [[ -f /usr/HTTPServer/bin/httpd ]]; then
		cd /lfs/system/tools/ihs/bin
		./ihs_dirs.sh
		./ihs_osrs.sh
		./ihs_cgi.sh
		./ihs_autoindex.sh
	else
		print "IHS not installed on this server"
	fi
else
	print "This script needs to be run using sudo"
fi
