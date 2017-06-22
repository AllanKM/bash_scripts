#!/bin/ksh

###################################################################
#
#  plugininst_v2.sh -- This script is used to install the IHS 
#                      plugin in accordance with ITCS104 and 
#                      EI Standards
#
#------------------------------------------------------------------
#
#  Todd Stephens - 10/17/2010 - Major overhaul
#  Todd Stephens - 10/10/2012 - Standardization/cleanup
#
###################################################################

# Verify only one instance of script is running
SCRIPTNAME=`basename $0`
PIDFILE=/logs/scriptpids/${SCRIPTNAME}.pid
if [[ -f $PIDFILE ]]; then
   OLDPID=`cat $PIDFILE`
   if [[ $OLDPID == "" ]]; then
      echo "A previous version of the script left a corrupted PID file"
      echo "Correct and restart script"
      exit 1
   fi
   RESULT=`ps -ef| grep ${OLDPID} | grep ${SCRIPTNAME}`
   if [[ -n "${RESULT}" ]]; then
      echo "A previous version of ${SCRIPTNAME} is already running"
      echo "  on this node (${OLDPID}).  Try again later"
      exit 255
   else
      if [[ ! -d /logs/scriptpids ]]; then
         mkdir /logs/scriptpids
      fi
      echo $$ > /logs/scriptpids/${SCRIPTNAME}.pid
   fi
else
   if [[ ! -d /logs/scriptpids ]]; then
      mkdir /logs/scriptpids
   fi
   echo $$ > /logs/scriptpids/${SCRIPTNAME}.pid
fi

