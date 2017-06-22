#!/bin/ksh
if [[ $(hostname -s) != v20056 ]]; then 
    print -u2 -- "Must run from v20056"
	exit 4
fi
function getlist {
	plex=$1
	lssys_parm=$2
	lssys -q -e role==webserver.* realm==*.$lssys_parm >$$_servers.txt
	sudo /Tivoli/scripts/tiv.task -f ~/$$_servers.txt -t 300 -l $plex ~/$$_tivcmd.sh >~/${plex}_IHS.txt
}

cat <<EOF >~/$$_tivcmd.sh
#!/bin/ksh
server=\$(hostname -s)
env=\$(lssys -1 -l hostenv -n)
for f in \$(ls /usr/sbin/apa*ctl /usr/HTT*/bin/apach* /usr/WebS*/HTTP*/bin/apach*); do
	\$f -V | while read line; do
		if [[ "\$line" = *"Server version"* ]]; then
			print "\$server;\$env; \$f; \$line"
		fi
	done
done
EOF
chmod +x ~/$$_tivcmd.sh

getlist ECC z1
getlist CI1 p1
getlist PX1 p1
getlist CI2 p2
getlist PX2 p2
getlist CI3 p3
getlist PX3 p3
getlist PX5 p5

rm -f ~/$$_tivcmd.sh
rm -f ~/$$_servers.txt
