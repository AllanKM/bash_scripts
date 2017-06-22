#!/bin/ksh
#------------------------------------------------------------------
# move WAS heapdumps to an offline directory 
#------------------------------------------------------------------
script=${0##*/}
if [ -z "$SUDO_USER" ]; then 
   print -u2 -- "$script must be run using SUDO"
else
   target=$1
   if [ -z "$target" ]; then
      print -u2 "Syntax:\n $script <directory to move heapdumps to>"
      exit
   fi 
   
   if [ ! -d "$target" ]; then
      print -u2 "$target does not exist, will create it"
      mkdir -p $target
   fi

   find /usr/WebSp*/AppServer/profiles \( -name "heapdump.*.phd" -o -name "Snap.*.trc" -o -name "javacore.*.txt" -o -name "core.*.dmp" \) -exec mv {} $target \;
	chown -R root:eiadm $target
	chmod -R 660 $target
fi
