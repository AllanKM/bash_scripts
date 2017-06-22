#!/bin/ksh
#
# Author: Chris K
# This script is used to simply locate was plugin logs and clear them out. This will be set to run in cron once every week.
# It was a greed by the apps team that there is no value in long-term retention of this plugin log


# Log file to be cleared:
LOGFILE=http_plugin.log

if [ -d /logs/was* ]; then
   LOGDIRS=`ls -d /logs/was*`
     for DIR in ${LOGDIRS}; do
        if [ -f ${DIR}/${LOGFILE} ]; then
          /usr/bin/cat /dev/null > ${DIR}/${LOGFILE}
        fi
     done
fi