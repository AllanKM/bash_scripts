#!/usr/local/bin/perl
#*************************************************************************
# Perform healthchecking and enforcement of WebSphere ITCS104 standards.
#*************************************************************************
# Developer(s):  James Walton [jfwalton@us.ibm.com]
# Date:          08 January 2007
#*************************************************************************
use Getopt::Long;
use Sys::Hostname;
use Expect;
use Switch;
use strict;
use warnings;
use LWP::UserAgent;
use Crypt::SSLeay;

#---- DEBUG DEBUG ----
print "I am a tool currently under development -- PLEASE DON'T USE ME\n"
exit
#---- DEBUG DEBUG ----

sub usage () {
	print "Usage: was_itcs104.pl check|secure [-r WI|UD]\n";
}

#global vars/defaults
my ($argc, $enableSecurity, $CONFIG_FILE, $REGISTRY, $WASUSER, $WASDIR, $ASROOT, $WASNODE);
my (@WASDIRS, @IHSDIRS, @WASGROUPS, @ADMGROUPS, @SYSGROUPS, @USRGROUPS);
#-- Add a declaration of "boolean" variables for each ITCS104 check function
#--  true=1=pass, false=0=fail

#*****************************************************************
#  BEGIN Parsing arguments
#*****************************************************************
$argc=$#ARGV + 1;
if ($argc > 0) {
	my ($n,$action);
	for ($n=0; $n < $argc; $n++) {
		switch ($ARGV[$n]) {
			case "-r" {
				$n++;
				switch ($ARGV[$n]) {
					case ['WI','UD'] {$REGISTRY=$ARGV[$n]}
					else {
						usage();
						die "WebSphere registry provided not defined.\n";
						}
				}
			}
			case "-c" {
				$n++;
				$CONFIG_FILE=$ARGV[$n];
			}				
			case ['secure','check'] {$action=$ARGV[$n];}
			else {
				usage();
				die "Invalid argument passed as parameter.";
			}
		}
	}
	#When a registry is defined, we'll enable security during the 'secure' action.
	if ($REGISTRY)	{ $enableSecurity=1; }
	else			{ $enableSecurity=0; }
	
	#load up the config
	print "Loading configuration from ${CONFIG_FILE}... ";
	my $loadResult=loadConfig();
	if ($loadResult) {
		die $loadResult;
	}
	
	# Setup environment variables
	setupEnvVars();
	
	#perform action
	switch ($action){
		case "secure" {
			$action=secureITCS104();
			#debug
			#print "Secure!\n";
			if ($action =~ /^OK$/) {$action="Success!";}
		}
		case "check" {
			$action=checkITCS104();
			#debug
			#print "Check!\n";
			if ($action =~ /^OK$/) {$action="Success!";}
		}
		else {}
	}
} else {
	usage();
	exit 1;
}

#*****************************************************************
#  Functions
#*****************************************************************

#----- All security checks start in this function -----#
sub checkITCS104 {
	checkAdminRoles();
	checkProcessIDGroup();
	checkServerID();
	checkMQ();
	checkGlobalSecurity();
	checkJava2Security();
	checkAppServerSecurity();
	checkSSLKeystores();
	checkAuthentication();
	checkLDAPS();
	checkCORBANaming();
	checkEARWAR();
	checkSSLEncryption();
	checkLogs();
	checkInstallRoot();
	checkAdminconsole();
	checkDocumentRoot();
	checkSampleApps();
	checkAdminTools();
	checkBackups();
	checkStandardLogging();
}

#----- All security lockdowns start from this function -----#
sub secureITCS104 {
	secureAdminRoles();
	secureProcessIDGroup();
	secureServerID();
	checkMQ();
	enableSecurity();
	secureCORBANaming();
	checkEARWAR();
	secureLogRetention();
	secureWASDirectories();
	secureAdminconsole();
	secureSampleApps();
	secureBackups();
	checkStandardLogging();
}

