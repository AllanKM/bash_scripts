#!/bin/sh

#
# Installs the IHS plugin
#

# USAGE: plugininst.sh [version] [volumegroup for /usr/WebSphereXX/AppServer filesystem] [64 | 32 Bit]

# Set umask
umask 002

#Defaults
FULLVERSION=51111
if lsvg appvg >/dev/null 2>&1; then
	VG=appvg
else
	VG=rootvg
fi
BITS=32

SO1=libUnixRegistryImpl.so
SO2=mod_app_server_http.so
SO3=mod_app_server_http_eapi.so
SO4=mod_ibm_app_server_http.so
SO5=mod_was_ap20_http.so

KEYSTORE_YZ=ei_yz_plugin*
KEYSTORE_GZ=ei_gz_plugin*
KEYSTORE_BZ=ei_bz_plugin*

TOOLSDIR="/lfs/system/tools"
RESPDIR=${TOOLSDIR}/was/responsefiles
WAS_ETC=${TOOLSDIR}/was/etc

SLEEP=10

#process command-line options

until [ -z "$1" ] ; do
	case $1 in
		version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FULLVERSION=$VALUE; fi ;;
		bits=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then BITS=$VALUE; fi ;;	
		keystoredir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then WAS_ETC=$VALUE; fi ;;
		vg=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VG=$VALUE; fi ;;
		toolsdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
		responsedir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then RESPDIR=$VALUE; fi ;;
		*) 	print -u2 -- "#### Unknown argument: $1" 
			print -u2 -- "#### Usage: $0 [ version=<desired WAS version> ] [ bits=<64 or 32> ]"
			print -u2 -- "####           [ keystoredir=<full path to directory with keystore files> ]"
			print -u2 -- "####           [ toolsdir=<path to ihs scripts> ] [ vg=<volume group> ]"
			print -u2 -- "####           [ responsedir=<full path to direcdtory with response files> ]"
			exit 1
			;;
        esac
        shift
done



VERSION=`echo $FULLVERSION | cut -c1,2`


#-----------------------------------
# Version 51 Plugin Installation
#-----------------------------------
install_51 ()
{
	CFLEVEL=`echo $FULLVERSION | cut -c4-`
	if [ "$CFLEVEL" == "" ]; then
        echo "Unable to determine which CF level from $VERSION"
        exit 1
	fi
    DOTVER="5.1"
    DESTDIR=/usr/WebSphere${VERSION}/AppServer
    INSTALLPKG="WSBPL1AA51"
    RESPFILE="v51silent.IHS20.plugin.script"
    LOGDIR="/logs/was${VERSION}"

    if [ ! -f ${RESPDIR}/${RESPFILE} ]; then
       echo "File ${RESPDIR}/${RESPFILE} does not exist"
       echo "Use Tivoli SD tools to push ${TOOLSDIR}/was files to this server"
       echo "Exiting..."
       exit 1
    fi

    case `uname` in
        AIX)
                INSTDIR="/fs/system/images/websphere/5.1"
                OSDIR="aix"
                FIXES="was51_fp1_aix was511_cf${CFLEVEL}_aix was511_SR5_jdk_aix"

                # These are the names of the actual shared object files which must exist
                INSTALL_STATUS=`lslpp -l| grep -c $INSTALLPKG`
                INSTALL_STATUS2=`ls -l ${DESTDIR}/bin | grep -c -E "${SO1}|${SO2}|${SO3}|${SO4}|${SO5}"`

        ;;
        Linux)

        uname -a | grep ppc > /dev/null
        if [[ $? -eq 0 ]]; then
                INSTDIR="/fs/system/images/websphere/linux_ppc/5.1/"
                OSDIR="linuxppc"
                FIXES="was51_fp1_linux was511_cf${CFLEVEL}_linux was511_SR5_jdk_linux_ppc"
            else
                INSTDIR="/fs/system/images/websphere/linux/5.1"
                OSDIR="linuxi386"
                FIXES="was51_fp1_linux was511_cf${CFLEVEL}_linux was511_SR4_jdk_linux_i386"
                #java -version hangs unless the following ulimit command is executed
                # as mentioned at http://www-1.ibm.com/support/docview.wss?uid=swg21182138
                ulimit -s 8196
            fi


                INSTALL_STATUS=`rpm -qa | grep -c $INSTALLPKG`
                INSTALL_STATUS2=`ls -l $DESTDIR | grep -c -E "${SO1}|${SO2}|${SO3}|${SO4}|${SO5}"`
        ;;
    esac
        df -m $DESTDIR > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo "Creating filesystem $DESTDIR"
			/fs/system/bin/eimkfs $DESTDIR 3072M $VG
		else
			fsize=`df -m $DESTDIR|tail -1|awk '{split($2,s,"."); print s[1]}'`
			if [ "$fsize" -lt 3072 ]; then
				echo "Increasing $DESTDIR filesystem size to 3072MB"
				/fs/system/bin/eichfs $DESTDIR 3072M
			else
				echo "Filesystem $DESTDIR already larger than 3072MB, making no changes."
			fi
		fi
		echo "---------------------------------------------------------------"
		echo " Installing WebSphere Plugin $VERSION"
		echo 
		echo
		echo "Tail /tmp/log.txt for installation details and progress"
		echo "---------------------------------------------------------------"
        cd ${INSTDIR}/wbisf/${OSDIR}/WAS/ && ./install -is:log /tmp/find_java.log -options ${RESPDIR}/${RESPFILE}
          for FIX in $FIXES
              do
                ${TOOLSDIR}/was/setup/install_was_fixpack.sh $FIX
                if [ $? -ne 0 ]; then
                  echo "Installation of $FIX failed...."
                  echo "exiting...."
                  exit 1
               fi
             done
}

