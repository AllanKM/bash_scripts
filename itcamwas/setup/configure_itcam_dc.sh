#!/bin/ksh
# USAGE: configure_itcam_dc.sh {51|60|61} ms_host ms_port dmgr_host dmgr_port cell node [appserver_filter]

usage ()
{
print "Usage:  configure_itcam_dc.sh {51|60|61} ms_host ms_port dmgr_host dmgr_port cell node [appserver_filter]"
}

if [[ "$(whoami)" != "root" ]]
  then
    print "Error: This command must be run as root"
    exit 1
fi
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

#echo $1 "is the fullversion"
#echo $2 " is the MS"
#echo $3 " is the MS Port"
#echo $4 " is the DM host"
#echo $5 " is the DM port"
#echo $6 " is the WAS cell"
#echo $7 " is the AppServer Node"
#exit 1

DCOPTFILE=v61.itcamw-dc-was.opt
CANDLE_HOME=/opt/IBM/ITM
DC_ROOT=/opt/IBM/ITM/WASDC
TOOLSDIR=/fs/system/tools/sysmgmt/setup/

WAS_TOOLS=/lfs/system/tools/was
WAS_PASSWD=$WAS_TOOLS/etc/was_passwd

case $VERSION in
        61) REGISTRY=$(echo $WASCELL|awk '{split($0,c,"61"); print c[2]}'|cut -c1-2) ;;
        60) REGISTRY=$(echo $WASCELL|awk '{split($0,c,"60"); print c[2]}'|cut -c1-2) ;;
        51) REGISTRY=$(echo $WASCELL|awk '{split($0,c,"51"); print c[2]}'|cut -c1-2) ;;
        *) usage ;;
esac

if [ "$REGISTRY" != "ed" ]; then
  SECUSER=eiauth@events.ihost.com
else
  SECUSER=eibpauth@us.ibm.com
fi


## Grab Global Security user's password
if [[ -e $WAS_PASSWD ]]; then
  if [ "$REGISTRY" == "ed" ]; then
        encrypted_passwd=$(grep ed_ldap $WAS_PASSWD |awk '{split($0,pwd,"ed_ldap="); print pwd[2]}' |sed -e 's/\\//g')
        passwd_string=`$WAS_TOOLS/bin/PasswordDecoder.sh $encrypted_passwd`
        SECPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
  else
        encrypted_passwd=$(grep global_security $WAS_PASSWD |awk '{split($0,pwd,"global_security="); print pwd[2]}' |sed -e 's/\\//g')
        passwd_string=`$WAS_TOOLS/bin/PasswordDecoder.sh $encrypted_passwd`
        SECPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
  fi
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
        51)     PROFILE_HOME=${WAS_HOME}
                SUBPROFILEHOME=${SUBWASHOME}
                PROFILE=NULL
        ;;
        *)
                usage
        ;;
esac

## Preinstall
echo "========================================="
echo " Setting up filesystems, logs, etc"
echo "========================================="
if [[ ! -d ${DC_ROOT} ]]; then
    mkdir -p ${DC_ROOT}
fi
if [[ ! -d /logs/itcam ]]; then
    mkdir -p /logs/itcam
fi
chown -R root.itmusers ${DC_ROOT}
chown -R root.itmusers /logs/itcam
chmod -R ug+rwx,g+s,o-rwx ${DC_ROOT} /logs/itcam
if [[ -d /var/ibm/tivoli/common/CYN ]]; then
    print "CYN logging directory exists, moving before creating link"
    mv /var/ibm/tivoli/common/CYN /var/ibm/tivoli/common/CYN.old
fi
ln -sf /logs/itcam /var/ibm/tivoli/common/CYN
chuser groups='mqm,apps,mqbrkrs,itmusers' webinst

## Replace values in responsefile
echo "========================================="
echo " Preparing the ITCAM WAS DC responsefile"
echo "========================================="
cp ${TOOLSDIR}/response/${DCOPTFILE} /tmp
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
sed -e "s/DC_ASL_PORT=.*/DC_ASL_PORT=${DMPORT}/" ${DCOPTFILE}  > ${DCOPTFILE}.custom && mv ${DCOPTFILE}.custom  ${DCOPTFILE}
sed -e "s/DC_ASL_USERNAME=.*/DC_ASL_USERNAME=${SECUSER}/" ${DCOPTFILE}  > ${DCOPTFILE}.custom && mv ${DCOPTFILE}.custom  ${DCOPTFILE}
sed -e "s/DC_ASL_PASSWD=.*/DC_ASL_PASSWD=${SECPass}/" ${DCOPTFILE}  > ${DCOPTFILE}.custom && mv ${DCOPTFILE}.custom  ${DCOPTFILE}
sed -e "s/AM_SOCKET_BINDIP=.*/AM_SOCKET_BINDIP=${HOST}.event.ibm.com/" ${DCOPTFILE}  > ${DCOPTFILE}.custom && mv ${DCOPTFILE}.custom  ${DCOPTFILE}

## Build Appserver List and edit responsefile
if [ "$ASFILTER" == "NULL" ]; then
        appservers=`ls ${PROFILE_HOME}/config/cells/$WASCELL/nodes/$ASNODE/servers/| grep -v nodeagent`
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

## Kick-off DC config
echo "========================================="
echo " Configuring the ITCAM WAS DataCollector"
echo "========================================="
${DC_ROOT}/config_dc/config_dc.sh -silent -options /tmp/${DCOPTFILE}

## Disable verbose garbage collection
echo "========================================="
echo " Disabling JVM verbose garbage collection"
echo "========================================="
for as in $appservers; do
        echo "   Disable verbosegc: $node/$as"
        su - webinst -c "${WAS_HOME}/bin/wsadmin.sh -lang jython -f /lfs/system/tools/was/lib/disableVerboseGC.py ${HOST} $as"
done


#Reset permissions
echo "========================================="
echo " Setting permissions ..."
echo "========================================="
chown -R root.itmusers ${DC_ROOT} /logs/itcam
find ${DC_ROOT} -type d -exec chmod ug+rwx,o-rwx {} \;
find ${DC_ROOT} -type f -exec chmod ug+rw,o-rwx {} \;
find /logs/itcam -type d -exec chmod ug+rwx,o-rwx {} \;
find /logs/itcam -type f -exec chmod ug+rw,o-rwx {} \;
/lfs/system/tools/was/setup/was_perms.ksh

## Restart ITCAM Agent
echo "========================================="
echo " Restarting the TEM Agent (ITCAM)"
echo "========================================="
#/opt/IBM/ITM/bin/itmcmd agent stop yn
#/opt/IBM/ITM/bin/itmcmd agent start yn
$CANDLE_HOME/bin/itmcmd agent stop yn
$CANDLE_HOME/bin/itmcmd agent start yn

#sync the node with the DM
echo "========================================="
echo " Syncing the WAS configurations from DMGR"
echo "========================================="
su - webinst -c "${WAS_HOME}/bin/wsadmin.sh -f /lfs/system/tools/was/scripts/nodeAction.jacl -action sync -node ${HOST}"
##Prompt uses to restart all affected appservers
echo "ITCAM for WebSphere Data Collector configured, please check that the appservers configuration were updated."
echo "Then restart the all affected application servers to begin full WAS monitoring."

exit 0