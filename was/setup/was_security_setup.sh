#!/bin/sh
# Configures the cell's global security configuration.
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
#
#   Usage: was_security_setup.sh {WI|ED} {61|70|85} {PROFILE}"

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

# Set Globals
case $VERSION in 
	61*|70*|85*)	
        if [ "$PROFILE" == "" ]; then 
		#Grab default profile
		defScript=/usr/WebSphere${VERSION}/AppServer/properties/fsdb/_was_profile_default/default.sh
    		DEFPROFILE=$(grep setup $defScript|awk '{split($0,pwd,"WAS_USER_SCRIPT="); print pwd[2]}')
    		WAS_NODE=$(grep WAS_NODE= $DEFPROFILE|awk '{split($0,pwd,"WAS_NODE="); print pwd[2]}')
    		PROFILE=$(echo $DEFPROFILE|awk '{split($0,profile,"/"); print profile[6]}')
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
    	   	ADMINSERVER=server1
    		SERVERSTATUS="serverStatus.sh $ADMINSERVER"
    		STARTSERVER="startServer.sh $ADMINSERVER"
    		STOPSERVER="stopServer.sh $ADMINSERVER"	
		fi
		echo "Using Profile directory:  $WAS_PROFILE_HOME"
		;;
	*)
		echo "Not configured for version $VERSION"
		echo "exiting...."
		exit 1;
esac


WAS_TOOLS=/lfs/system/tools/was
WAS_PASSWD=${WAS_TOOLS}/etc/was_passwd
WSADMIN=${WAS_HOME}/bin/wsadmin.sh
WASLIB=${WAS_TOOLS}/lib
USER=webinst
GROUP=eiadm
case $AUTH in
	WI) SEC_USER=eiauth@events.ihost.com ;;
	ED) SEC_USER=C-BCYD897@nomail.relay.ibm.com ;;
esac
REQTIMEOUT=6000

# Check for user
if [[ -z `id $USER` ]]; then
  echo "Error: user $USER does not exist."
  exit 1
fi

# Make sure permissions allow $USER to write to the various files
/lfs/system/tools/was/setup/was_perms.ksh

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
        /usr/bin/chmod 644 /etc/hosts
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

# does profile start with z or b,g or y, if not try using resolv.conf
if [[ $zone == "z" ]]; then
	#Force ECC nodes to BZ
	zone="b"
elif [[ $zone != [bgy] ]]; then
   echo unable to determine zone from PROFILE
   echo Attempting configuration using /etc/resolve.conf
   set -- $(grep search /etc/resolv.conf)
   while [[ "$1" != "" ]]; do
      if [[ "$1" = [bgy].*.p?.event.ibm.com ]]
      then
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

# now check if the is a pre, cdt or prd setup
# check for old style profile name
X=`echo $PROFILE | grep -E "^[A-z]{3}[0-9]{2}"`
if [[ $? == 0 ]]; then
	envir=`echo $PROFILE | cut -c3 | tr '[:upper:]' '[:lower:]' `
else
	envir=`echo $PROFILE | cut -c3-5 | tr '[:upper:]' '[:lower:]' `
fi
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
echo "Using symlink $symlink to keystore $keyStore"

# Now check keystore exists and copy to the WAS directory
if [[ -e $WAS_HOME/etc/$keyStore ]]; then
	echo "Found keystore in WAS directory..."
elif [[ -e $WAS_TOOLS/etc/$keyStore ]]; then
	echo "Copying keystore from $WAS_TOOLS/etc..."
	echo "cp $WAS_TOOLS/etc/$keyStore $WAS_HOME/etc/$keyStore"
	cp $WAS_TOOLS/etc/$keyStore $WAS_HOME/etc/$keyStore
	chown $USER.$GROUP $WAS_HOME/etc/$keyStore
	chmod 660 $WAS_HOME/etc/$keyStore
	if [[ $VERSION == "85" || $VERSION == "70" || $VERSION == "61" ]]; then
	  	echo "Linking $keyStore to profile/$PROFILE/etc"
	    ln -fs $WAS_HOME/etc/$keyStore $WAS_HOME/profiles/$PROFILE/etc/$symlink
	    ln -fs $WAS_HOME/etc/$keyStore $WAS_HOME/profiles/$PROFILE/etc/$keyStore
	fi
