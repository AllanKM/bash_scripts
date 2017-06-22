#!/bin/sh
#
#   Configures the TIP cell's global security configuration.
#
#   Usage: was_security_setup.sh {WI|ED} {61|70|85} {PROFILE} [-tippw <tip_password>] <-bypassSSL> <-bypassSEC> <-bypassUPW> <-bypassPERMS> <-debug>
#
#   If tipadmin's password is needed, use -tippw as the first optional argument. 
#   For now, it's needed unless the password is "tipadmin"  
#   Use ED for TIP. TIP support has not been extended to WI environnments.
#
#   Typical use:
#     cd    /lfs/system/tools/tip/setup
#     sudo ./tip_was_security_setup.sh ED 70 TIPProfile -tippw <password>   
#    
#   TODO:  
#    1. Fix harcoded envir  As an option perhaps, get envir from lssys     
#    2. Exclude authrealm (?) in lssys grep           
#    3. Support the option to recopy the key and trust store files  - low priority
#    4. Get the tip password from a tip passwd file like EI was does it
#
#
# Author:	James Walton
# Contact:	jfwalton@us.ibm.com
# Date:		13 Nov 2006
#
#
#   Change History:
#     Steve Farrell 03-11-2008  Unspecified 
#     Lou Amodeo    03-01-2013  Add support for Websphere 8.5
#     Lou Amodeo    03-11-2013  Additional de-versioning removal  
#     E Coley       04-10-2013  Add support for TIPProfile
#                   04-18-2013  Update ILMT stores to use EI-supplied store 
#                   08-05-2013  
#
#    Changes in support of TIPProfile
#      Stop the server only if we started it. 
#      Use the tipadmin userid and password
#      Add options to help testing: bypassSSL, bypassPERMS, bypassSEC, and bypassUPW 
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
#

SCRIPT_VERSION=1.03
SCRIPTNAME=$(basename $0)

echo "Executing $SCRIPTNAME version $SCRIPT_VERSION"
TIP="y"
TIP_TOOLS=/lfs/system/tools/tip
TIPLIB=${TIP_TOOLS}/lib
TIPADMIN=tipadmin
TIPPW=tipadmin
NODE=$(hostname -s)
STARTED_SERVER='n'
DATE=$(date +"%Y%m%d%H%M")

args="$@"
BYPASS_SSL=`echo $args | grep bypassSSL | wc -l`
BYPASS_SEC=`echo $args | grep bypassSEC | wc -l`
BYPASS_UPW=`echo $args | grep bypassUPW | wc -l`
BYPASS_PERMS=`echo $args | grep bypassPERMS | wc -l`
DEBUG=`echo $args | grep debug | wc -l`
CONSOLELOG=`echo $args | grep consolelog | wc -l`
if [ "$DEBUG" == 0 ]; then
    DEBUG=""   
fi
case $1 in
	WI|wi)  AUTH=WI;;
	ED|ed|BP)  AUTH=ED;;
	*) echo "Error: Unrecognized user registry specified."
	exit 1
esac

HOST=`/bin/hostname -s`
FULLVERSION=${2:-70023}
VERSION=`echo $FULLVERSION | cut -c1-2`
if [ "$3" == "" ]; then
	PROFILE=$HOST
else
	PROFILE=$3								
fi

#TIP
if [ "$4" == "-tippw" ]; then
    TIPPW=$5
    echo "Default TIPPW overridden" 
fi	

