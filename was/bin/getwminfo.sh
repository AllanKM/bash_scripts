#!/bin/bash
#---------------------------------------------------------------------------------
#
# Change History: 
#
#  Lou Amodeo     03-01-2013  Add support for WebSphere V8.5
#
#
#---------------------------------------------------------------------------------
#

logdir=/fs/scratch/webmodulereport
healthchecks=`cat /lfs/system/tools/was/bin/check_was.sh | grep '$checkURL'`
if [ ! -d $logdir ]; then
  mkdir $logdir
  chmod 775 $logdir 
  chown webinst:eiadm $logdir
fi
if [ -f /usr/WebSphere85/AppServer/bin/wsadmin.sh ]; then
  version="85"
fi
if [ -f /usr/WebSphere70/AppServer/bin/wsadmin.sh ]; then
   version=${version}" 70"
fi
if [ -f /usr/WebSphere61/AppServer/bin/wsadmin.sh ]; then
  version=${version}" 61"
fi
# Exit if no WAS is found
if [ -z $version ]; then
  exit 1
fi

if [[ `whoami` != 'root' ]]; then
  echo "Run with sudo"
  exit 2
fi
for ver in $version; do
  lc=`ls /usr/WebSphere${ver}/AppServer/profiles/*anager 2>/dev/null | wc -l`
# Exit if there is no dmgr profile
  if [ $lc -eq 0 ]; then
    continue
  fi
  lssys `hostname` |grep role |grep 'DM.BACKUP'
  if [ $? -eq 0 ]; then
    echo "BACKUP DM.  Exiting."
    exit 3
  fi 
  dmgrname=`ls /usr/WebSphere${ver}/AppServer/profiles/ |grep anager`
  logname=${logdir}/wmreport-${dmgrname}-`hostname`-was${ver}.txt
  su - webinst -c "/usr/WebSphere${ver}/AppServer/bin/wsadmin.sh -lang jython -f /lfs/system/tools/was/bin/webmoduleinfo.py -conntype NONE |grep -v WASX > ${logname}"
  # Append hc urls
  cat /lfs/system/tools/was/bin/check_was.sh | grep '$checkURL' >> ${logname}
done
