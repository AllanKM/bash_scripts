#!/bin/sh
#
#   Configures the TIP cell's global security configuration.     
#
#   Usage: tip_was_security_setup_v3.sh ED {70|85}  
#                      [-tippw <tip_password>]           # Supply tipadmin's password when it is not "tipadmin"
#                      [-useClientProps]                 # No userid/pw needed when it is supplied in soap.client.props
#                                                        # If tippw is supplied, it is ignored  
#                      [-projroot $PROJROOT ]            # Project root dir. ex: /opt/IBM/Netcool
#                      [-washome $WASHOME]               # WebSphere home    ex: /opt/IBM/Netcool/tip 
#                      [-user $USERID]  [-group $GROUP]  # userid and group(file system) of WAS TIP
#                      [-DKTS $FILENAME $DKTS_password]  # default key and trust store override 
#                      [-tipid NCO|TCR|TAD|TCR31]        # TIP identifier   
#         NO, NOT YET  [-ldap bluepages|EI|none]         # not yet - LDAP choice  default 'bluepages'
#                      [-tiptools $TIP_TOOLS_LOCATION]
#                      [-bypassPERMS|-bp] [- bypassSST|-bsst] [-bypassSSL|-bssl] [-bypassSEC-bsec]
#                      [-bypassUPW|-bupw]                # Bypass update of soap.client.props
#                      [-debug]
#
#          Required: 
#                 ED, 
#                 tip_password if not "tipadmin"     
#
#   If tipadmin's password is different from the default tipadmin value, 
#      1.  use -tippw to supply it  - or -. 
#      2.  use -useClientProps to indicate password is stored in soap.client.props
# 
#   Use ED for TIP. TIP support has not been extended to WI environnments.
#
#   Typical use: 
# 
#     cd    /lfs/system/tools/tip/setup
#     sudo ./tip_was_security_setup_v3.sh ED 70 TIPProfile -tippw <password> 
#     sudo ./tip_was_security_setup_v3.sh ED 85 JazzSMProfile  -debug  
#   Requiremnts:
#     EI WAS tools in /lfs/system/tools/waso
#
#   TODO:  
#    1. Fix harcoded envir  As an option perhaps, get envir from lssys     
#    2. Support the option to re-copy the key and trust store files  - low priority
#    4. Get the tip password from a tip passwd file like EI WAS does
#
#
#   Change History:
#     Steve Farrell 03-11-2008  Unspecified 
#     Lou Amodeo    03-01-2013  Add support for Websphere 8.5
#     Lou Amodeo    03-11-2013  Additional de-versioning removal  
#     E Coley       04-10-2013  Add support for TIPProfile
#                   04-18-2013  Update ILMT stores to use EI-supplied store 
#     E Coley       06-09-2013  V2 for general TIP use. Several TODO's. Support TIPProfile only.  
#     E Coley       10-03-2013  Create profile/etc symlink if jks file already in place.  
#     E Coley       10-04-2013  Allow this script to re-run without WAS userid/pw by exploiting  soap.client.props.
#     E Coley       06-06-2014  Support TCR 3.1, JazzSMProfile                           
#                   07-25-2014  Changes needed for NCO                                   
#
#    Changes to support of TIPProfile
#      Stop the server only if we started it. 
#      Use the tipadmin userid and password
#      Add options to help testing and execute by section: bypassSSL, bypassPERMS, bypassSEC, and bypassUPW 
#      Append the date to some of the file backup names
#      Add a debug option 
#      Add option to pass in the tipadmin password
#      Special processing for TIPProfile for ED authorization
#      - use TIPProfile bin directory not the app server bin.
#      - use user tipadmin instead of C-BCYD897@nomail.relay.ibm.com 
#      - add additional arguments to call to security config jython script 
#      Obtain zone from dirstore
#      Start and stop servers using profile bin directory
#

SCRIPT_VERSION=1.08a
SCRIPTNAME=$(basename $0)

TIP="y"
TIP_TOOLS=/lfs/system/tools/tip
TIPLIB=${TIP_TOOLS}/lib
TIPADMIN=tipadmin
TIPPW=tipadmin
# For capturing WAS HOME override of default
WASHOME=/usr/WebSphere70/AppServer
WASHOME_OVERRIDE="n"
PROFILE="TIPProfile"  # also support JazzSMProfile 
PROFILE_DEFAULT=TIPProfile 

PROJROOT=/usr/WebSphere70   # default 
WASLOGS=/logs/was70/TIPProfile 
TIPID=""  # NCO | TAD | TCR | TCR31    default derived from WASHOME directory
TIP_SEC_TAD4D="n"   # In addition to a primary TIPID config, perform some steps for a TAD4D config
#                     to support a dual configuration   

LDAP_TYPE="blue"   
#         none  -  LDAP not configured 
#         blue  -  bluepages as in standard EI config
#         ei    -  EI LDAP used by ITM team  
# Default user and group 
USER=webinst 
GROUP=eiadm
# Indicate if user and group supplied at runtimeto overrid edefaults
USER_OVERRIDE="n" 
GROUP_OVERRIDE="n"

# Override the EI-WAS supplied versions of the key and trust store when we must
# default key trust store
DKTS_OVERRIDE="n"    # y|n  Override to NodeDefaultTrustStore and KeyStore
DKTS_filename="-"    
DKTS_password="-"

USE_SOAP_CLIENT_PROPS="n"   # Use soap.client.props userid/pw for WAS authentication y|n 

CONTINUE_PROMPTS="y"
AUTH="ED" 
NODE=$(hostname -s)
STARTED_SERVER='n'
DATE=$(date +"%Y%m%d%H%M")
JVM_OUTPUT_DIRECTIVE=" >/dev/null"
SHOW_JVM_MSGS="n"

# Pause 
pause() {
echo "\nPausing briefy"
sleep 3
echo    
}
# Issue prompt to contunue or briefly pause
prompt_to_continue() {
  if [ $CONTINUE_PROMPTS == y ]; then
    echo "\nHit any key to continue, or cancel(CNTL-c) to quit"  
    read -r choice 
  else
    pause    
  fi
}
# Determine type of TIP (TAD, NCO, TCR, TCR31 ) based on WASHOME and PROFILE
# if -tipid argument was not supplied 
# If the dir does not contain TCR or Netcool, we assume TAD
# Input WASHOME PROFILE
# Output:TIPID    
determine_default_TIPID(){
  if [  $PROFILE == JazzSMProfile ]; then
      TIPID="TCR31"	    
  elif [ "$TIPID" == "" ]; then
    TIPID=TAD 
    was_home_is_nco=$(echo $WASHOME | tr '[:upper:]' '[:lower:]'   |  grep 'netcool' )
    if [ $? -eq 0 ]; then 
      TIPID=NCO
      return 
    fi  
    was_home_is_TCR=$(echo $WASHOME | tr '[:upper:]' '[:lower:]'   |  grep 'tcr' )
    if [ $? -eq 0 ]; then 
      TIPID=TCR
      return 
    fi
  fi    
}


