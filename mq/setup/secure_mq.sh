#!/bin/ksh

#############################
#
# security checking
#
#############################

#############################
#
# itcs104 checking
#
#############################

if [[ $SUDO_USER == "" ]]; then
  echo "Please run as \"sudo\""
  exit 1
fi
/lfs/system/tools/mq/bin/mq_itcs104.sh

