#!/bin/ksh

###################################################################
#
#  uninstall_ihs_v2.sh -- This script is used to remove all ihs
#             products in a particular serverroot from a node
#
#------------------------------------------------------------------
#
#  Todd Stephens - 10/17/12 - Initial Creation
#
###################################################################

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
# IHS removal script
#---------------------------------------------------------------

# Set umask
umask 002

# Set default values
TIMER_ACTIVATED=0
IHSLEVEL=""
IHSINSTANCE=""
IHSEXTENSION=""
WASLEVEL=""
WASINSTANCE=""
typeset -l PRODUCT="all"
WASEXTENTION=""
DESTDIR=""
BITS=32
TOOLSDIR=/lfs/system/tools
SLEEP=30
ERROR=0
NOTHING_FOUND_WAS_PLUGIN=1
NOTHING_FOUND_UPDATEINSTALLER=1
NOTHING_FOUND_BASE_IHS=1

# Read in libraries
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
      ihs_level=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then IHSLEVEL=$VALUE; fi ;;
      was_level=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then WASLEVEL=$VALUE; fi ;;
      ihsinstnum=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then IHSINSTANCE=$VALUE; fi ;;
      wasinstnum=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then WASINSTANCE=$VALUE; fi ;;
      product=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PRODUCT=$VALUE; fi ;;
      toolsdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
      *)  print -u2 -- "#### Unknown argument: $1"
          print -u2 -- "#### Usage: ${0:##*/}"
          print -u2 -- "####           ihs_level = < Major_Minor number of ihs install > "
          print -u2 -- "####           [ ihsinstnum=< instance number of the desired IHS version > ]"
          print -u2 -- "####           [ was_level=< Major_Minor number of plugin install > ]"
          print -u2 -- "####           [ wasinstnum=< instance number of the desired Plugin version > ]"
          print -u2 -- "####           [ product=< software package to uninstall [all|plugin] > ]"
          print -u2 -- "####           [ toolsdir = < path to ihs scripts > ]"
          print -u2 -- "#### ---------------------------------------------------------------------------"
          print  -u2 -- "####             Defaults:"
          print  -u2 -- "####               ihs_level   = NODEFAULT"
          print  -u2 -- "####               ihsinstnum  = NULL"
          print  -u2 -- "####               was_level   = NULL"
          print  -u2 -- "####               wasinstnum  = NULL"
          print  -u2 -- "####               product     = all"
          print  -u2 -- "####               toolsdir    = /lfs/system/tools"
          print  -u2 -- "####             Notes: "
          print  -u2 -- "####               1) ihsinstnum is used to identify"
          print  -u2 -- "####                  multiple installs of the "
          print  -u2 -- "####                  same base version of IHS"
          print  -u2 -- "####               2) wasinstnum is used to identify"
          print  -u2 -- "####                  multiple installs of the "
          print  -u2 -- "####                  same base version of plugin"
          print  -u2 -- "####               3) product is used to remove"
          print  -u2 -- "####                  subset of IHS install from "
          print  -u2 -- "####                  a given location.  Only accepts"
          print  -u2 -- "####                  all or plugin at this time"
          print  -u2 -- "####               4) if you specify a value for"
          print  -u2 -- "####                  product of plugin then option"
          print  -u2 -- "####                  was_level is required"
          exit 1
      ;;
   esac
   shift
done

