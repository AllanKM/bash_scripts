#!/bin/ksh

function stop_httpd_verification_61
{
   typeset SERVERROOT=$1 TOOLSDIR=$2 SLEEP=$3 PRODUCT=$4 RETURN_CODE=0 OS=`uname`
   typeset -i INDENT=$5

   if [[ $SERVERROOT == "" ]]; then
      echo "Function stop_httpd_verification_61 needs SERVERROOT defined"
      exit 1
   fi

   if [[ $TOOLSDIR == "" ]]; then
      echo "Function stop_httpd_verification_61 needs TOOLSDIR defined"
      exit 1
   fi

   if [[ $SLEEP == "" ]]; then
      echo "Function stop_httpd_verification_61 needs SLEEP defined"
      exit 1
   fi

   if [[ $PRODUCT != "ihs" && $PRODUCT != "plug" ]]; then
      echo "Function stop_httpd_verification_61 needs PRODUCT defined"
      echo "Acceptable values for PRODUCT are \"ihs\" or \"plug\""
      exit 1
   fi

   if [[ $INDENT == "" ]]; then
      INDENT=0
   fi

   case $OS in
      AIX)    PS="ps -ef" ;;
      Linux)  PS="ps --cols 1000 -ef" ;;
   esac 

   NUMPROCS=`$PS | grep -v grep | grep httpd | grep root | grep ${SERVERROOT}/ | wc -l | sed s/\ //g`
   if [[ $INDENT -gt 0 ]]; then
      printf "%-${INDENT}c" " "
   fi
   echo "$NUMPROCS processes found running"

   if [[ $NUMPROCS -gt 0 ]]; then
      if [[ -f ${SERVERROOT}/bin/apachectl ]]; then
         if [[ $INDENT -gt 0 ]]; then
            printf "%-${INDENT}c" " "
         fi
         echo "Stopping IHS"
         ${TOOLSDIR}/../bin/rc.ihs stop
      else
         if [[ $INDENT -gt 0 ]]; then
            printf "%-${INDENT}c" " "
         fi
         echo "IHS is running"
         if [[ $INDENT -gt 0 ]]; then
            printf "%-${INDENT}c" " "
         fi
         echo "Can not stop IHS, installation incomplete"
         return 2
      fi
   elif [[ $NUMPROCS -eq 0 ]]; then
      if [[ $INDENT -gt 0 ]]; then
         printf "%-${INDENT}c" " "
      fi
      echo "IHS is not running"
   else
      if [[ $INDENT -gt 0 ]]; then
         printf "%-${INDENT}c" " "
      fi
      echo "Can not determine if IHS is running or not"
      if [[ $INDENT -gt 0 ]]; then
         printf "%-${INDENT}c" " "
      fi
      echo "Aborting install"
      return 2
   fi
   echo ""
}

function stop_httpd_verification_70
{
   typeset SERVERROOT=$1 TOOLSDIR=$2 SLEEP=$3 PRODUCT=$4 RETURN_CODE=0 OS=`uname`
   typeset -i INDENT=$5

   if [[ $SERVERROOT == "" ]]; then
      echo "Function stop_httpd_verification_70 needs SERVERROOT defined"
      exit 1
   fi
   if [[ $TOOLSDIR == "" ]]; then
      echo "Function stop_httpd_verification_70 needs TOOLSDIR defined"
      exit 1
   fi

   if [[ $SLEEP == "" ]]; then
      echo "Function stop_httpd_verification_70 needs SLEEP defined"
      exit 1
   fi

   if [[ $PRODUCT != "ihs" && $PRODUCT != "plug" ]]; then
      echo "Function stop_httpd_verification_70 needs PRODUCT defined"
      echo "Acceptable values for PRODUCT are \"ihs\" or \"plug\""
      exit 1
   fi

   if [[ $INDENT == "" ]]; then
      INDENT=0
   fi

   case $OS in
      AIX)    PS="ps -ef" ;;
      Linux)  PS="ps --cols 1000 -ef" ;;
   esac 

   NUMPROCS=`$PS | grep -v grep | grep httpd | grep root | grep ${SERVERROOT}/ | wc -l | sed s/\ //g`
   if [[ $INDENT -gt 0 ]]; then
      printf "%-${INDENT}c" " "
   fi
   echo "$NUMPROCS processes found running"

   if [[ $NUMPROCS -gt 0 ]]; then
      if [[ -f ${SERVERROOT}/bin/apachectl ]]; then
         if [[ $INDENT -gt 0 ]]; then
            printf "%-${INDENT}c" " "
         fi
         echo "Stopping IHS"
         ${TOOLSDIR}/../bin/rc.ihs stop
      else
         if [[ $INDENT -gt 0 ]]; then
            printf "%-${INDENT}c" " "
         fi
         echo "IHS is running"
         if [[ $INDENT -gt 0 ]]; then
            printf "%-${INDENT}c" " "
         fi
         echo "Can not stop IHS, installation incomplete"
         return 2
      fi
   elif [[ $NUMPROCS -eq 0 ]]; then
      if [[ $INDENT -gt 0 ]]; then
         printf "%-${INDENT}c" " "
      fi
      echo "IHS is not running"
   else
      if [[ $INDENT -gt 0 ]]; then
         printf "%-${INDENT}c" " "
      fi
      echo "Can not determine if IHS is running or not"
      if [[ $INDENT -gt 0 ]]; then
         printf "%-${INDENT}c" " "
      fi
      echo "Aborting install"
      return 2
   fi
   echo ""
}

function stop_httpd_verification_85
{
   typeset SERVERROOT=$1 TOOLSDIR=$2 SLEEP=$3 PRODUCT=$4 RETURN_CODE=0 OS=`uname`
   typeset -i INDENT=$5

   if [[ $SERVERROOT == "" ]]; then
      echo "Function stop_httpd_verification_85 needs SERVERROOT defined"
      exit 1
   fi
   if [[ $TOOLSDIR == "" ]]; then
      echo "Function stop_httpd_verification_85 needs TOOLSDIR defined"
      exit 1
   fi

   if [[ $SLEEP == "" ]]; then
      echo "Function stop_httpd_verification_85 needs SLEEP defined"
      exit 1
   fi

   if [[ $PRODUCT != "ihs" && $PRODUCT != "plug" ]]; then
      echo "Function stop_httpd_verification_85 needs PRODUCT defined"
      echo "Acceptable values for PRODUCT are \"ihs\" or \"plug\""
      exit 1
   fi

   if [[ $INDENT == "" ]]; then
      INDENT=0
   fi

   case $OS in
      AIX)    PS="ps -ef" ;;
      Linux)  PS="ps --cols 1000 -ef" ;;
   esac 

   NUMPROCS=`$PS | grep -v grep | grep httpd | grep root | grep ${SERVERROOT}/ | wc -l | sed s/\ //g`
   if [[ $INDENT -gt 0 ]]; then
      printf "%-${INDENT}c" " "
   fi
   echo "$NUMPROCS processes found running"

   if [[ $NUMPROCS -gt 0 ]]; then
      if [[ -f ${SERVERROOT}/bin/apachectl ]]; then
         if [[ $INDENT -gt 0 ]]; then
            printf "%-${INDENT}c" " "
         fi
         echo "Stopping IHS"
         ${TOOLSDIR}/../bin/rc.ihs stop
      else
         if [[ $INDENT -gt 0 ]]; then
            printf "%-${INDENT}c" " "
         fi
         echo "IHS is running"
         if [[ $INDENT -gt 0 ]]; then
            printf "%-${INDENT}c" " "
         fi
         echo "Can not stop IHS, installation incomplete"
         return 2
      fi
   elif [[ $NUMPROCS -eq 0 ]]; then
      if [[ $INDENT -gt 0 ]]; then
         printf "%-${INDENT}c" " "
      fi
      echo "IHS is not running"
   else
      if [[ $INDENT -gt 0 ]]; then
         printf "%-${INDENT}c" " "
      fi
      echo "Can not determine if IHS is running or not"
      if [[ $INDENT -gt 0 ]]; then
         printf "%-${INDENT}c" " "
      fi
      echo "Aborting install"
      return 2
   fi
   echo ""
}

function install_timer
{
   typeset SLEEP=$1

   if [[ $SLEEP == "" ]]; then
      echo "Function install_timer needs SLEEP defined"
      exit 1
   fi

   count=$SLEEP
   while [[ $count -gt 0 ]]; do
      printf "    Continuing in $count seconds         \r"
      count=`expr $count - 1`
      sleep 1
   done
   echo ""; echo ""
}

function function_error_check
{
   typeset CODE=$? FUNCTION=$1 SCRIPT_TYPE=$2

   if [[ $FUNCTION == "" ]]; then
      echo "Function function_error_check needs FUNCTION defined"
      exit 1
   fi

   if [[ $SCRIPT_TYPE != "ihs" && $SCRIPT_TYPE != "plug" && $SCRIPT_TYPE != "perms" && $SCRIPT_TYPE != "uninstall" ]]; then
      echo "Function function_error_check for $FUNCTION"
      echo "needs SCRIPT_TYPE defined"
      echo "Must be a value of \"ihs\", \"plug\", \"perms\" or \"uninstall\""
      exit 1
   fi

   if [[ $CODE -gt 0 && $CODE -lt 100 ]]; then
      echo "    Function $FUNCTION had a return code $CODE" 
      echo ""
      error_message_${SCRIPT_TYPE} $CODE
   elif [[ $CODE -eq 100 ]]; then
      return 100
   fi
}

function error_message_ihs
{
   typeset CODE=$1

   if [[ $CODE == "" ]]; then
      echo "Function error_message_ihs needs CODE defined"
      echo "Setting it to default of 2"
      echo ""
      CODE=2
   fi

   echo "/////////////////////////////////////////////////////////////////"
   echo "**********             Installation of IHS             **********"
   echo "**********  failed to complete due to errors.  Review  **********"
   echo "**********      script output for further details      **********"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit $CODE
}

function error_message_perms
{
   typeset CODE=$1

   if [[ $CODE == "" ]]; then
      echo "Function error_message_perms needs CODE defined"
      echo "Setting it to default of 2"
      echo ""
      CODE=2
   fi

   echo "/////////////////////////////////////////////////////////////////"
   echo "**********       The setting of permissions has        **********"
   echo "**********  failed to complete due to errors.  Review  **********"
   echo "**********      script output for further details      **********"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit $CODE
}

function error_message_uninstall
{
   typeset CODE=$1

   if [[ $CODE == "" ]]; then
      echo "Function error_message_perms needs CODE defined"
      echo "Setting it to default of 2"
      echo ""
      CODE=2
   fi

   echo "/////////////////////////////////////////////////////////////////"
   echo "**********             The Removal of IHS              **********"
   echo "**********  failed to complete due to errors.  Review  **********"
   echo "**********      script output for further details      **********"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit $CODE
}

function check_fs_size
{
   typeset FILESYSTEM=$1 SIZE_MB=$2 TOOLSDIR=$3
  
   if [[ $FILESYSTEM == "" ]]; then
      echo "Function check_fs_size needs FILESYSTEM defined"
      exit 1
   fi

   if [[ $SIZE_MB == "" ]]; then
      echo "Function check_fs_size needs SIZE_MB defined"
      exit 1
   fi

   if [[ $TOOLSDIR == "" ]]; then
      echo "Function check_fs_size needs TOOLSDIR defined"
      exit 1
   fi

   echo "    Sizing filesystem $FILESYSTEM"
   echo "      to at least size $PROJECT_FS_SIZE mb"
   typeset -i EXISTING_SIZE=`df -Pm | grep " $FILESYSTEM" | awk '{print $2}'`
   DELTA=$((SIZE_MB-EXISTING_SIZE))
   if [[ $DELTA -gt 0 ]]; then
      /fs/system/bin/eichfs $FILESYSTEM +${DELTA}M
      if [[ $? -gt 0 ]]; then
         echo "    The check and possible increase of $FILESYSTEM"
         echo "      Failed"
         echo ""
         return 3
      else
         echo "   Filesystem $FILESYSTEM was resized to ${SIZE_MB}M"
         echo "   from the previous size of ${EXISTING_SIZE}M"
         echo ""
      fi
   else
      echo "    Filesystem $FILESYSTEM is already sized to ${EXISTING_SIZE}M"
      echo "    which is greater or equal to the requested size of ${SIZE_MB}M"
      echo ""
   fi
}

function check_fs_avail_space
{
   typeset FILESYSTEM=$1 SIZE_MB=$2 TOOLSDIR=$3
  
   if [[ $FILESYSTEM == "" ]]; then
      echo "Function check_fs_avail_space needs FILESYSTEM defined"
      exit 1
   fi

   if [[ $SIZE_MB == "" ]]; then
      echo "Function check_fs_avail_space needs SIZE_MB defined"
      exit 1
   fi

   if [[ $TOOLSDIR == "" ]]; then
      echo "Function check_fs_avail_space needs TOOLSDIR defined"
      exit 1
   fi

   echo "Ensuring $FILESYSTEM has ${SIZE_MB}MB free"
   typeset -i EXISTING_SIZE=`df -Pm | grep " ${FILESYSTEM}$" | awk '{print $2}'`
   typeset -i AVAIL=`df -Pm | grep " ${FILESYSTEM}$" | awk '{print $4}'`
   DELTA=$((SIZE_MB-AVAIL))
   if [[ $DELTA -gt 0 ]]; then
      /fs/system/bin/eichfs $FILESYSTEM +${DELTA}M
      if [[ $? -gt 0 ]]; then
         echo "    The check and possible increase of FILESYSTEM"
         echo "      Failed"
         echo "      Aborting install"
         return 3
      else
         typeset -i NEW_SIZE=`df -Pm | grep " ${FILESYSTEM}$" | awk '{print $2}'`
         echo "   Filesystem $FILESYSTEM was resized to ${NEW_SIZE}M"
         echo "   from the previous size of ${EXISTING_SIZE}M"
         echo ""
      fi
   else
      echo "    Filesystem $FILESYSTEM has ${AVAIL}M available"
      echo "    which is greater or equal to the requested size of ${SIZE_MB}M"
      echo ""
   fi
}

os_specific_parameters_61 ()
{
   #NOTE:  Need to typeset CHMOD CHMODR XARGS FS_TABLE WASSRCDIR SYSTEM_GRP"
   #         within any script or function that calls this function.  Not"
   #         typesetting these variables within this function"
   typeset BITS=$1

   if [[ $BITS == "" ]]; then
      echo "Function os_specific_parameters_61 needs BITS defined"
      exit 1
   fi

      case `uname` in
      AIX)
         if [[ $BITS == "64" ]]; then
            WASSRCDIR="/fs/system/images/websphere/6.1/aix-64"
         else
            WASSRCDIR="/fs/system/images/websphere/6.1/aix"
         fi
         CHMOD="chmod -h"
         CHMODR="chmod -hR"
         XARGS="xargs -I{} "
         FS_TABLE="/etc/filesystems"
         SYSTEM_GRP="system"
      ;;
      Linux)
         uname -a | grep ppc
         if [[ "$?" -eq 0 ]]; then
            WASSRCDIR="/fs/system/images/websphere/6.1/linuxppc"
            if [[ $BITS == "64" ]]; then
               WASSRCDIR="/fs/system/images/websphere/6.1/linuxppc-64"
            fi
         else
            if [[ $BITS == "64" ]]; then
               echo "No 64-bit src image defined for non-ppc linux"
               echo "  exiting..."
               return 2
            else
               WASSRCDIR="/fs/system/images/websphere/6.1/linux"
            fi
         fi
         CHMOD="chmod "
         CHMODR="chmod -R "
         XARGS="xargs -i{} "
         FS_TABLE="/etc/fstab"
         SYSTEM_GRP="root"
      ;;
      *)
         print -u2 -- "${0:##*/}: `uname` not supported by this install script."
         return 2
      ;;
   esac
}

os_specific_parameters_70 ()
{
   #NOTE:  Need to typeset CHMOD CHMODR XARGS FS_TABLE WASSRCDIR SYSTEM_GRP"
   #         within any script or function that calls this function.  Not"
   #         typesetting these variables within this function"
   typeset BITS=$1

   if [[ $BITS == "" ]]; then
      echo "Function os_specific_parameters_70 needs BITS defined"
      exit 1
   fi

      case `uname` in
      AIX)
         if [[ $BITS == "64" ]]; then
            WASSRCDIR="/fs/system/images/websphere/7.0/aix-64"
         else
            WASSRCDIR="/fs/system/images/websphere/7.0/aix"
         fi
         CHMOD="chmod -h"
         CHMODR="chmod -hR"
         XARGS="xargs -I{} "
         FS_TABLE="/etc/filesystems"
         SYSTEM_GRP="system"
      ;;
      Linux)
         uname -a | grep ppc
         if [[ "$?" -eq 0 ]]; then
            WASSRCDIR="/fs/system/images/websphere/7.0/linuxppc"
            if [[ $BITS == "64" ]]; then
               WASSRCDIR="/fs/system/images/websphere/7.0/linuxppc-64"
            fi
         else
            if [[ $BITS == "64" ]]; then
               echo "No 64-bit src image defined for non-ppc linux"
               echo "  exiting..."
               return 2
            else
               WASSRCDIR="/fs/system/images/websphere/7.0/linux"
            fi
         fi
         CHMOD="chmod "
         CHMODR="chmod -R "
         XARGS="xargs -i{} "
         FS_TABLE="/etc/fstab"
         SYSTEM_GRP="root"
      ;;
      *)
         print -u2 -- "${0:##*/}: `uname` not supported by this install script."
         return 2
      ;;
   esac
}

os_specific_parameters_85 ()
{
   #NOTE:  Need to typeset CHMOD CHMODR XARGS FS_TABLE WASSRCDIR SYSTEM_GRP"
   #         within any script or function that calls this function.  Not"
   #         typesetting these variables within this function"

      WASSRCDIR="/fs/system/images/websphere/8.5/supplements"
      
      case `uname` in
      AIX)
         
         CHMOD="chmod -h"
         CHMODR="chmod -hR"
         XARGS="xargs -I{} "
         FS_TABLE="/etc/filesystems"
         SYSTEM_GRP="system"
      ;;
      Linux)
         CHMOD="chmod "
         CHMODR="chmod -R "
         XARGS="xargs -i{} "
         FS_TABLE="/etc/fstab"
         SYSTEM_GRP="root"
      ;;
      *)
         print -u2 -- "${0:##*/}: `uname` not supported by this install script."
         return 2
      ;;
   esac
}

