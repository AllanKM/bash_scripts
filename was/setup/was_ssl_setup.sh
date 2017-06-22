#!/bin/bash
# Configures the local node's SSL configuration prior to cell federation.
# Usage: was_ssl_setup.sh version WI|ED [prd|spp|pre|cdt [profile]]
#
#   Change History:
#     Lou Amodeo    03-11-2013  Add support for Websphere 8.5 
#

HOST=`/bin/hostname -s`
VERSION=`echo $1 | cut -c1-2`
AUTH=$2
case $3 in
	pre) KEYSTORE_YZ=ei_yz_was_test.jks
		KEYSTORE_GZ=ei_gz_was_stage.jks
		KEYSTORE_BZ=ei_bz_was.jks
	;;
	cdt) KEYSTORE_YZ=ei_yz_was_test.jks
		KEYSTORE_GZ=ei_gz_was_stage.jks
		KEYSTORE_BZ=ei_bz_was.jks
	;;
	*)  KEYSTORE_YZ=ei_yz_was.jks
		KEYSTORE_GZ=ei_gz_was.jks
		KEYSTORE_BZ=ei_bz_was.jks
	;;
esac
if [ "$4" != "" ]; then
	PROFILE=$4									
fi

# Set Globals
APPDIR=/usr/WebSphere${VERSION}/AppServer
WAS_ETC=/lfs/system/tools/was/etc
WAS_PASSWD=${WAS_ETC}/was_passwd
WSADMIN=$APPDIR/bin/wsadmin.sh
WASLIB=/lfs/system/tools/was/lib
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

# Make sure permissions allow $USER and $GROUP to write to the various files
/lfs/system/tools/was/setup/was_perms.ksh

# Determine Zone - pick keystore to look for and check existence
zone=`grep realm /usr/local/etc/nodecache|tail -n 1|awk '{split($3,zone,".");print zone[1]}'`
case $zone in
  y) keyStore=$KEYSTORE_YZ
     echo "Node to be configured with YZ keystore..." ;;
  g) keyStore=$KEYSTORE_GZ
     echo "Node to be configured with GZ keystore..." ;;
  b) keyStore=$KEYSTORE_BZ
     echo "Node to be configured with BZ keystore..." ;;
  *) echo "Error: Unrecognized realm found when determining zone keystore."
     exit 1
esac

copyKey="false"
if [[ -e $APPDIR/etc/$keyStore ]]; then
  echo "Found keystore in WAS directory..."
  currentSum=`md5sum ${APPDIR}/etc/${keyStore}`
  lfsfileSum=`md5sum ${WAS_ETC}/${keyStore}`
  if [[ $currentSum != $lfsfileSum ]]; then
  	echo "Current keystore and lfs_tools keystore do NOT match."
  	copyKey="true"
  fi
elif [[ -e $WAS_ETC/$keyStore ]]; then
  copyKey="true"
else
  copyKey="false"
  echo "Error: Keystore not found on node - place keystore in $APPDIR/etc or re-sync WAS tools before continuing."
  exit 1
fi

if [[ $copyKey == "true" ]]; then
  echo "Copying keystore from ${WAS_ETC}..."
  cp ${WAS_ETC}/${keyStore} ${APPDIR}/etc/${keyStore}
  chown ${USER}:${GROUP} ${APPDIR}/etc/${keyStore}
  chmod 660 ${APPDIR}/etc/${keyStore}
  echo "Linking $keyStore to profile/${PROFILE}/etc"
  ln -fs ${APPDIR}/etc/${keyStore} ${APPDIR}/profiles/${PROFILE}/etc/${keyStore}
fi

# Grab the security user and keystore passwords
if [[ -e $WAS_PASSWD ]]; then
	case $AUTH in
		WI) encrypted_passwd=$(grep ^global_security $WAS_PASSWD |awk '{split($0,pwd,"global_security="); print pwd[2]}' |sed -e 's/\\//g') ;;
		ED) encrypted_passwd=$(grep ^ed_ldap $WAS_PASSWD |awk '{split($0,pwd,"ed_ldap="); print pwd[2]}' |sed -e 's/\\//g') ;;
	esac
	passwd_string=`$WASLIB/../bin/PasswordDecoder.sh $encrypted_passwd`
	ldapPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
	echo "Found and decoded security user password"

	if [[ $keyStore == $KEYSTORE_BZ ]]; then
		encrypted_passwd=$(grep ^ssl_bz_keystore $WAS_PASSWD |awk '{split($0,pwd,"ssl_bz_keystore="); print pwd[2]}' |sed -e 's/\\//g')
	else
		if [ `echo $keyStore |grep '_stage'` ]; then
			encrypted_passwd=$(grep ^ssl_gzstage_keystore $WAS_PASSWD |awk '{split($0,pwd,"ssl_gzstage_keystore="); print pwd[2]}' |sed -e 's/\\//g')
		else
			encrypted_passwd=$(grep ^ssl_gz_keystore $WAS_PASSWD |awk '{split($0,pwd,"ssl_gz_keystore="); print pwd[2]}' |sed -e 's/\\//g')
		fi 
	fi
	passwd_string=`$WASLIB/../bin/PasswordDecoder.sh $encrypted_passwd`
	keyPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
	keyPass61=$(echo $encrypted_passwd ||sed -e "s/\\\//g")
	echo "Found and decoded keystore password"
