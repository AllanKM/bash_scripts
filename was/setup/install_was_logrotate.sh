#!/bin/bash
# Usage:  install_was_logrotate.sh
WASCFG="/lfs/system/tools/was/conf"
LRFILE="was_logs"
case `uname` in
	AIX)	CFGFILE="was_logs"
			OWNERSHIP="root:system" ;;
	Linux)	CFGFILE="was_logs_linux"
			OWNERSHIP="root:root" ;;
esac

#-- Install Backup cron --#
if [ -f ${WASCFG}/${CFGFILE} ]; then
	echo "Copying ${WASCFG}/${CFGFILE} to /etc/logrotate.d/${LRFILE}"
	cp ${WASCFG}/${CFGFILE} /etc/logrotate.d/${LRFILE}
	chown $OWNERSHIP /etc/logrotate.d/${LRFILE}
	chmod 664 /etc/logrotate.d/${LRFILE}
else
	echo "ERROR: Logrotate configuration file ${WASCFG}/${CFGFILE} was not found."
	exit 1
fi
echo "Done!"