sub loadConfig {
	if (-s $CONFIG_FILE && -f $CONFIG_FILE) {
		#read in Environment config file values
		my @configs;
		my ($entry,$junk);
		open(CONFIG,$CONFIG_FILE);
		@configs=<CONFIG>;
		foreach $entry (@configs) {
			chomp($entry);
			if ($entry =~ /^WASDIRS=/) {  # -- Load WAS Directory list
				($junk,$entry)=split(/=/,$entry);
				@WASDIRS=split(/\ /,$entry);
			} elsif ($entry =~ /^IHSDIRS=/) {  # -- Load IHS Directory list
				($junk,$entry)=split(/=/,$entry);
				@IHSDIRS=split(/\ /,$entry);
			} elsif ($entry =~ /^WASUSER=/) {  # -- Load WAS User ID
				($junk,$WASUSER)=split(/=/,$entry);
			} elsif ($entry =~ /^WASGROUPS=/) {  # -- Load WAS Group list
				($junk,$entry)=split(/=/,$entry);
				@WASGROUPS=split(/\ /,$entry);
			} elsif ($entry =~ /^ADMGROUPS=/) {  # -- Load Local OS WAS Admin Group list
				($junk,$entry)=split(/=/,$entry);
				@ADMGROUPS=split(/\ /,$entry);
			} elsif ($entry =~ /^SYSGROUPS=/) {  # -- Load Local OS System Admin Group list
				($junk,$entry)=split(/=/,$entry);
				@SYSGROUPS=split(/\ /,$entry);
			} elsif ($entry =~ /^USRGROUPS=/) {  # -- Load Local OS Users Group list
				($junk,$entry)=split(/=/,$entry);
				@USRGROUPS=split(/\ /,$entry);
			} else {}
		}
		print "OK\n";
		return 0;
	} else {
		return "ERROR: WAS Environment config file (${CONFIG_FILE}) not found, exiting.\n";
	}
}

sub setupEnvVars {
	#Set WebSphere directories
	my $numProfiles,$defScript,$DEFPROFILE,$AS_PROFILE;
	foreach $dir (@WASDIRS) {
		if ( -e $dir && -d $dir ) {
			$WASDIR=$dir;
			$ASROOT=$WASDIR;
			if ( -e "${dir}/profiles" && -d "${dir}/profiles" ) {
				$numProfiles=scalar(`ls ${dir}/profiles|wc -l`);
				if ( $numProfiles -gt 1 ) {
					#-- Currently only setup for the default profile if there are multiple
					$defScript="${WASDIR}/properties/fsdb/_was_profile_default/default.sh";
					$DEFPROFILE=`grep setup ${defScript}|awk '{split($0,pwd,"WAS_USER_SCRIPT="); print pwd[2]}'`;
					$AS_PROFILE=`echo ${DEFPROFILE}|awk '{split($0,profile,"/"); print profile[6]}'`;
				} else {
					$AS_PROFILE=`ls ${dir}/profiles`;
				}
				$ASROOT="${WASDIR}/profiles/${AS_PROFILE}";
			}
			$WASNODE=`grep WAS_NODE= ${ASROOT}/bin/setupCmdLine.sh |awk '{split($0,pwd,"WAS_NODE="); print pwd[2]}'`;
			#-- Currently will check only the first WAS instance it finds.
			#-- Change to treat multiple profiles or instances the same, overwrite @WASDIRS with instance/profile list
			#-- Same goes for $WASNODE -> @WASNODES
			break;
		}
	}
}

#*****************************************************************
# 1.1 - Userids
#--------------------------
#	* WAS Admin Roles: additional users/groups, console/wsadmin available
sub checkAdminRoles {
	my ($additionalUser, $additionalGroups, $consoleAvailable);
	#-- check that LDAP is the active security user registry
	#-- check for users/groups in the admin roles
	if ($additionalUser || $additionalGroups) {
		$adminRoles=1;
	} else {
		print "WARNING: Admin Roles - ${reason} (ITCS104 2.2.20, 1.1 UserIDs)";
		$adminRoles=0;
	}
	#-- check for active console if a dmgr node
	if ($consoleAvailable) {
		$adminRoles=1;
	} else {
		print "WARNING: Admin Roles - ${reason} (ITCS104 2.2.20, 1.1 UserIDs)";
		$adminRoles=0;
	}
}

sub secureAdminRoles {
}

