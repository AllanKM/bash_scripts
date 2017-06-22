 #!/bin/ksh

checkForDonBlick() {
	#set -x
	checkURL=/lfs/system/tools/ihs/bin/chk_url.pm
	MONITOR_DATE=`date --date='1 day ago' +%m%d%Y`
	EVENT=$1
	case $EVENT in
		*masters*)
			#$checkURL masters-search-even 'http://origin.masters.org/search/htsearch?sort=score&format=long&config=masters-even&restrict=&exclude=&method=and&words=donblick' for_search_mon.html
			$checkURL masters-search-odd 'http://origin.masters.org/search/htsearch?sort=score&format=long&config=masters-odd&restrict=&exclude=&method=and&words=donblick' for_search_mon.html
			$checkURL masters-search_mon 'http://origin.masters.org/search/db/for_search_mon.html'  $MONITOR_DATE
			;;
		*ausopen*)
			#$checkURL ausopen-search-even 'http://origin.australianopen.com/search/htsearch?config=ausopen-even&sort=score&format=long&method=and&words=donblick' for_search_mon.html
			$checkURL ausopen-search-odd 'http://origin.australianopen.com/search/htsearch?config=ausopen-odd&sort=score&format=long&method=and&words=donblick' for_search_mon.html
			$checkURL ausopen-search_mon 'http://origin.australianopen.com/search/db/for_search_mon.html'  $MONITOR_DATE
			;;	
		*usopen*)
			$checkURL usopen-search-even 'http://origin.usopen.org/search/htsearch?config=usopen-even&sort=score&format=long&method=and&words=donblick' for_search_mon.html
			#$checkURL usopen-search-odd 'http://origin.usopen.org/search/htsearch?config=usopen-odd&sort=score&format=long&method=and&words=donblick' for_search_mon.html
			$checkURL usopen-search_mon 'http://origin.usopen.org/search/db/for_search_mon.html'  $MONITOR_DATE
			;;
		*usga*)
			$checkURL cmusga-search-even 'http://origin.usopen.com/search/htsearch?config=cmusga-even&sort=score&format=long&method=and&words=donblick' for_search_mon.html
			#$checkURL cmusga-search-odd 'http://origin.usopen.com/search/htsearch?config=cmusga-odd&sort=score&format=long&method=and&words=donblick' for_search_mon.html
			$checkURL masters-search_mon 'http://origin.usopen.com/search/db/for_search_mon.html'  $MONITOR_DATE
			;;
		*tonys*)
			$checkURL tonys-search-even 'http://origin.tonyawards.com/search/tonys/htsearch?config=tonys-even&sort=score&format=long&method=and&words=donblick' for_search_mon.html
			#$checkURL tonys-search-odd 'http://origin.tonyawards.com/search/tonys/htsearch?config=tonys-odd&sort=score&format=long&method=and&words=donblick' for_search_mon.html
			$checkURL tonys-search_mon 'http://origin.tonyawards.com/search/db/for_search_mon.html'  $MONITOR_DATE
			;;
		*wimbledon*)
			$checkURL wimbledon-search-even 'http://origin.wimbledon.org/search/htsearch?config=wimbledon-even&sort=score&format=long&method=and&words=donblick' for_search_mon.html
			#$checkURL wimbledon-search-odd 'http://origin.wimbledon.org/search/htsearch?config=wimbledon-odd&sort=score&format=long&method=and&words=donblick' for_search_mon.html
			$checkURL wimbledon-search_mon 'http://origin.wimbledon.org/search/db/for_search_mon.html'  $MONITOR_DATE
			;;
		*rolandgarros*|*french*)
			#$checkURL rolandgarros-search-even 'http://origin.rolandgarros.com/search/htsearch?config=rg_e-even&sort=score&format=long&method=and&words=donblick' for_search_mon.html
			$checkURL rolandgarros-search-odd 'http://origin.rolandgarros.com/search/htsearch?config=rg_e-odd&sort=score&format=long&method=and&words=donblick' for_search_mon.html
			$checkURL rolandgarros-search_mon 'http://origin.rolandgarros.com/en_FR/search/db/for_search_mon.html'  $MONITOR_DATE
			;;
		*) print -u2 -- "#### Update htdig_functions.sh to recognize $EVENT" ;;
	esac
	
	
	
}


