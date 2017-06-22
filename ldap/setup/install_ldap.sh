#!/bin/ksh
#---------------------------------------------------------------
# LDAP code install.  
#---------------------------------------------------------------
debug=${DEBUG:-0}
#----------------
# defaults 
#----------------
LFSTOOLS=/lfs/system/tools/ldap
code_conf="${LFSTOOLS}/etc/ldap_version.conf"
etc=/etc/services
vg=appvg1
vgsize=2048M
type=client
version=6.3
port=389
secure_port=636
seed="j0hnny4pples33d"
root_dn="cn=root"


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


trap 'stty echo; exit' INT
function wait_user {
   print -u2 -- "Press enter to continue or Ctrl-c to exit"
   read response
}

getpassword() {
   pw_for=$1
   PASSWORD=""
   PASSWORD_CONF="z"
   i=1
   while [ "$PASSWORD" != "$PASSWORD_CONF" ] && [ $i -lt 4 ]; do
      print -u2 -n -- "Enter password for $pw_for: "
      stty -echo
      read PASSWORD
      stty echo
      print -u2 -n -- "\nConfirm password: "
      stty -echo
      read PASSWORD_CONF
      stty echo
      i=$((i+1))
      if [ "$PASSWORD" != "$PASSWORD_CONF" ]; then
         print -u2 -- "\nPassword do not match try again ... "
         PASSWORD=""
      fi
   done   
   if [ -z "$PASSWORD" ]; then
      print -u2 -- "#### Failed to set password"
      exit 2
   fi
   print -u2 -- ""
   print $PASSWORD
}

function debug {
   [ "$debug" = 1 ] && print -u2 -- "${YELLOW}DEBUG: ${BLUE}$@ ${RESET}"
}

function lookup_code {
   file=$1
   version=$2
   type=$3 
   while read line; do
      debug $line
      set -- $(print $line)
      if [ "$version" = "$1" ] && [ "$type" = "$2" ]; then  
         if [ -e $3 ]; then
            debug "matched ver: $1 type: $2   path: $3"   
            print $3
            return
         else
            print -u2 -- "#### $3 does not exist"
            exit 2
         fi
      fi  
   done < $file
}
# USAGE: install_ldap.sh [VERSION] [SERVER|CLIENT]

install_gskit_aix() {
   cd $install_dir/gskit
   files=$( set -- `ls @(GSK|gsk)*`; print $* )
   if [ "$debug" = 1 ]; then 
      debug "installp -acgXd . $files"
   else
  print    installp -acgXd . $files
   fi
   cd - >/dev/null 
}

install_server_aix() {
   print -u2 -- "============================================================================================"
   print -u2 -- "Installing LDAP Server code from $install_dir"
   print -u2 -- "============================================================================================" 
   
   install_gskit_aix
   cd $install_dir/tdsfiles
   files=$( set -- `ls  idsldap*@(msg|srv)* | grep -v proxy`; print $* )
   if [ "$debug" = 1 ]; then 
      debug "installp -acgXd . $files"
   else
      installp -acgXd . $files
   fi
   cd - >/dev/null  
}

install_client_aix() {
   print -u2 -- "============================================================================================"
   print -u2 -- "Installing LDAP Client code from $install_dir"
   print -u2 -- "============================================================================================"
   cd $install_dir/tdsfiles 
   install_gskit_aix
   files=$( set -- `ls idsldap*@(msg|clt)*`; print $* )
   if [ "$debug" = 1 ]; then 
      debug "installp -acgXd . $files"
   else
      installp -acgXd . $files
   fi
   cd - >/dev/null 
}

function usage {
  echo "Usage:"
  echo ""
  echo " $0 [VERSION] [SERVER|CLIENT]"
  echo ""
}

