#!/bin/sh
# This script initiates the scanning process on all webservers.
# the scan is started using NOHUP so continues to run after the completion of this script
# A subsequent script is executed to pull the results of the scan back to this server

APPDIR="/lfs/system/tools/itcs104/ihs"
for PLEX in PX1 PX2 PX3 ECC CI2 CI3; do
	/Tivoli/scripts/tiv.task -t 300 -l $PLEX -u root ${APPDIR}/ihs_scan.sh 
done

