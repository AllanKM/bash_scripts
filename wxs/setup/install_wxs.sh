#!/bin/bash
# Usage: install_wxs.sh wxs=7.1.x.x [was=<61|70>] [profiles=<name1>[,<name2>,<name3>]]
HOST=`/bin/hostname -s`
TOOLSDIR="/lfs/system/tools/wxs"
BITVER="64"

#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
    	wxs=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then WXSFULLVER=$VALUE; fi ;;
    	was=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then WASFULLVER=$VALUE; fi ;;
    	bit=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then BITVER=$VALUE; fi ;;
		profiles=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROFILES=$VALUE; fi ;;
		*)	echo "#### Unknown argument: $1"
            echo "#### Usage: install_wxs.sh wxs=7.1.x.x [was=<61|70>] [profiles=<name1>[,<name2>,<name3>]]"
			exit 1
			;;
	esac
	shift
done
WXSVER=`echo $WXSFULLVER | cut -c1-3`
WXSNODOTVER=`echo $WXSVER | cut -c1,3`
INSTDIR="/fs/system/images/websphere/wxs/${WXSVER}"
PRODFILE="WXS.product"
VG=appvg1

if [ -n "$WASFULLVER" ]; then
	WASVER=`echo $WASFULLVER | cut -c1-2`
	BASEDIR="/usr/WebSphere${WASVER}"
	WXSROOT="/usr/WebSphere${WASVER}/AppServer"
	RESPFILE="wxs71_silent_was.script"
	if [ -z "$PROFILES" ]; then
		#Search for profiles
		i=0
		for profile in `ls ${WXSROOT}/profiles/`; do
			profList[$i]="${profile}"
			i=$(($i+1))
		done
		#If more than one profile exists, prompt user to specify via command-line
		if [ $i -gt 1 ]; then
			echo "#### Please specify which profile(s) to augment via command-line"
			echo "#### Usage: install_wxs.sh was=<61|70> [profiles=<name1>[,<name2>,<nameN>]]"
			exit 1
		fi
		PROFILES=${profList}
	fi
	#Modify the responsefile
	cp ${TOOLSDIR}/responsefiles/${RESPFILE} /tmp/
	cd /tmp
	sed -e "s%installLocation=.*%installLocation=\"${WXSROOT}\"%" ${RESPFILE}  > ${RESPFILE}.custom && mv ${RESPFILE}.custom $RESPFILE
	sed -e "s/profileAugmentList=.*/profileAugmentList=\"${PROFILES}\"/" ${RESPFILE}  > ${RESPFILE}.custom && mv ${RESPFILE}.custom $RESPFILE
else
	BASEDIR="/usr/WebSphere"
	WXSROOT="/usr/WebSphere/eXtremeScale${WXSNODOTVER}"
	RESPFILE="wxs71_silent_sa.script"
	cp ${TOOLSDIR}/responsefiles/${RESPFILE} /tmp/
fi

# Create webinst if not existing
id webinst > /dev/null 2>&1
if [  $? -ne 0 ]; then
    /fs/system/tools/auth/bin/mkeigroup -r local -f apps
    /fs/system/tools/auth/bin/mkeiuser  -r local -f webinst apps
fi

# Setup Filesystems
echo "Setting up filesystems for WXS"
df -m $BASEDIR > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Creating filesystem $BASEDIR"
	/fs/system/bin/eimkfs $BASEDIR 2560M $VG
else
	fsize=`df -m $BASEDIR|tail -1|awk '{split($2,s,"."); print s[1]}'`
	if [ "$fsize" -lt 2560 ]; then
		echo "Increasing $BASEDIR filesystem size to 2560MB"
		/fs/system/bin/eichfs $BASEDIR 2560M
	else
		echo "Filesystem $BASEDIR already 2560MB or larger, making no changes."
	fi
fi

fsize=`df -m /tmp|tail -1|awk '{split($2,s,"."); print s[1]}'`
if [ "$fsize" -lt 1024 ]; then
	echo "Increasing /tmp filesystem size to 1024MB"
	/fs/system/bin/eichfs /tmp 1024M
else
	echo "Filesystem /tmp already larger than 1024MB, making no changes."
fi

df -m /projects > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Creating filesystem /projects"
	/fs/system/bin/eimkfs /projects 1024M $VG
else
	fsize=`df -m /projects|tail -1|awk '{split($2,s,"."); print s[1]}'`
	if [ "$fsize" -lt 1024 ]; then
		echo "Increasing /projects filesystem size to 1024MB"
		/fs/system/bin/eichfs /projects 1024M
	else
		echo "Filesystem /projects already larger than 1024MB, making no changes."
	fi
fi