while [ $# -gt 0 ]; do
   
   case $1 in 
      vg=*)
         vg=${1#*=}
         ;;
      vgsize=*)
         vgsize=${1#*=}
         ;;
      [[:digit:]].[[:digit:]]) 
         install_code=$(lookup_code $code_conf $1 BASE )
         if [ -n "$install_code"  ]; then
            debug "install code for $1 is $install_code" 
            version=$1
         else
            print -u2 "source code for $1 not found"
            exit 2
         fi
         ;;
      server|client ) 
         type=$1
         ;;   
      instance=*)
         instance=${1#*=}
         ;;
      instance_pw=*)
         instance_pw=${1#*=}
         ;;
      dbgroup=*)
         dbgroup=${1#*=}
         ;;
      dbuser=*)
         dbuser=${1#*=}
         ;;
      dbuser_pw=*)
         dbuser_pw=${1#*=}
         ;;
      db2version=*)
         db2version=${1#*=}
         if [ ! -e /opt/IBM/db2/V$db2version/instance/db2icrt ]; then
            print -u2 -- "#### DB2 $1 is not installed"
            exit 2 
         fi
         ;;
      port=*)
         port=${1#*=}
         ;;
      secure_port=*)
         secure_port=${1#*=}
         ;;
      ssl=*) 
         ssl=${1#*=}
         ;;
      seed=*)
         seed=${1#*=}
         ;;
      eischema) 
         eischema=1
         ;;
      root_dn=*) 
         root_dn=${1#*=}
         ;;
      root_dn_pw=*) 
         root_dn_pw=${1#*=}
         ;;
      *) print --u2 -- "${RED}Unrecognised parm: $1${RESET}"
      ;;
   esac
   shift 
done
install_dir=$(lookup_code $code_conf $version BASE )
debug "version=$version type=$type"
if [ $type = "server" ]; then
   if [ -z "$instance" ]; then
      print -u2 -- "#### Missing instance name, specify instance= parm"
      exit 2
   fi
   if [ -z "$db2version" ]; then
      print -u2 -- "#### Need DB2 version, specify db2version= parm"
      exit 2 
   fi
   
   # app id & group
   if [ -z "$dbgroup" ]; then
      if [[ $instance = *"db" ]]; then  
         dbgroup=${instance%db}
      else
         print -u2 -- "#### instance name not in EI standard, correct it or add dbgroup= and dbuser= parms"
         exit 2
      fi 
   fi
   if [ -z "$dbuser" ]; then     
      if [[ $instance = *"db" ]]; then
         dbuser="${instance%db}us"
      else
         print -u2 -- "#### instance name not in EI standard, correct it or add dbuser= parm"
         exit 2
      fi
   fi
   
   if [ -z "$root_dn_pw" ]; then
      root_dn_pw=$(getpassword "$root_dn") 
   fi
   if [ -z "$instance_pw" ]; then
      instance_pw=$(getpassword "$instance") 
   fi
   if [ -z "$dbuser_pw" ]; then
      dbuser_pw=$(getpassword "$dbuser") 
   fi
   
   debug "instance=$instance instance_pw=$instance_pw"
   debug "dbgroup=$dbgroup dbuser=$dbuser dbuser_pw=$dbuser_pw"
   debug "vg=$vg vgsize=$vgsize"
   debug "root_dn=$root_dn root_dn_pw=$root_dn_pw eischema=$eischema"
   debug "seed=$seed ssl=$ssl"
   debug "port=$port secure_port=$secure_port"
fi

#=====================================================================
# Install client product code
#=====================================================================

if ! lslpp -l | grep -Eq "idsldap.*clt(32|64).* ${version}\."; then
    install_client_aix
else
    print "============================================================================================"
    print "$version Client already installed"
    print "============================================================================================" 
    lslpp -l | grep -E "ids.*clt(32|64).* ${version}\." | sort -u
fi             

