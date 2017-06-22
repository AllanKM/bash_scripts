#!/bin/ksh

checkWASapps() {
        date "+%T Checking WebSphere Processes"
#       # if ps -eoargs= |awk '/AppServer\/j[a]va/ {print $1,$NF}' |sort |uniq -c | grep java ; then
        #PS=$(ps -opid=,comm= -u webinst | awk '/java/ {print $1}' | xargs)
        #PIDList=$( print $PS | tr " " ",")
        #if [ -n "${PS}" ]; then
        #        print "Found the following WebSphere Application Servers:"
        #        ps -p$PIDList -opid=,etime=,args= | awk '{printf "\t PID %s -> %s \n",$1,$NF}' | sort  -k3
        # else
        #        print -u2 -- "########## WebSphere AppServer not running"
        #        return 1
        #fi
        #Use servstatus.ksh script 
        . /lfs/system/tools/was/bin/servstatus.ksh 
}

