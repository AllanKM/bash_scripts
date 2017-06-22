#!/bin/sh

#
# TIP version - Decodes the WebSphere {xor} formatted password provided into clear text.
#               Supports a WASHOME argument a WASHOME + profile name
# Usage   PasswordDecoder.sh <encoded_password>  [washome] [washome profile_name]

# Ex: PasswordDecoder.sh $pw
#     PasswordDecoder.sh $pw $WASHOME
#     PasswordDencoder.sh $pw $WASHOME JazzSMProfile
#               

# Author:       James Walton (original author) 
# Contact:      jfwalton@us.ibm.com
# Date:         25 October 2006
#---------------------------------------------------------------------------------
# Change History: 
# Lou Amodeo     03-01-2013  Add support for WebSphere V8.5
# E Coley        06-10-2013  TIP version
# E Coley        10-08-2013  Look for common sense WAS HOME
# E C            11-30-2013  Improve error handling  
# E C            06-07-2014  Support WASHOME and TIP PROFILE NAME override to 
#                             support JazzSMProfile  
#---------------------------------------------------------------------------------
#
# Version 1.01
#
WASHOME=/usr/WebSphere70/AppServer
TIPPROFILE=$WASHOME/profiles/TIPProfile
PROFILE_NAME_SUPPLIED=n
encoded_password=""
STD_WAS=/usr/WebSphere70/AppServer
STD_NCO=/opt/IBM/Netcool/tip
STD_TCR=/opt/IBM/TCR/tip
STD_TCR1=/opt/IBM/TCR1/tip


if   [ $# -eq 0 ]; then
   	echo "USAGE:  PasswordDecoder.sh encoded_password [<WASHOME>] [ <WASHOME> <PROFILE_NAME>] "  
    exit
elif [ $# -eq 1 ]; then
    encoded_password=$1   
elif [ $# -eq 2 ]; then   
    encoded_password=$1   
    WASHOME=$2
    TIPPROFILE=$WASHOME/profiles/TIPProfile
    WASHOME_SUPPLIED="y"

elif [ $# -eq 3 ]; then     # 06-2014
    encoded_password=$1   
    WASHOME=$2
    WASHOME_SUPPLIED="y"
    PROFILE_NAME=$3
    TIPPROFILE=$WASHOME/profiles/$PROFILE_NAME
    PROFILE_NAME_SUPPLIED=y
    
else
    echo "USAGE:  PasswordDecoder.sh encoded_password [<WASHOME>] [ <WASHOME> <PROFILE_NAME>]"  
    exit 1     
fi
if [ ! -d $WASHOME ]; then
    if   [ -d $STD_WAS  ]; then WASHOME=$STD_WAS;
    elif [ -d $STD_NCO  ]; then WASHOME=$STD_NCO; 
    elif [ -d $STD_TCR  ]; then WASHOME=$STD_TCR;    
    elif [ -d $STD_TCR1 ]; then WASHOME=$STD_TCR1;  
    else  
        echo "ERROR: No WAS home located...terminating" 
        exit 1     
    fi
    TIPPROFILE=$WASHOME/profiles/TIPProfile 
fi      
PROFILE=$TIPPROFILE
binDir=$PROFILE/bin

if [[ -z $WASHOME ]]; then
	echo No WebSphere directory found at $WASHOME.
	exit 1
fi

if [[ -z $binDir ]]; then
	echo No WAS profilre bin directrory at $binDir
	exit 1
fi

export REPLACE_WAS_HOME=$WASHOME
. $binDir/setupCmdLine.sh
 #echo "pw decoder: JAVA_HOME=$JAVA_HOME" # JAVA_HOME is good
 #echo "pw decoder: encoded_password=$encoded_password"
 #echo "            JAVA_HOME/bin/java=$JAVA_HOME/bin/java"
 
"$JAVA_HOME/bin/java" "-Dws.ext.dirs=$WAS_EXT_DIRS:$WAS_USER_DIRS" "-Djava.ext.dirs=$JAVA_EXT_DIRS" $JVM_EXTRA_CMD_ARGS -classpath "$WAS_CLASSPATH" com.ibm.ws.bootstrap.WSLauncher com.ibm.ws.security.util.PasswordDecoder "$encoded_password"

