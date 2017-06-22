#!/bin/bash

# check we're running as root
if [[ `whoami` != "root" ]]; then
   echo "This script must be run using sudo."
   exit
fi

# check for multiple WebSphere dirs
if [[ $(ls -1d /usr/WebSphere* | wc -l | sed 's/ *//g') -gt 1 ]]; then
   for dir in $(ls -1d /usr/WebSphere*); do
      num=$((num+1))
      version[$num]=$dir
      echo -e "\t[$num]\t$dir";
   done
   if [[ $num -gt 1 ]]; then
      REPLY=0
      while [[ $REPLY -gt $num ]] || [[ $REPLY -eq "0" ]]; do
         read -p "Enter number for the WebSphere version you want to use: "
      done
   else REPLY=1
   fi
   DIR=${version[$REPLY]}
   echo
else
   DIR=$(ls -1d /usr/WebSphere*)
fi

# set some variables
WAS_VER=${DIR#/usr/WebSphere}
WAS_DIR="${DIR}/AppServer"
TOOLS_DIR="/lfs/system/tools/was"
WSADMIN="${WAS_DIR}/profiles/*/bin/wsadmin.sh -lang jython"

# get the cell of the dmgr
defScript=${WAS_DIR}/properties/fsdb/_was_profile_default/default.sh
DEFPROFILE=$(grep setup $defScript|awk '{split($0,pwd,"WAS_USER_SCRIPT="); print pwd[2]}')
PROFILE=$(echo $DEFPROFILE|awk '{split($0,profile,"/"); print profile[6]}')
if [ "$PROFILE" == "" ]; then
   echo "Failed to find the default profile"
   echo "exiting...."
   exit 1
fi
CELL=`grep WAS_CELL= ${WAS_DIR}/profiles/$PROFILE/bin/setupCmdLine.sh | cut -d= -f2`
LOGFILE=/logs/was${WAS_VER}/${CELL}Manager/dmgr/client_auth_config.log
[[ ! -d /logs/was${WAS_VER}/${CELL}Manager/dmgr ]] && LOGFILE=/tmp/client_auth_config.log

# we put the main routine in a code block in order to redirect all the output to the logfile
{
   date
   echo "Running against WAS version ${WAS_VER}, logging to ${LOGFILE}"
   
   # create EIClientAuth SSL Config
   read -p "Create the EIClientAuth SSL Config? "
   echo "$REPLY" >> $LOGFILE
   if [[ "$REPLY" == [Yy] ]]; then
      echo "   Creating the EIClientAuth SSL configuration"
      cat > /tmp/createClientAuthSSLconfig.py <<EOF
try:
   AdminTask.createSSLConfig('[ \
-alias EIClientAuth \
-type JSSE \
-scopeName (cell):${CELL} \
-trustStoreName CellDefaultTrustStore \
-trustStoreScopeName (cell):${CELL} \
-keyStoreName CellDefaultKeyStore \
-keyStoreScopeName (cell):${CELL} \
-jsseProvider IBMJSSE2 \
-sslProtocol SSL_TLS \
-clientAuthentication true \
-securityLevel HIGH -enabledCiphers ]')
   print "      Created SSL config"
except:
   print "      ERROR: Something went wrong creating the SSL config"
AdminConfig.save()
EOF
      ${WSADMIN} -f /tmp/createClientAuthSSLconfig.py
      rm -rf /tmp/createClientAuthSSLconfig.py
   fi
   
   # apply the SSL config
   read -p "Change inbound SSL configuration, cluster by cluster (confirmation asked before each cluster unless you answer 'a' for all)? "
   echo "$REPLY" >> $LOGFILE
   if [[ "$REPLY" == [YyAa] ]]; then
      # get list of clusters
      echo "   Getting a list of clusters"
      CLUSTER_LIST=$(${WSADMIN} -f ${TOOLS_DIR}/lib/cluster.py -action list | grep -v WASX)
      for CLUSTER in ${CLUSTER_LIST}; do
         [[ "$REPLY" == [Yy] ]] && read -p "      Apply client auth SSL config to ${CLUSTER}? "
         if [[ "$REPLY" == [YyAa] ]]; then
            [[ "$REPLY" == [Yy] ]] && echo "$REPLY" >> $LOGFILE
            cat > /tmp/applyCA_SSL_conf_${CLUSTER}.py <<EOF
try:
   AdminTask.createSSLConfigGroup('[\
-name ${CLUSTER} \
-scopeName (cell):${CELL}:(cluster):${CLUSTER} \
-direction inbound \
-certificateAlias \
-sslConfigAliasName EIClientAuth \
-sslConfigScopeName (cell):${CELL} ]')
   print "         Applied client auth SSL config to ${CLUSTER} successfully"
except:
   print "         ERROR: Something went wrong applying the client auth SSL config to ${CLUSTER}"
AdminConfig.save()
EOF
            ${WSADMIN} -f /tmp/applyCA_SSL_conf_${CLUSTER}.py
            rm -rf /tmp/applyCA_SSL_conf_${CLUSTER}.py
         else
            REPLY="Y"
         fi
      done
   fi
   
   # sync the nodes
   echo
   echo "To take effect, this requires a simple sync - no cluster/JVM restarts are required."
   read -p "Sync running nodeagents (confirmation asked before each node unless you answer 'a' for all)? "
   echo "$REPLY" >> $LOGFILE
   if [[ "$REPLY" == [YyAa] ]]; then
      echo "   Getting list of running nodeagents"
      NODE_LIST=$(${WSADMIN} -c "print AdminControl.queryNames('type=Server,name=nodeagent,*')" | grep node= | sed 's/.*node=//g' | sed 's/,.*//g')
      for NODE in ${NODE_LIST}; do
         [[ "$REPLY" == [Yy] ]] && read -p "      Sync ${NODE}? "
         if [[ "$REPLY" == [YyAa] ]]; then
            [[ "$REPLY" == [Yy] ]] && echo "$REPLY" >> $LOGFILE
            ${WSADMIN} -f ${TOOLS_DIR}/lib/node.py -action sync -node ${NODE}
         else
            REPLY="Y"
         fi
      done
   fi
   
   echo
   echo "All done. Have a truly wonderful day, safe in the knowledge that the ITCS104 police can't now shout at us about this :-)"
} 2>&1 | tee -a ${LOGFILE}

chown ${SUDO_USER} ${LOGFILE}
