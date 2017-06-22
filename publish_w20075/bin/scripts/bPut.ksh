#!/usr/bin/ksh

FILETOPUB=$1
URL=$2
EVENT=$3

java -Xmx64M -classpath "/fs/system-RW/tools/publish/bin/bNimble1320.jar:/fs/system-RW/tools/publish/bin/GAF1000.jar:/fs/system-RW/tools/publish/bin/bNimbleApps.jar" com.ibm.events.bnimbleapps.bput.bPut -url $URL -event $EVENT -stats -debug $FILETOPUB 
