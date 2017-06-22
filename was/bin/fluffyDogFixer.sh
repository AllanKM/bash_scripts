#!/bin/bash
# Address POODLE SSLv3 vulnerability
#
# Author:	James Walton
# Contact:	jfwalton@us.ibm.com
# Date:		22 Oct 2014
#
#   Usage: fluffyDogFixer.sh on|off|show [client=yes|no|only] [version=85] [profile=profile_name] [connx=SOAP|NONE]

USER=webinst
WASLIB="/lfs/system/tools/was/lib"
FIXERLIB="${WASLIB}/fluffyDogFixer.py"

# Process command-line opts
until [ -z "$1" ] ; do
    case $1 in
		version=*)	VALUE=${1#*=}; if [ "$VALUE" != "" ]; then export VERSION=$VALUE; fi ;;
		profile=*)	VALUE=${1#*=}; if [ "$VALUE" != "" ]; then export PROFILE=$VALUE; fi ;;
		client=*)	VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CLIENT=$VALUE; fi ;;
		connx=*)	VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CONNX=$VALUE; fi ;;
		*)	POODLEFIX=$1 ;;
    esac
    shift
done

# Make sure VERSION is 2-digit, set and get WebSphere profile directory
${WASLIB}/getWasDir.sh | tee /tmp/getWasDir.out
ASROOT=`cat /tmp/getWasDir.out |tail -1 |awk '{print $2}'`
if [[ -z $VERSION ]]; then
	VERSION=`echo $ASROOT |awk '{split($0,p,"/"); print p[3]}' |cut -c10-11`
fi
rm /tmp/getWasDir.out
echo "---------------------------------------------------------------"

#=============================================================================================
# Fix SSL configurations, as long as this is not a clientprop-only request
#=============================================================================================
if [[ $CLIENT != "only" ]]; then
	WSADMIN="${ASROOT}/bin/wsadmin.sh"
	if [[ ! -f $WSADMIN ]]; then
	    echo "ERROR: WebSphere directory or wsadmin.sh not found in ${ASROOT}/bin, exiting..."; exit 1
	fi
	if [[ $CONNX == "NONE" ]]; then
		WSADMIN="$WSADMIN -conntype NONE"
	fi
	LOGDIR="/logs/was${VERSION}"
	LOG="${LOGDIR}/fluffyDogFixer_wsadmin.out"
	echo "*******************************************************************************************"
	echo "* Profile  : $ASROOT"
	echo "* Log file : $LOG"
	echo "* wsadmin  : $FIXERLIB $POODLEFIX"
	echo "*******************************************************************************************"
	su - $USER -c "$WSADMIN -tracefile $LOG -f $FIXERLIB $POODLEFIX 2>&1 |egrep -v '^WASX|sys-package-mgr'"
fi

#=============================================================================================
# Now fix the ssl.client.props if required and requested
#=============================================================================================
if [[ $CLIENT != "no" ]]; then
	case $POODLEFIX in
		"on")   SSLPROT="TLS" ;;
		"off")  SSLPROT="SSL_TLS" ;;
	esac
	
	curProtocol=`grep '^com.ibm.ssl.protocol' ${ASROOT}/properties/ssl.client.props |awk '{split($0,p,"="); print p[2]}'`
	if [[ $POODLEFIX == "show" ]]; then
		echo "ssl.client.props using protocol:  $curProtocol"
	elif [[ $curProtocol == $SSLPROT ]]; then
		echo "ssl.client.props already @ protocol:  $SSLPROT"
	else 
		echo -ne "ssl.client.props MODIFY to protocol:  $SSLPROT     "
		su - $USER -c "cp -p ${ASROOT}/properties/ssl.client.props ${ASROOT}/properties/ssl.client.props.orig"
		su - $USER -c "sed -e \"s/com.ibm.ssl.protocol=.*/com.ibm.ssl.protocol=${SSLPROT}/g\" ${ASROOT}/properties/ssl.client.props.orig > ${ASROOT}/properties/ssl.client.props"
		if [ $? -eq 0 ]; then
			echo "[SUCCESS]"
		else
			echo "[FAILED]"
		fi
	fi
fi