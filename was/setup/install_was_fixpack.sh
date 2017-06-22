#!/bin/ksh

#---------------------------------------------------------------
# WAS fixpack installer
#---------------------------------------------------------------

# USAGE: install_was_fixpack.sh [fixpack ID] (--skip-perms)
unset JAVA_HOME
unset WAS_HOME

# Name of the fixpack ID (i.e. 6.0-WS-WAS-AixPPC32-RP0000002, 6.1.0-WS-WAS-AixPPC32-FP0000027)
FIXPACKID=$1
SKIPPERMS=$2
PPC=0


TOOLSDIR="/lfs/system/tools/was"

was_60_fixpack ()
{
    BASEDIR="/usr/WebSphere${VERSION}"
    if [ -d ${BASEDIR}/AppServer ]; then
    	APPDIR="${BASEDIR}/AppServer"
    else
    	echo "Unable to determine base application server path!"
    	exit 1
    fi

    PRODFILE="${APPDIR}/properties/version/WAS.product"
    DOTVER=`grep version\> ${PRODFILE} | cut -d">" -f 2 | cut -d"<" -f 1`

    echo "Removing old updateinstaller files from ${APPDIR}..."
	if [ -d ${APPDIR}/updateinstaller ]; then
    	rm -r ${APPDIR}/updateinstaller
    fi

    echo "Untarring $FIXPACKID files to ${APPDIR}..."
    if [ -f "${FIXDIR}/${FIXPACKID}.tar" ]; then
    	cd ${APPDIR}
    	tar -xf "${FIXDIR}/${FIXPACKID}.tar"
    else
    	echo "${FIXDIR}/${FIXPACKID}.tar does not exist"
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
        FIXTYPE=`echo $FIXPACKID | cut  -d'-' -f5 | cut -c 1,2`
    fi

    . ${APPDIR}/bin/setupCmdLine.sh
    cd ${APPDIR}/updateinstaller

    case $FIXTYPE in
    	FP)
       		./update -silent -W maintenance.package="./maintenance/${FIXPACKID}.pak" -W product.location="/usr/WebSphere60/AppServer" -W update.type="install"
            echo "Checking WAS.product file for $DOTVER to see if fixpack installed properly"
            NEWDOTVER=`grep version\> ${PRODFILE} | cut -d">" -f 2 | cut -d"<" -f 1`
            if [ $NEWDOTVER == $DOTVER ]; then
                echo "Version info in $PRODFILE has not been updated. Please check the log file for errors."
                exit 1
            else
                echo "Fix Install Successful. Updated WAS version is: ${NEWDOTVER}"
            fi
    		;;
    	RP)
			./update -silent -W relaunch.active=false
			./update -silent -W maintenance.package="./maintenance/${FIXPACKID}.pak" -W product.location="/usr/WebSphere60/AppServer" -W update.type="install"
            echo "Checking WAS.product file for $DOTVER to see if fixpack installed properly"
            NEWDOTVER=`grep version\> ${PRODFILE} | cut -d">" -f 2 | cut -d"<" -f 1`
            if [ $NEWDOTVER == $DOTVER ]; then
                echo "Version info in $PRODFILE has not been updated. Please check the log file for errors."
                exit 1
            else
                echo "Fix Install Successful. Updated WAS version is: ${NEWDOTVER}"
            fi
    		;;
    	SDK)
			./update -silent -W relaunch.active=false
			./update -silent -W maintenance.package="./maintenance/${FIXPACKID}.pak" -W product.location="/usr/WebSphere60/AppServer" -W update.type="install"
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
}