#--------------------------
#	* WAS Process ID/Group: not root, not personal, must have group, limit system privs
sub checkProcessIDGroup {
	#-- Check configured RunAs user/group
	#-- Limit check to only appservers on the local node.
	@procExecList=qw(`grep execution ${ASROOT}/config/cells/*/nodes/${ASNODE}/servers/*/server.xml |sed 's/\ /\~/g'|sed 's/:~~~~/~/g'|awk '{split($0,proc,"~/"); for (x in proc) print proc[x];}'`);
	fail=-1;
	foreach $procExec (@procExecList) {
		$procName=`echo $procexec |awk '{split($0,proc,"~"); split(proc[1],name,"/"); print name[11]}')`;
		$procUser=`echo $procExec |awk '{split($0,proc," "); split (proc[5],user,"\""); print user[2]}'`;
		$procGroup=`echo $procExec |awk '{split($0,proc," "); split (proc[6],group,"\""); print group[2]}'`;
		if ( $procUser == "" || $procGroup == "" ) {
			$fail+=1;
			$failedAppServer[$fail]=$procName;
		}
	}
	
	#-- Check that user is not an LDAP ID
	#-- Check that user is not root and doesn't have excessive system privileges (system groups)
	if ( $WASUSER == "root" || $WASGROUP == "" ) {
		$wasProcessID=0;
	} else {
		$wasProcessID=1;
	}
	
		#-- Check that user is not a member of personal ID user groups (eiadm and such) 
	foreach $group (@USERGROUPS) {
		if ( $WASGROUP == $group ) {
			wasProcessId=0;
			break;
		}
	}
	
	#-- Check that user's default gid is one of the configured WAS groups (i.e. apps or mqm)
}

sub secureProcessIDGroup {
}

#--------------------------
#	* WAS Default Admin Server ID: not personal, additional users/groups defined, non-interactive logon
sub checkServerID {
	#-- Compare RunAs user and Server UserID, make sure they are different
	#-- Ensure the unique WAS security user is being used (i.e. eiteam or eiauth@events.ihost.com)
	#-- Check that other admin users/groups are defined
	#-- Check that adminconsole lockdown is in place to meet non-expiring password req's
	#-- Run an ldapsearch and check that server ID isn't a personal ID (preferredlanguage or bluepages?)
}

sub secureServerID {
}

#--------------------------
#	* General users: no check (done by applications, dev responsibility)

#--------------------------
#	* mqm/mqbrkrs groups: only if MQ or EM installed
sub checkMQ {
	#-- Check for existence of mqm and mqbrkrs groups
	#-- if found, ensure MQ is really installed (lslpp and/or rpm)
}

#*****************************************************************
# 2.0 - Authentication
#--------------------------
#	* Global Security: enabled
sub checkGlobalSecurity {
	#-- Check that security is enabled cell-wide
	#-- Verify that dmgr is running with security enabled via adminconsole html
}

#--------------------------
#	* Java 2 Security: enabled, or exemption documented for products that cannot use it
sub checkJava2Security {
	#-- Check that Java 2 security is enabled cell-wide
	#-- Check that appservers on local node have not disabled it
}

#--------------------------
#	* AppServer Security: warn if security disabled (not a violation, just a heads up)
sub checkAppServerSecurity {
	#-- Check that appservers on local node have not disabled security
	#-- Flag a warning if it is disabled, not a violation
}

#--------------------------
#	* SSL: no Dummy (default) certs/keystores
sub checkSSLKeystores {
	#-- Check that dummy keystores are not in use
	#-- Also, perform check of 4.1 Encryption - keystores are protected (no general user)
}

#--------------------------
#	* Authentication Mechanism: LTPA, no SWAM
sub checkAuthentication {
	#-- Check that LTPA is in use (SWAM is allowed with https, but for EI policy we'll flag it)
}

#--------------------------
#	* LDAP SSL: enabled
sub checkLDAPS {
	#-- Check that SSL connection is enabled for LDAP
}

sub enableSecurity {
	#Setup of full security (global, java2, SSL, LTPA, LDAPS, etc)
}