#-------------------------------
# Version 61 Plugin
#-------------------------------
install_61 ()
{
   DOTVER=6.1
   INSTALLPKG="WSPAA61"

   case `uname` in
        AIX)
			###Check for 64-bit flag
			if [[ $BITS == "64" ]]; then
				WASSRCDIR="/fs/system/images/websphere/6.1/aix-64"
			else
				WASSRCDIR="/fs/system/images/websphere/6.1/aix"
			fi
        ;;
        Linux)
			###Check cpu type
			if [[ -n `uname -p|grep ppc` ]]; then
				###Check for 64-bit flag
				if [[ $BITS == "64" ]]; then
					WASSRCDIR="/fs/system/images/websphere/6.1/linuxppc-64"
				else
					WASSRCDIR="/fs/system/images/websphere/6.1/linuxppc"
				fi
			else
				###Check for 64-bit flag
				if [[ $BITS == "64" ]]; then
					echo "No 64-bit src image defined for non-ppc linux"
					echo "exiting..."
					exit 1
				else
					WASSRCDIR="/fs/system/images/websphere/6.1/linux"
				fi
			fi
        ;;
    esac
	SRCDIR="${WASSRCDIR}/supplements/plugin"
    if [ ! -f /etc/apachectl ]; then
        echo "/etc/apachectl not found. Please ensure IHS has been installed"
        echo "Exiting..."
        exit 1
    elif [ -h /etc/apachectl ]; then
        HTTP=`ls -al /etc/apachectl | cut -d">" -f2 | cut  -d"/" -f3`
        IHSDIR=/usr/${HTTP}
        DESTDIR=${IHSDIR}/Plugins
        LOGDIR="/logs/${HTTP}/Plugins"
        RESPFILE=v61silent.plugin.script