# Locste a few of the arguments 
# TODO: clean this up 
args="$@"
BYPASS_SST=`echo $args | grep bypassSST | wc -l`           # Bypass server status test 
BYPASS_SSL=`echo $args | grep bypassSSL | wc -l`           # Bypass config SSL 
BYPASS_SEC=`echo $args | grep bypassSEC | wc -l`           # Bypass config security
BYPASS_UPW=`echo $args | grep bypassUPW | wc -l`           # Bypass user/pw update to properties  
BYPASS_PERMS=`echo $args | grep bypassPERMS | wc -l`
DEBUG=`echo $args | grep debug | wc -l`
CONSOLELOG=`echo $args | grep consolelog | wc -l`
if [ $DEBUG == 0 -o "$DEBUG" == "0" ]; then
  DEBUG=""  
else
  SHOW_JVM_MSGS="y"      
fi

#TODO: error if WD
case $1 in
	WI|wi)  AUTH=WI;;
	ED|ed|BP)  AUTH=ED;;
	*) echo "Error: Unrecognized user registry specified."
	exit 1
esac

HOST=`/bin/hostname -s`
FULLVERSION=${2:-70023}
VERSION=`echo $FULLVERSION | cut -c1-2`
PROFILE=$3

echo "EI Tivoli Integrated Portal $SCRIPTNAME version $SCRIPT_VERSION executing"

####################################
# Locate the other arguments
####################################
    i=0
    while [ $i -le $# ]; do
      i=$((i + 1))
      eval parm=\${$i:-}
      case "$parm" in
        -washome|-wh)
           i=$((i + 1))
           eval WASHOME=\${$i:-}
           WASHOME_OVERRIDE="y"
           ;; 
        -projroot|-pr)
           i=$((i + 1))
           eval PROJROOT=\${$i:-}
           ;; 
        -tippw)
           i=$((i + 1))
           eval TIPPW=\${$i:-}
           echo "Default TIPPW overridden"
           ;;                            
        -user)
           i=$((i + 1))
           eval USER=\${$i:-}
           USER_OVERRIDE="y" 
           ;;         
        -group)
           i=$((i + 1))
           eval GROUP=\${$i:-}
           GROUP_OVERRIDE="y"
           ;; 
        -tiptools|-tt)
           i=$((i + 1))
           eval TIP_TOOLS=\${$i:-}
           TIPLIB=${TIP_TOOLS}/lib
           ;;    
      	-logdir|waslogs)
           i=$((i + 1))
           eval WASLOGS=\${$i:-}
           ;; 
      	-DKTSreplace|-DKTS)
      	   DKTS_OVERRIDE="y"
      	   i=$((i + 1))
           eval DKTS_filename=\${$i:-}
           i=$((i + 1))
           eval DKTS_password=\${$i:-}
           ;; 
        -tipid)
           i=$((i + 1))
           eval TIPID_OVERRIDE=\${$i:-}
           TIPID_OVERRIDE=$(echo $TIPID_OVERRIDE | tr '[:lower:]' '[:upper:]')
           TO=$TIPID_OVERRIDE 
           TIPID=$TIPID_OVERRIDE
           if [ $TO == "NCO" -o $TO == "TCR" -o $TO == "TAD"  -o $TO -o "TCR31" ]; then
             OK="y"
           else
             echo "ERROR - Invalid -tipid supplied: $TIPID_OVERRIDE"
             exit1
           fi         
           ;;                    
      	-tad4d|tad4d)
           TIP_SEC_TAD4D="y"
           ;;  
        -useClientProps|-ucp|-useWASauth|-uwa)
           USE_SOAP_CLIENT_PROPS="y"
           ;;        
       	-prompts|-pr)
           CONTINUE_PROMPTS="y"
           ;;   
       	-noprompts|-nop)
           CONTINUE_PROMPTS="n"
           ;;      
        -bypassPERMS|-bp)
           BYPASS_PERMS=1
           ;;   
        -bypassSSL|-bssl)
           BYPASS_SSL=1
           ;;  
        -bypassSST|-bsst)
           BYPASS_SST=1
           ;;     
        -bypassSEC|-bsec)
           BYPASS_SEC=1
           ;;
        -bypassUPW|-bupw)
           BYPASS_UPW=1
           ;;
       	-xbp)                    
           BYPASS_PERMS=0    
           ;;   
        -xbssl)
           BYPASS_SSL=0
           ;;  
        -xbsst)
           BYPASS_SST=0
           ;;     
        -xbsec)
           BYPASS_SEC=0
           ;;
        -xbupw)
           BYPASS_UPW=0
           ;;                          
        *)
           ;;
           
      esac
    done

echo "####################################################################"
echo "#                                                                  #"   
echo "# EI Tivoli Integrated Portal (TIP) / JazzSM  WAS security config  #"   
echo "#                                                                  #"
echo "####################################################################"
echo  
########################################################
# Examine the input and draw conclusions about defaults 
########################################################
  #1. WAS home and profile 
  if [ $WASHOME_OVERRIDE == "n" ]; then
    WAS_PROFILE_HOME="/usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}"
    WAS_HOME=/usr/WebSphere${VERSION}/AppServer
  else
    WAS_PROFILE_HOME="${WASHOME}/profiles/${PROFILE}"
    WAS_HOME=${WASHOME}
  fi
  #2 Profile JazzSMProfile 
  if [ $PROFILE == JazzSMProfile ]; then
      WASLOGS=/logs/was${VERSION}/JazzSMProfile
      PROJROOT=/usr/WebSphere85
  fi	
  if [ ! -e $WAS_PROFILE_HOME ]; then
     echo "ERROR: WebSphere directory invalid: $WAS_PROFILE_HOME...terminating"
    exit 1
  fi        
  #2. Type of TIP sing WASHOME  ( TCR, TCR31, TAD, NCO )
  determine_default_TIPID
  
  #3. Type of LDAP to configure if any . Default is blue(pages)  
  if   [ $TIPID == "NCO" ]; then
         LDAP_TYPE="none"

  elif [ $TIPID == "TCR" ]; then  
         LDAP_TYPE="ei"   
         if [ $USER_OVERRIDE == "n" ] ; then
             USER=webinst   
         fi  
         if [ $GROUP_OVERRIDE == "n" ] ; then  
             GROUP=itmusers    
         fi                
  elif [ $TIPID == "TCR31" ]; then  
         LDAP_TYPE="ei"   
         if [ $USER_OVERRIDE == "n" ] ; then
             USER=webinst   
         fi  
         if [ $GROUP_OVERRIDE == "n" ] ; then  
             GROUP=eiadm    
         fi                
  fi  
  
  #4
  if [ $SHOW_JVM_MSGS == "y" ]; then
      JVM_OUTPUT_DIRECTIVE=""  
  fi   
 
