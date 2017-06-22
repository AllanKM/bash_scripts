#!/bin/ksh

#---------------------------------------------------------------
# WVE fixpack installer
#---------------------------------------------------------------

# USAGE: install_wve_fixpack.sh was=<61|70> fix=<fixpackid>
unset JAVA_HOME
unset WAS_HOME

#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
		was=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VERSION=$VALUE; fi ;;
    	fix=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FIXPACKID=$VALUE; fi ;;
		*)	echo "#### Unknown argument: $1"
            echo "#### Usage: install_wve_fixpack.sh was=<61|70> fix=<fixpackid>"
			exit 1
			;;
	esac
	shift
done
WASVERSION=`echo $VERSION | cut -c1-2`
UPDIRESPONSE="v${WASVERSION}silent.updi.script"

TOOLSDIR="/lfs/system/tools/wve"

wve_61_fixpack ()
{
    BASEDIR="/usr/WebSphere${WASVERSION}"
    if [ -d ${BASEDIR}/AppServer ]; then
	    APPDIR="${BASEDIR}/AppServer"
	    UPDDIR="${BASEDIR}/UpdateInstaller"
    else
	    echo "Unable to determine base application server path!"
	    exit 1
    fi

    PRODFILE="${APPDIR}/properties/version/WXDOP.product"
    DOTVER=`grep version\> ${PRODFILE} | cut -d">" -f 2 | cut -d"<" -f 1`
    UPDNEW=`grep "Version" ${UPDINSTDIR}/UpdateInstaller/version.txt | awk '{print $2}'`
    UPDCUR=`grep "Version" ${UPDDIR}/version.txt | awk '{print $2}'`
    CURFIXLEVEL=`echo $UPDCUR| awk -F . '{ print ($1*1000000)+($2*10000)+($3*100)+$4 }'`
    NEWFIXLEVEL=`echo $UPDNEW| awk -F . '{ print ($1*1000000)+($2*10000)+($3*100)+$4 }'`

    echo "Checking for the UpdateInstaller ..."
    if [[ ! -d $UPDDIR || $CURFIXLEVEL -lt $NEWFIXLEVEL ]]; then
    	echo "UpdateInstaller version $UPDCUR will be updated to $UPDNEW"
    	echo "Removing old UpdateInstaller..."
        ${UPDDIR}/uninstall/uninstall -silent
        rm -rf ${UPDDIR}/*
        echo "Installing UpdateInstaller version ${UPDNEW}"
        cd ${UPDINSTDIR}/UpdateInstaller
        ./install -silent -options "/lfs/system/tools/was/responsefiles/${UPDIRESPONSE}"
        echo "Checking updatelog.txt for INSTCONFSUCCESS"
        LASTLINES=`tail -3 ${UPDDIR}/logs/install/log.txt`
		if [ "$LASTLINES" != "" ]; then
			echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
			if [ $? -eq 0 ]; then
			    echo "UpdateInstaller installed"
			else
			    echo "UpdateInstalled install failed.  Last few lines of install log contained:"
			    echo "$LASTLINES"
			    echo
			    echo
			    echo "exiting...."
				exit 1
			fi
  		else
		    echo "Failed to locate log file:"
		    echo "     ${UPDDIR}/logs/install/log.txt"
		    echo "UpdateInstaller installation must have failed."
		    echo "Exiting...."
		    exit 1
  		fi
    else
    	echo "Installed UpdateInstaller version $UPDCUR is greater than or equal to version $UPDNEW found in gpfs...skipping update"
    fi

    echo "Copying $FIXPACKID files to ${UPDDIR}/maintenance..."
    if [ -f "${FIXDIR}/${FIXPACKID}.pak" ]; then
    	cp -p "${FIXDIR}/${FIXPACKID}.pak" ${UPDDIR}/maintenance/
    else
    	echo "${FIXDIR}/${FIXPACKID}.pak does not exist"
    	exit 1
    fi

    echo "---------------------------------------------------------------"
    echo " Installing fixpack $FIXPACKID"
    echo
    echo
    echo "Tail $APPDIR/logs/update/${FIXPACKID}.install/updatelog.txt for installation details and progress"
    echo "---------------------------------------------------------------"

    echo ${FIXPACKID} | grep -q SDK
    if [ $? -eq 0 ]; then
        FIXTYPE=SDK
    else
		echo ${FIXPACKID} | grep -q IFP
        if [ $? -eq 0 ]; then
            FIXTYPE=IF
        else
        	FIXTYPE=`echo $FIXPACKID | cut  -d'-' -f4 | cut -c 1,2`
        fi
    fi

    . ${APPDIR}/bin/setupCmdLine.sh
    cd ${UPDDIR}

    case $FIXTYPE in
        FP)
			./update.sh -silent -W maintenance.package="./maintenance/${FIXPACKID}.pak" -W product.location="${APPDIR}" -W update.type="install"
            NEWDOTVER=`grep version\> ${PRODFILE} | cut -d">" -f 2 | cut -d"<" -f 1`
			echo "Checking WAS.product file for $NEWDOTVER to see if fixpack installed properly"
            if [ $NEWDOTVER == $DOTVER ]; then
                echo "Version info in $PRODFILE has not been updated. Please check the log file for errors."
                exit 1
            else
                echo "Fix Install Successful. Updated WAS version is: ${NEWDOTVER}"
            fi
        	;;
        RP)
			#./update.sh -silent -W relaunch.active=false
			./update.sh -silent -W maintenance.package="./maintenance/${FIXPACKID}.pak" -W product.location="${APPDIR}" -W update.type="install"
            NEWDOTVER=`grep version\> ${PRODFILE} | cut -d">" -f 2 | cut -d"<" -f 1`
            echo "Checking WAS.product file for $NEWDOTVER to see if fixpack installed properly"
            if [ $NEWDOTVER == $DOTVER ]; then
                echo "Version info in $PRODFILE has not been updated. Please check the log file for errors."
                exit 1
            else
                echo "Fix Install Successful. Updated WAS version is: ${NEWDOTVER}"
            fi
        	;;
        IF)
			#./update.sh -silent -W relaunch.active=false
			./update.sh -silent -W maintenance.package="./maintenance/${FIXPACKID}.pak" -W product.location="${APPDIR}" -W update.type="install"
            echo "Checking updatelog.txt for INSTCONFSUCCESS"
            LASTLINES=`tail -3 ${APPDIR}/logs/update/${FIXPACKID}.install/updatelog.txt`
			if [ "$LASTLINES" != "" ]; then
		        echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
		        if [ $? -eq 0 ]; then
	                echo "$FIXPACK installed"
		        else
	                echo "$FIXPACK install failed.  Last few lines of install log contained:"
	                echo "$LASTLINES"
	                echo
	                echo
	                echo "exiting...."
	                exit 1
		        fi
			else
                echo "Failed to locate log file:"
                echo "     ${APPDIR}/logs/update/${FIXPACKID}.install/updatelog.txt"
                echo "Fix pack installation must have failed."
                echo "Exiting...."
                exit 1
			fi
			;;
        *)
			echo "Fixpack type not supported by this script. Please edit the script if necessary."
			exit 1
			;;
    esac
    echo "Cleaning up $FIXPACKID files from ${UPDDIR}/maintenance..."
    if [ -f "${UPDDIR}/maintenance/${FIXPACKID}.pak" ]; then
    	rm "${UPDDIR}/maintenance/${FIXPACKID}.pak"
    else
    	echo "${FIXDIR}/${FIXPACKID}.pak does not exist"
    	exit 1
    fi
}

case $FIXPACKID in
    6*|7*)
			FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f4`
			FIXDIR="/fs/system/images/websphere/ve/fixes"
			JAVAVER=`/usr/WebSphere${WASVERSION}/AppServer/java/bin/java -version  2>&1 |grep '^IBM J9 VM'`
			WASJDK=`echo $JAVAVER |awk '{print $12}'`
			WASOS=`echo $JAVAVER |awk '{print $11}'`
			case $WASOS in
				AIX)
					case $WASJDK in
						ppc64-64)	UPDFIX=`cd /fs/system/images/websphere/7.0/aix-64/update/; ls -tr|tail -1`
									UPDINSTDIR="/fs/system/images/websphere/7.0/aix-64/update/${UPDFIX}" ;;
						ppc-32)	UPDFIX=`cd /fs/system/images/websphere/7.0/aix/update/; ls -tr|tail -1`
								UPDINSTDIR="/fs/system/images/websphere/7.0/aix/update/${UPDFIX}" ;;
						*)	echo "Not configured to install Update Installer on this AIX platform"
							exit 1
							;;
			        esac
					;;
			    Linux)
					case $WASJDK in
						ppc64-64)	UPDFIX=`cd /fs/system/images/websphere/7.0/linuxppc-64/update/; ls -tr|tail -1`
									UPDINSTDIR="/fs/system/images/websphere/7.0/linuxppc-64/update/${UPDFIX}" ;;
						ppc-32)	UPDFIX=`cd /fs/system/images/websphere/7.0/linuxppc/update/; ls -tr|tail -1`
								UPDINSTDIR="/fs/system/images/websphere/7.0/linuxppc/update/${UPDFIX}" ;;
						*)	echo "Not configured to install Update Installer on this Linux platform"
							exit 1
							;;
			        esac
					;;
			    *)
					echo "Not configured to install Update Installer on this OS"
					exit 1
					;;
			esac
			wve_61_fixpack
			;;
	*)
			echo "Not configured to install $FIXPACKID"
			echo "exiting...."
			exit 1
		;;
esac

echo " Setting Permissions "
/lfs/system/tools/was/setup/was_perms.ksh
exit 0
