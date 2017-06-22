#!/bin/ksh

echo "Setting ownership and permissions for Lotus Connections..."
chown -Rh webinst:eiadm /projects/connections*  > /dev/null 2>&1
chmod g+s /projects/connections* > /dev/null 2>&1
chmod -Rh ug+rwx,o-rwx /projects/connections* > /dev/null 2>&1

echo "...Complete"

exit 0