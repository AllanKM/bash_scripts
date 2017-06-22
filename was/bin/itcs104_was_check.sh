#!/bin/bash
# Usage: itcs104_was_check.sh [version=VERSION] [profile=PROFILE] [--skip-archive]
#
#---------------------------------------------------------------------------------
#
# Change History: 
#
#  Lou Amodeo     03-01-2013  Add support for WebSphere V8.5
#  Lou Amodeo     03-13-2013  Process user test failing due to TSM backup.
#  Lou Amodeo     03-14-2013  Change TIME logging counter to warning.
#  Lou Amodeo     11-08-2013  Section 5 $WASROOT perms returning wrong value
#                             for symbolic links
#
#
#---------------------------------------------------------------------------------
#
# Check if a base WAS dir exists, otherwise, exit
if [ -d /usr/WebSphere61 ]; then
  wasbox="Yes"
fi
if [ -d /usr/WebSphere70 ]; then
  wasbox="Yes"
fi
if [[ -d /usr/WebSphere85 && $(mount | grep /gpfs/projects_isolated/ibmportal | grep ,ro | wc -l | sed 's/ //g') -eq 0 ]]; then
  wasbox="Yes"
fi
# Exit if no WAS is found
if [ -z $wasbox ]; then
  exit 1
fi

host=`hostname`
DATE=`date +"%Y%m%d"`
ARCHIVEDIR=/fs/backups/audit/was/`date +"%Y%m"`
REALARCHDIR=/fs/system/audit/was/`date +"%Y%m"`
SCRATCHDIR=/fs/scratch/wasitcs104/`date +"%Y%m"`
ARCHIVELOG="${ARCHIVEDIR}/was_itcs104_${host}_${DATE}.log"
LOCALLOG="/logs/was_itcs104_${DATE}.log"
PLATFORM=`uname`
ITCSVER="9.0"

if [ `ps -ef |grep java |grep -v grep |grep WebSphere|wc -l` = 0 ]; then
  echo "No running processes" > $LOCALLOG
  exit 1
fi

#
if [ ! -d $SCRATCHDIR ]; then
  mkdir -p $SCRATCHDIR
  chgrp eiadm $SCRATCHDIR 
  chmod 770 $SCRATCHDIR
fi



#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
		version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VERSION=$VALUE; fi ;;
		profile=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROFILE=$VALUE; fi ;;
		"--skip-archive")  skipArchive="yes" ;;
		*)	echo "#### Unknown argument: $1"
            echo "#### Usage: itcs104_was_check.sh [version=<85|70|61>] [profile=<profileName>] [--skip-archive]"
			exit 1
			;;
	esac
	shift
done

function itcsHCHeader {
  echo "ITCS WebSphere Application Server Appendix Version ${ITCSVER}"
  echo "Hostname: `hostname`"
  echo "Date: ${DATE}"
  echo "Owner: Marjan Gjoni"
}

itcsHCHeader >> $LOCALLOG

#Populate list of possible base directories
case $VERSION in
	61|70|85)	rootDir="/usr/WebSphere${VERSION}/AppServer"
			if [[ -n $PROFILE ]]; then
				dirs="${rootDir}/profiles/${PROFILE}"
			else
				i=0
				for profile in `ls ${rootDir}/profiles/`; do
					dirs[$i]="${rootDir}/profiles/${profile}"
					i=$(($i+1))
				done
			fi ;;
	*)	rootDirs="/usr/WebSphere85/AppServer /usr/WebSphere70/AppServer /usr/WebSphere61/AppServer"
		i=0
		for root in $rootDirs; do
			for profile in `ls ${root}/profiles/`; do
				dirs[$i]="${root}/profiles/${profile}"
				i=$(($i+1))
			done
		done ;;
esac

if [ -f /logs/was_itcs104_*.log ]; then
	echo "Cleaning out any old local reports from /logs"
	rm /logs/was_itcs104_*.log
fi
echo "ITCS104 Report will be logged to $LOCALLOG"
echo "This may take a while, do not interrupt or press any keys (most I/O will be redirected)"

