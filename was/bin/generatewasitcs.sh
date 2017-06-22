#!/usr/bin/bash
today=`date +%y%m%d`
log=/tmp/itcslog${today}.log
for plex in PX1 PX2 PX3 PX5 CI2 CI3 ECC; do 
  /Tivoli/scripts/tiv.task -t 600 -l $plex -u root /lfs/system/tools/was/bin/itcs104_was_check.sh 2>&1>> ${log}
done

chmod a+r ${log}