else
	echo "Error: Keystore not found on node - place keystore in $WAS_HOME/etc or re-sync WAS tools before continuing."
	exit 1
fi

# Create a symlink to the keystore if required
if [[ "$keyStore" != "$symlink" ]] ; then
    ln -fs $WAS_HOME/etc/$keyStore $WAS_HOME/etc/$symlink
fi

# Grab the security user and keystore passwords
if [ -e $WAS_PASSWD ]; then
	case $AUTH in
		WI) encrypted_passwd=$(grep ^global_security $WAS_PASSWD |awk '{split($0,pwd,"global_security="); print pwd[2]}' |sed -e 's/\\//g') ;;
		ED) encrypted_passwd=$(grep ^ed_ldap $WAS_PASSWD |awk '{split($0,pwd,"ed_ldap="); print pwd[2]}' |sed -e 's/\\//g') ;;
	esac
	passwd_string=`$WAS_TOOLS/bin/PasswordDecoder.sh $encrypted_passwd`
	ldapPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
	bindPass=$ldapPass
	echo "Found and decoded security user password"
	if [ "$AUTH" == "WI" ]; then
			encrypted_passwd=$(grep ^wi_bind $WAS_PASSWD |awk '{split($0,pwd,"wi_bind="); print pwd[2]}' |sed -e 's/\\//g')
			passwd_string=`$WAS_TOOLS/bin/PasswordDecoder.sh $encrypted_passwd`
			bindPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
			echo "Found and decoded WI app user (bind) password"
	fi

	if [ "$zone" == "b" ]; then
		encrypted_passwd=$(grep ^ssl_bz_keystore $WAS_PASSWD |awk '{split($0,pwd,"ssl_bz_keystore="); print pwd[2]}' |sed -e 's/\\//g')
	else
		if [ `echo $keyStore |grep '_stage'` ]; then
			encrypted_passwd=$(grep ^ssl_gzstage_keystore $WAS_PASSWD |awk '{split($0,pwd,"ssl_gzstage_keystore="); print pwd[2]}' |sed -e 's/\\//g')
		else
			encrypted_passwd=$(grep ^ssl_gz_keystore $WAS_PASSWD |awk '{split($0,pwd,"ssl_gz_keystore="); print pwd[2]}' |sed -e 's/\\//g')
		fi
	fi
	passwd_string=`$WAS_TOOLS/bin/PasswordDecoder.sh $encrypted_passwd`
        keyPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
	keyPass61=$(echo $encrypted_passwd ||sed -e "s/\\\//g")
        echo "Found and decoded keystore password"
else
	echo "Error: WebSphere password setup file not found."
	exit 1
fi

