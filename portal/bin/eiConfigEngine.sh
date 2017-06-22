#!/bin/ksh

# author: Thad Hinz
# date  : 02/26/2014

findpath="/usr/WebSphere*/AppServer/profiles/*/ConfigEngine/ConfigEngine.sh"

mycmds=$(find $findpath)

if [[ $mycmds != "" ]];then
  cmdcnt=$(find $findpath | wc -l)
  echo $cmdcnt
else
  echo "No ConfigEngine.sh commands found on this server! Exiting..."
  exit 1
fi

# if more than 1 cmd found place in an array and give user option to select
# otherwise just use the single command found
if [[ $cmdcnt -gt 1 ]];then
  echo "##@## Multiple ConfigEngine.sh commands were found on this server! ##@##"
  echo
  set -A cmd_array $mycmds
  counter=0
  while [[ $counter -lt $cmdcnt ]];do
    echo "$counter - ${cmd_array[$counter]}"
    counter=$(($counter + 1))
  done
  echo
  echo "Type in the number of the command you wish to run or use [CTRL-C] to quit"
  read cmdselect
  runcmd=${cmd_array[$cmdselect]}
else
  runcmd=$mycmds
fi

echo "Executing su - webinst -c \"$runcmd $@\"..."

su - webinst -c "$runcmd $@"
