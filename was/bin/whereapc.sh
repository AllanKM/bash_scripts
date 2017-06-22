#!/bin/bash
user=`whoami`
if [[ $user != 'root' ]]; then
  echo "Run as sudo"
  exit 1
fi
if [ ! -f /usr/WebSphere70/AppServer/bin/checkPlacementLocation.jacl ]; then
  echo "checkPlacementLocation.jacl does not exist, VE is either not installed or the script is missing.  Exiting."
  exit 1
else
  output=`su - webinst -c '/usr/WebSphere70/AppServer/bin/wsadmin.sh -f /usr/WebSphere70/AppServer/bin/checkPlacementLocation.jacl'`
fi
cat <<EOF | python - "$output"
import sys
server,node = sys.argv[1].split('SERVER_NAME ')[1].split('}')[0], sys.argv[1].split('NODE_NAME ')[1].split('}')[0]
print "APC Log location: %s:/logs/was70/%s/%s/apc.log" % (node, node, server)
EOF
