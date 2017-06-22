#!/bin/bash
# USAGE: install_itcam_dc.sh {51|60|61} dmgr_host dmgr_soap_port dmgr_http_port db_host db_port
HOST=`/usr/bin/hostname -s`
FULLVERSION=$1
VERSION=`echo $FULLVERSION | cut -c1-2`
DMHOST=$2
WASCELL=${DMHOST%%?anager}
SOAPPORT=$3
HTTPPORT=$4
DBHOST=$5
DBPORT=$6

ITCAMMS=$HOST
ASNODE=$HOST
MSAPPSRV="${HOST}_itcam_ms"
DBUSER=itcamus
DBJDBCDIR="\/home\/webinst\/sqllib\/java"

ITCAM_CODE_PATH=/fs/system/images/itm61/itcam61/was
ITCAM_FIXDIR=${ITCAM_CODE_PATH}/fixes
MS_INSTALL_PATH=${ITCAM_CODE_PATH}/aix_unix/ManagingServer
MSOPTFILE=v61.itcamw-ms.opt
MS_ROOT=/opt/IBM/itcam/WebSphere/MS
TOOLSDIR=/lfs/system/tools/itcamwas
ITCAMWPASSWD=${TOOLSDIR}/etc/itcamw_passwd

WAS_TOOLS=/lfs/system/tools/was
WAS_PASSWD=$WAS_TOOLS/etc/was_passwd
SECUSER=eiauth@events.ihost.com

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

if [[ ! -d ${WAS_HOME} ]]; then
	echo "Directory ${WAS_HOME} not found! Please ensure that your WebSphere environment is already installed."
	exit 1
fi

## Grab Global Security user's password
if [[ -e $WAS_PASSWD ]]; then
	encrypted_passwd=$(grep global_security $WAS_PASSWD |awk '{split($0,pwd,"global_security="); print pwd[2]}' |sed -e 's/\\//g')
	passwd_string=`$WAS_TOOLS/bin/PasswordDecoder.sh $encrypted_passwd`
	SECPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
else
	echo "Error: WebSphere password setup file not found."
	exit 1
fi

## Grab ITCAMW DB user's password
if [[ -e $ITCAMWPASSWD ]]; then
	encrypted_passwd=$(grep itcamus $ITCAMWPASSWD |awk '{split($0,pwd,"itcamus="); print pwd[2]}' |sed -e 's/\\//g')
	passwd_string=`$WAS_TOOLS/bin/PasswordDecoder.sh $encrypted_passwd`
	DBPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
else
	echo "Error: ITCAMW DB password setup file not found."
	exit 1
fi

## Preinstall
echo "========================================="
echo " Setting up filesystems, logs, etc"
echo "========================================="
mkdir -p ${MS_ROOT} /logs/itcam
chown -R webinst.eiadm /opt/IBM/itcam/WebSphere
chown -R webinst.eiadm /logs/itcam
chmod -R ug+rwx,g+s,o-rwx /opt/IBM/itcam/WebSphere /logs/itcam
ln -sf /logs/itcam /var/ibm/tivoli/common/CYN
/lfs/system/tools/configtools/make_filesystem /opt 1792

## Start MS AppServer
echo "========================================="
echo " Starting MS AppServer (must be pre-configured)"
echo "========================================="
if [[ -d ${PROFILE_HOME}/config/cells/${WASCELL}/nodes/${ASNODE}/servers/${MSAPPSRV} ]]; then
	${WAS_TOOLS}/bin/rc.was start ${MSAPPSRV} -n
else
	echo "Error: Managing Server appserver ($MSAPPSRV) does not exist, please create."
	exit 1
fi