# Set Globals
case $VERSION in 
	61*|70*|85*)	
   if [ "$PROFILE" == "" ]; then 
		  #Grab default profile
		  defScript=/usr/WebSphere${VERSION}/AppServer/properties/fsdb/_was_profile_default/default.sh
      DEFPROFILE=$(grep setup $defScript|awk '{split($0,pwd,"WAS_USER_SCRIPT="); print pwd[2]}')
      WAS_NODE=$(grep WAS_NODE= $DEFPROFILE|awk '{split($0,pwd,"WAS_NODE="); print pwd[2]}')
    	
      [ -n "$DEBUG" ] && echo "DEFPROFILE: $DEFPROFILE"
      [ -n "$DEBUG" ] && echo "WAS_NODE: $WAS_NODE"
    		
    	PROFILE=$(echo $DEFPROFILE|awk '{split($0,profile,"/"); print profile[6]}')
    	 -n "$DEBUG" ] && echo "PROFILE: $PROFILE"
    		
			if [ "$PROFILE" == "" ]; then 
    			echo "Failed to find Profile for security configuration"
    			echo "exiting...."
    			exit 1
			fi
		fi
		WAS_PROFILE_HOME="/usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}"
		WAS_HOME=/usr/WebSphere${VERSION}/AppServer
		if [ `echo ${PROFILE}|grep Manager` ]; then
			  ADMINSERVER=dmgr
    		SERVERSTATUS="serverStatus.sh $ADMINSERVER"
    		STARTSERVER="startManager.sh"
    		STOPSERVER="stopManager.sh"
    elif [ -d /usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}/logs/nodeagent ]; then
			  echo "This node is already federated and inherits global security settings"
			  echo "from its deployment manager"
			  echo "exiting...."
			  exit 1
		else
		    [ -n "$DEBUG" ] && echo " ..no deployment manager" 
    	  ADMINSERVER=server1
    		SERVERSTATUS="serverStatus.sh $ADMINSERVER"
    		STARTSERVER="startServer.sh $ADMINSERVER"
    		STOPSERVER="stopServer.sh $ADMINSERVER"	
		fi
		[ -n "$DEBUG" ] && echo "Using Profile directory:  $WAS_PROFILE_HOME"
		;;
	*)
		echo "Not configured for version $VERSION"
		echo "exiting...."
		exit 1;
esac

# TIP
if [ $PROFILE == "TIPProfile" ]; then
    SERVERSTATUS="$SERVERSTATUS -username $TIPADMIN -password $TIPPW"
    STOPSERVER="$STOPSERVER -username $TIPADMIN -password $TIPPW"        
fi  

[ -n "$DEBUG" ] && echo ADMINSERVER:  $ADMINSERVER
[ -n "$DEBUG" ] && echo SERVERSTATUS: $SERVERSTATUS
[ -n "$DEBUG" ] && echo SERVERSTART:  $SERVERSTART
[ -n "$DEBUG" ] && echo SERVERSTOP:   $SERVERSTOP


WAS_TOOLS=/lfs/system/tools/was
WAS_PASSWD=${WAS_TOOLS}/etc/was_passwd
WSADMIN=${WAS_HOME}/bin/wsadmin.sh
WASLIB=${WAS_TOOLS}/lib


# TIP 
# this should be an across the board change  yes?
if [ $PROFILE == "TIPProfile" ]; then
    WSADMIN=${WAS_PROFILE_HOME}/bin/wsadmin.sh      
    [ -n "$DEBUG" ] && echo "WSADMIN changed to $WSADMIN"
fi  
 
USER=webinst
GROUP=eiadm

case $AUTH in
	WI) SEC_USER=eiauth@events.ihost.com ;;
  ED) 
	    SEC_USER=C-BCYD897@nomail.relay.ibm.com 
	    if [ $PROFILE == "TIPProfile" ]; then
	        SEC_USER=tipadmin    
	        [ -n "$DEBUG" ] && echo "In TIPProfile use SEC_USER: $SEC_USER" 
	    fi    
	    ;;
esac
REQTIMEOUT=6000

# Check for user
if [[ -z `id $USER` ]]; then
  echo "Error: user $USER does not exist."
  exit 1
fi

echo "PROFILE=$PROFILE"
 

# Make sure permissions allow $USER to write to the various files
# Update WAS ownership and permissions
if [ $BYPASS_PERMS == "0" ]; then
    echo "Updating WAS owner and permissions in was_perms.ksh"   
    /lfs/system/tools/was/setup/was_perms.ksh
    echo "Updating WAS owner and permissions inwas_perms.ksh...complete" 
else
    echo "Bypassing owner/permissions update by request" 
fi

