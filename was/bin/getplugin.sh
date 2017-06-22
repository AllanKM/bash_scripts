#!/bin/ksh
if [[ -z "$1" ]]; then
	print -u2 -- "#### Error need to supply cluster name for theplugin to be generated"
	exit 1
elif [ ! -d /usr/WebSp*/App*/profiles/*/config/cells/*/clusters/$1 ]; then
	print -u2 -- "#### Invalid cluster name"
	exit 1
else
	CLUSTER=$1
fi
rm -f /tmp/$CLUSTER 1>/dev/null 2>&1
su - webinst -c "/usr/WebSphere*/AppServer/profiles/*/bin/GenPluginCfg.sh -cluster.name $CLUSTER -output.file.name /tmp/${CLUSTER}_plugin-cfg.xml -destination.root /projects/HTTPServer"  >/dev/null
chmod -R 755 /tmp/${CLUSTER}_plugin-cfg.xml