echo "-----------------------------------------------------------------"
echo " Installing WebSphere eXtreme Scale $WXSVER"
echo "   WXS Directory  : $WXSROOT"
echo "   Install Options: /tmp/${RESPFILE}"
echo "-----------------------------------------------------------------"
cd ${INSTDIR}
if [ "$BITVER" == "32" ]; then
    cd WXS
    ./install.aix.ppc32 -silent -options /tmp/${RESPFILE}
else
    ./install -silent -options /tmp/${RESPFILE}
fi


echo "Checking $PRODFILE file for $WXSVER"
grep version\>${WXSVER} ${WXSROOT}/properties/version/${PRODFILE}
if [ $? -ne 0 ]; then 
    echo "Failed to install WebSphere eXtreme Scale $WXSVER.  Exiting..."
    exit 1
fi

echo "Checking log.txt for INSTCONFSUCCESS"
LASTLINES=`tail -3 ${WXSROOT}/logs/wxs/install/log.txt`
if [ "$LASTLINES" != "" ]; then
    echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
    if [ $? -eq 0 ]; then
    	echo "WebSphere eXtreme Scale $WXSVER installed SUCCESSFULLY."
    else
        echo "#### WebSphere eXtreme Scale $WXSVER install FAILED."
        echo "Last few lines of install log contained:"
        echo "$LASTLINES"
        echo
        echo "Exiting..."
        exit 1
    fi
else
    echo "Failed to locate log file:"
    echo "     ${WXSROOT}/logs/wxs/install/log.txt"
    echo "Installation must have failed."
    echo "Exiting..."
    exit 1
fi

if [ -z "$WASFULLVER" ]; then
	echo "Creating $WXSLOGS"
	WXSLOGS="/logs/wxs${WXSNODOTVER}"
	if [[ ! -d $WXSLOGS ]]; then 
	    mkdir $WXSLOGS
	    chown webinst.eiadm $WXSLOGS
	    chmod u+rwx,g+rwsx,o-rwx $WXSLOGS
	fi
	mv ${WXSROOT}/logs ${WXSROOT}/logs.orig
	ln -s $WXSLOGS ${WXSROOT}/logs
	chmod g+s $BASEDIR $WXSLOGS
	mv ${WXSROOT}/logs.orig/* $WXSLOGS
	rm -fr ${WXSROOT}/logs.orig
fi
# -- Pull OS platform info for JDK fixpacks --#
case `uname` in
	"Linux") OS="Linux" ;;
	"AIX") OS="Aix" ;;
esac
case `uname -p` in
	ppc* | powerpc)	PLATFORM="PPC" ;;
	x86_64)	PLATFORM="X" ;;
esac

# Install Fixpacks if necessary
if [ -n "$WASVER" ]; then
	# IFPM87563 not applicable to WAS client installs
	case $WXSFULLVER in
		7.1.0.0) echo "!!--- No Fixpack selected for install ---!!" ;;
		7.1.0.1) ${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.0.1-WS-WXS-FP0000001 was=$WASVER ;;
		7.1.0.2) ${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.0.2-WS-WXS-FP0000002 was=$WASVER ;;
		7.1.0.3) ${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.0.3-WS-WXS-FP0000003 was=$WASVER
				${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.0.3-WS-WXS-IFPM54583 was=$WASVER
				${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.0.3-WS-WXS-IFPM59004 was=$WASVER ;;
		7.1.1.1) ${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.0-WS-WXS-RP0000001 was=$WASVER
				${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.1-WS-WXS-FP0000001 was=$WASVER
				${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.1.1-WS-WXS-IFPM68769 was=$WASVER
				${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.1.1-WS-WXS-IFPM77948 was=$WASVER
				${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.1.1-WS-WXS-IFPM87867 was=$WASVER ;;
		*) echo "### Not configured to install specified WXS fixpack!"
	esac
else
	case $WXSFULLVER in
		7.1.0.0) echo "!!--- No Fixpack selected for install ---!!" ;;
		7.1.0.1) ${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.0.1-WS-WXS-FP0000001 ;;
		7.1.0.2) ${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.0.2-WS-WXS-FP0000002 ;;
		7.1.0.3) ${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.0.3-WS-WXS-FP0000003
				${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.0.3-WS-WXS-IFPM54583
				${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.0.3-WS-WXS-IFPM59004 ;;
		7.1.1.1) ${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.0-WS-WXS-RP0000001
				${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.1-WS-WXS-FP0000001
				${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.1.1-WS-WXS-IFPM68769
				${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.1.1-WS-WXS-IFPM77948
				${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.1.1-WS-WXS-IFPM87867
				${TOOLSDIR}/setup/install_wxs_fixpack.sh fix=7.1.1.1-WS-WXS-${OS}${PLATFORM}${BITVER}-IFPM87563 ;;
		*) echo "### Not configured to install specified WXS fixpack!"
	esac
fi

#Set normal WAS permissions
/lfs/system/tools/was/setup/was_perms.ksh