#======================================================================
# Install server
#======================================================================
if [ "$type" = "server" ]; then
   if ! lslpp -l "idsldap.*" | grep -Eq "ids.*srv(32|64).* ${version}\."; then
      # server not installed
      install_server_aix
   else
      print "============================================================================================"
      print "$version Server is already installed"
      print "============================================================================================"
      lslpp -l | grep -E "ids.*srv(32|64).* ${version}\." | sort -u
   fi
   wait_user
       
   BASEDIR=/db2_database/$instance
   print "============================================================================================"
   print "Installing LDAP Server $version for instance $instance"
   print "============================================================================================"
   #======================================================================
   # check volume group exists
   #======================================================================
   print "============================================================================================"
   print "Checking volume group"
   print "============================================================================================" 
   
   if lsvg ${vg} >/dev/null 2>&1; then
      print "Using ${vg} as the volume group"
   else
      print "VG ${vg} does not exist.  Please specify the correct vg=."
      exit 1
   fi
  
     
   print "============================================================================================"
   print "Setting up filesystems"
   print "============================================================================================"
   df -m $BASEDIR > /dev/null 2>&1
   if [ $? -ne 0 ]; then
      echo "Creating filesystem $BASEDIR"
      if [ "$debug" = 1 ]; then
         debug "/fs/system/bin/eimkfs $BASEDIR $vgsize $vg"
      else
         /fs/system/bin/eimkfs $BASEDIR $vgsize $vg
      fi
   else
      fsize=$( set -- `df -m $BASEDIR|tail -1`; print ${2%.*})
      if [ "$fsize" -lt $vgsize ]; then
         echo "Increasing $BASEDIR filesystem size to $vgsize"
         if [ "$debug" = 1 ]; then
            debug "/fs/system/bin/eichfs $BASEDIR ${vgsize}"
         else
            /fs/system/bin/eichfs $BASEDIR ${vgsize}
         fi
      else
         echo "Filesystem $BASEDIR already larger than $vgsize, making no changes."
      fi
   fi
   
   # check filesystem got created
   df $BASEDIR >/dev/null 2>&1
   if [[ $? -ne 0 ]]; then
      exit 2
   fi
   
   wait_user  
   print "============================================================================================"
   print "Adding users and groups"
   print "============================================================================================"
   
   if ! grep -q ^$dbgroup /etc/group; then
   print "$? not equal to 0"
      if [ "$debug" = 1 ]; then
         debug "/fs/system/tools/auth/bin/mkeigroup -r local -f $dbgroup"
         debug "/usr/bin/chgrpmem -m + root $dbgroup"
         debug "/usr/bin/chgrpmem -m + root idsldap"
      else
         debug "Creating group"
         /fs/system/tools/auth/bin/mkeigroup -r local -f -d "$instance LDAP group" $dbgroup
         /usr/bin/chgrpmem -m + root $dbgroup
         /usr/bin/chgrpmem -m + root idsldap
      fi
   fi 
   
   id $instance > /dev/null 2>&1 
   if [[ $? -ne 0 ]]; then
      if [ "$debug" = 1 ]; then
         debug "/fs/system/tools/auth/bin/mkeiuser  -r local -f $instance $dbgroup /db2_database/$instance"
         debug "/usr/bin/chgrpmem -m + $instance idsldap"
      else
         /fs/system/tools/auth/bin/mkeiuser  -r local -f  -d "$instance LDAP db owner" $instance $dbgroup /db2_database/$instance
         /usr/bin/chgrpmem -m + $instance idsldap
         print "$instance:$instance_pw" | /usr/bin/chpasswd
         /usr/bin/pwdadm -c $instance
      fi
   fi
   
   id $dbuser >/dev/null 2>&1
   if [[ $? -ne 0 ]]; then
      if [ "$debug" = 1 ]; then
         debug "/fs/system/tools/auth/bin/mkeiuser  -r local -f $dbuser $dbgroup"
         debug "/usr/bin/chgrpmem -m + $dbuser idsldap"
      else
         /fs/system/tools/auth/bin/mkeiuser  -r local -f  -d "$instance LDAP user" $dbuser $dbgroup
         print "$dbuser:$dbuser_pw" | /usr/bin/chpasswd
         /usr/bin/chgrpmem -m + $dbuser idsldap
         /usr/bin/pwdadm -c $dbuser
      fi
   fi
   
   
   if [ "$debug" = 1 ]; then
      debug "chown -R $instance:$dbgroup $BASEDIR"
   else
      chown -R $instance:$dbgroup $BASEDIR
      chmod -R 775 $BASEDIR
   fi
   
   if [ ! -e /db2_database/$instance/.profile ]; then
      print "# profile for $instance" >/db2_database/$instance/.profile
   fi
   
   wait_user
 
