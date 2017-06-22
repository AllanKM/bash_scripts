#!/usr/bin/env bash
if [ `hostname` != 'v20056'  ]; then echo "Hey you, dont run this here. Try v20056"; fi
rmscript=/tmp/rmver.sh
echo "rm /fs/system/config/was/version/*.csv" > $rmscript
echo "if [ -d /gpfs/scratch/b/version  ]; then rm /gpfs/scratch/b/version/*.csv; fi" >> $rmscript
echo "if [ -d /gpfs/scratch/y/version  ]; then rm /gpfs/scratch/y/version/*.csv; fi" >> $rmscript
echo "if [ -d /gpfs/scratch/g/version  ]; then rm /gpfs/scratch/g/version/*.csv; fi" >> $rmscript
chmod u+x $rmscript
for plex in PX1 PX2 PX3 PX5 CI1 CI2 CI3 ECC; do
	  /Tivoli/scripts/tiv.task -t 600 -l $plex -c role==gpfs.server.sync -u root ${rmscript} 2>&1>> /dev/null
done

versionscript=/lfs/system/tools/was/bin/productfind.sh
verlog=/fs/scratch/mgjoni/ver.log
tmp=/tmp/hi.sh
echo "!#/usr/bin/bash" > $tmp
echo "if [ -f $versionscript  ]; then" >> $tmp
echo "$versionscript" >> $tmp
echo "fi; exit" >> $tmp
chmod u+x $tmp
for plex in PX1 PX2 PX3 PX5 CI1 CI2 CI3 ECC; do
    /Tivoli/scripts/tiv.task -t 600 -l $plex -u root ${tmp} 2>&1>> ${verlog}
done

scratchscript=/tmp/scratchver.sh
echo "!#/usr/bin/bash" > $scratchscript
echo "if [ -d /gpfs/scratch/b/version  ]; then cp /gpfs/scratch/b/version/*.csv /fs/system/config/was/version; fi" >> $scratchscript
echo "if [ -d /gpfs/scratch/y/version  ]; then cp /gpfs/scratch/y/version/*.csv /fs/system/config/was/version; fi" >> $scratchscript
echo "if [ -d /gpfs/scratch/g/version  ]; then cp /gpfs/scratch/g/version/*.csv /fs/system/config/was/version; fi" >> $scratchscript
chmod u+x $scratchscript
for plex in PX1 PX2 PX3 PX5 CI1 CI2 CI3 ECC; do
      /Tivoli/scripts/tiv.task -t 600 -l $plex -c role==gpfs.server.sync -u root ${scratchscript} 2>&1>> /dev/null
done

syncscript=/tmp/syncscript.sh
echo "/fs/system/bin/eisync --notgpfs /fs/system/config/was --ecctoo" > $syncscript
chmod u+x $syncscript
for plex in PX2 ECC; do
        /Tivoli/scripts/tiv.task -t 600 -l $plex -c role==gpfs.server.sync -u root ${syncscript} 2>&1>> /dev/null
done