# Set Globals
case $VERSION in 
	61*|70*|85*)	
	  # Have revised PROFILE code 
	  # If no override in arguments use EI defaults :
		if [ $WASHOME_OVERRIDE == "n" ]; then
		  WAS_PROFILE_HOME="/usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}"
		  WAS_HOME=/usr/WebSphere${VERSION}/AppServer
		else
		  WAS_PROFILE_HOME="${WASHOME}/profiles/${PROFILE}"
		  WAS_HOME=${WASHOME}
		fi      
	  ADMINSERVER=server1
 		SERVERSTATUS="serverStatus.sh $ADMINSERVER"
 		STARTSERVER="startServer.sh $ADMINSERVER"
 		STOPSERVER="stopServer.sh $ADMINSERVER"	
		[ -n "$DEBUG" ] && echo "Using Profile directory:  $WAS_PROFILE_HOME"
		;;
	*)
		echo "Not configured for version $VERSION"
		echo "exiting...."
		exit 1;
esac

# TIP
# If requested to use WAS security credentials stored in soap.client.props, do so 
if [ $USE_SOAP_CLIENT_PROPS == "n" ]; then
    SERVERSTATUS="$SERVERSTATUS -username $TIPADMIN -password $TIPPW"
    STOPSERVER="$STOPSERVER -username $TIPADMIN -password $TIPPW"  
else
    SERVERSTATUS="$SERVERSTATUS"
    STOPSERVER="$STOPSERVER"  
fi          

WAS_TOOLS=/lfs/system/tools/was
WASLIB=${WAS_TOOLS}/lib
WAS_PASSWD=${WAS_TOOLS}/etc/was_passwd
WSADMIN=${WAS_HOME}/bin/wsadmin.sh

# TIP 
if [ $PROFILE == TIPProfile -o $PROFILE == JazzSMProfile ]; then
    WSADMIN=${WAS_PROFILE_HOME}/bin/wsadmin.sh      
    [ -n "$DEBUG" ] && echo "WSADMIN changed to $WSADMIN"
fi  
 
[ -n "$DEBUG" ] && echo PROFILE:        $PROFILE 
[ -n "$DEBUG" ] && echo WAS_HOME:       $WAS_HOME
[ -n "$DEBUG" ] && echo WAS_PROFILE_HOME: $WAS_PROFILE_HOME
[ -n "$DEBUG" ] && echo WSADMIN:        $WSADMIN
[ -n "$DEBUG" ] && echo TIPID:          "$TIPID" 
[ -n "$DEBUG" ] && echo TIP_SEC_TAD4D:  $TIP_SEC_TAD4D 
[ -n "$DEBUG" ] && echo LDAP_TYPE:      $LDAP_TYPE 
[ -n "$DEBUG" ] && echo USE_SOAP_PROPS: $USE_SOAP_CLIENT_PROPS
[ -n "$DEBUG" ] && echo ADMINSERVER:    $ADMINSERVER
[ -n "$DEBUG" ] && echo SERVERSTATUS:   $SERVERSTATUS
[ -n "$DEBUG" ] && echo STARTSERVER:    $STARTSERVER
[ -n "$DEBUG" ] && echo STOPSERVER:     $STOPSERVER
[ -n "$DEBUG" ] && echo DKTS_OVERRIDE:  $DKTS_OVERRIDE $DKTS_filename $DKTS_password

 
# Obtain SEC_USER
case $AUTH in
	WI)  echo "Unexpected AUTH value for TIP environment"
	     exit 1
	     #SEC_USER=eiauth@events.ihost.com 
	     ;;
  ED) 
	    SEC_USER=tipadmin    
	    [ -n "$DEBUG" ] && echo "SEC_USER: $SEC_USER" 
	    ;;
esac
REQTIMEOUT=6000

#
# Confirm input before continuing 
# ===============================
#
  echo 
  echo "***************"
  echo "Confirm input: "
  echo "***************"
  echo "..TIP identifier:           $TIPID" 
  if  [ "$TIPID" != "TAD" ]; then 
    echo "..plus TAD4D                $TIP_SEC_TAD4D"
  fi
  echo "..WebSphere home(-washome): $WAS_HOME"    
  echo "..Project root(-projroot):  $PROJROOT" 
  echo "..Profile name:             $PROFILE" 
  echo "..WAS profile home:         $WAS_PROFILE_HOME"   
  echo "..User(-user):              $USER" 
  echo "..Group(-group):            $GROUP"
  echo "..Log directory(-logdir):   $WASLOGS"
  if [ $USE_SOAP_CLIENT_PROPS == "n" ]; then
      echo "..User for wsadmin calls:   $SEC_USER" 
      echo "..PW for wsadmin calls:     $TIPPW" 
  else
      echo "..Use user/pw in WAS props: $USE_SOAP_CLIENT_PROPS"             
  fi  
  echo "..TIP tools directory:      $TIP_TOOLS"
  echo "..Default key-trust store override: $DKTS_OVERRIDE"  
  if [ $DKTS_OVERRIDE == "y" ]; then
    echo "..   filename/pw:           $DKTS_filename/$DKTS_password"
  fi
  echo "..LDAP type:                $LDAP_TYPE" 
  echo "..BYPASS_PERMS:             $BYPASS_PERMS"
  echo "..BYPASS_SSL(ssl config):   $BYPASS_SSL"
  echo "..BYPASS_SST(server status):$BYPASS_SST"
  echo "..BYPASS_SEC(sec config):   $BYPASS_SEC"
  echo "..BYPASS_UPW(u/pw props):   $BYPASS_UPW"
  echo "..Continuation prompts:     $CONTINUE_PROMPTS"
  echo "..DEBUG:                    $DEBUG"
  echo "..Show JVM mgs:             $SHOW_JVM_MSGS" 
  echo  
  echo "Hit enter to continue, or cancel(CNTL-c) to quit"  
  read -r choice  

# Check for user
if [[ -z `id $USER` ]]; then
  echo "Error: user $USER does not exist."
  exit 1
fi

######################################
# Update WAS ownership and permissions 
######################################
if [ $BYPASS_PERMS == "0" ]; then
	  echo "***"
	  echo "About to update WAS owner/perms at $WASLOC"
	  echo "***"
	  prompt_to_continue
	  
    if [ $PROFILE == 	JazzSMProfile ]; then
      PERMS_CMD="/projects/jazz/sbin/jazz_perms.sh"
      echo "Updating WAS and JazzSM owner and permissions using jazz_perms.sh"  
    else 	  	
  	
      PERMS_CMD="$TIP_TOOLS/setup/tip_perms.sh -projroot $PROJROOT -washome $WAS_HOME -user $USER -group $GROUP -logdir $WASLOGS" 
      echo "Updating WAS owner and permissions using tip_perms.sh"  
    fi
    echo "..using $PERMS_CMD"
    #$TIP_TOOLS/setup/tip_perms.sh -projroot $PROJROOT -washome $WAS_HOME -user $USER -group $GROUP -logdir $logdir
    $PERMS_CMD
    if [ $? -ne 0 ]; then
        echo "ERROR Update PWNER/perms failed...terminating"
        exit 	
    fi    
    echo "Updating WAS owner and permissions ...complete" 
