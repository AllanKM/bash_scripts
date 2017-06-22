#!/bin/ksh
#Check the health of LCS
#All errors messages begin the line with "###"
#To look for just errors, run:  check_lcs.sh | grep \#

funcs=/lfs/system/tools/lcs/lib/lcs_functions.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

#Call checkLCSclient defined in lib/lcs_functions.sh
checkLCSclient

#rlocke test
date "+%T ###### $0 Done"