#For deployment Managers, make sure /etc/hosts has entries to resolve the dmgr nodename and cell name
if [ "$ADMINSERVER" == "dmgr" ]; then
    
    grep $PROFILE /etc/hosts > /dev/null 2>&1
    if [ $? -ne 0 ] ; then
        SHORT=${PROFILE%%?anager}
        HOSTLIST=`grep $HOST /etc/hosts`
        NEWHOSTLIST="$HOSTLIST $SHORT $PROFILE"
        echo "Adding entries to /etc/hosts for $SHORT $PROFILE"
        cp /etc/hosts /etc/hosts.bak
        sed "/$HOST/d" /etc/hosts > /tmp/hosts.custom
        echo $NEWHOSTLIST >> /tmp/hosts.custom && mv /tmp/hosts.custom /etc/hosts
        grep $PROFILE /etc/hosts
    fi
fi

# Determine Zone - pick keystore to look for and check existence
# Assumption here is the PROFILE conforms to the WAS naming convention, ie
# 2 char Zone id
# 3 char Environment type
# 2 char WAS version 
# 1 char WAS minor version (optional)
# 2 char Authentication mechanism
echo Attempting configuration using PROFILE $PROFILE
zone=`echo $PROFILE | cut -c1 | tr '[:upper:]' '[:lower:]' `

#
# Need zone from lssys for TIP
echo "Do zone lookup using lssys"
#TODO - avoid match on authrealm 
EIREALM=$(lssys $NODE | grep realm | cut -d'=' -f 2 )    
zone=$(echo $EIREALM | cut -d'.' -f 1 )
[ -n "$DEBUG" ] && echo zone: $zone


# does profile start with z or b,g or y, if not try using resolv.conf
if [[ $zone == "z" ]]; then
	#Force ECC nodes to BZ
	echo "forcing zone b until script can be changed" 
	zone="b"

# TIP why not lssys for zone-- need change for prod ?	
elif [[ $zone != [bgy] ]]; then
   echo unable to determine zone from PROFILE
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


# if we get here then $zone contains b,g or y
symlink=ei_${zone}z_was.jks
[ -n "$DEBUG" ] && echo symlink=$symlink

# now check if the is a pre, cdt or prd setup
# check for old style profile name
X=`echo $PROFILE | grep -E "^[A-z]{3}[0-9]{2}"`
if [[ $? == 0 ]]; then
	envir=`echo $PROFILE | cut -c3 | tr '[:upper:]' '[:lower:]' `
else
	envir=`echo $PROFILE | cut -c3-5 | tr '[:upper:]' '[:lower:]' `
fi

if [ $PROFILE == "TIPProfile" ]; then
  ENV=$(lssys $NODE | grep hostenv | cut -d'=' -f 2 )     
  [ -n "$DEBUG" ] && echo ENV=$ENV
  envir=$(echo $ENV | tr '[:upper:]' '[:lower:]')
fi  

[ -n "$DEBUG" ] && echo "Prior to envir test for keyStore. envir: $envir"
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

[ -n "$DEBUG" ] && echo "After envir test keyStore=$keyStore"
echo "envir set to $envir"
echo "Using symlink $symlink to keystore $keyStore"
# Now verify that keystore exists and copy to the WAS directory
# Create symlink in the profile's etc directory  
# Input:  $symlink  $keyStore $keyloc 
# Output: symlink in TIPProfile/etc 
# If already there, this is config rerun. Do not recopy

# TODO - support option to rename keystore if found and re-copy  
if [[ -e $WAS_HOME/etc/$keyStore ]]; then
	echo "Found keystore in $WAS_HOME/etc/$keyStore  leaving it as is"
	echo "  Also leave the symlink in $WAS_HOME/profiles/$PROFILE/etc"
elif [[ -e $WAS_TOOLS/etc/$keyStore ]]; then
	echo "Copying keystore from $WAS_TOOLS/etc..."
	echo "cp $WAS_TOOLS/etc/$keyStore $WAS_HOME/etc/$keyStore"
	cp $WAS_TOOLS/etc/$keyStore $WAS_HOME/etc/$keyStore
	chown $USER.$GROUP $WAS_HOME/etc/$keyStore
	chmod 660 $WAS_HOME/etc/$keyStore
	if [[ $VERSION == "85" || $VERSION == "70" || $VERSION == "61" ]]; then
	  	echo "Linking $WAS_HOME/profiles/$PROFILE/etc/$symlink to $WAS_HOME/etc/$keyStore "
	    ln -fs $WAS_HOME/etc/$keyStore $WAS_HOME/profiles/$PROFILE/etc/$symlink
	    if [ $symlink != $keyStore ]; then 
	        echo " also linking $WAS_HOME/profiles/$PROFILE/etc/$keyStore to $WAS_HOME/etc/$keyStore"  
	        ln -fs $WAS_HOME/etc/$keyStore $WAS_HOME/profiles/$PROFILE/etc/$keyStore
	    fi    
	fi
