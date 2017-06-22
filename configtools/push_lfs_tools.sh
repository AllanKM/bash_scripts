#!/bin/ksh
#usage: push_lfs_tools [ dirstore role | host name | p1 | p3 | p5 | rtp | bld | por | plex1 | plex3 | plex5 | px1 | px3 | px5 | ci1 | ci2 | ci3 | ecc | z1 | all ]

# Run push_lfs_tools on v10062 ( Master Tivoli TMR Server )
# Only one of the following arguments must be passed to push_lfs_tools:
# "dirstore role", "host name", "p1", "p3", "p5", "rtp", "bld", "por", "px1", "px3", "px5", "plex1", "plex3", "plex5", "ci1", "ci2", "ci3", "z1", "ecc", or "all".
# The push will be directed to nodes based on the argument.

queryDirstore() {
	#Distribute lfs_tools to servers with these roles
	APPROLES="WEBSEAL WAS. WPS WXS WEBSERVER DATABASE WBIMB CWS.CSM.AIX PUB MQ MONITORING BASTION.INTERNAL.EI GPFS.SERVER.SYNC ITCAM.WAS.MS TPM TMF.TMR SEARCH."
	
	targets=/Tivoli/sd/lfs_tools/lfs_tools_nodes
	targets_tmp=/tmp/$$-push-targets
	rm -f /Tivoli/sd/lfs_tools/lfs_tools_nodes
	for ROLE in $APPROLES ; do
		lssys -q -e role==${ROLE}* nodestatus!=BAD systemtype==system.* $REALM >>$targets_tmp
	done
	cat $targets_tmp | sort -u >$targets
	rm -f $targets_tmp

	if [ -r /Tivoli/sd/lfs_tools/exclude_nodes ]; then
		# get list of nodes in both excludes and targets
		tmp_exclude=/tmp/$$-excludes
		cat $targets /Tivoli/sd/lfs_tools/exclude_nodes | sort | uniq -d >$tmp_exclude
	fi
	if [ -s $tmp_exclude -gt 0 ]; then 
		echo "\n#### Warning nodes in /Tivoli/sd/lfs_tools/exclude_nodes will be skipped #####"
		cat $tmp_exclude
		echo "#### Warning #####\n"
		cat $targets $tmp_exclude | sort | uniq -u >$targets
		rm -f $tmp_exclude
	fi
	echo "Number of nodes in $targets that are targets for distribution:"
	cat $targets | wc -l
}

if [ $(id -u) -ne 0 ]; then
   use_sudo=1
fi
echo
echo "----------------------------------------------------------"
echo

HOST=`/bin/hostname -s`

if [ "$HOST" != "v10062" ]; then
	echo "Run push_lfs_tools on v10062 only"
	echo "exiting...."
	exit 1
fi

echo "Looking for tar of lfs_tools"
if [ ! -r /Tivoli/sd/lfs_tools/lfs_tools.tar ]; then
        echo "Run get_lfs_tools first to obtain the latest scripts from the IIOSB and prepart lfs_tools for distribution"
        exit 1
fi

cat /dev/null > /Tivoli/sd/lfs_tools/lfs_tools_nodes
if [ $? -ne 0 ]; then
        echo "Unable to write to /Tivoli/sd/lfs_tools/lfs_tools_nodes.  Exiting..."
        exit 1
fi

cd /Tivoli/sd/lfs_tools
if [[ $? -ne 0 ]]; then
        echo "Failed to change working directory to /Tivoli/sd/lfs_tools"
        exit 1
fi 

echo
echo
echo "----------------------------------------------------------"
echo
echo

