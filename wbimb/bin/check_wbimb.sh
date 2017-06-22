#!/bin/ksh
#Check the health of XIN and WBIMB
#Usage:
#         check_wbimb.sh  

#All errors messages begin the line with "###"
#To look for just errors, run:  check_ihs.sh | grep \#

funcs=/lfs/system/tools/wbimb/lib/wbimb_functions.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

checkPaging 
checkXIN 6

date "+%T ###### $0 Done"
