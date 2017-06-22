#!/bin/bash
#---------------------------------------------------------------
# Uninstall WebSphere eXtremeScale (run as sudo)
#---------------------------------------------------------------
#
# USAGE: remove_wxs_86.sh wxs=<wxsversion> | was=<wasversion> pkgtype=<STANDALONE | CLIENT | WASCLIENT | WAS7CLIENT> [augprofiles=<name1>[,<name2>,<nameN>]] [nostop]
#
#---------------------------------------------------------------
#
#  Change History: 
#
#  Lou Amodeo - 06/19/2013 - Initial creation
#  Lou Amodeo - 12/12/2013 - change rmfs to /fs/system/bin/eirmfs
#
#
#---------------------------------------------------------------
#

#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
        wxs=*)         VALUE=${1#*=}; if [ "$VALUE" != "" ];      then FULLVERSION=$VALUE; fi ;;
        was=*)         VALUE=${1#*=}; if [ "$VALUE" != "" ];      then WASFULLVER=$VALUE;  fi ;;
        pkgtype=*)     VALUE=${1#*=}; if [ "$VALUE" != "" ];      then PKGTYPE=$VALUE;     fi ;;
        augprofiles=*) VALUE=${1#*=}; if [ "$VALUE" != "" ];      then PROFILES=$VALUE;    fi ;;
        nostop)        VALUE=${1#*=}; if [ "$VALUE" != "" ];      then NOSTOP="nostop";    fi ;;
        *)  echo "#### Unknown argument: $1"
            echo "#### Usage: remove_wxs_86.sh wxs=<wxsversion> | was=<wasversion> pkgtype=<STANDALONE | CLIENT | WASCLIENT | WAS7CLIENT> [augprofiles=<name1>[,<name2>,<nameN>]] [nostop]"
            exit 1
            ;;
    esac
    shift
done

if [ ${PKGTYPE} == "STANDALONE" ]; then
      PACKAGE="com.ibm.websphere.WXS.v86"
elif [ ${PKGTYPE} == "WASCLIENT" ]; then
      PACKAGE="com.ibm.websphere.WXSCLIENT.was8.v86"
elif [ ${PKGTYPE} == "WAS7CLIENT" ]; then
      PACKAGE="com.ibm.websphere.WXSCLIENT.was7.v86"      
elif [ ${PKGTYPE} == "CLIENT" ]; then
      PACKAGE="com.ibm.websphere.WXSCLIENT.v86"
else
      echo "Invalid Package type specified: ${PKGTYPE}"
      exit 1
fi

# WASCLIENT gets installed in WebSphere directory tree, other clients in eXtremeScale tree
if [ ${PKGTYPE} == "WASCLIENT" -o ${PKGTYPE} == "WAS7CLIENT" ]; then
    if [ -z ${WASFULLVER} ]; then
        echo  "was= must be specified"
        exit 1
    fi
    WASVERSION=`echo $WASFULLVER | cut -c1-2`
    BASEDIR="/usr/WebSphere${WASVERSION}"
    APPDIR="${BASEDIR}/AppServer"
else
    if [ -z $FULLVERSION} ]; then
        echo  "wxs= must be specified"
        exit 1
    fi
    VERSION=`echo $FULLVERSION | cut -c1-2`
    BASEDIR="/usr/WebSphere${VERSION}"
    APPDIR="${BASEDIR}/eXtremeScale"
fi

IMBASEDIR="/opt/IBM/InstallationManager"

if [ ! -d $APPDIR ]; then
    echo "WebSphere eXtremeScale is not installed at $APPDIR"
    exit 1
fi

if [ ${PKGTYPE} == "WASCLIENT" -o ${PKGTYPE} == "WAS7CLIENT" ]; then
    if [ -z "$NOSTOP" ]; then
	    if [ -d ${APPDIR} ]; then
		    echo "Executing: \"rc.was stop all\""
		    if [ -f /lfs/system/tools/was/bin/rc.was ]; then
			    /lfs/system/tools/was/bin/rc.was stop all
		    fi
	    else
		    echo "Failed to locate $APPDIR, exiting..."
		    exit
	    fi
    else
	    echo "NoStop was specified, proceeding with the assumption that WebSphere is stopped."
    fi
fi

#
# Unaugment WebSphere profiles if profiles were specified
# You cannot uninstall the WXS WASCLIENT if existing profiles have been augmented.
# 
if [ "$PKGTYPE" == "WASCLIENT" -o "$PKGTYPE" == "WAS7CLIENT" ]; then
   if [ ! -z "$PROFILES" ]; then
      /lfs/system/tools/wxs/setup/augment_profile_wxs_86.sh was=$WASVERSION profiles=$PROFILES unaugment $NOSTOP
   fi
fi

echo "------------------------------------------------------------------------------------------"
echo " Uninstalling WebSphere eXtremeScale package: $PACKAGE "
echo " Location: $APPDIR                                                                        "
echo
echo "------------------------------------------------------------------------------------------"
echo

$IMBASEDIR/eclipse/tools/imcl uninstall $PACKAGE -installationDirectory $APPDIR
if [ $? -ne 0 ]; then 
    echo "Failed to uninstall package: $PACKAGE.  Exiting...."
    exit 1
fi

if [ ${PKGTYPE} == "STANDALONE" -o "$PKGTYPE" == "CLIENT" ]; then
    if [ -d $APPDIR ]; then
	    echo "Removing logs directory /logs/wxs${VERSION}"
	    cd /tmp
	    rm -fr /logs/wxs${VERSION}	
	    echo "Removing $APPDIR filesystem"
	    /fs/system/bin/eirmfs -f $APPDIR
	    if [ -d $APPDIR ]; then
		    rmdir $APPDIR
	    fi
	    if [ -d $BASEDIR ]; then
            rmdir $BASEDIR
        fi
    fi
fi

echo "-------------------------------------------------------------------------------------"
echo " Uninstalled WebSphere eXtremScale successfully                                      "
echo
echo "-------------------------------------------------------------------------------------"
echo
exit 0
