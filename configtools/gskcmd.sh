#!/bin/bash

cmd="capicmd"
lib='lib'
if [[ `uname -s` = 'AIX' ]]; then
	if [[ $(getconf -a | grep KERN) = *64* ]]; then
		cmd="capicmd_64"
		lib='lib64'
	fi

else
	if [[ $(uname -i) = *64* ]]; then
		cmd="capicmd_64"
		lib='lib64'
	fi
fi

gskit=$(find /usr/opt/ibm /usr/local/ibm /opt/IBM/ITM -name "gsk*$cmd" 2>/dev/null)

for gskcmd in $gskit; do 
	libdir=${gskcmd%/*}
	libdir=$(echo $libdir | sed -e "s+/bin$+/$lib+")
	break
done
if [[ -z "$gskcmd" ]]; then
	echo "Cannot find a working GSK command" 1>&2
	exit 16
else
  export LD_LIBRARY_PATH=%LD_LIBRARY_PATH%:$libdir
  exec $gskcmd "$@"

fi

