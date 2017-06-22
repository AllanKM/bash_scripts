#!/usr/bin/bash
tmpscript=/tmp/cpitcs.sh
echo "cp -r /gpfs/scratch/g/wasitcs104/* /fs/system/audit/was/" > ${tmpscript}
chmod u+x ${tmpscript}
for plex in PX1 PX2 PX3 PX5 CI1 CI2 CI3; do
  /Tivoli/scripts/tiv.task -t 300 -l $plex -c role==gpfs.server.sync -u root ${tmpscript};
done

tmpscript=/tmp/cpitcs.sh
echo "cp -r /gpfs/scratch/b/wasitcs104/* /fs/system/audit/was/" > ${tmpscript}
for plex in ECC; do
  /Tivoli/scripts/tiv.task -t 300 -l $plex -c role==gpfs.server.sync -u root ${tmpscript};
done

syncscript=/tmp/syncitcs.sh
mydate=`date +"%Y%m"`
echo "chmod -R a+rx /fs/system/audit/was/${mydate}" >> ${syncscript}
for plex in PX1 PX2 PX3 PX5 CI1 CI2 CI3 ECC; do
  /Tivoli/scripts/tiv.task -t 300 -l $plex -c role==gpfs.server.sync -u root ${syncscript};
done

mydate=`date +%Y%m`
syncscript=/tmp/syncitcs.sh
echo "cd /fs/system/audit/was/" > ${syncscript}
echo "/fs/system/bin/eisync --notgpfs /fs/system/audit/was/${mydate} --ecctoo" >> ${syncscript}
for plex in ECC; do
  /Tivoli/scripts/tiv.task -t 300 -l $plex -c role==gpfs.server.sync -u root ${syncscript};
done
