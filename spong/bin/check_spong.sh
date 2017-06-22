#!/bin/ksh
#Check the health of eSpong
#All errors messages begin the line with "###"
#To look for just errors, run:  check_spong.sh | grep \#

funcs=/lfs/system/tools/spong/lib/spong_functions.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

#Call checkSpongClient defined in lib/spong_functions.sh
checkSpongClient

date "+%T ###### $0 Done"