function set_base_ihs_perms_61
{
   typeset DESTDIR=$1 TOOLSDIR=$2 PRODUCT_TXT CODE CHMOD CHMODR XARGS FS_TABLE WASSRCDIR SYSTEM_GRP
   typeset HTTPLOG=`echo ${DESTDIR} | cut -d"/" -f3`
   typeset -l PRODUCT=$3

   if [[ $DESTDIR == "" ]]; then
      echo "Function set_base_ihs_perms_61 needs DESTDIR defined"
      exit 1
   fi

   if [[ $TOOLSDIR == "" ]]; then
      echo "Function set_base_ihs_perms_61 needs TOOLSDIR defined"
      exit 1
   fi 

   if [[ $PRODUCT == "" ]]; then
      echo "Function set_base_ihs_perms_61 needs PRODUCT defined"
      echo "Parameter PRODUCT needs to be one of the following:"
      echo "  ihs, plugin, or all"
      exit 1
   elif [[ $PRODUCT == "all" ]]; then
      PRODUCT_TXT="all IHS/SDK Products Installed"
   elif [[ $PRODUCT == "ihs" ]]; then
      PRODUCT_TXT="Base IHS Install"
   elif [[ $PRODUCT == "plugin" ]]; then
      PRODUCT_TXT="WAS Plugin Install"
   else
      echo "Parameter PRODUCT needs to be one of the following:"
      echo "  ihs, plugin, or all" 
      exit 1
   fi 

   echo "---------------------------------------------------------------"
   echo "      Set Ownership and Permissions for"
   echo "          $PRODUCT_TXT"
   echo "      At serverroot"
   echo "          $DESTDIR"
   echo "---------------------------------------------------------------"
   echo ""

   # Verify IHS is installed or exit if not
   if [[ ( $PRODUCT == "all" || $PRODUCT == "ihs" ) && ! -f ${DESTDIR}/bin/httpd ]]; then
      echo "Base IHS install not detected"
      echo "Aborting set perms process"
      exit 1
   fi

   # Verify WAS Plugin is installed or exit if not if the request is for plug
   if [ $PRODUCT == "plugin" -a ! -f ${DESTDIR}/Plugins/bin/mod_was_ap20_http.so -a ! -f ${DESTDIR}/Plugins61*/bin/mod_was_ap20_http.so -a ! -f ${DESTDIR}/Plugins70*/bin/mod_was_ap22_http.so ]; then
      echo "WAS Plugin install not detected"
      echo "Aborting set perms process"
      exit 1
   fi

   os_specific_parameters_61 32
   function_error_check os_specific_parameters_61 perms

   echo "Adding ids as needed"
   echo "Checking existance of apps group creating it as needed"
   grep apps /etc/group > /dev/null 2>&1
   if [[ $? -ne 0 ]]; then
      /fs/system/tools/auth/bin/mkeigroup -r local -f apps
      if [[ $? -gt 0 ]]; then
         echo "/////////////////////////////////////////////////////////////////"
         echo "**********        Execution of mkeigroup Failed        **********"
         echo "/////////////////////////////////////////////////////////////////"
         exit 3
      fi
   else
      echo "   Group apps already exist"
   fi

   echo "Checking existance of webinst user creating it as needed"
   id webinst > /dev/null 2>&1
   if [[  $? -ne 0 ]]; then
      /fs/system/tools/auth/bin/mkeiuser  -r local -f webinst apps
      if [[ $? -gt 0 ]]; then
         echo "/////////////////////////////////////////////////////////////////"
         echo "**********        Execution of mkeiuser Failed         **********"
         echo "/////////////////////////////////////////////////////////////////"
         exit 3
      fi
   else
      echo "   ID webinst already exist"
   fi

   if [[ -d /logs/${HTTPLOG} ]]; then
      if [[ -L /logs/${HTTPLOG} ]]; then
         echo "/logs/${HTTPLOG} is a symlink, setting ownership of link"
         chown -h webinst.eiadm /logs/${HTTPLOG}
         HTTPLOG=`ls -l /logs/${HTTPLOG} | awk {'print $NF'}`
         HTTPLOG=`echo $HTTPLOG | awk -F '/' {'print $NF'}`
         echo "Real dir is /logs/${HTTPLOG}"
      fi
      if [[ -d /logs/${HTTPLOG} && ! -L /logs/${HTTPLOG} ]]; then
         echo "Setting permissions on /logs/${HTTPLOG}"
         chown -h webinst.eiadm /logs/${HTTPLOG}
         $CHMOD 2750 /logs/${HTTPLOG}
         if [[ $PRODUCT == "all" ]]; then
            if [ -d /logs/${HTTPLOG}/Plugins* ]; then
               chown -h webinst.eiadm /logs/${HTTPLOG}/Plugins*
               $CHMOD 2750 /logs/${HTTPLOG}/Plugins*
            fi
            find /logs/$HTTPLOG | egrep "/logs/${HTTPLOG}/install|/logs/${HTTPLOG}/update|/logs/${HTTPLOG}/uninstall|/logs/${HTTPLOG}/Plugins.*/install|/logs/${HTTPLOG}/Plugins.*/update|/logs/${HTTPLOG}/Plugins.*/uninstall|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS chown -h root.$SYSTEM_GRP {}
            find /logs/$HTTPLOG -type d | egrep "/logs/${HTTPLOG}/install|/logs/${HTTPLOG}/update|/logs/${HTTPLOG}/uninstall|/logs/${HTTPLOG}/Plugins.*/install|/logs/${HTTPLOG}/Plugins.*/update|/logs/${HTTPLOG}/Plugins.*/uninstall|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS chmod 0775 {}
            find /logs/$HTTPLOG -type f | egrep "/logs/${HTTPLOG}/install|/logs/${HTTPLOG}/update|/logs/${HTTPLOG}/uninstall|/logs/${HTTPLOG}/Plugins.*/install|/logs/${HTTPLOG}/Plugins.*/update|/logs/${HTTPLOG}/Plugins.*/uninstall|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS $CHMOD 0664 {}
         elif [[ $PRODUCT == "ihs" ]]; then
            find /logs/$HTTPLOG | egrep "/logs/${HTTPLOG}/install|/logs/${HTTPLOG}/update|/logs/${HTTPLOG}/uninstall|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS chown -h root.$SYSTEM_GRP {}
            find /logs/$HTTPLOG -type d | egrep "/logs/${HTTPLOG}/install|/logs/${HTTPLOG}/update|/logs/${HTTPLOG}/uninstall|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS $CHMOD 0775 {}
            find /logs/$HTTPLOG -type f | egrep "/logs/${HTTPLOG}/install|/logs/${HTTPLOG}/update|/logs/${HTTPLOG}/uninstall|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS $CHMOD 0664 {}
         elif [[ $PRODUCT == "plugin" ]]; then
            if [ -d /logs/${HTTPLOG}/Plugins* ]; then
               chown -h webinst.eiadm /logs/${HTTPLOG}/Plugins*
               $CHMOD 2750 /logs/${HTTPLOG}/Plugins*
            fi
            find /logs/$HTTPLOG | egrep "/logs/${HTTPLOG}/Plugins.*/install|/logs/${HTTPLOG}/Plugins.*/update|/logs/${HTTPLOG}/Plugins.*/uninstall|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS chown -h root.$SYSTEM_GRP {}
            find /logs/$HTTPLOG -type d | egrep "/logs/${HTTPLOG}/Plugins.*/install|/logs/${HTTPLOG}/Plugins.*/update|/logs/${HTTPLOG}/Plugins.*/uninstall|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS $CHMOD 0775 {}
            find /logs/$HTTPLOG -type f | egrep "/logs/${HTTPLOG}/Plugins.*/install|/logs/${HTTPLOG}/Plugins.*/update|/logs/${HTTPLOG}/Plugins.*/uninstall|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS $CHMOD 0664 {}
         fi
      else
         echo "/logs/$HTTPLOG does not exist on this node as a real dir"
      fi
   else
      echo "Can not find log dir for IHS install $HTTPLOG on this node"
   fi
   echo "Setting base ownership and permissions on $DESTDIR"
   if [[ $PRODUCT == "all" || $PRODUCT == "ihs" ]]; then
      chown root.eiadm $DESTDIR
      ls -1 $DESTDIR | egrep -v "UpdateInstaller|Plugins.*" | $XARGS chown -hR root.eiadm $DESTDIR/{}
      $CHMOD 0775 $DESTDIR
      ls -1 $DESTDIR | egrep -v "logs|icons|htdocs|UpdateInstaller|Plugins.*" | $XARGS $CHMODR 0770 $DESTDIR/{}
      find $DESTDIR -type d | egrep "${DESTDIR}\/icons|${DESTDIR}\/htdocs" | $XARGS $CHMOD 0775 {}  
      find $DESTDIR -type f | egrep "${DESTDIR}\/icons|${DESTDIR}\/htdocs" | $XARGS $CHMOD 0664 {}  
   fi
   if [[ $PRODUCT == "all" || $PRODUCT == "ihs" ]]; then
      echo "Setting specific permissions in $DESTDIR"
      $CHMOD 0660 ${DESTDIR}/LICENSE.txt ${DESTDIR}/version.signature

      if [[ -d ${DESTDIR}/GSKitImage ]]; then
         echo "    Setting specific permissions in GSKitImage subdir"
         find ${DESTDIR}/GSKitImage/* | grep -v gskit.sh | $XARGS $CHMOD 0660 {}
      fi
   
      if [[ -d ${DESTDIR}/bin ]]; then
         echo "    Setting specific permissions in bin subdir"
         $CHMOD 0660 ${DESTDIR}/bin/envvars ${DESTDIR}/bin/envvars-std
      fi

      if [[ -d ${DESTDIR}/build ]]; then
         echo "    Setting specific permissions in build subdir"
         $CHMOD 0660 ${DESTDIR}/build/*
         $CHMOD 0770 ${DESTDIR}/build/instdso.sh ${DESTDIR}/build/libtool
      fi

      if [[ -d ${DESTDIR}/codepages ]]; then
         echo "    Setting specific permissions in codepages subdir"
         $CHMOD 0660 ${DESTDIR}/codepages/*
      fi

      if [[ -d ${DESTDIR}/conf ]]; then
         echo "    Setting specific permissions in conf subdir"
         $CHMOD 0660 ${DESTDIR}/conf/*
      fi

      if [[ -d ${DESTDIR}/error ]]; then
         echo "    Setting specific permissions in error subdir"
         $CHMOD 0660 ${DESTDIR}/error/*
         $CHMOD 0770 ${DESTDIR}/error/include
         $CHMOD 0660 ${DESTDIR}/error/include/*
      fi

      if [[ -d ${DESTDIR}/example_module ]]; then
         echo "    Setting specific permissions in example_module subdir"
         $CHMOD 0660 ${DESTDIR}/example_module/*
      fi

      if [[ -d ${DESTDIR}/include ]]; then
         echo "    Setting specific permissions in include subdir"
         $CHMOD 0660 ${DESTDIR}/include/*
      fi

      if [[ -d ${DESTDIR}/java ]]; then
         echo "    Setting specific permissions in java subdir"
         if [[ -f ${DESTDIR}/java/COPYRIGHT ]]; then
            $CHMOD 0660 ${DESTDIR}/java/COPYRIGHT
         fi
         if [[ -f ${DESTDIR}/java/copyright ]]; then
            $CHMOD 0660 ${DESTDIR}/java/copyright
         fi
         if [[ -d ${DESTDIR}/java/docs ]]; then
            find ${DESTDIR}/java/docs/* -type f -exec $CHMOD 0660 {} \;
         fi
         find ${DESTDIR}/java/jre/* -type f -exec $CHMOD 0660 {} \;
         $CHMODR 0770 ${DESTDIR}/java/jre/bin
      fi

      if [[ -d ${DESTDIR}/lafiles ]]; then
         echo "    Setting specific permissions in lafiles subdir"
         $CHMOD 0660 ${DESTDIR}/lafiles/*
      fi

      if [[ -d ${DESTDIR}/lib ]]; then
         echo "    Setting specific permissions in lib subdir"
         $CHMOD 0660 ${DESTDIR}/lib/*
      fi

      if [[ -d ${DESTDIR}/license ]]; then
         echo "    Setting specific permissions in license subdir"
         $CHMOD 0660 ${DESTDIR}/license/*
      fi

      if [[ -d ${DESTDIR}/man ]]; then
         echo "    Setting specific permissions in man subdir"
         find ${DESTDIR}/man/* -type f -exec $CHMOD 0660 {} \;
      fi

      if [[ -d ${DESTDIR}/modules ]]; then
         echo "    Setting specific permissions in modules subdir"
         $CHMOD 0660 ${DESTDIR}/modules/*
      fi

      if [[ -d ${DESTDIR}/properties ]]; then
         echo "    Setting specific permissions in properties subdir"
         find ${DESTDIR}/properties/* -type f -exec $CHMOD 0660 {} \;
      fi

      if [[ -d ${DESTDIR}/readme ]]; then
         echo "    Setting specific permissions in readme subdir"
         $CHMOD 0660 ${DESTDIR}/readme/*
      fi

      if [[ -d ${DESTDIR}/uninstall ]]; then
         echo "    Setting specific permissions in uninstall subdir"
         find ${DESTDIR}/uninstall/* -type f -exec $CHMOD 0660 {} \;
         $CHMOD 0770 ${DESTDIR}/uninstall/uninstall
         $CHMODR 0770 ${DESTDIR}/uninstall/java/bin
      fi
   fi

   if [[ $PRODUCT == "all" || $PRODUCT == "plugin" ]]; then
      PLUGIN_LIST=`ls -d ${DESTDIR}/Plugins* 2> /dev/null`
      for PLUGDIR in $PLUGIN_LIST
      do
         case $PLUGDIR in
            ${DESTDIR}/Plugins)
               set_plugin_perms
            ;; 
            ${DESTDIR}/Plugins61*)
               set_plugin61_perms $PLUGDIR
            ;; 
            ${DESTDIR}/Plugins70*)
               set_plugin70_perms $PLUGDIR
            ;;
            *)
               echo "Plugin dir detected that is not supported"
               echo "  by this ownership and permissions"
               echo "  verification script"
            ;;
         esac
      done
   fi

   if [[ -d ${DESTDIR}/UpdateInstaller ]]; then
      echo "Setting specific permissions in ${DESTDIR}/UpdateInstaller"
      chown -hR root.eiadm ${DESTDIR}/UpdateInstaller
      $CHMODR 0770 ${DESTDIR}/UpdateInstaller
      $CHMOD 0660 ${DESTDIR}/UpdateInstaller/update.jar ${DESTDIR}/UpdateInstaller/version.txt

      echo "    Setting specific permissions in bin subdir"
      find ${DESTDIR}/UpdateInstaller/bin/jni/* -type f -exec $CHMOD  0660 {} \;
      
      echo "    Setting specific permissions in doc subdir"
      find ${DESTDIR}/UpdateInstaller/docs/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in framework subdir"
      find ${DESTDIR}/UpdateInstaller/framework/* -type f -exec $CHMOD 0660 {} \;
      $CHMOD 0770 ${DESTDIR}/UpdateInstaller/framework/utils/detectprocess.sh

      echo "    Setting specific permissions in java subdir"
      if [[ -f ${DESTDIR}/UpdateInstaller/java/COPYRIGHT ]]; then
         $CHMOD 0660 ${DESTDIR}/UpdateInstaller/java/COPYRIGHT
      fi
      if [[ -f ${DESTDIR}/UpdateInstaller/java/copyright ]]; then
         $CHMOD 0660 ${DESTDIR}/UpdateInstaller/java/copyright
      fi
      if [[ -f ${DESTDIR}/UpdateInstaller/java/notices.txt ]]; then
         $CHMOD 0660 ${DESTDIR}/UpdateInstaller/java/notices.txt
      fi
      if [[ -f ${DESTDIR}/UpdateInstaller/java/docs/IBMJAVASDK0606.SYS2 ]]; then
         $CHMOD 0660 ${DESTDIR}/UpdateInstaller/java/docs/IBMJAVASDK0606.SYS2
      fi
      if [[ -f ${DESTDIR}/UpdateInstaller/java/docs/autorun.inf ]]; then
         $CHMOD 0660 ${DESTDIR}/UpdateInstaller/java/docs/autorun.inf
      fi
      if [[ -f ${DESTDIR}/UpdateInstaller/java/docs/launchpad.ini ]]; then
         $CHMOD 0660 ${DESTDIR}/UpdateInstaller/java/docs/launchpad.ini
      fi
      find ${DESTDIR}/UpdateInstaller/java/docs/content/* -type f -exec $CHMOD 0660 {} \;
      find ${DESTDIR}/UpdateInstaller/java/docs/* -type f | egrep "\.js$|\.html$|\.htm$|\.properties| \.css$" | $XARGS $CHMOD 0660 {}
      find ${DESTDIR}/UpdateInstaller/java/jre/lib/* -type f -exec $CHMOD 0660 {} \;
      find ${DESTDIR}/UpdateInstaller/java/jre/plugin/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in lafiles subdir"
      $CHMOD 0660 ${DESTDIR}/UpdateInstaller/lafiles/*

      echo "    Setting specific permissions in lib subdir"
      $CHMOD 0660 ${DESTDIR}/UpdateInstaller/lib/*

      echo "    Setting specific permissions in maintenance subdir"
      if [[ `ls ${DESTDIR}/UpdateInstaller/maintenance| wc -l` -gt 0 ]]; then
         $CHMOD 0660 ${DESTDIR}/UpdateInstaller/maintenance/*
      fi

      echo "    Setting specific permissions in properties subdir"
      find ${DESTDIR}/UpdateInstaller/properties/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in responsefiles subdir"
      $CHMOD 0660 ${DESTDIR}/UpdateInstaller/responsefiles/*

      echo "    Setting specific permissions in uninstall subdir"
      find ${DESTDIR}/UpdateInstaller/uninstall/* -type f -exec $CHMOD 0660 {} \;
      $CHMOD 0770 ${DESTDIR}/UpdateInstaller/uninstall/uninstall
      $CHMODR 0770 ${DESTDIR}/UpdateInstaller/uninstall/java/bin
   fi
 
   if [[ $PRODUCT == "all" || $PRODUCT == "ihs" ]]; then
      if [[ -f /opt/HPODS/LCS/bin/eiRotate ]]; then
         echo "Setting perms on eiRotate"
         $CHMOD 0755 /opt/HPODS/LCS/bin/eiRotate
      fi
   fi 
}

function set_base_ihs_perms_70
{
   typeset DESTDIR=$1 TOOLSDIR=$2 PRODUCT_TXT CODE CHMOD CHMODR XARGS FS_TABLE WASSRCDIR SYSTEM_GRP
   typeset HTTPLOG=`echo ${DESTDIR} | cut -d"/" -f3`
   typeset -l PRODUCT=$3

   if [[ $DESTDIR == "" ]]; then
      echo "Function set_base_ihs_perms_70 needs DESTDIR defined"
      exit 1
   fi

   if [[ $TOOLSDIR == "" ]]; then
      echo "Function set_base_ihs_perms_70 needs TOOLSDIR defined"
      exit 1
   fi 

   if [[ $PRODUCT == "" ]]; then
      echo "Function set_base_ihs_perms_70 needs PRODUCT defined"
      echo "Parameter PRODUCT needs to be one of the following:"
      echo "  ihs, plugin, or all"
      exit 1
   elif [[ $PRODUCT == "all" ]]; then
      PRODUCT_TXT="all IHS/SDK Products Installed"
   elif [[ $PRODUCT == "ihs" ]]; then
      PRODUCT_TXT="Base IHS Install"
   elif [[ $PRODUCT == "plugin" ]]; then
      PRODUCT_TXT="WAS Plugin Install"
   else
      echo "Parameter PRODUCT needs to be one of the following:"
      echo "  ihs, plugin, or all" 
      exit 1
   fi 

   echo "---------------------------------------------------------------"
   echo "      Set Ownership and Permissions for"
   echo "          $PRODUCT_TXT"
   echo "      At serverroot"
   echo "          $DESTDIR"
   echo "---------------------------------------------------------------"
   echo ""

   # Verify IHS is installed or exit if not
   if [[ ( $PRODUCT == "all" || $PRODUCT == "ihs" ) && ! -f ${DESTDIR}/bin/httpd ]]; then
      echo "Base IHS install not detected"
      echo "Aborting set perms process"
      exit 1
   fi

   # Verify WAS Plugin is installed or exit if not if the request is for plug
   if [ $PRODUCT == "plugin" -a ! -f ${DESTDIR}/Plugins/bin/mod_was_ap20_http.so -a ! -f ${DESTDIR}/Plugins70*/bin/mod_was_ap22_http.so ]; then
      echo "WAS Plugin install not detected"
      echo "Aborting set perms process"
      exit 1
   fi

   os_specific_parameters_70 32
   function_error_check os_specific_parameters_70 perms

   echo "Adding ids as needed"
   echo "Checking existance of apps group creating it as needed"
   grep apps /etc/group > /dev/null 2>&1
   if [[ $? -ne 0 ]]; then
      /fs/system/tools/auth/bin/mkeigroup -r local -f apps
      if [[ $? -gt 0 ]]; then
         echo "/////////////////////////////////////////////////////////////////"
         echo "**********        Execution of mkeigroup Failed        **********"
         echo "/////////////////////////////////////////////////////////////////"
         exit 3
      fi
   else
      echo "   Group apps already exist"
   fi

   echo "Checking existance of webinst user creating it as needed"
   id webinst > /dev/null 2>&1
   if [[  $? -ne 0 ]]; then
      /fs/system/tools/auth/bin/mkeiuser  -r local -f webinst apps
      if [[ $? -gt 0 ]]; then
         echo "/////////////////////////////////////////////////////////////////"
         echo "**********        Execution of mkeiuser Failed         **********"
         echo "/////////////////////////////////////////////////////////////////"
         exit 3
      fi
   else
      echo "   ID webinst already exist"
   fi

   if [[ -d /logs/${HTTPLOG} ]]; then
      if [[ -L /logs/${HTTPLOG} ]]; then
         echo "/logs/${HTTPLOG} is a symlink, setting ownership of link"
         chown -h webinst.eiadm /logs/${HTTPLOG}
         HTTPLOG=`ls -l /logs/${HTTPLOG} | awk {'print $NF'}`
         HTTPLOG=`echo $HTTPLOG | awk -F '/' {'print $NF'}`
         echo "Real dir is /logs/${HTTPLOG}"
      fi
      if [[ -d /logs/${HTTPLOG} && ! -L /logs/${HTTPLOG} ]]; then
         echo "Setting permissions on /logs/${HTTPLOG}"
         chown -h webinst.eiadm /logs/${HTTPLOG}
         $CHMOD 2750 /logs/${HTTPLOG}
         if [[ $PRODUCT == "all" ]]; then
            if [ -d /logs/${HTTPLOG}/Plugins* ]; then
               chown -h webinst.eiadm /logs/${HTTPLOG}/Plugins*
               $CHMOD 2750 /logs/${HTTPLOG}/Plugins*
            fi
            find /logs/$HTTPLOG | egrep "/logs/${HTTPLOG}/install|/logs/${HTTPLOG}/update|/logs/${HTTPLOG}/uninstall|/logs/${HTTPLOG}/Plugins/install|/logs/${HTTPLOG}/Plugins/update|/logs/${HTTPLOG}/Plugins/uninstall|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS chown -h root.$SYSTEM_GRP {}
            find /logs/$HTTPLOG -type d | egrep "/logs/${HTTPLOG}/install|/logs/${HTTPLOG}/update|/logs/${HTTPLOG}/uninstall|/logs/${HTTPLOG}/Plugins/install|/logs/${HTTPLOG}/Plugins/update|/logs/${HTTPLOG}/Plugins/uninstall|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS $CHMOD 0775 {}
            find /logs/$HTTPLOG -type f | egrep "/logs/${HTTPLOG}/install|/logs/${HTTPLOG}/update|/logs/${HTTPLOG}/uninstall|/logs/${HTTPLOG}/Plugins/install|/logs/${HTTPLOG}/Plugins/update|/logs/${HTTPLOG}/Plugins/uninstall|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS $CHMOD 0664 {}
         elif [[ $PRODUCT == "ihs" ]]; then
            find /logs/$HTTPLOG | egrep "/logs/${HTTPLOG}/install|/logs/${HTTPLOG}/update|/logs/${HTTPLOG}/uninstall|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS chown -h root.$SYSTEM_GRP {}
            find /logs/$HTTPLOG -type d | egrep "/logs/${HTTPLOG}/install|/logs/${HTTPLOG}/update|/logs/${HTTPLOG}/uninstall|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS $CHMOD 0775 {}
            find /logs/$HTTPLOG -type f | egrep "/logs/${HTTPLOG}/install|/logs/${HTTPLOG}/update|/logs/${HTTPLOG}/uninstall|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS $CHMOD 0664 {}
         elif [[ $PRODUCT == "plugin" ]]; then
            if [ -d /logs/${HTTPLOG}/Plugins* ]; then
               chown -h webinst.eiadm /logs/${HTTPLOG}/Plugins*
               $CHMOD 2750 /logs/${HTTPLOG}/Plugins*
            fi
            find /logs/$HTTPLOG | egrep "/logs/${HTTPLOG}/Plugins.*/install|/logs/${HTTPLOG}/Plugins.*/update|/logs/${HTTPLOG}/Plugins.*/uninstall|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS chown -h root.$SYSTEM_GRP {}
            find /logs/$HTTPLOG -type d | egrep "/logs/${HTTPLOG}/Plugins.*/install|/logs/${HTTPLOG}/Plugins.*/update|/logs/${HTTPLOG}/Plugins.*/uninstall|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS $CHMOD 0775 {}
            find /logs/$HTTPLOG -type f | egrep "/logs/${HTTPLOG}/Plugins.*/install|/logs/${HTTPLOG}/Plugins.*/update|/logs/${HTTPLOG}/Plugins.*/uninstall|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS $CHMOD 0664 {}
         fi
      else
         echo "/logs/$HTTPLOG does not exist on this node as a real dir"
      fi
   else
      echo "Can not find log dir for IHS install $HTTPLOG on this node"
   fi
 
   echo "Setting base ownership and permissions on $DESTDIR"
   if [[ $PRODUCT == "all" || $PRODUCT == "ihs" ]]; then
      chown root.eiadm $DESTDIR
      ls -1 $DESTDIR | egrep -v "UpdateInstaller|Plugins.*" | $XARGS chown -hR root.eiadm $DESTDIR/{}
      $CHMOD 0775 $DESTDIR
      ls -1 $DESTDIR | egrep -v "logs|cgi-bin|icons|htdocs|UpdateInstaller|Plugins.*" | $XARGS $CHMODR 0770 $DESTDIR/{}
      find $DESTDIR -type d | egrep "${DESTDIR}\/cgi-bin|${DESTDIR}\/icons|${DESTDIR}\/htdocs" | $XARGS $CHMOD 0775 {}  
      find $DESTDIR -type f | egrep "${DESTDIR}\/icons|${DESTDIR}\/htdocs" | $XARGS $CHMOD 0664 {}  
   fi

   if [[ $PRODUCT == "all" || $PRODUCT == "ihs" ]]; then
      echo "Setting specific permissions in $DESTDIR"
      $CHMOD 0660 ${DESTDIR}/version.signature

      if [[ -d ${DESTDIR}/GSKitImage ]]; then
         echo "    Setting specific permissions in GSKitImage subdir"
         find ${DESTDIR}/GSKitImage/* | grep -v gskit.sh | $XARGS $CHMOD 0660 {}
      fi
   
      if [[ -d ${DESTDIR}/bin ]]; then
         echo "    Setting specific permissions in bin subdir"
         $CHMOD 0660 ${DESTDIR}/bin/envvars ${DESTDIR}/bin/envvars-std ${DESTDIR}/bin/install/*
      fi

      if [[ -d ${DESTDIR}/build ]]; then
         echo "    Setting specific permissions in build subdir"
         $CHMOD 0660 ${DESTDIR}/build/*
         $CHMOD 0770 ${DESTDIR}/build/instdso.sh ${DESTDIR}/build/libtool ${DESTDIR}/build/mkdir.sh
      fi

      if [[ -d ${DESTDIR}/codeset ]]; then
         echo "    Setting specific permissions in codepages subdir"
         $CHMOD 0660 ${DESTDIR}/codeset/*
      fi

      if [[ -d ${DESTDIR}/conf ]]; then
         echo "    Setting specific permissions in conf subdir"
         $CHMOD 0660 ${DESTDIR}/conf/*
      fi

      if [[ -d ${DESTDIR}/error ]]; then
         echo "    Setting specific permissions in error subdir"
         $CHMOD 0660 ${DESTDIR}/error/*
         $CHMOD 0770 ${DESTDIR}/error/include
         $CHMOD 0660 ${DESTDIR}/error/include/*
      fi

      if [[ -d ${DESTDIR}/example_module ]]; then
         echo "    Setting specific permissions in example_module subdir"
         $CHMOD 0660 ${DESTDIR}/example_module/*
      fi

      if [[ -d ${DESTDIR}/gsk7 ]]; then
         echo "    Setting specific permissions in gsk7 subdir"
         $CHMOD 0660 ${DESTDIR}/gsk7/copyright
         $CHMOD 0660 ${DESTDIR}/gsk7/lib/*
         find ${DESTDIR}/gsk7/classes -type f -exec $CHMOD 0660 {} \;
         find ${DESTDIR}/gsk7/icc -type f -exec $CHMOD 0660 {} \;
      fi

      if [[ -d ${DESTDIR}/include ]]; then
         echo "    Setting specific permissions in include subdir"
         $CHMOD 0660 ${DESTDIR}/include/*
      fi

      if [[ -d ${DESTDIR}/java ]]; then
         echo "    Setting specific permissions in java subdir"
         if [[ -f ${DESTDIR}/java/COPYRIGHT ]]; then
            $CHMOD 0660 ${DESTDIR}/java/COPYRIGHT
         fi
         if [[ -f ${DESTDIR}/java/copyright ]]; then
            $CHMOD 0660 ${DESTDIR}/java/copyright
         fi
         if [[ -f ${DESTDIR}/java/notices.txt ]]; then
            $CHMOD 0660 ${DESTDIR}/java/notices.txt
         fi
         if [[ -d ${DESTDIR}/java/docs ]]; then
            find ${DESTDIR}/java/docs/* -type f -exec $CHMOD 0660 {} \;
            $CHMOD 0770 ${DESTDIR}/java/docs/launchpad.exe ${DESTDIR}/java/docs/launchpad.sh 
         fi
         find ${DESTDIR}/java/jre/* -type f -exec $CHMOD 0660 {} \;
         $CHMODR 0770 ${DESTDIR}/java/jre/bin
      fi

      if [[ -d ${DESTDIR}/lafiles ]]; then
         echo "    Setting specific permissions in lafiles subdir"
         $CHMOD 0660 ${DESTDIR}/lafiles/*
      fi

      if [[ -d ${DESTDIR}/lib ]]; then
         echo "    Setting specific permissions in lib subdir"
         $CHMOD 0660 ${DESTDIR}/lib/*
      fi

      if [[ -d ${DESTDIR}/license ]]; then
         echo "    Setting specific permissions in license subdir"
         $CHMOD 0660 ${DESTDIR}/license/*
      fi

      if [[ -d ${DESTDIR}/man ]]; then
         echo "    Setting specific permissions in man subdir"
         find ${DESTDIR}/man/* -type f -exec $CHMOD 0660 {} \;
      fi

      if [[ -d ${DESTDIR}/modules ]]; then
         echo "    Setting specific permissions in modules subdir"
         find ${DESTDIR}/modules -type f -exec $CHMOD 0660 {} \; 
      fi

      if [[ -d ${DESTDIR}/properties ]]; then
         echo "    Setting specific permissions in properties subdir"
         find ${DESTDIR}/properties/* -type f -exec $CHMOD 0660 {} \;
         $CHMOD 0770 ${DESTDIR}/properties/gskitbackup/*/gsk7/bin/*
         $CHMOD 0770 ${DESTDIR}/properties/gskitbackup/*/gsk7/private*
         $CHMOD 0660 ${DESTDIR}/properties/gskitbackup/*/gsk7/copyright
         $CHMOD 0660 ${DESTDIR}/properties/gskitbackup/*/gsk7/lib/*
         find ${DESTDIR}/properties/gskitbackup/*/gsk7/classes -type f -exec $CHMOD 0660 {} \;
         find ${DESTDIR}/properties/gskitbackup/*/gsk7/icc -type f -exec $CHMOD 0660 {} \;
      fi

      if [[ -d ${DESTDIR}/readme ]]; then
         echo "    Setting specific permissions in readme subdir"
         $CHMOD 0660 ${DESTDIR}/readme/*
      fi

      if [[ -d ${DESTDIR}/uninstall ]]; then
         echo "    Setting specific permissions in uninstall subdir"
         find ${DESTDIR}/uninstall/* -type f -exec $CHMOD 0660 {} \;
         $CHMOD 0770 ${DESTDIR}/uninstall/uninstall
      fi
   fi

   if [[ $PRODUCT == "all" || $PRODUCT == "plugin" ]]; then
      PLUGIN_LIST=`ls -d ${DESTDIR}/Plugins* 2> /dev/null`
      for PLUGDIR in $PLUGIN_LIST
      do
         case $PLUGDIR in
            ${DESTDIR}/Plugins)
               set_plugin_perms
            ;; 
            ${DESTDIR}/Plugins70*)
               set_plugin70_perms $PLUGDIR
            ;;
            *)
               echo "Plugin dir detected that is not supported"
               echo "  by this ownership and permissions"
               echo "  verification script"
            ;;
         esac
      done
   fi

   if [[ -d ${DESTDIR}/UpdateInstaller ]]; then
      echo "Setting specific permissions in ${DESTDIR}/UpdateInstaller"
      chown -hR root.eiadm ${DESTDIR}/UpdateInstaller
      $CHMODR 0770 ${DESTDIR}/UpdateInstaller
      $CHMOD 0660 ${DESTDIR}/UpdateInstaller/update.jar ${DESTDIR}/UpdateInstaller/version.txt

      echo "    Setting specific permissions in bin subdir"
      find ${DESTDIR}/UpdateInstaller/bin/jni/* -type f -exec $CHMOD  0660 {} \;
      
      echo "    Setting specific permissions in doc subdir"
      find ${DESTDIR}/UpdateInstaller/docs/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in framework subdir"
      find ${DESTDIR}/UpdateInstaller/framework/* -type f -exec $CHMOD 0660 {} \;
      $CHMOD 0770 ${DESTDIR}/UpdateInstaller/framework/utils/detectprocess.sh

      echo "    Setting specific permissions in java subdir"
      if [[ -f ${DESTDIR}/UpdateInstaller/java/COPYRIGHT ]]; then
         $CHMOD 0660 ${DESTDIR}/UpdateInstaller/java/COPYRIGHT
      fi
      if [[ -f ${DESTDIR}/UpdateInstaller/java/copyright ]]; then
         $CHMOD 0660 ${DESTDIR}/UpdateInstaller/java/copyright
      fi
      if [[ -f ${DESTDIR}/UpdateInstaller/java/notices.txt ]]; then
         $CHMOD 0660 ${DESTDIR}/UpdateInstaller/java/notices.txt
      fi
      if [[ -f ${DESTDIR}/UpdateInstaller/java/docs/IBMJAVASDK0606.SYS2 ]]; then
         $CHMOD 0660 ${DESTDIR}/UpdateInstaller/java/docs/IBMJAVASDK0606.SYS2
      fi
      if [[ -f ${DESTDIR}/UpdateInstaller/java/docs/autorun.inf ]]; then
         $CHMOD 0660 ${DESTDIR}/UpdateInstaller/java/docs/autorun.inf
      fi
      if [[ -f ${DESTDIR}/UpdateInstaller/java/docs/launchpad.ini ]]; then
         $CHMOD 0660 ${DESTDIR}/UpdateInstaller/java/docs/launchpad.ini
      fi
      find ${DESTDIR}/UpdateInstaller/java/docs/content/* -type f -exec $CHMOD 0660 {} \;
      find ${DESTDIR}/UpdateInstaller/java/docs/* -type f | egrep "\.js$|\.html$|\.htm$|\.properties| \.css$" | $XARGS $CHMOD 0660 {}
      find ${DESTDIR}/UpdateInstaller/java/jre/lib/* -type f -exec $CHMOD 0660 {} \;
      find ${DESTDIR}/UpdateInstaller/java/jre/plugin/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in lafiles subdir"
      $CHMOD 0660 ${DESTDIR}/UpdateInstaller/lafiles/*

      echo "    Setting specific permissions in lib subdir"
      $CHMOD 0660 ${DESTDIR}/UpdateInstaller/lib/*

      echo "    Setting specific permissions in maintenance subdir"
      if [[ `ls ${DESTDIR}/UpdateInstaller/maintenance| wc -l` -gt 0 ]]; then
         $CHMOD 0660 ${DESTDIR}/UpdateInstaller/maintenance/*
      fi

      echo "    Setting specific permissions in properties subdir"
      find ${DESTDIR}/UpdateInstaller/properties/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in responsefiles subdir"
      $CHMOD 0660 ${DESTDIR}/UpdateInstaller/responsefiles/*

      echo "    Setting specific permissions in uninstall subdir"
      find ${DESTDIR}/UpdateInstaller/uninstall/* -type f -exec $CHMOD 0660 {} \;
      $CHMOD 0770 ${DESTDIR}/UpdateInstaller/uninstall/uninstall
      $CHMODR 0770 ${DESTDIR}/UpdateInstaller/uninstall/java/bin
   fi
 
   if [[ $PRODUCT == "all" || $PRODUCT == "ihs" ]]; then
      if [[ -f /opt/HPODS/LCS/bin/eiRotate ]]; then
         echo "Setting perms on eiRotate"
         $CHMOD 0755 /opt/HPODS/LCS/bin/eiRotate
      fi
   fi 
}

function set_base_ihs_perms_85
{
   typeset DESTDIR=$1 TOOLSDIR=$2 PLUGINDIR=$4 PRODUCT_TXT CODE CHMOD CHMODR XARGS FS_TABLE WASSRCDIR SYSTEM_GRP
   typeset HTTPLOG=`echo $DESTDIR | cut -d'/' -f3,4`
   typeset -l PRODUCT=$3

   if [[ $DESTDIR == "" ]]; then
      echo "Function set_base_ihs_perms_85 needs DESTDIR defined"
      exit 1
   fi

   if [[ $TOOLSDIR == "" ]]; then
      echo "Function set_base_ihs_perms_85 needs TOOLSDIR defined"
      exit 1
   fi 

   if [[ $PRODUCT == "" ]]; then
      echo "Function set_base_ihs_perms_85 needs PRODUCT defined"
      echo "Parameter PRODUCT needs to be one of the following:"
      echo "  ihs, plugin, or all"
      exit 1
   elif [[ $PRODUCT == "all" ]]; then
      PRODUCT_TXT="all IHS/SDK Products Installed"
   elif [[ $PRODUCT == "ihs" ]]; then
      PRODUCT_TXT="Base IHS Install"
   elif [[ $PRODUCT == "plugin" ]]; then
      PRODUCT_TXT="WAS Plugin Install"
   else
      echo "Parameter PRODUCT needs to be one of the following:"
      echo "  ihs, plugin, or all" 
      exit 1
   fi

   if [[ $PRODUCT == "all" || $PRODUCT == "plugin" ]]; then
       if [[ $PLUGINDIR == "" ]]; then
           echo "Function set_base_ihs_perms_85 needs PLUGINDIR defined"
           exit 1
       fi
   fi

   echo "---------------------------------------------------------------"
   echo "      Set Ownership and Permissions for"
   echo "          $PRODUCT_TXT"
   echo "      At serverroot"
   echo "          $DESTDIR"
   echo "---------------------------------------------------------------"
   echo ""

   # Verify IHS is installed or exit if not
   if [[ ( $PRODUCT == "all" || $PRODUCT == "ihs" ) && ! -f ${DESTDIR}/bin/httpd ]]; then
      echo "Base IHS install not detected"
      echo "Aborting set perms process"
      exit 1
   fi

   # Verify WAS Plugin is installed or exit if not if the request is for plug
   if [ $PRODUCT == "plugin" -a ! -f ${PLUGINDIR}/bin/64bits/mod_was_ap22_http.so ]; then
      echo "WAS Plugin install not detected"
      echo "Aborting set perms process"
      exit 1
   fi

   os_specific_parameters_85
   function_error_check os_specific_parameters_85 perms

   echo "Adding ids as needed"
   echo "Checking existance of apps group creating it as needed"
   grep apps /etc/group > /dev/null 2>&1
   if [[ $? -ne 0 ]]; then
      /fs/system/tools/auth/bin/mkeigroup -r local -f apps
      if [[ $? -gt 0 ]]; then
         echo "/////////////////////////////////////////////////////////////////"
         echo "**********        Execution of mkeigroup Failed        **********"
         echo "/////////////////////////////////////////////////////////////////"
         exit 3
      fi
   else
      echo "   Group apps already exist"
   fi

   echo "Checking existance of webinst user creating it as needed"
   id webinst > /dev/null 2>&1
   if [[  $? -ne 0 ]]; then
      /fs/system/tools/auth/bin/mkeiuser  -r local -f webinst apps
      if [[ $? -gt 0 ]]; then
         echo "/////////////////////////////////////////////////////////////////"
         echo "**********        Execution of mkeiuser Failed         **********"
         echo "/////////////////////////////////////////////////////////////////"
         exit 3
      fi
   else
      echo "   ID webinst already exist"
   fi
   
   if [[ $PRODUCT == "all" || $PRODUCT == "ihs" ]]; then
      if [[ -d /logs/${HTTPLOG} ]]; then
         if [[ -L /logs/${HTTPLOG} ]]; then
            echo "/logs/${HTTPLOG} is a symlink, setting ownership of link"
            chown -h webinst.eiadm /logs/${HTTPLOG}
            HTTPLOG=`ls -l /logs/${HTTPLOG} | awk {'print $NF'}`
            HTTPLOG=`echo $HTTPLOG | awk -F '/' {'print $NF'}`
            echo "Real dir is /logs/${HTTPLOG}"
         fi
         if [[ -d /logs/${HTTPLOG} && ! -L /logs/${HTTPLOG} ]]; then
            echo "Setting permissions on /logs/${HTTPLOG}"
            chown -h webinst.eiadm /logs/${HTTPLOG}
            $CHMOD 2750 /logs/${HTTPLOG}
            find /logs/$HTTPLOG | egrep "/logs/${HTTPLOG}/install|/logs/${HTTPLOG}/postinstall|/logs/${HTTPLOG}/update|/logs/${HTTPLOG}/uninstall" | $XARGS chown -h root.$SYSTEM_GRP {}
            find /logs/$HTTPLOG -type d | egrep "/logs/${HTTPLOG}/install|/logs/${HTTPLOG}/postinstall|/logs/${HTTPLOG}/update|/logs/${HTTPLOG}/uninstall" | $XARGS $CHMOD 0775 {}
            find /logs/$HTTPLOG -type f | egrep "/logs/${HTTPLOG}/install|/logs/${HTTPLOG}/postinstall|/logs/${HTTPLOG}/update|/logs/${HTTPLOG}/uninstall" | $XARGS $CHMOD 0664 {}
         else
            echo "/logs/$HTTPLOG does not exist on this node as a real dir"
         fi
      else
         echo "Can not find log dir for IHS install $HTTPLOG on this node"
      fi
   fi

   if [[ $PRODUCT == "all" || $PRODUCT == "ihs" ]]; then
       echo "Setting base ownership and permissions on $DESTDIR"
       chown root.eiadm $DESTDIR
       ls -1 $DESTDIR | egrep -v "Plugins.*" | $XARGS chown -hR root.eiadm $DESTDIR/{}
       $CHMOD 0775 $DESTDIR
       ls -1 $DESTDIR | egrep -v "logs|cgi-bin|icons|htdocs" | $XARGS $CHMODR 0770 $DESTDIR/{}
       find $DESTDIR -type d | egrep "${DESTDIR}\/cgi-bin|${DESTDIR}\/icons|${DESTDIR}\/htdocs" | $XARGS $CHMOD 0775 {}  
       find $DESTDIR -type f | egrep "${DESTDIR}\/icons|${DESTDIR}\/htdocs" | $XARGS $CHMOD 0664 {}  
   fi

   if [[ $PRODUCT == "all" || $PRODUCT == "ihs" ]]; then
      echo "Setting specific permissions in $DESTDIR"
      $CHMOD 0660 ${DESTDIR}/version.signature

      if [[ -d ${DESTDIR}/GSKitImage ]]; then
         echo "    Setting specific permissions in GSKitImage subdir"
         find ${DESTDIR}/GSKitImage/* | grep -v gskit.sh | $XARGS $CHMOD 0660 {}
      fi
   
      if [[ -d ${DESTDIR}/bin ]]; then
         echo "    Setting specific permissions in bin subdir"
         $CHMOD 0660 ${DESTDIR}/bin/envvars ${DESTDIR}/bin/envvars-std
      fi

      if [[ -d ${DESTDIR}/build ]]; then
         echo "    Setting specific permissions in build subdir"
         $CHMOD 0660 ${DESTDIR}/build/*
         $CHMOD 0770 ${DESTDIR}/build/instdso.sh ${DESTDIR}/build/libtool ${DESTDIR}/build/mkdir.sh
      fi

      if [[ -d ${DESTDIR}/codeset ]]; then
         echo "    Setting specific permissions in codepages subdir"
         $CHMOD 0660 ${DESTDIR}/codeset/*
      fi

      if [[ -d ${DESTDIR}/conf ]]; then
         echo "    Setting specific permissions in conf subdir"
         $CHMOD 0660 ${DESTDIR}/conf/*
      fi

      if [[ -d ${DESTDIR}/error ]]; then
         echo "    Setting specific permissions in error subdir"
         $CHMOD 0660 ${DESTDIR}/error/*
         $CHMOD 0770 ${DESTDIR}/error/include
         $CHMOD 0660 ${DESTDIR}/error/include/*
      fi

      if [[ -d ${DESTDIR}/example_module ]]; then
         echo "    Setting specific permissions in example_module subdir"
         $CHMOD 0660 ${DESTDIR}/example_module/*
      fi

      if [[ -d ${DESTDIR}/gsk8 ]]; then
         echo "    Setting specific permissions in gsk8 subdir"
         $CHMOD 0660 ${DESTDIR}/gsk8/copyright
         $CHMOD 0660 ${DESTDIR}/gsk8/lib64/*
         find ${DESTDIR}/gsk8/lib64/C/icc -type f -exec $CHMOD 0660 {} \;
         find ${DESTDIR}/gsk8/lib64/N/icc -type f -exec $CHMOD 0660 {} \;
      fi

      if [[ -d ${DESTDIR}/include ]]; then
         echo "    Setting specific permissions in include subdir"
         $CHMOD 0660 ${DESTDIR}/include/*
      fi

      if [[ -d ${DESTDIR}/java ]]; then
         echo "    Setting specific permissions in java subdir"
         if [[ -f ${DESTDIR}/java/COPYRIGHT ]]; then
            $CHMOD 0660 ${DESTDIR}/java/COPYRIGHT
         fi
         if [[ -f ${DESTDIR}/java/copyright ]]; then
            $CHMOD 0660 ${DESTDIR}/java/copyright
         fi
         if [[ -f ${DESTDIR}/java/notices.txt ]]; then
            $CHMOD 0660 ${DESTDIR}/java/notices.txt
         fi
         if [[ -d ${DESTDIR}/java/docs ]]; then
            find ${DESTDIR}/java/docs/* -type f -exec $CHMOD 0660 {} \;
            $CHMOD 0770 ${DESTDIR}/java/docs/launchpad.exe ${DESTDIR}/java/docs/launchpad.sh 
         fi
         find ${DESTDIR}/java/jre/* -type f -exec $CHMOD 0660 {} \;
         $CHMODR 0770 ${DESTDIR}/java/jre/bin
      fi

      if [[ -d ${DESTDIR}/lafiles ]]; then
         echo "    Setting specific permissions in lafiles subdir"
         $CHMOD 0660 ${DESTDIR}/lafiles/*
      fi

      if [[ -d ${DESTDIR}/lib ]]; then
         echo "    Setting specific permissions in lib subdir"
         $CHMOD 0660 ${DESTDIR}/lib/*
      fi

      if [[ -d ${DESTDIR}/license ]]; then
         echo "    Setting specific permissions in license subdir"
         $CHMOD 0660 ${DESTDIR}/license/*
      fi

      if [[ -d ${DESTDIR}/man ]]; then
         echo "    Setting specific permissions in man subdir"
         find ${DESTDIR}/man/* -type f -exec $CHMOD 0660 {} \;
      fi

      if [[ -d ${DESTDIR}/modules ]]; then
         echo "    Setting specific permissions in modules subdir"
         find ${DESTDIR}/modules -type f -exec $CHMOD 0660 {} \; 
      fi

      if [[ -d ${DESTDIR}/properties ]]; then
         echo "    Setting specific permissions in properties subdir"
         find ${DESTDIR}/properties/* -type f -exec $CHMOD 0660 {} \;
         $CHMOD 0770 ${DESTDIR}/properties/version/nsf/backup/backupnsf.ihs.unixdist.sh         
      fi

      if [[ -d ${DESTDIR}/readme ]]; then
         echo "    Setting specific permissions in readme subdir"
         $CHMOD 0660 ${DESTDIR}/readme/*
      fi

      if [[ -d ${DESTDIR}/uninstall ]]; then
         echo "    Setting specific permissions in uninstall subdir"
         find ${DESTDIR}/uninstall/* -type f -exec $CHMOD 0660 {} \;
      fi
   fi

   if [[ $PRODUCT == "all" || $PRODUCT == "plugin" ]]; then
      if [[ -d ${PLUGINDIR} ]]; then
           set_plugin85_perms $PLUGINDIR
      fi
   fi

   if [[ $PRODUCT == "all" || $PRODUCT == "ihs" ]]; then
      if [[ -f /opt/HPODS/LCS/bin/eiRotate ]]; then
         echo "Setting perms on eiRotate"
         $CHMOD 0755 /opt/HPODS/LCS/bin/eiRotate
      fi
   fi

}

function set_plugin_perms
{ 
   typeset CHMOD CHMODR XARGS FS_TABLE WASSRCDIR SYSTEM_GRP 

   os_specific_parameters_61 32
   function_error_check os_specific_parameters_61 perms

   if [[ -d ${DESTDIR}/Plugins ]]; then
      echo "Setting specific permissions in ${DESTDIR}/Plugins"
      chown -hR root.eiadm ${DESTDIR}/Plugins
      $CHMODR 0770 ${DESTDIR}/Plugins

      if [[ -d ${DESTDIR}/Plugins/GSKitImage ]]; then
         echo "    Setting specific permissions in GSKitImage subdir"
         find ${DESTDIR}/Plugins/GSKitImage/* -type f | grep -v gskit.sh | $XARGS $CHMOD 0660 {}
      fi 

      echo "    Setting specific permissions in bin subdir"
      ls ${DESTDIR}/Plugins/bin/*.a  > /dev/null 2>&1
      if [[ $? -eq 0 ]]; then
         $CHMOD 0660 ${DESTDIR}/Plugins/bin/*.a
      fi
      ls ${DESTDIR}/Plugins/bin/*.so > /dev/null 2>&1
      if [[ $? -eq 0 ]]; then
         $CHMOD 0660 ${DESTDIR}/Plugins/bin/*.so
      fi

      echo "    Setting specific permissions in config subdir"
      find ${DESTDIR}/Plugins/config/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in configuration subdir"
      $CHMOD 0660 ${DESTDIR}/Plugins/configuration/*

      echo "    Setting specific permissions in etc subdir"
      $CHMOD 0660 ${DESTDIR}/Plugins/etc/*

      if [[ -d ${DESTDIR}/Plugins/gsk7 ]]; then
         echo "    Setting specific permissions in gsk7 subdir"
         if [ -f ${DESTDIR}/Plugins/gsk7/gsk7_*/COPYRIGHT ]; then
            $CHMOD 0660 ${DESTDIR}/Plugins/gsk7/gsk7_*/COPYRIGHT
         fi
         if [ -f ${DESTDIR}/Plugins/gsk7/gsk7_*/copyright ]; then
            $CHMOD 0660 ${DESTDIR}/Plugins/gsk7/gsk7_*/copyright
         fi
         $CHMOD 0660 ${DESTDIR}/Plugins/gsk7/gsk7_*/classes/*\.*
         $CHMOD 0660 ${DESTDIR}/Plugins/gsk7/gsk7_*/classes/jre/lib/ext/*.txt
         $CHMOD 0660 ${DESTDIR}/Plugins/gsk7/gsk7_*/classes/native/*
         $CHMOD 0660 ${DESTDIR}/Plugins/gsk7/gsk7_*/icc/*.txt
         $CHMOD 0660 ${DESTDIR}/Plugins/gsk7/gsk7_*/icc/icclib/*
         $CHMOD 0660 ${DESTDIR}/Plugins/gsk7/gsk7_*/icc/osslib/*
         $CHMOD 0660 ${DESTDIR}/Plugins/gsk7/gsk7_*/lib/*
      fi

      echo "    Setting specific permissions in java subdir"
      if [[ -f ${DESTDIR}/Plugins/java/COPYRIGHT ]]; then
         $CHMOD 0660 ${DESTDIR}/Plugins/java/COPYRIGHT
      fi
      if [[ -f ${DESTDIR}/Plugins/java/copyright ]]; then
         $CHMOD 0660 ${DESTDIR}/Plugins/java/copyright
      fi
      find ${DESTDIR}/Plugins/java/docs/* -type f -exec $CHMOD 0660 {} \;
      find ${DESTDIR}/Plugins/java/jre/lib/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in lafiles subdir"
      $CHMOD 0660 ${DESTDIR}/Plugins/lafiles/*

      echo "    Setting specific permissions in lib subdir"
      find ${DESTDIR}/Plugins/lib/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in plugins subdir"
      $CHMOD 0660 ${DESTDIR}/Plugins/plugins/*

      echo "    Setting specific permissions in properties subdir"
      find ${DESTDIR}/Plugins/properties/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in roadmap subdir"
      find ${DESTDIR}/Plugins/roadmap/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in uninstall subdir"
      find ${DESTDIR}/Plugins/uninstall/* -type f -exec $CHMOD 0660 {} \;
      $CHMOD 0770 ${DESTDIR}/Plugins/uninstall/uninstall
      if [[ -d ${DESTDIR}/Plugins/uninstall/java/bin ]]; then
         $CHMODR 0770 ${DESTDIR}/Plugins/uninstall/java/bin
      fi
   else
      echo "WAS Plugin dir was not found"
   fi
}

function set_plugin61_perms
{ 
   typeset PLUGDIR=$1 CHMOD CHMODR XARGS FS_TABLE WASSRCDIR SYSTEM_GRP 

   if [[ $PLUGDIR == "" ]]; then
      echo "Function set_plugin61_perms needs PLUGDIR defined"
      exit 1
   fi

   os_specific_parameters_61 32
   function_error_check os_specific_parameters_61 perms

   if [[ -d ${PLUGDIR} ]]; then
      echo "Setting specific permissions in ${PLUGDIR}"
      chown -hR root.eiadm ${PLUGDIR}
      $CHMODR 0770 ${PLUGDIR}

      echo "    Setting specific permissions in GSKitImage subdir"
      find ${PLUGDIR}/GSKitImage/* -type f | grep -v gskit.sh | $XARGS $CHMOD 0660 {} 

      echo "    Setting specific permissions in bin subdir"
      ls ${PLUGDIR}/bin/*.a  > /dev/null 2>&1
      if [[ $? -eq 0 ]]; then
         $CHMOD 0660 ${PLUGDIR}/bin/*.a
      fi
      ls ${PLUGDIR}/bin/*.so > /dev/null 2>&1
      if [[ $? -eq 0 ]]; then
         $CHMOD 0660 ${PLUGDIR}/bin/*.so
      fi

      echo "    Setting specific permissions in config subdir"
      find ${PLUGDIR}/config/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in configuration subdir"
      $CHMOD 0660 ${PLUGDIR}/configuration/*

      echo "    Setting specific permissions in etc subdir"
      $CHMOD 0660 ${PLUGDIR}/etc/*

      echo "    Setting specific permissions in java subdir"
      if [[ -f ${PLUGDIR}/java/COPYRIGHT ]]; then
         $CHMOD 0660 ${PLUGDIR}/java/COPYRIGHT
      fi
      if [[ -f ${PLUGDIR}/java/copyright ]]; then
         $CHMOD 0660 ${PLUGDIR}/java/copyright
      fi
      find ${PLUGDIR}/java/docs/* -type f -exec $CHMOD 0660 {} \;
      find ${PLUGDIR}/java/jre/lib/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in lafiles subdir"
      $CHMOD 0660 ${PLUGDIR}/lafiles/*

      echo "    Setting specific permissions in lib subdir"
      find ${PLUGDIR}/lib/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in plugins subdir"
      $CHMOD 0660 ${PLUGDIR}/plugins/*

      echo "    Setting specific permissions in properties subdir"
      find ${PLUGDIR}/properties/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in roadmap subdir"
      find ${PLUGDIR}/roadmap/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in uninstall subdir"
      find ${PLUGDIR}/uninstall/* -type f -exec $CHMOD 0660 {} \;
      $CHMOD 0770 ${PLUGDIR}/uninstall/uninstall
      $CHMODR 0770 ${PLUGDIR}/uninstall/java/bin
   else
      echo "$PLUGDIR dir was not found"
   fi
}

function set_plugin70_perms
{ 
   typeset PLUGDIR=$1 CHMOD CHMODR XARGS FS_TABLE WASSRCDIR SYSTEM_GRP

   if [[ $PLUGDIR == "" ]]; then
      echo "Function set_plugin70_perms needs PLUGDIR defined"
      exit 1
   fi

   os_specific_parameters_70 32
   function_error_check os_specific_parameters_70 perms

   if [[ -d ${PLUGDIR} ]]; then
      echo "Setting specific permissions in ${PLUGDIR}"
      chown -hR root.eiadm ${PLUGDIR}
      $CHMODR 0770 ${PLUGDIR}

      echo "    Setting specific permissions in bin subdir"
      ls ${PLUGDIR}/bin/*.a  > /dev/null 2>&1
      if [[ $? -eq 0 ]]; then
         $CHMOD 0660 ${PLUGDIR}/bin/*.a
      fi
      ls ${PLUGDIR}/bin/*.so > /dev/null 2>&1
      if [[ $? -eq 0 ]]; then
         $CHMOD 0660 ${PLUGDIR}/bin/*.so
      fi

      echo "    Setting specific permissions in config subdir"
      find ${PLUGDIR}/config/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in configuration subdir"
      $CHMOD 0660 ${PLUGDIR}/configuration/*

      echo "    Setting specific permissions in etc subdir"
      $CHMOD 0660 ${PLUGDIR}/etc/*

      echo "    Setting specific permissions in gsk7 subdir"
      if [ -f ${PLUGDIR}/gsk7/gsk7_*/COPYRIGHT ]; then
         $CHMOD 0660 ${PLUGDIR}/gsk7/gsk7_*/COPYRIGHT
      fi
      if [ -f ${PLUGDIR}/gsk7/gsk7_*/copyright ]; then
         $CHMOD 0660 ${PLUGDIR}/gsk7/gsk7_*/copyright
      fi
      $CHMOD 0660 ${PLUGDIR}/gsk7/gsk7_*/classes/*\.*
      $CHMOD 0660 ${PLUGDIR}/gsk7/gsk7_*/classes/jre/lib/ext/*.txt
      $CHMOD 0660 ${PLUGDIR}/gsk7/gsk7_*/classes/native/*
      $CHMOD 0660 ${PLUGDIR}/gsk7/gsk7_*/icc/*.txt
      $CHMOD 0660 ${PLUGDIR}/gsk7/gsk7_*/icc/icclib/*
      $CHMOD 0660 ${PLUGDIR}/gsk7/gsk7_*/icc/osslib/*
      $CHMOD 0660 ${PLUGDIR}/gsk7/gsk7_*/lib/*

      echo "    Setting specific permissions in java subdir"
      if [[ -f ${PLUGDIR}/java/COPYRIGHT ]]; then
         $CHMOD 0660 ${PLUGDIR}/java/COPYRIGHT
      fi
      if [[ -f ${PLUGDIR}/java/copyright ]]; then
         $CHMOD 0660 ${PLUGDIR}/java/copyright
      fi
      find ${PLUGDIR}/java/docs/* -type f -exec $CHMOD 0660 {} \;
      find ${PLUGDIR}/java/jre/lib/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in lafiles subdir"
      $CHMOD 0660 ${PLUGDIR}/lafiles/*

      echo "    Setting specific permissions in lib subdir"
      find ${PLUGDIR}/lib/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in plugins subdir"
      $CHMOD 0660 ${PLUGDIR}/plugins/*

      echo "    Setting specific permissions in properties subdir"
      find ${PLUGDIR}/properties/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in roadmap subdir"
      find ${PLUGDIR}/roadmap/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in uninstall subdir"
      find ${PLUGDIR}/uninstall/* -type f -exec $CHMOD 0660 {} \;
      $CHMOD 0770 ${PLUGDIR}/uninstall/uninstall
   else
      echo "$PLUGDIR dir was not found"
   fi
}

function set_plugin85_perms
{ 
   typeset PLUGDIR=$1 CHMOD CHMODR XARGS FS_TABLE WASSRCDIR SYSTEM_GRP
   typeset PLUGINLOG=`echo $PLUGDIR | cut -d'/' -f3,4`

   if [[ $PLUGDIR == "" ]]; then
      echo "Function set_plugin85_perms needs PLUGDIR defined"
      exit 1
   fi

   os_specific_parameters_85
   function_error_check os_specific_parameters_85 perms

   if [ -d /logs/${PLUGINLOG} ]; then
       chown -h webinst.eiadm /logs/${PLUGINLOG}*
       $CHMOD 2750 /logs/${PLUGINLOG}
       find /logs/$PLUGINLOG | egrep "/logs/${PLUGINLOG}/install|/logs/${PLUGINLOG}/update|/logs/${PLUGINLOG}/uninstall" | $XARGS chown -h root.$SYSTEM_GRP {}
       find /logs/$PLUGINLOG -type d | egrep "/logs/${PLUGINLOG}/install|/logs/${PLUGINLOG}/Plugins.*/update|/logs/${PLUGINLOG}/uninstall" | $XARGS $CHMOD 0775 {}
       find /logs/$PLUGINLOG -type f | egrep "/logs/${PLUGINLOG}/install|/logs/${PLUGINLOG}/update|/logs/${PLUGINLOG}/uninstall" | $XARGS $CHMOD 0664 {}
   fi

   if [[ -d ${PLUGDIR} ]]; then
      echo "Setting specific permissions in ${PLUGDIR}"
      chown -hR root.eiadm ${PLUGDIR}
      $CHMODR 0770 ${PLUGDIR}

      echo "    Setting specific permissions in bin subdir"
      ls ${PLUGDIR}/bin/32bits/*.a  > /dev/null 2>&1
      if [[ $? -eq 0 ]]; then
         $CHMOD 0660 ${PLUGDIR}/bin/32bits/*.a
      fi
      ls ${PLUGDIR}/bin/32bits/*.so > /dev/null 2>&1
      if [[ $? -eq 0 ]]; then
         $CHMOD 0660 ${PLUGDIR}/bin/32bits/*.so
      fi
      ls ${PLUGDIR}/bin/64bits/*.a  > /dev/null 2>&1
      if [[ $? -eq 0 ]]; then
         $CHMOD 0660 ${PLUGDIR}/bin/64bits/*.a
      fi
      ls ${PLUGDIR}/bin/64bits/*.so > /dev/null 2>&1
      if [[ $? -eq 0 ]]; then
         $CHMOD 0660 ${PLUGDIR}/bin/64bits/*.so
      fi
      
      echo "    Setting specific permissions in config subdir"
      find ${PLUGDIR}/config/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in configuration subdir"
      $CHMOD 0660 ${PLUGDIR}/configuration/*

      echo "    Setting specific permissions in etc subdir"
      $CHMOD 0660 ${PLUGDIR}/etc/*

      echo "    Setting specific permissions in gsk8 subdir"
      if [ -f ${PLUGDIR}/gsk8/gsk8_*/COPYRIGHT ]; then
         $CHMOD 0660 ${PLUGDIR}/gsk8/gsk8_*/COPYRIGHT
      fi
      if [ -f ${PLUGDIR}/gsk8/gsk8_*/copyright ]; then
         $CHMOD 0660 ${PLUGDIR}/gsk8/gsk8_*/copyright
      fi
      
      $CHMOD 0660 ${PLUGDIR}/gsk8/gsk8_32/lib/C/icc/*.txt
      $CHMOD 0660 ${PLUGDIR}/gsk8/gsk8_32/lib/C/icc/icclib/*
      $CHMOD 0660 ${PLUGDIR}/gsk8/gsk8_32/lib/C/icc/osslib/*
      $CHMOD 0660 ${PLUGDIR}/gsk8/gsk8_32/lib/N/icc/*.txt
      $CHMOD 0660 ${PLUGDIR}/gsk8/gsk8_32/lib/N/icc/icclib/*
      $CHMOD 0660 ${PLUGDIR}/gsk8/gsk8_32/lib/N/icc/osslib/*
      $CHMOD 0660 ${PLUGDIR}/gsk8/gsk8_32/lib/*
      $CHMOD 0660 ${PLUGDIR}/gsk8/gsk8_64/lib64/C/icc/*.txt
      $CHMOD 0660 ${PLUGDIR}/gsk8/gsk8_64/lib64/C/icc/icclib/*
      $CHMOD 0660 ${PLUGDIR}/gsk8/gsk8_64/lib64/C/icc/osslib/*
      $CHMOD 0660 ${PLUGDIR}/gsk8/gsk8_64/lib64/N/icc/*.txt
      $CHMOD 0660 ${PLUGDIR}/gsk8/gsk8_64/lib64/N/icc/icclib/*
      $CHMOD 0660 ${PLUGDIR}/gsk8/gsk8_64/lib64/N/icc/osslib/*
      $CHMOD 0660 ${PLUGDIR}/gsk8/gsk8_64/lib64/*

      echo "    Setting specific permissions in java subdir"
      if [[ -f ${PLUGDIR}/java/COPYRIGHT ]]; then
         $CHMOD 0660 ${PLUGDIR}/java/COPYRIGHT
      fi
      if [[ -f ${PLUGDIR}/java/copyright ]]; then
         $CHMOD 0660 ${PLUGDIR}/java/copyright
      fi
      find ${PLUGDIR}/java/docs/* -type f -exec $CHMOD 0660 {} \;
      find ${PLUGDIR}/java/jre/lib/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in lafiles subdir"
      $CHMOD 0660 ${PLUGDIR}/lafiles/*

      echo "    Setting specific permissions in lib subdir"
      find ${PLUGDIR}/lib/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in plugins subdir"
      $CHMOD 0660 ${PLUGDIR}/plugins/*

      echo "    Setting specific permissions in properties subdir"
      find ${PLUGDIR}/properties/* -type f -exec $CHMOD 0660 {} \;
      
      echo "    Setting specific permissions in backup subdir"
      ls ${PLUGDIR}/properties/version/nsf/backup/*.sh > /dev/null 2>&1
      if [[ $? -eq 0 ]]; then
         $CHMOD 0770 ${PLUGDIR}/properties/version/nsf/backup/*.sh
      fi

      echo "    Setting specific permissions in roadmap subdir"
      find ${PLUGDIR}/roadmap/* -type f -exec $CHMOD 0660 {} \;

      echo "    Setting specific permissions in uninstall subdir"
      find ${PLUGDIR}/uninstall/* -type f -exec $CHMOD 0660 {} \;
      
      echo "    Setting specific permissions in util subdir"
      find ${PLUGDIR}/util/* -type f -exec $CHMOD 0660 {} \;      
   else
      echo "$PLUGDIR dir was not found"
   fi
}

function set_site_perms
{
   typeset SITETAG=$1 TOOLSDIR=$2 SITE SITELOG SITE_CONTENT DOCROOT CONTENTROOT PUBID PUBGRP PUBPERMS CHMOD CHMODR XARGS

   if [[ $SITETAG == "" ]]; then
      echo "Function set_site_perms needs SITETAG defined"
      exit 1
   fi
 
   if [[ $TOOLSDIR == "" ]]; then
      echo "Function set_site_perms needs TOOLSDIR defined"
      exit 1
   fi
 
   echo ""
   echo "---------------------------------------------------------------"
   echo "      Set Ownership and Permissions for"
   echo "          $SITETAG"
   echo "---------------------------------------------------------------"
   echo ""

   case `uname` in
      Linux)
         CHMOD="chmod "
         CHMODR="chmod -R "
         XARGS="xargs -i{} "
         SYSTEM_GRP="root"
      ;;
      AIX)
         CHMOD="chmod -h"
         CHMODR="chmod -hR"
         XARGS="xargs -I{} "
         SYSTEM_GRP="system"
      ;;
      *)
         echo "Operating system not supported by this script"
         exit 2
      ;;
   esac
   
   echo "Adding ids as needed"
   echo "Checking existance of apps group creating it as needed"
   grep apps /etc/group > /dev/null 2>&1
   if [[ $? -ne 0 ]]; then
      /fs/system/tools/auth/bin/mkeigroup -r local -f apps
      if [[ $? -gt 0 ]]; then
         echo "/////////////////////////////////////////////////////////////////"
         echo "**********        Execution of mkeigroup Failed        **********"
         echo "/////////////////////////////////////////////////////////////////"
         exit 3
      fi
   else
      echo "   Group apps already exist"
   fi

   echo "Checking existance of pubinst" 
   id pubinst > /dev/null 2>&1
   if [[ $? -eq 0 ]]; then
      echo "    found pubinst id"
      PUBID="pubinst"
      PUBGRP="apps"
      PUBPERMS="0755"
   else
      echo "    pubinst user not found -- using id root instead"
      PUBID="root"
      PUBGRP="eiadm"
      PUBPERMS="0775"
   fi

   if [[ -d /logs/${SITETAG} ]]; then
      if [[ -L /logs/${SITETAG} ]]; then
         echo "/logs/${SITETAG} is a symlink, setting ownership of link"
         chown -h webinst.eiadm /logs/${SITETAG}
         SITELOG=`ls -l /logs/${SITETAG} | awk {'print $NF'}`
         echo "Real dir is ${SITELOG}"
      fi
      if [[ $SITELOG == "" ]]; then
         SITELOG=/logs/$SITETAG
      fi
      if [[ -d ${SITELOG} && ! -L ${SITELOG} ]]; then
         echo "Setting permissions on ${SITELOG}"
         chown -hR webinst.eiadm ${SITELOG}
         find ${SITELOG} -type d -exec $CHMOD 2750 {} \;
         find ${SITELOG} -type f -exec $CHMOD 0640 {} \; 
      else
         echo "${SITELOG} does not exist on this node as a real dir"
      fi
   else
      echo "Can not find Log Directory for site ${SITETAG} on this node"
   fi
   if [[ -d /projects/${SITETAG} ]]; then
      if [[ -L /projects/${SITETAG} ]]; then
         echo "/projects/${SITETAG} is a symlink, setting ownership of link"
         chown -h root.eiadm /projects/${SITETAG}
         SITE=`ls -l /projects/${SITETAG} | awk {'print $NF'}`
         echo "Real dir is ${SITE}"
      fi
      if [[ $SITE == "" ]]; then
         SITE=/projects/$SITETAG
      fi
      if [[ -d ${SITE} && ! -L ${SITE} ]]; then
         echo "Setting permissions on ${SITE}"
         chown -h root.eiadm ${SITE}
         $CHMOD 0775 ${SITE}
         if [[ -d ${SITE}/content ]]; then 
            if [[ ! -L ${SITE}/content ]]; then
               if [[ ! -d ${SITE}/content/htdocs ]]; then
                  echo "    Setting permissions on content subdir"
                  chown ${PUBID}.${PUBGRP} ${SITE}/content
                  $CHMOD $PUBPERMS ${SITE}/content
                  DOCROOT=${SITE}/content
                  CONTENTROOT=${SITE}
               elif [[ -d ${SITE}/content/htdocs ]]; then
                  echo "    Setting permissions on content subdir"
                  chown root.eiadm ${SITE}/content
                  $CHMOD 0775 ${SITE}/content
                  echo "    Setting permissions on content/htdocs subdir"
                  chown ${PUBID}.${PUBGRP} ${SITE}/content/htdocs
                  $CHMOD $PUBPERMS ${SITE}/content/htdocs
                  DOCROOT=${SITE}/content/htdocs
                  CONTENTROOT=${SITE}/content
               else
                  echo "    Processing content subdir -- Unable to determine type"
                  echo "        of install.  Verify PERM settings"
                  
               fi
               if [[ $DOCROOT != "" ]]; then
                  if [[ -d ${DOCROOT}/Admin ]]; then
                     echo "    Setting permissions on ${DOCROOT}/Admin subdir"
                     chown -hR root.eiadm ${DOCROOT}/Admin
                     find ${DOCROOT}/Admin -type d -exec $CHMOD 0775 {} \;
                     find ${DOCROOT}/Admin -type f -exec $CHMOD 0664 {} \;
                  fi
                  if [[ -f $DOCROOT/site.txt ]]; then
                     echo "    Setting permissions on site.txt"
                     chown -h root.eiadm ${DOCROOT}/site.txt
                     $CHMOD 0664 ${DOCROOT}/site.txt
                  else
                     echo "    site.txt does not exist"
                  fi
                  if [[ -L ${DOCROOT}/sslsite.txt ]]; then
                     echo "    Setting ownership on sslsite.txt symlink"
                     chown -h root.eiadm ${DOCROOT}/sslsite.txt
                  else
                     echo "    sslsite.txt symlink does not exist"
                  fi
               else
                  echo "    Could not determine DOCROOT.  Verify PERM settings"
               fi
            else
               echo "    Content dir is a Symlink -- set perms on symlink"
               chown -h root.eiadm ${SITE}/content

               SITE_CONTENT=`ls -l ${SITE}/content | awk {'print $NF'}`
               if [[ $SITE_CONTENT != /fs/projects_isolated* ]]; then
                  echo "        Symlink does not match ei standards.  Verify Symlink"
               fi

               if [[ -d ${SITE}/nodeid ]]; then
                  echo "    Setting permissions on nodeid subdir"
                  chown -hR root.eiadm ${SITE}/nodeid
                  if [[ `ls ${SITE}/nodeid/whichnode.txt | wc -l` -gt 0 ]]; then
                     $CHMOD 0664 ${SITE}/nodeid/*
                  else
                     echo "        whichnode.txt does not exit -- check install"
                  fi
               else
                  echo "        nodeid subdir does not exist -- check install"
               fi
            fi
         else
            echo "    Content subdir does not exist"
         fi

         if [ -d /projects/HTTPServer* ]; then
            if [[ -d ${SITE}/config ]]; then
               echo "    Setting permissions on config subdir"
               chown -h root.eiadm ${SITE}/config
               if [[ ! -L ${SITE}/config ]]; then
                  chown -hR root.eiadm ${SITE}/config/*
                  find ${SITE}/config -type d -exec $CHMOD 0770 {} \;
                  find ${SITE}/config -type f -exec $CHMOD 0660 {} \;
                  find ${SITE}/config -name "*passwd" -exec chgrp -h apps {} \;
               else
                  echo "     config subdir is a link which does not match standard"
                  echo "     Not handled by script"
               fi
            else
               echo "    config subdir does not exist"
            fi
         else
            if [[ -d ${SITE}/conf ]]; then
               echo "    Setting permissions on conf subdir"
               chown -h root.eiadm ${SITE}/conf
               if [[ ! -L ${SITE}/conf ]]; then
                  chown -hR root.eiadm ${SITE}/conf/*
                  find ${SITE}/conf -type f -name "plugin*" -exec chgrp -h apps {} \;
                  find ${SITE}/conf -type f -name "*.map" -exec chgrp -h apps {} \;
                  find ${SITE}/conf -type d -exec $CHMOD 0775 {} \;
                  find ${SITE}/conf -type f -exec $CHMOD 0660 {} \;
                  find ${SITE}/conf -type f -name "plugin*" -exec $CHMOD 0640 {} \;
                  find ${SITE}/conf -type f -name "*.map" -exec $CHMOD 0640 {} \;
               else
                  echo "     conf subdir is a link which does not match standard"
                  echo "     Not handled by script"
               fi
            else
               echo "    conf subdir does not exist"
            fi
            if [[ -d ${SITE}/key ]]; then
               echo "    Setting permissions on key subdir"
               chown -h root.eiadm ${SITE}/key
               if [[ ! -L ${SITE}/key ]]; then
                  $CHMOD 0775 ${SITE}/key
                  if [[ `ls ${SITE}/key | wc -l` -gt 0 ]]; then
                     chown -h root.apps ${SITE}/key/*
                     $CHMOD 0640 ${SITE}/key/*
                  fi
               else
                  echo "     key subdir is a link which does not match standard"
                  echo "     Not handled by script"
               fi
            else
               echo "    key subdir does not exist"
            fi
            if [[ -d ${SITE}/modules ]]; then
               echo "    Setting permissions on modules subdir"
               chown -h root.eiadm ${SITE}/modules
               if [[ ! -L ${SITE}/modules ]]; then
                  chown -hR root.eiadm ${SITE}/modules/*
                  find ${SITE}/modules -type d -exec $CHMOD 0770 {} \;
                  find ${SITE}/modules -type f -exec $CHMOD 0660 {} \;
               else
                  echo "     modules subdir is a link which does not match standard"
                  echo "     Not handled by script"
               fi
            else
               echo "    modules subdir does not exist"
            fi
         fi               
 
         if [[ -d ${SITE}/bin ]]; then
            echo "    Setting permissions on bin subdir"
            chown -h root.eiadm ${SITE}/bin
            if [[ ! -L ${SITE}/bin ]]; then
               $CHMODR 0770 ${SITE}/bin
               if [[ `ls ${SITE}/bin | wc -l` -gt 0 ]]; then
                  chown -hR root.eiadm ${SITE}/bin/*
               fi
            else
               echo "     bin subdir is a link which does not match standard"
               echo "     Not handled by script"
            fi
         else
            echo "    bin subdir does not exist"
         fi

         if [[ $CONTENTROOT == "" ]]; then
            CONTENTROOT=${SITE}
         fi

         if [[ -d ${CONTENTROOT}/cgi-bin && ! -L ${SITE}/content ]]; then
            echo "    Setting permissions on cgi-bin subdir"
            chown -h root.eiadm ${CONTENTROOT}/cgi-bin
            if [[ ! -L ${CONTENTROOT}/cgi-bin ]]; then
               $CHMOD 0775 ${CONTENTROOT}/cgi-bin
            else
               echo "     cgi-bin subdir is a link which does not match standard"
               echo "     Not handled by script"
            fi
         elif [[ ! -L ${SITE}/content ]]; then
            echo "    cgi-bin subdir does not exist"
         fi
         if [[ -d ${CONTENTROOT}/fcgi-bin && ! -L ${SITE}/content ]]; then
            echo "    Setting permissions on fcgi-bin subdir"
            chown -h root.eiadm ${CONTENTROOT}/fcgi-bin
            if [[ ! -L ${CONTENTROOT}/fcgi-bin ]]; then
               $CHMOD 0775 ${CONTENTROOT}/fcgi-bin
            else
               echo "     fcgi-bin subdir is a link which does not match standard"
               echo "     Not handled by script"
            fi
         elif [[ ! -L ${SITE}/content ]]; then
            echo "    fcgi-bin subdir does not exist"
         fi
         if [[ -d ${CONTENTROOT}/etc && ! -L ${SITE}/content ]]; then
            echo "    Setting permissions on etc subdir"
            chown -h ${PUBID}.${PUBGRP} ${CONTENTROOT}/etc
            if [[ ! -L ${CONTENTROOT}/etc ]]; then
               $CHMOD $PUBPERMS ${CONTENTROOT}/etc
            else
               echo "     etc subdir is a link which does not match standard"
               echo "     Not handled by script"
            fi
         elif [[ ! -L ${SITE}/content ]]; then
            echo "    etc subdir does not exist"
         fi
         if [[ -d ${contentroot}/data && ! -L ${SITE}/content ]]; then
            echo "    Setting permissions on data subdir"
            chown -h ${PUBID}.${PUBGRP} ${CONTENTROOT}/data
            if [[ ! -L ${CONTENTROOT}/data ]]; then
               $CHMOD $PUBPERMS ${CONTENTROOT}/data
            else
               echo "     data subdir is a link which does not match standard"
               echo "     Not handled by script"
            fi
         elif [[ ! -L ${SITE}/content ]]; then
            echo "    data subdir does not exist"
         fi

         echo
         echo "    Looking for any file or directory not explicitely handled"
         echo "    and setting default ownership and perms on anything found" 
         echo
         find ${SITE}/* -prune | egrep -v "${SITE}/cgi-bin|/${SITE}/config|${SITE}/conf|${SITE}/content|${SITE}/data|${SITE}/etc|${SITE}/fgi-bin|${SITE}/bin|${SITE}/key|${SITE}/modules|${SITE}/nodeid" | $XARGS chown -h root.eiadm {}
         find ${SITE}/* -prune -type d | egrep -v "${SITE}/cgi-bin|/${SITE}/config|${SITE}/conf|${SITE}/content|${SITE}/data|${SITE}/etc|${SITE}/fgi-bin|${SITE}/bin|${SITE}/key|${SITE}/modules|${SITE}/nodeid" | $XARGS $CHMOD 0770 {} 
         find ${SITE}/* -prune -type f  -exec $CHMOD 0660 {} \;

         # if sitepermlist.cfg file exists .. .then call set_permissions.sh
         if [ -f ${SITE}/conf*/sitepermlist.cfg ]; then
            echo "Special permission file sitepermlist.cfg found -- processing"
            cat ${SITE}/conf*/sitepermlist.cfg | ${TOOLSDIR}/configtools/set_permissions.sh
         fi
         if [[ -f /etc/logrotate.d/http_plugin ]]; then
            echo "Setting perms on plugin logrotate config"
            chown root.${SYSTEM_GRP} /etc/logrotate.d/http_plugin
            $CHMOD 444 /etc/logrotate.d/http_plugin
         fi
      else
         echo "/projects/${SITE} does not exist on this node as a real dir"
      fi
   else
      echo "Site $SITE does not exist on this node"
   fi
}

