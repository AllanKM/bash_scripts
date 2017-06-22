#!/bin/bash
#   Usage: was_tsm_restore.sh version=VERSION [dir=DIRECTORY] [tmpdir=DIRECTORY] [date=DATE] [time=TIME]"
#			Date format: MM/DD/YYYY
#			Time format: HH:MM:SS
#	* Leave off date/time to restore from the most recent backup

TSMrestore () {
	#Prep any date/time parameters
	if [ -z "$RDATE" ] && [ -z "$RTIME" ]; then
		#Restore from last backup
		DATE_PARAMS=""
	elif [ -z "$RDATE" ] && [ -n "$RTIME" ]; then
		#Restore from backup within last 24 hours
		TODAY=`date +"%m/%d/%Y"`
		DATE_PARAMS="-pitdate=${TODAY} -pittime=${RTIME}"
	elif [ -n "$RDATE" ] && [ -z "$RTIME" ]; then
		#Restore from last backup on given date
		EOD="23:59:59"
		DATE_PARAMS="-pitdate=${RDATE} -pittime=${EOD}"
	elif [ -n "$RDATE" ] && [ -n "$RTIME" ]; then
		#Restore from specific date and time
		DATE_PARAMS="-pitdate=${RDATE} -pittime=${RTIME}"
	fi
	
	#Check if restoring to a tmp dir
	if [ -n "$TMPDIR" ]; then
		echo "Performing TSM restore of $RESTOREDIR to temporary directory $TMPDIR..."
		dsmc restore "$RESTOREDIR" $TMPDIR $DATE_PARAMS
	else
		echo "Checking for running WebSphere processes..."
		/lfs/system/tools/was/bin/servstatus.ksh 2>&1 |grep -v "RUNNING COUNT" |grep RUNNING > /dev/null
		if [ $? -eq 0 ]; then
			echo "### ERROR: Found running WebSphere processes, please stop them before attempting in-place TSM restore."
			exit 1
		fi
		echo "About to perform TSM restore of $RESTOREDIR to $RESTOREDIR..."
		printf "\nThis will overwrite everything under $RESTOREDIR, are you sure? (y/n) "
		read confirm
		case $confirm in
			[Yy])	dsmc restore "$RESTOREDIR" $DATE_PARAMS ;;
			*)	echo "Aborting TSM restore of $RESTOREDIR..."
				exit 0 ;;
		esac
	fi
}

HOST=`hostname`
#process command-line options
until [ -z "$1" ] ; do
    case $1 in
		version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VERSION=$VALUE; fi ;;
		dir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then RESTOREDIR=$VALUE; fi ;;
		tmpdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TMPDIR=$VALUE; fi ;;
		date=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then RDATE=$VALUE; fi ;;
	    time=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then RTIME=$VALUE; fi ;;
		*)	echo "#### Unknown argument: $1"
            echo "#### Usage: Usage: was_tsm_restore.sh version=VERSION [dir=DIRECTORY] [tmpdir=DIRECTORY] [date=DATE] [time=TIME]"
            exit 1
			;;
	esac
	shift
done

#Check for requested restore date and formatting
if [ -n "$RDATE" ]; then
	echo $RDATE | grep '[01][0-9]/[0-3][0-9]/20[0-9][0-9]' > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "Please specify the date you wish to restore in the format: MM/DD/YYYY"
		echo "exiting..."
		exit 1
	else
		echo "Requested restore date: $RDATE"
	fi
fi

#Check for requested restore time
if [ -n "$RTIME" ]; then
	echo $RTIME | grep '[0-2][0-9]:[0-5][0-9]:[0-5][0-9]' > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "Please specify the time you wish to restore in the format: HH:MM:SS"
		echo "exiting..."
		exit 1
	else
		echo "Requested restore time: $RTIME"
	fi
fi

#Check for temporary restore directory
if [ -n "$TMPDIR" ]; then
	echo $TMPDIR | grep '^/.*/$' > /dev/null
	if [ $? -ne 0 ]; then
		echo "Specified temporary directory MUST contain a trailing / (ex. /fs/scratch/mytmp/ )"
		exit 1
	fi
	if [ ! -d $TMPDIR ]; then
		echo "Requested temporary restore directory does not exist, creating it."
		mkdir $TMPDIR
	fi
	echo "Temporary restore directory: ($TMPDIR)"
fi

#Directory specified or prompt for default options?
if [ -n "$RESTOREDIR" ]; then
	echo $RESTOREDIR | grep '^/.*/$' > /dev/null
	if [ $? -ne 0 ]; then
		echo "Specified directory MUST contain a trailing / (ex. /usr/WebSphere70/ )"
		exit 1
	fi
else
	#No directory given, prompt for options
	#Set WAS version and default dirs
	WASDIR="/usr/WebSphere${VERSION}/"
	DIRLIST[1]="/projects/"
	DIRLIST[2]="$WASDIR"
	i=1
	echo "Which WebSphere TSM backup would you like to restore?"
	while [[ ${DIRLIST[$i]} != "" ]]; do
		echo "        [$i] ${DIRLIST[$i]}"
		i=$(($i+1))
	done
	printf "\nEnter number for the WebSphere TSM backup: "
	read choice
	RESTOREDIR=${DIRLIST[$choice]}
fi

echo "Restoring: $RESTOREDIR"
echo "=================================================="
echo
TSMrestore
echo
echo "=================================================="
echo "TSM restore complete!"
echo "Restoring WAS permissions"
#Reset WAS permissions
/lfs/system/tools/was/setup/was_perms.ksh