#------------------------------------
#  Base Plugin Installation
#------------------------------------
        if [ ! -f ${RESPDIR}/${RESPFILE} ]; then
          echo "File ${RESPDIR}/${RESPFILE} does not exist"
          echo "Use Tivoli SD tools to push ${TOOLSDIR}/was files to this server"
          echo "Exiting..."
          exit 1
        fi

        echo "Installing plugin in ${DESTDIR}..."
        cp ${RESPDIR}/${RESPFILE} /tmp
        cd /tmp
        sed -e "s%installLocation=.*%installLocation=${DESTDIR}%" ${RESPFILE}  > ${RESPFILE}.custom && mv ${RESPFILE}.custom  $RESPFILE
        sed -e "s%webServerConfigFile1=.*%webServerConfigFile1=${IHSDIR}/conf/httpd.conf%" ${RESPFILE}  > ${RESPFILE}.custom && mv ${RESPFILE}.custom  $RESPFILE
        #Install plugin using created response file
        ${SRCDIR}/install -options /tmp/${RESPFILE} -silent
        echo "Installation complete"
        echo ""
        FULLVER=`grep "<version>" ${DESTDIR}/properties/version/PLG.product | cut -d">" -f2 | cut -d"<" -f1`
        echo "Installed plugin version is ${FULLVER}"
        echo ""
        
#-----------------------------------
# Fixes Installation
#-----------------------------------
       echo "Executing install fixpack script"
       ${TOOLSDIR}/was/setup/install_plugin_fixes.sh root=$IHSDIR version=$FULLVERSION bits=$BITS toolsdir=$TOOLSDIR responsedir=${RESPDIR}
    fi
}
echo "Ensuring /tmp has 500MB in it"
fsize=`df -m /tmp|tail -1|awk '{split($2,s,"."); print s[1]}'`
if [ "$fsize" -lt 1024 ]; then
	echo "  -> Increasing /tmp filesystem size to 500MB"
	/fs/system/bin/eichfs /tmp 500M
else
	echo "  -> Filesystem /tmp already larger than 500MB, making no changes."
fi
case $VERSION in
	51)	install_51 ;;
	61)	install_61 ;;
    *)
		echo "Version $VERSION plugin install not supported by this script."
        echo "Exiting"
        exit 1
esac

if [ ! -d ${LOGDIR} ]; then
        echo "Create log directory ${LOGDIR}"
        echo ""
	mkdir ${LOGDIR}
fi

if [ -d ${DESTDIR}/logs ]; then
    echo "Rsync contents from ${DESTDIR}/logs to ${LOGDIR}"
    ${TOOLSDIR}/configtools/filesync ${DESTDIR}/logs/ ${LOGDIR}/ acv 0 0
    echo ""
    echo "Replace ${DESTDIR}/logs with symlink to ${LOGDIR}"
    rm -r ${DESTDIR}/logs
    ln -s ${LOGDIR} ${DESTDIR}/logs
fi
                
if [[ $VERSION == "51" ]]; then
   # Determine Zone - pick keystore to look for and check existence
   zone=`grep realm /usr/local/etc/nodecache|awk '{split($3,zone,".");print zone[1]}'`
   case $zone in
  		y) 	keyStore=$KEYSTORE_YZ
     		echo "plugin to be configured with EI YZ keystore..." ;;
  		g) 	keyStore=$KEYSTORE_GZ
     		echo "plugin to be configured with EI GZ keystore..." ;;
  		b) 	keyStore=$KEYSTORE_BZ
     		echo "plugin to be configured with EI BZ keystore..." ;;
  		*) echo "Error: Unrecognized realm [$zone] found when determining zone keystore."
  esac
  if [[ -f /usr/WebSphere${VERSION}/AppServer/etc/$keyStore ]]; then
  	echo "Found keystore in WAS directory..."
  elif [[ -f $WAS_ETC/$keyStore ]]; then
  	echo "Copying plugin keystore from $WAS_ETC..."
  	cp $WAS_ETC/$keyStore /usr/WebSphere${VERSION}/AppServer/etc/
  else
  	echo "Error: Keystore not found on node - place $keyStore in /usr/WebSphere${VERSION}/AppServer/etc/ or re-sync $WAS_ETC before continuing."
  fi
  ${TOOLSDIR}/was/setup/was_perms.ksh
elif [[ $VERSION == "61" ]]; then
  ${TOOLSDIR}/ihs/setup/ihs_perms root=$IHSDIR version=6.1
fi

