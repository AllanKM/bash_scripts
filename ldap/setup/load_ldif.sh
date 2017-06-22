#!/bin/ksh

# Setup LDAP ready for loading ldif file
#     remove replication
#     remove main data tree
#     stop ldap
#     load ldif 

my_funcs=/lfs/system/tools/ldap/lib/ksh_functions.ksh
if [ -r $my_funcs ]; then
   . $my_funcs
else
   print -u2 -- "#### Can't read functions file at $my_funcs"
   exit 
fi

#---------------------------------------------------------
# Command syntax
#---------------------------------------------------------
function syntax {
   print "Syntax: $pgm <instance_name> <ldif_file> -D <ldap_root> -w <ldap_root_pw>"
}

#------------------------------------
# delete existing replication config
#--------------------------------------
function delete_replication {
   cmd="ldapsearch $common_parms -p $port -LLL -b o=ibm,c=us objectclass=ibm-replica* dn"
   #----------------------------------
   # create an array of dn's for the replication config
   #----------------------------------    
   set -A dns $( $cmd | (
      while read line; do
         if [ -n "$line" ]; then 
            line=${line#*\ }
            print $line
         fi
      done ) )
   
   i=${#dns[*]}
   i=$((i-1))
   
   #-------------------------------
   # now delete dns in reverse order
   #-------------------------------
   show "h:Delete existing replication objects"
   while [ $i -gt 1 ]; do
      cmd="ldapdelete $common_parms ${dns[$i]}" 
      show $cmd 
      $cmd
      i=$((i-1))
   done
}

#---------------------------------------------------------
# Main code starts here
#---------------------------------------------------------
if [ -z "$SUDO_USER" ]; then
   show "h:${RED}Must be run using sudo${RESET}"
   exit
fi

#---------------------------------------------------------
# Help out with syntax if no parms supplied
#---------------------------------------------------------
if [ $# -eq 0 ]; then
   pgm=${0##*/}
   syntax
   exit 
fi

instance=$1
shift

#---------------------------------------------------------
# check out the remaining parms
#---------------------------------------------------------
while [ -n "$1" ]; do
   if [[ "$1" = *".ldif" ]]; then                # its a ldif file
      ldif=$1
   else
       ldap_parm="$ldap_parm $1"        # append to other ldap parms
   fi 
   shift
done

#-----------------------------------------------
# check LDIF has been supplied and is readable
#-----------------------------------------------
if [[ -z "$ldif" || ! -r "$ldif" ]]; then 
   show ${RED}"\nCannot read ldif file\n$RESET"
   syntax
   exit
fi

#----------------------------------------------
# check instance exists in LDAP instance list
#----------------------------------------------
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

#----------------------------------------------
# check instance home dir exists
#----------------------------------------------
if [ ! -d "$home" ]; then
   show "${RED}$instance does not exist{$RESET}"
   exit
fi

host=`hostname -s`
#----------------------------------------------
# get connection details from ibmslapd.conf
#----------------------------------------------
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

common_parms="-h $host -K $home/idsslapd-$instance/etc/ldapauth.kdb -p $port $ldap_parm"

#----------------------------------------------
# save existing replication config if not already done
#----------------------------------------------
if [ ! -e ./${host}_repl_setup.ldif ]; then
   show "h:Save existing Replication config"

   cmd="ldapsearch $common_parms -p $port -LLL -b o=ibm,c=us objectclass=ibm-replica*"
   show $cmd  
   $cmd >./${host}_repl_setup.ldif
fi

#-------------------------------------
# delete existing replication config
#-------------------------------------
delete_replication 

#----------------------------------
# Can now delete all other entries
#----------------------------------
show "h:delete all entries"
cmd="ldapdelete $common_parms -s o=ibm,c=us"
show $cmd
$cmd

#------------------------
# Stop the ldap server
#------------------------
show "h:"${RED} Stopping LDAP ${RESET}
/opt/IBM/ldap/V$version/sbin/idsslapd -I $instance -k

#------------------------
# Load the ldif data
#------------------------
/opt/IBM/ldap/V${version}/sbin/ldif2db -I $instance -i $ldif -r no

#------------------------
# Start LDAP
#------------------------
show "h:${YELLOW}Starting LDAP${RESET}"
/opt/IBM/ldap/V$version/sbin/idsslapd -I $instance
ldapsearch $common_parms -s base -b o=ibm,c=us objectclass=* dn >/dev/null 2>&1
while [ $? -gt 0 ]; do
   sleep 2
   ldapsearch $common_parms -s base -b o=ibm,c=us objectclass=* dn >/dev/null 2>&1 
done
#--------------------------------------------------
# Delete and replication config in the loaded data
#--------------------------------------------------
show "h:deleting old replication setup"
delete_replication

#--------------------------------------------------
# Load replication configuration for this setup
#--------------------------------------------------
show "h:loading $host replication setup"
ldapadd $common_parms -c -f ${instance}_repl.ldif