was_61_fixpack ()
{
    BASEDIR="/usr/WebSphere${VERSION}"
    if [ -d ${BASEDIR}/AppServer ]; then
	    APPDIR="${BASEDIR}/AppServer"
	    UPDDIR="${BASEDIR}/UpdateInstaller"
    else
	    echo "Unable to determine base application server path!"
	    exit 1
    fi

    PRODFILE="${APPDIR}/properties/version/WAS.product"
    DOTVER=`grep version\> ${PRODFILE} | cut -d">" -f 2 | cut -d"<" -f 1`
    UPDNEW=`grep "Version" ${UPDINSTDIR}/UpdateInstaller/version.txt | awk '{print $2}'`
    UPDCUR=`grep "Version" ${UPDDIR}/version.txt | awk '{print $2}'`
#    CURFIXLEVEL=`echo $UPDCUR | cut -d"." -f4`
#    NEWFIXLEVEL=`echo $UPDNEW | cut -d"." -f4`
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
        	FIXTYPE=`echo $FIXPACKID | cut  -d'-' -f5 | cut -c 1,2`
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
        SDK|IF)
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
was_70_fixpack ()
{
    BASEDIR="/usr/WebSphere${VERSION}"
    if [ -d ${BASEDIR}/AppServer ]; then
            APPDIR="${BASEDIR}/AppServer"
            UPDDIR="${BASEDIR}/UpdateInstaller"
    else
            echo "Unable to determine base application server path!"
            exit 1
    fi
      
    PRODFILE="${APPDIR}/properties/version/WAS.product"
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
                FIXTYPE=`echo $FIXPACKID | cut  -d'-' -f5 | cut -c 1,2`
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
        SDK|IF)
			#./update.sh -silent -W relaunch.active=false
			./update.sh -silent -W maintenance.package="./maintenance/${FIXPACKID}.pak" -W product.location="${APPDIR}" -W update.type="install"
            echo "Checking updatelog.txt for INSTCONFSUCCESS"
            LASTLINES=`tail -3 ${APPDIR}/logs/update/${FIXPACKID}.install/updatelog.txt`
			if [ "$LASTLINES" != "" ]; then
				echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
				if [ $? -eq 0 ]; then
					echo "$FIXPACK installed"
					# Now copy the unrestricted JCE Policy files
					echo "Copying IBM JCE Unrestricted Policy files"
					cd ${APPDIR}/java/jre/lib/security
					cp -p local_policy.jar local_policy.jar.${FIXPACKID}
					cp -p /fs/system/images/websphere/unrestricted_jce_policy/local_policy.jar ./
					cp -p US_export_policy.jar US_export_policy.jar.${FIXPACKID}
					cp -p /fs/system/images/websphere/unrestricted_jce_policy/US_export_policy.jar ./
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
	60*|6.0*)
			VERSION="60"
			FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f5`
			case `uname` in
				AIX)	FIXDIR="/fs/system/images/websphere/6.0/fixes"
						platform="aix"
						;;
				Linux)	FIXDIR="/fs/system/images/websphere/linux/6.0/fixes"
						platform="linux"
						;;
				*)		echo "Not configured to install $FIXPACKID on this platform"
				        exit 1
				        ;;
			esac
			if [[ `echo ${FIXLEVEL}|grep '^FP000000[23][1-9]$'` != "" || ${FIXLEVEL} == "FP00000030" || `echo ${FIXPACKID}|grep 'IFP'` != "" ]]; then
				# Cumulative Fixpack 21 and up use the 6.1 UpdateInstaller
				UPDINEW=`ls -tr /fs/system/images/websphere/6.1/${platform}/update/|tail -1`
				UPDINSTDIR="/fs/system/images/websphere/6.1/${platform}/update/${UPDINEW}"
				UPDIRESPONSE="v60silent.updi.script"
				was_61_fixpack
			else
				was_60_fixpack
			fi
			;;
    61*|6.1*)
			VERSION="61"
			UPDIRESPONSE="v61silent.updi.script"
			case `uname` in
				AIX)
					case $FIXPACKID in
						*PPC64*)	FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f5`
									UPDINSTDIR="/fs/system/images/websphere/6.1/aix-64/update/UPDI-${FIXLEVEL}"
									FIXDIR="/fs/system/images/websphere/6.1/aix-64/base/fixes"
									;;
						*PPC32*)	FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f5`
									UPDINSTDIR="/fs/system/images/websphere/6.1/aix/update/UPDI-${FIXLEVEL}"
									FIXDIR="/fs/system/images/websphere/6.1/aix/base/fixes"
									;;
						*IFP*)		FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f4`
									if [ ! `echo ${FIXLEVEL}|grep '^IFP'` ]; then
										FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f5`
									fi
									CURPLAT=`grep panelDefPath /usr/WebSphere${VERSION}/AppServer/properties/WSCustomConstants.properties |cut -d"/" -f7`
									CURUPDLEVEL=`ls /fs/system/images/websphere/6.1/${CURPLAT}/update|tail -1`
									UPDINSTDIR="/fs/system/images/websphere/6.1/${CURPLAT}/update/${CURUPDLEVEL}"
									FIXDIR="/fs/system/images/websphere/6.1/efixes"
									;;
						*)	echo "Not configured to install $FIXPACKID on this AIX platform"
							exit 1
							;;
			        esac
					;;
			    Linux)
					case $FIXPACKID in
						*PPC64*)	FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f5`
									UPDINSTDIR="/fs/system/images/websphere/6.1/linuxppc-64/update/UPDI-${FIXLEVEL}"
									FIXDIR="/fs/system/images/websphere/6.1/linuxppc-64/base/fixes"
									;;
						*PPC32*)	FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f5`
									UPDINSTDIR="/fs/system/images/websphere/6.1/linuxppc/update/UPDI-${FIXLEVEL}"
									FIXDIR="/fs/system/images/websphere/6.1/linuxppc/base/fixes"
									;;
						  *X32*)    FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f5`
									UPDINSTDIR="/fs/system/images/websphere/6.1/linux/update/UPDI-${FIXLEVEL}"
									FIXDIR="/fs/system/images/websphere/6.1/linux/base/fixes"
									;;
						*IFP*)    FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f4`
									if [ ! `echo ${FIXLEVEL}|grep '^IFP'` ]; then
										FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f5`
									fi
									CURPLAT=`grep panelDefPath /usr/WebSphere${VERSION}/AppServer/properties/WSCustomConstants.properties |cut -d"/" -f7`
									CURUPDLEVEL=`ls /fs/system/images/websphere/6.1/${CURPLAT}/update|tail -1`
									UPDINSTDIR="/fs/system/images/websphere/6.1/${CURPLAT}/update/${CURUPDLEVEL}"
									FIXDIR="/fs/system/images/websphere/6.1/efixes"
									;;                                                            
						*)	echo "Not configured to install $FIXPACKID on this Linux platform"
						    exit 1
						    ;;
					esac
					;;
			    *)
					echo "Not configured to install $FIXPACKID on this platform"
					exit 1
					;;
			esac
			was_61_fixpack
			;;
    70*|7.0*)
            VERSION="70"
            UPDIRESPONSE="v70silent.updi.script"
            case `uname` in
                AIX)
                    case $FIXPACKID in
                    	*PPC64*)	FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f5`
                                    UPDINSTDIR="/fs/system/images/websphere/7.0/aix-64/update/UPDI-${FIXLEVEL}"
                                    FIXDIR="/fs/system/images/websphere/7.0/aix-64/base/fixes"
                                ;;
                        *PPC32*)	FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f5`
                                    UPDINSTDIR="/fs/system/images/websphere/7.0/aix/update/UPDI-${FIXLEVEL}"
                                    FIXDIR="/fs/system/images/websphere/7.0/aix/base/fixes"
                                ;;
                        *IFP*)		FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f4`
                                    if [ ! `echo ${FIXLEVEL}|grep '^IFP'` ]; then
                                            FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f5`
                                    fi
                                    CURPLAT=`grep panelDefPath /usr/WebSphere${VERSION}/AppServer/properties/WSCustomConstants.properties |cut -d"/" -f7`
                                    CURUPDLEVEL=`ls /fs/system/images/websphere/7.0/${CURPLAT}/update|tail -1`
                                    UPDINSTDIR="/fs/system/images/websphere/7.0/${CURPLAT}/update/${CURUPDLEVEL}"
                                    FIXDIR="/fs/system/images/websphere/7.0/efixes"
                                ;;                                             
                        *)	echo "Not configured to install $FIXPACKID on this AIX platform"
                            exit 1
                            ;;    
                    esac                      
                            ;;
                Linux)        
                    case $FIXPACKID in
						*PPC64*)	FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f5`
                                    UPDINSTDIR="/fs/system/images/websphere/7.0/linuxppc-64/update/UPDI-${FIXLEVEL}"
                                    FIXDIR="/fs/system/images/websphere/7.0/linuxppc-64/base/fixes"
                                ;;                                                             
						*PPC32*)	FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f5`
                                    UPDINSTDIR="/fs/system/images/websphere/7.0/linuxppc/update/UPDI-${FIXLEVEL}"
                                    FIXDIR="/fs/system/images/websphere/7.0/linuxppc/base/fixes"
                                ;;
						*X32*)	FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f5`
                                UPDINSTDIR="/fs/system/images/websphere/7.0/linux/update/UPDI-${FIXLEVEL}"
                                FIXDIR="/fs/system/images/websphere/7.0/linux/base/fixes"
                            ;;
						*X64*)	FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f5`
								UPDINSTDIR="/fs/system/images/websphere/7.0/linux-64/update/UPDI-${FIXLEVEL}"
								FIXDIR="/fs/system/images/websphere/7.0/linux-64/base/fixes"
							;;
                        *IFP*)	FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f4`
                                if [ ! `echo ${FIXLEVEL}|grep '^IFP'` ]; then
                                        FIXLEVEL=`echo ${FIXPACKID} | cut -d"-" -f5`
                                fi
                                CURPLAT=`grep panelDefPath /usr/WebSphere${VERSION}/AppServer/properties/WSCustomConstants.properties |cut -d"/" -f7`
                                CURUPDLEVEL=`ls /fs/system/images/websphere/7.0/${CURPLAT}/update|tail -1`
                                UPDINSTDIR="/fs/system/images/websphere/7.0/${CURPLAT}/update/${CURUPDLEVEL}"
                                FIXDIR="/fs/system/images/websphere/7.0/efixes"
                            ;;
                        *)	echo "Not configured to install $FIXPACKID on this Linux platform"
							exit 1
							;;
                    esac
					;;
				*)	echo "Not configured to install $FIXPACKID on this platform"
	                exit 1
	                ;;
            esac
            was_70_fixpack
            ;;
	*)	echo "Not configured to install $FIXPACKID"
		echo "exiting...."
		exit 1
		;;
esac

# Check whether EI WAS adminconsole lock was removed
if [[ $VERSION == "70" || $VERSION == "61" ]]; then
	# Both the eilock.js file and the modified prop must exist, if either are missing, re-apply
	grep eilock /usr/WebSphere${VERSION}/AppServer/systemApps/isclite.ear/isclite.war/WEB-INF/classes/com/ibm/isclite/common/Messages_en.properties > /dev/null
	if [ $? -ne 0 ] || [ ! -f /usr/WebSphere${VERSION}/AppServer/systemApps/isclite.ear/isclite.war/scripts/eilock.js ]; then
		echo "Reapplying EI WebSphere administration console lockout for the primary admin user."
		/lfs/system/tools/was/setup/install_was_lock.sh $VERSION
	fi
fi

if [ "$SKIPPERMS" == "--skip-perms" ]; then
    echo "Skipping was_perms.ksh run..."
else
    echo " Setting Permissions "
    /lfs/system/tools/was/setup/was_perms.ksh
fi

exit 0