else
	echo "Error: Keystore not found on node - place keystore in $WAS_HOME/etc or re-sync WAS tools before continuing."
	exit 1
fi

# Create a symlink to the keystore if required
if [[ "$keyStore" != "$symlink" ]] ; then
    echo "Creating  symlink to the keystore as required: $WAS_HOME/etc/$symlink"
    ln -fs $WAS_HOME/etc/$keyStore $WAS_HOME/etc/$symlink
fi
[ -n "$DEBUG" ] && echo WAS_PASSWD: $WAS_PASSWD

# Grab the security user and keystore passwords
if [ -e $WAS_PASSWD ]; then
	case $AUTH in
		WI) encrypted_passwd=$(grep global_security $WAS_PASSWD |awk '{split($0,pwd,"global_security="); print pwd[2]}' |sed -e 's/\\//g') ;;
		ED) encrypted_passwd=$(grep ed_ldap $WAS_PASSWD |awk '{split($0,pwd,"ed_ldap="); print pwd[2]}' |sed -e 's/\\//g') ;;
	esac

	passwd_string=`$WAS_TOOLS/bin/PasswordDecoder.sh $encrypted_passwd`
	ldapPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
	bindPass=$ldapPass
	
	[ -n "$DEBUG" ] && echo "encrypted_passwd: $encrypted_passwd"
	[ -n "$DEBUG" ] && echo "decoded encrypted_passwd passwd_string: $passwd_string"
	[ -n "$DEBUG" ] && echo "ldap - ldapPass: $ldapPass"
	[ -n "$DEBUG" ] && echo "ldap - bindPass: $bindPass"
	
	echo "Found and decoded security user password"
	if [ "$AUTH" == "WI" ]; then
	    echo "AUTH_WI"
			encrypted_passwd=$(grep wi_bind $WAS_PASSWD |awk '{split($0,pwd,"wi_bind="); print pwd[2]}' |sed -e 's/\\//g')
			passwd_string=`$WAS_TOOLS/bin/PasswordDecoder.sh $encrypted_passwd`
			bindPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
			echo "Found and decoded WI app user (bind) password"
	fi

	if [ "$zone" == "b" ]; then
		encrypted_passwd=$(grep ssl_bz_keystore $WAS_PASSWD |awk '{split($0,pwd,"ssl_bz_keystore="); print pwd[2]}' |sed -e 's/\\//g')
	else
		encrypted_passwd=$(grep ssl_keystore $WAS_PASSWD |awk '{split($0,pwd,"ssl_keystore="); print pwd[2]}' |sed -e 's/\\//g')
	fi
	passwd_string=`$WAS_TOOLS/bin/PasswordDecoder.sh $encrypted_passwd`
	
	# TIP
	[ -n "$DEBUG" ] &&  echo "TIP decoded passwd_string:  $passwd_string"
	
  keyPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
	keyPass61=$(echo $encrypted_passwd ||sed -e "s/\\\//g")
	
	[ -n "$DEBUG" ] &&  echo " keyPass: $keyPass"
	
   echo "Found and decoded keystore password"
else
	echo "Error: WebSphere password setup file not found."
	exit 1
fi

