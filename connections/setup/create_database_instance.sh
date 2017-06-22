#!/bin/ksh

DESCRIPTION="IBMCOM Lotus Connections"
OWNERID=lcibmdb
GROUP=lcibmdb2
APPID=lcuser
PORT=62000

/opt/IBM/db2/V9.1/install/db2ls -q 2>/dev/null | grep BASE_DB2_ENGINE > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Installing DB2 server code"
    /lfs/system/tools/db2/setup/instdb2 -server -91
fi

echo "Creating filesystems"
if lsvg appvg >/dev/null 2>&1; then
	VG=appvg
else
	VG=rootvg
fi

if [ ! -d /db2_database ]; then
	mkdir /db2_database
fi

if [ ! -d /db2_datbase/${OWNERID} ]; then
	echo "Creating /db2_database/${OWNERID} filesystem"
	/lfs/system/tools/configtools/make_filesystem /db2_database/${OWNERID} 10240 $VG
fi

lsgroup $GROUP >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Creating Group: $GROUP"
	/fs/system/tools/auth/bin/mkeigroup -r local -d "$DESCRIPTION Instance admin group" -f $GROUP
fi

id $OWNERID >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Creating ID: $OWNERID"
	/fs/system/tools/auth/bin/mkeiuser  -r local -t apps -d "$DESCRIPTION Instance Owner" -f $OWNERID $GROUP /db2_database/${OWNERID}
fi

id $APPID >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Creating ID: $APPID"
	/fs/system/tools/auth/bin/mkeiuser -x -r local -t apps -d "$DESCRIPTION App User" -f $APPID $GROUP
fi

ls -ld /db2_database/${OWNERID} | grep $GROUP >/dev/null
if [ $? -ne 0 ]; then
	echo "Setting owndership and permissions for /db2_database/${OWNERID}"
	umount /db2_database/${OWNERID}
	chown ${OWNERID}:$GROUP /db2_database/${OWNERID}
	chmod 755 /db2_database /db2_database/${OWNERID}
	mount /db2_database/${OWNERID}
	chown ${OWNERID}:$GROUP /db2_database/${OWNERID}
	chmod 755 /db2_database/${OWNERID}
fi

grep $PORT /etc/services | grep $OWNERID >/dev/null
if [ $? -ne 0 ]; then
		echo "Adding ports to /etc/services"
	echo DB2_${OWNERID}     ${PORT}/tcp >> /etc/services
	let PORT=PORT+1
	echo DB2_${OWNERID}_1   ${PORT}/tcp >> /etc/services
	let PORT=PORT+1
	echo DB2_${OWNERID}_2   ${PORT}/tcp >> /etc/services
	let PORT=PORT+1
	echo DB2_${OWNERID}_END ${PORT}/tcp >> /etc/services
fi

if [ ! -d /logs/${OWNERID} ]; then
	echo "Creating logs directory"
	mkdir /logs/${OWNERID}
	chown ${OWNERID}:$GROUP /logs/${OWNERID}
	chmod 755 /logs/${OWNERID}
fi

/opt/IBM/db2/V9.1/instance/db2ilist | grep -w $OWNERID >/dev/null
if [ $? -ne 0 ]; then
	echo "Creating DB2 server instance"
	/opt/IBM/db2/V9.1/instance/db2icrt -s ese -u $OWNERID -p DB2_${OWNERID} $OWNERID
	su - $OWNERID -c ". ~/.profile; /opt/IBM/db2/V9.1/instance/db2iauto -on $OWNERID"
	su - $OWNERID -c ". ~/.profile; db2start" >/dev/null
	su - $OWNERID -c ". ~/.profile; db2set | grep DB2COMM"
	su - $OWNERID -c ". ~/.profile; db2 update dbm cfg using health_mon off"
	su - $OWNERID -c ". ~/.profile; db2set | grep AUTOSTART"
	oslevel -r | grep 5300-04 >/dev/null
	if [ $? -eq 0 ]; then
		su - $OWNERID -c ". ~/.profile; db2set DB2_NUM_CKPW_DAEMONS=0" >/dev/null
		su - $OWNERID -c ". ~/.profile; db2set | grep CKPW"
	fi
	su - $OWNERID -c ". ~/.profile; db2stop" >/dev/null
	su - $OWNERID -c ". ~/.profile; db2start" >/dev/null
	su - $OWNERID -c ". ~/.profile; db2 update dbm cfg using dft_mon_bufpool on" >/dev/null
	su - $OWNERID -c ". ~/.profile; db2 update dbm cfg using dft_mon_lock on" >/dev/null
	su - $OWNERID -c ". ~/.profile; db2 update dbm cfg using dft_mon_sort on" >/dev/null
	su - $OWNERID -c ". ~/.profile; db2 update dbm cfg using dft_mon_timestamp on" >/dev/null
	su - $OWNERID -c ". ~/.profile; db2 get dbm cfg | grep DFT_MON"
	su - $OWNERID -c ". ~/.profile; db2stop" >/dev/null
	su - $OWNERID -c ". ~/.profile; db2start" >/dev/null
fi
	
echo
echo
echo ">>>Locate password for $APPID and be prepared to enter it. Press return to continue:"
echo ">>>"
read

echo "Prompting for $APPID password - obtain from the Password store"
passwd $APPID 
pwdadm -c $APPID

