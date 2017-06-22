#!/bin/bash
# Calls xmlaccess.sh to export the entire portal configuration (not including users, user's access
# control, or any other user configurations).

#Globals
WAS_TOOLS=/lfs/system/tools/was/bin
DECODER=${WAS_TOOLS}/PasswordDecoder.sh
PORTAL_TOOLS=/lfs/system/tools/portal
PORTAL_PASSWD=${PORTAL_PASSWD}/etc/portal_passwd
ROLE=`/usr/bin/lssys -n -lrole | grep role | cut -d= -f2`
XMLACCESS=`find /usr/WebSphere*/PortalServer -name "xmlaccess.sh" |grep -v base`
EXPORTXML=/usr/WebSphere61/PortalServer/doc/xml-samples/ExportRelease.xml
OUT=${1:-/tmp/`hostname`-wps-export.xml}

for line in $(cat ${PORTAL_PASSWD} |grep -v ^#);
do
  echo ${ROLE} | grep -q `echo $line |awk -F'|' {'print $1'}`
  if [ $? -eq 0 ]; then
    encrypted_passwd=$(echo $line |awk -F'|' {'print $3'})
    adminID=$(echo $line |awk -F'|' {'print $2'})
    port=$(echo $line |awk -F'|' {'print $5'})
    context=$(echo $line |awk -F'|' {'print $4'})
    break
  fi
done

passwd_string=`$DECODER $encrypted_passwd`
adminPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")

# Execute export command
$XMLACCESS -user $adminID -password $adminPass -url http://localhost:${port}${context}/config -in $EXPORTXML -out $OUT