else
	echo "Error: WebSphere password setup file not found."
	exit 1
fi

# Check for wsadmin.sh (that WAS installed) and execute
if [[ -x $WSADMIN ]]; then
	if [[ $PROFILE == "" ]]; then
		echo "Looking up default profile"
		defScript=$APPDIR/properties/fsdb/_was_profile_default/default.sh
		DEFPROFILE=$(grep setup $defScript|awk '{split($0,pwd,"WAS_USER_SCRIPT="); print pwd[2]}')
		WAS_NODE=$(grep WAS_NODE= $DEFPROFILE|awk '{split($0,pwd,"WAS_NODE="); print pwd[2]}')
		PROFILE=$(echo $DEFPROFILE|awk '{split($0,profile,"/"); print profile[6]}')
		echo "$PROFILE"
		WAS_PROPS=$APPDIR/profiles/$PROFILE/properties
	else
		echo "Using profile $PROFILE specified on the command line"
		WAS_NODE=$PROFILE
		WAS_PROPS=$APPDIR/profiles/$PROFILE/properties
	fi
	echo "Linking $keyStore to profile/$PROFILE/etc"
	ln -sf $APPDIR/etc/$keyStore $APPDIR/profiles/$PROFILE/etc/$keyStore
  
	if [[ $(grep WAS_CELL= $APPDIR/bin/setupCmdLine.sh |awk '{split($0,pwd,"WAS_CELL="); print pwd[2]}') == $WAS_NODE ]]; then
		echo "Node is not federated, wsadmin will be executed with -conntype NONE"
		CONNX=NONE
	elif [[ $(grep WAS_CELL= $APPDIR/profiles/$PROFILE/bin/setupCmdLine.sh |awk '{split($0,pwd,"WAS_CELL="); print pwd[2]}') == $WAS_NODE ]]; then
		echo "Node is not federated, wsadmin will be executed with -conntype NONE"
		CONNX=NONE
	elif [[ ${WAS_NODE} == "wpnode" ]]; then
		echo "Node is a portal farm node, wsadmin will be executed with -conntype NONE"
		CONNX=NONE
	else
		echo "Node is federated, wsadmin will be executed with -conntype SOAP"
		CONNX=SOAP
	fi
 	echo "Found wsadmin.sh - searching for admin scripts..."
	# Check for sslConfig.py
	if [[ -e $WASLIB/sslConfig.py ]]; then
		echo "Found sslConfig.py - executing as $USER..."
		LOGGING="-tracefile /logs/was${VERSION}/${PROFILE}/wsadmin.sslConfig.traceout"
		result=`su - $USER -c "$WSADMIN -lang jython -conntype $CONNX $LOGGING -f $WASLIB/sslConfig.py -node $WAS_NODE -keystore $keyStore -keypassword $keyPass -version $VERSION"`
		echo "Updating soap.client.props..."
		su - $USER -c "cp -p $WAS_PROPS/soap.client.props $WAS_PROPS/soap.client.props.orig"
		su - $USER -c "sed -e \"s/Userid=.*/Userid=$SEC_USER/g;s/loginPassword=.*/loginPassword=$ldapPass/g;s/Source=.*/Source=stdin/g;s/requestTimeout=.*/requestTimeout=$REQTIMEOUT/g\" $WAS_PROPS/soap.client.props.orig > $WAS_PROPS/soap.client.props"
		echo "Updating ssl.client.props..."
		su - $USER -c "cp -p $WAS_PROPS/ssl.client.props $WAS_PROPS/ssl.client.props.orig"
		su - $USER -c "sed -e \"s#Store=.*#Store=$APPDIR/profiles/$PROFILE/etc/$keyStore#g;s/StorePassword=.*/StorePassword=$keyPass61/g;s/Type=.*/Type=JKS/g\" $WAS_PROPS/ssl.client.props.orig > $WAS_PROPS/ssl.client.props"
		grep -i createBackup $APPDIR/bin/PropFilePasswordEncoder.sh > /dev/null 2>&1
		if [[ $? -ne 0 ]]; then
			cp $APPDIR/bin/PropFilePasswordEncoder.sh $APPDIR/bin/PropFilePasswordEncoder.sh.orig
			echo "" >> $APPDIR/bin/PropFilePasswordEncoder.sh.orig
			sed -e "s/-classpath/-Dcom.ibm.websphere.security.util.createBackup=false -classpath/" $APPDIR/bin/PropFilePasswordEncoder.sh.orig > $APPDIR/bin/PropFilePasswordEncoder.sh
		fi
		result=`su - $USER -c "$APPDIR/bin/PropFilePasswordEncoder.sh $WAS_PROPS/soap.client.props com.ibm.SOAP.loginPassword"`
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
if [[ $CONNX == SOAP ]]; then
	/lfs/system/tools/was/bin/fluffyDogFixer.sh on client=only
else
	/lfs/system/tools/was/bin/fluffyDogFixer.sh on connx=NONE
fi
echo "Done!"
