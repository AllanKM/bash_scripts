#!/bin/bash
# USAGE: install_itcam_dc.sh {51|60|61} ms_host ms_port dmgr_host dmgr_port cell node [appserver_filter]
HOST=`/usr/bin/hostname -s`
FULLVERSION=$1
VERSION=`echo $FULLVERSION | cut -c1-2`
ITCAMMS=$2
MSPORT=$3
DMHOST=$4
DMPORT=$5
WASCELL=$6
ASNODE=$7
ASFILTER=${8:-NULL}

ITCAM_CODE_PATH=/fs/system/images/itm61/itcam61/was
ITCAM_FIXDIR=${ITCAM_CODE_PATH}/fixes
DC_INSTALL_PATH=${ITCAM_CODE_PATH}/aix_unix/DataCollector
DCOPTFILE=v61.itcamw-dc-was.opt
DC_ROOT=/opt/IBM/itcam/WebSphere/DC
TEMA_INSTALL_PATH=${ITCAM_CODE_PATH}/aix_unix/TEMAgent
TEMA_OPTION_FILE=v61.itcamw-tema.opt
TOOLSDIR=/lfs/system/tools/itcamwas

WAS_TOOLS=/lfs/system/tools/was
WAS_PASSWD=$WAS_TOOLS/etc/was_passwd
SECUSER=eiauth@events.ihost.com

## Grab Global Security user's password
if [[ -e $WAS_PASSWD ]]; then
	encrypted_passwd=$(grep global_security $WAS_PASSWD |awk '{split($0,pwd,"global_security="); print pwd[2]}' |sed -e 's/\\//g')
	passwd_string=`$WAS_TOOLS/bin/PasswordDecoder.sh $encrypted_passwd`
	SECPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
else
	echo "Error: WebSphere password setup file not found."
	exit 1
fi

## Setup WAS variables
WAS_HOME="/usr/WebSphere${VERSION}/AppServer"
SUBWASHOME="\/usr\/WebSphere${VERSION}\/AppServer"
WAS_JVM=${WAS_HOME}/java
case $VERSION in
	60|61) PROFILE_HOME="${WAS_HOME}/profiles/${ASNODE}"
			SUBPROFILEHOME="${SUBWASHOME}\/profiles\/${ASNODE}"
			PROFILE=$ASNODE
	;;
	51)	PROFILE_HOME=${WAS_HOME}
		SUBPROFILEHOME=${SUBWASHOME}
		PROFILE=NULL
	;;
esac

## Preinstall
echo "========================================="
echo " Setting up filesystems, logs, etc"
echo "========================================="
mkdir -p ${DC_ROOT} /logs/itcam
chown -R webinst.eiadm /opt/IBM/itcam/WebSphere
chown -R webinst.eiadm /logs/itcam
chmod -R ug+rwx,g+s,o-rwx /opt/IBM/itcam/WebSphere /logs/itcam
ln -sf /logs/itcam /var/ibm/tivoli/common/CYN
/lfs/system/tools/configtools/make_filesystem /opt 1792

## Change heap size for appserver to be configured, should be at least 128MB more than app requires
## InfoCenter says heap max > 512 improves DC performance -- so far as long as max >= 256 it works fine, 128 is skimping
#if [ heapMax == 256 ]; then
#	heapMax=384
#elif [ heapMax < 512 ]; then
#	heapMax=512
#elif [ heapMax == 512 ]; then
#	heapMax=640
#fi

## Install TEMA - must stop existing ITM OS agent
echo "========================================="
echo " Installing the TEM Agent for ITCAM WAS"
echo "========================================="
/opt/IBM/ITM/bin/itmcmd agent stop ux
${TEMA_INSTALL_PATH}/install.sh -q -h /opt/IBM/ITM -p ${TOOLSDIR}/responsefiles/${TEMA_OPTION_FILE}

## Configure TEMA
ncplex=`grep realm /usr/local/etc/nodecache|awk '{split($3,realm,".");print realm[3]}'`
case $ncplex in
  p1) PLEX=P1
     ;;
  p2) PLEX=P2
     ;;
  p3) PLEX=P3
     ;;
  *) echo "Error: Unrecognized realm found when determining node's plex."
     exit 1
esac
echo "========================================="
echo " Configuring the TEM Agent for ITCAM WAS"
echo "========================================="
ITM_RESPONSEFILE=/fs/system/images/tivoli/itm6/install_itm/YNAgent/${PLEX}.YNAgent.config.txt
/opt/IBM/ITM/bin/itmcmd config -A -p ${ITM_RESPONSEFILE} yn