function set_global_server_perms
{

   HTTPDIR="$1"
   HTTPLOG="$1"

   case `uname` in
      Linux)
         CHMOD="chmod "
         CHMODR="chmod -R "
         XARGS="xargs -i{} "
         SYSTEM_GRP="root"
      ;;
      AIX)
         CHMOD="chmod -h"
         CHMODR="chmod -hR"
         XARGS="xargs -I{} "
         SYSTEM_GRP="system"
      ;;
      *)
         echo "Operating system not supported by this script"
         exit 2
      ;;
   esac
  
  
   if [[ -d /logs/${HTTPLOG} ]]; then
      if [[ -L /logs/${HTTPLOG} ]]; then
         echo "/logs/${HTTPLOG} is a symlink, setting ownership of link"
         chown -h webinst.eiadm /logs/${HTTPLOG}
         HTTPLOG=`ls -l /logs/${HTTPLOG} | awk {'print $NF'}`
         HTTPLOG=`echo $HTTPLOG | awk -F '/' {'print $NF'}`
         echo "Real dir is /logs/${HTTPLOG}"
      fi
      if [[ -d /logs/${HTTPLOG} && ! -L /logs/${HTTPLOG} ]]; then
         echo "Setting permissions on /logs/${HTTPLOG}"
         find /logs/$HTTPLOG -type d | egrep -v "/logs/${HTTPLOG}/install|/logs/${HTTPLOG}/update|/logs/${HTTPLOG}/Plugin/install|/logs/${HTTPLOG}/Plugin/update|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS chown -h webinst.eiadm {} 
         find /logs/$HTTPLOG -type d | egrep -v "/logs/${HTTPLOG}/install|/logs/${HTTPLOG}/update|/logs/${HTTPLOG}/Plugin/install|/logs/${HTTPLOG}/Plugin/update|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS $CHMOD 2750 {} 
         find /logs/$HTTPLOG -type f | egrep -v "/logs/${HTTPLOG}/install|/logs/${HTTPLOG}/update|/logs/${HTTPLOG}/Plugin/install|/logs/${HTTPLOG}/Plugin/update|/logs/${HTTPLOG}/UpdateInstaller" | $XARGS $CHMOD 0640 {} 
      else
         echo "/logs/$HTTPDIR does not exist on this node as a real dir" 
      fi
   else
      echo "Can not find log dir for global webserver $HTTPLOG on this node"
   fi
         
   if [[ -d /projects/${HTTPDIR} ]]; then
      if [[ -L /projects/${HTTPDIR} ]]; then
         echo "/projects/${HTTPDIR} is a symlink, setting ownership of link"
         chown -h root.eiadm /projects/${HTTPDIR}
         HTTPDIR=`ls -l /projects/${HTTPDIR} | awk {'print $NF'}`
         HTTPDIR=`echo $HTTPDIR | awk -F '/' {'print $NF'}`
         echo "Real dir is /projects/${HTTPDIR}"
      fi
      if [[ -d /projects/${HTTPDIR} && ! -L /projects/${HTTPDIR} ]]; then
         echo "Setting permissions on  /projects/${HTTPDIR}"
         chown -h root.eiadm /projects/${HTTPDIR}
         $CHMOD 0775 /projects/${HTTPDIR}
         if [[ -d /projects/${HTTPDIR}/content ]]; then
            echo "    Setting permissions on the content subdir"
            chown -hR root.eiadm /projects/${HTTPDIR}/content
            if [[ ! -L /projects/${HTTPDIR}/content ]]; then
               find /projects/${HTTPDIR}/content -type d -exec $CHMOD 0775 {} \;
               find /projects/${HTTPDIR}/content -type f -exec $CHMOD 0664 {} \;
            else
               echo "    content subdir is a link which does not match standard"
               echo "    Not handed by script"
            fi
         else
            echo "    content subdir does not exist"
         fi
         if [[ -d /projects/${HTTPDIR}/conf ]]; then
            for FILE in `ls /projects/${HTTPDIR}/conf/*conf 2>/dev/null`; do
               grep "eiRotate" $FILE > /tmp/line
               if [[ $? -eq 0 ]]; then
                  grep umask /tmp/line > /dev/null
                  if [[ $? -ne 0 ]]; then
                     echo "    Adding umask line to eiRotate stanzas in $FILE"
                     cp $FILE ${FILE}.bak
                     sed -e "s/\/eiRotate/\/eiRotate -umask 027/" $FILE > /tmp/httpd.conf && mv /tmp/httpd.conf  $FILE
                  fi
               fi
            done
            echo "    Setting permissions on conf dir"
            chown -h root.eiadm /projects/${HTTPDIR}/conf
            if [[ ! -L /projects/${HTTPDIR}/conf ]]; then
               chown -hR root.eiadm /projects/${HTTPDIR}/conf/*
               $CHMOD 775 /projects/${HTTPDIR}/conf
               find /projects/${HTTPDIR}/conf -type f -name "plugin*" -exec chgrp -h apps {} \; 
               find /projects/${HTTPDIR}/conf -type f -name "*.map" -exec chgrp -h apps {} \; 
               find /projects/${HTTPDIR}/conf/* -type d -exec $CHMOD 0770 {} \;
               find /projects/${HTTPDIR}/conf -type f -exec $CHMOD 0660 {} \;
               find /projects/${HTTPDIR}/conf -type f -name "plugin*" -exec $CHMOD 0640 {} \;
               find /projects/${HTTPDIR}/conf -type f -name "*.map" -exec $CHMOD 0640 {} \;
            else
               echo "    conf subdir is a link which does not match standard"
               echo "    Not handled by script"
            fi
         else
            echo "    conf subdir does not exist" 
         fi
         if [[ -d /projects/${HTTPDIR}/etc ]]; then
            echo "    Setting permissions of the etc subdir"
            chown -h root.eiadm /projects/${HTTPDIR}/etc
            if [[ ! -L /projects/${HTTPDIR}/etc ]]; then
               find /projects/${HTTPDIR}/etc -type d -exec chown -h root.eiadm {} \;
               find /projects/${HTTPDIR}/etc -type f -exec chown -h root.apps {} \;
               find /projects/${HTTPDIR}/etc -type d -exec $CHMOD 0775 {} \;
               find /projects/${HTTPDIR}/etc -type f -exec $CHMOD 0640 {} \;
            else
               echo "    etc subdir is a link which does not match standard"
               echo "    Not handled by script"
            fi
         else
            echo "    etc subdir does not exist"
         fi
         if [[ -d /projects/${HTTPDIR}/bin ]]; then
            echo "    Setting permissions of the bin subdir"
            chown -h root.eiadm /projects/${HTTPDIR}/bin
            if [[ ! -L /projects/${HTTPDIR}/bin ]]; then
               chown -hR root.eiadm /projects/${HTTPDIR}/bin/*
               $CHMODR 0770 /projects/${HTTPDIR}/bin
            else
               echo "    bin subdir is a link which does not match standard"
               echo "    Not handled by script"
            fi
         else
            echo "    bin subdir does not exist"
         fi
         if [[ -d /projects/${HTTPDIR}/lib ]]; then
            echo "    Setting permissions of the lib subdir"
            chown -h root.eiadm /projects/${HTTPDIR}/lib
            if [[ ! -L /projects/${HTTPDIR}/lib ]]; then
               find /projects/${HTTPDIR}/lib -type d -exec chown -h root.eiadm {} \;
               find /projects/${HTTPDIR}/lib -type f -exec chown -h root.eiadm {} \;
               find /projects/${HTTPDIR}/lib -type d -exec $CHMOD 0770 {} \;
               find /projects/${HTTPDIR}/lib -type f -exec $CHMOD 0640 {} \;
            else
               echo "    lib subdir is a link which does not match standard"
               echo "    Not handled by script"
            fi
         else
            echo "    lib subdir does not exist"
         fi
         echo
         echo "    Looking for any file or directory not explicitely handled"
         echo "    setting default ownership and perms"
         echo
         find /projects/${HTTPDIR}/* | egrep -v "/projects/${HTTPDIR}/conf|/projects/${HTTPDIR}/content|/projects/${HTTPDIR}/etc|/projects/${HTTPDIR}/bin|/projects/${HTTPDIR}/lib" | $XARGS chown -h root.eiadm {}
         find /projects/${HTTPDIR}/* -type d | egrep -v "/projects/${HTTPDIR}/conf|/projects/${HTTPDIR}/content|/projects/${HTTPDIR}/etc|/projects/${HTTPDIR}/bin|/projects/${HTTPDIR}/lib" | $XARGS $CHMOD 0770 {}
         find /projects/${HTTPDIR}/* -type f | egrep -v "/projects/${HTTPDIR}/conf|/projects/${HTTPDIR}/content|/projects/${HTTPDIR}/etc|/projects/${HTTPDIR}/bin|/projects/${HTTPDIR}/lib" | $XARGS $CHMOD 0660 {}
         # if permlist.cfg file exists .. .then call set_permissions.sh
         if [[ -f "/projects/${HTTPDIR}/conf/permlist.cfg" ]]; then
            echo "Old standard permlist.cfg found -- setting special permissions"
            cat /projects/${HTTPDIR}/conf/permlist.cfg | /lfs/system/tools/configtools/set_permissions.sh
         fi
         # if globalpermlist.cfg file exists .. .then call set_permissions.sh
         if [[ -f "/projects/${HTTPDIR}/conf/globalpermlist.cfg" ]]; then
            echo "Special permission file globalpermlist.cfg found -- processing"
            cat /projects/${HTTPDIR}/conf/globalpermlist.cfg | /lfs/system/tools/configtools/set_permissions.sh
         fi
         if [[ -f /etc/logrotate.d/http_plugin ]]; then
            echo "Setting perms on plugin logrotate config"
            chown root.${SYSTEM_GRP} /etc/logrotate.d/http_plugin
            $CHMOD 444 /etc/logrotate.d/http_plugin
         fi
      else
         echo "/projects/$HTTPDIR does not exist on this node as a real dir"
      fi
   else
      echo "HTTPDIR $HTTPDIR does not exit on this node"
   fi
} 

function updateinstaller_uninstall_61
{
   typeset SERVERROOT=$1 LASTLINES UPDATEINSTALLER=0

   if [[ $SERVERROOT == "" ]]; then
      echo "Function updateinstaller_uninstall_61 needs SERVERROOT defined"
      exit 1
   fi

   if [[ -d ${SERVERROOT}/UpdateInstaller ]]; then
      if [[ -f ${SERVERROOT}/UpdateInstaller/update.sh ]]; then
         echo "Previous UpdateInstaller install detected"
         if [[ -f ${SERVERROOT}/UpdateInstaller/uninstall/uninstall ]]; then
            if [[ -f ${SERVERROOT}/UpdateInstaller/logs/uninstall/log.txt ]]; then
               echo "    A previous UpdateInstaller uninstall log detected"
               echo "      Removing"
               rm ${SERVERROOT}/UpdateInstaller/logs/uninstall/*
               if [[ $? -gt 0 ]]; then
                  echo "    Removal of previous uninstall logs"
                  echo "      Failed"
                  return 3
               fi 
            fi
            echo "    Running UpdateInstaller uninstall script"
            echo "    Tail ${SERVERROOT}/UpdateInstaller/logs/uninstall/log.txt for uninstall details and progress"
            ${SERVERROOT}/UpdateInstaller/uninstall/uninstall -silent
            if [[ -f ${SERVERROOT}/UpdateInstaller/logs/uninstall/log.txt ]]; then
               LASTLINES=`tail -3 ${SERVERROOT}/UpdateInstaller/logs/uninstall/log.txt`
               if [[ "$LASTLINES" != "" ]]; then
                  echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
                  if [[ $? -eq 0 ]]; then
                     echo "    UpdateInstaller Uninstall Successful"
                     UPDATEINSTALLER=1
                  else
                     echo "    UpdateInstaller Uninstall Failed"
                     echo "    Last few lines of install log contain:"
                     echo "$LASTLINES"
                     echo ""
                     echo "    Please check install log for further details"
                     return 3
                  fi
               else
                  echo "    UpdateInstaller Uninstall log is empty"
                  echo "    UpdateInstaller Uninstall Failed"
                  return 3
               fi
            else
               echo "    Failed to find UpdateInstaller Uninstall log"
               echo "    UpdateInstaller Uninstall Failed"
               return 3
            fi
         else
            echo "    No UpdateInstaller uninstall program exist in"
            echo "      ${SERVERROOT}/UpdateInstaller"
            echo "    UpdateInstaller Uninstall Failed"
            return 3
         fi
      fi
      if [[ -f ${SERVERROOT}/UpdateInstaller/update.sh ]]; then
         echo "    The attempt at uninstalling the UpdateInstaller"
         echo "      Failed"
         return 2
      else
         if [[ $UPDATEINSTALLER -eq  0 ]]; then
            echo "Even though ${SERVERROOT}/UpdateInstaller exist"
            echo "  no viable UpdateInstaller install detected"
            echo "    Continuing ................."
            echo ""
         fi
         cd /tmp
         echo "    Removing ${SERVERROOT}/UpdateInstaller directory"
         rm -r ${SERVERROOT}/UpdateInstaller
         if [[ $? -gt 0 ]]; then
            echo "    Removal of UpdateInstaller directory"
            echo "      Failed"
            return 3
         fi 
      fi
      echo ""
   fi
}

function updateinstaller_uninstall_70
{
   typeset SERVERROOT=$1 LASTLINES UPDATEINSTALLER=0

   if [[ $SERVERROOT == "" ]]; then
      echo "Function updateinstaller_uninstall_70 needs SERVERROOT defined"
      exit 1
   fi

   if [[ -d ${SERVERROOT}/UpdateInstaller ]]; then
      if [[ -f ${SERVERROOT}/UpdateInstaller/update.sh ]]; then
         echo "Previous UpdateInstaller install detected"
         if [[ -f ${SERVERROOT}/UpdateInstaller/uninstall/uninstall ]]; then
            if [[ -f ${SERVERROOT}/UpdateInstaller/logs/uninstall/log.txt ]]; then
               echo "    A previous UpdateInstaller uninstall log detected"
               echo "      Removing"
               rm ${SERVERROOT}/UpdateInstaller/logs/uninstall/*
               if [[ $? -gt 0 ]]; then
                  echo "    Removal of previous uninstall logs"
                  echo "      Failed"
                  return 3
               fi 
            fi
            echo "    Running UpdateInstaller uninstall script"
            echo "    Tail ${SERVERROOT}/UpdateInstaller/logs/uninstall/log.txt for uninstall details and progress"
            ${SERVERROOT}/UpdateInstaller/uninstall/uninstall -silent
            if [[ -f ${SERVERROOT}/UpdateInstaller/logs/uninstall/log.txt ]]; then
               LASTLINES=`tail -3 ${SERVERROOT}/UpdateInstaller/logs/uninstall/log.txt`
               if [[ "$LASTLINES" != "" ]]; then
                  echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
                  if [[ $? -eq 0 ]]; then
                     echo "    UpdateInstaller Uninstall Successful"
                     UPDATEINSTALLER=1
                  else
                     echo "    UpdateInstaller Uninstall Failed"
                     echo "    Last few lines of install log contain:"
                     echo "$LASTLINES"
                     echo ""
                     echo "    Please check install log for further details"
                     return 3
                  fi
               else
                  echo "    UpdateInstaller Uninstall log is empty"
                  echo "    UpdateInstaller Uninstall Failed"
                  return 3
               fi
            else
               echo "    Failed to find UpdateInstaller Uninstall log"
               echo "    UpdateInstaller Uninstall Failed"
               return 3
            fi
         else
            echo "    No UpdateInstaller uninstall program exist in"
            echo "      ${SERVERROOT}/UpdateInstaller"
            echo "    UpdateInstaller Uninstall Failed"
            return 3
         fi
      fi
      if [[ -f ${SERVERROOT}/UpdateInstaller/update.sh ]]; then
         echo "    The attempt at uninstalling the UpdateInstaller"
         echo "      Failed"
         return 2
      else
         if [[ $UPDATEINSTALLER -eq  0 ]]; then
            echo "Even though ${SERVERROOT}/UpdateInstaller exist"
            echo "  no viable UpdateInstaller install detected"
            echo "    Continuing ................."
            echo ""
         fi
         cd /tmp
         echo "    Removing ${SERVERROOT}/UpdateInstaller directory"
         rm -r ${SERVERROOT}/UpdateInstaller
         if [[ $? -gt 0 ]]; then
            echo "    Removal of UpdateInstaller directory"
            echo "      Failed"
            return 3
         fi 
      fi
      echo ""
   fi
}

function updateinstaller_clean_logs_61
{
   typeset SERVER_LOG_TAG=$1 NOTHING_FOUND_INSTALL=0 NOTHING_FOUND_TMP=0

   if [[ $SERVER_LOG_TAG == "" ]]; then
      echo "Function updateinstaller_clean_logs_61 needs SERVER LOG TAG defined"
      exit 1
   fi

   if [[ -L /logs/${SERVER_LOG_TAG} ]]; then
      echo "    /logs/${SERVER_LOG_TAG} is a symlink"
      SERVER_LOG_TAG=`ls -l /logs/${SERVER_LOG_TAG} | awk {'print $NF'}`
      SERVER_LOG_TAG=`echo $SERVER_LOG_TAG | awk -F '/' {'print $NF'}`
      echo "    Real dir is /logs/${SERVER_LOG_TAG}"
   fi
   if [[ -d /logs/${SERVER_LOG_TAG} && ! -L /logs/${SERVER_LOG_TAG} ]]; then
      if [[ -d /logs/${SERVER_LOG_TAG}/UpdateInstaller ]]; then
         if [[ -d /logs/${SERVER_LOG_TAG}/UpdateInstaller/install || -d /logs/${SERVER_LOG_TAG}/UpdateInstaller/tmp ]]; then
            echo "Previous UpdateInstaller Log Directory detected"
            if [[ -d /logs/${SERVER_LOG_TAG}/UpdateInstaller/install ]]; then
               echo "    Cleaning UpdateInstaller install logs"
               rm -r /logs/${SERVER_LOG_TAG}/UpdateInstaller/install
               if [[ $? -gt 0 ]]; then
                  echo "    Removal of UpdateInstaller install logs"
                  echo "      Failed"
                  return 3
               fi
               NOTHING_FOUND_INSTALL=0
            else
               NOTHING_FOUND_INSTALL=1
            fi
            if [[ -d /logs/${SERVER_LOG_TAG}/UpdateInstaller/tmp ]]; then
               echo "    Cleaning UpdateInstaller tmp logs"
               rm -r /logs/${SERVER_LOG_TAG}/UpdateInstaller/tmp
               if [[ $? -gt 0 ]]; then
                  echo "    Removal of UpdateInstaller tmp logs"
                  echo "      Failed"
                  return 3
               fi
               NOTHING_FOUND_TMP=0
            else
               NOTHING_FOUND_TMP=1
            fi
            echo ""
         else
            NOTHING_FOUND_INSTALL=1
            NOTHING_FOUND_TMP=1
         fi
      else
         NOTHING_FOUND_INSTALL=1
         NOTHING_FOUND_TMP=1
      fi
   elif [[ -L /logs/${SERVER_LOG_TAG} ]]; then
      echo "    /logs/$SERVER_LOG_TAG is still a symlink --- not handled by script"
      echo "    UpdateInstaller log cleaning Failed"
      return 2
   fi

   if [[ $NOTHING_FOUND_INSTALL -eq  1 && $NOTHING_FOUND_TMP -eq 1 ]]; then
      return 100
   fi
}

function updateinstaller_clean_logs_70
{
   typeset SERVER_LOG_TAG=$1 NOTHING_FOUND_INSTALL=0 NOTHING_FOUND_TMP=0

   if [[ $SERVER_LOG_TAG == "" ]]; then
      echo "Function updateinstaller_clean_logs_70 needs SERVER LOG TAG defined"
      exit 1
   fi

   if [[ -L /logs/${SERVER_LOG_TAG} ]]; then
      echo "    /logs/${SERVER_LOG_TAG} is a symlink"
      SERVER_LOG_TAG=`ls -l /logs/${SERVER_LOG_TAG} | awk {'print $NF'}`
      SERVER_LOG_TAG=`echo $SERVER_LOG_TAG | awk -F '/' {'print $NF'}`
      echo "    Real dir is /logs/${SERVER_LOG_TAG}"
   fi
   if [[ -d /logs/${SERVER_LOG_TAG} && ! -L /logs/${SERVER_LOG_TAG} ]]; then
      if [[ -d /logs/${SERVER_LOG_TAG}/UpdateInstaller ]]; then
         if [[ -d /logs/${SERVER_LOG_TAG}/UpdateInstaller/install || -d /logs/${SERVER_LOG_TAG}/UpdateInstaller/tmp ]]; then
            echo "Previous UpdateInstaller Log Directory detected"
            if [[ -d /logs/${SERVER_LOG_TAG}/UpdateInstaller/install ]]; then
               echo "    Cleaning UpdateInstaller install logs"
               rm -r /logs/${SERVER_LOG_TAG}/UpdateInstaller/install
               if [[ $? -gt 0 ]]; then
                  echo "    Removal of UpdateInstaller install logs"
                  echo "      Failed"
                  return 3
               fi
               NOTHING_FOUND_INSTALL=0
            else
               NOTHING_FOUND_INSTALL=1
            fi
            if [[ -d /logs/${SERVER_LOG_TAG}/UpdateInstaller/tmp ]]; then
               echo "    Cleaning UpdateInstaller tmp logs"
               rm -r /logs/${SERVER_LOG_TAG}/UpdateInstaller/tmp
               if [[ $? -gt 0 ]]; then
                  echo "    Removal of UpdateInstaller tmp logs"
                  echo "      Failed"
                  return 3
               fi
               NOTHING_FOUND_TMP=0
            else
               NOTHING_FOUND_TMP=1
            fi
            echo ""
         else
            NOTHING_FOUND_INSTALL=1
            NOTHING_FOUND_TMP=1
         fi
      else
         NOTHING_FOUND_INSTALL=1
         NOTHING_FOUND_TMP=1
      fi
   elif [[ -L /logs/${SERVER_LOG_TAG} ]]; then
      echo "    /logs/$SERVER_LOG_TAG is still a symlink --- not handled by script"
      echo "    UpdateInstaller log cleaning Failed"
      return 2
   fi

   if [[ $NOTHING_FOUND_INSTALL -eq  1 && $NOTHING_FOUND_TMP -eq 1 ]]; then
      return 100
   fi
}

function base_ihs_uninstall_61
{
   typeset BASE_IHS=0 SERVERROOT=$1 BITS=$2 LASTLINES MESSAGE="" CHMOD CHMODR XARGS FS_TABLE

   if [[ $SERVERROOT == "" ]]; then
      echo "Function base_ihs_uninstall_61 needs SERVERROOT defined"
      exit 1
   fi

   if [[ $BITS == "" ]]; then
      echo "Function base_ihs_uninstall_61 needs BITS defined"
      exit 1
   fi

   os_specific_parameters_61 $BITS
   function_error_check os_specific_parameters_61 ihs

   if [[ -d $SERVERROOT ]]; then
      if [[ -L $SERVERROOT ]]; then
         echo "$SERVERROOT is a symlink and not handled by this script"
         echo "Can not determine if Base IHS is installed or not"
         return 2
      fi
      if [[ -f ${SERVERROOT}/bin/httpd ]]; then
         echo "Previous Base IHS install detected"
         if [[ -f ${SERVERROOT}/uninstall/uninstall ]]; then
            if [[ -f ${SERVERROOT}/logs/uninstall/log.txt ]]; then
               echo "    A previous Base IHS uninstall log detected"
               echo "      Removing"
               rm ${SERVERROOT}/logs/uninstall/*
               if [[ $? -gt 0 ]]; then
                  echo "    Removal of previous Base IHS uninstall logs"
                  echo "      Failed"
                  return 3
               fi
            fi
            echo "    Running Base IHS uninstall script"
            echo "    Tail ${SERVERROOT}/logs/uninstall/log.txt for uninstall details and progress"
            ${SERVERROOT}/uninstall/uninstall -silent
            if [[ -f ${SERVERROOT}/logs/uninstall/log.txt ]]; then
               LASTLINES=`tail -3 ${SERVERROOT}/logs/uninstall/log.txt`
               if [[ "$LASTLINES" != "" ]]; then
                  echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
                  if [[ $? -eq 0 ]]; then
                     echo "    Base IHS uninstall Successful"
                     BASE_IHS=1
                  else
                     echo "    Base IHS uninstall Failed"
                     echo "    Last few lines of install log contain:"
                     echo "$LASTLINES"
                     echo ""
                     echo "    Please check install log for further details"
                     return 3
                  fi
               else
                  echo "    Base IHS uninstall log is empty"
                  echo "    Base IHS uninstall Failed"
                  return 3
               fi
            else
               echo "    Failed to find Base IHS uninstall log"
               echo "    Base IHS uninstall Failed"
               return 3
            fi
         else
            echo "    No Base IHS uninstall program exist in"
            echo "      $SERVERROOT"
            return 3
         fi
      fi
      if [[ -f ${SERVERROOT}/Plugins/bin/mod_was_ap20_http.so ]]; then
         MESSAGE="      WAS Plugin installed \n"
      fi
      if [[ -f ${SERVERROOT}/UpdateInstaller/update.sh ]]; then
         MESSAGE="$MESSAGE      UpdateInstaller installed \n"
      fi
      if [[ -f ${SERVERROOT}/bin/httpd ]]; then
         MESSAGE="$MESSAGE      Base IHS installed \n"
      fi
      if [[ $MESSAGE != "" ]]; then
         echo "    After the attempt at uninstalling IHS products"
         echo "      at $SERVERROOT"
         echo "      the following IHS products were still found"
         printf "$MESSAGE"
         return 2
      else
         if [[ $BASE_IHS -eq 0 ]]; then
            echo "Even though $SERVERROOT exist"
            echo "  no viable Base IHS install detected"
            echo "    Continuing ................."
            echo ""
         fi
         cd /tmp
         if [[ `ls -1 $SERVERROOT | wc -l` -gt 0 ]]; then
            echo "    Removing remaining dest dir $SERVERROOT contents"
            rm -r $SERVERROOT/*
            if [[ $? -gt 0 ]]; then
               echo "    Removal of Base IHS server root directory contents"
               echo "      Failed"
               return 3
           fi
         fi
         df -Pm | grep " ${SERVERROOT}$" > /dev/null 2>&1
         if [[ $? -eq 0 ]]; then
            echo "    Removing filesystem $SERVERROOT"
            /fs/system/bin/eirmfs -f $SERVERROOT
            if [[ $? -gt 0 ]]; then
               echo "    Removal of filesystem $SERVERROOT"
               echo "      Failed"
               return 3
            fi
         fi
      fi
   fi
}

function base_ihs_uninstall_70
{
   typeset BASE_IHS=0 SERVERROOT=$1 BITS=$2 LASTLINES MESSAGE="" CHMOD CHMODR XARGS FS_TABLE

   if [[ $SERVERROOT == "" ]]; then
      echo "Function base_ihs_uninstall_70 needs SERVERROOT defined"
      exit 1
   fi

   if [[ $BITS == "" ]]; then
      echo "Function base_ihs_uninstall_70 needs BITS defined"
      exit 1
   fi

   os_specific_parameters_70 $BITS
   function_error_check os_specific_parameters_70 ihs

   if [[ -d $SERVERROOT ]]; then
      if [[ -L $SERVERROOT ]]; then
         echo "$SERVERROOT is a symlink and not handled by this script"
         echo "Can not determine if Base IHS is installed or not"
         return 2
      fi
      if [[ -f ${SERVERROOT}/bin/httpd ]]; then
         echo "Previous Base IHS install detected"
         if [[ -f ${SERVERROOT}/uninstall/uninstall ]]; then
            if [[ -f ${SERVERROOT}/logs/uninstall/log.txt ]]; then
               echo "    A previous Base IHS uninstall log detected"
               echo "      Removing"
               rm ${SERVERROOT}/logs/uninstall/*
               if [[ $? -gt 0 ]]; then
                  echo "    Removal of previous Base IHS uninstall logs"
                  echo "      Failed"
                  return 3
               fi
            fi
            echo "    Running Base IHS uninstall script"
            echo "    Tail ${SERVERROOT}/logs/uninstall/log.txt for uninstall details and progress"
            ${SERVERROOT}/uninstall/uninstall -silent
            if [[ -f ${SERVERROOT}/logs/uninstall/log.txt ]]; then
               LASTLINES=`tail -3 ${SERVERROOT}/logs/uninstall/log.txt`
               if [[ "$LASTLINES" != "" ]]; then
                  echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
                  if [[ $? -eq 0 ]]; then
                     echo "    Base IHS uninstall Successful"
                     BASE_IHS=1
                  else
                     echo "    Base IHS uninstall Failed"
                     echo "    Last few lines of install log contain:"
                     echo "$LASTLINES"
                     echo ""
                     echo "    Please check install log for further details"
                     return 3
                  fi
               else
                  echo "    Base IHS uninstall log is empty"
                  echo "    Base IHS uninstall Failed"
                  return 3
               fi
            else
               echo "    Failed to find Base IHS uninstall log"
               echo "    Base IHS uninstall Failed"
               return 3
            fi
         else
            echo "    No Base IHS uninstall program exist in"
            echo "      $SERVERROOT"
            return 3
         fi
      fi
      if [[ -f ${SERVERROOT}/Plugins/bin/mod_was_ap20_http.so ]]; then
         MESSAGE="      WAS Plugin installed \n"
      fi
      if [[ -f ${SERVERROOT}/UpdateInstaller/update.sh ]]; then
         MESSAGE="$MESSAGE      UpdateInstaller installed \n"
      fi
      if [[ -f ${SERVERROOT}/bin/httpd ]]; then
         MESSAGE="$MESSAGE      Base IHS installed \n"
      fi
      if [[ $MESSAGE != "" ]]; then
         echo "    After the attempt at uninstalling IHS products"
         echo "      at $SERVERROOT"
         echo "      the following IHS products were still found"
         printf "$MESSAGE"
         return 2
      else
         if [[ $BASE_IHS -eq 0 ]]; then
            echo "Even though $SERVERROOT exist"
            echo "  no viable Base IHS install detected"
            echo "    Continuing ................."
            echo ""
         fi
         cd /tmp
         if [[ `ls -1 $SERVERROOT | wc -l` -gt 0 ]]; then
            echo "    Removing remaining dest dir $SERVERROOT contents"
            rm -r $SERVERROOT/*
            if [[ $? -gt 0 ]]; then
               echo "    Removal of Base IHS server root directory contents"
               echo "      Failed"
               return 3
           fi
         fi
         df -Pm | grep " ${SERVERROOT}$" > /dev/null 2>&1
         if [[ $? -eq 0 ]]; then
            echo "    Removing filesystem $SERVERROOT"
            /fs/system/bin/eirmfs -f $SERVERROOT
            if [[ $? -gt 0 ]]; then
               echo "    Removal of filesystem $SERVERROOT"
               echo "      Failed"
               return 3
            fi
         fi
      fi
   fi
}

function base_ihs_clean_logs_61
{
   typeset SERVER_LOG_TAG=$1 NOTHING_FOUND_UPDATE=0 NOTHING_FOUND_INSTALL=0

   if [[ $SERVER_LOG_TAG == "" ]]; then
      echo "Function base_ihs_clean_logs needs SERVER LOG TAG defined"
      exit 1
   fi

   if [[ -L /logs/${SERVER_LOG_TAG} ]]; then
      echo "    /logs/${SERVER_LOG_TAG} is a symlink"
      SERVER_LOG_TAG=`ls -l /logs/${SERVER_LOG_TAG} | awk {'print $NF'}`
      SERVER_LOG_TAG=`echo $SERVER_LOG_TAG | awk -F '/' {'print $NF'}`
      echo "    Real dir is /logs/${SERVER_LOG_TAG}"
   fi
   if [[ -d /logs/${SERVER_LOG_TAG} && ! -L /logs/${SERVER_LOG_TAG} ]]; then
      if [[ -d /logs/${SERVER_LOG_TAG}/install || -d /logs/${SERVER_LOG_TAG}/update ]]; then
         echo "Previous Base IHS Log Directory detected"
         if [[ -d /logs/${SERVER_LOG_TAG}/install ]]; then
            echo "    Cleaning Base IHS install logs"
            rm -r /logs/${SERVER_LOG_TAG}/install
            if [[ $? -gt 0 ]]; then
               echo "    Removal of Base IHS install logs"
               echo "      Failed"
               return 3
            fi
            NOTHING_FOUND_INSTALL=0
         else
            NOTHING_FOUND_INSTALL=1
         fi
         if [[ -d /logs/${SERVER_LOG_TAG}/update ]]; then
            echo "    Cleaning Base IHS update logs"
            rm -r /logs/${SERVER_LOG_TAG}/update
            if [[ $? -gt 0 ]]; then
               echo "    Removal of Base IHS update logs"
               echo "      Failed"
               return 3
            fi
            NOTHING_FOUND_UPDATE=0
         else
            NOTHING_FOUND_UPDATE=1
         fi
         echo ""
      else
         NOTHING_FOUND_INSTALL=1
         NOTHING_FOUND_UPDATE=1
      fi
   elif [[ -L /logs/${SERVER_LOG_TAG} ]]; then
      echo "    /logs/$SERVER_LOG_TAG is still a symlink --- not handled by script"
      echo "    Base IHS log cleaning Failed"
      return 2
   fi

   if [[ $NOTHING_FOUND_INSTALL -eq 1 && $NOTHING_FOUND_UPDATE -eq 1 ]]; then
      return 100
   fi
}

function base_ihs_clean_logs_70
{
   typeset SERVER_LOG_TAG=$1 NOTHING_FOUND_UPDATE=0 NOTHING_FOUND_INSTALL=0

   if [[ $SERVER_LOG_TAG == "" ]]; then
      echo "Function base_ihs_clean_logs needs SERVER LOG TAG defined"
      exit 1
   fi

   if [[ -L /logs/${SERVER_LOG_TAG} ]]; then
      echo "    /logs/${SERVER_LOG_TAG} is a symlink"
      SERVER_LOG_TAG=`ls -l /logs/${SERVER_LOG_TAG} | awk {'print $NF'}`
      SERVER_LOG_TAG=`echo $SERVER_LOG_TAG | awk -F '/' {'print $NF'}`
      echo "    Real dir is /logs/${SERVER_LOG_TAG}"
   fi
   if [[ -d /logs/${SERVER_LOG_TAG} && ! -L /logs/${SERVER_LOG_TAG} ]]; then
      if [[ -d /logs/${SERVER_LOG_TAG}/install || -d /logs/${SERVER_LOG_TAG}/update ]]; then
         echo "Previous Base IHS Log Directory detected"
         if [[ -d /logs/${SERVER_LOG_TAG}/install ]]; then
            echo "    Cleaning Base IHS install logs"
            rm -r /logs/${SERVER_LOG_TAG}/install
            if [[ $? -gt 0 ]]; then
               echo "    Removal of Base IHS install logs"
               echo "      Failed"
               return 3
            fi
            NOTHING_FOUND_INSTALL=0
         else
            NOTHING_FOUND_INSTALL=1
         fi
         if [[ -d /logs/${SERVER_LOG_TAG}/update ]]; then
            echo "    Cleaning Base IHS update logs"
            rm -r /logs/${SERVER_LOG_TAG}/update
            if [[ $? -gt 0 ]]; then
               echo "    Removal of Base IHS update logs"
               echo "      Failed"
               return 3
            fi
            NOTHING_FOUND_UPDATE=0
         else
            NOTHING_FOUND_UPDATE=1
         fi
         echo ""
      else
         NOTHING_FOUND_INSTALL=1
         NOTHING_FOUND_UPDATE=1
      fi
   elif [[ -L /logs/${SERVER_LOG_TAG} ]]; then
      echo "    /logs/$SERVER_LOG_TAG is still a symlink --- not handled by script"
      echo "    Base IHS log cleaning Failed"
      return 2
   fi

   if [[ $NOTHING_FOUND_INSTALL -eq 1 && $NOTHING_FOUND_UPDATE -eq 1 ]]; then
      return 100
   fi
}

function base_ihs_clean_logs_85
{
   typeset SERVER_LOG_TAG=$1 NOTHING_FOUND_UPDATE=0 NOTHING_FOUND_INSTALL=0 NOTHING_FOUND_POSTINSTALL=0

   if [[ $SERVER_LOG_TAG == "" ]]; then
      echo "Function base_ihs_clean_logs needs SERVER LOG TAG defined"
      exit 1
   fi

   if [[ -L /logs/${SERVER_LOG_TAG} ]]; then
      echo "    /logs/${SERVER_LOG_TAG} is a symlink"
      SERVER_LOG_TAG=`ls -l /logs/${SERVER_LOG_TAG} | awk {'print $NF'}`
      SERVER_LOG_TAG=`echo $SERVER_LOG_TAG | awk -F '/' {'print $NF'}`
      echo "    Real dir is /logs/${SERVER_LOG_TAG}"
   fi
   if [[ -d /logs/${SERVER_LOG_TAG} && ! -L /logs/${SERVER_LOG_TAG} ]]; then
      if [[ -d /logs/${SERVER_LOG_TAG}/install || -d /logs/${SERVER_LOG_TAG}/postinstall || -d /logs/${SERVER_LOG_TAG}/update ]]; then
         echo "Previous Base IHS Log Directory detected"
         if [[ -d /logs/${SERVER_LOG_TAG}/install ]]; then
            echo "    Cleaning Base IHS install logs"
            rm -r /logs/${SERVER_LOG_TAG}/install
            if [[ $? -gt 0 ]]; then
               echo "    Removal of Base IHS install logs"
               echo "      Failed"
               return 3
            fi
            NOTHING_FOUND_INSTALL=0
         else
            NOTHING_FOUND_INSTALL=1
         fi
         if [[ -d /logs/${SERVER_LOG_TAG}/postinstall ]]; then
            echo "    Cleaning Base IHS postinstall logs"
            rm -r /logs/${SERVER_LOG_TAG}/postinstall
            if [[ $? -gt 0 ]]; then
               echo "    Removal of Base IHS postinstall logs"
               echo "      Failed"
               return 3
            fi
            NOTHING_FOUND_POSTINSTALL=0
         else
            NOTHING_FOUND_POSTINSTALL=1
         fi
         if [[ -d /logs/${SERVER_LOG_TAG}/update ]]; then
            echo "    Cleaning Base IHS update logs"
            rm -r /logs/${SERVER_LOG_TAG}/update
            if [[ $? -gt 0 ]]; then
               echo "    Removal of Base IHS update logs"
               echo "      Failed"
               return 3
            fi
            NOTHING_FOUND_UPDATE=0
         else
            NOTHING_FOUND_UPDATE=1
         fi
         echo ""
      else
         NOTHING_FOUND_INSTALL=1
         NOTHING_FOUND_POSTINSTALL=1
         NOTHING_FOUND_UPDATE=1
      fi
   elif [[ -L /logs/${SERVER_LOG_TAG} ]]; then
      echo "    /logs/$SERVER_LOG_TAG is still a symlink --- not handled by script"
      echo "    Base IHS log cleaning Failed"
      return 2
   fi

   if [[ $NOTHING_FOUND_INSTALL -eq 1 && $NOTHING_FOUND_POSTINSTALL -eq 1 && $NOTHING_FOUND_UPDATE -eq 1 ]]; then
      return 100
   fi
}

function UpdateInstaller_61
{
   typeset FULLVERSION=$1 IHSBASELEVEL=$2 DESTDIR=$3 BITS=$4 UPDI_LEVEL=$5 TOOLSDIR=$6 PRODUCT=$7 SLEEP=$8 WASSRCDIR SRCDIR RESPDIR UPDRESPFILE FIXLEVEL UPDATEVERSION CURFIXLEVEL NEWFIXLEVEL LASTLINES  NODRYRUN_VALUE CHMOD CHMODR XARGS FS_TABLE SYSTEM_GRP
   typeset HTTPLOG=`echo ${DESTDIR} | cut -d"/" -f3` BASELEVEL=`echo $FULLVERSION | cut -c1,2` MAJORNUM=`echo $BASELEVEL | cut -c1` MINORNUM=`echo $BASELEVEL | cut -c2`

   if [[ $FULLVERSION == "" ]]; then
      echo "Function UpdateInstaller_61 needs FULLVERSION defined"
      exit 1
   fi
   if [[ $IHSBASELEVEL == "" ]]; then
      echo "Function UpdateInstaller_61 needs IHSBASELEVEL defined"
      exit 1
   fi
   if [[ $DESTDIR == "" ]]; then
      echo "Function UpdateInstaller_61 needs DESTDIR defined"
      exit 1
   fi
   if [[ $BITS == "" ]]; then
      echo "Function UpdateInstaller_61 needs BITS defined"
      exit 1
   fi
   if [[ $UPDI_LEVEL == "" ]]; then
      echo "Function UpdateInstaller_61 needs UPDI_LEVEL defined"
      exit 1
   fi
   if [[ $TOOLSDIR == "" ]]; then
      echo "Function UpdateInstaller_61 needs TOOLSDIR defined"
      exit 1
   fi

   if [[ $PRODUCT != "ihs" && $PRODUCT != "plug" ]]; then
      echo "Function UpdateInstaller_61 needs PRODUCT defined"
      echo "Must be a value of \"ihs\" or \"plug\""
      exit 1
   elif [[ $PRODUCT == "ihs" ]]; then
      CAPTION="IHS/SDK"
   elif [[ $PRODUCT == "plug" ]]; then
      CAPTION="WAS PLUGIN/SDK" 
   fi

   echo "---------------------------------------------------------------"
   echo "                Install UpdateInstaller"
   echo "---------------------------------------------------------------"
   echo ""

   # Verify Base IHS is installed --- if not abort
   if [[ ! -f ${DESTDIR}/bin/httpd ]]; then
      echo "Base IHS install not detected"
      echo "Exiting UpdateInstaller install"
      echo "Note:  Can not install any updates"
      echo ""
      return 2
   fi

   os_specific_parameters_61 $BITS
   function_error_check os_specific_parameters_61 $PRODUCT

   updateinstaller_version_61 $DESTDIR short
   updateinstaller_sdk_version_61 $DESTDIR
   echo ""
   SRCDIR="${WASSRCDIR}/supplements"
   RESPDIR="${TOOLSDIR}/ihs/responsefiles"
   UPDRESPFILE=ihs${MAJORNUM}.${MINORNUM}.updinst.silent.script
   if [[ ! -d ${WASSRCDIR}/update/UPDI-${UPDI_LEVEL}/UpdateInstaller ]]; then
      echo "    UpdateInstaller image not found in"
      echo "       $WASSRCDIR/update/UPDI-${UPDI_LEVEL}/UpdateInstaller"
      echo "    Exiting UpdateInstaller install"
      echo "    Note:  Can not install any updates"
      echo ""
      return 2
   elif [[ ! -f ${RESPDIR}/${UPDRESPFILE} ]]; then
      echo "    File ${RESPDIR}/${UPDRESPFILE} does not exist"
      echo "    Use Tivoli SD tools to push ${TOOLSDIR}/ihs files to this server"
      echo "    Exiting UpdateInstaller install"
      echo "    Note:  Can not install any updates"
      echo ""
      return 2
   else
      if [[ -f ${DESTDIR}/UpdateInstaller/version.txt ]]; then
         FIXLEVEL=`cat ${DESTDIR}/UpdateInstaller/version.txt| grep Version: | awk {'print $2'}`
      elif [[ ! -f ${DESTDIR}/UpdateInstaller/update.sh ]]; then
         FIXLEVEL=0.0.0.0
      else
         echo "    An UpdateInstaller installed --- unable to determine version"
         echo "    Aborting UpdateInstaller install"
         echo "Note:  Can not install any updates."
         echo ""
         return 2
      fi
      UPDIVERSION=`cat ${WASSRCDIR}/update/UPDI-${UPDI_LEVEL}/UpdateInstaller/version.txt| grep Version: | awk {'print $2'}`
      CURFIXLEVEL=`echo $FIXLEVEL| awk -F . '{ print ($1*1000000)+($2*10000)+($3*100)+$4 }'`
      NEWFIXLEVEL=`echo $UPDIVERSION| awk -F . '{ print ($1*1000000)+($2*10000)+($3*100)+$4 }'`
      if [[ $CURFIXLEVEL -lt $NEWFIXLEVEL ]]; then
         echo "Installing version of UpdateInstaller needed to install"
         echo "  fixpacks to obtain $CAPTION fixlevel $FULLVERSION (${UPDIVERSION} --> ${UPDI_LEVEL})"
         echo "  to ${DESTDIR}/UpdateInstaller"
         echo "  in $SLEEP seconds"
         echo "    Ctrl-C to suspend"
         echo ""
         install_timer $SLEEP
         function_error_check install_timer $PRODUCT
         updateinstaller_uninstall_61 $DESTDIR
         updateinstaller_clean_logs_61 $HTTPLOG 
         echo "Installing UpdateInstaller ($UPDIVERSION)"
         cp ${RESPDIR}/${UPDRESPFILE} /tmp/${UPDRESPFILE}
         cd /tmp
         sed -e "s%installLocation=.*%installLocation=${DESTDIR}/UpdateInstaller%" ${UPDRESPFILE} > ${UPDRESPFILE}.custom && mv ${UPDRESPFILE}.custom  ${UPDRESPFILE}
         if [[ $? -gt 0 ]]; then
            echo "    Edit to response file for install location"
            echo "      Failed"
            echo ""
            return 3
         fi
         # Install using edited responsefile
         if [[ -f ${WASSRCDIR}/update/UPDI-${UPDI_LEVEL}/UpdateInstaller/install ]]; then
            ${WASSRCDIR}/update/UPDI-${UPDI_LEVEL}/UpdateInstaller/install -options /tmp/${UPDRESPFILE} -silent 
         else
            echo "UpdateInstaller install program not located in the image directory"
            echo "Aborting UpdateInstaller install"
            echo ""
            return 3
         fi
         if [[ -f ${DESTDIR}/UpdateInstaller/logs/install/log.txt ]]; then
            LASTLINES=`tail -3 ${DESTDIR}/UpdateInstaller/logs/install/log.txt`
            if [[ "$LASTLINES" != "" ]]; then
               echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
               if [[ $? -eq 0 ]]; then
                  echo "    UpdateInstaller install Successful"
                  printf "    "
                  updateinstaller_version_61 $DESTDIR short
                  printf "    "
                  updateinstaller_sdk_version_61 $DESTDIR
                  echo ""
               else
                  echo "    UpdateInstaller install Failed"
                  echo "    Last few lines of install log contain:"
                  echo "$LASTLINES"
                  echo ""
                  echo "    Please check install log for further details"
                  echo ""
                  return 3
               fi
            else
               echo "    UpdateInstaller install log is empty"
               echo "    UpdateInstaller install Failed"
               echo ""
               return 3
            fi
         else
            echo "    Failed to find UpdateInstaller install log"
            echo "    UpdateInstaller install Failed"
            echo ""
            return 3
         fi

         echo "Setting up UpdateInstaller log directory according to the"
         echo "  EI standards for an IHS webserver"
         echo ""
         if [[ -d /logs/${HTTPLOG} ]]; then
            if [[ -d ${DESTDIR}/UpdateInstaller/logs && ! -L ${DESTDIR}/UpdateInstaller/logs ]]; then
               if [[ ! -d /logs/${HTTPLOG}/UpdateInstaller ]]; then
                  echo "    Creating /logs/${HTTPLOG}/UpdateInstaller"
                  mkdir /logs/${HTTPLOG}/UpdateInstaller
                  if [[ $? -gt 0 ]]; then
                     echo "    Creation of UpdateInstaller log directory"
                     echo "      Failed"
                     echo ""
                     return 3
                  fi
               fi

               #Preserve the value of the EI_FILESYNC_NODR env variable
               #Set it to 1 for these syncs
               NODRYRUN_VALUE=`echo $EI_FILESYNC_NODR`
               export EI_FILESYNC_NODR=1

               if [[ -d /logs/${HTTPLOG}/UpdateInstaller ]]; then
                  echo "    Rsync over UpdateInstaller logs"
                  ${TOOLSDIR}/configtools/filesync ${DESTDIR}/UpdateInstaller/logs/ /logs/${HTTPLOG}/UpdateInstaller/ avc 0 0
                  if [[ $? -gt 0 ]]; then
                     echo "    UpdateInstaller log filesync"
                     echo "       Failed"
                     echo ""
                     return 2
                  else
                     echo ""
                     echo "    Replacing ${DESTDIR}/UpdateInstaller/log"
                     echo "      with a symlink to /logs/${HTTPLOG}/UpdateInstaller"
                     rm -r ${DESTDIR}/UpdateInstaller/logs
                     if [[ $? -gt 0 ]]; then
                        echo "    Removal of old UpdateInstaller log dir"
                        echo "      Failed"
                        echo ""
                        return 3
                     else
                        ln -s /logs/${HTTPLOG}/UpdateInstaller ${DESTDIR}/UpdateInstaller/logs
                        if [[ $? -gt 0 ]]; then
                           echo "    Creation of link for UpdateInstaller logs"
                           echo "      Failed"
                           echo ""
                           return 3
                        fi
                     fi
                  fi
               fi
               echo ""
               #Restoring env variable EI_FILESYNC_NODR to previous value
               export EI_FILESYNC_NODR=$NODRYRUN_VALUE         
            elif [[ -L ${DESTDIR}/UpdateInstaller/logs ]]; then
               echo "    This is not a fresh UpdateInstaller install"
               echo "    Check script output for details"
               echo ""
               return 2
            else
               echo "    Can not find any UpdateInstaller logs"
               echo "    Aborting the install"
               echo ""
               return 2
            fi
         else
            echo "    Can not find Base IHS logs"
            echo "    Aborting the install"
            echo ""
            return 2
         fi
      else
         echo "    UpdateInstaller is already at a version (${FIXLEVEL})"
         echo "      which is equal to or higher then"
         echo "      the requested level of $UPDIVERSION (${UPDI_LEVEL})"
         echo ""
      fi
   fi
}

function UpdateInstaller_70
{
   typeset FULLVERSION=$1 IHSBASELEVEL=$2 DESTDIR=$3 BITS=$4 UPDI_LEVEL=$5 TOOLSDIR=$6 PRODUCT=$7 SLEEP=$8 WASSRCDIR SRCDIR RESPDIR UPDRESPFILE FIXLEVEL UPDATEVERSION CURFIXLEVEL NEWFIXLEVEL LASTLINES  NODRYRUN_VALUE CHMOD CHMODR XARGS FS_TABLE SYSTEM_GRP
   typeset HTTPLOG=`echo ${DESTDIR} | cut -d"/" -f3` BASELEVEL=`echo $FULLVERSION | cut -c1,2` MAJORNUM=`echo $BASELEVEL | cut -c1` MINORNUM=`echo $BASELEVEL | cut -c2`

   if [[ $FULLVERSION == "" ]]; then
      echo "Function UpdateInstaller_70 needs FULLVERSION defined"
      exit 1
   fi
   if [[ $IHSBASELEVEL == "" ]]; then
      echo "Function UpdateInstaller_70 needs IHSBASELEVEL defined"
      exit 1
   fi
   if [[ $DESTDIR == "" ]]; then
      echo "Function UpdateInstaller_70 needs DESTDIR defined"
      exit 1
   fi
   if [[ $BITS == "" ]]; then
      echo "Function UpdateInstaller_70 needs BITS defined"
      exit 1
   fi
   if [[ $UPDI_LEVEL == "" ]]; then
      echo "Function UpdateInstaller_70 needs UPDI_LEVEL defined"
      exit 1
   fi
   if [[ $TOOLSDIR == "" ]]; then
      echo "Function UpdateInstaller_70 needs TOOLSDIR defined"
      exit 1
   fi

   if [[ $PRODUCT != "ihs" && $PRODUCT != "plug" ]]; then
      echo "Function UpdateInstaller_70 needs PRODUCT defined"
      echo "Must be a value of \"ihs\" or \"plug\""
      exit 1
   elif [[ $PRODUCT == "ihs" ]]; then
      CAPTION="IHS/SDK"
   elif [[ $PRODUCT == "plug" ]]; then
      CAPTION="WAS PLUGIN/SDK" 
   fi

   echo "---------------------------------------------------------------"
   echo "                Install UpdateInstaller"
   echo "---------------------------------------------------------------"
   echo ""

   # Verify Base IHS is installed --- if not abort
   if [[ ! -f ${DESTDIR}/bin/httpd ]]; then
      echo "Base IHS install not detected"
      echo "Exiting UpdateInstaller install"
      echo "Note:  Can not install any updates"
      echo ""
      return 2
   fi

   os_specific_parameters_70 $BITS
   function_error_check os_specific_parameters_70 $PRODUCT

   updateinstaller_version_70 $DESTDIR short
   updateinstaller_sdk_version_70 $DESTDIR
   echo ""
   SRCDIR="${WASSRCDIR}/supplements"
   RESPDIR="${TOOLSDIR}/ihs/responsefiles"
   UPDRESPFILE=ihs${MAJORNUM}.${MINORNUM}.updinst.silent.script
   if [[ ! -d ${WASSRCDIR}/update/UPDI-${UPDI_LEVEL}/UpdateInstaller ]]; then
      echo "    UpdateInstaller image not found in"
      echo "       $WASSRCDIR/update/UPDI-${UPDI_LEVEL}/UpdateInstaller"
      echo "    Exiting UpdateInstaller install"
      echo "    Note:  Can not install any updates"
      echo ""
      return 2
   elif [[ ! -f ${RESPDIR}/${UPDRESPFILE} ]]; then
      echo "    File ${RESPDIR}/${UPDRESPFILE} does not exist"
      echo "    Use Tivoli SD tools to push ${TOOLSDIR}/ihs files to this server"
      echo "    Exiting UpdateInstaller install"
      echo "    Note:  Can not install any updates"
      echo ""
      return 2
   else
      if [[ -f ${DESTDIR}/UpdateInstaller/version.txt ]]; then
         FIXLEVEL=`cat ${DESTDIR}/UpdateInstaller/version.txt| grep Version: | awk {'print $2'}`
      elif [[ ! -f ${DESTDIR}/UpdateInstaller/update.sh ]]; then
         FIXLEVEL=0.0.0.0
      else
         echo "    An UpdateInstaller installed --- unable to determine version"
         echo "    Aborting UpdateInstaller install"
         echo "Note:  Can not install any updates."
         echo ""
         return 2
      fi
      UPDIVERSION=`cat ${WASSRCDIR}/update/UPDI-${UPDI_LEVEL}/UpdateInstaller/version.txt| grep Version: | awk {'print $2'}`
      CURFIXLEVEL=`echo $FIXLEVEL| awk -F . '{ print ($1*1000000)+($2*10000)+($3*100)+$4 }'`
      NEWFIXLEVEL=`echo $UPDIVERSION| awk -F . '{ print ($1*1000000)+($2*10000)+($3*100)+$4 }'`
      if [[ $CURFIXLEVEL -lt $NEWFIXLEVEL ]]; then
         echo "Installing version of UpdateInstaller needed to install"
         echo "  fixpacks to obtain $CAPTION fixlevel $FULLVERSION (${UPDIVERSION} --> ${UPDI_LEVEL})"
         echo "  to ${DESTDIR}/UpdateInstaller"
         echo "  in $SLEEP seconds"
         echo "    Ctrl-C to suspend"
         echo ""
         install_timer $SLEEP
         function_error_check install_timer $PRODUCT
         updateinstaller_uninstall_70 $DESTDIR
         updateinstaller_clean_logs_70 $HTTPLOG 
         echo "    Installing UpdateInstaller ($UPDIVERSION)"
         cp ${RESPDIR}/${UPDRESPFILE} /tmp/${UPDRESPFILE}
         cd /tmp
         sed -e "s%installLocation=.*%installLocation=${DESTDIR}/UpdateInstaller%" ${UPDRESPFILE} > ${UPDRESPFILE}.custom && mv ${UPDRESPFILE}.custom  ${UPDRESPFILE}
         if [[ $? -gt 0 ]]; then
            echo "    Edit to response file for install location"
            echo "      Failed"
            echo ""
            return 3
         fi
         # Install using edited responsefile
         if [[ -f ${WASSRCDIR}/update/UPDI-${UPDI_LEVEL}/UpdateInstaller/install ]]; then
            ${WASSRCDIR}/update/UPDI-${UPDI_LEVEL}/UpdateInstaller/install -options /tmp/${UPDRESPFILE} -silent
         else
            echo "UpdateInstaller install program not located in the image directory"
            echo "Aborting UpdateInstaller install"
            echo ""
            return 3
         fi
         if [[ -f ${DESTDIR}/UpdateInstaller/logs/install/log.txt ]]; then
            LASTLINES=`tail -3 ${DESTDIR}/UpdateInstaller/logs/install/log.txt`
            if [[ "$LASTLINES" != "" ]]; then
               echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
               if [[ $? -eq 0 ]]; then
                  echo "    UpdateInstaller install Successful"
                  printf "    "
                  updateinstaller_version_61 $DESTDIR short
                  printf "    "
                  updateinstaller_sdk_version_61 $DESTDIR
                  echo ""
               else
                  echo "    UpdateInstaller install Failed"
                  echo "    Last few lines of install log contain:"
                  echo "$LASTLINES"
                  echo ""
                  echo "    Please check install log for further details"
                  echo ""
                  return 3
               fi
            else
               echo "    UpdateInstaller install log is empty"
               echo "    UpdateInstaller install Failed"
               echo ""
               return 3
            fi
         else
            echo "    Failed to find UpdateInstaller install log"
            echo "    UpdateInstaller install Failed"
            echo ""
            return 3
         fi

         echo "Setting up UpdateInstaller log directory according to the"
         echo "  EI standards for an IHS webserver"
         echo ""
         if [[ -d /logs/${HTTPLOG} ]]; then
            if [[ -d ${DESTDIR}/UpdateInstaller/logs && ! -L ${DESTDIR}/UpdateInstaller/logs ]]; then
               if [[ ! -d /logs/${HTTPLOG}/UpdateInstaller ]]; then
                  echo "    Creating /logs/${HTTPLOG}/UpdateInstaller"
                  mkdir /logs/${HTTPLOG}/UpdateInstaller
                  if [[ $? -gt 0 ]]; then
                     echo "    Creation of UpdateInstaller log directory"
                     echo "      Failed"
                     echo ""
                     return 3
                  fi
               fi

               #Preserve the value of the EI_FILESYNC_NODR env variable
               #Set it to 1 for these syncs
               NODRYRUN_VALUE=`echo $EI_FILESYNC_NODR`
               export EI_FILESYNC_NODR=1

               if [[ -d /logs/${HTTPLOG}/UpdateInstaller ]]; then
                  echo "    Rsync over UpdateInstaller logs"
                  ${TOOLSDIR}/configtools/filesync ${DESTDIR}/UpdateInstaller/logs/ /logs/${HTTPLOG}/UpdateInstaller/ avc 0 0
                  if [[ $? -gt 0 ]]; then
                     echo "    UpdateInstaller log filesync"
                     echo "       Failed"
                     echo ""
                     return 2
                  else
                     echo ""
                     echo "    Replacing ${DESTDIR}/UpdateInstaller/log"
                     echo "      with a symlink to /logs/${HTTPLOG}/UpdateInstaller"
                     rm -r ${DESTDIR}/UpdateInstaller/logs
                     if [[ $? -gt 0 ]]; then
                        echo "    Removal of old UpdateInstaller log dir"
                        echo "      Failed"
                        echo ""
                        return 3
                     else
                        ln -s /logs/${HTTPLOG}/UpdateInstaller ${DESTDIR}/UpdateInstaller/logs
                        if [[ $? -gt 0 ]]; then
                           echo "    Creation of link for UpdateInstaller logs"
                           echo "      Failed"
                           echo ""
                           return 3
                        fi
                     fi
                  fi
               fi
               echo ""
               #Restoring env variable EI_FILESYNC_NODR to previous value
               export EI_FILESYNC_NODR=$NODRYRUN_VALUE         
            elif [[ -L ${DESTDIR}/UpdateInstaller/logs ]]; then
               echo "    This is not a fresh UpdateInstaller install"
               echo "    Check script output for details"
               echo ""
               return 2
            else
               echo "    Can not find any UpdateInstaller logs"
               echo "    Aborting the install"
               echo ""
               return 2
            fi
         else
            echo "    Can not find Base IHS logs"
            echo "    Aborting the install"
            echo ""
            return 2
         fi
      else
         echo "    UpdateInstaller is already at a version (${FIXLEVEL})"
         echo "      which is equal to or higher then"
         echo "      the requested level of $UPDIVERSION (${UPDI_LEVEL})"
         echo ""
      fi
   fi
}

function install_ihs_fixes_61
{
   typeset FULLVERSION=$1 DESTDIR=$2 BITS=$3 TOOLSDIR=$4 SLEEP=$5 SKIPUPDATES=$6 PACKAGES=$7 WASSRCDIR SRCDIR RESPDIR FIXRESPFILE LIST SPLITPACKAGES FIXPKG FIXTYPE FIXPACKID CURFIXLEVEL NEWFIXLEVEL SDKVERSION ERROR LINENUM LASTLINES ITEM LIST_TMP CHMOD CHMODR XARGS FS_TABLE SYSTEM_GRP
   typeset BASELEVEL=`echo $FULLVERSION | cut -c1,2` MAJORNUM=`echo $BASELEVEL | cut -c1` MINORNUM=`echo $BASELEVEL | cut -c2`

   if [[ $FULLVERSION == "" ]]; then
      echo "Function install_ihs_fixes_61 needs FULLVERSION defined"
      exit 1
   fi

   if [[ $DESTDIR == "" ]]; then
      echo "Function install_ihs_fixes_61 needs DESTDIR defined"
      exit 1
   fi

   if [[ $BITS == "" ]]; then
      echo "Function install_ihs_fixes_61 needs BITS defined"
      exit 1
   fi

   if [[ $TOOLSDIR == "" ]]; then
      echo "Function install_ihs_fixes_61 needs TOOLSDIR defined"
      exit 1
   fi

   if [[ $SLEEP == "" ]]; then
      echo "Function install_ihs_fixes_61 needs SLEEP defined"
      exit 1
   fi

   if [[ $SKIPUPDATES == "" ]]; then
      echo "Function install_ihs_fixes_61 needs SKIPUPDATES defined"
      exit 1
   fi

   if [[ $PACKAGES == "" ]]; then
      echo "Function install_ihs_fixes_61 needs PACKAGES defined"
      echo "Specify \"all\" to install all packages for this fixlevel"
      exit 1
   fi

   echo "---------------------------------------------------------------"
   echo "                Install IHS/SDK Fixpacks"
   echo "---------------------------------------------------------------"
   echo ""

   # Verify IHS is installed or exit if not
   if [[ ! -f ${DESTDIR}/bin/httpd ]]; then
      echo "Base IHS install not detected"
      echo "Skipping updates"
      echo ""
      return 1
   fi
     
   if [[ $SKIPUPDATES -eq 1 ]]; then
      echo "Install of UpdateInstaller required to install fixes"
      echo "  Failed"
      echo "Skipping updates"
      echo ""
      return 1
   fi 

   os_specific_parameters_61 $BITS
   function_error_check os_specific_parameters_61 ihs

   SRCDIR="${WASSRCDIR}/supplements/fixes/${FULLVERSION}/ihs"
   RESPDIR="${TOOLSDIR}/ihs/responsefiles"
   FIXRESPFILE=ihs${MAJORNUM}.${MINORNUM}.fixes.silent.script

   if [[ -d ${SRCDIR} ]]; then
      cd ${SRCDIR}
   else
      echo "Image fixes directory for IHS fullversion ${FULLVERSION}" 
      echo "  does not exist"
      echo "Skipping updates"
      echo ""
      return 1
   fi

   if [[ $PACKAGES == "all" ]]; then
      ls *.pak > /dev/null 2>&1
      if [[ $? -eq 0 ]]; then 
         PACKAGE_LIST=`ls *.pak`
      fi
   else
      SPLITPACKAGES=`echo ${PACKAGES} | sed 's/\:/\\\n/g'`
      PACKAGE_LIST=`echo ${SPLITPACKAGES}`
      for ITEM in $PACKAGE_LIST; do
         ls $ITEM > /dev/null 2>&1
         if [[ $? -ne 0 ]]; then
            echo "Package $ITEM does not exist at"
            echo "  ${SRCDIR}"
            echo "Check the requested fixes list"
            echo "Skipping updates"
            echo ""
            return 1
         fi
      done
   fi

   for FIXPKG in $PACKAGE_LIST
   do
      FIXPACKID=${FIXPKG%.*}
      if [[ -f ${DESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt ]]; then
         LASTLINES=`tail -3 ${DESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt`
         if [[ "$LASTLINES" != "" ]]; then
            echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
            if [[ $? -eq 0 ]]; then
               FIXPKG=""
            fi
         fi
      fi
      if [[ ${FIXPKG} != "" ]]; then
         LIST_TMP="${LIST_TMP}${FIXPKG}\n"
      fi
   done
   if [[ $LIST_TMP != "" ]]; then
      LIST=`echo ${LIST_TMP} | grep -n pak |sed 's/^\([0-9]*\):/\1.- /'`
   else
      if [[ $SPLITPACKAGES != "" ]]; then
         echo "All requested fixes are already successfully installed"
         echo "  Aborting Fixpack install"
      else
         echo "All fixes required of IHS version $FULLVERSION"
         echo "  are successfully installed"
         echo "  Aborting Fixpack install"
      fi
      echo ""
      return 200
   fi

   if [[ ! -f ${DESTDIR}/UpdateInstaller/update.sh ]]; then
      echo "Cannot find ${DESTDIR}/UpdateInstaller/update.sh"
      echo "Skipping updates"
      echo ""
      return 1
   elif [[ $LIST != "" ]]; then
      echo "Applying fixpacks in this order"
      echo "  to IHS $BASELEVEL"
      echo "  located in $DESTDIR"
      echo "  to obtain IHS/SDK fixlevel $FULLVERSION"
      echo "  in $SLEEP seconds"
      echo "    Ctrl-C to suspend"
      echo ""
      echo "$LIST"
      echo ""
      install_timer $SLEEP
      function_error_check install_timer ihs

      LINENUM=1
      echo "Beginning fixpack installation process"
      echo "################################################################################"
      echo ""
      for FIXPKG in $LIST; do
         if [[ $FIXPKG == *.pak ]]; then
            echo "${LINENUM}) ${FIXPKG%.*}"
            echo "--------------------------------------------------------------------------------"
            echo ${FIXPKG} | grep -q SDK
            if [[ $? -eq 0 ]]; then
               FIXTYPE=SDK
            else
               echo ${FIXPKG} | grep -q IFP
               if [[ $? -eq 0 ]]; then
                  FIXTYPE=IF
               else
                  FIXTYPE=`echo $FIXPKG | cut  -d'-' -f5 | cut -c 1,2`
               fi
            fi
            if [[ $FIXTYPE != "SDK" && $FIXTYPE != "IF" && $FIXTYPE != "FP" && $FIXTYPE != "RP" ]]; then
               echo "$FIXPKG "
               echo "    is not a supported FIXTYPE by this script"
               ERROR=1
               (( LINENUM = LINENUM + 1 ))
               echo ""
               continue
            fi
            if [[ ! -f ${RESPDIR}/${FIXRESPFILE} ]]; then
               echo "  File ${RESPDIR}/${FIXRESPFILE} does not exist"
               echo "  Use Tivoli SD tools to push ${TOOLSDIR}/ihs files to this server"
               echo ""
               return 2
            else
               if [[ $FIXPKG == *IHS* ]]; then
                  CURFIXLEVEL=`cat ${DESTDIR}/version.signature | awk '{print $4}'`
               fi
               FIXPACKID=${FIXPKG%.*}
               echo "    Installing fixpack $FIXPACKID"
               echo "    Tail ${DESTDIR}/log/update/${FIXPACKID}.install/updatelog.txt for installation details and progress"
               cp ${RESPDIR}/${FIXRESPFILE} /tmp/${FIXRESPFILE}
               if [[ $? -gt 0 ]]; then
                  echo "    Copying of response file to tmp dir"
                  echo "      Failed"
                  echo ""
                  return 3
               fi
               cd /tmp
               sed -e "s%maintenance.package=.*%maintenance.package=${SRCDIR}/${FIXPKG}%" ${FIXRESPFILE}  > ${FIXRESPFILE}.custom && mv ${FIXRESPFILE}.custom  ${FIXRESPFILE}
               if [[ $? -gt 0 ]]; then
                  echo "    Edit to response file for maintenance package id"
                  echo "      Failed"
                  echo ""
                  return 3
               fi
               sed -e "s%product.location=.*%product.location=${DESTDIR}%" ${FIXRESPFILE}  > ${FIXRESPFILE}.custom && mv ${FIXRESPFILE}.custom  $FIXRESPFILE
               if [[ $? -gt 0 ]]; then
                  echo "    Edit to response file for product location"
                  echo "      Failed"
                  echo ""
                  return 3
               fi
               #Install fix using created response file
               if [[ -f ${DESTDIR}/log/update/${FIXPACKID}.install/updatelog.txt ]]; then
                  echo "    A previous version of the install log for this fixpack was detected"
                  echo "        Removing"
                  rm ${DESTDIR}/log/update/${FIXPACKID}.install/*
                  if [[ $? -gt 0 ]]; then
                     echo "    Removal of previous version install logs"
                     echo "      Failed"
                     echo ""
                     return 3
                  fi
               fi
               ${DESTDIR}/UpdateInstaller/update.sh -options /tmp/${FIXRESPFILE} -silent
               case $FIXTYPE in
                  FP|RP)
                     NEWFIXLEVEL=`cat ${DESTDIR}/version.signature | awk '{print $4}'`
                     if [[ $NEWFIXLEVEL == $CURFIXLEVEL ]]; then
                        echo "    IHS Version info has not updated."
                        echo "    IHS Fixpack install Failed"
                        echo "    Please check log file for errors"
                        ERROR=1
                     else
                        echo "    IHS Fix install Successful"
                        printf "    "
                        base_ihs_version_61 $DESTDIR short
                     fi
                  ;;
                  SDK)
                     if [[ -f ${DESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt ]]; then
                        LASTLINES=`tail -3 ${DESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt`
                        if [[ "$LASTLINES" != "" ]]; then
                           echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
                           if [[ $? -eq 0 ]]; then
                              echo "    SDK Fixpack install Successful"
                              printf "    "
                              base_ihs_sdk_version_61 $DESTDIR
                           else
                              echo "    SDK Fixpack install Failed"
                              echo "    Last few lines of install log contain:"
                              echo "$LASTLINES"
                              echo ""
                              echo "    Please check install log for further details"
                              ERROR=1
                           fi
                        else
                           echo "    SDK Fixpack install log is empty"
                           echo "    SDK Fixpack install Failed"
                           ERROR=1
                        fi
                     else
                        echo "    Failed to find SDK Fixpack install log"
                        echo "    SDK Fixpack install Failed"
                        ERROR=1
                     fi
                  ;;
                  IF)
                     if [[ -f ${DESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt ]]; then
                        LASTLINES=`tail -3 ${DESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt`
                        if [[ "$LASTLINES" != "" ]]; then
                           echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
                           if [[ $? -eq 0 ]]; then
                              echo "    Interim Fixpack install Successful"
                           else
                              echo "    Interim Fixpack install Failed"
                              echo "    Last few lines of install log contain:"
                              echo "$LASTLINES"
                              echo ""
                              echo "    Please check install log for further details"
                              ERROR=1
                           fi
                        else
                           echo "    Interim Fixpack install log is empty"
                           echo "    Interim Fixpack install Failed"
                           ERROR=1
                        fi
                     else
                        echo "    Failed to find Interim Fixpack install log"
                        echo "    Interim Fixpack install Failed"
                        ERROR=1
                     fi
                  ;;
               esac
            fi
            echo ""
            (( LINENUM = LINENUM + 1 ))
            stop_httpd_verification_61 $DESTDIR $TOOLSDIR $SLEEP ihs 4
            function_error_check stop_httpd_verification_61 ihs
            echo ""
         fi
      done
      echo "################################################################################"
   else
      echo "No fixes found to apply in ${SRCDIR}"
      echo ""
      return 200
   fi

   if [[ $ERROR -gt 0 ]]; then
      return 2
   fi
}

function install_ihs_fixes_70
{
   typeset FULLVERSION=$1 DESTDIR=$2 BITS=$3 TOOLSDIR=$4 SLEEP=$5 SKIPUPDATES=$6 PACKAGES=$7 WASSRCDIR SRCDIR RESPDIR FIXRESPFILE LIST SPLITPACKAGES FIXPKG FIXTYPE FIXPACKID CURFIXLEVEL NEWFIXLEVEL SDKVERSION ERROR LINENUM LASTLINES ITEM LIST_TMP CHMOD CHMODR XARGS FS_TABLE SYSTEM_GRP
   typeset BASELEVEL=`echo $FULLVERSION | cut -c1,2` MAJORNUM=`echo $BASELEVEL | cut -c1` MINORNUM=`echo $BASELEVEL | cut -c2`

   if [[ $FULLVERSION == "" ]]; then
      echo "Function install_ihs_fixes_70 needs FULLVERSION defined"
      exit 1
   fi

   if [[ $DESTDIR == "" ]]; then
      echo "Function install_ihs_fixes_70 needs DESTDIR defined"
      exit 1
   fi

   if [[ $BITS == "" ]]; then
      echo "Function install_ihs_fixes_70 needs BITS defined"
      exit 1
   fi

   if [[ $TOOLSDIR == "" ]]; then
      echo "Function install_ihs_fixes_70 needs TOOLSDIR defined"
      exit 1
   fi

   if [[ $SLEEP == "" ]]; then
      echo "Function install_ihs_fixes_70 needs SLEEP defined"
      exit 1
   fi

   if [[ $SKIPUPDATES == "" ]]; then
      echo "Function install_ihs_fixes_70 needs SKIPUPDATES defined"
      exit 1
   fi

   if [[ $PACKAGES == "" ]]; then
      echo "Function install_ihs_fixes_70 needs PACKAGES defined"
      echo "Specify \"all\" to install all packages for this fixlevel"
      exit 1
   fi

   echo "---------------------------------------------------------------"
   echo "                Install IHS/SDK Fixpacks"
   echo "---------------------------------------------------------------"
   echo ""

   # Verify IHS is installed or exit if not
   if [[ ! -f ${DESTDIR}/bin/httpd ]]; then
      echo "Base IHS install not detected"
      echo "Skipping updates"
      echo ""
      return 1
   fi
     
   if [[ $SKIPUPDATES -eq 1 ]]; then
      echo "Install of UpdateInstaller required to install fixes"
      echo "  Failed"
      echo "Skipping updates"
      echo ""
      return 1
   fi 

   os_specific_parameters_70 $BITS
   function_error_check os_specific_parameters_70 ihs

   SRCDIR="${WASSRCDIR}/supplements/fixes/${FULLVERSION}/ihs"
   RESPDIR="${TOOLSDIR}/ihs/responsefiles"
   FIXRESPFILE=ihs${MAJORNUM}.${MINORNUM}.fixes.silent.script

   if [[ -d ${SRCDIR} ]]; then
      cd ${SRCDIR}
   else
      echo "Image fixes directory for IHS fullversion ${FULLVERSION}" 
      echo "  does not exist"
      echo "Skipping updates"
      echo ""
      return 1
   fi

   if [[ $PACKAGES == "all" ]]; then
      ls *.pak > /dev/null 2>&1
      if [[ $? -eq 0 ]]; then 
         PACKAGE_LIST=`ls *.pak`
      fi
   else
      SPLITPACKAGES=`echo ${PACKAGES} | sed 's/\:/\\\n/g'`
      PACKAGE_LIST=`echo ${SPLITPACKAGES}`
      for ITEM in $PACKAGE_LIST; do
         ls $ITEM > /dev/null 2>&1
         if [[ $? -ne 0 ]]; then
            echo "Package $ITEM does not exist at"
            echo "  ${SRCDIR}"
            echo "Check the requested fixes list"
            echo "Skipping updates"
            echo ""
            return 1
         fi
      done
   fi

   for FIXPKG in $PACKAGE_LIST
   do
      FIXPACKID=${FIXPKG%.*}
      if [[ -f ${DESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt ]]; then
         LASTLINES=`tail -3 ${DESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt`
         if [[ "$LASTLINES" != "" ]]; then
            echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
            if [[ $? -eq 0 ]]; then
               FIXPKG=""
            fi
         fi
      fi
      if [[ ${FIXPKG} != "" ]]; then
         LIST_TMP="${LIST_TMP}${FIXPKG}\n"
      fi
   done
   if [[ $LIST_TMP != "" ]]; then
      LIST=`echo ${LIST_TMP} | grep -n pak |sed 's/^\([0-9]*\):/\1.- /'`
   else
      if [[ $SPLITPACKAGES != "" ]]; then
         echo "All requested fixes are already successfully installed"
         echo "  Aborting Fixpack install"
      else
         echo "All fixes required of WAS Plugin version $FULLVERSION"
         echo "  are successfully installed"
         echo "  Aborting Fixpack install"
      fi
      echo ""
      return 200
   fi

   if [[ ! -f ${DESTDIR}/UpdateInstaller/update.sh ]]; then
      echo "Cannot find ${DESTDIR}/UpdateInstaller/update.sh"
      echo "Skipping updates"
      echo ""
      return 1
   elif [[ $LIST != "" ]]; then
      echo "Applying fixpacks in this order"
      echo "  to IHS $BASELEVEL"
      echo "  located in $DESTDIR"
      echo "  to obtain IHS/SDK fixlevel $FULLVERSION"
      echo "  in $SLEEP seconds"
      echo "    Ctrl-C to suspend"
      echo ""
      echo "$LIST"
      echo ""
      install_timer $SLEEP
      function_error_check install_timer ihs

      LINENUM=1
      echo "Beginning fixpack installation process"
      echo "################################################################################"
      echo ""
      for FIXPKG in $LIST; do
         if [[ $FIXPKG == *.pak ]]; then
            echo "${LINENUM}) ${FIXPKG%.*}"
            echo "--------------------------------------------------------------------------------"
            echo ${FIXPKG} | grep -q SDK
            if [[ $? -eq 0 ]]; then
               FIXTYPE=SDK
            else
               echo ${FIXPKG} | grep -q IFP
               if [[ $? -eq 0 ]]; then
                  FIXTYPE=IF
               else
                  FIXTYPE=`echo $FIXPKG | cut  -d'-' -f5 | cut -c 1,2`
               fi
            fi
            if [[ $FIXTYPE != "SDK" && $FIXTYPE != "IF" && $FIXTYPE != "FP" && $FIXTYPE != "RP" ]]; then
               echo "$FIXPKG "
               echo "    is not a supported FIXTYPE by this script"
               ERROR=1
               (( LINENUM = LINENUM + 1 ))
               echo ""
               continue
            fi
            if [[ ! -f ${RESPDIR}/${FIXRESPFILE} ]]; then
               echo "  File ${RESPDIR}/${FIXRESPFILE} does not exist"
               echo "  Use Tivoli SD tools to push ${TOOLSDIR}/ihs files to this server"
               echo ""
               return 2
            else
               if [[ $FIXPKG == *IHS* ]]; then
                  CURFIXLEVEL=`cat ${DESTDIR}/version.signature | awk '{print $4}'`
               fi
               FIXPACKID=${FIXPKG%.*}
               echo "    Installing fixpack $FIXPACKID"
               echo "    Tail ${DESTDIR}/log/update/${FIXPACKID}.install/updatelog.txt for installation details and progress"
               cp ${RESPDIR}/${FIXRESPFILE} /tmp/${FIXRESPFILE}
               if [[ $? -gt 0 ]]; then
                  echo "    Copying of response file to tmp dir"
                  echo "      Failed"
                  echo ""
                  return 3
               fi
               cd /tmp
               sed -e "s%maintenance.package=.*%maintenance.package=${SRCDIR}/${FIXPKG}%" ${FIXRESPFILE}  > ${FIXRESPFILE}.custom && mv ${FIXRESPFILE}.custom  ${FIXRESPFILE}
               if [[ $? -gt 0 ]]; then
                  echo "    Edit to response file for maintenance package id"
                  echo "      Failed"
                  echo ""
                  return 3
               fi
               sed -e "s%product.location=.*%product.location=${DESTDIR}%" ${FIXRESPFILE}  > ${FIXRESPFILE}.custom && mv ${FIXRESPFILE}.custom  $FIXRESPFILE
               if [[ $? -gt 0 ]]; then
                  echo "    Edit to response file for product location"
                  echo "      Failed"
                  echo ""
                  return 3
               fi
               #Install fix using created response file
               if [[ -f ${DESTDIR}/log/update/${FIXPACKID}.install/updatelog.txt ]]; then
                  echo "    A previous version of the install log for this fixpack was detected"
                  echo "        Removing"
                  rm ${DESTDIR}/log/update/${FIXPACKID}.install/*
                  if [[ $? -gt 0 ]]; then
                     echo "    Removal of previous version install logs"
                     echo "      Failed"
                     echo ""
                     return 3
                  fi
               fi
               ${DESTDIR}/UpdateInstaller/update.sh -options /tmp/${FIXRESPFILE} -silent
               case $FIXTYPE in
                  FP|RP)
                     NEWFIXLEVEL=`cat ${DESTDIR}/version.signature | awk '{print $4}'`
                     if [[ $NEWFIXLEVEL == $CURFIXLEVEL ]]; then
                        echo "    IHS Version info has not updated."
                        echo "    IHS Fixpack install Failed"
                        echo "    Please check log file for errors"
                        ERROR=1
                     else
                        echo "    IHS Fix install Successful"
                        printf "    "
                        base_ihs_version_70 $DESTDIR short
                     fi
                  ;;
                  SDK)
                     if [[ -f ${DESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt ]]; then
                        LASTLINES=`tail -3 ${DESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt`
                        if [[ "$LASTLINES" != "" ]]; then
                           echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
                           if [[ $? -eq 0 ]]; then
                              echo "    SDK Fixpack install Successful"
                              printf "    "
                              base_ihs_sdk_version_70 $DESTDIR
                           else
                              echo "    SDK Fixpack install Failed"
                              echo "    Last few lines of install log contain:"
                              echo "$LASTLINES"
                              echo ""
                              echo "    Please check install log for further details"
                              ERROR=1
                           fi
                        else
                           echo "    SDK Fixpack install log is empty"
                           echo "    SDK Fixpack install Failed"
                           ERROR=1
                        fi
                     else
                        echo "    Failed to find SDK Fixpack install log"
                        echo "    SDK Fixpack install Failed"
                        ERROR=1
                     fi
                  ;;
                  IF)
                     if [[ -f ${DESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt ]]; then
                        LASTLINES=`tail -3 ${DESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt`
                        if [[ "$LASTLINES" != "" ]]; then
                           echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
                           if [[ $? -eq 0 ]]; then
                              echo "    Interim Fixpack install Successful"
                           else
                              echo "    Interim Fixpack install Failed"
                              echo "    Last few lines of install log contain:"
                              echo "$LASTLINES"
                              echo ""
                              echo "    Please check install log for further details"
                              ERROR=1
                           fi
                        else
                           echo "    Interim Fixpack install log is empty"
                           echo "    Interim Fixpack install Failed"
                           ERROR=1
                        fi
                     else
                        echo "    Failed to find Interim Fixpack install log"
                        echo "    Interim Fixpack install Failed"
                        ERROR=1
                     fi
                  ;;
               esac
            fi
            echo ""
            (( LINENUM = LINENUM + 1 ))
            stop_httpd_verification_70 $DESTDIR $TOOLSDIR $SLEEP ihs 4
            function_error_check stop_httpd_verification_70 ihs
            echo ""
         fi
      done
      echo "################################################################################"
   else
      echo "No fixes found to apply in ${SRCDIR}"
      echo ""
      return 200
   fi

   if [[ $ERROR -gt 0 ]]; then
      return 2
   fi
}