# Verify script is called via sudo or ran as root
if [[ $SUDO_USER == "" && $USER != "root" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "*******       Script install_ihs_v2.sh needs              *******"
   echo "*******              to be ran with sudo                  *******"
   echo "*******                   or as root                      *******"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

#---------------------------------------------------------------
# Plugin silent install according to EI standards
#---------------------------------------------------------------

# Set umask
umask 002

# Set default values
TIMER_ACTIVATED=0
FULLVERSION=""
IHSINSTANCE=""
WASINSTANCE=""
typeset -u UPDI_LEVEL=""
IHSLEVEL=""
PLUGINDIR=""
BITS=32
TOOLSDIR="/lfs/system/tools"
SKIPUPDATES=0
SLEEP=30
ERROR=0
NOTHING_FOUND_WAS_PLUGIN=1

# Read in libraries
#IHSLIBPATH="/fs/home/todds/lfs_tools"
IHSLIBPATH="/lfs/system/tools"
funcs=${IHSLIBPATH}/ihs/lib/ihs_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

funcs=${IHSLIBPATH}/ihs/lib/ihs_install_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

funcs=${IHSLIBPATH}/was/lib/was_install_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

funcs=${IHSLIBPATH}/was/lib/was_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

# Process command-line options
until [ -z "$1" ] ; do
   case $1 in
      ihs_level=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then IHSLEVEL=$VALUE; fi ;;
      ihsinstnum=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then IHSINSTANCE=$VALUE; fi ;;
      was_version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FULLVERSION=$VALUE; fi ;;
      wasinstnum=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then WASINSTANCE=$VALUE; fi ;;
      bits=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then BITS=$VALUE; fi ;;	
      updiVersion=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then UPDI_LEVEL=$VALUE; fi ;;
      toolsdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
      *)  print -u2 -- "#### Unknown argument: $1" 
          print -u2 -- "#### Usage: ${0:##*/}"
          print -u2 -- "####           ihs_level = < Major_Minor number of ihs install > " 
          print -u2 -- "####           was_version = < desired WAS version > "
          print -u2 -- "####           [ ihsinstnum=< instance number of the desired IHS version > ]"
          print -u2 -- "####           [ wasinstnum=< instance number of the desired Plugin version > ]"
          print -u2 -- "####           [ bits = < 64 or 32 >  ]"
          print -u2 -- "####           [ updiVersion = < UpdateInstaller Version > ]"
          print -u2 -- "####           [ toolsdir = < path to ihs scripts > ]"
          print -u2 -- "#### ---------------------------------------------------------------------------"
          print  -u2 -- "####             Defaults:"
          print  -u2 -- "####               ihs_level   = NODEFAULT"
          print  -u2 -- "####               was_version = NODEFAULT"
          print  -u2 -- "####               ihsinstnum  = NULL"
          print  -u2 -- "####               wasinstnum  = NULL"
          print  -u2 -- "####               bits        = 32"
          print  -u2 -- "####               updiVersion = FP00000NN - Based on was_version"
          print  -u2 -- "####               toolsdir    = /lfs/system/tools"
          print  -u2 -- "####             Notes: "
          print  -u2 -- "####               1) ihsinstnum is used to identify"
          print  -u2 -- "####                  multiple installs of the "
          print  -u2 -- "####                  same base version of IHS"
          print  -u2 -- "####               2) wasinstnum is used to identify"
          print  -u2 -- "####                  multiple installs of the "
          print  -u2 -- "####                  same base version of WAS Plugin"
          exit 1
      ;;
   esac
   shift
done

if [[ $IHSLEVEL == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Must specify a base level of IHS where the plugin "
   echo "    will be installed"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $FULLVERSION == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Must specify a version of plugin to install"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ ! -d $TOOLSDIR ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Tools Directory $TOOLSDIR does not exist"
   echo "      on this node"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

BASELEVEL=`echo ${FULLVERSION} | cut -c1,2`
FIXPACKLEVEL=`echo ${FULLVERSION} | awk '{print substr ($1, length($1) - 1, length($1))}'`
IHSLEVEL=`echo ${IHSLEVEL} | cut -c1,2`

if [[ $IHSLEVEL == 61 && $IHSINSTANCE == "" ]]; then
   if [[ -d /usr/HTTPServer61 ]]; then
      IHSDIR="/usr/HTTPServer61"
   elif [[ -d /usr/HTTPServer ]]; then
      IHSDIR="/usr/HTTPServer"
   else
      echo "A Serverroot is not detected"
      echo "for IHS 61"
      echo "Aborting WAS Plugin install"
      exit 1
   fi
elif [[ $IHSINSTANCE == "0" ]]; then
   if [[ -d /usr/HTTPServer ]]; then
      IHSDIR="/usr/HTTPServer"
   else
      echo "Base HTTPServer Serverroot is not detected"
      echo "Aborting WAS Plugin install"
      exit 1
   fi
else
   if [[ $IHSINSTANCE != "" ]]; then
      IHSEXTENSION="_${IHSINSTANCE}"
   fi
   if [[ -d /usr/HTTPServer${IHSLEVEL}${IHSEXTENSION} ]]; then
      IHSDIR="/usr/HTTPServer${IHSLEVEL}${IHSEXTENSION}"
   else
      echo "A Serverroot is not detected"
      if [[ $IHSINSTANCE == "" ]]; then
         echo "for IHS $IHSLEVEL"
      else
         echo "for IHS $IHSLEVEL Instance $IHSINSTANCE"
      fi
      echo "Aborting WAS Plugin Install"
      exit 1
   fi
fi
if [[ $UPDI_LEVEL == "" ]]; then
   UPDI_LEVEL="FP00000${FIXPACKLEVEL}"
fi
HTTPLOG=`echo ${IHSDIR} | cut -d"/" -f3`
if [[ $WASINSTANCE != "" ]]; then
   WASEXTENSION="_${WASINSTANCE}"
fi
PLUGDESTDIR=${IHSDIR}/Plugins${BASELEVEL}${WASEXTENSION}
PLUGLOGDIR=/logs/${HTTPLOG}/Plugins${BASELEVEL}${WASEXTENSION}

# Verify IHS is installed or exit if not
if [[ ! -f ${IHSDIR}/bin/httpd ]]; then
   echo "Base IHS install not detected"
   echo "Aborting WAS Plugin Install"
   exit 1
fi

install_plugin_61 ()
{
   SRCDIR="${WASSRCDIR}/supplements/plugin"
   RESPDIR=${TOOLSDIR}/was/responsefiles

   echo "---------------------------------------------------------------"
   echo "      Uninstall any previous version of WAS Plugin"
   echo "      located in plugin dir $PLUGDESTDIR"
   echo "---------------------------------------------------------------"
   echo ""
   if [[ -d ${PLUGDESTDIR} ]]; then
      if [[ -f ${PLUGDESTDIR}/bin/mod_was_ap20_http.so ]]; then
         TIMER_ACTIVATED=1
         echo "Detected a previous version of the WAS Plugin"
         echo "  installed at $PLUGDESTDIR"
         echo "Removing this WAS Plugin in $SLEEP seconds"
         echo "  Ctrl-C to suspend"
         echo ""
         install_timer $SLEEP
         function_error_check install_timer plug
         stop_httpd_verification_$IHSLEVEL $IHSDIR $TOOLSDIR $SLEEP plug
         function_error_check stop_httpd_verification_$IHSLEVEL plug
         echo ""
      fi
      was_plugin_uninstall_61 $PLUGDESTDIR
      function_error_check was_plugin_uninstall_61 plug
      echo ""
   else
      echo "${PLUGDESTDIR} does not exist"
      echo "No previous install of WAS Plugin was detected"
      echo ""
   fi 

   if [[ $TIMER_ACTIVATED -eq 0 ]]; then
      if [[ -d $PLUGLOGDIR ]]; then
         echo "$PLUGLOGDIR directory exist"
         echo "Checking for WAS Plugin logs"
         echo "---------------------------------------------------------------"
         echo "    Remove any detected WAS Plugin product logs"
         echo "    located in plugin log dir $PLUGLOGDIR"
         echo "---------------------------------------------------------------"
         echo ""
         if [[ `ls ${PLUGLOGDIR}/install 2> /dev/null | wc -l` -gt 0 || `ls ${PLUGLOGDIR}/update 2> /dev/null | wc -l` -gt 0 ]]; then
            echo "Detected the following WAS Plugin product logs"
            echo "  at $PLUGLOGDIR"
            echo "Removing these WAS Plugin product logs in $SLEEP seconds"
            echo "  Ctrl-C to suspend"
            echo ""
            install_timer $SLEEP
            function_error_check install_timer plug
         fi
      else
         echo "Nor are there any logs detected at $PLUGLOGDIR"
         echo "Nothing to remove"
         echo ""
      fi
   fi
   if [[ -d $PLUGLOGDIR && ! -f ${PLUGDESTDIR}/bin/mod_was_ap20_http.so ]]; then
      if [[ $TIMER_ACTIVATED -eq 1 ]]; then
         echo "Performing previous install log cleaning if detected"
      fi
      was_plugin_clean_logs_61 $PLUGLOGDIR $HTTPLOG
      function_error_check was_plugin_clean_logs_61 plug
      if [[ $? -ne 100 ]]; then
         NOTHING_FOUND_WAS_PLUGIN=0
      fi
      if [[ $NOTHING_FOUND_WAS_PLUGIN -eq 1 ]]; then
         echo "    No logs found to remove"
      fi
      echo ""
   elif [[ -d $PLUGLOGDIR ]]; then
      echo "WAS Plugin still detected at $PLUGDESTDIR"
      echo "Aborting log cleaning functions"
      error_message_plug 2
   fi

   echo "---------------------------------------------------------------"
   echo "                   Install WAS Plugin"
   echo "---------------------------------------------------------------"
   echo ""

   echo "Installing WAS Plugin ${BASELEVEL} "
   echo "  to directory $PLUGDESTDIR"
   echo "  from $SRCDIR"
   echo "  in $SLEEP seconds"
   echo "    Ctrl-C to suspend"
   echo ""
   install_timer $SLEEP
   function_error_check install_timer plug
   echo ""

   RESPONSEFILE=v${BASELEVEL}silent.plugin.script
   if [[ ! -f ${RESPDIR}/${RESPONSEFILE} ]]; then
      echo "File ${RESPDIR}/${RESPONSEFILE} does not exist"
      echo "Use Tivoli SD tools to push ${TOOLSDIR}/was files to this server"
      error_message_plug 2
   else
      check_fs_avail_space $IHSDIR 900 $TOOLSDIR
      function_error_check check_fs_avail_space plug
      check_fs_avail_space /tmp 600 $TOOLSDIR
      function_error_check check_fs_avail_space plug
      cp ${RESPDIR}/${RESPONSEFILE} /tmp/${RESPONSEFILE}
      if [[ $? -gt 0 ]]; then
         echo "    Copying of the response file to tmp"
         echo "      Failed"
         echo ""
         error_message_plug 3
      fi
      cd /tmp
      sed -e "s%installLocation=.*%installLocation=\"${PLUGDESTDIR}\"%" ${RESPONSEFILE}  > ${RESPONSEFILE}.custom && mv ${RESPONSEFILE}.custom  ${RESPONSEFILE}
      if [[ $? -gt 0 ]]; then
         echo "    Edit to response file for install location"
         echo "      Failed"
         echo ""
         error_message_plug 3
      fi
      if [[ -d $SRCDIR ]]; then
         cd $SRCDIR
      else
         echo "WAS Plugin Image dir $SRCDIR does not exist on this node. Aborting WAS Plugin Install"
         echo ""
         error_message_plug 2
      fi
      echo "Beginning installation ..."
      echo ""
      if [[ -f ${SRCDIR}/install ]]; then
         ${SRCDIR}/install -options /tmp/${RESPONSEFILE} -silent
      else
         echo "WAS Plugin Image directory on this node does not contain the install script"
         echo "${SRCDIR}/install"
         echo "Aborting WAS Plugin Install"
         echo ""
         error_message_plug 3
      fi
      if [[ -f ${PLUGDESTDIR}/logs/install/log.txt ]]; then
         LASTLINES=`tail -3 ${PLUGDESTDIR}/logs/install/log.txt`
         if [[ "$LASTLINES" != "" ]]; then
            echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
            if [[ $? -eq 0 ]]; then
               echo "    WAS Plugin install Successful"
               printf "    "
               was_plugin_version_61 $PLUGDESTDIR short
               echo ""
            else
               echo "    WAS Plugin install "
               echo "      Failed"
               echo "    Last few lines of install log contain:"
               echo "$LASTLINES"
               echo ""
               echo "    Please check install log for further details"
               echo ""
               error_message_plug 3
            fi
         else
            echo "    WAS Plugin install log is empty"
            echo "    WAS Plugin install "
            echo "      Failed"
            echo ""
            error_message_plug 3
         fi
      else
         echo "    Failed to find WAS Plugin install log"
         echo "    WAS Plugin install "
         echo "      Failed"
         echo ""
         error_message_plug 3
      fi
   fi
   stop_httpd_verification_$IHSLEVEL $IHSDIR $TOOLSDIR $SLEEP plug 4
   function_error_check stop_httpd_verification_$IHSLEVEL plug
   echo ""
       
   echo "Setting up WAS Plugin log directory according to the"
   echo "  EI standards for an IHS webserver"
   echo ""
   if [[ -d /logs/${HTTPLOG} ]]; then
      if [[ -d ${PLUGDESTDIR}/logs && ! -L ${PLUGDESTDIR}/logs ]]; then
         if [ ! -d ${PLUGLOGDIR} ]; then
            echo "    Creating ${PLUGLOGDIR}"
            mkdir ${PLUGLOGDIR}
            if [[ $? -gt 0 ]]; then
               echo "    Creation of WAS Plugin log directory"
               echo "      Failed"
               echo ""
               ERROR=1
            fi
         fi

         #Preserve the value of the EI_FILESYNC_NODR env variable
         #Set it to 1 for these syncs
         NODRYRUN_VALUE=`echo $EI_FILESYNC_NODR`
         export EI_FILESYNC_NODR=1

         if [[ -d ${PLUGLOGDIR} ]]; then
            echo "    Rsync over ${PLUGDESTDIR}/logs directory"
            ${TOOLSDIR}/configtools/filesync ${PLUGDESTDIR}/logs/ ${PLUGLOGDIR}/ avc 0 0
            if [[ $? -gt 0 ]]; then
               echo "    WAS Plugin log filesync"
               echo "      Failed"
               ERROR=1
            else
               echo ""
               echo "    Replacing ${PLUGDESTDIR}/logs "
               echo "      with a symlink to ${PLUGLOGDIR}"
               rm -r ${PLUGDESTDIR}/logs
               if [[ $? -gt 0 ]]; then
                  echo "    Removal of old WAS Plugin log directory"
                  echo "      Failed"
                  error_message_plug 2 
               else
                  ln -s ${PLUGLOGDIR} ${PLUGDESTDIR}/logs
                  if [[ $? -gt 0 ]]; then
                     echo "    Creation of link for WAS Plugin logs"
                     echo "      Failed"
                     error_message_plug 2
                  fi
               fi
            fi
         fi
         echo ""
         #Restoring env variable EI_FILESYNC_NODR to previous value
         export EI_FILESYNC_NODR=$NODRYRUN_VALUE
      elif [[ -L ${PLUGDESTDIR}/logs ]]; then
         echo "    This is not a fresh WAS Plugin install"
         echo "    Check script output for details"
         echo ""
         error_message_plug 2
      else
         echo "    Can not find any WAS Plugin logs"
         echo "    Aborting the install"
         echo ""
         error_message_plug 2
      fi
   else
      echo "    Can not find Base IHS logs"
      echo "    Aborting the install"
      echo ""
      error_message_plug 2
   fi
   
   #---------------------------------------------------------------
   #                Install UpdateInstaller
   #---------------------------------------------------------------
   UpdateInstaller_61 $FULLVERSION $IHSLEVEL $IHSDIR $BITS $UPDI_LEVEL $TOOLSDIR plug $SLEEP
   if [[ $? -gt 0 ]]; then
      SKIPUPDATES=1
   fi

   #---------------------------------------------------------------
   #                Install WAS Plugin Fixpacks
   #---------------------------------------------------------------
   install_plugin_fixes_61 $FULLVERSION $IHSLEVEL $IHSDIR $PLUGDESTDIR $BITS $TOOLSDIR $SLEEP $SKIPUPDATES all
   RETURN_CODE=$?
   if [[ $RETURN_CODE -eq 1 ]]; then
      ERROR=1
   elif [[ $RETURN_CODE -gt 1 && $RETURN_CODE -ne 200 ]]; then
      echo "    Installation of one or more WAS Plugin/SDK Fixpacks"
      echo "      Failed"
      ERROR=1
   elif [[ $RETURN_CODE -ne 200 ]]; then
      echo "    WAS Plugin/SDK Fixpacks install Successful"
   fi
   echo ""
}

install_plugin_70 ()
{
   SRCDIR="${WASSRCDIR}/supplements/plugin"
   RESPDIR=${TOOLSDIR}/was/responsefiles

   echo "---------------------------------------------------------------"
   echo "      Uninstall any previous version of WAS Plugin"
   echo "      located in plugin dir $PLUGDESTDIR"
   echo "---------------------------------------------------------------"
   echo ""
   if [[ -d ${PLUGDESTDIR} ]]; then
      if [[ -f ${PLUGDESTDIR}/bin/mod_was_ap22_http.so ]]; then
         TIMER_ACTIVATED=1
         echo "Detected a previous version of the WAS Plugin"
         echo "  installed at $PLUGDESTDIR"
         echo "Removing this WAS Plugin in $SLEEP seconds"
         echo "  Ctrl-C to suspend"
         echo ""
         install_timer $SLEEP
         function_error_check install_timer plug
         stop_httpd_verification_$IHSLEVEL $IHSDIR $TOOLSDIR $SLEEP plug
         function_error_check stop_httpd_verification_$IHSLEVEL plug
         echo ""
      fi
      was_plugin_uninstall_70 $PLUGDESTDIR
      function_error_check was_plugin_uninstall_70 plug
      echo ""
   else
      echo "${PLUGDESTDIR} does not exist"
      echo "No previous install of WAS Plugin was detected"
      echo ""
   fi 

   if [[ $TIMER_ACTIVATED -eq 0 ]]; then
      if [[ -d $PLUGLOGDIR ]]; then
         echo "$PLUGLOGDIR directory exist"
         echo "Checking for WAS Plugin logs"
         echo "---------------------------------------------------------------"
         echo "    Remove any detected WAS Plugin product logs"
         echo "    located in plugin log dir $PLUGLOGDIR"
         echo "---------------------------------------------------------------"
         echo ""
         if [[ `ls ${PLUGLOGDIR}/install 2> /dev/null | wc -l` -gt 0 || `ls ${PLUGLOGDIR}/update 2> /dev/null | wc -l` -gt 0 ]]; then
            echo "Detected the following WAS Plugin product logs"
            echo "  at $PLUGLOGDIR"
            echo "Removing these WAS Plugin product logs in $SLEEP seconds"
            echo "  Ctrl-C to suspend"
            echo ""
            install_timer $SLEEP
         fi
      else
         echo "Nor are there any logs detected at $PLUGLOGDIR"
         echo "Nothing to remove"
         echo ""
      fi
   fi
   if [[ -d $PLUGLOGDIR && ! -f ${PLUGDESTDIR}/bin/mod_was_ap22_http.so ]]; then
      if [[ $TIMER_ACTIVATED -eq 1 ]]; then
         echo "Performing previous install log cleaning if detected"
      fi
      was_plugin_clean_logs_70 $PLUGLOGDIR $HTTPLOG
      function_error_check was_plugin_clean_logs_70 plug
      if [[ $? -ne 100 ]]; then
         NOTHING_FOUND_WAS_PLUGIN=0
      fi
      if [[ $NOTHING_FOUND_WAS_PLUGIN -eq 1 ]]; then
         echo "    No logs found to remove"
      fi
      echo ""
   elif [[ -d $PLUGLOGDIR ]]; then
      echo "WAS Plugin still detected at $PLUGDESTDIR"
      echo "Aborting log cleaning functions"
      error_message_plug 2
   fi

   echo "---------------------------------------------------------------"
   echo "                   Install WAS Plugin"
   echo "---------------------------------------------------------------"
   echo ""

   echo "Installing WAS Plugin ${BASELEVEL} "
   echo "  to directory $PLUGDESTDIR"
   echo "  from $SRCDIR"
   echo "  in $SLEEP seconds"
   echo "    Ctrl-C to suspend"
   echo ""
   install_timer $SLEEP
   function_error_check install_timer plug

   RESPONSEFILE=v${BASELEVEL}silent.plugin.script
   if [[ ! -f ${RESPDIR}/${RESPONSEFILE} ]]; then
      echo "File ${RESPDIR}/${RESPONSEFILE} does not exist"
      echo "Use Tivoli SD tools to push ${TOOLSDIR}/was files to this server"
      error_message_plug 2
   else
      check_fs_avail_space $IHSDIR 900 $TOOLSDIR
      function_error_check check_fs_avail_space plug
      check_fs_avail_space /tmp 600 $TOOLSDIR
      function_error_check check_fs_avail_space plug
      cp ${RESPDIR}/${RESPONSEFILE} /tmp/${RESPONSEFILE}
      if [[ $? -gt 0 ]]; then
         echo "    Copying of the response file to tmp"
         echo "      Failed"
         echo ""
         error_message_plug 3
      fi
      cd /tmp
      sed -e "s%installLocation=.*%installLocation=\"${PLUGDESTDIR}\"%" ${RESPONSEFILE}  > ${RESPONSEFILE}.custom && mv ${RESPONSEFILE}.custom  ${RESPONSEFILE}
      if [[ $? -gt 0 ]]; then
         echo "    Edit to response file for install location"
         echo "      Failed"
         echo ""
         error_message_plug 3
      fi
      if [[ -d $SRCDIR ]]; then
         cd $SRCDIR
      else
         echo "WAS Plugin Image dir $SRCDIR does not exist on this node. Aborting WAS Plugin Install"
         echo ""
         error_message_plug 2
      fi
      echo "Beginning installation ..."
      echo ""
      if [[ -f ${SRCDIR}/install ]]; then
         ${SRCDIR}/install -options /tmp/${RESPONSEFILE} -silent
      else
         echo "WAS Plugin Image directory on this node does not contain the install script"
         echo "${SRCDIR}/install"
         echo "Aborting WAS Plugin Install"
         echo ""
         error_message_plug 3
      fi
      if [[ -f ${PLUGDESTDIR}/logs/install/log.txt ]]; then
         LASTLINES=`tail -3 ${PLUGDESTDIR}/logs/install/log.txt`
         if [[ "$LASTLINES" != "" ]]; then
            echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
            if [[ $? -eq 0 ]]; then
               echo "    WAS Plugin install Successful"
               printf "    "
               was_plugin_version_70 $PLUGDESTDIR short
               echo ""
            else
               echo "    WAS Plugin install "
               echo "      Failed"
               echo "    Last few lines of install log contain:"
               echo "$LASTLINES"
               echo ""
               echo "    Please check install log for further details"
               echo ""
               error_message_plug 3
            fi
         else
            echo "    WAS Plugin install log is empty"
            echo "    WAS Plugin install "
            echo "      Failed"
            echo ""
            error_message_plug 3
         fi
      else
         echo "    Failed to find WAS Plugin install log"
         echo "    WAS Plugin install "
         echo "      Failed"
         echo ""
         error_message_plug 3
      fi
   fi
   stop_httpd_verification_$IHSLEVEL $IHSDIR $TOOLSDIR $SLEEP plug 4
   function_error_check stop_httpd_verification_$IHSLEVEL plug
   echo ""
       
   echo "Setting up WAS Plugin log directory according to the"
   echo "  EI standards for an IHS webserver"
   echo ""
   if [[ -d /logs/${HTTPLOG} ]]; then
      if [[ -d ${PLUGDESTDIR}/logs && ! -L ${PLUGDESTDIR}/logs ]]; then
         if [ ! -d ${PLUGLOGDIR} ]; then
            echo "    Creating ${PLUGLOGDIR}"
            mkdir ${PLUGLOGDIR}
            if [[ $? -gt 0 ]]; then
               echo "    Creation of WAS Plugin log directory"
               echo "      Failed"
               echo ""
               ERROR=1
            fi
         fi

         #Preserve the value of the EI_FILESYNC_NODR env variable
         #Set it to 1 for these syncs
         NODRYRUN_VALUE=`echo $EI_FILESYNC_NODR`
         export EI_FILESYNC_NODR=1

         if [[ -d ${PLUGLOGDIR} ]]; then
            echo "    Rsync over ${PLUGDESTDIR}/logs directory"
            ${TOOLSDIR}/configtools/filesync ${PLUGDESTDIR}/logs/ ${PLUGLOGDIR}/ avc 0 0
            if [[ $? -gt 0 ]]; then
               echo "    WAS Plugin log filesync"
               echo "      Failed"
               ERROR=1
            else
               echo ""
               echo "    Replacing ${PLUGDESTDIR}/logs "
               echo "      with a symlink to ${PLUGLOGDIR}"
               rm -r ${PLUGDESTDIR}/logs
               if [[ $? -gt 0 ]]; then
                  echo "    Removal of old WAS Plugin log directory"
                  echo "      Failed"
                  error_message_plug 2 
               else
                  ln -s ${PLUGLOGDIR} ${PLUGDESTDIR}/logs
                  if [[ $? -gt 0 ]]; then
                     echo "    Creation of link for WAS Plugin logs"
                     echo "      Failed"
                     error_message_plug 2
                  fi
               fi
            fi
         fi
         echo ""
         #Restoring env variable EI_FILESYNC_NODR to previous value
         export EI_FILESYNC_NODR=$NODRYRUN_VALUE
      elif [[ -L ${PLUGDESTDIR}/logs ]]; then
         echo "    This is not a fresh WAS Plugin install"
         echo "    Check script output for details"
         echo ""
         error_message_plug 2
      else
         echo "    Can not find any WAS Plugin logs"
         echo "    Aborting the install"
         echo ""
         error_message_plug 2
      fi
   else
      echo "    Can not find Base IHS logs"
      echo "    Aborting the install"
      echo ""
      error_message_plug 2
   fi
   
   #---------------------------------------------------------------
   #                Install UpdateInstaller
   #---------------------------------------------------------------
   UpdateInstaller_70 $FULLVERSION $IHSLEVEL $IHSDIR $BITS $UPDI_LEVEL $TOOLSDIR plug $SLEEP
   if [[ $? -gt 0 ]]; then
      SKIPUPDATES=1
   fi

   #---------------------------------------------------------------
   #                Install WAS Plugin Fixpacks
   #---------------------------------------------------------------
   install_plugin_fixes_70 $FULLVERSION $IHSLEVEL $IHSDIR $PLUGDESTDIR $BITS $TOOLSDIR $SLEEP $SKIPUPDATES all
   RETURN_CODE=$?
   if [[ $RETURN_CODE -eq 1 ]]; then
      ERROR=1
   elif [[ $RETURN_CODE -gt 1 && $RETURN_CODE -ne 200 ]]; then
      echo "    Installation of one or more WAS Plugin/SDK Fixpacks"
      echo "      Failed"
      ERROR=1
   elif [[ $RETURN_CODE -ne 200 ]]; then
      echo "    WAS Plugin/SDK Fixpacks install Successful"
   fi
   echo ""
}

#---------------------------------------------------------------
# Commands that run on all platforms
#---------------------------------------------------------------

case $BASELEVEL in
   61)
      os_specific_parameters_61 $BITS
      function_error_check os_specific_parameters_61 plug
      install_plugin_61 
   ;;
   70)
      os_specific_parameters_70 $BITS
      function_error_check os_specific_parameters_70 plug
      install_plugin_70 
   ;;
   *)
      echo ""
      echo "/////////////////////////////////////////////////////////////////"
      echo "***********    WAS Plugin Version $BASELEVEL not supported    ***********"
      echo "***********          by this install script           ***********"
      echo "/////////////////////////////////////////////////////////////////"
      echo ""
      exit 1
   ;;
esac

echo ""
echo "---------------------------------------------------------------"
echo "       Running IHS Installed Version Report"
echo "---------------------------------------------------------------"
echo ""

installed_versions_${IHSLEVEL} $IHSDIR
echo ""

# Remove PID file
if [[ -f $PIDFILE ]]; then
   rm $PIDFILE
fi

if [[ $ERROR -gt 0 ]]; then
   echo "/////////////////////////////////////////////////////////////////"
   printf "********     Installation of WAS Plugin version $FULLVERSION"
   echo "    ********"
   echo "********      completed with errors.  Review script      ********"
   echo "********          output for further details             ********"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 2
fi