else
    echo "***"
    echo "Updating owner/permissions bypassed by request\n" 
    echo "***"
fi
prompt_to_continue

#######################
# Keystore work 
#######################
# Determine Zone from lssys for TIP
echo "***"
echo "Execute keystore lookups"
echo "***"
echo "Do zone lookup using lssys"
EIREALM=$(lssys $NODE | grep realm | grep -v authrealm | cut -d'=' -f 2 )    
zone=$(echo $EIREALM | cut -d'.' -f 1 )
[ -n "$DEBUG" ] && echo zone: $zone

if [[ $zone == "z" ]]; then
	#Force ECC nodes to BZ
	echo "Forcing zone b until script can be changed" 
	zone="b"
elif [[ $zone != [bgy] ]]; then
   echo Attempting configuration using /etc/resolve.conf
   set -- $(grep search /etc/resolv.conf)
   while [[ "$1" != "" ]]; do
      if [[ "$1" = [bgy].*.p?.event.ibm.com ]]; then
         zone=`echo "$1" | cut -d. -f1`
      fi
      shift
   done
   if [[ "$zone" == "" ]]; then
      print -u2 -- "#### Unable to determine zone from /etc/resolv.conf"
      exit 1
   fi
fi

# Determine the keystore name to use in this config run
echo "***"
echo "Determine the keystore name to use in this config run"
echo "***"
symlink=""
keyStore=""
keyloc=""
# If no default overrides
if [ $DKTS_OVERRIDE == "n" ]; then
  # If we get here then $zone contains b,g or y
  # Standard EI keystore name and location
  keyloc=$WAS_TOOLS/etc
  symlink=ei_${zone}z_was.jks
  [ -n "$DEBUG" ] && echo symlink=$symlink

  # now check if the is a pre, cdt or prd setup
  ENV=$(lssys $NODE | grep hostenv | cut -d'=' -f 2 )     
  envir=$(echo $ENV | tr '[:upper:]' '[:lower:]')
  [ -n "$DEBUG" ] && echo "ENV=$ENV, envir: $envir"
  case $envir in
	  prd|p) # production environment symlink and key file are the same
		  keyStore=$symlink
		  ;;
	  pre) # preproduction environment, keyfile name is different depending on zone
		  if [[ "$zone" == "y" ]]; then
			  keyStore=ei_${zone}z_was_test.jks
		  elif [[ "$zone" == "g" ]]; then
			  keyStore=ei_${zone}z_was_stage.jks
		  else  
			  keyStore=$symlink
		  fi
		  ;;
	  cdt) # cdt environment, keyfile name is different depending on zone
		  if [[ "$zone" == "y" ]]; then
		    	keyStore=ei_${zone}z_was_test.jks
		  elif [[ "$zone" == "g" ]]; then
		      keyStore=ei_${zone}z_was_stage.jks
		  else  
		  	keyStore=$symlink
		  fi
		  ;;
	  *) echo "Assuming production environment"
		  keyStore=$symlink
		  ;;
  esac
  [ -n "$DEBUG" ] && echo "After envir test, standard EI keyStore=$keyStore"
  
else
  # User has supplied an override to keystore 
  # The jks file needs to be in the TIP tools etc directory  
  echo "Override requested to NodeDefaultTrustStore and NodeDefaultKeyStore: $DKTS_filename" 
  echo "   located at $TIP_TOOLS/etc"
  keyloc=$TIP_TOOLS/etc
  file_path=$keyloc/$DKTS_filename
  keyStore=$DKTS_filename     # keystore name
  symlink=$keyStore
  if [ ! -e $file_path ]; then
    echo "*ERROR*  Override to KeyStore does not exist at: $file_loc" 
    exit 1  
  else
    echo "Override to EI-WAS NodeDefaultTrust-Key Stores: $DKTS_filename"  
    [ -n "$DEBUG" ] && echo "After override, keyStore=$keyStore" 
  fi   
fi     

echo "*"
echo "Examine keystore symlinks"
echo "*"

# Now verify that keystore exists and copy to the WAS directory
# Create symlink(s) in the profile's etc directory  
# Input:  $symlink  $keyStore $keyloc 
# Output: symlink(s) in $PROFILE/etc 
# TODO? - support option to rename keystore if found and re-copy  
# If already there, this is config rerun. The key store may have been updated about trusted certs. 
if [[ -e $WAS_HOME/etc/$keyStore ]]; then
	echo "Found keystore in $WAS_HOME/etc/$keyStore  leaving it as is because it may have trust updates"
	echo "Found keystore in $WAS_HOME/etc/$keyStore  - creating a backup" 
	cp -p $WAS_HOME/etc/$keyStore $WAS_HOME/etc/$keyStore.$DATE
	if [ -L $WAS_HOME/profiles/$PROFILE/etc/$keyStore ]; then
	    echo "Found keystore symlink at $WAS_HOME/profiles/$PROFILE/etc/$keyStore"
	    echo " leaving it in place"
	else
	    echo "Creating the symlink $WAS_HOME/profiles/$PROFILE/etc/$keyStore"
	    echo "   to $WAS_HOME/etc/$keyStore "               
	    ln -fs $WAS_HOME/etc/$keyStore $WAS_HOME/profiles/$PROFILE/etc/$keyStore
	fi   
	#echo "  Also leave the symlink in $WAS_HOME/profiles/$PROFILE/etc"
elif [[ -e $keyloc/$keyStore ]]; then
 	echo "Copying keystore $keyStore from $keyloc...to WAS_HOME/etc"
	echo "cp $keyloc/$keyStore $WAS_HOME/etc/$keyStore"
	cp       $keyloc/$keyStore $WAS_HOME/etc/$keyStore
	chown $USER.$GROUP $WAS_HOME/etc/$keyStore
	chmod 660 $WAS_HOME/etc/$keyStore
	echo "Linking $keyStore to profile/$PROFILE/etc  "
 	echo "   $symlink and $keyStore"   
  ln -fs $WAS_HOME/etc/$keyStore $WAS_HOME/profiles/$PROFILE/etc/$symlink
	if [ $symlink != $keyStore ]; then 
	    echo " also linking $WAS_HOME/profiles/$PROFILE/etc/$keyStore to $WAS_HOME/etc/$keyStore"  
	    ln -fs $WAS_HOME/etc/$keyStore $WAS_HOME/profiles/$PROFILE/etc/$keyStore
	fi    
else
	echo "Error: Keystore $keyStore not found on node at $keyloc"
	exit 1
fi
# Create a symlink to the keystore if required  
if [[ "$keyStore" != "$symlink" ]] ; then
    echo "Creating symlink to the keystore as required: $WAS_HOME/etc/$symlink"
    ln -fs $WAS_HOME/etc/$keyStore $WAS_HOME/etc/$symlink
fi

