#!/usr/bin/bash
if [ `hostname` != "v20056"  ]; then 
	echo "Only on v20056"
	exit 1
fi
dmgrlist=/fs/home/mgjoni/dmgrs.txt
wlplist=/fs/home/mgjoni/wlp.txt
syncserver=/tmp/syncserver.txt
lssys -qe role==was.dm.* |grep -v z > $dmgrlist
lssys -qe role==was.wwsm.bigdata | grep -v z >> $dmgrlist
lssys -qe role==was.*sa* | grep -v z >> $dmgrlist
lssys -qe role==wlp.* | grep -v z > $wlplist
log=/tmp/PORTSlog${today}.log
portrun=/fs/home/mgjoni/genport.sh
echo '/lfs/system/tools/was/bin/portreport.sh > /fs/system/config/was/`ls /usr/WebSphere*/AppServer/profiles/*/config/cells/ |grep -v xml`Manager-portsapps.csv 2>/tmp/portreportcron.log' > $portrun
echo '/fs/system/bin/eisync --notgpfs /fs/system/config/was --ecctoo > /tmp/portreportsync.log' > /tmp/sync.sh
chmod u+x /tmp/sync.sh
dmgrtojson=/fs/home/mgjoni/mkdmgr.sh
lssys -qe role==gpfs.server.sync |grep z > $syncserver

# Generate portsapps.csv on each dmgr
for plex in PX1 PX2 PX3 PX5; do 
	  /Tivoli/scripts/tiv.task -t 600 -l $plex -f $dmgrlist -u webinst ${portrun}  2>&1>> ${log}
done

wlpportrun=/fs/home/mgjoni/genwlpport.sh
echo '/lfs/system/tools/was/bin/portreport.sh > /fs/system/config/was/WLP_`hostname`.csv' > $wlpportrun
# Process WLP nodes
for plex in PX1 PX2 PX3 PX5; do 
	  /Tivoli/scripts/tiv.task -t 600 -l $plex -f $wlplist -u root ${wlpportrun}  2>&1>> ${log}
done

# Sync csvs, then create json file, then sync again
for plex in ECC; do 
    /Tivoli/scripts/tiv.task -t 600 -f $syncserver -l $plex -u root /tmp/sync.sh 2>&1>> ${log}
#    /Tivoli/scripts/tiv.task -t 600 -f $syncserver -l $plex -u root $dmgrtojson 2>&1>> ${log}
#    /Tivoli/scripts/tiv.task -t 600 -f $syncserver -l $plex -u root /tmp/sync.sh 2>&1>> ${log}
done