#Begin loop of directories
for dir in ${dirs[*]}; do
	failCount=0
	warnCount=0
	if [[ ! -d $dir ]]; then
		# Skip this directory, it doesn't exist
		continue
	fi
	WASROOT=${dir%%/profiles/*}
	ASROOT=$dir
	CFGROOT="${ASROOT}/config"
	echo "  Scanning: $ASROOT"
	case $WASROOT in
        "/usr/WebSphere85/AppServer")
			procExecList=$(grep execution ${CFGROOT}/cells/*/nodes/*/servers/*/server.xml |sed 's/\ /~/g'|sed 's/:~/~/g'|sed 's/~~~~/~/g'|awk '{split($0,proc,"~/"); for (x in proc) print proc[x];}')
			VERSION=85 ;;
		"/usr/WebSphere70/AppServer")
			procExecList=$(grep execution ${CFGROOT}/cells/*/nodes/*/servers/*/server.xml |sed 's/\ /~/g'|sed 's/:~/~/g'|sed 's/~~~~/~/g'|awk '{split($0,proc,"~/"); for (x in proc) print proc[x];}')
			VERSION=70 ;;
		"/usr/WebSphere61/AppServer")
			procExecList=$(grep execution ${CFGROOT}/cells/*/nodes/*/servers/*/server.xml |sed 's/\ /~/g'|sed 's/:~/~/g'|sed 's/~~~~/~/g'|awk '{split($0,proc,"~/"); for (x in proc) print proc[x];}')
			VERSION=61 ;;
	esac
	LOGDIR="/logs/was${VERSION}"

	{ #Begin code block for file redirection
	echo "@@ ========== Begin ITCS104 Compliance Report -- $DATE -- $host -- $ASROOT =========="
	echo "@@ ---------- Checking ITCS104 WAS Section 1 ----------"
	case $VERSION in
		61) LOGGING="-tracefile ${LOGDIR}/wsadmin.itcs104-authAdmin.traceout" ;;
		*) LOGGING="" ;;
	esac
	su - webinst -c "${ASROOT}/bin/wsadmin.sh -conntype NONE $LOGGING -f /lfs/system/tools/was/lib/auth.py -action list -auth admin |grep -v ServerExt|grep -v PrimaryAdminExt|grep -v '^WASX'|grep -v 'sys-package'"
	if [ $? -ne 0 ]; then
		echo "@@ ITCS104-WAS 1.1 Userids (Roles): FAIL *** No Users or Groups defined in the ${VERSION} Admin Authorization Roles."
		failCount=$(($failCount+1))
	else
		echo "@@ ITCS104-WAS 1.1 Userids (Roles): PASS *** Users/Groups defined in ${VERSION} Admin Authorization Roles."
		userRoles="true"
	fi

	pUser=`ps -ef |grep "/usr/WebSphere${VERSION}/AppServer"|egrep -v "LCF|bNimble" |grep -v grep|tail -1|awk '{print $1}'|xargs -I '{}' grep {} /etc/passwd`
	echo $pUser
	if [[ $pUser == "" ]]; then
       if [[ `ps -ef |grep "WebSphere${VERSION}"|grep -v grep |wc -l` -gt 0 ]]; then 
		  echo "@@ ITCS104-WAS 1.1 Userids (Process): FAIL *** WebSphere ${VERSION} process user is NOT a unique local ID."
		  failCount=$(($failCount+1))
       else
		  echo "@@ ITCS104-WAS 1.1 Userids (Process): *** WebSphere ${VERSION} process is NOT running."
                fi
	else
		echo "@@ ITCS104-WAS 1.1 Userids (Process): PASS *** WebSphere ${VERSION} process user is a unique local ID."
	fi
	
	pGroup=`ps -ef |grep "WebSphere${VERSION}"|grep -v LCF|grep -v bNimble|grep -v grep|tail -1|awk '{print $1}'|xargs -I '{}' grep {} /etc/group`
	echo $pGroup
	if [[ $pGroup == "" ]]; then
                if [[ `ps -ef |grep "WebSphere${VERSION}"|grep -v grep |wc -l` -gt 0 ]]; then 
		  echo "@@ ITCS104-WAS 1.1 Userids (Process): FAIL *** WebSphere ${VERSION} process group is NOT a unique local group."
		  failCount=$(($failCount+1))
                else
		  echo "@@ ITCS104-WAS 1.1 Userids (Process): *** WebSphere ${VERSION} process is NOT running."
                fi
	else
		echo "@@ ITCS104-WAS 1.1 Userids (Process): PASS *** WebSphere ${VERSION} process group is a unique local group."
	fi
	
	webID=`ps -ef |grep "/usr/WebSphere${VERSION}/AppServer"|grep -v LCF|grep -v bNimble|grep -v grep|tail -1|awk '{print $1}'`;
    webinstID=${webID}
    idcheck=1
    for grp in $(groups ${webID} | awk -F':' {'print $2'}); do 
       if [[ "apps itmusers mqbrkrs mqm stg hadoop" != *"${grp}"* ]]; then 
            idcheck=0
       fi
    done  
    if [[ $idcheck == '1' ]]; then
       echo $webinstID
	   echo "@@ ITCS104-WAS 1.1 Userids (Process): PASS *** WebSphere ${VERSION} process user has limited system privileges." 
    else
	   echo $webinstID
       echo "@@ ITCS104-WAS 1.1 Userids (Process): FAIL *** WebSphere ${VERSION} process user has non-standard system privileges, check for possible root/system/user access."
       failCount=$(($failCount+1))
	fi
	
	procUser=`echo $webinstID |awk '{print $1}'`
	for procexec in $procExecList; do
		if [ $VERSION -eq 61 ]; then
				procName=$(echo $procexec |awk '{split($0,proc,"~"); split(proc[1],name,"/"); print name[11]"("name[13]")"}')
				runUser=$(echo $procexec |awk '{split($0,proc,"~"); split (proc[5],user,"\""); print user[2]}')
				runGroup=$(echo $procexec |awk '{split($0,proc,"~"); split (proc[6],group,"\""); print group[2]}')
		else
				procName=$(echo $procexec |awk '{split($0,proc,"~"); split(proc[1],name,"/"); print name[9]"("name[11]")"}')
				runUser=$(echo $procexec |awk '{split($0,proc,"~"); split (proc[5],user,"\""); print user[2]}')
				runGroup=$(echo $procexec |awk '{split($0,proc,"~"); split (proc[6],group,"\""); print group[2]}')
		fi

		if [[ -z $runUser || -z $runGroup ]]; then
			if [[ $procUser != "webinst" ]]; then
				# RunAs user/group are not configured and webinst is not running the process, fail ITCS104 check
				echo "@@ ITCS104-WAS 1.1 Userids (Process): FAIL *** WAS${VERSION} JVM missing runAs user or group and process is not running as webinst (unique user) -- $procName :: $runUser / $runGroup"
				failCount=$(($failCount+1))
			else
				# RunAs user/group are not configured and webinst is running the process, warn to fix configs
				echo "@@ ITCS104-WAS 1.1 Userids (Process): WARN *** WAS${VERSION} JVM missing runAs user or group, but process is running as webinst (unique user), fix configs for better security -- $procName :: $runUser / $runGroup"
				warnCount=$(($warnCount+1))
			fi
		else
				echo "@@ ITCS104-WAS 1.1 Userids (Process): PASS *** WAS${VERSION} RunAs user/group are configured - $procName :: $runUser / $runGroup"
		fi
	done

	cd ${CFGROOT}
	if [[ $VERSION -eq 61 || $VERSION -eq 70 || $VERSION -eq 85 ]]; then
		echo "@@ ITCS104-WAS 1.1 Userids (ServerID): PASS *** WebSphere 6.1 / 7.0 / 8.5 -- no serverID required."
	else
		srvID=`grep serverId cells/*/security.xml |grep LDAP|awk '{print $4}'`
		case "$srvID" in
			'serverId="eiteam"'| \
			'serverId="eiauth@events.ihost.com"'| \
			'serverId="IBMuniqueIdentifier=060000GMV4,cn=people,c=US,l=world"'| \
			'serverId="uid=270002YDRHWI,ou=persons,o=ibm.com"'| \
			'serverId="uid=060000GMV4WI,ou=persons,o=ibm.com"')
					echo "WebSphere ${VERSION} LDAP serverID = $srvID"
					echo "@@ ITCS104-WAS 1.1 Userids (ServerID): PASS *** Unique/non-personal LDAP Security ServerID in use in WAS${VERSION}." ;;
			'serverId="uid=C-794B897,c=us,ou=bluepages,o=ibm.com"')
					CELL="IIP"
					echo "WebSphere ${VERSION} LDAP serverID = $srvID"
					echo "@@ ITCS104-WAS 1.1 Userids (ServerID): PASS *** Unique/non-personal LDAP Security ServerID in use in WAS${VERSION}." ;;
			*)
				echo "WebSphere LDAP serverID = $srvID"
				echo "@@ ITCS104-WAS 1.1 Userids (ServerID): FAIL *** WebSphere ${VERSION} LDAP Security serverID is not one of the EI unique IDs (could be a personal ID or v6.1 slipping through)."
				failCount=$(($failCount+1))
		esac
		if [[ $userRoles != "true" ]]; then
			echo "@@ ITCS104-WAS 1.1 Userids (ServerID): FAIL *** Additional administration IDs are NOT configured in WAS${VERSION} (see output from Admin Auth Roles)."
			failCount=$(($failCount+1))
		else
			echo "@@ ITCS104-WAS 1.1 Userids (ServerID): PASS *** Additional administration IDs are configured in WAS${VERSION}."
		fi
	fi
	cd ${WASROOT}
	if [[ $CELL == "IIP" ]]; then
		echo "@@ ITCS104-WAS 1.1 Userids (ServerID): PASS *** WAS${VERSION} Cell secured to IIP, default admin user has expiring password."
	else
		if [[ `expr match $WASROOT '\(WebSphere60\)'` ]]; then
			grep 'eilock\.js' systemApps/adm*/adminc*/WEB-INF/classes/com/ibm/ws/console/core/resources/ConsoleAppResources.properties
			if [ $? -ne 0 ]; then
				echo "@@ ITCS104-WAS 1.1 Userids (ServerID): FAIL *** WebSphere ${VERSION} is not restricting the default admin user which has a non-expiring password, install the EI WAS 6.0 console properties [AppDB DOC-0020JFW]"
				failCount=$(($failCount+1))
			else
				echo "@@ ITCS104-WAS 1.1 Userids (ServerID): PASS *** WebSphere ${VERSION} is restricting the default admin user, which has non-expiring password."
			fi
		fi
	fi

	echo "@@ ---------- Checking ITCS104 WAS Section 2 ----------"
	cd ${CFGROOT}
	grep '<security' cells/*/security.xml|awk '{print $9}'|grep "true"
	if [ $? -ne 0 ]; then
		grep '<security' cells/*/security.xml|awk '{print $9}'
		echo "@@ ITCS104-WAS 2 Authentication (Security): FAIL *** WebSphere ${VERSION} Security (Global/Admin+App) is NOT enabled."
		failCount=$(($failCount+1))
	else
		echo "@@ ITCS104-WAS 2 Authentication (Security): PASS *** WebSphere ${VERSION} Security (Global/Admin+App) is enabled."
		securityON="true"
	fi
	
	asSec=`find . -name security.xml|grep 'servers/'|wc -l`
	if [ $asSec -eq 0 ]; then
		echo "@@ ITCS104-WAS 2 Authentication (Security): PASS *** No ${VERSION} application servers using custom security settings."
	else
		grep '<security' cells/*/nodes/*/servers/*/security.xml|awk '{print $11}'
		asSec=`grep '<security' cells/*/nodes/*/servers/*/security.xml|awk '{print $11}'|wc -l`
		echo "@@ ITCS104-WAS 2 Authentication (Security): PASS *** Note: $asSec application servers are using custom security settings; i.e. WebSphere ${VERSION} security could be disabled (not a violation)."
	fi
	
	if [[ $VERSION -eq 61 || $VERSION -eq 70 || $VERSION -eq 85 ]]; then
		echo "@@ ITCS104-WAS 2 Authentication (SSL): PASS *** WAS 6.1/7.0 SSL default keystores are allowed."
	else
		grep 'Dummy' cells/*/security.xml
		if [ $? -ne 1 ]; then
			echo "@@ ITCS104-WAS 2 Authentication (SSL): FAIL *** WebSphere ${VERSION} has Dummy keystores in the SSL configurations."
			failCount=$(($failCount+1))
		else
			echo "@@ ITCS104-WAS 2 Authentication (SSL): PASS *** Dummy keystores not in use in the WAS${VERSION} SSL configurations."
		fi
	fi

	isWIM=0
	if [[ $VERSION -eq 70 || $VERSION -eq 85 ]]; then
		grep '<security' cells/*/security.xml|awk '{print $18}'|grep "LTPA"
		if [ $? -ne 0 ]; then
			grep '<security' cells/*/security.xml|awk '{print $18}'
			echo "@@ ITCS104-WAS 2 Authentication (Mechanism): FAIL *** WebSphere ${VERSION} security authentication mechanism is NOT LTPA."
			failCount=$(($failCount+1))
		else
			echo "@@ ITCS104-WAS 2 Authentication (Mechanism): PASS *** WebSphere ${VERSION} security authentication mechanims is LTPA."
		fi
		
		grep '<security' cells/*/security.xml|awk '{print $19}'|grep "LDAP"
		if [ $? -ne 0 ]; then
			grep '<security' cells/*/security.xml|awk '{print $19}'|grep "WIM"
			if [ $? -eq 0 ]; then
				isWIM=1
				grep 'LdapRepositoryType' cells/*/wim/config/wimconfig.xml
				if [ $? -ne 0 ]; then
					grep '<security' cells/*/security.xml|awk '{print $19}'
					echo "@@ ITCS104-WAS 1.1 Userids + 2 Authentication (LDAP): WARN *** WebSphere ${VERSION} security user registry is Federated Repositories without LDAP. (LDAP is preferred, followed by LocalOS - where possible)"
					warnCount=$(($warnCount+1))
				else
					echo "@@ ITCS104-WAS 1.1 Userids + 2 Authentication (LDAP): PASS *** WebSphere ${VERSION} security user registry is Federated Repositories with LDAP."
					ldapSecurity="true"
				fi
			else
				grep '<security' cells/*/security.xml|awk '{print $19}'
				echo "@@ ITCS104-WAS 1.1 Userids + 2 Authentication (LDAP): WARN *** WebSphere ${VERSION} security user registry is not LDAP or Federated Repositories. (LDAP is preferred, followed by LocalOS - where possible)"
				warnCount=$(($warnCount+1))
			fi
		else
			echo "@@ ITCS104-WAS 1.1 Userids + 2 Authentication (LDAP): PASS *** WebSphere ${VERSION} security user registry is LDAP."
			ldapSecurity="true"
		fi
	elif [[ $VERSION -eq 61 ]]; then
		grep '<security' cells/*/security.xml|awk '{print $17}'|grep "LTPA"
		if [ $? -ne 0 ]; then
			grep '<security' cells/*/security.xml|awk '{print $17}'
			echo "@@ ITCS104-WAS 2 Authentication (Mechanism): FAIL *** WebSphere ${VERSION} security authentication mechanism is NOT LTPA."
			failCount=$(($failCount+1))
		else
			echo "@@ ITCS104-WAS 2 Authentication (Mechanism): PASS *** WebSphere ${VERSION} security authentication mechanims is LTPA."
		fi
		
		grep '<security' cells/*/security.xml|awk '{print $18}'|grep "LDAP"
		if [ $? -ne 0 ]; then
			grep '<security' cells/*/security.xml|awk '{print $18}'|grep "WIM"
			if [ $? -eq 0 ]; then
				isWIM=1
				grep 'LdapRepositoryType' cells/*/wim/config/wimconfig.xml
				if [ $? -ne 0 ]; then
					grep '<security' cells/*/security.xml|awk '{print $18}'
					echo "@@ ITCS104-WAS 1.1 Userids + 2 Authentication (LDAP): WARN *** WebSphere ${VERSION} security user registry is Federated Repositories without LDAP. (LDAP is preferred, followed by LocalOS - where possible)"
					warnCount=$(($warnCount+1))
				else
					echo "@@ ITCS104-WAS 1.1 Userids + 2 Authentication (LDAP): PASS *** WebSphere ${VERSION} security user registry is Federated Repositories with LDAP."
					ldapSecurity="true"
				fi
			else
				grep '<security' cells/*/security.xml|awk '{print $18}'
				echo "@@ ITCS104-WAS 1.1 Userids + 2 Authentication (LDAP): WARN *** WebSphere ${VERSION} security user registry is not LDAP or Federated Repositories. (LDAP is preferred, followed by LocalOS - where possible)"
				warnCount=$(($warnCount+1))
			fi
		else
			echo "@@ ITCS104-WAS 1.1 Userids + 2 Authentication (LDAP): PASS *** WebSphere ${VERSION} security user registry is LDAP."
			ldapSecurity="true"
		fi
	else
		echo "@@ ITCS104-WAS 2 Authentication (Mechanism): WARN *** Unable to determine WebSphere ${VERSION} security authentication mechanism (scan not configured for version)."
		echo "@@ ITCS104-WAS 1.1 Userids + 2 Authentication (LDAP): WARN *** Unable to determine WebSphere ${VERSION} security user registry is or is not LDAP (scan not configured for version)."
		warnCount=$(($warnCount+2))
	fi
	
	if [[ $ldapSecurity == "true" ]]; then
		if [ $isWIM -eq 1 ]; then
			grep 'sslEnabled="true"' cells/*/wim/config/wimconfig.xml
			if [ $? -ne 0 ]; then
				echo "@@ ITCS104-WAS 2 Authentication (LDAP): FAIL *** WebSphere ${VERSION} LDAP user registry in Federated Repositories is not configured for SSL."
				failCount=$(($failCount+1))
			else
				echo "@@ ITCS104-WAS 2 Authentication (LDAP): PASS *** WebSphere ${VERSION} LDAP user registry in Federated Repositories configured for SSL."
			fi
		else
			grep 'security:LDAPUserRegistry' cells/*/security.xml|grep 'sslEnabled="true"'
			if [ $? -ne 0 ]; then
				grep 'security:LDAPUserRegistry' cells/*/security.xml
				echo "@@ ITCS104-WAS 2 Authentication (LDAP): FAIL *** WebSphere ${VERSION} LDAP user registry is not configured for SSL."
				failCount=$(($failCount+1))
			else
				echo "@@ ITCS104-WAS 2 Authentication (LDAP): PASS *** WebSphere ${VERSION} LDAP user registry configured for SSL."
			fi
		fi
	else
		echo "## LDAP user registry not in use, skipping LDAP SSL check."
	fi
	
	echo "@@ ---------- Checking ITCS104 WAS Section 3 ----------"
	case $VERSION in
		61|70|85) LOGGING="-tracefile ${LOGDIR}/wsadmin.itcs104-authNaming.traceout" ;;
		*) LOGGING="" ;;
	esac
	su - webinst -c "${ASROOT}/bin/wsadmin.sh -conntype NONE $LOGGING -f /lfs/system/tools/was/lib/auth.py -action list -auth naming|grep -v ServerExt|grep -v '^WASX'|grep -v 'sys-package'|grep Everyone|grep Read"
	if [ $? -ne 0 ]; then
		echo "@@ ITCS104-WAS 3 Authorization: FAIL *** CORBA Naming Role (Everyone) is NOT set to only Read permission in WAS${VERSION}."
		failCount=$(($failCount+1))
	else
		echo "@@ ITCS104-WAS 3 Authorization: PASS *** CORBA Naming Role (Everyone) set to only Read permission in WAS${VERSION}."
	fi
	
	### Used to be a code-block to check that AllAuthenticated was set to Read Only ###
	### Starting with v6.1, AllAuthenticated group was no longer available ###
	
	echo "@@ ---------- Checking ITCS104 WAS Section 4 ----------"
	# Check SSL security levels; Note: SSL_TLS utilizes SSLv2
	if [[ $VERSION -eq 61 || $VERSION -eq 70 || $VERSION -eq 85 ]]; then
		secLev=`grep 'securityLevel=' cells/*/security.xml|grep -v 'securityLevel="HIGH"'`
		sslProt=`grep 'sslProtocol' cells/*/security.xml|grep -v SSLv[23]|grep -v 'TLS'`
	else
		secLev=`grep 'securityLevel=' cells/*/security.xml|grep -v 'securityLevel="HIGH"'`
		sslProt=`grep 'ssl.protocol' cells/*/security.xml|grep -v SSLv[23]|grep -v 'TLS'`
	fi
	if [[ $secLev != "" ]]; then
		echo "@@ ITCS104-WAS 4.1 Encryption (SSL): FAIL *** One or more WAS${VERSION} SSL configurations are NOT using HIGH security levels (less than 128-bit encryption)."
		failCount=$(($failCount+1))
	else
		echo "@@ ITCS104-WAS 4.1 Encryption (SSL): PASS *** All WAS${VERSION} SSL configurations are using HIGH security levels (128-bit or better encryption)."
	fi
	if [[ $sslProt != "" ]]; then
		echo "@@ ITCS104-WAS 4.1 Encryption (SSL): FAIL *** One or more WAS${VERSION} SSL configurations are NOT SSLv2 or higher."
		failCount=$(($failCount+1))
	else
		echo "@@ ITCS104-WAS 4.1 Encryption (SSL): PASS *** All WAS${VERSION} SSL configurations are using SSLv2 or higher."
	fi
	
	# Check that servers have HTTPS transports, warn if HTTP-only
	case $VERSION in
		61|70|85)
			srvCount=`grep APPLICATION_SERVER cells/*/nodes/*/serverindex.xml|grep -v m2m|wc -l`
			srvSSL=`grep WC_defaulthost_secure cells/*/nodes/*/serverindex.xml|wc -l` ;;
		*)	#Do something else for another version that is unsupported as of yet
	esac
	if [ $srvSSL -lt $srvCount ]; then
		missCount=$(($srvCount - $srvSSL))
		echo "@@ ITCS104-WAS 4.1 Encryption (SSL): WARN *** $missCount WAS${VERSION} application servers do NOT have HTTPS transports. Ensure they are not serving confidential data or communicating across zone boundaries."
		warnCount=$(($warnCount+1))
	else
		echo "@@ ITCS104-WAS 4.1 Encryption (SSL): PASS *** All WAS${VERSION} application servers are using HTTPS transports."
	fi
	
	# Check Key protections
	case $PLATFORM in
		AIX) keyperms=$(perl -e '$mode=(stat("/lfs/system/tools/was/etc"))[2]; $shortmode=substr((sprintf("%o",$mode), 3, 3)); printf "%s\n", scalar($shortmode);') ;;
		Linux) keyperms=$(perl -e '$mode=(stat("/lfs/system/tools/was/etc"))[2]; $shortmode=substr((sprintf("%o",$mode), 2, 3)); printf "%s\n", scalar($shortmode);') ;;
	esac
	case $keyperms in
		750|770|700) echo "@@ ITCS104-WAS 4.1 Encryption (Keys): PASS *** Keystores are protected: ${host} : $keyperms : /lfs/system/tools/was/etc" ;;
		*) echo "@@ ITCS104-WAS 4.1 Encryption (Keys): FAIL *** Keystores are NOT protected: ${host} : $keyperms : /lfs/system/tools/was/etc"
		   failCount=$(($failCount+1))
	esac
	
	# Check that key prop/config files have encrypted passwords
	cd ${ASROOT}/properties
	grep 'Password=' soap.client.props |grep -v '{xor}' |grep -v ^#
	if [ $? -ne 1 ]; then
		echo "@@ ITCS104-WAS 4.1 Encryption (Passwords): FAIL *** WAS${VERSION} File soap.client.props contains one or more unencrypted password(s)."
		failCount=$(($failCount+1))
	else
		echo "@@ ITCS104-WAS 4.1 Encryption (Passwords): PASS *** WAS${VERSION} File soap.client.props contains encrypted password(s)."
	fi
	
	if [ $VERSION -eq 61 ]; then
		grep 'Password=' ssl.client.props |grep -v '{xor}'
		if [ $? -ne 1 ]; then
			echo "@@ ITCS104-WAS 4.1 Encryption (Passwords): FAIL *** WAS${VERSION} File ssl.client.props one or more unencrypted password(s)."
			failCount=$(($failCount+1))
		else
			echo "@@ ITCS104-WAS 4.1 Encryption (Passwords): PASS *** WAS${VERSION} File ssl.client.props contains encrypted password(s)."
		fi
	fi
	
	cd ${CFGROOT}
	grep -i 'password=' cells/*/security.xml|grep -iv 'password="{xor}'
	if [ $? -ne 1 ]; then
		echo "@@ ITCS104-WAS 4.1 Encryption (Passwords): FAIL *** WAS${VERSION} File security.xml contains one or more unencrypted password(s)."
		failCount=$(($failCount+1))
	else
		echo "@@ ITCS104-WAS 4.1 Encryption (Passwords): PASS *** WAS${VERSION} File security.xml contains encrypted password(s)."
	fi
	
	echo "@@ ---------- Checking ITCS104 WAS Section 5 ----------"
	if [[ $WASROOT == "/usr/WebSphere85/AppServer" ]]; then
		case $PLATFORM in
			AIX) perms=$(perl -e '$mode=(stat("/usr/WebSphere85/AppServer"))[2]; $octalmode=sprintf "%04o\n", $mode &07777; printf "%s\n", substr($octalmode,1,3);')
				 logperms=$(perl -e '$mode=(stat("/logs/was85"))[2]; $octalmode=sprintf "%04o\n", $mode &07777; printf "%s\n", substr($octalmode,1,3);');;
		    Linux) perms=$(perl -e '$mode=(stat("/usr/WebSphere85/AppServer"))[2]; $octalmode=sprintf "%04o\n", $mode &07777; printf "%s\n", substr($octalmode,1,3);')
               logperms=$(perl -e '$mode=(stat("/logs/was85"))[2]; $octalmode=sprintf "%04o\n", $mode &07777; printf "%s\n", substr($octalmode,1,3);');;
		esac
		logpath=/logs/was85
    elif [[ $WASROOT == "/usr/WebSphere70/AppServer" ]]; then
		case $PLATFORM in
			AIX) perms=$(perl -e '$mode=(stat("/usr/WebSphere70/AppServer"))[2]; $octalmode=sprintf "%04o\n", $mode &07777; printf "%s\n", substr($octalmode,1,3);')
				 logperms=$(perl -e '$mode=(stat("/logs/was70"))[2]; $octalmode=sprintf "%04o\n", $mode &07777; printf "%s\n", substr($octalmode,1,3);');;
	        Linux) perms=$(perl -e '$mode=(stat("/usr/WebSphere70/AppServer"))[2]; $octalmode=sprintf "%04o\n", $mode &07777; printf "%s\n", substr($octalmode,1,3);')
                logperms=$(perl -e '$mode=(stat("/logs/was70"))[2]; $octalmode=sprintf "%04o\n", $mode &07777; printf "%s\n", substr($octalmode,1,3);');;
		esac
		logpath=/logs/was70
	elif [[ $WASROOT == "/usr/WebSphere61/AppServer" ]]; then
		case $PLATFORM in
			AIX) perms=$(perl -e '$mode=(stat("/usr/WebSphere61/AppServer"))[2]; $octalmode=sprintf "%04o\n", $mode &07777; printf "%s\n", substr($octalmode,1,3);')
				 logperms=$(perl -e '$mode=(stat("/logs/was61"))[2]; $octalmode=sprintf "%04o\n", $mode &07777; printf "%s\n", substr($octalmode,1,3);');;
            Linux) perms=$(perl -e '$mode=(stat("/usr/WebSphere61/AppServer"))[2]; $octalmode=sprintf "%04o\n", $mode &07777; printf "%s\n", substr($octalmode,1,3);')
                logperms=$(perl -e '$mode=(stat("/logs/was61"))[2]; $octalmode=sprintf "%04o\n", $mode &07777; printf "%s\n", substr($octalmode,1,3);');;
		esac
		logpath=/logs/was61
	fi

    case $perms in
	     750|770|700) echo "@@ ITCS104-WAS 5.1 OS Resources (WASRoot): PASS *** WebSphere ${VERSION} directories protected: ${host} : $perms : $WASROOT" ;;
		 *) echo "@@ ITCS104-WAS 5.1 OS Resources (WASRoot): FAIL *** WebSphere ${VERSION} directories NOT protected: ${host} : $perms : $WASROOT"
		   failCount=$(($failCount+1))
	esac
	
	if [[ $securityON == "true" ]]; then
		echo "@@ ITCS104-WAS 5.1 OS Resources (AdminConsole): PASS *** WebSphere ${VERSION} admin console protected, security is enabled."
	else
		echo "@@ ITCS104-WAS 5.1 OS Resources (AdminConsole): FAIL *** WebSphere ${VERSION} admin console NOT protected, security is NOT enabled."
		failCount=$(($failCount+1))
	fi

	#check for IHS
	if [[ -e /usr/HTTPServer/version.signature ]]; then
		iVersion=`cat /usr/HTTPServer/version.signature|awk '{print $4}'`
		iDocRoot=`grep DocumentRoot /usr/HTTPServer/conf/httpd.conf`
		echo "@@ ITCS104-WAS 5.1 OS Resources (DocRoot): WARN *** IHS installed on WebSphere ${VERSION} node, check output to ensure WAS static content does not serve from IHS Document Root"
		warnCount=$(($warnCount+1))
		echo "IHS v${iVersion} -- $iDocRoot"
		echo "	`grep 'Include ' /usr/HTTPServer/conf`"
	else
		echo "@@ ITCS104-WAS 5.1 OS Resources (DocRoot): PASS *** IHS not installed."
	fi
	
	defApp=`find ${ASROOT}/installedApps/ -name 'DefaultApplication.ear'|wc -l`
	if [ $defApp -ne 0 ]; then
		echo "@@ ITCS104-WAS 5.1 OS Resources (Samples): FAIL *** Sample application (DefaultApplication) installed on WAS${VERSION}."
		failCount=$(($failCount+1))
	else
		echo "@@ ITCS104-WAS 5.1 OS Resources (Samples): PASS *** Sample application (DefaultApplication) not installed on WAS${VERSION}."
	fi
	ivtApp=`find ${ASROOT}/installedApps/ -name 'ivtApp.ear'|wc -l`
	if [ $? -ne 0 ]; then
		echo "@@ ITCS104-WAS 5.1 OS Resources (Samples): FAIL *** Sample application (ivtApp) installed on WAS${VERSION}."
		failCount=$(($failCount+1))
	else
		echo "@@ ITCS104-WAS 5.1 OS Resources (Samples): PASS *** Sample application (ivtApp) not installed on WAS${VERSION}."
	fi
	
	case $PLATFORM in
		AIX) toolperms=$(perl -e '$mode=(stat("/lfs/system/tools/was"))[2]; $shortmode=substr((sprintf("%o",$mode), 3, 3)); printf "%s\n", scalar($shortmode);') ;;
		Linux) toolperms=$(perl -e '$mode=(stat("/lfs/system/tools/was"))[2]; $shortmode=substr((sprintf("%o",$mode), 2, 3)); printf "%s\n", scalar($shortmode);') ;;
	esac
	case $toolperms in
		755|775|750|770|700)
			echo "@@ ITCS104-WAS 5.1 OS Resources (AdminTools): PASS *** WebSphere admin tools protected: ${host} : $toolperms : /lfs/system/tools/was" ;;
		*)  echo "@@ ITCS104-WAS 5.1 OS Resources (AdminTools): FAIL *** WebSphere admin tools NOT protected: ${host} : $toolperms : /lfs/system/tools/was"
		    failCount=$(($failCount+1))
	esac
	
	# Check permissions of the Backup files, only perform from DM nodes if possible.
	if [[ `echo ${ASROOT}|grep Manager` != "" ]]; then
		# Check permissions
		backupperms=$(perl -e '$mode=(stat("/fs/backups/was"))[2]; $shortmode=substr((sprintf("%o",$mode), 2, 3)); printf "%s\n", scalar($shortmode);')
		case $backupperms in
			750|770|700) echo "@@ ITCS104-WAS 5.1 OS Resources (Backups): PASS *** WebSphere backups protected: $backupperms : /fs/backups/was" ;;
			*) echo "@@ ITCS104-WAS 5.1 OS Resources (Backups): FAIL *** WebSphere backups NOT protected: $backupperms : /fs/backups/was"
			   failCount=$(($failCount+1))
		esac
	else
		echo "@@ Not a DM node, skipping Backup files permission check as they are centrally located and rsync'ed."
	fi
        # Check for general user write perms on automated scripts 
        badperm=0
        for file in $(ls /lfs/system/tools/was/setup/); do perms=`ls -l /lfs/system/tools/was/setup/$file |awk {'print $1'}`; if [ ${perms:8:1} = 'w' ]; then badperm=1; fi ; done
        if [[ $badperm == 0 ]]; then
                echo "@@ ITCS104-WAS 5.1 OS Resources (Automated Scripts): PASS *** WAS${VERSION} Automated scripts that execute with privileged authority as defined in Section 5.2 are protected from being modified by general users."
        else
                echo "@@ ITCS104-WAS 5.1 OS Resources (Automated Scripts): FAIL *** WAS${VERSION} Automated scripts that execute with privileged authority as defined in Section 5.2 are NOT protected from being modified by general users."
                failCount=$(($failCount+1))
        fi

	
	if [[ $userRoles == "true" ]]; then
		echo "@@ ITCS104-WAS 5.2 Security/Admin Authority: PASS *** WAS${VERSION} Users have been defined with security and system admin authority."
	else
		echo "@@ ITCS104-WAS 5.2 Security/Admin Authority: FAIL *** WAS${VERSION} Users have NOT been defined with security and system admin authority."
		failCount=$(($failCount+1))
	fi
	
	echo "@@ ---------- Checking ITCS104 WAS Section 6 ----------"
	cd ${CFGROOT}	
        grep 'SystemOut.log' cells/*/nodes/*/servers/*/server.xml|grep -v 'TIME'
	if [ $? -eq 0 ]; then
		echo "@@ ITCS104-WAS 6 Activity Auditing: WARN *** One or more WASservers configured without TIME based log rollover."
		warnCount=$(($warnCount+1))
	else
		echo "@@ ITCS104-WAS 6 Activity Auditing: PASS *** All WAS${VERSION} servers configured with TIME based log rollover."
	fi
	
	ls -l /etc/logrotate.d/was_logs
	if [ $? -ne 0 ]; then
		echo "@@ ITCS104-WAS 6 Activity Auditing: FAIL *** Node is missing logrotate config(s) used to prep logs for LCS pick-up and retention."
		failCount=$(($failCount+1))
	else
		echo "@@ ITCS104-WAS 6 Activity Auditing: PASS *** Node has logrotate config(s) to prep logs for LCS pick-up and retention."
	fi
	
	lcsJVM=`ls /opt/HPODS/LCS/conf/lcs_clientjvm*.conf|wc -l`
	if [ $lcsJVM -lt 1 ]; then
		echo "@@ ITCS104-WAS 6 Activity Auditing: FAIL *** Node is missing LCS client config for JVM logs."
		failCount=$(($failCount+1))
	else
		ls -l /opt/HPODS/LCS/conf/lcs_clientjvm*.conf
		echo "@@ ITCS104-WAS 6 Activity Auditing: PASS *** Node has LCS client config for JVM logs."
	fi
	
	case $logperms in
		750|770|700) echo "@@ ITCS104-WAS 6 Activity Auditing: PASS *** WebSphere ${VERSION} logs protected: ${host} : $logperms : $logpath" ;;
		*) echo "@@ ITCS104-WAS 6 Activity Auditing: FAIL *** WebSphere ${VERSION} logs NOT protected: ${host} : $logperms : $logpath"
		   failCount=$(($failCount+1))
	esac

	echo "@@ *** ITCS104 WAS sections without verification output are due to a lack of script-verifiable requirements."
	echo "@@ ========== End ITCS104 Compliance Report -- $DATE -- $host -- $ASROOT =========="
	} >> ${LOCALLOG}
	#End code block for file redirection
	echo "             Failures: $failCount"
	echo "             Warnings: $warnCount"
done
if [ $failCount -gt 0 ]; then
  echo "****************************"
  echo "Overall Status: FAILED ($failCount failure(s))" >> $LOCALLOG
else
  echo "****************************"
  echo "Overall Status: PASSED" >> $LOCALLOG
fi
chgrp eiadm $LOCALLOG
chmod 660 $LOCALLOG

if [[ -z $skipArchive ]]; then
	if [ ! -d $ARCHIVEDIR ]; then
		echo "Creating directory: $ARCHIVEDIR"
		mkdir -p $ARCHIVEDIR
		chgrp eiadm $ARCHIVEDIR
		chmod 770 $ARCHIVEDIR
	fi
	echo "Archiving $LOCALLOG to $ARCHIVELOG for audit tracking."
	echo "!!! IMPORTANT -- You MUST manually move $ARCHIVELOG to $REALARCHDIR !!!"
	cp -p $LOCALLOG $ARCHIVELOG
	cp -p $ARCHIVELOG $SCRATCHDIR
else
	echo "Not archiving $LOCALLOG for auditing."
fi
echo "ITCS104 scan complete."