if [[ $IHSLEVEL == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Must specify a base level of IHS that you want to "
   echo "    be uninstalled"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $PRODUCT != "all" && $PRODUCT != "plugin" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "   Option product must have value of \"all\" or \"plugin\"" 
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $PRODUCT == "plugin" && $WASLEVEL == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "   Option product is set to \"plugin\", option was_level"
   echo "   is required "
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

remove_ihs_61 ()
{
   echo "---------------------------------------------------------------"
   echo "    Uninstall any detected IHS/SDK products"
   echo "---------------------------------------------------------------"
   echo ""
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
      function_error_check install_timer uninstall 
      stop_httpd_verification_61 $DESTDIR $TOOLSDIR $SLEEP ihs
      function_error_check stop_httpd_verification_61 uninstall
   fi
   PLUGDESTDIR_LIST=`ls -d ${DESTDIR}/Plugins* 2> /dev/null`
   for PLUGDESTDIR in $PLUGDESTDIR_LIST
   do
      WASBASELEVEL=`echo ${PLUGDESTDIR%%_*} | awk '{print substr ($1, length($1) - 1, length($1))}'`
      case $WASBASELEVEL in
         61*|ns)
            was_plugin_uninstall_61 $PLUGDESTDIR
            function_error_check was_plugin_uninstall_61 uninstall
            echo ""
         ;;
         70*)
            was_plugin_uninstall_70 $PLUGDESTDIR
            function_error_check was_plugin_uninstall_70 uninstall
            echo ""
         ;;
      esac
   done
   if [[ -f ${DESTDIR}/UpdateInstaller/version.txt ]]; then
      UPDI_VERSION=`cat ${DESTDIR}/UpdateInstaller/version.txt| grep Version | awk '{print $2}' | cut -c1,3`
   else
      UPDI_VERSION=70
   fi
   updateinstaller_uninstall_$UPDI_VERSION $DESTDIR
   function_error_check updateinstaller_uninstall_$UPDI_VERSION uninstall
   echo ""
   base_ihs_uninstall_61 $DESTDIR $BITS
   function_error_check base_ihs_uninstall_61 uninstall
   echo ""
}

remove_ihs_logs_61 ()
{
   if [[ $TIMER_ACTIVATED -eq 0 ]] then
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
               function_error_check was_plugin_clean_logs_61 uninstall 
               if [[ $? -eq 100 ]]; then
                  NOT_FOUND_COUNT=$((NOT_FOUND_COUNT + 1))
               fi
            ;;
            70*)
               was_plugin_clean_logs_70 $PLUGLOGDIR
               function_error_check was_plugin_clean_logs_70 uninstall
               if [[ $? -eq 100 ]]; then
                  NOT_FOUND_COUNT=$((NOT_FOUND_COUNT + 1))
               fi
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
      function_error_check updateinstaller_clean_logs_$UPDI_VERSION uninstall
      if [[ $? -ne 100 ]]; then
         NOTHING_FOUND_UPDATEINSTALLER=0
      fi
      base_ihs_clean_logs_61 $HTTPLOG
      function_error_check base_ihs_clean_logs_61 uninstall
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
      error_message_uninstall 2
   fi
}

remove_ihs_70 ()
{
   echo "---------------------------------------------------------------"
   echo "    Uninstall any detected IHS/SDK products"
   echo "---------------------------------------------------------------"
   echo ""
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
      function_error_check install_timer uninstall
      stop_httpd_verification_70 $DESTDIR $TOOLSDIR $SLEEP ihs
      function_error_check stop_httpd_verification_61 uninstall
   fi
   PLUGDESTDIR_LIST=`ls -d ${DESTDIR}/Plugins* 2> /dev/null`
   for PLUGDESTDIR in $PLUGDESTDIR_LIST
   do
      WASBASELEVEL=`echo ${PLUGDESTDIR%%_*} | awk '{print substr ($1, length($1) - 1, length($1))}'`
      case $WASBASELEVEL in
         70*)
            was_plugin_uninstall_70 $PLUGDESTDIR
            function_error_check was_plugin_uninstall_70 uninstall
            echo ""
         ;;
      esac
   done
   if [[ -f ${DESTDIR}/UpdateInstaller/version.txt ]]; then
      UPDI_VERSION=`cat ${DESTDIR}/UpdateInstaller/version.txt| grep Version | awk '{print $2}' | cut -c1,3`
   else
      UPDI_VERSION=70
   fi
   updateinstaller_uninstall_$UPDI_VERSION $DESTDIR
   function_error_check updateinstaller_uninstall_$UPDI_VERSION uninstall
   echo ""
   base_ihs_uninstall_70 $DESTDIR $BITS
   function_error_check base_ihs_uninstall_70 uninstall
   echo ""
}

