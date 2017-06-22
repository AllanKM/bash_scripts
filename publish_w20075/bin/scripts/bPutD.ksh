#!/usr/bin/ksh

#USEFP=$1
FILETOPUB=$2
URL=$3
EVENT=$4

#if [ $USEFP="-fullpath" ]; then
#	JAVA=/usr/java130/bin/java
#else
#	JAVA=java
#fi

$JAVA -classpath /fs/system/tools/publish/bin/bNimble.jar com.ibm.events.util.bPut -url $URL -event $EVENT -debug -stats $FILETOPUB