#Get latest list of Application nodes from the dirstore
case $1 in
	all)
		echo "WARNING:  Pushing tools to all three plexes at once"
		echo "Best practice is to populate just one site at a time"
		#If "all", then just make sure we don't touch Surfaid machines	
		queryDirstore
		TMR="-a"
		;;
	p1|rtp|plex1)
		echo "Gathering list of application related servers in $1"
		REALM="realm==*p1"
		queryDirstore
		TMR="-l PX1,CI1,ECC"
		;;
	ci1)
		echo "Gathering list of application related servers in $1"
		REALM="realm==*ci.p1"
		queryDirstore
		TMR="-l CI1"
		;;
	px1)
		echo "Gathering list of application related servers in $1"
		REALM="realm==*ei.p1"
		queryDirstore
		TMR="-l PX1"
		;;
	ecc)
		echo "Gathering list of application related servers in $1"
		REALM="realm==*.z1"
		queryDirstore
		TMR="-l ECC"
		;;
        z1)
                echo "Gathering list of application related servers in $1"
                REALM="realm==*.z1"
                queryDirstore
                TMR="-l ECC"
                ;;
	p3|bld|plex3)
		echo "Gathering list of application related servers in $1"
		REALM="realm==*p3"
		queryDirstore
		TMR="-l PX3,CI3"
		;;
	px3)
		echo "Gathering list of application related servers in $1"
		REALM="realm==*ei.p3"
		queryDirstore
		TMR="-l PX3"
		;;
	ci3)
		echo "Gathering list of application related servers in $1"
		REALM="realm==*ci.p3"
		queryDirstore
		TMR="-l CI3"
		;;
	p5|por|plex5)
		echo "Gathering list of application related servers in $1"
		REALM="realm==*p5"
		queryDirstore
		TMR="-l PX5"
		;;
	px5)
		echo "Gathering list of application related servers in $1"
		REALM="realm==*ei.p5"
		queryDirstore
		TMR="-l PX5"
		;;
	ci5)
		echo "Gathering list of application related servers in $1"
		REALM="realm==*ci.p5"
		queryDirstore
		TMR="-l CI5"
		;;
	*.*)
		echo "Pushing tools to role: $1"
		lssys -q -e role==${1}* > /Tivoli/sd/lfs_tools/lfs_tools_nodes
		echo "/Tivoli/sd/lfs_tools/lfs_tools_nodes contains:"
		cat /Tivoli/sd/lfs_tools/lfs_tools_nodes
		TMR="-a"
		;;
	*)
		echo "Pushing tools to host: $1" 
		REALM=`lssys $1 | grep realm | cut -d= -f2`
		case $REALM in
			*ei.p1|*cs.p1) TMR="-l PX1"  ;;
			*ei.p3|*cs.p3) TMR="-l PX3"  ;;
			*ei.p5|*cs.p5) TMR="-l PX5"  ;;
			*ci.p1) TMR="-l CI1"  ;;
			*.z1) TMR="-l ECC"  ;;
			*ci.p3) TMR="-l CI3"  ;;
			*ci.p5) TMR="-l CI5"  ;;
			*) 
				lssys $1
				echo "Update $0 to recognize $REALM associated with host $1"
				exit 1
				;;
		esac
		echo $1 > /Tivoli/sd/lfs_tools/lfs_tools_nodes
		echo "/Tivoli/sd/lfs_tools/lfs_tools_nodes contains:"
		cat /Tivoli/sd/lfs_tools/lfs_tools_nodes
		;;
esac

if [ -n "$use_sudo" ];then
	echo "Using sudo now to distribute files"
	echo "Enter your greenzone password if sudo prompts for it"
	sudo chmod g+rw /Tivoli/sd/lfs_tools/lfs_tools_nodes
	sudo chgrp eiadm /Tivoli/sd/lfs_tools/lfs_tools_nodes
	echo "\n\n----------------------------------------------------------\n\n"
	echo "sudo /Tivoli/scripts/tiv.install $TMR -f /Tivoli/sd/lfs_tools/lfs_tools_nodes /Tivoli/sd/lfs_tools /tmp"
	sudo /Tivoli/scripts/tiv.install $TMR -f /Tivoli/sd/lfs_tools/lfs_tools_nodes /Tivoli/sd/lfs_tools /tmp
else
	chmod g+rw /Tivoli/sd/lfs_tools/lfs_tools_nodes
	chgrp eiadm /Tivoli/sd/lfs_tools/lfs_tools_nodes
	echo "\n\n----------------------------------------------------------\n\n"
	echo "/Tivoli/scripts/tiv.install $TMR -f /Tivoli/sd/lfs_tools/lfs_tools_nodes /Tivoli/sd/lfs_tools /tmp"
	/Tivoli/scripts/tiv.install $TMR -f /Tivoli/sd/lfs_tools/lfs_tools_nodes /Tivoli/sd/lfs_tools /tmp
fi