#   print "============================================================================================"
#   print "Adding DB2 ports to $etc"
#   print "============================================================================================"
#   if ! grep -iq "DB2_${instance}" $etc; then
#      i=50000
#      while grep -Eq "$i|$((i+1))|$((i+2))|$((i+3))" $etc; do
#         i=$((i+100))
#      done
#      service="DB2_$instance\t$((i))\nDB2_${instance}_1\t$((i+1))\nDB2_${instance}_2\t$((i+2))\nDB2_${instance}_END\t$((i+3))"
#      if [ "$debug" = 1 ]; then
#         debug $service
#      else
#         print $service >> $etc
#      fi
#   else 
#      print -u2 -- "DB2_$instance already exists in $etc "
#   fi
#   wait_user
   
   print "============================================================================================"
   print "Creating DB2 V$db2version instance $instance"
   print "============================================================================================" 
   if [ "$debug" = 1 ]; then
      debug "/opt/IBM/db2/V$db2version/instance/db2icrt -s ese -u ${instance} -p DB2_${instance} ${instance}"
   else
      /opt/IBM/db2/V$db2version/instance/db2icrt -s ese -u ${instance} -p DB2_${instance} ${instance}
   fi
   if [ $? -gt 0 ]; then
      print -u2 -- "DB2 Instance create failed cannot continue"
      exit 2
   fi
   wait_user
   
   print "============================================================================================"
   print "Creating LDAP instance $instance"
   print "============================================================================================" 
   if [ "$debug" = 1 ]; then
      debug "/opt/IBM/ldap/V${version}/sbin/idsicrt -I $instance -p $port -s $secure_port -e $seed"
   else
      /opt/IBM/ldap/V${version}/sbin/idsicrt -I $instance -n -p $port -s $secure_port -e $seed
   fi
   if [ $? -gt 0 ]; then 
      print -u2 -- "LDAP instance create failed"
      exit 2
   fi 
   wait_user
   
   mkdir /logs/$instance
   mv /db2_database/$instance/idsslapd-$instance/logs/* /logs/$instance
   rm -rf /db2_database/$instance/idsslapd-$instance/logs
   ln -sf /logs/$instance /db2_database/$instance/idsslapd-$instance/logs
   
   
   print "============================================================================================"
   print "Adding LDAP root user: $root_dn"
   print "============================================================================================" 
   if [ "$debug" = 1 ]; then
      debug "/opt/IBM/ldap/V${version}/sbin/idsdnpw -q -I $instance -u $root_dn -p $root_dn_pw"
   else
      /opt/IBM/ldap/V${version}/sbin/idsdnpw -q -I $instance -n -u $root_dn -p $root_dn_pw
   fi
   if [ $? -gt 0 ]; then 
      print -u2 -- "LDAP add root user failed"
      exit 2
   fi 
  
   wait_user
   print "============================================================================================"
   print "Configuring LDAP database"
   print "============================================================================================" 
   if [ "$debug" = 1 ]; then
      debug "/opt/IBM/ldap/V${version}/sbin/idscfgdb -I $instance -a $instance -l $BASEDIR -t $instance -w $instance_pw"
   else
      print "/opt/IBM/ldap/V${version}/sbin/idscfgdb -I $instance -a $instance -l $BASEDIR -t $instance -w \"$instance_pw\""
      /opt/IBM/ldap/V${version}/sbin/idscfgdb -I $instance -n -a $instance -l $BASEDIR -t $instance -w "$instance_pw"
   fi
   if [ $? -gt 0 ]; then 
      print -u2 -- "LDAP config database failed"
      exit 2
   fi 
   wait_user
   
   print "============================================================================================"
   print "Adding LDAP suffix o=ibm,c=us"
   print "============================================================================================"
   if [ "$debug" = 1 ]; then
      debug "/opt/IBM/ldap/V${version}/sbin/idscfgsuf -I $instance -s \"o=ibm,c=us\""
   else
      /opt/IBM/ldap/V${version}/sbin/idscfgsuf -I $instance -n -s "o=ibm,c=us"
   fi
   if [ $? -gt 0 ]; then 
      print -u2 -- "LDAP add o=ibm c=us failed"
      exit 2
   fi 
   wait_user
   
   if [ -n "$eischema" ]; then
      print "============================================================================================"
      print "Installing EI schema"
      print "============================================================================================"
   
      cd ${BASEDIR}/idsslapd-$instance/etc
      tar="$LFSTOOLS/schemas/v${version}schemas.tar"
      if [ -e "$tar" ]; then
         if [ "$debug" = 1 ]; then
            debug "tar -xf $tar"
         else
            tar -xf $tar
         fi
      else
         print -u2 -- "#### Cannot install schemas missing $tar"
      fi
      wait_user
   fi
   
   
   print "============================================================================================"
   print "Customising LDAP config"
   print "============================================================================================"
 
   sed -e 's/^ibm-slapdPwEncryption:.*$/ibm-slapdPwEncryption: sha/g' \
       -e 's/^ibm-slapdDbUser:.*$/ibm-slapdDbUser: $dbuser/g' \
       -e 's/^ibm-slapdDbUser:.*$/ibm-slapdDbUserPW: $dbuser_pw/g' \
       -e 's/^ibm-slapdSizeLimit:.*$/ibm-slapdSizeLimit: 0/g' \
       -e 's/^ibm-slapdAllowAnon:.*$/ibm-slapdAllowAnon: FALSE/g' \
       -e 's/^ibm-slapdWriteTimeout:.*$/ibm-slapdWriteTimeout: 120/g' \
       -e "s/^ibm-slapdServerId:.*$/ibm-slapdServerId: ${HOSTNAME}/g"  $BASEDIR/idsslapd-$instance/etc/ibmslapd.conf >/tmp/$$.conf
 
   mv /tmp/$$.conf $BASEDIR/idsslapd-$instance/etc/ibmslapd.conf
   wait_user
   
   if [ -n "$ssl" ]; then
      print "============================================================================================"
      print "Enabling SSL / LDAPS"
      print "============================================================================================"
      if [ "$debug" = 1 ]; then
         debug "cp /$LFSTOOLS/etc/ldapauth.* ${BASEDIR}/idsslapd-$instance/etc/"
      else
         cp $LFSTOOLS/etc/ldapauth.* ${BASEDIR}/idsslapd-$instance/etc/
      fi
      sed -e "s%^ibm-slapdSecurity:.*$%ibm-slapdSecurity: $ssl%g" \
         -e "s%^ibm-slapdSslAuth:.*$%ibm-slapdSslAuth: serverclientauth%g" \
         -e "s%^ibm-slapdSslCertificate:.*$%ibm-slapdSslCertificate: EI CA signed cert for ldapauth%g" \
         -e "s%^ibm-slapdSslKeyDatabase:.*%ibm-slapdSslKeyDatabase: ${BASEDIR}/idsslapd-$instance/etc/ldapauth.kdb%g" $BASEDIR/idsslapd-$instance/etc/ibmslapd.conf >/tmp/$$.conf
       
       mv /tmp/$$.conf $BASEDIR/idsslapd-$instance/etc/ibmslapd.conf
   fi
   
   chmod -R o+rx $BASEDIR/idsslapd-$instance
   chown $instance:$dbgroup $BASEDIR/idsslapd-$instance/etc/*

   #=======================
   # lock down the users
   #=======================
   chsec -f /etc/security/user -a maxage=0 -s ${dbuser}
   chuser shell=/bin/false $dbuser
   if ! grep -q ${dbuser} /etc/ftpusers; then 
      echo $dbuser >>/etc/ftpusers
   fi
   
   chsec -f /etc/security/user -a maxage=0 -s ${instance}
   chsec -f /etc/security/user -a login=false -s ${instance}
   chsec -f /etc/security/user -a rlogin=false -s ${instance}
   if ! grep -q ${instance} /etc/ftpusers; then 
      echo $instance >>/etc/ftpusers
   fi
   
   print -- "$YELLOW if you intend to replicate this server or load ldif data from another server"
   print -- "be sure to copy the ibmslapddir.ksf from the existing server to "
   print -- "\t$BASEDIR/idsslapd-$instance/etc"
   print -- "before you start this server$RESET"
fi
