#!/bin/ksh
####################################################################################
# Script Name - check.ksh
# Author - Ronald Lee/China/IBM
# Date - 2011/12/01
# Purpose - A wrapper for check_app.ksh. Run the check scripts for IHS, WAS, bNimble, ITM, LCS, SPONG
#           under /lfs/system/bin/ and store the output to ${logdir}.
#           Then compare and display the Existence, Running and Healthcheck Status of
#           IHS, WAS, bNimble, ITM, LCS, SPONG with the one got in previous run.
####################################################################################


#bdir=/fs/home/ronaldl/s/1.3
bdir=/lfs/system/tools/configtools

[ -f ${bdir}/.fct ] && . ${bdir}/.fct || { echo "${bdir}/.fct not found." >&2; exit 1; }
[ $(id -u) -ne 0 ] && { ECHO Please run this script as root >&2; exit 1; }

hname=$(hostname -s)

bindir=/lfs/system/bin

#logdir=/fs/home/ronaldl/s/1.3/log
logdir=/fs/scratch/${hname}
[ ! -d $logdir ] && mkdir -p -m 775 $logdir

timestamp1=$1
timestamp2=${2:-$(date +%Y%m%d%H%M%S)}

if [ -f ${bdir}/check_app.ksh ]; then

ECHO IHS
ECHO ===
. ${bdir}/check_app.ksh ihs

ECHO WAS
ECHO ===
. ${bdir}/check_app.ksh was

ECHO bNimble
ECHO =======
. ${bdir}/check_app.ksh bNimble

ECHO ITM
ECHO ===
. ${bdir}/check_app.ksh itm

ECHO LCS
ECHO ===
. ${bdir}/check_app.ksh lcs

ECHO SPONG
ECHO =====
. ${bdir}/check_app.ksh spong

else
  ECHO "${bdir}/check_app.ksh not found." >&2
  exit 1
fi
