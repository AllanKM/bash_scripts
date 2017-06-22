#!/bin/ksh

umask 0033

#bdir=${bdir:-/fs/home/ronaldl/s/1.3}
bdir=${bdir:-/lfs/system/tools/configtools}

[ -f ${bdir}/.fct ] && . ${bdir}/.fct || { echo "${bdir}/.fct not found." >&2; exit 1; }
[ $(id -u) -ne 0 ] && { ECHO Please run this script as root >&2; exit 1; }

hname=${hname:-$(hostname -s)}
appname=$1

[ ! ${appname} ] && { ECHO "Usage: $0 <appname>" >&2; exit; }

case ${appname} in
itm)
	binname="cinfo_r"
	bindir=${bindir:-/lfs/system/bin}
	binfile="/opt/IBM/ITM/bin/cinfo -r"
	break
	;;
*)
	binname=check_${appname}
	bindir=${bindir:-/lfs/system/bin}
	binfile=${bindir}/${binname}.sh
	break
	;;
esac

#logdir=${logdir:-/fs/home/ronaldl/s/1.3/log}
logdir=${logdir:-/fs/scratch/${hname}}
if [ ! -d $logdir ]; then
  read ans?"Log directory \"$logdir\" not exist, create?[y/n]: "
  if [[ $ans = [Yy] ]]; then
    mkdir -p -m 775 $logdir
  else
    ECHO "Log directory \"$logdir\" not exist, script aborted." >&2
    exit 1
  fi
fi

timestamp1=${timestamp1:-$2}
timestamp1=${timestamp1:-$(basename $(ls -tr ${logdir}/${binname}.${hname}.*out 2>/dev/null|tail -1) 2>/dev/null|awk -F. '{print $3}')}
timestamp2=${timestamp2:-$3}
timestamp2=${timestamp2:-$(date +%Y%m%d%H%M%S)}

outfile1=${logdir}/${binname}.${hname}.${timestamp1}.out
ec_logfile1=${logdir}/ec_${appname}.${hname}.${timestamp1}.log
rc_logfile1=${logdir}/rc_${appname}.${hname}.${timestamp1}.log
hc_logfile1=${logdir}/hc_${appname}.${hname}.${timestamp1}.log
outfile2=${logdir}/${binname}.${hname}.${timestamp2}.out
ec_logfile2=${logdir}/ec_${appname}.${hname}.${timestamp2}.log
rc_logfile2=${logdir}/rc_${appname}.${hname}.${timestamp2}.log
hc_logfile2=${logdir}/hc_${appname}.${hname}.${timestamp2}.log

#exec 2> /dev/null

# [ -f /lfs/system/bin/check_lcs.sh ] not supported?? To be debug...
#if [ -f ${binfile%% *} ]; then
[ ! -f ${outfile2} ] && ${binfile} > ${outfile2} 2>&1
#else
#ECHO "### ${binfile%% *} not found.  Please use other method to check this." >&2
#ECHO
#return 1
#fi

# [-f /lfs/system/bin/bNimble ] not supported?? To be debug...
#[ -f ${binfile%% *} ] && ${binfile} > ${outfile2} 2>&1 || { ECHO "### ${binfile%% *} not found.  Please use other method to check this." >&2; ECHO; return 1; }

[ -f ${bdir}/ec_${appname}.awk ] && AWK -f ${bdir}/ec_${appname}.awk "${outfile1}" > ${ec_logfile1} 2>/dev/null
[ -f ${bdir}/rc_${appname}.awk ] && AWK -f ${bdir}/rc_${appname}.awk "${outfile1}" > ${rc_logfile1} 2>/dev/null
[ -f ${bdir}/hc_${appname}.awk ] && AWK -f ${bdir}/hc_${appname}.awk "${outfile1}" > ${hc_logfile1} 2>/dev/null
[ -f ${bdir}/ec_${appname}.awk ] && AWK -f ${bdir}/ec_${appname}.awk "${outfile2}" > ${ec_logfile2} 2>/dev/null
[ -f ${bdir}/rc_${appname}.awk ] && AWK -f ${bdir}/rc_${appname}.awk "${outfile2}" > ${rc_logfile2} 2>/dev/null
[ -f ${bdir}/hc_${appname}.awk ] && AWK -f ${bdir}/hc_${appname}.awk "${outfile2}" > ${hc_logfile2} 2>/dev/null

#ECHO ${appname}
#ECHO ===
if [ -f ${ec_logfile2} ]; then
ECHO "Program\t\tPrevious_Status\tCurrent_Status"
ECHO "Check  \t\t${timestamp1:-xxxxxxxxxxxxxx}\t${timestamp2:-xxxxxxxxxxxxxx}"
ECHO "-------\t\t---------------\t--------------"
disp "${ec_logfile1}" "${ec_logfile2}" 15 15 14
ECHO
fi
if [ -f ${rc_logfile2} ]; then
ECHO "Running\t\tPrevious_Status\tCurrent_Status"
ECHO "Check  \t\t${timestamp1:-xxxxxxxxxxxxxx}\t${timestamp2:-xxxxxxxxxxxxxx}"
ECHO "-------\t\t---------------\t--------------"
disp "${rc_logfile1}" "${rc_logfile2}" 15 15 14
ECHO
fi
if [ -f ${hc_logfile2} ]; then
ECHO "Health\t\tPrevious_Status\tCurrent_Status"
ECHO "Check \t\t${timestamp1:-xxxxxxxxxxxxxx}\t${timestamp2:-xxxxxxxxxxxxxx}"
ECHO "------\t\t---------------\t--------------"
disp "${hc_logfile1}" "${hc_logfile2}" 15 15 14
ECHO
fi
