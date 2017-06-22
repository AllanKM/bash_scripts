#!/bin/ksh

###################################################################
#
#  install_ihs_v2.sh -- This script is used to install ihs 
#             in accordance with ITCS104 and EI Standards
#
#------------------------------------------------------------------
#
#  Todd Stephens - 8/21/07 - Initial creation
#  Todd Stephens - 10/04/10 - Major overhaul to clean up issues
#  Todd Stephens - 06/16/12 - Further cleanup and adding support 
#                                for IHS 7.0
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
# IHS silent install according to EI standards
#---------------------------------------------------------------

# Set umask
umask 002

# Set default values
TIMER_ACTIVATED=0
FULLVERSION=""
IHSINSTANCE=""
IHSEXTENSION=""
typeset -u UPDI_LEVEL=""
IHS_FS_SIZE=1704
PROJECT_FS_SIZE=512
PROJECTS_LINK=""
DESTDIR=""
BITS=32
TOOLSDIR=/lfs/system/tools
SLEEP=30
ERROR=0
NOTHING_FOUND_WAS_PLUGIN=1
NOTHING_FOUND_UPDATEINSTALLER=1
NOTHING_FOUND_BASE_IHS=1
SKIPUPDATES=0
VG=""

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
until [[ -z "$1" ]] ; do
   case $1 in
      projects_size=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROJECT_FS_SIZE=$VALUE; fi ;;
      projects_link=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROJECT_LINK=$VALUE; fi ;;
      ihs_version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FULLVERSION=$VALUE; fi ;;
      ihsinstnum=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then IHSINSTANCE=$VALUE; fi ;;
      bits=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then BITS=$VALUE; fi ;;	
      updiVersion=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then UPDI_LEVEL=$VALUE; fi ;;
      toolsdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
      vg=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VG=$VALUE; fi ;;
      *)  print -u2 -- "#### Unknown argument: $1" 
          print -u2 -- "#### Usage: ${0:##*/}"
          print -u2 -- "####           ihs_version=< desired IHS version >"
          print -u2 -- "####           vg=< volume group where ihs binaries are installed >"
          print -u2 -- "####           [ ihsinstnum=< instance number of the desired IHS version > ]"
          print -u2 -- "####           [ bits=< 64 or 32 > ]"
          print -u2 -- "####           [ updiVersion=< updateInstaller version > ]"
          print -u2 -- "####           [ projects_size=< size of /projects in MB > ]"
          print -u2 -- "####           [ projects_link=< /projects link location > ]"
          print -u2 -- "####           [ toolsdir=< path to ei local tools > ]"
          print -u2 -- "#### ---------------------------------------------------------------------------"
          print  -u2 -- "####             Defaults:"
          print  -u2 -- "####               ihs_version   = NODEFAULT"
          print  -u2 -- "####               vg            = NODEFAULT"
          print  -u2 -- "####               ihsinstnum    = NULL"
          print  -u2 -- "####               bits          = 32"
          print  -u2 -- "####               updiVersion   = FP00000NN - Based on ihs_version"
          print  -u2 -- "####               projects_size = 512"
          print  -u2 -- "####               projects_link = NODEFAULT"
          print  -u2 -- "####               toolsdir      = /lfs/system/tools"
          print  -u2 -- "####             Notes:  "
          print  -u2 -- "####               1) In order to use projects_link"
          print  -u2 -- "####                  you must specify a projects_size"
          print  -u2 -- "####                  of zero"
          print  -u2 -- "####               2) ihsinstnum is used to install"
          print  -u2 -- "####                  multiple of the same version"
          print  -u2 -- "####                  of IHS"
          exit 1
      ;;
   esac
   shift
done

