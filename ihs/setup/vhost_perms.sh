#!/bin/ksh
# Author: Russ Scadden
# Set permissions according to ITCS104 specifications on /projects/<virtual host> directories
# This script should be ran as a "postInstallCmd" for each virtual host sync resource  
# through configtool
#
# USAGE: vhost_perms.sh [list of virtual hosts]
#    where
#        The list of space separated virtual hosts are passed to the  
# set_vhost_perms function one at a time.  Permissions are set on matching /logs/${VHOST}
# and /projects/${VHOST} directories.


#Starting to modulize permissions so various scripts can set permissions
funcs=/lfs/system/tools/ihs/lib/htdig_functions.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"
funcs=/lfs/system/tools/ihs/lib/ihs_functions.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

PROJECTDIR=/projects
VHOSTLIST="$*"

if [[ ! -f /etc/apachectl ]]; then
       echo "/etc/apachectl not found. Please ensure IHS has been installed"
       echo "Exiting..."
       exit 1
fi

for VHOST in `echo $VHOSTLIST` ; do
	if [[ ! "$VHOST" == "" ]]; then
	        if [ -d /projects/${VHOST} ]; then
	                set_vhost_perms $VHOST
	        fi
	        if [[ -d /projects/${VHOST}/search ]]; then
	        	htdig_perms $VHOST
	        fi
	fi
done

if [[ $VHOSTLIST == "" ]]; then
        set_global_server_perms
fi