remove_ihs_logs_70 ()
{
   if [[ $TIMER_ACTIVATED -eq 0 ]] then
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
            70*)
               was_plugin_clean_logs_70 $PLUGLOGDIR
               function_error_check was_plugin_clean_logs_70 uninstall
               if [[ $? -eq 100 ]]; then
                  NOT_FOUND_COUNT=$((NOT_FOUND_COUNT + 1))
               fi
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
      function_error_check updateinstaller_clean_logs_$UPDI_VERSION uninstall
      if [[ $? -ne 100 ]]; then
         NOTHING_FOUND_UPDATEINSTALLER=0
      fi
      base_ihs_clean_logs_70 $HTTPLOG
      function_error_check base_ihs_clean_logs_70 uninstall
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
      error_message_uninstall 2
   fi
}

remove_plugin_61 ()
{
   if [[ $WASINSTANCE == "" ]]; then
      PLUGDESTDIR=${DESTDIR}/Plugins$WASLEVEL
      PLUGLOGDIR=/logs/${HTTPLOG}/Plugins$WASLEVEL
   elif [[ $WASINSTANCE -eq 0 ]]; then
      PLUGDESTDIR=${DESTDIR}/Plugins
      PLUGLOGDIR=/logs/${HTTPLOG}/Plugins
   else
      WASEXTENSION="_$WASINSTANCE"
      PLUGDESTDIR=${DESTDIR}/Plugins${WASLEVEL}${WASEXTENSION}
      PLUGLOGDIR=/logs/${HTTPLOG}/Plugins${WASLEVEL}${WASEXTENSION}
   fi 

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
         stop_httpd_verification_$IHSLEVEL $DESTDIR $TOOLSDIR $SLEEP plug
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
}

remove_plugin_logs_61 ()
{
   if [[ $WASINSTANCE == "" ]]; then
      PLUGDESTDIR=${DESTDIR}/Plugins$WASLEVEL
      PLUGLOGDIR=/logs/${HTTPLOG}/Plugins$WASLEVEL
   elif [[ $WASINSTANCE -eq 0 ]]; then
      PLUGDESTDIR=${DESTDIR}/Plugins
      PLUGLOGDIR=/logs/${HTTPLOG}/Plugins
   else
      WASEXTENSION="_$WASINSTANCE"
      PLUGDESTDIR=${DESTDIR}/Plugins${WASLEVEL}${WASEXTENSION}
      PLUGLOGDIR=/logs/${HTTPLOG}/Plugins${WASLEVEL}${WASEXTENSION}
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
   else 
      echo "$PLUGLOGDIR does not exist"
      echo "No logs to remove"
   fi
}

remove_plugin_70 ()
{
   if [[ $WASINSTANCE == "" ]]; then
      PLUGDESTDIR=${DESTDIR}/Plugins$WASLEVEL
      PLUGLOGDIR=/logs/${HTTPLOG}/Plugins$WASLEVEL
   elif [[ $WASINSTANCE -eq 0 ]]; then
      PLUGDESTDIR=${DESTDIR}/Plugins
      PLUGLOGDIR=/logs/${HTTPLOG}/Plugins
   else
      WASEXTENSION="_$WASINSTANCE"
      PLUGDESTDIR=${DESTDIR}/Plugins${WASLEVEL}${WASEXTENSION}
      PLUGLOGDIR=/logs/${HTTPLOG}/Plugins${WASLEVEL}${WASEXTENSION}
   fi 

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
         stop_httpd_verification_$IHSLEVEL $DESTDIR $TOOLSDIR $SLEEP plug
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
}