if [[ $FULLVERSION == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Must specify a version of IHS to install"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $VG == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Must specify a Volumn Group for install"
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
MAJORNUM=`echo ${BASELEVEL} | cut -c1`
MINORNUM=`echo ${BASELEVEL} | cut -c2`
FIXPACKLEVEL=`echo ${FULLVERSION} | awk '{print substr ($1, length($1) - 1, length($1))}'`
DESTDIR="/usr/HTTPServer${BASELEVEL}"
if [[ $IHSINSTANCE == "0" ]]; then
   DESTDIR="${DESTDIR}"
elif [[ $IHSINSTANCE != "" ]]; then
   IHSEXTENSION="_${IHSINSTANCE}"
   DESTDIR="${DESTDIR}${IHSEXTENSION}"
else
   if [[ -d /usr/HTTPServer && $BASELEVEL == "61" ]]; then
      echo "Directory /usr/HTTPServer exist.  Either remove"
      echo "  this directory/install or rerun this command"
      echo "  with the instnum option"
      echo ""
      exit 2
   fi
fi
if [[ $UPDI_LEVEL == "" ]]; then
   UPDI_LEVEL="FP00000${FIXPACKLEVEL}"
fi
HTTPLOG=`echo ${DESTDIR} | cut -d"/" -f3`

install_ihs_61 ()
{
   SRCDIR="${WASSRCDIR}/supplements/IHS"
   RESPDIR="${TOOLSDIR}/ihs/responsefiles"

   echo "---------------------------------------------------------------"
   echo "      Uninstall any previous version of IHS/SDK products"
   echo "      located in serverroot $DESTDIR"
   echo "---------------------------------------------------------------"
   echo ""
   if [[ -d $DESTDIR ]]; then
      MESSAGE=""
      if [ -f ${DESTDIR}/Plugins*/bin/mod_was_ap20_http.so -o -f ${DESTDIR}/Plugins*/bin/mod_was_ap22_http.so ]; then
         MESSAGE="    WAS Plugin installed \n"
      fi
      if [[ -f ${DESTDIR}/UpdateInstaller/update.sh ]]; then
         MESSAGE="$MESSAGE    UpdateInstaller installed \n"
      fi
      if [[ -f ${DESTDIR}/bin/httpd ]]; then
         MESSAGE="$MESSAGE    Base IHS installed \n"
      fi
      if [[ $MESSAGE != "" ]]; then
         TIMER_ACTIVATED=1
         echo "Detected the following IHS products installed "
         echo "  at $DESTDIR"
         echo "$MESSAGE"
         echo "Removing these IHS products in $SLEEP seconds"
         echo "  Ctrl-C to suspend"
         echo ""
         install_timer $SLEEP
         function_error_check install_timer ihs
         stop_httpd_verification_61 $DESTDIR $TOOLSDIR $SLEEP ihs
         function_error_check stop_httpd_verification_61 ihs
      fi
      PLUGDESTDIR_LIST=`ls -d ${DESTDIR}/Plugins* 2> /dev/null`
      for PLUGDESTDIR in $PLUGDESTDIR_LIST
      do
         WASBASELEVEL=`echo ${PLUGDESTDIR%%_*} | awk '{print substr ($1, length($1) - 1, length($1))}'`
         case $WASBASELEVEL in
            61*|ns)  
               was_plugin_uninstall_61 $PLUGDESTDIR
               function_error_check was_plugin_uninstall_61 ihs
               echo ""
            ;;
            70*)
               was_plugin_uninstall_70 $PLUGDESTDIR
               function_error_check was_plugin_uninstall_70 ihs
               echo ""
            ;;
            *)
               echo "Base Level $WASBASELEVEL not supported by this script"
               echo "Aborting"
               exit 1
            ;;
         esac
      done
      if [[ -f ${DESTDIR}/UpdateInstaller/version.txt ]]; then
         UPDI_VERSION=`cat ${DESTDIR}/UpdateInstaller/version.txt| grep Version | awk '{print $2}' | cut -c1,3`
      else
         UPDI_VERSION=70
      fi
      updateinstaller_uninstall_$UPDI_VERSION $DESTDIR
      function_error_check updateinstaller_uninstall_$UPDI_VERSION ihs
      echo ""
      base_ihs_uninstall_61 $DESTDIR $BITS
      function_error_check base_ihs_uninstall_61 ihs
      echo ""
   else
      echo "$DESTDIR does not exist"
      echo "No previous install of Base IHS detected"
      echo ""
   fi

   if [[ $TIMER_ACTIVATED -eq 0 ]]; then
      if [[ -d /logs/$HTTPLOG ]]; then
         echo "/logs/$HTTPLOG directory exist"
         echo "Checking for IHS logs"
         echo "---------------------------------------------------------------"
         echo "    Remove any detected IHS/SDK product logs"
         echo "---------------------------------------------------------------"
         echo ""
         MESSAGE=""
         if [[ `ls /logs/${HTTPLOG}/Plugins*/install 2> /dev/null| wc -l` -gt 0 || `ls /logs/${HTTPLOG}/Plugins*/update 2> /dev/null| wc -l` -gt 0 ]]; then
            MESSAGE="    WAS Plugin logs \n"
         fi
         if [[ `ls /logs/${HTTPLOG}/UpdateInstaller/install 2> /dev/null | wc -l` -gt 0 || `ls /logs/${HTTPLOG}/UpdateInstaller/update 2> /dev/null | wc -l` -gt 0 ]]; then
            MESSAGE="$MESSAGE    UpdateInstaller logs \n"
         fi
         if [[ `ls /logs/${HTTPLOG}/install 2> /dev/null| wc -l` -gt 0 || `ls /logs/${HTTPLOG}/update 2> /dev/null| wc -l` -gt 0 ]]; then
            MESSAGE="$MESSAGE    Base IHS logs \n"
         fi
         if [[ $MESSAGE != "" ]]; then
            echo "Detected the following IHS product logs "
            echo "  at /logs/$HTTPLOG"
            echo "$MESSAGE"
            echo "Removing these IHS product logs in $SLEEP seconds"
            echo "  Ctrl-C to suspend"
            echo ""
            install_timer $SLEEP
            function_error_check install_timer ihs
         fi
      else
         echo "Nor are there any logs detected at /logs/$HTTPLOG"
         echo "Nothing to remove"
         echo ""
      fi
   fi
   if [ -d /logs/$HTTPLOG -a ! -f ${DESTDIR}/bin/httpd -a ! -f ${DESTDIR}/Plugins*/bin/mod_was_ap20_http.so -a ! -f ${DESTDIR}/Plugins*/bin/mod_was_ap22_http.so -a ! -f ${DESTDIR}/UpdateInstaller/update.sh ]; then
      if [[ $TIMER_ACTIVATED -eq 1 ]]; then
         echo "Performing previous install log cleaning if detected"
      fi
      PLUGLOGDIR_LIST=`ls -d /logs/${HTTPLOG}/Plugins* 2> /dev/null`
      LOOPCOUNT=0
      NOT_FOUND_COUNT=0
      for PLUGLOGDIR in $PLUGLOGDIR_LIST
      do
         WASBASELEVEL=`echo ${PLUGLOGDIR%%_*} | awk '{print substr ($1, length($1) - 1, length($1))}'`
         case $WASBASELEVEL in
            61*|ns)  
               was_plugin_clean_logs_61 $PLUGLOGDIR
               function_error_check was_plugin_clean_logs_61 ihs
               if [[ $? -eq 100 ]]; then
                  NOT_FOUND_COUNT=$((NOT_FOUND_COUNT + 1)) 
               fi
            ;;
            70*)
               was_plugin_clean_logs_70 $PLUGLOGDIR
               function_error_check was_plugin_clean_logs_70 ihs
               if [[ $? -eq 100 ]]; then
                  NOT_FOUND_COUNT=$((NOT_FOUND_COUNT + 1)) 
               fi
            ;;
            *)
               echo "Base Level $WASBASELEVEL not supported by this script"
               echo "Aborting"
               exit 1
            ;;
         esac
         LOOPCOUNT=$((LOOPCOUNT + 1))
      done
      if [[ $LOOPCOUNT != $NOT_FOUND_COUNT ]]; then
         NOTHING_FOUND_WAS_PLUGIN=0
      fi
      if [[ $UPDI_VERSION == "" ]]; then
         UPDI_VERSION=70
      fi
      updateinstaller_clean_logs_$UPDI_VERSION $HTTPLOG
      function_error_check updateinstaller_clean_logs_$UPDI_VERSION ihs
      if [[ $? -ne 100 ]]; then
         NOTHING_FOUND_UPDATEINSTALLER=0
      fi
      base_ihs_clean_logs_61 $HTTPLOG 
      function_error_check base_ihs_clean_logs_61 ihs
      if [[ $? -ne 100 ]]; then
         NOTHING_FOUND_BASE_IHS=0
      fi
      if [[ $NOTHING_FOUND_WAS_PLUGIN -eq 1 && $NOTHING_FOUND_UPDATEINSTALLER -eq 1 && $NOTHING_FOUND_BASE_IHS -eq 1 ]]; then
         echo "    No logs found to remove"
      fi
      echo ""
   elif [[ -d /logs/$HTTPLOG ]]; then
      echo "IHS products still detected at $DESTDIR"
      echo "Aborting log cleaning functions"
      error_message_ihs 2
   fi

   echo "---------------------------------------------------------------"
   echo "                    Install Base IHS"
   echo "---------------------------------------------------------------"
   echo ""
   echo "Installing IHS ${BASELEVEL}"
   echo "  to directory $DESTDIR"
   echo "  from ${SRCDIR}"
   echo "  in $SLEEP seconds"
   echo "    Ctrl-C to suspend"
   echo ""
   install_timer $SLEEP
   function_error_check install_timer ihs

   RESPONSEFILE=ihs${MAJORNUM}.${MINORNUM}.base.silent.script
   if [[ ! -f ${RESPDIR}/${RESPONSEFILE} ]]; then
      echo "File ${RESPDIR}/${RESPONSEFILE} does not exist"
      echo "Use Tivoli SD tools to push ${TOOLSDIR}/ihs files to this server"
      error_message_ihs 2
   else
      check_fs_avail_space /tmp 500 $TOOLSDIR
      function_error_check check_fs_avail_space ihs
      /fs/system/bin/eimkfs $DESTDIR ${IHS_FS_SIZE}M $VG IHS${BASELEVEL}${IHSEXTENSION}lv
      if [[ $? -ne 0 ]] ; then
         echo "    Creation of Filesystem $DESTDIR"
         echo "      Failed"
         echo ""
         error_message_ihs 3
      fi
      echo ""
      echo "Verify that $FS_TABLE is populated"
      grep -w $DESTDIR $FS_TABLE > /dev/null 2>&1
      if [[ $? -ne 0 ]] ; then
         echo "    Warning:  Filesystem entry not found"
         echo ""
         ERROR=1
      else
         echo "    Filesystem entry verified"
         echo ""
      fi

      if [[ `ls $DESTDIR | wc -l` -gt 0 ]]; then
         rm -r ${DESTDIR}/*
         if [[ $? -gt 0 ]]; then
            echo "    Removal of Server Root contents after filesystem creation"
            echo "      Failed"
            echo ""
            error_message_ihs 3
         fi
      fi
      cp ${RESPDIR}/${RESPONSEFILE} /tmp/${RESPONSEFILE}
      if [[ $? -gt 0 ]]; then
         echo "    Copying of the response file to tmp"
         echo "      Failed"
         echo ""
         error_message_ihs 3
      fi
      cd /tmp
      sed -e "s%installLocation=.*%installLocation=${DESTDIR}%" ${RESPONSEFILE} > ${RESPONSEFILE}.custom && mv ${RESPONSEFILE}.custom  ${RESPONSEFILE}
      if [[ $? -gt 0 ]]; then
         echo "    Edit to response file for install location"
         echo "      Failed"
         echo ""
         error_message_ihs 3
      fi
      if [[ -d $SRCDIR ]]; then
         cd $SRCDIR
      else
         echo "IHS Image dir $SRCDIR does not exist on this node. Aborting IHS Install"
         echo ""
         error_message_ihs 2
      fi
      echo "Beginning installation ..."
      echo ""
      if [[ -f ${SRCDIR}/install ]]; then
         ${SRCDIR}/install -options "/tmp/${RESPONSEFILE}" -silent
      else
         echo "IHS Image directory on this node does not contain the install script"
         echo "${SRCDIR}/install"
         echo "Aborting IHS Install"
         echo ""
         error_message_ihs 3
      fi
      echo ""
      if [[ -f ${DESTDIR}/logs/install/log.txt ]]; then
         LASTLINES=`tail -3 ${DESTDIR}/logs/install/log.txt`
         if [[ "$LASTLINES" != "" ]]; then
            echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
            if [[ $? -eq 0 ]]; then
               echo "    Base IHS install Successful"
               printf "    "
               base_ihs_version_61 $DESTDIR short
               echo ""
            else
               echo "    Base IHS install "
               echo "      Failed"
               echo "    Last few lines of install log contain:"
               echo "$LASTLINES"
               echo ""
               echo "    Please check install log for further details"
               echo ""
               error_message_ihs 3
            fi
         else
            echo "    Base IHS install log is empty"
            echo "    Base IHS install "
            echo "      Failed"
            echo ""
            error_message_ihs 3
         fi
      else
         echo "    Failed to find Base IHS install log"
         echo "    Base IHS install "
         echo "      Failed"
         echo ""
         error_message_ihs 3
      fi
   fi
   stop_httpd_verification_61 $DESTDIR $TOOLSDIR $SLEEP ihs 4
   function_error_check stop_httpd_verification_61 ihs
   echo ""

   echo "Setting up Base IHS log directory according to the"
   echo "  EI standards for an IHS webserver"
   echo ""
   if [[ -d ${DESTDIR}/logs/ && ! -L ${DESTDIR}/logs/ ]]; then
      if [[ ! -d /logs/${HTTPLOG} ]]; then
         echo "    Creating /logs/${HTTPLOG}"
         mkdir /logs/${HTTPLOG}
         if [[ $? -gt 0 ]]; then
            echo "    Creation of Base IHS log directory"
            echo "      Failed"
            echo ""
            error_message_ihs 2
         fi
      fi

      #Preserve the value of the EI_FILESYNC_NODR env variable
      #Set it to 1 for these syncs
      NODRYRUN_VALUE=`echo $EI_FILESYNC_NODR`
      export EI_FILESYNC_NODR=1

      if [[ -d /logs/${HTTPLOG} ]]; then
         echo "    Rsync over ${DESTDIR}/logs directory"
         ${TOOLSDIR}/configtools/filesync ${DESTDIR}/logs/ /logs/${HTTPLOG}/ avc 0 0
         if [[ $? -gt 0 ]]; then
            echo "    Base IHS log filesync"
            echo "      Failed"
            error_message_ihs 2
         else
            echo ""
            echo "    Replacing ${DESTDIR}/logs "
            echo "      with a symlink to /logs/${HTTPLOG}"
            rm -r ${DESTDIR}/logs
            if [[ $? -gt 0 ]]; then
               echo "    Removal of old Base IHS log directory"
               echo "      Failed"
               error_message_ihs 2
            else
               ln -s /logs/${HTTPLOG} ${DESTDIR}/logs
               if [[ $? -gt 0 ]]; then
                  echo "    Creation of link for Base IHS logs"
                  echo "      Failed"
                  error_message_ihs 2
               fi
            fi
         fi
      fi
      echo ""
      #Restoring env variable EI_FILESYNC_NODR to previous value
      export EI_FILESYNC_NODR=$NODRYRUN_VALUE
   elif [[ -L ${DESTDIR}/logs ]]; then
      echo "    This is not a fresh Base IHS install"
      echo "    Check script output for details"
      echo ""
      error_message_ihs 2
   else
      echo "    Can not find any Base IHS install logs"
      echo "    Aborting the install"
      echo ""
      error_message_ihs 2
   fi
  
   #---------------------------------------------------------------
   # Install UpdateInstaller
   #---------------------------------------------------------------
   UpdateInstaller_61 $FULLVERSION $BASELEVEL $DESTDIR $BITS $UPDI_LEVEL $TOOLSDIR ihs $SLEEP
   if [[ $? -gt 0 ]]; then
      SKIPUPDATES=1
   fi

   #---------------------------------------------------------------
   # Install Base IHS Fixpacks
   #---------------------------------------------------------------
   install_ihs_fixes_61 $FULLVERSION $DESTDIR $BITS $TOOLSDIR $SLEEP $SKIPUPDATES all
  RETURN_CODE=$? 
   if [[ $RETURN_CODE -eq 1 ]]; then
      ERROR=1
   elif [[ $RETURN_CODE -gt 1 && $RETURN_CODE -ne 200 ]]; then
      echo "    Installation of one or more IHS/SDK Fixpacks"
      echo "      Failed"
      ERROR=1
   elif [[ $RETURN_CODE -ne 200 ]]; then
      echo "    IHS/SDK Fixpacks install Successful"
   fi
   echo ""
}

install_ihs_70 ()
{
   SRCDIR="${WASSRCDIR}/supplements/IHS"
   RESPDIR="${TOOLSDIR}/ihs/responsefiles"

   echo "---------------------------------------------------------------"
   echo "      Uninstall any previous version of IHS/SDK products"
   echo "      located in serverroot $DESTDIR"
   echo "---------------------------------------------------------------"
   echo ""
   if [[ -d $DESTDIR ]]; then
      MESSAGE=""
      if [ -f ${DESTDIR}/Plugins*/bin/mod_was_ap22_http.so ]; then
         MESSAGE="    WAS Plugin installed \n"
      fi
      if [[ -f ${DESTDIR}/UpdateInstaller/update.sh ]]; then
         MESSAGE="$MESSAGE    UpdateInstaller installed \n"
      fi
      if [[ -f ${DESTDIR}/bin/httpd ]]; then
         MESSAGE="$MESSAGE    Base IHS installed \n"
      fi
      if [[ $MESSAGE != "" ]]; then
         TIMER_ACTIVATED=1
         echo "Detected the following IHS products installed "
         echo "  at $DESTDIR"
         echo "$MESSAGE"
         echo "Removing these IHS products in $SLEEP seconds"
         echo "  Ctrl-C to suspend"
         echo ""
         install_timer $SLEEP
         function_error_check install_timer ihs
         stop_httpd_verification_70 $DESTDIR $TOOLSDIR $SLEEP ihs
         function_error_check stop_httpd_verification_70 ihs
      fi
      PLUGDESTDIR_LIST=`ls -d ${DESTDIR}/Plugins* 2> /dev/null`
      for PLUGDESTDIR in $PLUGDESTDIR_LIST
      do
         WASBASELEVEL=`echo ${PLUGDESTDIR%%_*} | awk '{print substr ($1, length($1) - 1, length($1))}'`
         case $WASBASELEVEL in
            61*|ns)  
               was_plugin_uninstall_61 $PLUGDESTDIR
               function_error_check was_plugin_uninstall_61 ihs
               echo ""
            ;;
            70*)
               was_plugin_uninstall_70 $PLUGDESTDIR
               function_error_check was_plugin_uninstall_70 ihs
               echo ""
            ;;
            *)
               echo "Base Level $WASBASELEVEL not supported by this script"
               echo "Aborting"
               exit 1
            ;;
         esac
      done
      if [[ -f ${DESTDIR}/UpdateInstaller/version.txt ]]; then
         UPDI_VERSION=`cat ${DESTDIR}/UpdateInstaller/version.txt| grep Version | awk '{print $2}' | cut -c1,3`
      else
         UPDI_VERSION=70
      fi
      updateinstaller_uninstall_$UPDI_VERSION $DESTDIR
      function_error_check updateinstaller_uninstall_$UPDI_VERSION ihs
      echo ""
      base_ihs_uninstall_70 $DESTDIR $BITS
      function_error_check base_ihs_uninstall_70 ihs
      echo ""
   else
      echo "$DESTDIR does not exist"
      echo "No previous install of Base IHS detected"
      echo ""
   fi

   if [[ $TIMER_ACTIVATED -eq 0 ]]; then
      if [[ -d /logs/$HTTPLOG ]]; then
         echo "/logs/$HTTPLOG directory exist"
         echo "Checking for IHS logs"
         echo "---------------------------------------------------------------"
         echo "    Remove any detected IHS/SDK product logs"
         echo "---------------------------------------------------------------"
         echo ""
         MESSAGE=""
         if [[ `ls /logs/${HTTPLOG}/Plugins*/install 2> /dev/null| wc -l` -gt 0 || `ls /logs/${HTTPLOG}/Plugins*/update 2> /dev/null| wc -l` -gt 0 ]]; then
            MESSAGE="    WAS Plugin logs \n"
         fi
         if [[ `ls /logs/${HTTPLOG}/UpdateInstaller/install 2> /dev/null | wc -l` -gt 0 || `ls /logs/${HTTPLOG}/UpdateInstaller/update 2> /dev/null | wc -l` -gt 0 ]]; then
            MESSAGE="$MESSAGE    UpdateInstaller logs \n"
         fi
         if [[ `ls /logs/${HTTPLOG}/install 2> /dev/null| wc -l` -gt 0 || `ls /logs/${HTTPLOG}/update 2> /dev/null| wc -l` -gt 0 ]]; then
            MESSAGE="$MESSAGE    Base IHS logs \n"
         fi
         if [[ $MESSAGE != "" ]]; then
            echo "Detected the following IHS product logs "
            echo "  at /logs/$HTTPLOG"
            echo "$MESSAGE"
            echo "Removing these IHS product logs in $SLEEP seconds"
            echo "  Ctrl-C to suspend"
            echo ""
            install_timer $SLEEP
            function_error_check install_timer ihs
         fi
      else
         echo "Nor are there any logs detected at /logs/$HTTPLOG"
         echo "Nothing to remove"
         echo ""
      fi
   fi
   if [ -d /logs/$HTTPLOG -a ! -f ${DESTDIR}/bin/httpd -a ! -f ${DESTDIR}/Plugins*/bin/mod_was_ap22_http.so -a ! -f ${DESTDIR}/UpdateInstaller/update.sh ]; then
      if [[ $TIMER_ACTIVATED -eq 1 ]]; then
         echo "Performing previous install log cleaning if detected"
      fi
      PLUGLOGDIR_LIST=`ls -d /logs/${HTTPLOG}/Plugins* 2> /dev/null`
      LOOPCOUNT=0
      NOT_FOUND_COUNT=0
      for PLUGLOGDIR in $PLUGLOGDIR_LIST
      do
         WASBASELEVEL=`echo ${PLUGLOGDIR%%_*} | awk '{print substr ($1, length($1) - 1, length($1))}'`
         case $WASBASELEVEL in
            61*|ns)  
               was_plugin_clean_logs_61 $PLUGLOGDIR
               function_error_check was_plugin_clean_logs_61 ihs
               if [[ $? -eq 100 ]]; then
                  NOT_FOUND_COUNT=$((NOT_FOUND_COUNT + 1)) 
               fi
            ;;
            70*)
               was_plugin_clean_logs_70 $PLUGLOGDIR
               function_error_check was_plugin_clean_logs_70 ihs
               if [[ $? -eq 100 ]]; then
                  NOT_FOUND_COUNT=$((NOT_FOUND_COUNT + 1)) 
               fi
            ;;
            *)
               echo "Base Level $WASBASELEVEL not supported by this script"
               echo "Aborting"
               exit 1
            ;;
         esac
         LOOPCOUNT=$((LOOPCOUNT + 1))
      done
      if [[ $LOOPCOUNT != $NOT_FOUND_COUNT ]]; then
         NOTHING_FOUND_WAS_PLUGIN=0
      fi
      if [[ $UPDI_VERSION == "" ]]; then
         UPDI_VERSION=70
      fi
      updateinstaller_clean_logs_$UPDI_VERSION $HTTPLOG
      function_error_check updateinstaller_clean_logs_$UPDI_VERSION ihs
      if [[ $? -ne 100 ]]; then
         NOTHING_FOUND_UPDATEINSTALLER=0
      fi
      base_ihs_clean_logs_70 $HTTPLOG 
      function_error_check base_ihs_clean_logs_70 ihs
      if [[ $? -ne 100 ]]; then
         NOTHING_FOUND_BASE_IHS=0
      fi
      if [[ $NOTHING_FOUND_WAS_PLUGIN -eq 1 && $NOTHING_FOUND_UPDATEINSTALLER -eq 1 && $NOTHING_FOUND_BASE_IHS -eq 1 ]]; then
         echo "    No logs found to remove"
      fi
      echo ""
   elif [[ -d /logs/$HTTPLOG ]]; then
      echo "IHS products still detected at $DESTDIR"
      echo "Aborting log cleaning functions"
      error_message_ihs 2
   fi

   echo "---------------------------------------------------------------"
   echo "                    Install Base IHS"
   echo "---------------------------------------------------------------"
   echo ""
   echo "Installing IHS ${BASELEVEL}"
   echo "  to directory $DESTDIR"
   echo "  from ${SRCDIR}"
   echo "  in $SLEEP seconds"
   echo "    Ctrl-C to suspend"
   echo ""
   install_timer $SLEEP
   function_error_check install_timer ihs

   RESPONSEFILE=ihs${MAJORNUM}.${MINORNUM}.base.silent.script
   if [[ ! -f ${RESPDIR}/${RESPONSEFILE} ]]; then
      echo "File ${RESPDIR}/${RESPONSEFILE} does not exist"
      echo "Use Tivoli SD tools to push ${TOOLSDIR}/ihs files to this server"
      error_message_ihs 2
   else
      check_fs_avail_space /tmp 500 $TOOLSDIR
      function_error_check check_fs_avail_space ihs
      /fs/system/bin/eimkfs $DESTDIR ${IHS_FS_SIZE}M $VG IHS${BASELEVEL}${IHSEXTENSION}lv
      if [[ $? -ne 0 ]] ; then
         echo "    Creation of Filesystem $DESTDIR"
         echo "      Failed"
         echo ""
         error_message_ihs 3
      fi
      echo ""
      echo "Verify that $FS_TABLE is populated"
      grep -w $DESTDIR $FS_TABLE > /dev/null 2>&1
      if [[ $? -ne 0 ]] ; then
         echo "    Warning:  Filesystem entry not found"
         echo ""
         ERROR=1
      else
         echo "    Filesystem entry verified"
         echo ""
      fi

      if [[ `ls $DESTDIR | wc -l` -gt 0 ]]; then
         rm -r ${DESTDIR}/*
         if [[ $? -gt 0 ]]; then
            echo "    Removal of Server Root contents after filesystem creation"
            echo "      Failed"
            echo ""
            error_message_ihs 3
         fi
      fi
      cp ${RESPDIR}/${RESPONSEFILE} /tmp/${RESPONSEFILE}
      if [[ $? -gt 0 ]]; then
         echo "    Copying of the response file to tmp"
         echo "      Failed"
         echo ""
         error_message_ihs 3
      fi
      cd /tmp
      sed -e "s%installLocation=.*%installLocation=${DESTDIR}%" ${RESPONSEFILE} > ${RESPONSEFILE}.custom && mv ${RESPONSEFILE}.custom  ${RESPONSEFILE}
      if [[ $? -gt 0 ]]; then
         echo "    Edit to response file for install location"
         echo "      Failed"
         echo ""
         error_message_ihs 3
      fi
      if [[ -d $SRCDIR ]]; then
         cd $SRCDIR
      else
         echo "IHS Image dir $SRCDIR does not exist on this node. Aborting IHS Install"
         echo ""
         error_message_ihs 2
      fi
      echo "Beginning installation ..."
      echo ""
      if [[ -f ${SRCDIR}/install ]]; then
         ${SRCDIR}/install -options "/tmp/${RESPONSEFILE}" -silent 
      else
         echo "IHS Image directory on this node does not contain the install script"
         echo "${SRCDIR}/install"
         echo "Aborting IHS Install"
         echo ""
         error_message_ihs 3
      fi
      echo ""
      if [[ -f ${DESTDIR}/logs/install/log.txt ]]; then
         LASTLINES=`tail -3 ${DESTDIR}/logs/install/log.txt`
         if [[ "$LASTLINES" != "" ]]; then
            echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
            if [[ $? -eq 0 ]]; then
               echo "    Base IHS install Successful"
               printf "    "
               base_ihs_version_70 $DESTDIR short
               echo ""
            else
               echo "    Base IHS install "
               echo "      Failed"
               echo "    Last few lines of install log contain:"
               echo "$LASTLINES"
               echo ""
               echo "    Please check install log for further details"
               echo ""
               error_message_ihs 3
            fi
         else
            echo "    Base IHS install log is empty"
            echo "    Base IHS install "
            echo "      Failed"
            echo ""
            error_message_ihs 3
         fi
      else
         echo "    Failed to find Base IHS install log"
         echo "    Base IHS install "
         echo "      Failed"
         echo ""
         error_message_ihs 3
      fi
   fi
   stop_httpd_verification_70 $DESTDIR $TOOLSDIR $SLEEP ihs 4
   function_error_check stop_httpd_verification_70 ihs
   echo ""

   echo "Setting up Base IHS log directory according to the"
   echo "  EI standards for an IHS webserver"
   echo ""
   if [[ -d ${DESTDIR}/logs/ && ! -L ${DESTDIR}/logs/ ]]; then
      if [[ ! -d /logs/${HTTPLOG} ]]; then
         echo "    Creating /logs/${HTTPLOG}"
         mkdir /logs/${HTTPLOG}
         if [[ $? -gt 0 ]]; then
            echo "    Creation of Base IHS log directory"
            echo "      Failed"
            echo ""
            error_message_ihs 2
         fi
      fi

      #Preserve the value of the EI_FILESYNC_NODR env variable
      #Set it to 1 for these syncs
      NODRYRUN_VALUE=`echo $EI_FILESYNC_NODR`
      export EI_FILESYNC_NODR=1

      if [[ -d /logs/${HTTPLOG} ]]; then
         echo "    Rsync over ${DESTDIR}/logs directory"
         ${TOOLSDIR}/configtools/filesync ${DESTDIR}/logs/ /logs/${HTTPLOG}/ avc 0 0
         if [[ $? -gt 0 ]]; then
            echo "    Base IHS log filesync"
            echo "      Failed"
            error_message_ihs 2
         else
            echo ""
            echo "    Replacing ${DESTDIR}/logs "
            echo "      with a symlink to /logs/${HTTPLOG}"
            rm -r ${DESTDIR}/logs
            if [[ $? -gt 0 ]]; then
               echo "    Removal of old Base IHS log directory"
               echo "      Failed"
               error_message_ihs 2
            else
               ln -s /logs/${HTTPLOG} ${DESTDIR}/logs
               if [[ $? -gt 0 ]]; then
                  echo "    Creation of link for Base IHS logs"
                  echo "      Failed"
                  error_message_ihs 2
               fi
            fi
         fi
      fi
      echo ""
      #Restoring env variable EI_FILESYNC_NODR to previous value
      export EI_FILESYNC_NODR=$NODRYRUN_VALUE
   elif [[ -L ${DESTDIR}/logs ]]; then
      echo "    This is not a fresh Base IHS install"
      echo "    Check script output for details"
      echo ""
      error_message_ihs 2
   else
      echo "    Can not find any Base IHS install logs"
      echo "    Aborting the install"
      echo ""
      error_message_ihs 2
   fi
  
   #---------------------------------------------------------------
   # Install UpdateInstaller
   #---------------------------------------------------------------
   UpdateInstaller_70 $FULLVERSION $BASELEVEL $DESTDIR $BITS $UPDI_LEVEL $TOOLSDIR ihs $SLEEP
   if [[ $? -gt 0 ]]; then
      SKIPUPDATES=1
   fi

   #---------------------------------------------------------------
   # Install Base IHS Fixpacks
   #---------------------------------------------------------------
   install_ihs_fixes_70 $FULLVERSION $DESTDIR $BITS $TOOLSDIR $SLEEP $SKIPUPDATES all
  RETURN_CODE=$? 
   if [[ $RETURN_CODE -eq 1 ]]; then
      ERROR=1
   elif [[ $RETURN_CODE -gt 1 && $RETURN_CODE -ne 200 ]]; then
      echo "    Installation of one or more IHS/SDK Fixpacks"
      echo "      Failed"
      ERROR=1
   elif [[ $RETURN_CODE -ne 200 ]]; then
      echo "    IHS/SDK Fixpacks install Successful"
   fi
   echo ""
}

#---------------------------------------------------------------
# Commands that run on all platforms
#---------------------------------------------------------------

case $BASELEVEL in
   61)
      os_specific_parameters_61 $BITS
      function_error_check os_specific_parameters_61 ihs
      install_ihs_61
   ;;
   70)
      os_specific_parameters_70 $BITS
      function_error_check os_specific_parameters_70 ihs
      install_ihs_70
   ;;
   *)
      echo ""
      echo "/////////////////////////////////////////////////////////////////"
      echo "************    Base IHS Version $BASELEVEL not supported    ************"
      echo "************         by this install script          ************"
      echo "/////////////////////////////////////////////////////////////////"
      echo ""
      exit 1
   ;;
esac

echo "---------------------------------------------------------------"
echo "            Performing Post Install Setup"
echo "---------------------------------------------------------------"
echo ""
echo "Setting up /projects filesystem according to the "
echo "  EI standards for an IHS webserver"
echo ""

#See if /projects is a link to /www or other wise not a candidate for a
#filesystem change
if [[ -d /projects && ! -L /projects ]]; then
   if [[ `ls /projects | wc -l` -gt 0 ]]; then
      grep  /projects $FS_TABLE > /dev/null 2>&1
      if [[ $? -gt 0 ]]; then
         echo "    /projects exist and is not empty or a filesystem"
         echo "      Do nothing"
         echo ""
      elif [[ $PROJECT_FS_SIZE -gt 0 ]]; then
         check_fs_size /projects $PROJECT_FS_SIZE $TOOLSDIR
         function_error_check check_fs_size ihs
      fi
   else
      grep  /projects $FS_TABLE > /dev/null 2>&1
      if [[  $? -gt 0 && $PROJECT_FS_SIZE -gt 0 ]]; then
         /fs/system/bin/eimkfs /projects ${PROJECT_FS_SIZE}M $VG
         if [[ $? -ne 0 ]] ; then
            echo "    Creation of Filesystem /projects "
            echo "      Failed"
            echo ""
            ERROR=1
         fi
         echo ""
         echo "Verify that $FS_TABLE is populated"
         grep /projects $FS_TABLE > /dev/null 2>&1
         if [[ $? -ne 0 ]] ; then
            echo "    Warning:  Filesystem entry not found"
            echo ""
            ERROR=1
         else
            echo "    Filesystem entry verified"
            echo ""
         fi
      elif [[ $PROJECT_FS_SIZE -gt 0 ]]; then
         check_fs_size /projects $PROJECT_FS_SIZE $TOOLSDIR
         function_error_check check_fs_size ihs
      fi
   fi
elif [[ -L /projects ]]; then
   echo "    /projects is a link.  Leaving it alone"
   ls -ld /projects
   echo ""
elif [[ $PROJECT_FS_SIZE -gt 0 ]]; then
   /fs/system/bin/eimkfs /projects ${PROJECT_FS_SIZE}M $VG
   if [[ $? -ne 0 ]] ; then
      echo "    Creation of Filesystem /projects "
      echo "      Failed"
      echo ""
      error=1
   fi
   echo ""
   echo "Verify that $FS_TABLE is populated"
   grep /projects $FS_TABLE > /dev/null 2>&1
   if [[ $? -ne 0 ]] ; then
      echo "    Warning:  Filesystem entry not found"
      echo ""
      ERROR=1
   else
      echo "    Filesystem entry verified"
      echo ""
   fi
elif [[ $PROJECTS_LINK != "" ]]; then
   ln -fs $PROJECTS_LINK /projects
fi

echo "Adding umask statement to apachectl"
sed '
/ARGV\=\"\$\@\"/ i\
umask 027
' ${DESTDIR}/bin/apachectl > ${DESTDIR}/bin/apachectl.new && mv ${DESTDIR}/bin/apachectl.new ${DESTDIR}/bin/apachectl 

echo ""
echo "---------------------------------------------------------------"
echo "       Running IHS Installed Version Report"
echo "---------------------------------------------------------------"
echo ""

installed_versions_${BASELEVEL} $DESTDIR
echo ""

# Remove PID file
if [[ -f $PIDFILE ]]; then
   rm $PIDFILE
fi

if [[ $ERROR -gt 0 ]]; then
   echo "/////////////////////////////////////////////////////////////////"
   printf "************    Installation of IHS version $FULLVERSION"
   echo "     ***********"
   echo "************  completed with errors.  Review script   ***********"
   echo "************       output for further details         ***********"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 3
fi

