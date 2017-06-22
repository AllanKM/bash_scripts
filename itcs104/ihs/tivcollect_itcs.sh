#!/bin/sh
# This script must run 1 hour or so after tivscan_itcs.sh to allow time for the scanning process
# to complete as some servers with large content directories take a long time to finish. 
# The scan process writes a file to /fs/scratch/itcs104, this process retireves the file and
# saves to the audit data directory

APPDIR="/lfs/system/tools/itcs104/ihs"
OUTFILE=/fs/system/audit/ihs/data/`date +'%Y%m%d'`.dat
TASKFILE=/tmp/ihs_itcs_collect_`date +'%Y%m%d`.txt
print "Retireving scan results to $TASKFILE and collating to $OUTFILE"
rm $OUTFILE
rm $TASKFILE
for PLEX in PX1 PX2 PX3 CI2 CI3 ECC ;  do
	/Tivoli/scripts/tiv.task -t 300 -l $PLEX -u root ${APPDIR}/ihs_collect.sh >>$TASKFILE
done
grep "ITCS," $TASKFILE >$OUTFILE
chmod 770 $OUTFILE
chown root:eiadm $OUTFILE
