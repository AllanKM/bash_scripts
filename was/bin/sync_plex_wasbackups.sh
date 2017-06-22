#!/bin/bash
#   Usage: sync_plex_wasbackups.sh [--no-prompt] [--no-dry-run]
#		Intended to be run as a cron job

# The function performing the real sync work
function sync_cell {
	thisCell=$1
	destNode=$2
	if [[ -n $DRYRUN ]]; then
		echo "DRYRUN Sync!"
		rsync --stats --progress --rsync-path="if [[ ! -d $ARCHIVEDIR/$thisCell ]]; then mkdir $ARCHIVEDIR/$thisCell ; fi && rsync" -ntcave ssh $ARCHIVEDIR/$thisCell/${thisCell}Manager* $destNode:$ARCHIVEDIR/$thisCell/
		echo
		printf "Continue with non-dryrun sync? (y/n) "
		read reply
		case $reply in
			[nN]|"no")
				echo "Aborting synchronization..."
				exit 0 ;;
		esac
		rsync --stats --progress --rsync-path="if [[ ! -d $ARCHIVEDIR/$thisCell ]]; then mkdir $ARCHIVEDIR/$thisCell ; fi && rsync" -tcave ssh $ARCHIVEDIR/$thisCell/${thisCell}Manager* $destNode:$ARCHIVEDIR/$thisCell/
	else
		rsync --stats --progress --rsync-path="if [[ ! -d $ARCHIVEDIR/$thisCell ]]; then mkdir $ARCHIVEDIR/$thisCell ; fi && rsync" -tcave ssh $ARCHIVEDIR/$thisCell/${thisCell}Manager* $destNode:$ARCHIVEDIR/$thisCell/
	fi
	echo
}

#ARCHIVEDIR=/fs/site/was
ARCHIVEDIR=/fs/backups/was
PROMPT="yes"
DRYRUN="yes"
# Check for any passed arguments
for arg in $* ; do
	case $arg in
		"--no-prompt") PROMPT=""
			;;
		"--no-dry-run") DRYRUN=""
			;;
		*)
	esac
done

# Determine which plex we're in and thus which node this script should be on.
REALM=`lssys -l realm $HOSTNAME | grep realm | awk {'print $3'}`
case $REALM in
	g.ei.p1) SRCHOST=v10200
			 DESTHOST1=v20200
			 DESTHOST2=v30200
		;;
	g.ei.p2) SRCHOST=v20200
			 DESTHOST1=v30200
			 DESTHOST2=v10200
		;;
	g.ei.p3) SRCHOST=v30200
			 DESTHOST1=v10200
			 DESTHOST2=v20200
		;;
	*) echo "ERROR: This script must be run from a GZ CWS node."
esac

# Clean up any potentially old backups that might have been sync'ed here
#  - was_backup_config.sh only cleans up locally for the cell it is backing up
echo "Removing WAS config archives older than 14 days."
find ${ARCHIVEDIR}/ -type f -name "*.zip" -mtime +14 -exec rm -f {} \;
find ${ARCHIVEDIR}/ -type f -name "*.tar" -mtime +14 -exec rm -f {} \;

# Compile a list of WAS cells with DM backups in this plex.
#  - Search for DM zip files in the past week, then pull out the cell name.
ZIPS=`find ${ARCHIVEDIR} -type f -name 'gz*Manager*.zip' -mtime -8`
WASCELLS=`for zip in $ZIPS; do echo $zip|awk '{split($0,z,"/"); print z[5]}'; done`
echo "Found the following WAS Cells with DM backups in the local plex:"
echo $WASCELLS

# Check to see that the cells' DM nodes are actually in the local plex
#  - Do this because after one round of syncs, the DM backups will be everywhere.
echo
echo "Checking which cell DM nodes are in the local plex."
DMLIST=""
for possible in $WASCELLS; do
	node=`lssys -qe role==was.dm.${possible} role!=was.dm.backup`
	if [ `echo $node|wc -w` -eq 1 ]; then
		srcPlex=`lssys -l realm -n |grep realm|awk '{split($0,p,"."); print p[3]}'`
		dmPlex=`lssys -l realm $node |grep realm|awk '{split($0,p,"."); print p[3]}'`
		if [[ $srcPlex == $dmPlex ]]; then
			# Primary DM for the cell is in this plex, add to list
			if [[ $DMLIST == "" ]]; then
				DMLIST=$possible
			else
				DMLIST="$DMLIST $possible"
			fi
		fi
	else
		# More than one node matches for the cell name, no indication of primary
		#  - Sync if one node is in this plex.
		for nd in $node; do
			srcPlex=`lssys -l realm -n |grep realm|awk '{split($0,p,"."); print p[3]}'`
			dmPlex=`lssys -l realm $nd |grep realm|awk '{split($0,p,"."); print p[3]}'`
			if [[ $srcPlex == $dmPlex ]]; then
				# One of the DM nodes for the cell is in this plex, add to list
				if [[ $DMLIST == "" ]]; then
					DMLIST=$possible
				else
					DMLIST="$DMLIST $possible"
				fi
			fi
		done
	fi
done
WASCELLS=$DMLIST
echo "List of Cell DM nodes to synchronize backups for:"
echo $WASCELLS
echo

# Verify with user if prompt was not overriden
if [[ -n $PROMPT ]]; then
	printf "Are you really sure you want to synchronize these cell backups? (y/n) "
	read reply
	case $reply in
		[nN]|"no")
			echo "Aborting synchronization..."
			exit 0 ;;
	esac
fi

if [[ $USER == "root" ]]; then
	echo "EXECUTE: Sync WAS DM backups from $SRCHOST..."
	for cell in $WASCELLS; do
		echo "SYNC: $cell backups to $DESTHOST1"
		echo "---------------------------------"
		sync_cell $cell $DESTHOST1
		echo "SYNC: $cell backups to $DESTHOST2"
		echo "---------------------------------"
		sync_cell $cell $DESTHOST2
	done
else
	echo "ERROR: This script needs to be run as root (not sudo) or via a root cron job."
fi