# Check for wsadmin.sh (that WAS installed) and execute
if [[ -x $WSADMIN ]]; then
	WAS_NODE=$(grep WAS_NODE= $WAS_PROFILE_HOME/bin/setupCmdLine.sh |awk '{split($0,pwd,"WAS_NODE="); print pwd[2]}')
	[ -n "$DEBUG" ] && echo "WAS_NODE: $WAS_NODE"
	WAS_PROPS=$WAS_PROFILE_HOME/properties
	echo "Found wsadmin.sh - searching for admin scripts..."
		
	# For TIP, we also need tip_was_securityConfig.py 
	# TIP  [[ -e $WASLIB/sslConfig.py && -e $WASLIB/securityConfig.py ]]; then
	if [[ -e $WASLIB/sslConfig.py && -e $TIPLIB/tip_was_securityConfig.py ]];  then
		echo "Executing sslConfig.py or tip_sslConfig.py as $USER..."
		
		LOGGING="-tracefile /logs/was${VERSION}/${PROFILE}/wsadmin.sslConfig.traceout"
		if [ CONSOLELOG == "1" ]; then
	      LOGGING=" "      
	  fi   
		[ -n "$DEBUG" ] && echo "Call sslConfig node: $WAS_NODE, keystore: $keyStore,  keypassword= $keyPass"
			
    #------------------------
	  # Execute SSL config
	  #------------------------	
	  # SSL_SCRIPT used for both TIP and standard EI 
	  SSL_SCRIPT="$WASLIB/sslConfig.py"
	  SSL_TIP_SPECIAL_SCRIPT="$TIPLIB/tip_sslConfig.py"
	  CONNARGS="-conntype NONE"
	  # Standard EI ssl config call. Note - TIP needs this work done also 
	  SSL_PY_ARGS="-node $WAS_NODE -keystore $keyStore -keypassword $keyPass -version $VERSION"
		ADDARGS=""
		WSADMIN_SSL_CMD="$WSADMIN $CONNARGS -lang jython $LOGGING -f $SEC_SCRIPT $SSL_PY_ARGS"   
		[ -n "$DEBUG" ] && ADDARGS="$ADDARGS -debug"
		
		tad4d_installed="0"
	  if [ $PROFILE == "TIPProfile" ]; then
		    CONNARGS="-conntype NONE -user $TIPADMIN -password $TIPPW"  
		    lmt=$(ls /opt/IBM/LMT*)
	      if [ $? -eq 0 ]; then 
            tad4d_installed="1"
        fi
        tad4d=$(ls /opt/IBM/TAD4D*)  
        if [ $? -eq 0 ]; then 
            tad4d_installed="1"
        fi
        SSL_TIP_LMT_PY_ARGS="-node $WAS_NODE -ks ILMTkeystore -ts ILMTtruststore -keystore $keyStore -keypassword $keyPass -version $VERSION"
        WSADMIN_TIP_SPECIAL_SSL_CMD="$WSADMIN $CONNARGS -lang jython $LOGGING -f $SSL_TIP_SPECIAL_SCRIPT $SSL_TIP_LMT_PY_ARGS $ADDARGS"
	  fi   
  	echo	              
	  echo "Call to wsdamin sslConfig scripts.." 
	  if [ $BYPASS_SSL == 0 ]; then  
	      echo "Call to wsdamin sslConfig.py for standard EI ssl config...." 
	      # Original way for now - we know this works !
		    result=`su - $USER -c "$WSADMIN -lang jython -conntype NONE $LOGGING -f $WASLIB/sslConfig.py -node $WAS_NODE -keystore $keyStore -keypassword $keyPass -version $VERSION | grep -v '^WASX'"`
		    echo "  Return code: $? "
		    echo "..result: "  $result
		    if [ $PROFILE == "TIPProfile" ]; then  #  -a  tad4d_installed == "1"  ]; then
		        echo "Call to wsdamin tip_sslConfig.py for special TIP LMT EI ssl config...." 
		        result=`su - $USER -c "$WSADMIN_TIP_SPECIAL_SSL_CMD| grep -v '^WASX'"`
		        echo "  Return code: $? "   
		        echo "..result: "  $result
		        echo "Call to wsdamin tip_sslConfig.py for special TIP LMT EI ssl config....complete" 
		        echo 
	     fi  
		else
        result="SSL config bypassed on request"
    fi       
  	echo "Call to wsdamin sslConfig.py....complete" 
	  
		
	  # The starts and stops need to use the profile's bin directory unless default profile is changed
    [ -n "$DEBUG" ] && echo WAS_PROFILE_HOME: $WAS_PROFILE_HOME
    
    # The status commands needs username and password until stored in soap.client.props 
    # right? 
    		
		## Start up the admin server if present; and it is not already started
		echo "Checking status of $ADMINSERVER ..."
    ## A new managed profile will not have a server1 defined, so start will fail
    # TIP noServer=`su - $USER -c "$WAS_HOME/bin/$SERVERSTATUS |tail -1|grep ADMU0522E"`
    # ADMU0522E No server by this name in the configuration: 
    # revise this noServer=`su - $USER -c "$WAS_PROFILE_HOME/bin/$SERVERSTATUS |tail -1|grep ADMU0522E"`
    # Issue this only once 
    serverStatus=`su - $USER -c "$WAS_PROFILE_HOME/bin/$SERVERSTATUS"`
    noServer=$(echo $serverStatus | tail -1|grep ADMU0522E)
    ##echo "Checking status of $ADMINSERVER ...complete"
    [ -n "$DEBUG" ] && echo "..noServer= $noServer"
    echo
    adminStatus=""
    
    # TODO: use the name  startedStatus="" 
    
    # tip  If server name valid
    if [[ -z $noServer ]]; then 
        [ -n "$DEBUG" ] && echo "..valid server name"  
  	    # Is the server started ? 
		    adminStatus=$(echo $serverStatus |tail -1|grep STARTED)
		    [ -n "$DEBUG" ] && echo "..for started status adminStatus: $adminStatus"
		fi               
    # TIP If a valid server and not started, start it  
		if [[ -z $noServer && -z $adminStatus ]]; then
		     echo Issuing start server: \n  $WAS_PROFILE_HOME/bin/$STARTSERVER
		     # TIP result=`su - $USER -c "$WAS_HOME/bin/$STARTSERVER"`
		     result=`su - $USER -c "$WAS_PROFILE_HOME/bin/$STARTSERVER"`
		     [ -n "$DEBUG" ] && echo "..From startServer: $result"
		     STARTED_SERVER='y'
		elif
		   [[ -z $noServer ]]; then
		      echo "..Server already running"
	  fi           
    echo "Checking status of server ...complete"
    
    #  
    #Security config -  is only required if there is an Admin server defined 	
    #
    if [[ -z $noServer ]]; then
       if [[ $ADMINSERVER == "server1" ]]; then
           ADDARGS="-standalone"
           if [ $PROFILE == "TIPProfile" ]; then
               ADDARGS="$ADDARGS -keypassword $keyPass"  
           fi    
       fi    
       if [ -n "$DEBUG" ]; then
               ADDARGS="$ADDARGS -debug"
       fi
		   LOGGING="-tracefile /logs/was${VERSION}/${PROFILE}/wsadmin.securityConfig.traceout"
		   
		   [ -n "$DEBUG" ] && echo  ldapPass $ldapPass 
		   [ -n "$DEBUG" ] && echo  bindPass $bindPass 
		   [ -n "$DEBUG" ] && echo  keyPass  $keyPass
		   [ -n "$DEBUG" ] && echo  ADDARGS $ADDARGS
		   
		   if [ CONSOLELOG == "1" ]; then 
         	         LOGGING=""      
		   fi
		   # If TIPProfile, we need to specify connect args for a running WAS(standalone) on this host 
		   CONNARGS=""
		   if [ $PROFILE == "TIPProfile" ]; then
		      CONNARGS="-conntype SOAP -user $TIPADMIN -password $TIPPW"  
		      [ -n "$DEBUG" ] && echo "CONNARGS: $CONNARGS"
		   fi  
		   
		   ## WSADMIN="/usr/WebSphere70/AppServer/profiles/TIPProfile/bin/wsadmin.sh"  
		   ## TODO:  support debug argument
		   if [ $PROFILE == "TIPProfile" ]; then
		       SEC_SCRIPT="$TIPLIB/tip_was_securityConfig.py"
		   else
		       SEC_SCRIPT="$WASLIB/securityConfig.py"
		   fi 
		   WSADMIN_SECURITY_CMD="$WSADMIN $CONNARGS -lang jython $LOGGING \
		              -f $SEC_SCRIPT  \
		              -$AUTH -ldappassword $ldapPass -bindpassword $bindPass  \
		              $ADDARGS"
		   
		   [ -n "$DEBUG" ] && echo "WAS command for security config: "
		   [ -n "$DEBUG" ] && echo "  ${WSADMIN_SECURITY_CMD}"
		   #-----------------------------
       # Execute security config  
       #-----------------------------
       echo
       echo "Call to wsdamin security config"     
       if [ $BYPASS_SEC == 0 ]; then  
		       result=`su - $USER -c "$WSADMIN_SECURITY_CMD | grep -v '^WASX'"`
		       echo "  Return code: $? "
       else
           result="Security config bypassed on request"
       fi    	   
		   echo "..result: "  $result
		   echo                                                                                                                                                                                        
		   echo "Call to wsdamin security config.... complete"                                                                                                                                                                                      
	  	 echo	   
       # Stop server only if we started it 
       if [ $STARTED_SERVER == 'y' ]; then
           echo "Stopping $ADMINSERVER ..."
           # TIP - use the profile home result=`su - $USER -c "$WAS_HOME/bin/$STOPSERVER"`
           result=`su - $USER -c "$WAS_PROFILE_HOME/bin/$STOPSERVER"`
           echo "Stopping $ADMINSERVER ..complete"
       fi    
    else
       echo "Bypassing securityConfig.py no admin server was defined" 
    fi
		
		#
		# Update properties files 
		#
		if [ $PROFILE == "TIPProfile" ]; then
		    loginpw=$TIPPW
		else
		    loginpw=$ldapPass
		fi          
		[ -n "$DEBUG" ] && echo  "Userid=$SEC_USER  loginPassword=$loginpw keyPass61=$keyPass61" 
	  [ -n "$DEBUG" ] && echo  "WAS_PROPS=$WAS_PROPS"
	
		echo "Updating soap.client.props"
		if [ $BYPASS_UPW == 0 ]; then 
		  su - $USER -c "cp -p $WAS_PROPS/soap.client.props $WAS_PROPS/soap.client.props.$DATE"
		  su - $USER -c "sed -e \"s/Userid=.*/Userid=$SEC_USER/g;s/loginPassword=.*/loginPassword=$loginpw/g;s/Source=.*/Source=stdin/g;s/requestTimeout=.*/requestTimeout=$REQTIMEOUT/g\" $WAS_PROPS/soap.client.props.$DATE > $WAS_PROPS/soap.client.props"

		  echo "Updating ssl.client.props..using $keyPass61"
	    su - $USER -c "cp -p $WAS_PROPS/ssl.client.props $WAS_PROPS/ssl.client.props.$DATE"
		  su - $USER -c "sed -e \"s#Store=.*#Store=$WAS_HOME/profiles/$PROFILE/etc/$keyStore#g;s/StorePassword=.*/StorePassword=$keyPass61/g;s/Type=.*/Type=JKS/g\" $WAS_PROPS/ssl.client.props.$DATE > $WAS_PROPS/ssl.client.props"

		  grep -i createBackup $WAS_HOME/bin/PropFilePasswordEncoder.sh > /dev/null 2>&1
		  echo "Encoding soap.client.props"
		  if [[ $? -ne 0 ]]; then
	  	  cp $WAS_HOME/bin/PropFilePasswordEncoder.sh $WAS_HOME/bin/PropFilePasswordEncoder.sh.orig
			  echo "" >> $WAS_HOME/bin/PropFilePasswordEncoder.sh.orig
			  sed -e "s/-classpath/-Dcom.ibm.websphere.security.util.createBackup=false -classpath/" $WAS_HOME/bin/PropFilePasswordEncoder.sh.orig > $WAS_HOME/bin/PropFilePasswordEncoder.sh
		  fi
		  result=`su - $USER -c "$WAS_HOME/bin/PropFilePasswordEncoder.sh $WAS_PROPS/soap.client.props com.ibm.SOAP.loginPassword"`
		  if [ -f $WAS_PROPS/soap.client.props.bak ]; then
			  rm $WAS_PROPS/soap.client.props.bak
		  fi
	    echo "Updating soap.client.props...complete "
	  else
	    echo "Updating soap.client.props...bypassed by request"    
	  fi    
	else
	    echo "Error: WebSphere admin scripts have not been synched to this node."
	    exit 1
	fi
else
	echo "Error: WebSphere appears to not be installed correctly, wsadmin.sh not found."
	exit 1
fi
echo "Done!"