checkSearchIndexing() {
	#set -x
	if [ -d /logs/htdig ]; then
		date "+%T Checking Search Indexing updates"
		for event in $( find /projects/*/content/search /projects/*/content/*/search -name "for_search_mon.html" -mtime +1 -mtime -21 | \
		sed 's!/projects/\(.*\)/content/search/.*!\1!' ); do
		
			print -u2 --  "#### $event search index is older than 24 hours."
			#cd /www/$event/htdocs/; ls -dl search/db
		done
		#All indexes
		find /projects/*/content/search -name "for_search_mon.html"  -mtime -21 | \
			sed 's!\(.*\)/for_search_mon.html!\1!' >>/tmp/$$~
		#good indexes
		find /projects/*/content/search -name "for_search_mon.html" -mtime -1 | \
			sed 's!\(.*\)/for_search_mon.html!\1!' >>/tmp/$$~~
		#display results, run each index in $$~ thru $$~~ to determine staleness
		( cat /tmp/$$~ || cat /tmp/$$~~ ) 2>/dev/null |xargs ls -ild |while read inum  mode link own group size date time time2 file; do
			[ -z "${file}" ] && file="${time2}" || time="${time} ${time2}" # handles date with spaces
			grep -q "$file" /tmp/$$~~ 2>/dev/null && \
				print -- "\t$date $time $file" || \
				print -u2 -- "##stale\t$date $time $file" 
		done
		rm /tmp/$$~ /tmp/$$~~ 2>/dev/null

	else
		print "This node is not configured to run search indexing"
	fi
}

htdig_perms() {
	# Provide the subdirectory under /projects to traverse and set permissons
	# /projects/<sub directory>/search
	# This is used to set permissions after syncing htdig search config files.
	DIR=$1
		
 	if [[ -d /projects/${DIR}/search ]]; then 
 		echo "Setting permissions for search (htdig) in /projects/${DIR}/search" 
		chown root.eiadm /projects/${DIR}/search
		chmod 755 /projects/${DIR}/search
 	else
		print -u2 -- "#### /projects/${DIR}/search directory not found.  Can't set permissions"
	fi
    if [[ -d /projects/${DIR}/search/cgi-bin ]]; then
    	chown -R webinst.eiadm /projects/${DIR}/search/cgi-bin
        chmod -R 750 /projects/${DIR}/search/cgi-bin
    fi
    if [[ -d /projects/${DIR}/search/bin ]]; then
    	chown -R root.eiadm /projects/${DIR}/search/bin
        find /projects/${DIR}/search/bin -type d -exec chmod 750 {} \;
        find /projects/${DIR}/search/bin -type f -exec chmod 740 {} \;
    fi
    if [[ -d /projects/${DIR}/search/conf ]]; then
    	chown -R webinst.eiadm /projects/${DIR}/search/conf
        find /projects/${DIR}/search/conf -type d -exec chmod 750 {} \;
        find /projects/${DIR}/search/conf -type f -exec chmod 640 {} \;
	fi
	
	# Now run through the new directory structure, the old stuff above can stay until we've verified it's all gone
	if [[ -d /projects/${DIR} ]]; then 
 		echo "Setting permissions for search (htdig) in /projects/${DIR}" 
		chown root.eiadm /projects/${DIR}
		chmod 755 /projects/${DIR}
 	else
		print -u2 -- "#### /projects/${DIR} directory not found.  Can't set permissions"
	fi
    if [[ -d /projects/${DIR}/scripts ]]; then
    	chown -R root.eiadm /projects/${DIR}/scripts
        find /projects/${DIR}/scripts -type d -exec chmod 750 {} \;
        find /projects/${DIR}/scripts -type f -exec chmod 550 {} \;
    fi
    if [[ -d /projects/${DIR}/conf ]]; then
    	chown -R webinst.eiadm /projects/${DIR}/conf
        find /projects/${DIR}/conf -type d -exec chmod 750 {} \;
        find /projects/${DIR}/conf -type f -exec chmod 440 {} \;
	fi
	if [[ -d /projects/${DIR}/common ]]; then
    	chown -R webinst.eiadm /projects/${DIR}/common
        find /projects/${DIR}/common -type d -exec chmod 755 {} \;
        find /projects/${DIR}/common -type f -exec chmod 644 {} \;
	fi
}
