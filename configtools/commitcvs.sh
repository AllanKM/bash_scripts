#!/bin/ksh
#	$Log: commitcvs.sh,v $
#	Revision 1.8  2009/10/21 07:27:55  steve_farrell
#	Updated to handle move of master directories to p3
#	
#	Revision 1.7  2009/08/19 18:28:41  todds
#	Changed the realm to be used to g.ei.p1
#	
#	Revision 1.6  2008/08/14 09:47:29  steve_farrell
#	Fixed rsync target directory
#	
#	Revision 1.5  2008/08/14 09:31:45  steve_farrell
#	Changed rsync destination to $PROD
#	
#	Revision 1.4  2008/08/14 09:12:13  steve_farrell
#	Fixed rsync target directory error
#	
#	Revision 1.3  2008/07/30 10:52:15  steve_farrell
#	Reworded messgage
#	Added comment about lfs_tools check
#	
#	Revision 1.2  2008/07/30 10:37:01  steve_farrell
#	Removed references to configtool
#	added further checks for y.ei.p1 & y.cs.p1 and existance of lfs_tools
#	added release function for freeing lock without CVS update
#	Fixed bug in configtool_ds outstanding upload detection
#	
#	Revision 1.1  2008/07/18 12:55:11  steve_farrell
#	Initial load of configtool commitcvs/lockcvs/checkcvs scripts
#	
#	Revision 1.1  2008/07/18 12:22:59  steve_farrell
#	Added new configtool_ds checking to commitcvs/lockcvs and new command checkcvs
#	
#	Revision 1.3  2008/06/11 12:42:53  steve_farrell
#	fixed logging
#
# usage:   commitcvs <cvs_source> [force]

if [ $# -eq 0 ]; then
  echo ""
  echo " usage:   commitcvs <cvs_source> [force | release]"
  echo ""
  echo "force will cause the CVS commit to occur even if you dont own the lock"
  echo "release will relinquish your lock without uploading to CVS"
  exit
fi

umask 002

SOURCE=$1
DEST=$2
me=`whoami`
BASEDIR="/fs/system/src/cvsroot/locks/${SOURCE}"
LOCKFILE="${BASEDIR}/${SOURCE}.lck"
HISTFILE="${BASEDIR}/${SOURCE}.hst"
PROD=/fs/system/config/configtool
CFGTOOL_DS=/lfs/system/bin/configtool_ds
PROD_DS=/fs/system/config/configtool_ds

# Check we are running from the correct zone

REALM=`lssys -l realm $HOSTNAME | grep realm | awk {'print $3'}`
if [[ $REALM != g.ei.p3 ]] ; then
	echo "commitcvs can only be run from a server in realm g.ei.p3"
	exit
fi

if [[ "$DEST" = "release" ]]; then
	if [ -f $LOCKFILE ]; then
		echo "$LOCKFILE exists..."
		cat $LOCKFILE
		lck_user=`cat $LOCKFILE | head -1 | awk '{print $3}'`
		if [ "$lck_user" = "$me" ]; then
			echo "releasing lock on $SOURCE"
			rm $LOCKFILE
		else
			echo "Lock owned by $lck_user you cannot release it"
			exit
		fi
	else
		echo "$SOURCE not locked"
		exit
	fi
fi
if [[ "$DEST" = "force" ]] ; then
	echo "Use the Force"
	force=1
else
	force=0
fi

# Test if we have the lock file or have specified force on the commandline

if [ -f $LOCKFILE ]; then
	echo "$LOCKFILE exists..."
	cat $LOCKFILE
	lck_user=`cat $LOCKFILE | head -1 | awk '{print $3}'`
	if [ "$lck_user" != "$me" ]; then
		if [ $force = 1 ]; then
			echo "Force in effect.  Last edited by $lck_user, commit to CVS, then remove $LOCKFILE"
		else
			echo "WARNING $SOURCE locked by $lck_user and force not specified....ABORTING!!"
			exit 1
		fi
	else
		echo "Last edited by $me, comitting, then removing $LOCKFILE"
	fi
else
	if [ $force = 1 ]; then
		echo "Force in effect.  continuing even though lock not held"
	else
		echo "You do not hold the lock on $SOURCE .... ABORTING!!"
		exit 1
	fi
fi

if [[ "$SOURCE" = "configtool_ds" ]] ; then
	if [ -f $CFGTOOL_DS ] ; then							# Check lfs_tools version is installed

		# Check dirstore is up-to-date before allowing cvs commit
		if [ `$CFGTOOL_DS -t upload | egrep "NEW ROLE|NEW RESOURCE|CHANGE within" | wc -l` -ne 0 ]; then
			echo "Updating DIRSTORE"
			echo "press Enter to continue or CTRL-C to abort"
			read
			$CFGTOOL_DS -d upload
		fi
		
		# Final check upload has completed. 
		if [ `$CFGTOOL_DS -t upload | egrep "NEW ROLE|NEW RESOURCE|CHANGE within" | wc -l` -eq 0 ]; then
			echo "Commiting $SOURCE CVS source"
			cd ~/src
			cvs commit $SOURCE
			echo rsync -rcv ~/src/${SOURCE}/ $PROD_DS/
			rsync -rcv ~/src/${SOURCE}/ $PROD_DS/
			
			# keep the lock history
			cat $LOCKFILE >$HISTFILE
			rm $LOCKFILE
			exit
		else
			echo "****************************************************************************"
			echo "Problems with DIRSTORE update must be resolved before commitcvs can complete"
			echo "Run $CFGTOOL_DS -t upload  to see what the problems were"
			echo "****************************************************************************"
			exit
		fi
	else
		echo "this command can only be run from server where lfs_tools are deployed"
		exit 0
	fi
else

	# Do the CVS commit for all other sources
	# lock ownership and realm tests passed, commit to CVS

	echo "Commiting $SOURCE CVS source"
	cd ~/src
	cvs commit $SOURCE
	rm $LOCKFILE
	echo "Copying files to production area $PROD"
	rsync -rcv ~/src/${SOURCE}/ $PROD/
fi
