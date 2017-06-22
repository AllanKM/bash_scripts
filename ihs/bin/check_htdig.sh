#!/bin/ksh
#Check the health of HtDig

#All errors messages begin the line with "###"
#To look for just errors, run:  check_htdig.sh | grep \#

funcs=/lfs/system/tools/ihs/lib/htdig_functions.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"


#Call various functions defined in lib/htdig_functions.sh
date "+%T Checking Search Results"
#Update the list of events to check as the site launches in the EI and when it is switched to it's year round hosting"
SITES_TO_CHECK_SEARCH="masters rolandgarros"
for site in $SITES_TO_CHECK_SEARCH; do
	checkForDonBlick $site 
done

checkSearchIndexing

date "+%T ###### $0 Done"