## Install TEMA Fixpack 2
echo "========================================="
echo " Installing TEMA Fixpack 2 for ITCAM WAS"
echo "========================================="
TEMA_FIXPACK_DIR=${ITCAM_FIXDIR}/tema_unix_fp2
${TEMA_FIXPACK_DIR}/install.sh -q -h /opt/IBM/ITM -p ${TOOLSDIR}/responsefiles/${TEMA_OPTION_FILE}

## Start Agents
echo "========================================="
echo " Starting the TEM Agents (OS & ITCAM)"
echo "========================================="
/opt/IBM/ITM/bin/itmcmd agent start ux
/opt/IBM/ITM/bin/itmcmd agent start yn

## Replace values in responsefile
echo "========================================="
echo " Preparing the ITCAM WAS DC responsefile"
echo "========================================="
cp ${TOOLSDIR}/responsefiles/${DCOPTFILE} /tmp 
cd /tmp
sed -e "s/DC_MSKS_SERVERNAME=.*/DC_MSKS_SERVERNAME==${ITCAMMS}.event.ibm.com/" ${DCOPTFILE}  > ${DCOPTFILE}.custom && mv ${DCOPTFILE}.custom  ${DCOPTFILE}
sed -e "s/DC_MSKS_CODEBASEPORT=.*/DC_MSKS_CODEBASEPORT=${MSPORT}/" ${DCOPTFILE}  > ${DCOPTFILE}.custom && mv ${DCOPTFILE}.custom  ${DCOPTFILE}
sed -e "s/WS_NODE_NAME=.*/WS_NODE_NAME=cells\/${WASCELL}\/nodes\/${ASNODE}/" ${DCOPTFILE}  > ${DCOPTFILE}.custom && mv ${DCOPTFILE}.custom  ${DCOPTFILE}
sed -e "s/DC_WD_PROFILEHOME=.*/DC_WD_PROFILEHOME=${SUBPROFILEHOME}/" ${DCOPTFILE}  > ${DCOPTFILE}.custom && mv ${DCOPTFILE}.custom  ${DCOPTFILE}
sed -e "s/DC_WD_PROFILENAME=.*/DC_WD_PROFILENAME=${PROFILE}/" ${DCOPTFILE}  > ${DCOPTFILE}.custom && mv ${DCOPTFILE}.custom  ${DCOPTFILE}
sed -e "s/DC_WD_WASBASEDIR=.*/DC_WD_WASBASEDIR=${SUBWASHOME}/" ${DCOPTFILE}  > ${DCOPTFILE}.custom && mv ${DCOPTFILE}.custom  ${DCOPTFILE}
sed -e "s/WAS_BASEDIR=.*/WAS_BASEDIR=${SUBWASHOME}/" ${DCOPTFILE}  > ${DCOPTFILE}.custom && mv ${DCOPTFILE}.custom  ${DCOPTFILE}
sed -e "s/DC_WD_WASVER=.*/DC_WD_WASVER=${VERSION}/" ${DCOPTFILE}  > ${DCOPTFILE}.custom && mv ${DCOPTFILE}.custom  ${DCOPTFILE}
sed -e "s/DC_ASL_HOSTNAME=.*/DC_ASL_HOSTNAME=${DMHOST}.event.ibm.com/" ${DCOPTFILE}  > ${DCOPTFILE}.custom && mv ${DCOPTFILE}.custom  ${DCOPTFILE}
sed -e "s/DC_ASL_SOAPPORT=.*/DC_ASL_SOAPPORT=${DMPORT}/" ${DCOPTFILE}  > ${DCOPTFILE}.custom && mv ${DCOPTFILE}.custom  ${DCOPTFILE}
sed -e "s/DC_ASL_USERNAME=.*/DC_ASL_USERNAME=${SECUSER}/" ${DCOPTFILE}  > ${DCOPTFILE}.custom && mv ${DCOPTFILE}.custom  ${DCOPTFILE}
sed -e "s/DC_ASL_PASSWD=.*/DC_ASL_PASSWD=${SECPass}/" ${DCOPTFILE}  > ${DCOPTFILE}.custom && mv ${DCOPTFILE}.custom  ${DCOPTFILE}
sed -e "s/AM_SOCKET_BINDIP=.*/AM_SOCKET_BINDIP=${HOST}.event.ibm.com/" ${DCOPTFILE}  > ${DCOPTFILE}.custom && mv ${DCOPTFILE}.custom  ${DCOPTFILE}

