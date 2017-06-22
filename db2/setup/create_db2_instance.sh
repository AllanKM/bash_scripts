#!/bin/bash
# Usage:  create_db2_instance.sh <version> <instance_name>
#         version = 91 | 9.1 | 95 | 9.5

usage() {
	echo "#### Missing required parameter: $1"
	echo "Usage: create_db2_instance.sh <version> <instance_name>"
	echo "       version = 91 | 9.1 | 95 | 9.5"
}

# Verify command running as sudo/root
if [[ $USER != "root" ]]; then
	echo "#### Must run script with sudo or as root"
	exit 1
fi

# Check for paramters
if [ -z $1 ]; then
	usage "VERSION"
	exit 1
fi
VER=$1
case $VER in
	91|9.1)	VERSION="9.1"
			INSTVER="-91"
			;;
	95|9.5) VERSION="9.5"
			INSTVER="-95"
			;;
	*)	usage "VERSION"
		exit 1 ;;
esac

if [ -z $2 ]; then
	usage "INSTANCE NAME"
	exit 1
fi
DB2INST=$2

# Install DB2 client, if not installed already
if [ -x /opt/IBM/db2/V${VERSION}/instance/db2icrt ]; then
	echo "DB2 v${VERSION} installed."
else
	echo "DB2 v${VERSION} not installed on this node, installing before instance creation..."
	/fs/system/tools/db2/instdb2 ${INSTVER}
fi

if [[ $DB2INST != "webinst" ]]; then
	# Create 100 MB /db2_database file system
	if [[ `df /db2_database |grep db2_database` != "" ]]; then
		echo "Filesystem /db2_database exists."
	else
		echo "Creating filesystem /db2_database (100MB)"
		/fs/system/bin/make_filesystem /db2_database 100 appvg
	fi
	INSTHOME="/db2_database/${DB2INST}"
else
	INSTHOME="/home/${DB2INST}"
fi
id $DB2INST
if [ $? -ne 0 ]; then
	# Create DB2 instance owner group and user
	echo "Creating DB2 instance user:group ${DB2INST}:apps"
	/fs/system/tools/auth/bin/mkeigroup -r local apps
	/fs/system/tools/auth/bin/mkeiuser -r local ${DB2INST} apps ${INSTHOME}
else
	echo "User $DB2INST exists, continuing"
fi

# Create DB2 client instance
if [[ `/opt/IBM/db2/V${VERSION}/instance/db2ilist |grep $DB2INST` != "" ]]; then
	echo "#### DB2 instance $DB2INST already exists!"
	exit 1
else
	echo "Creating DB2 instance $DB2INST at ${INSTHOME}"
	/opt/IBM/db2/V${VERSION}/instance/db2icrt ${DB2INST}
fi

# Print reminder: Set dummy password for non-webinst instance owner
if [[ $DB2INST != "webinst" ]]; then
	echo "#### IMPORTANT: You MUST MANUALLY configure the instance owner to be ITCS104 complaint!!!"
	echo "Steps to be completed for ITCS104 compliance:"
	echo "  sudo su - root"
	echo "  passwd ${DB2INST}"
	echo "    (Use a dummy password, as you will be clearing it)"
	echo "  pwdadm -c ${DB2INST}"
	echo "  vi /etc/security/passwd"
	echo "    (Set password = * for the ${DB2INST} stanza)"
	echo "    (Remove lastupdate row from the ${DB2INST} stanza)"
fi