remove_plugin_logs_70 ()
{
   if [[ $WASINSTANCE == "" ]]; then
      PLUGDESTDIR=${DESTDIR}/Plugins$WASLEVEL
      PLUGLOGDIR=/logs/${HTTPLOG}/Plugins$WASLEVEL
   elif [[ $WASINSTANCE -eq 0 ]]; then
      PLUGDESTDIR=${DESTDIR}/Plugins
      PLUGLOGDIR=/logs/${HTTPLOG}/Plugins
   else
      WASEXTENSION="_$WASINSTANCE"
      PLUGDESTDIR=${DESTDIR}/Plugins${WASLEVEL}${WASEXTENSION}
      PLUGLOGDIR=/logs/${HTTPLOG}/Plugins${WASLEVEL}${WASEXTENSION}
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
   else 
      echo "$PLUGLOGDIR does not exist"
      echo "No logs to remove"
   fi
}

IHSLEVEL=`echo ${IHSLEVEL} | cut -c1,2`
if [[ $IHSLEVEL != 61 && $IHSLEVEL != 70 ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "************    Base IHS Version $IHSLEVEL not supported    ************"
   echo "************      by this IHS uninstall script       ************"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $IHSLEVEL == 61 && $IHSINSTANCE == "" ]]; then
   if [[ -d /usr/HTTPServer61 ]]; then
      DESTDIR="/usr/HTTPServer61"
      HTTPLOG="HTTPServer61"
      if [[ $PRODUCT == "all" ]]; then
         remove_ihs_61
         remove_ihs_logs_61
      fi
      if [[ $PRODUCT == "plugin" ]]; then
         remove_plugin_$WASLEVEL
         remove_plugin_logs_$WASLEVEL
      fi
   elif [[ -d /usr/HTTPServer ]]; then
      DESTDIR="/usr/HTTPServer"
      HTTPLOG="HTTPServer"
      if [[ $PRODUCT == "all" ]]; then
         remove_ihs_61
         remove_ihs_logs_61
      fi
      if [[ $PRODUCT == "plugin" ]]; then
         remove_plugin_$WASLEVEL
         remove_plugin_logs_$WASLEVEL
      fi
   else
      echo "A Serverroot is not detected"
      echo "for IHS 61"
      echo ""
      if [[ -d /logs/HTTPServer || -d /logs/HTTPServer61 ]]; then
         if [[ -d /logs/HTTPServer61 ]]; then
            echo "/logs/HTTPServer61 directory exist"
            echo "Checking for IHS logs"
            HTTPLOG="HTTPServer61"
            if [[ $PRODUCT == "all" ]]; then
               remove_ihs_logs_61
            fi
            if [[ $PRODUCT == "plugin" ]]; then
               remove_plugin_logs_$WASLEVEL
            fi
         fi
         if [[ -d /logs/HTTPServer ]]; then
            echo "/logs/HTTPServer directory exist"
            echo "Checking for IHS logs"
            HTTPLOG="HTTPServer"
            if [[ $PRODUCT == "all" ]]; then
               remove_ihs_logs_61
            fi
            if [[ $PRODUCT == "plugin" ]]; then
               remove_plugin_logs_$WASLEVEL
            fi
         fi
      else
         if [[ $PRODUCT == "all" ]]; then
            echo "Nor are there any logs detected"
            echo "Aborting IHS removal as there is nothing to remove"
            exit 1
         fi
         if [[ $PRODUCT == "plugin" ]]; then
            echo "Nor are there any logs detected"
            echo "Aborting Plugin removal as there is nothing to remove"
            exit 1
         fi
      fi
   fi
