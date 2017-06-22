#!/bin/bash
# Usage:  install_wxs_logrotate.sh
WXSCFG=/lfs/system/tools/wxs/conf
CFGFILE=wxs_logs
#-- Install logrotate.d config --#
if [ -f ${WXSCFG}/${CFGFILE} ]; then
	echo "Copying ${WXSCFG}/${CFGFILE} to /etc/logrotate.d/"
	cp ${WXSCFG}/${CFGFILE} /etc/logrotate.d/${CFGFILE}
	case `uname` in
		AIX) chown root:system /etc/logrotate.d/${CFGFILE} ;;
		Linux) chown root:root /etc/logrotate.d/${CFGFILE} ;;
	esac
	chmod 664 /etc/logrotate.d/${CFGFILE}
else
	echo "ERROR: Logrotate configuration file ${WXSCFG}/${CFGFILE} was not found."
	exit 1
fi
echo "Done!"