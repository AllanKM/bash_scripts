#!/bin/bash
# Export a WebSphere AppServer plugin configuration for a given application cluster
#    - A wrapper script for GenPluginCfg.sh
#
# Author:	James Walton <jfwalton@us.ibm.com>
# Date:		29 Oct 2009
# Usage: 	export_plugin.sh [version=<60|61>] [profile=<profilename] [site=<sitetag>] <clustername> <clustername2> ... <clusternameN>

USER=webinst
sitetag="HTTPServer"
#Process command-line options
until [ -z "$1" ] ; do
    case $1 in
		version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VERSION=$VALUE; fi ;;
		profile=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROFILE=$VALUE; fi ;;
    	site=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SITETAG=$VALUE; fi ;;
		help) echo "Usage: 	export_plugin.sh [version=<60|61>] [profile=<profilename] [site=<sitetag>] <clustername> <clustername2> ... <clusternameN>"
			exit 0 ;;
		*)	if [ ${#CLUSTERS} -eq 0 ]; then
				CLUSTERS=$1
		    else
		    	CLUSTERS="$CLUSTERS $1"
			fi
			;;
	esac
	shift
done

i=0
if [ "$VERSION" != "" ] && [ "$PROFILE" != "" ]; then
	#Use version and profile specified on command line
	wasList[$i]="/usr/WebSphere${VERSION}/AppServer/profiles/${PROFILE}"
	i=$(($i+1))
elif [ "$VERSION" != "" ] && [ "$PROFILE" == "" ]; then
	#Use version specified, search for profiles
	DIR="/usr/WebSphere${VERSION}/AppServer"
	for profile in `ls ${DIR}/profiles/`; do
		wasList[$i]="${DIR}/profiles/${profile}"
		i=$(($i+1))
	done
elif [ "$VERSION" == "" ] && [ "$PROFILE" != "" ]; then
	#Search for profile given
	DIRLIST=`ls -d /usr/WebSphere*/AppServer/profiles/* | grep $PROFILE`
	for DIR in $DIRLIST; do
		wasList[$i]=$DIR
		i=$(($i+1))
	done
else
	#No version/profile
	DIRLIST=`find /usr/WebSphere* -type d -name 'AppServer' ! -name . -prune`
	for DIR in $DIRLIST; do
		for profile in `ls ${DIR}/profiles/`; do
			wasList[$i]="${DIR}/profiles/${profile}"
			i=$(($i+1))
		done
	done
fi

if [ $i -gt 1 ]; then
	echo "WebSphere environment(s) and profiles:"
	i=0
	while [[ ${wasList[$i]} != "" ]]; do
		echo "        [$i] ${wasList[$i]}"
		i=$(($i+1))
	done
	printf "\nEnter number for the WebSphere environment you want to use: "
	read choice
	echo "Using: ${wasList[$choice]}"
	ASROOT=${wasList[$choice]}
	GENPLG="${ASROOT}/bin/GenPluginCfg.sh"
else
	ASROOT=${wasList}
	GENPLG="${wasList}/bin/GenPluginCfg.sh"
fi

if [ ! -f $GENPLG ]; then
	echo "Failed to locate $GENPLG ... exiting"
	exit 1
fi

for cluster in $CLUSTERS; do
	if [ ! -d ${ASROOT}/config/cells/*/clusters/${cluster} ]; then
		echo "#### Invalid cluster name ($cluster), skipping."
	else
		filename="/tmp/${cluster}_plugin-cfg.xml"
		ARGS="-cluster.name $cluster -output.file.name $filename -destination.root /projects/HTTPServer"
		echo "-----------------------------------------------------------------------"
		echo "Exporting $cluster plugin configuration ..."
		#DEBUG echo " $GENPLG $ARGS"
		#NOTE: the grep is used to trap any error messages from GenPluginCfg.sh
		su - $USER -c "$GENPLG $ARGS|grep '^PLGC[0-9][0-9][0-9][0-9]E:'"
		chmod 644 $filename
		echo "Done. ($filename)"
		echo "-----------------------------------------------------------------------"
		
		echo "Fixing up Log and PluginInstallRoot paths"
		echo "   Plugin Log:  /logs/${sitetag}/Plugins${VERSION}/http_plugin.log"
		echo "   PluginInstallRoot:  /usr/HTTPServer/Plugins${VERSION}"
		echo "-----------------------------------------------------------------------"
		sed -e "s#Name=\"/projects/HTTPServer/logs/http_plugin.log\"/>#Name=\"/logs/${sitetag}/Plugins${VERSION}/http_plugin.log\"/>#" \
			-e "s#Name=\"PluginInstallRoot\" Value=\"/projects/HTTPServer/\"/>#Name=\"PluginInstallRoot\" Value=\"/usr/HTTPServer/Plugins${VERSION}/\"/>#" \
			${filename} > ${filename}.new
		mv ${filename}.new ${filename}
		
	fi
done