## Replace values in responsefile
echo "========================================="
echo " Preparing the ITCAM WAS MS responsefile"
echo "========================================="
cp ${TOOLSDIR}/responsefiles/${MSOPTFILE} /tmp 
cd /tmp
sed -e "s/KERNEL_HOST01=.*/KERNEL_HOST01=${ITCAMMS}.event.ibm.com/" ${MSOPTFILE}  > ${MSOPTFILE}.custom && mv ${MSOPTFILE}.custom  ${MSOPTFILE}
sed -e "s/WAS_SERVER=.*/WAS_SERVER=${MSAPPSRV}/" ${MSOPTFILE}  > ${MSOPTFILE}.custom && mv ${MSOPTFILE}.custom  ${MSOPTFILE}
sed -e "s/WAS_NODE=.*/WAS_NODE=${ASNODE}/" ${MSOPTFILE}  > ${MSOPTFILE}.custom && mv ${MSOPTFILE}.custom  ${MSOPTFILE}
sed -e "s/WAS_CELL=.*/WAS_CELL=${WASCELL}/" ${MSOPTFILE}  > ${MSOPTFILE}.custom && mv ${MSOPTFILE}.custom  ${MSOPTFILE}
sed -e "s/WAS_HOSTNAME=.*/WAS_HOSTNAME=${DMHOST}.event.ibm.com/" ${MSOPTFILE}  > ${MSOPTFILE}.custom && mv ${MSOPTFILE}.custom  ${MSOPTFILE}
sed -e "s/WAS_PROFILEHOME=.*/WAS_PROFILEHOME=${SUBPROFILEHOME}/" ${MSOPTFILE}  > ${MSOPTFILE}.custom && mv ${MSOPTFILE}.custom  ${MSOPTFILE}
sed -e "s/WAS_PROFILENAME=.*/WAS_PROFILENAME=${PROFILE}/" ${MSOPTFILE}  > ${MSOPTFILE}.custom && mv ${MSOPTFILE}.custom  ${MSOPTFILE}
sed -e "s/WAS_BASEDIR=.*/WAS_BASEDIR=${SUBWASHOME}/" ${MSOPTFILE}  > ${MSOPTFILE}.custom && mv ${MSOPTFILE}.custom  ${MSOPTFILE}
sed -e "s/WAS_SOAP_PORT=.*/WAS_SOAP_PORT=${SOAPPORT}/" ${MSOPTFILE}  > ${MSOPTFILE}.custom && mv ${MSOPTFILE}.custom  ${MSOPTFILE}
sed -e "s/WAS_ADMIN_CONSOLE_PORT=.*/WAS_ADMIN_CONSOLE_PORT=${HTTPPORT}/" ${MSOPTFILE}  > ${MSOPTFILE}.custom && mv ${MSOPTFILE}.custom  ${MSOPTFILE}
sed -e "s/WAS_USER=.*/WAS_USER=${SECUSER}/" ${MSOPTFILE}  > ${MSOPTFILE}.custom && mv ${MSOPTFILE}.custom  ${MSOPTFILE}
sed -e "s/WAS_USER_PWD=.*/WAS_USER_PWD=${SECPass}/" ${MSOPTFILE}  > ${MSOPTFILE}.custom && mv ${MSOPTFILE}.custom  ${MSOPTFILE}

sed -e "s/DB2_SCHEMA_USER=.*/DB2_SCHEMA_USER=${DBUSER}/" ${MSOPTFILE}  > ${MSOPTFILE}.custom && mv ${MSOPTFILE}.custom  ${MSOPTFILE}
sed -e "s/DB2_SCHEMA_PASSWORD=.*/DB2_SCHEMA_PASSWORD=${DBPass}/" ${MSOPTFILE}  > ${MSOPTFILE}.custom && mv ${MSOPTFILE}.custom  ${MSOPTFILE}
sed -e "s/DB2_INST_PORTNUMBER=.*/DB2_INST_PORTNUMBER=${DBPORT}/" ${MSOPTFILE}  > ${MSOPTFILE}.custom && mv ${MSOPTFILE}.custom  ${MSOPTFILE}
sed -e "s/DB2_SERVER=.*/DB2_SERVER=${DBHOST}/" ${MSOPTFILE}  > ${MSOPTFILE}.custom && mv ${MSOPTFILE}.custom  ${MSOPTFILE}
sed -e "s/DB2_JDBC=.*/DB2_JDBC=${DBJDBCDIR}/" ${MSOPTFILE}  > ${MSOPTFILE}.custom && mv ${MSOPTFILE}.custom  ${MSOPTFILE}

## Kick-off MS install
echo "========================================="
echo " Installing the ITCAM WAS ManaginServer"
echo "========================================="
${MS_INSTALL_PATH}/setup_MS.bin -silent -is:javaconsole -is:log /logs/itcam/MSlog.txt -options /tmp/${MSOPTFILE}