# Check for wsadmin.sh (that WAS installed) and execute
if [[ -x $WSADMIN ]]; then
	WAS_NODE=$(grep WAS_NODE= $WAS_PROFILE_HOME/bin/setupCmdLine.sh |awk '{split($0,pwd,"WAS_NODE="); print pwd[2]}')
	WAS_PROPS=$WAS_PROFILE_HOME/properties
	echo "Found wsadmin.sh - searching for admin scripts..."
	# Check for sslConfig.py and securityConfig.py
	if [[ -e $WASLIB/sslConfig.py && -e $WASLIB/securityConfig.py ]]; then
		echo "Found sslConfig.py and securityConfig.py"
		echo "Executing sslConfig.py as $USER..."
		LOGGING="-tracefile /logs/was${VERSION}/${PROFILE}/wsadmin.sslConfig.traceout"
		result=`su - $USER -c "$WSADMIN -lang jython -conntype NONE $LOGGING -f $WASLIB/sslConfig.py -node $WAS_NODE -keystore $keyStore -keypassword $keyPass -version $VERSION | grep -v '^WASX'"`
		echo $result
	
		## Start up the admin server if present; and it is not already started
		echo "Checking status of $ADMINSERVER ..."
                ## A new managed profile will not have a server1 defined, so start will fail
                noServer=`su - $USER -c "$WAS_HOME/bin/$SERVERSTATUS |tail -1|grep ADMU0522E"` 
                adminStatus=""
                if [[ -z $noServer ]]; then 
		     adminStatus=`su - $USER -c "$WAS_HOME/bin/$SERVERSTATUS |tail -1|grep STARTED"`
                fi               

		if [[ -z $noServer && -z $adminStatus ]]; then
		     echo "Starting $ADMINSERVER ..."
		     result=`su - $USER -c "$WAS_HOME/bin/$STARTSERVER"`
		fi               
               	
                #Security config is only required if there is an Admin server defined 	
                if [[ -z $noServer ]]; then
                     echo "Executing securityConfig.py as $USER..."
                     if [[ $ADMINSERVER == "server1" ]]; then
                         ADDARGS="-standalone"
		     fi
		     LOGGING="-tracefile /logs/was${VERSION}/${PROFILE}/wsadmin.securityConfig.traceout"
			 result=`su - $USER -c "$WSADMIN -lang jython $LOGGING -f $WASLIB/securityConfig.py -$AUTH -ldappassword $ldapPass -bindpassword $bindPass $ADDARGS | grep -v '^WASX'"`
		     echo $result
                     echo "Security complete ..."
                     echo "Stopping $ADMINSERVER ..."
                     result=`su - $USER -c "$WAS_HOME/bin/$STOPSERVER"`
                else
                     echo "Bypassing securityConfig.py no admin server was defined" 
                fi
		
		echo "Updating soap.client.props..."
		su - $USER -c "cp -p $WAS_PROPS/soap.client.props $WAS_PROPS/soap.client.props.orig"
		su - $USER -c "sed -e \"s/Userid=.*/Userid=$SEC_USER/g;s/loginPassword=.*/loginPassword=$ldapPass/g;s/Source=.*/Source=stdin/g;s/requestTimeout=.*/requestTimeout=$REQTIMEOUT/g\" $WAS_PROPS/soap.client.props.orig > $WAS_PROPS/soap.client.props"

		echo "Updating ssl.client.props..."
		su - $USER -c "cp -p $WAS_PROPS/ssl.client.props $WAS_PROPS/ssl.client.props.orig"
		su - $USER -c "sed -e \"s#Store=.*#Store=$WAS_HOME/profiles/$PROFILE/etc/$keyStore#g;s/StorePassword=.*/StorePassword=$keyPass61/g;s/Type=.*/Type=JKS/g\" $WAS_PROPS/ssl.client.props.orig > $WAS_PROPS/ssl.client.props"

		grep -i createBackup $WAS_HOME/bin/PropFilePasswordEncoder.sh > /dev/null 2>&1
		if [[ $? -ne 0 ]]; then
			cp $WAS_HOME/bin/PropFilePasswordEncoder.sh $WAS_HOME/bin/PropFilePasswordEncoder.sh.orig
			echo "" >> $WAS_HOME/bin/PropFilePasswordEncoder.sh.orig
			sed -e "s/-classpath/-Dcom.ibm.websphere.security.util.createBackup=false -classpath/" $WAS_HOME/bin/PropFilePasswordEncoder.sh.orig > $WAS_HOME/bin/PropFilePasswordEncoder.sh
		fi
		result=`su - $USER -c "$WAS_HOME/bin/PropFilePasswordEncoder.sh $WAS_PROPS/soap.client.props com.ibm.SOAP.loginPassword"`
		if [ -f $WAS_PROPS/soap.client.props.bak ]; then
			rm $WAS_PROPS/soap.client.props.bak
		fi
	        
	else
	    echo "Error: WebSphere admin scripts have not been synched to this node."
	    exit 1
	fi
else
	echo "Error: WebSphere appears to not be installed correctly, wsadmin.sh not found."
	exit 1
fi

echo "Applying POODLE SSLv3 fix"
# Run with connx=NONE since we stop the dmgr after initial checks
/lfs/system/tools/was/bin/fluffyDogFixer.sh on connx=NONE

echo "Done!"