prompt_to_continue
  
# Grab the security user and keystore passwords from the EI WAS locations 
# Input: WAS_PASSWD
# Output: ldapPass, bindPass 
echo "***"
echo "Locating the security user and keystore passwords from the EI WAS locations"
echo "***  "
[ -n "$DEBUG" ] && echo WAS_PASSWD: $WAS_PASSWD
DEC_PROF_NAME=""   # If TIPProfile, thi svariable not needed
#if [ $PROFILE == JazzSMProfile ]; then
#    DEC_PROF_NAME=JazzSMProfile    	
#fi	
if [ -e $WAS_PASSWD ]; then
	case $AUTH in
		WI) encrypted_passwd=$(grep global_security $WAS_PASSWD |awk '{split($0,pwd,"global_security="); print pwd[2]}' |sed -e 's/\\//g') ;;
		ED) encrypted_passwd=$(grep ed_ldap $WAS_PASSWD |awk '{split($0,pwd,"ed_ldap="); print pwd[2]}' |sed -e 's/\\//g') ;;
	esac
	
	echo "call decoder on encrypted_passwd=$encrypted_passwd"
	passwd_string="$TIP_TOOLS/bin/PasswordDecoder.sh $encrypted_passwd $WAS_HOME $PROFILE"
	echo "passwd_string=$passwd_string"
	
	ldapPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
	bindPass=$ldapPass
	if [ "$zone" == "b" ]; then
		encrypted_passwd=$(grep ssl_bz_keystore $WAS_PASSWD |awk '{split($0,pwd,"ssl_bz_keystore="); print pwd[2]}' |sed -e 's/\\//g')
	else
		encrypted_passwd=$(grep ssl_keystore $WAS_PASSWD |awk '{split($0,pwd,"ssl_keystore="); print pwd[2]}' |sed -e 's/\\//g')
	fi
	passwd_string=$($TIP_TOOLS/bin/PasswordDecoder.sh $encrypted_passwd $WAS_HOME $PROFILE)
	[ -n "$DEBUG" ] && echo "encrypted_passwd: $encrypted_passwd"
	[ -n "$DEBUG" ] && echo "LDAP  ldapPass=$ldapPass -  bindPass=$bindPass "
	[ -n "$DEBUG" ] && echo "decoded passwd_string:  $passwd_string"
	echo "Found and decoded security passwords"
	keyPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
	#keyPass61=$(echo $encrypted_passwd ||sed -e "s/\\\//g")      # encoded version 
	keyPassEnc=$(echo $encrypted_passwd ||sed -e "s/\\\//g")      # encoded version 
	[ -n "$DEBUG" ] &&  echo " keyPass=$keyPass, keyPassEnc=$keyPassEnc"
	echo "Found and decoded keystore password"
else
	echo "Error: WebSphere password setup file not found."
	exit 1
fi

