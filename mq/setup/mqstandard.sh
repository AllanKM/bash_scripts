#!/bin/ksh

#Usage: sudo ./mqstandard.sh <Queue_Manager_Name> <ENV>
# [ENV]: cdt,pre,spp,prd
QMGR=$1
ENV=$2
typeset -l ENV
typeset -u QMGR
cd /fs/projects/$ENV
mkdir $QMGR > /dev/null 2>&1  
chmod 777 $QMGR
cd $QMGR
mkdir config > /dev/null 2>&1
chmod 777 config

cd /fs/backups/
mkdir mq > /dev/null 2>&1 
chmod 777 mq 

cd /logs
mkdir mq > /dev/null 2>&1
chmod 777 mq
