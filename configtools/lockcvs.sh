#!/bin/bash

# usage:   lockcvs <cvs_source> [force|check]

function dircheck() {
   local CDIR=$1
   local BACKUP=$2
   
   pushd $CDIR >/dev/null 2>&1
   
   for file in *; do
	   if [ -d $file ]; then
			dircheck $file $BACKUP/$file
		elif [ -f $file ]; then
		  if test $file -ot $BACKUP/$file ; then
            if [ $WARNED -eq 0 ]; then
               echo "****************************** Warning ************************************"
               echo "*                                                                         *"
               echo "* Files backed up prior to exporting $SOURCE from CVS are newer *"
               echo "* than the CVS copies. Check the correct files are uploaded to CVS    *"
               echo "*                                                                         *"
               echo "****************************** Warning ************************************"
               WARNED=1
	         fi
            echo $BACKUP/$file is newer than `pwd`/$file
         fi
		fi
		
   done
   popd >/dev/null 2>&1
   
}

if [ -z $1 ]; then
	echo "You must supply the name of the package to checkout and lock"
	exit 1
fi
site=`hostname -s |cut -c 1`
SOURCE=$1
me=`whoami`
BASEDIR="/fs/system/src/cvsroot/locks/${SOURCE}"
LOCKFILE="${BASEDIR}/${SOURCE}.lck"
HISTFILE="${BASEDIR}/${SOURCE}.hst"
CVSROOT=/fs/system/src/cvsroot

umask 002

REALM=`lssys -l realm $HOSTNAME | grep realm | awk {'print $3'}`
if [[ "$SOURCE" == "configtool_ds" ]] ; then 
	if [[ ! $REALM == "g.ei.p3"  ]]; then
		echo "This command can only be run from a g.ei.p3 server"
		exit 1
	fi
fi

if [[ "$2" = "force" ]]
	then
		echo "Use the Force"
		force=1
	else
		force=0
fi

if [[ "$2" = "check" ]]; then
	if [ -f $LOCKFILE ]; then
		cat $LOCKFILE
	else
		echo "No lockfile."
	fi
	exit
fi

#if [[ "$2" = "init" ]]; then
#	echo "Initializing ~/src/${SOURCE}..."
#	mkdir -p ~/src
#	cd ~/src
#	cvs checkout ${SOURCE}
#	exit 0
#fi

if [ -f $LOCKFILE ]; then
	echo "WARNING: $LOCKFILE lock file exists!"
	echo "Run cvs checkout ${SOURCE} if you want to checkout the files without locking."
	cat $LOCKFILE
	lck_user=`cat $LOCKFILE | head -1 | awk '{print $3}'`
	if [ $force = 1 ]; then
		echo "Creating new lock file.  Please check config files carefully before editing"
		echo "Creating $LOCKFILE"
		echo "Locked by ${me} on `date`" > $LOCKFILE
		echo "Updating $SOURCE CVS source"
	fi
else
	echo "Creating $LOCKFILE"
	echo "Locked by ${me} on `date`" > $LOCKFILE
	echo "Updating $SOURCE CVS source"

	if [[ ! -d ~/src ]]; then
		mkdir -p ~/src
	fi

	#=============================
	# WR 51641549	Steve Farrell
	#=============================
	if [ -d ~/src/$SOURCE ]; then
		#####################
		# save existing src
		#####################
		
		BACKUP=~/src/$SOURCE.`date +'%Y%m%d'`
		SEQ=1;
		while [ -d $BACKUP ]; do
			let "SEQ += 1"
			BACKUP=~/src/$SOURCE.`date +'%Y%m%d'`_$SEQ
		done
		echo "******************************************************************"
		echo "*"
		echo $SOURCE directory already exists backup being made to 
		echo -e "\t$BACKUP"
		echo "*"
		echo "******************************************************************"
			mv ~/src/$SOURCE $BACKUP
	else
		echo Existing checkout of $1 not found, no backup required
	fi

	# do cvs checkout
	cd ~/src
	cvs checkout $SOURCE
	
	# check if files in backup are newer than checked out ones
	if [ ! -z "$BACKUP" ]; then
		WARNED=0
		dircheck ~/src/$SOURCE/* ~/src/$BACKUP/*
	fi

	# Ensure checked out files match what is already in dirstore
	if [ "$SOURCE" == "configtool_ds" ]; then
		if [ `configtool_ds -t upload | egrep "NEW ROLE|CHANGES within" | wc -l` -ne 0 ]; then
			echo "*********************************************************************"
			echo "IMPORTANT !!!!!!"
			echo "CVS and DIRSTORE copies are not in sync, ensure they are synchronised"
			echo "before continuing with any further updates"
			echo " "
			if [ -f $HISTFILE ]; then
				echo "Previous updates were made by "
				tail -n1 $HISTFILE
			fi
			echo "*********************************************************************"
		fi
	fi
fi

