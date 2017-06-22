#!/bin/ksh

# Usage:   <path to config dir>/permlist.cfg | /lfs/system/tools/configtools/set_permissions.sh
# where the permlist.cfg file has the following structure per line:
# [full path to directory or file name]	[user] [user perms] [group] [group perms] [other perms]
# For any value that you don't want to alter use a '-' as a place holder
        
echo "Setting permissions..."
while read NAME USER USERPERMS GROUP GROUPPERMS OTHERPERMS 
do
	LINE="$NAME $USER $USERPERMS $GROUP $GROUPPERMS $OTHERPERMS"
	ACTION="$USER $USERPERMS $GROUP $GROUPPERMS $OTHERPERMS"
        USERPERMSCHECK=`echo ${USERPERMS} | sed 's/[rwxsNOE-]//g'`
        GROUPPERMSCHECK=`echo ${GROUPPERMS} | sed 's/[rwxsNOE-]//g'`
        OTHERPERMSCHECK=`echo ${OTHERPERMS} | sed 's/[rwxsNOE-]//g'`
	if [ -z "$NAME" ]; then
		print -u2 -- "#### Ran into a blank line.  Skipping entry ####"
		continue
	elif [ -z "$ACTION" ]; then
		print -u2 -- "#### No ownership or permission actions specified for ${NAME}.  Skipping entry ####"
		continue
	elif [ -z "$USER" ]; then
		print -u2 -- "#### User field not set for ${NAME}.  Use '-' as a place holder for no change.  Skipping entry #####"
		continue
	elif [ -z "$USERPERMS" ]; then
		print -u2 -- "#### User permissions field not set for ${NAME}.  Use '-' as a place holder for no change.  Skipping entry ####"
		continue
        elif [ ! -z "$USERPERMSCHECK" ]; then
                print -u2 -- "#### User permissions field does not contain the accepted values r,w,x,s, or NONE for ${NAME}.  Skipping entry ####"
                continue
	elif [ -z "$GROUP" ]; then
		print -u2 -- "#### No group specified for ${NAME}.  Use '-' as a place holder for no change.  Skipping entry ####"
		continue
	elif [ -z "$GROUPPERMS" ]; then
		print -u2 -- "#### No group permissions specified for ${NAME}.  Use the word NONE to grant no permissions for the group.  Use '-' as a place holder for no change.  Skipping entry ####"
		continue
        elif [ ! -z "$GROUPPERMSCHECK" ]; then
                print -u2 -- "#### Group permissions field does not contain the accepted values r,w,x,s, or NONE for ${NAME}.  Skipping entry ####"
                continue
	elif [ -z "$OTHERPERMS" ]; then
		print -u2 -- "#### No permissions specified for \"other\" for ${NAME}.  Use the word NONE to grant no permissions.  Use '-' as a place holder for no change.  Skipping entry ####"
		continue	
        elif [ ! -z "$OTHERPERMSCHECK" ]; then
                print -u2 -- "#### Other permissions field does not contain the accepted values r,w,x,s, or NONE for ${NAME}.  Skipping entry ####"
                continue
	fi
	ls -ld $NAME > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		print -u2 -- "#### $NAME does not exist.  Skipping entry ####"
		continue
	fi
	if [ "$USER" != '-' ]; then
		/usr/bin/id $USER > /dev/null 2>&1
		if [ $? -ne 0 ]; then 
			print -u2 -- "#### User [$USER] doesn't exist.  Skipping $NAME ####"
			continue
		fi
	fi
	if [ "$GROUP" != '-' ]; then
	   if [ `uname` == "AIX" ]; then
                lsgroup $GROUP > /dev/null 2>&1
           elif [ `uname` == "Linux" ]; then
                cat /etc/group | grep frog > /dev/null 2>&1
           else
                echo "Unsupported OS: `uname`"
                exit 2
           fi
		if [ $? -ne 0 ]; then 
			print -u2 -- "#### Group [$GROUP] doesn't exist.  Skipping $NAME ####"
			continue
		fi
	fi
        for RESULT in `ls -d $NAME`; do
	   if [[ -f "$RESULT" && ! -h "$RESULT" ]]; then
		FILENAME=$RESULT
		echo "File: $FILENAME"
		if [ "$USER" != '-' ]; then
			#echo "     Setting user to $USER"
			chown ${USER} $FILENAME
		fi
		if [ "$USERPERMS" != '-' ]; then
			#echo "     Setting user permissions to $USERPERMS"
			chmod u=${USERPERMS} $FILENAME
		fi
		if [ "$GROUP" != '-' ]; then
			#echo "     Setting group to $USER"
			chgrp ${GROUP} $FILENAME
		fi
		if [ "$GROUPPERMS" != '-' ]; then
		 	#echo "     Setting group permissions to $GROUPPERMS"
                        if [ "$GROUPPERMS" == "NONE" ]; then
                            GROUPPERMS=" "
                        fi
			chmod g=${GROUPPERMS} $FILENAME
		fi
		if [ "$OTHERPERMS"  != '-' ]; then
			#echo "     Setting permissions for other to $OTHERPERMS"
                        if [ "$OTHERPERMS" == "NONE" ]; then
                            OTHERPERMS=" "
                        fi 
			chmod o=${OTHERPERMS} $FILENAME
		fi
	   elif [ -h "$RESULT" ]; then
                FILENAME=$RESULT
                echo "Symlink: $FILENAME"
                if [ "$USER" != '-' ]; then
                        #echo "     Setting user to $USER"
                        chown -h ${USER} $FILENAME
                fi
                if [ "$GROUP" != '-' ]; then
                        #echo "     Setting group to $USER"
                        chgrp -h ${GROUP} $FILENAME
                fi
           elif [ -d "$RESULT" ]; then
		DIRNAME=$RESULT
		echo "Directory: $DIRNAME"
		if [ "$USER" != '-' ]; then
			#echo "     Setting user to ${USER}"
		        chown ${USER} $DIRNAME
                fi
		if [ "$USERPERMS" != '-' ]; then
			#echo "     Setting user permissions to $USERPERMS"
			chmod u=${USERPERMS} $DIRNAME
		fi
		if [ "$GROUP" != '-' ]; then
			#echo "     Setting group to ${GROUP}"
			chgrp ${GROUP} $DIRNAME
		fi
		if [ "$GROUPPERMS" != '-' ]; then
			#echo "     Setting group permissions to $GROUPPERMS"
                        if [ "$GROUPPERMS" == "NONE" ]; then
                            GROUPPERMS=" "
                        fi
			chmod  g=${GROUPPERMS} $DIRNAME
		fi
		if [ "$OTHERPERMS"  != '-' ]; then
			#echo "     Setting permissions for other to $OTHERPERMS"
                        if [ "$OTHERPERMS" == "NONE" ]; then
                            OTHERPERMS=" "
                        fi 
			chmod o=${OTHERPERMS} $DIRNAME
		fi
	   fi
        done
done