#*****************************************************************
# 3.0 - Authorization
#--------------------------
#	* CORBA Naming: EVERYONE=read|noaccess, ALL AUTHENTICATED=read
sub checkCORBANaming {
	#-- Until JACL script available to process CORBA values, checked manually.
	#-- quick 'n dirty could be (doesn't check actual permission level, but by default AllAuth would have 3 entries):
	#--    `grep AllAuthenticatedUsersExt naming-authz.xml |wc -l` == 1
	#--    `grep EveryoneExt naming-authz.xml |wc -l` <= 1
}

sub secureCORBANaming {
}

#--------------------------
#	* EAR/WAR: (application dev responsibility), ibm-application-ext.xmi and ibm-web-ext.xmi
sub checkEARWAR {
	#-- Only flag warnings, not violations
}

#*****************************************************************
# 3.2 - User Resources
#--------------------------
#	* Application developer responsibility for all requirements

#*****************************************************************
# 4.1 - Encryption
#--------------------------
#	* SSL Data Transmission: SSL v2+ and 128-bit, no automated check for the rest ()standards/procedures driven)
sub checkSSLEncryption {
	# Unlikely this would ever fail, default is v3 + securityLevel HIGH
	#-- Check that SSL keystores are configured for v2 or v3
	#-- Check that SSL keystores are set to securityLevel=HIGH (128-bit)
}

#--------------------------
#	* File/Data storage: no check (none stored on WAS boxes)

#--------------------------
#	* Protection of keystores: no general user access
#	> performed via checkSSLKeystores()

#*****************************************************************
# 5.1 - OS Resources
#--------------------------
#	* Logs: no general user access
sub checkLogs {
	#-- Ensure log access is restricted to WAS user and admin groups (no general user access)
	#-- Check that log rolling/retention is setup (for our records, just a warning)
}

sub secureLogRetention {
}

#--------------------------
#	* InstallRoot: no general user access, owner: WAS process ID, group: WAS admins
sub checkInstallRoot {
	#-- Check ownership and permissions of top level directory
	#-- Recursive search for files with general user access (find -perm -444)
}

sub secureWASDirectories {
	#Lock down InstallRoot, log directories, application config/properties, and admin tools
}

#--------------------------
#	* Secure Adminconsole: check for non-SSL ports, security enabled
sub checkAdminconsole {
	#-- Check that the adminconsole is running
	#-- Warn if non-SSL ports are found
	#-- If Global Security check failed, flag this as failed as well. 
}

sub secureAdminconsole {
}

#--------------------------
#	* DocRoot: check for IHS and warn, otherwise no check
sub checkDocumentRoot {
	#-- Update to search through the array of IHSDIRS for version.signature
	if ( -e "/usr/HTTPServer/version.signature" ) {
		print "WARNING: WAS/IHS coexistence - ensure WAS applications and IHS do not serving static content from the same DocumentRoot (ITCS104 2.2.20, 5.1 OSR, Document Root)";
		$documentRoot=0;
	} else {
		$documentRoot=1;
	}
}

#--------------------------
#	* Digital Cert Expiration Mgmt: no check (handled via process outside WebSphere)

#--------------------------
#	* Sample Apps: check no sample apps (ivtApp, DefaultApplication)
sub checkSampleApps {
	#-- Use config file array of sample app names, see if they are installed
	#-- Warn if installed
	#-- Flag if running (with note that the apps may be running temporarily for debug or install verification)
}

sub secureSampleApps {
	#Flag a warning about removing them
	#Ensure apps are stopped
}

#--------------------------
#	* Admin Tools: no access to general users, only admins (in case of passwords)
sub checkAdminTools {
	#-- Check WAS tools (/usr/WebSphere/AppServer/bin/*)
	#-- Check array of other tools directories from config file
}

#--------------------------
#	* Backup files: no general user access
sub checkBackups {
	#-- Check array of backup dirs from config file
	#-- "perms must be no greater than production files" -- i.e. no general user
}

sub secureBackups {
}

#*****************************************************************
# 7.1 - Healthchecking
#--------------------------
#	* Access/Activity logs: standard WAS logs exist
#			(<appserv>/SystemOut|Err.log, <appserv>/native_stdout|err.log)
#			(activity.log, ffdc/ contents > 0)
sub checkStandardLogging {
	#-- Make sure local appservers do not have any of the default logs disabled
}