elif [[ $IHSINSTANCE == "0" ]]; then
   if [[ -d /usr/HTTPServer ]]; then
      DESTDIR="/usr/HTTPServer"
      HTTPLOG="HTTPServer"
      if [[ $PRODUCT == "all" ]]; then
         remove_ihs_${IHSLEVEL}
         remove_ihs_logs_${IHSLEVEL}
      fi
      if [[ $PRODUCT == "plugin" ]]; then
         remove_plugin_$WASLEVEL
         remove_plugin_logs_$WASLEVEL
      fi
   else
      echo "Base HTTPServer Serverroot is not detected"
      echo ""
      if [[ -d /logs/HTTPServer ]]; then
         echo "/logs/HTTPServer directory exist"
         echo "Checking for IHS logs"
         HTTPLOG="HTTPServer"
         if [[ $PRODUCT == "all" ]]; then
            remove_ihs_logs_${IHSLEVEL}
         fi
         if [[ $PRODUCT == "plugin" ]]; then
            remove_plugin_logs_$WASLEVEL
         fi
      else
         if [[ $PRODUCT == "all" ]]; then
            echo "Nor are there any logs detected"
            echo "Aborting IHS Removal as there is nothing to remove"
            exit 1
         fi
         if [[ $PRODUCT == "plugin" ]]; then
            echo "Nor are there any logs detected"
            echo "Aborting Plugin Removal as there is nothing to remove"
            exit 1
         fi
      fi
   fi
else
   if [[ $IHSINSTANCE != "" ]]; then
      IHSEXTENSION="_${IHSINSTANCE}"
   fi
   if [[ -d /usr/HTTPServer${IHSLEVEL}${IHSEXTENSION} ]]; then
      DESTDIR="/usr/HTTPServer${IHSLEVEL}${IHSEXTENSION}"
      HTTPLOG="HTTPServer${IHSLEVEL}${IHSEXTENSION}"
      if [[ $PRODUCT == "all" ]]; then
         remove_ihs_${IHSLEVEL}
         remove_ihs_logs_${IHSLEVEL}
      fi
      if [[ $PRODUCT == "plugin" ]]; then
         remove_plugin_$WASLEVEL
         remove_plugin_logs_$WASLEVEL
      fi
   else
      echo "A Serverroot is not detected"
      if [[ $IHSINSTANCE == "" ]]; then
         echo "for IHS $IHSLEVEL"
      else
         echo "for IHS $IHSLEVEL Instance $IHSINSTANCE"
      fi
      echo ""
      if [ -d /logs/HTTPServer${IHSLEVEL}${IHSEXTENSION} ]; then
         echo "/logs/HTTPServer${IHSLEVEL}${IHSEXTENSION} directory exist"
         echo "Checking for IHS logs"
         HTTPLOG="HTTPServer${IHSLEVEL}${IHSEXTENSION}"
         if [[ $PRODUCT == "all" ]]; then
            remove_ihs_logs_${IHSLEVEL}
         fi
         if [[ $PRODUCT == "plugin" ]]; then
            remove_plugin_logs_$WASLEVEL
         fi
      else
         if [[ $PRODUCT == "all" ]]; then
            echo "Nor are there any logs detected"
            echo "Aborting IHS removal as there is nothing to remove"
            exit 1
         fi
         if [[ $PRODUCT == "plugin" ]]; then
            echo "Nor are there any logs detected"
            echo "Aborting Plugin removal as there is nothing to remove"
            exit 1
         fi
      fi
   fi
fi

if [[ $ERROR -gt 0 && $PRODUCT == "all" ]]; then
   echo "/////////////////////////////////////////////////////////////////"
   printf "************      Removal of IHS Base Level $IHSLEVEL"
   echo "        ***********"
   if [[ $IHSINSTANCE != "" ]]; then
      printf "************           Instance Number $IHSINSTANCE"
      echo "              ***********"
   fi
   echo "************  completed with errors.  Review script   ***********"
   echo "************       output for further details         ***********"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 3
fi

if [[ $ERROR -gt 0 && $PRODUCT == "plugin" ]]; then
   echo "/////////////////////////////////////////////////////////////////"
   printf "************   Removal of base WAS Plugin Level $WASLEVEL"
   echo "    ***********"
   if [[ $WASINSTANCE != "" ]]; then
      printf "************           Instance Number $WASINSTANCE"
      echo "              ***********"
   fi
   echo "************  completed with errors.  Review script   ***********"
   echo "************       output for further details         ***********"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 3
fi
