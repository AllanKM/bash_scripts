#!/bin/bash

lssys -qe role==*WAS.* > /tmp/washosts.txt
lssys -qe role==*WPS.* >> /tmp/washosts.txt
if [ -f /opt/freeware/bin/echo ]; then
  echo="/opt/freeware/bin/echo -n"
else
  echo="/usr/bin/echo"
fi

function set_hostlist {
  if [ ${nodegroups+1} ]; then 
    hostlist="-N $nodegroups"
  else
    hostlist="-w ${hosts:-/tmp/washosts.txt}"
  fi
}

function print_usage {
  echo "Example usage:"
  echo "  ./wherefix.sh -f 71126 -w w20031,w20032 - Search hosts w20031,w20032 for fix 71126"
  echo "  ./wherefix.sh -f 71126 -N WPS.SPE.PRD   - Search the node group WPS.SPE.PRD for fix 71126"
  echo "  ./wherefix.sh -f 71126                  - Search all was hosts for fix 71126   "
  echo ""
  echo "The arguments to use are:"
  echo "  -f <fix search string>"
  echo "  -w <comma delimited hosts with no spaces - not to be used with -N>"
  echo "  -N <comma delimited Node group with no spaces - not to be used with -w>" 
  echo "  Note: If -w or -N are not specified, all was hosts will be searched"
  echo ""
}

function process_args {
len=$#
if [ $len -eq 0 ]; then
  print_usage
  exit
fi
even=$(( $len%2 ))
while [ $# -gt 0 ]
do
  if [ $even -eq 0 ]; then
  case $1
  in
    -w)
      if [ ${nodegroups+1} ]; then print_usage; exit; fi
      hosts=$2
      shift 2
    ;;
    -f)
      fix=$2
      shift 2
    ;;
    -N)
      if [ ${hosts+1} ]; then print_usage; exit; fi
      nodegroups=$2
      shift 2
    ;;
    *)
      print_usage
      exit
    ;;
  esac
  else
      print_usage
      exit
  fi
done
}

function find_fix {
  echo "Searching for efix $fix"
  dssh -a ${hostlist} "if [ -f /usr/WebSphere60/AppServer/bin/versionInfo.sh ]; then $echo "WebSphere60:"; sudo /usr/WebSphere60/AppServer/bin/versionInfo.sh -maintenancePackages | grep $fix 2>/dev/null; if [ \$? -ne 0 ]; then echo \"Not Installed\"; fi; fi;\
    if [ -f /usr/WebSphere61/AppServer/bin/versionInfo.sh ]; then $echo "WebSphere61:"; sudo /usr/WebSphere61/AppServer/bin/versionInfo.sh -maintenancePackages |grep $fix 2>/dev/null; if [ \$? -ne 0 ]; then echo \"Not Installed\"; fi; fi;" 
  rm /tmp/washosts.txt
}

process_args $*
set_hostlist
find_fix