#!/bin/sh

#
# Decodes the WebSphere {xor} formatted password provided into clear text.
#

# Author:       James Walton
# Contact:      jfwalton@us.ibm.com
# Date:         25 October 2006
#
#---------------------------------------------------------------------------------
#
# Change History: 
#
#  Lou Amodeo     03-01-2013  Add support for WebSphere V8.5
#
#
#---------------------------------------------------------------------------------
#

directory="/usr/WebSphere85/AppServer /usr/WebSphere70/AppServer /usr/WebSphere61/AppServer /usr/WebSphere60/AppServer /usr/WebSphere/AppServer"

for dir in $directory; do
	if [[ -e $dir ]]; then
		thisDir=$dir
		defScript=$dir/properties/fsdb/_was_profile_default/default.sh
		DEFPROFILE=$(grep setup $defScript|awk '{split($0,pwd,"WAS_USER_SCRIPT="); print pwd[2]}')
		PROFILE=$(echo $DEFPROFILE|awk '{split($0,profile,"/"); print profile[6]}')
		binDir=$dir/profiles/$PROFILE/bin
	    break
	fi
done
if [[ -z $thisDir ]]; then
	echo No valid WebSphere directory found.
	exit
fi
export REPLACE_WAS_HOME=$thisDir
. $binDir/setupCmdLine.sh

if [ $# -eq 1 ]; then
	"$JAVA_HOME/bin/java" "-Dws.ext.dirs=$WAS_EXT_DIRS:$WAS_USER_DIRS" "-Djava.ext.dirs=$JAVA_EXT_DIRS" $JVM_EXTRA_CMD_ARGS -classpath "$WAS_CLASSPATH" com.ibm.ws.bootstrap.WSLauncher com.ibm.ws.security.util.PasswordDecoder $1
else
	echo USAGE:  PasswordDecoder.sh encoded_password
	exit
fi