## Build Appserver List and edit responsefile
if [ "$ASFILTER" == "NULL" ]; then
	appservers=`ls ${PROFILE_HOME}/config/cells/$WASCELL/nodes/$ASNODE/servers/`
else
	appservers=`ls ${PROFILE_HOME}/config/cells/$WASCELL/nodes/$ASNODE/servers/ |grep $ASFILTER`
fi
for as in $appservers; do
	if [[ -z $ASLIST ]]; then
		ASLIST="cells\/$WASCELL\/nodes\/$ASNODE\/servers\/$as"
	else
		ASLIST="$ASLIST , cells\/$WASCELL\/nodes\/$ASNODE\/servers\/$as"
	fi
done
sed -e "s/APP_SERVER_NAMES=.*/APP_SERVER_NAMES=\"${ASLIST}\"/" ${DCOPTFILE}  > ${DCOPTFILE}.custom && mv ${DCOPTFILE}.custom  ${DCOPTFILE}
echo "Done."

## Kick-off DC install
echo "========================================="
echo " Installing the ITCAM WAS DataCollector"
echo "========================================="
${DC_INSTALL_PATH}/setup_DC_aix.bin -silent -is:javaconsole -is:log /logs/itcam/DClog.txt -options /tmp/${DCOPTFILE}

## Install DC Fixpack 2
echo "========================================="
echo " Installing ITCAM WAS DataCollector FP2"
echo "========================================="
cd ${DC_ROOT}
mkdir updateinstaller
cd ${DC_ROOT}/updateinstaller
#unpack fixpack and installer
tar -xf ${ITCAM_FIXDIR}/fp2/ITCAM_V61_UpdateInstaller.tar
tar -xf ${ITCAM_FIXDIR}/fp2/6.1.0-TIV-ITCAMfWAS_MP-FP0002.tar
#edit silentUpdate.properties -- not needed, defaults work.
export JAVA_HOME=${WAS_JVM}
./silentUpdate.sh -prepareInstall
./silentUpdate.sh -install

#Drop updated keystores in place
echo "========================================="
echo " Replacing default ITCAM keystores"
echo "========================================="
cd ${DC_ROOT}/itcamdc/etc
mv CyaneaDCStore CyaneaDCStore.old
mv CyaneaDCStore_Comm CyaneaDCStore_Comm.old
mv CyaneaProxyStore CyaneaProxyStore.old
mv CyaneaProxyStore_Comm CyaneaProxyStore_Comm.old
mv dctomgmt.cer dctomgmt.cer.old
mv dctoproxy.cer dctoproxy.cer.old
mv proxytodc.cer proxytodc.cer.old
mv proxytomgmt.cer proxytomgmt.cer.old
cp ${ITCAM_CODE_PATH}/keystore_update/CyaneaDC* ./
cp ${ITCAM_CODE_PATH}/keystore_update/CyaneaProxy* ./
cp ${ITCAM_CODE_PATH}/keystore_update/dcto* ./
cp ${ITCAM_CODE_PATH}/keystore_update/proxyto* ./

#Reset permissions
echo "========================================="
echo " Setting permissions ..."
echo "========================================="
chown -R webinst.eiadm ${DC_ROOT} /logs/itcam
find ${DC_ROOT} -type d -exec chmod ug+rwx,o-rwx {} \;
find ${DC_ROOT} -type f -exec chmod ug+rw,o-rwx {} \;
find /logs/itcam -type d -exec chmod ug+rwx,o-rwx {} \;
find /logs/itcam -type f -exec chmod ug+rw,o-rwx {} \;

## Restart ITCAM Agent
echo "========================================="
echo " Restarting the TEM Agent (ITCAM)"
echo "========================================="
/opt/IBM/ITM/bin/itmcmd agent stop yn
/opt/IBM/ITM/bin/itmcmd agent start yn

#sync the node with the DM
echo "========================================="
echo " Syncing the WAS configurations from DMGR"
echo "========================================="
su - webinst -c "${WAS_HOME}/bin/wsadmin.sh -f /lfs/system/tools/was/scripts/nodeAction.jacl -action sync -node ${HOST}"
##Prompt uses to restart all affected appservers
echo "ITCAM for WebSphere Agent and Data Collector installed, please check that the appservers were properly configured."
echo "Then restart the all affected application servers to begin full WAS monitoring."