# 06-2013 For NCO support override of the EI-WAS default keystore
# Determine: keyStore, keyPass, keyPassEnc
if [ $DKTS_OVERRIDE == "y" ]; then
   echo "Default keystore override detected"  
   keyStore=$DKTS_filename  
   if [ $DKTS_password == "pw.ini" ]; then
   	   # Locate in etc/password.ini
   	   echo "  Looking in encoded pw in $TIP_TOOLS/etc/passwds.ini" 
       keyPassEnc=$(grep $keyStore $TIP_TOOLS/etc/passwds.ini | cut -d':' -f2)
       if [ "$keyPassEnc" == "" ]; then echo "ksystore name /pw not found..terminating"; exit 1; fi
       keyPass=$($TIP_TOOLS/bin/Passwd_wrapper.sh decode  $keyPassEnc  $WAS_HOME)
   else
       pw_rept_string=$($TIP_TOOLS/bin/PasswordEncoder.sh $DKTS_password $WAS_HOME $PROFILE )
       keyPass=$DKTS_password
       keyPassEnc=$(echo $pw_rept_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
   fi
   
   [ -n "$DEBUG" ] && echo "  keyStore=$keyStore, keyPass=$keyPass, keyPassEnc=$keyPassEnc" 
   echo "The EI default keystore name and password have been overriden"  
   echo "  keyStore=$keyStore, keyPass=$keyPass, keyPassEnc=$keyPassEnc"    
fi  

prompt_to_continue

#
# Prepare for wsadmin work
#

echo "***"
echo "Prepare for wsadmin work"
echo "***"

# Check for wsadmin.sh (that WAS installed) and execute
if [[ -x $WSADMIN ]]; then
	WAS_NODE=$(grep WAS_NODE= $WAS_PROFILE_HOME/bin/setupCmdLine.sh |awk '{split($0,pwd,"WAS_NODE="); print pwd[2]}')
	WAS_CELL=$(grep WAS_CELL= $WAS_PROFILE_HOME/bin/setupCmdLine.sh |awk '{split($0,pwd,"WAS_CELL="); print pwd[2]}')
	[ -n "$DEBUG" ] && echo "WAS_NODE: $WAS_NODE"
	WAS_PROPS=$WAS_PROFILE_HOME/properties
	echo "Found wsadmin.sh - searching for admin scripts..."
	
	if [[ -e $WASLIB/sslConfig.py && -e $TIPLIB/tip_was_securityConfig.py ]];  then
		LOGGING="-tracefile /logs/was${VERSION}/${PROFILE}/wsadmin.sslConfig.traceout"
		if [ CONSOLELOG == "1" ]; then
	      LOGGING=" "      
	  fi  
		
		###########################################################
	  # SSL config
	  # 04-2013 - tip_sslConfig.py allows you to specify app specific key/trust store names.
	  # 06-2013 - support an override to standard EI-WAS supplied stores for NodeDefaultKeyStore and NodeDefaultTrustStore
	  #               $keyStore  $keyPass
	  # We pass the unencoded keystore password 
	  ###########################################################	
	  if [ $BYPASS_SSL == 0 ]; then bypassed="not bypassed"	
	  else bypassed="bypassed"; fi
		
	  echo "***"
	  echo "Execute SSL config...SSL config updates $bypassed"
	  prompt_to_continue
	  echo "***"
	  [  -n "$DEBUG" ] && echo "Call sslConfig: $WAS_NODE, keystore: $keyStore,  keyPass= $keyPass"
	  SSL_CONFIG_SUCCESS=n
	  SSL_SCRIPT="$WASLIB/sslConfig.py"
	  SSL_TIP_SPECIAL_SCRIPT="$TIPLIB/tip_sslConfig.py"
	  CONNARGS="-conntype NONE"
	  # Standard EI ssl config call. Note - Every TIP needs this work done also 
	  SSL_PY_ARGS="-node $WAS_NODE -keystore $keyStore -keypassword $keyPass -version $VERSION"
		ADDARGS=""
		WSADMIN_SSL_CMD="$WSADMIN $CONNARGS -lang jython $LOGGING -f $SEC_SCRIPT $SSL_PY_ARGS"   
		[ -n "$DEBUG" ] && ADDARGS="$ADDARGS -debug"
		
		# This tad4d_installed flag  appears to be ignored
		tad4d_installed="0"
		if [ $PROFILE == TIPProfile -o $PROFILE == JazzSMProfile  ]; then
		    CONNARGS="-conntype NONE -user $TIPADMIN -password $TIPPW"  
        if [ $USE_SOAP_CLIENT_PROPS == "y" ]; then
            CONNARGS="-conntype NONE "     
        fi
		    lmt=$(ls /opt/IBM/LMT* > /dev/null 2>&1 )
	      if [ $? -eq 0 ]; then 
            tad4d_installed="1"
        fi
        tad4d=$(ls /opt/IBM/TAD4D* > /dev/null 2>&1)  
        if [ $? -eq 0 ]; then 
            tad4d_installed="1"
        fi
        
        SSL_TIP_LMT_PY_ARGS="-node $WAS_NODE -ks ILMTkeystore -ts ILMTtruststore -keystore $keyStore -keypassword $keyPass -version $VERSION"
        WSADMIN_TIP_SPECIAL_SSL_CMD="$WSADMIN $CONNARGS -lang jython $LOGGING -f $SSL_TIP_SPECIAL_SCRIPT $SSL_TIP_LMT_PY_ARGS $ADDARGS"
	  fi 
	    
  	echo	
  	echo "************************************"
	  echo "Call to wsdamin sslConfig scripts .." 
	  echo "************************************"
	  # Example  /opt/IBM/Netcool/tip/profiles/TIPProfile/bin/wsadmin.sh -lang jython -conntype NONE 
	  #       -tracefile /logs/was70/TIPProfile/wsadmin.sslConfig.traceout -f /lfs/system/tools/was/lib/sslConfig.py 
	  #       -node TIPNode -keystore z10031_netcool.jks -keypassword pw -version 70 
	  WSADMIN_SSL_CMD="$WSADMIN -lang jython -conntype NONE $LOGGING -f $WASLIB/sslConfig.py -node $WAS_NODE -keystore $keyStore -keypassword $keyPass -version $VERSION" 
		[ -n "$DEBUG" ] && echo "WAS command for ssl config: "
    [ -n "$DEBUG" ] && echo "  WSADMIN_SSL_CMD=\"${WSADMIN_SSL_CMD}\""
	  
	  # The wsadmin scripts should be smart enough to determine if LMT store are defined and if so, configure them.
	  # As of 06-2013, they are not.   
	  if [ $BYPASS_SSL == 0 ]; then  
	      # Part 1:
	      # ------
	      SECURITY_XML=$WAS_PROFILE_HOME/config/cells/$WAS_CELL/security.xml
	      echo "Backing up $SECURITY_XML to $SECURITY_XML.$DATE"
	      cp -p $SECURITY_XML  $SECURITY_XML.$DATE
	      if [[ $? -ne 0 ]]; then
	          echo " backup of security.xml failed... terminating"
	          exit 1 	
	      fi	
	       
	      echo "Call to wsdamin sslConfig.py for standard EI ssl config...." 
	      # expect to see if successful
	      #      Return code: 0
        #      ..result:  Success! Saving configuration...

	      result=`su - $USER -c "$WSADMIN_SSL_CMD | grep -v '^WASX'"`
	      ssl_rc=$?
	      ssl_success=$(echo $result | grep Success)
	      echo "  Return code: $ssl_rc "   
		    echo "..result: "  $result
		    # if [ $result -ne 0 ]; then
		    #     echo "ERROR: call to $WASLIB/sslConfig.py failed"	
		    # fi
		    if [ $ssl_rc -eq 0 ]; then
		        if  [ "$ssl_success" != "" ]; then
		            SSL_CONFIG_SUCCESS=y
		            echo "   Standard EI ssl config considered to be successful "
		        else    
		            echo "   Standard EI ssl config considered failed - No \"success\" message returned"           
		        fi  
		    else
		        echo "   Standard EI ssl config considered failed - ssl_rc=$ssl_rc"            
		    fi    	
		    
		    # Part 2:  
		    # ------
		    # At some point, this call likely will support other uses in addition to TAD4D. 
		    if [ $TIPID == "TAD" -o $TIP_SEC_TAD4D == "y" ]; then
		        # At present, tip_sslConfig.py needed only if this config supports TAD4D 
		        echo "Call to wsdamin tip_sslConfig.py for special TIP LMT EI ssl config...." 
		        [ -n "$DEBUG" ] && echo "WAS command for 2nd ssl config:"
            [ -n "$DEBUG" ] && echo "  WSADMIN_TIP_SPECIAL_SSL_CMD=$WSADMIN_TIP_SPECIAL_SSL_CMD"
		        #result=`su - $USER -c "$WSADMIN_TIP_SPECIAL_SSL_CMD | grep -v '^WASX'"`
		        #echo "  Return code: $? "   
		        #echo "..result: "  $result
		        # This style displays the jyhton script outpur messages in a more readable format
		        # until we can translate and display $results better.    
		        su - $USER -c "$WSADMIN_TIP_SPECIAL_SSL_CMD | grep -v '^WASX'" $JVM_OUTPUT_DIRECTIVE
		        echo "  Return code: $? "   
		        echo "Call to wsdamin tip_sslConfig.py for special TIP LMT EI ssl config....complete" 
  	        echo 
	      fi  
		else
        echo SSL config bypassed by request
    fi       
  	echo "Call to wsdamin sslConfig.py....complete" 
  	
		prompt_to_continue

		###################################
		#
		# Start server if it's not running
		# 
		###################################
		if [ $BYPASS_SST == 0 ]; then bypassed="not bypassed"	
	  else bypassed="bypassed"; fi

	 	echo "***************************************************************"
		echo "Checking status of $ADMINSERVER ...status and start $bypassed "
		echo "If this hangs, there may be a prompt to accept the certificate."
		echo "To find out, run with -debug, then execute STATUS_CMD  "
		echo "****************************************************************"
		prompt_to_continue
		
		# Typical response if server is running
		#   ADMU0116I: Tool information is being logged in file
    #       /opt/IBM/TCR1/tip/profiles/TIPProfile/logs/server1/serverStatus.log
    #   ADMU0128I: Starting tool with the TIPProfile profile
    #   ADMU0500I: Retrieving server status for server1
    #   ADMU0508I: The Application Server "server1" is STARTED
    # In WAS 8.5
    #   ADMU0116I: Tool information is being logged in file
    #       /usr/WebSphere85/AppServer/profiles/JazzSMProfile/logs/server1/serverStatus.log
    #   ADMU0128I: Starting tool with the JazzSMProfile profile
    #   ADMU0500I: Retrieving server status for server1
    #   ADMU0508I: The Application Server "server1" is STARTED

    # If no server exists
    #   ADMU0522E: No server by this name in the configuration: server11
  
    
    # If not running...
    #   < fill this in>
   
    STATUS_CMD="$WAS_PROFILE_HOME/bin/$SERVERSTATUS"
    [ -n "$DEBUG" ] && echo "STATUS_CMD=\"$STATUS_CMD\""
    [ -n "$DEBUG" ] && echo "USER=$USER" 
    if [ $BYPASS_SST == 0 ]; then 
      serverStatus=$(su - $USER -c "$STATUS_CMD")
      # Run server status command
      noServer=$(echo $serverStatus | tail -1 | grep ADMU0522E)   # ADMU0522E is "no server" message  
      [ -n "$DEBUG" ] && echo "  ..serverStatus=$serverStatus"
      [ -n "$DEBUG" ] && echo "  ..noServer=$noServer"
      adminStatusSTARTED=""
   
      if [[ -z $serverStatus ]]; then
        echo "Status command problem..no output returned, so we take no action" 
      else  
      	# If server name valid ?
      	# if not 
     		if [[ -z $noServer ]]; then    # if not null.. then we got status line output       
         	# Is the server started ? 
          adminStatusSTARTED=$(echo $serverStatus | tail -1 | grep STARTED)
         	# TODO improve this ? 
         	[ -n "$DEBUG" ] && echo "..for started status adminStatusSTARTED: $adminStatusSTARTED"
		  	  #fi               
      	
      		# If a valid server and not started, start it  
		  		if [[ -z $noServer && -z $adminStatusSTARTED ]]; then
		     		 # Issue startServer server1 command 
		      	 echo Issuing start server: $WAS_PROFILE_HOME/bin/$STARTSERVER
		     		 # TIP result=`su - $USER -c "$WAS_HOME/bin/$STARTSERVER"`
		      	 result=`su - $USER -c "$WAS_PROFILE_HOME/bin/$STARTSERVER"`
		      	 [ -n "$DEBUG" ] && echo "..From startServer:\n $result"
		      	 # This status should be checked.. Sometimes the start fails   
		      	 STARTED_SERVER='y'
		  		elif
		     		[[ -z $noServer ]]; then
		        		echo "..Server already running"
	    		fi 
	    	fi	
	    fi		          
      echo "Checking status of server ...complete"
    else
      echo "Server status and start server bypassed by request"
    fi
    
    prompt_to_continue
    
    ##########################################  
    # Security config   Assume  TIPProfile	
    # Q Why are keystore passwords passed ? 
    ##########################################
    if [[ -z $noServer ]]; then
    	if [ $BYPASS_SEC == 0 ]; then bypassed="not bypassed"	
      else bypassed="bypassed"; fi
      
      echo "********************************************"
		  echo "Checking security configuration.."
      echo "         security call to be: $bypassed"
		  echo "********************************************"
       if [ $TIPID != "TAD" -a $TIP_SEC_TAD4D == "y" ]; then
           TAD4D_ARG=" -tad4d "
       else
           TAD4D_ARG=""
       fi         
       ADDARGS="-standalone -keypassword $keyPass -tipid $TIPID $TAD4D_ARG "
       LOGGING="-tracefile /logs/was${VERSION}/${PROFILE}/wsadmin.securityConfig.traceout"
       [ -n "$DEBUG" ] && ADDARGS="$ADDARGS -debug"
   	   [ -n "$DEBUG" ] && echo  ldapPass=$ldapPass bindPass=$bindPass  keyPass=$keyPass
		   [ -n "$DEBUG" ] && echo  ADDARGS $ADDARGS
		   if [ CONSOLELOG == "1" ]; then 
           LOGGING=""      
		   fi
		   # In TIPProfile and JazzSMProfile, we need to specify connect args for a running
		   #  WAS(standalone) on this host and assuming that the userid/pw may not in soap.client.props 
		   CONNARGS=""
		   CONNARGS="-conntype SOAP -user $TIPADMIN -password $TIPPW" 
       if [ $USE_SOAP_CLIENT_PROPS == "y" ]; then
            CONNARGS="-conntype NONE "     
       fi 
		   [ -n "$DEBUG" ] && echo "CONNARGS: $CONNARGS"
			   
		   # Specify the security script to use
		   # TODO:  support debug argument
		   SEC_SCRIPT="$TIPLIB/tip_was_securityConfig_v2.py"
	     if [ $PROFILE == JazzSMProfile ]; then
	         SEC_SCRIPT="$TIPLIB/tip_was_securityConfig_v3.py"	   
	     fi
	
		   SEC_ARGS="-$AUTH -ldappassword $ldapPass -bindpassword $bindPass $ADDARGS"
		   WSADMIN_SECURITY_CMD="$WSADMIN $CONNARGS -lang jython $LOGGING -f $SEC_SCRIPT $SEC_ARGS"
		   [ -n "$DEBUG" ] && echo "WAS command for security config: "
		   [ -n "$DEBUG" ] && echo "  WSADMIN_SECURITY_CMD=\"${WSADMIN_SECURITY_CMD}\""
		   [ -n "$DEBUG" ] && echo "  WSADMIN=\"$WSADMIN\""
		   [ -n "$DEBUG" ] && echo "  CONNARGS=\"$CONNARGS\""
		   [ -n "$DEBUG" ] && echo "  LOGGING=\"$LOGGING\""
		   [ -n "$DEBUG" ] && echo "  SEC_SCRIPT=\"$SEC_SCRIPT\""
		   [ -n "$DEBUG" ] && echo "  SEC_ARGS=\"$SEC_ARGS\""
		   
		       
		   ###############################
       # Execute security config  
       ###############################
       echo
       echo "************************************"
       echo "Call to wsdamin security config " 
       echo "   security call to be: $bypassed" 
       echo "************************************"
       
       
       if [ $BYPASS_SEC == 0 ]; then  
       	   prompt_to_continue
		       # result=`su - $USER -c "$WSADMIN_SECURITY_CMD | grep -v '^WASX'"`
		       # TODO - If we do not display/output the results, we do not - yet -know if the script executed correctly
		       # Need to get both from "$result" 
		       su - $USER -c "$WSADMIN_SECURITY_CMD" 
		       #    HOLD FOR NOW  | grep -v '^WASX'" $JVM_OUTPUT_DIRECTIVE 
		       echo "  Return code: $? "
       else
           #result="Security config bypassed on request"
           echo Security config bypassed by request
       fi  
       #   echo "..result: "  $result
		   echo                                                                                                                                                                                        
		   # echo "Call to wsdamin security config.... complete"                                                                                                                                                                                      
	  	 
	  	 #####################################   
       # Stop server only if we started it 
       #####################################
       if [ $STARTED_SERVER == 'y' ]; then
           echo "***"
           echo "stop server temporarily disabled..." 
           echo "***"
           #  echo "Stopping $ADMINSERVER since we started it.."
           #  #  TIP - use the profile home result=`su - $USER -c "$WAS_HOME/bin/$STOPSERVER"`
           #  result=`su - $USER -c "$WAS_PROFILE_HOME/bin/$STOPSERVER"`
           #  echo "Stopping $ADMINSERVER ..complete"
       fi    
    else
       echo "Bypassing securityConfig.py no admin server was defined" 
    fi
    
		prompt_to_continue
		
		#####################################
		# Update properties files 
		# Input: TIPPW:      tipadmin password
		#        $keyPassEnc keystore encoded password - may be EI-standard or an override used by NCO
		#        USER, SEC_USER
		#        WAS_HOME, WAS_PROPS:  WAS home and properties directories
		# Notes:
		# 1. If USE_SOAP_CLIENT_PROPS="n", we exploit that soap.client.props contains userid/pw, so 
		#    do not update it with a possibly incorrect password.
		#          
		#####################################
		if [ $PROFILE == TIPProfile -o $PROFILE == JazzSMProfile ]; then
		    loginpw=$TIPPW
		else
		    loginpw=$ldapPass
		fi  
		        
		if [ $BYPASS_UPW == 0 ]; then bypassed="not bypassed"	
    else bypassed="bypassed"; fi
    if [ $SSL_CONFIG_SUCCESS == y ]; then ssl_props_bypassed="not bypassed"	
    else ssl_props_bypassed="bypassed"; fi
 
	  echo "**************************************************"
		echo "Updating soap and ssl .client.props as directed "
		echo "  soap.client.props update to be: $bypassed  " 
		echo "  ssl.client.props  update to be: $ssl_props_bypassed " 
		echo "**************************************************"
		[ -n "$DEBUG" ] && echo  "Userid=$SEC_USER  loginPassword=$loginpw keyPassEnc=$keyPassEnc" 
		[ -n "$DEBUG" ] && echo  "USER=$USER, WAS_PROPS=$WAS_PROPS " 
		[ -n "$DEBUG" ] && echo  "USE_SOAP_CLIENT_PROPS=$USE_SOAP_CLIENT_PROPS"
    [ -n "$DEBUG" ] && echo  "SSL_CONFIG_SUCCESS=$SSL_CONFIG_SUCCESS"

    # Bypass update userid/pw in soap.client.props ?
		if [ $BYPASS_UPW == 0 ]; then 
		  if [ $USE_SOAP_CLIENT_PROPS == "n" ]; then 
		    echo "  Updating soap.client.props with admin userid $SEC_USER and pw $loginpw"
		    prompt_to_continue
		    su - $USER -c "cp -p $WAS_PROPS/soap.client.props $WAS_PROPS/soap.client.props.$DATE"
		    su - $USER -c "sed -e \"s/Userid=.*/Userid=$SEC_USER/g;s/loginPassword=.*/loginPassword=$loginpw/g;s/Source=.*/Source=stdin/g;s/requestTimeout=.*/requestTimeout=$REQTIMEOUT/g\" $WAS_PROPS/soap.client.props.$DATE > $WAS_PROPS/soap.client.props"
        echo "  Updating soap.client.props..complete"
      
	      echo "  Encoding soap.client.props"
		    grep -i createBackup $WAS_HOME/bin/PropFilePasswordEncoder.sh > /dev/null 2>&1
		    if [[ $? -ne 0 ]]; then
		      echo "     backing up PropFilePasswordEncoder"
	  	    cp $WAS_HOME/bin/PropFilePasswordEncoder.sh $WAS_HOME/bin/PropFilePasswordEncoder.sh.orig
			    echo "" >> $WAS_HOME/bin/PropFilePasswordEncoder.sh.orig
			    sed -e "s/-classpath/-Dcom.ibm.websphere.security.util.createBackup=false -classpath/" $WAS_HOME/bin/PropFilePasswordEncoder.sh.orig > $WAS_HOME/bin/PropFilePasswordEncoder.sh
		    fi
		    result=`su - $USER -c "$WAS_HOME/bin/PropFilePasswordEncoder.sh $WAS_PROPS/soap.client.props com.ibm.SOAP.loginPassword"`
		    
		    if [ -f $WAS_PROPS/soap.client.props.bak ]; then
			    rm $WAS_PROPS/soap.client.props.bak
		    fi
	      echo "  Encoding soap.client.props...complete\n "
	    else
          echo "  Bypassing update of soap.client.props because \"-useClientProps\" requested" 
          echo "  The wsadmin userid/password is already contained in soap.client.props"	   
	    fi
	    
	    xx echo "  Updating ssl.client.props" # using $keyPassEnc"
	    # Input: $WAS_PROPS/ssl.client.props, $keyStore, $keyPassEnc 
	    su - $USER -c "cp -p $WAS_PROPS/ssl.client.props $WAS_PROPS/ssl.client.props.$DATE"
		  su - $USER -c "sed -e \"s#Store=.*#Store=$WAS_HOME/profiles/$PROFILE/etc/$keyStore#g;s/StorePassword=.*/StorePassword=$keyPassEnc/g;s/Type=.*/Type=JKS/g\" $WAS_PROPS/ssl.client.props.$DATE > $WAS_PROPS/ssl.client.props"
      echo "  Updating ssl.client.props..complete"
      
	  else
	    echo "Updating soap.client.props...bypassed by request\n" 
	    prompt_to_continue   
	  fi  
	  
	  # Update ssl.client props if ssl config was successful.. always - no bypass 
	  # Input: $WAS_PROPS/ssl.client.props, $keyStore, $keyPassEnc 
	  if [ $SSL_CONFIG_SUCCESS == y ]; then
        echo "Updating ssl.client props.. because ssl config was successful"            	
        prompt_to_continue  
        echo "  Updating ssl.client.props using $keyPassEnc" 
	      echo "    Creating backup in $WAS_PROPS/ssl.client.props.$DATE"
	      
	      su - $USER -c "cp -p $WAS_PROPS/ssl.client.props $WAS_PROPS/ssl.client.props.$DATE"
		    if [ $? -ne 0 ]; then echo "  backup failed...terminating; exit 1; fi; 
		    
		    su - $USER -c "sed -e \"s#Store=.*#Store=$WAS_HOME/profiles/$PROFILE/etc/$keyStore#g;s/StorePassword=.*/StorePassword=$keyPassEnc/g;s/Type=.*/Type=JKS/g\" $WAS_PROPS/ssl.client.props.$DATE > $WAS_PROPS/ssl.client.props"
        if [ $? -ne 0 ]; then echo "  update failed...terminating; exit 1; fi; 
        
        echo "  Updating ssl.client.props..complete"
    else
        echo "Bypass update ssl.client props because ssl config was *not* executed or was *not* successful" 
        prompt_to_continue        	  	
	  fi	
	    
	else
	    ###
	    # Should not occur
	    ### 
	    echo "Error: WebSphere admin scripts not located."
	    echo "WSADMIN=$WSADMIN"
	    exit 1
	fi
else
  echo
	echo "ERROR: WebSphere appears to not be installed correctly, wsadmin.sh not found or not executable."
	echo "       at $WSADMIN"
	exit 1
fi
echo "Done!"