## Install MS Fixpack 1
echo "========================================="
echo " Installing ITCAM WAS ManagingServer FP2"
echo "========================================="
cd ${MS_ROOT}
mkdir updateinstaller
cd ${MS_ROOT}/updateinstaller
#unpack fixpack and installer
tar -xf ${ITCAM_FIXDIR}/fp2/ITCAM_V61_UpdateInstaller.tar
tar -xf ${ITCAM_FIXDIR}/fp2/6.1.0-TIV-ITCAMfWAS_SVR-FP0002.tar
#edit silentUpdate.properties
PROPFILE=silentUpdate.properties
sed -e "s/#updateVe.wasHome=.*/updateVe.wasHome=${SUBWASHOME}/" ${PROPFILE}  > ${PROPFILE}.custom && mv ${PROPFILE}.custom  ${PROPFILE}
sed -e "s/#updateVe.was.soap.host=.*/updateVe.was.soap.host=${DMHOST}.event.ibm.com/" ${PROPFILE}  > ${PROPFILE}.custom && mv ${PROPFILE}.custom  ${PROPFILE}
sed -e "s/#updateVe.was.soap.port=.*/updateVe.was.soap.port=${SOAPPORT}/" ${PROPFILE}  > ${PROPFILE}.custom && mv ${PROPFILE}.custom  ${PROPFILE}
sed -e "s/#updateVe.was.node.*/updateVe.was.node=${ASNODE}/" ${PROPFILE}  > ${PROPFILE}.custom && mv ${PROPFILE}.custom  ${PROPFILE}
sed -e "s/#updateVe.was.server=.*/updateVe.was.server=${MSAPPSRV}/" ${PROPFILE}  > ${PROPFILE}.custom && mv ${PROPFILE}.custom  ${PROPFILE}
sed -e "s/#updateVe.was.user.*/updateVe.was.user=${SECUSER}/" ${PROPFILE}  > ${PROPFILE}.custom && mv ${PROPFILE}.custom  ${PROPFILE}
sed -e "s/#updateVe.was.password.*/updateVe.was.password=${SECPass}/" ${PROPFILE}  > ${PROPFILE}.custom && mv ${PROPFILE}.custom  ${PROPFILE}
export JAVA_HOME=${WAS_JVM}
./silentUpdate.sh -prepareInstall
./silentUpdate.sh -install

#Drop updated keystores in place
echo "========================================="
echo " Replacing default ITCAM keystores"
echo "========================================="
cd ${MS_ROOT}/etc
mv CyaneaMgmtStore CyaneaMgmtStore.old
mv CyaneaMgmtStore_Comm CyaneaMgmtStore_Comm.old
mv mgmttomgmt.cer mgmttomgmt.cer.old
mv mgmttoproxy.cer mgmttoproxy.cer.old
mv mgmttodc.cer mgmttodc.cer.old
cp ${ITCAM_CODE_PATH}/keystore_update/CyaneaMgmt* ./
cp ${ITCAM_CODE_PATH}/keystore_update/mgmtto* ./

#Edit properties files: turn on data trimmer, etc
echo "========================================="
echo " Updating MS properties files"
echo "========================================="
cd ${MS_ROOT}/etc
sed -e "s/_ELAPSED_TIME=2950/_ELAPSED_TIME=720/" aa_datatrimmer.properties  > aa_datatrimmer.properties.custom && mv aa_datatrimmer.properties.custom  aa_datatrimmer.properties
sed -e "s/_PERIOD=72000000/_PERIOD=18000000/" aa_datatrimmer.properties  > aa_datatrimmer.properties.custom && mv aa_datatrimmer.properties.custom  aa_datatrimmer.properties
sed -e "s/ENABLE_DATATRIMMER=.*/ENABLE_DATATRIMMER=true/" aa.properties  > aa.properties.custom && mv aa.properties.custom  aa.properties
sed -e "s/_DELETE_TIME=2940/_DELETE_TIME=720/" aa.properties  > aa.properties.custom && mv aa.properties.custom  aa.properties
sed -e "s/ENABLE_DATATRIMMER=.*/ENABLE_DATATRIMMER=true/" aa1.properties  > aa1.properties.custom && mv aa1.properties.custom  aa1.properties
sed -e "s/_DELETE_TIME=2940/_DELETE_TIME=720/" aa1.properties  > aa1.properties.custom && mv aa1.properties.custom  aa1.properties
sed -e "s/ENABLE_DATATRIMMER=.*/ENABLE_DATATRIMMER=true/" aa2.properties  > aa2.properties.custom && mv aa2.properties.custom  aa2.properties
sed -e "s/_DELETE_TIME=2940/_DELETE_TIME=720/" aa.properties  > aa2.properties.custom && mv aa2.properties.custom  aa2.properties

#Reset permissions
echo "========================================="
echo " Setting permissions ..."
echo "========================================="
chown -R webinst.eiadm ${MS_ROOT}
find ${MS_ROOT} -type d -exec chmod ug+rwx,o-rwx {} \;
find ${MS_ROOT} -type f -exec chmod ug+rw,o-rwx {} \;
${WAS_TOOLS}/setup/was_perms.ksh

##Cleanup
rm /tmp/${MSOPTFILE}
cd ${MS_ROOT}/updateinstaller
sed -e "s/updateVe.was.password=.*/updateVe.was.password=\<password\>/" ${PROPFILE}  > ${PROPFILE}.custom && mv ${PROPFILE}.custom  ${PROPFILE}

##Prompt uses to restart all affected appservers
echo "ITCAM for WebSphere Agent and Data Collector installed, please check that the appservers were properly configured."
echo "Then restart the all affected application servers to begin full WAS monitoring."