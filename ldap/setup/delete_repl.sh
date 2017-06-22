#!/bin/ksh


# Load ldif file into LDAP and setup replication
#---------------------------------------------------------
# color codes
#---------------------------------------------------------
   BLACK="\033[30;1;49m"
   RED="\033[31;1;49m"
   GREEN="\033[32;1;49m"
   YELLOW="\033[33;3;49m"
   BLUE="\033[34;49;1m"
   MAGENTA="\033[35;49;1m"
   CYAN="\033[36;49;1m"
   WHITE="\033[37;49;1m"
   RESET="\033[0m"

function repeat { typeset i=$1 c="$2" s="" ; while ((i)) ; do ((i=i-1)) ; s="$s$c" ; done ; echo  "$s" ; }

function show {
   if [[ "$1" = "h:"* ]]; then
      msg=$1
      msg=${msg#*:}
      shift
      banner=1
   fi
   msg="$msg $@"
   if [ -n "$banner" ]; then
      len=${#msg}
      len=$((len+4))
      line=$(repeat $len \*)
      print -u2 -- "$line"
      print -u2 -- "* $msg *"
      print -u2 -- "$line"
      unset banner
   else
      print -u2 -- "$msg"
   fi
   unset msg
}

if [ -z "$SUDO_USER" ]; then
   show "h:${RED}Must be run using sudo${RESET}"
   exit
fi

# save existing replication config
if [ $# -eq 0 ]; then
   pgm=${0##*/}
   print "Syntax: $pgm <instance_name> -D <ldap_root> -w <ldap_root_pw>"
   exit 
fi
instance=$1

while read line; do 
      if [[ "$line" = "cn: $instance"* ]]; then   
         wanted=1
      elif [[ "$line" = "cn: "* ]]; then
         unset wanted
      elif [[ "$line" = "ids-instanceVersion:"* && -n "$wanted" ]]; then
         version=$( set -- $line; print $2 )
      elif [[ "$line" = "ids-instanceLocation:"* && -n "$wanted" ]]; then
         home=$( set -- $line; print $2 )
      fi
done < /opt/IBM/ldap/idsinstinfo/idsinstances.ldif  

if [ ! -d "$home" ]; then
   print -u2 -- "$instance does not exist"
   exit
fi
shift
host=`hostname -s`

typeset -l line
while read line; do
   if [[ "$line" = "dn: "* ]]; then
      if [[ "$line" = "dn: cn=ssl"* ]]; then
         gotstanza=1
      else
         unset gotstanza
      fi
    elif [[ "$line" = "ibm-slapdsecureport:"* && -n "$gotstanza" ]]; then
      port=$(set -- $line; print $2)
    elif [[ "$line" = "ibm-slapdipaddress:"* ]]; then
      host=$( set -- $line; print $2 )
    elif [[ "$line" = "ibm-slapdserverid:"* ]]; then
      serverid=$( set -- $line; print $2 )
    fi
done < $home/idsslapd-$instance/etc/ibmslapd.conf

common_parms="-h $host -K $home/idsslapd-$instance/etc/ldapauth.kdb -p $port $@"


cmd="ldapsearch $common_parms -p $port -LLL -b o=ibm,c=us objectclass=ibm-replica*"

# now delete existing repl setup

# create array of repl dns
cmd="$cmd dn"
set -A dns $( $cmd | (
   while read line; do
      if [ -n "$line" ]; then 
         line=${line#*\ }
         print $line
      fi
   done ) )

i=${#dns[*]}
i=$((i-1))

# delete dns in reverse order
show "h:Delete existing replication objects"
while [ $i -gt 1 ]; do
   cmd="ldapdelete $common_parms ${dns[$i]}" 
   show $cmd 
   $cmd
   i=$((i-1))
done

