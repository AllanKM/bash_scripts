#!/bin/bash
# Usage: install_wve.sh was=<61|70> [profile=<name>]
HOST=`/bin/hostname -s`
TOOLSDIR="/lfs/system/tools/wve"
WASTOOLS="/lfs/system/tools/was"
INSTDIR="/fs/system/images/websphere/ve/7.0"
RESPFILE="wve611_silent.script"
PRODFILE="WXDOP.product"
WVEVER="7.0.0"

#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
		was=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VERSION=$VALUE; fi ;;
		profile=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROFILE=$VALUE; fi ;;
		*)	echo "#### Unknown argument: $1"
            echo "#### Usage: install_wve.sh was=<61|70> [profiles=<name1>[,<name2>,<nameN>]]"
			exit 1
			;;
	esac
	shift
done
WASVERSION=`echo $VERSION | cut -c1-2`
ASROOT="/usr/WebSphere${WASVERSION}/AppServer"
if [ -z $PROFILE ]; then
	#Search for profiles
	i=0
	for profile in `ls ${ASROOT}/profiles/`; do
		profList[$i]="${profile}"
		i=$(($i+1))
	done
	#If more than one profile exists, prompt user to specify via command-line
	if [ $i -gt 1 ]; then
		echo "#### Please specify which profile to augment via command-line"
		echo "#### Usage: install_wve.sh was=<61|70> [profiles=<name>]"
		exit 1
	fi
	PROFILE=${profList}
fi

case $PROFILE in
	*Manager) VESUBDIR="Controller" ;;
	*) VESUBDIR="Node" ;;
esac

#Check for running processes, stop all if running
runCount=`ps -ef |grep $ASROOT|grep -v grep|wc -l`
if [ $runCount -gt 0 ]; then
	echo "Running WebSphere processes found ($runCount), stopping all before continuing."
	/lfs/system/tools/was/bin/rc.was stop all
fi

#Modify the responsefile
cp ${TOOLSDIR}/responsefiles/${RESPFILE} /tmp/
cd /tmp
sed -e "s%installLocation=.*%installLocation=\"${ASROOT}\"%" ${RESPFILE}  > ${RESPFILE}.custom && mv ${RESPFILE}.custom $RESPFILE
sed -e "s/profileAugmentList=.*/profileAugmentList=\"${PROFILE}\"/" ${RESPFILE}  > ${RESPFILE}.custom && mv ${RESPFILE}.custom $RESPFILE
sed -e "s/installCimgrRepository=.*/installCimgrRepository=\"true\"/" ${RESPFILE}  > ${RESPFILE}.custom && mv ${RESPFILE}.custom $RESPFILE

echo "-----------------------------------------------------------------"
echo " Installing WebSphere Virtual Enterprise $WVEVER"
echo "   Instance: $ASROOT"
echo "   Profile: $PROFILE"
echo "-----------------------------------------------------------------"
cd ${INSTDIR}/${VESUBDIR}
./install -silent -options /tmp/${RESPFILE}

echo "Checking $PRODFILE file for $WVEVER"
grep "version\>${WVEVER}" ${ASROOT}/properties/version/${PRODFILE}
if [ $? -ne 0 ]; then 
    echo "Failed to install WebSphere Virtual Enterprise $WVEVER.  Exiting..."
    exit 1
fi

echo "Checking log.txt for INSTCONFSUCCESS"
LASTLINES=`tail -3 ${ASROOT}/logs/xd_operations/install/log.txt`
if [ "$LASTLINES" != "" ]; then
    echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
    if [ $? -eq 0 ]; then
    	echo "WebSphere Virtual Enterprise $WVEVER installed SUCCESSFULLY."
    else
        echo "#### WebSphere Virtual Enterprise $WVEVER install FAILED."
        echo "Last few lines of install log contained:"
        echo "$LASTLINES"
        echo
        echo "Exiting..."
        exit 1
    fi
else
    echo "Failed to locate log file:"
    echo "     ${ASROOT}/logs/xd_operations/install/log.txt"
    echo "Installation must have failed."
    echo "Exiting..."
    exit 1
fi

#Install Fix Packs
cd ${INSTDIR}/../fixes
FIXPACK=`ls -tr ${WVEVER}-WS-WXDOP-FP*.pak|tail -1|cut -c1-24`
${TOOLSDIR}/setup/install_wve_fixpack.sh was=${WASVERSION} fix=${FIXPACK}

#Set normal WAS permissions
/lfs/system/tools/was/setup/was_perms.ksh
