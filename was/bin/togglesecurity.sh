#!/bin/bash
WHOAMI=$(whoami)

if [[ $WHOAMI != "root" ]]; then
  echo "Run with sudo or as root"
  exit
fi

usage() {
  echo "Usage: $(basename $0) <dmgr profile> <on | off>"
  exit
}

backup_security() {
  cell=`ls ${1}/config/cells/ |grep -v plugin`
  sec_xml=${1}/config/cells/${cell}/security.xml
  echo ""
  echo "Found "$sec_xml"."
  echo ""
  cat $sec_xml | sed -e '2s/enabled="true"/enabled="false"/' > ${sec_xml}-disabled
  cat $sec_xml | sed -e '2s/enabled="false"/enabled="true"/' > ${sec_xml}-enabled
  chown webinst:eiadm ${sec_xml}*
  chmod 770 ${sec_xml}*
  replace_sec_xml $2 $sec_xml
}

instructions() {
  rm ${sec_xml}-enabled
  rm ${sec_xml}-disabled
  echo
  echo "You must restart the dmgr for the changes to take effect.  To revert security.xml to the original (with security enabled) run the following:"  
  echo 
  echo "sudo $0 $dmgr on"
  echo
}

replace_sec_xml() {
  if [ $1 = 'off' ]; then 
    echo "Setting enabled=\"false\" in ${sec_xml}"
    cp ${sec_xml}-disabled ${sec_xml}
  elif [ $1 = 'on' ]; then 
    echo "Setting enabled=\"true\" in ${sec_xml}"
    cp ${sec_xml}-enabled ${sec_xml}
  else usage
  fi
  echo
  instructions
}

if [ $# -lt 2 ]; then
  usage;
fi

for version in $(find /usr/ -name "WebSphere*" |grep -v AppServer); do
  dmgr=`ls ${version}/AppServer/profiles/ |grep $1`
  if [ $? -eq 0 ]; then backup_security ${version}/AppServer/profiles/${dmgr} $2; fi
done
