#!/bin/ksh

###################################################################
#
#  uninstall_ihs_v3.sh -- This script is used to remove all ihs
#      8.5.x.x products in a particular serverroot from a node
#
#------------------------------------------------------------------
#
#  Lou Amodeo - 04/18/2013 - Initial Creation
#  Lou Amodeo   05/13/2013 - Add revised directory structure support
#  Lou Amodeo - 12/12/2013 - change rmfs to /fs/system/bin/eirmfs
#
###################################################################

# Verify script is called via sudo or ran as root
if [[ $SUDO_USER == "" && $USER != "root" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "*******        Script uninstall_ihs_v3.sh needs           *******"
   echo "*******              to be run with sudo                  *******"
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
DESTDIR=""
TOOLSDIR=/lfs/system/tools
IHSLIBPATH="/lfs/system/tools"
PACKAGE="com.ibm.websphere.IHS.v85"
IMBASEDIR="/opt/IBM/InstallationManager"
SLEEP=15
ERROR=0
NOTHING_FOUND_WAS_PLUGIN=1
NOTHING_FOUND_BASE_IHS=1

# Read in libraries
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
      ihs_version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ];   then IHSLEVEL=$VALUE;    fi ;;
      was_version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ];   then WASLEVEL=$VALUE;    fi ;;
      ihsinstnum=*)   VALUE=${1#*=}; if [ "$VALUE" != "" ];   then IHSINSTANCE=$VALUE; fi ;;
      wasinstnum=*)   VALUE=${1#*=}; if [ "$VALUE" != "" ];   then WASINSTANCE=$VALUE; fi ;;
      product=*)      VALUE=${1#*=}; if [ "$VALUE" != "" ];   then PRODUCT=$VALUE;     fi ;;
      toolsdir=*)     VALUE=${1#*=}; if [ "$VALUE" != "" ];   then TOOLSDIR=$VALUE;    fi ;;
      *)  print  -u2 -- "#### Unknown argument: $1"
          print  -u2 -- "#### Usage: ${0:##*/}"
          print  -u2 -- "####           ihs_version = < Major_Minor number of ihs install > "
          print  -u2 -- "####           was_version = < Major_Minor number of WAS plugin install > "
          print  -u2 -- "####           [ ihsinstnum=< instance number of the desired IHS version > ]"
          print  -u2 -- "####           [ wasinstnum=< instance number of the desired Plugin version > ]"
          print  -u2 -- "####           [ product=< software package to uninstall [all|plugin] > ]"
          print  -u2 -- "####           [ toolsdir = < path to ihs scripts > ]"
          print  -u2 -- "#### ---------------------------------------------------------------------------"
          print  -u2 -- "####             Defaults:"
          print  -u2 -- "####               ihs_version = NODEFAULT"
          print  -u2 -- "####               was_version = NULL"
          print  -u2 -- "####               ihsinstnum  = NULL"
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
          print  -u2 -- "####                  was_version is required"
          print  -u2 -- "####               5) if you specify a value for"
          print  -u2 -- "####                  product of all and was_version"
          print  -u2 -- "####                  is not specified then was_version"
          print  -u2 -- "####                  is assumed to be same as ihs_version"
          print  -u2 -- "####               6) if you specify a value for"
          print  -u2 -- "####                  product of all and wasinstnum"
          print  -u2 -- "####                  is not specified then wasinstnum"
          print  -u2 -- "####                  is assumed to be same as ihsinstnum"
          exit 1
      ;;
   esac
   shift
done

remove_ihs_logs_85()
{
   if [[ $TIMER_ACTIVATED -eq 0 ]] then
      echo "---------------------------------------------------------------"
      echo "    Remove any detected IHS/SDK product logs"
      echo "---------------------------------------------------------------"
      echo ""
      MESSAGE=""      
      if [[ `ls /logs/${HTTPLOG}/install 2> /dev/null| wc -l` -gt 0 || `ls /logs/${HTTPLOG}/postinstall 2> /dev/null| wc -l` -gt 0 || `ls /logs/${HTTPLOG}/update 2> /dev/null| wc -l` -gt 0 ]]; then
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
   
   if [ -d /logs/$HTTPLOG -a ! -f ${DESTDIR}/bin/httpd ]; then
      if [[ $TIMER_ACTIVATED -eq 1 ]]; then
         echo "Performing previous install log cleaning if detected"
      fi
      base_ihs_clean_logs_85 $HTTPLOG
      function_error_check base_ihs_clean_logs_85 uninstall
      if [[ $? -ne 100 ]]; then
         NOTHING_FOUND_BASE_IHS=0
      fi
      if [[ $NOTHING_FOUND_BASE_IHS -eq 1 ]]; then
         echo "    No logs found to remove"
      fi
      echo "Removing /logs/$HTTPLOG"
      rm -r /logs/$HTTPLOG
      typeset -i numFiles=`find /logs/WebSphere${IHSLEVEL}${IHSEXTENSION} -type f | wc -l`
      if [[ $numFiles == 0 ]]; then
         rmdir /logs/WebSphere${IHSLEVEL}${IHSEXTENSION}
      fi
      echo ""
   elif [[ -d /logs/$HTTPLOG ]]; then
      echo "IHS products still detected at $DESTDIR"
      echo "Aborting log cleaning functions"
      error_message_uninstall 2
   fi
}

remove_plugin_85()
{
   if [[ $WASINSTANCE == "" ]]; then
      PLUGDESTDIR=/usr/WebSphere${WASLEVEL}/Plugin     
   else
      WASEXTENSION="_$WASINSTANCE"
      PLUGDESTDIR=/usr/WebSphere${WASLEVEL}${WASEXTENSION}/Plugin
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
      ${TOOLSDIR}/was/setup/remove_plugin_v3.sh was_version=${WASLEVEL} wasinstnum=${WASINSTANCE}
      if [[ $? -ne 0 ]]; then
         echo ""
         echo "Removal of WebSphere Plugin failed."
         echo ""
         ERROR=1
      fi
   else
      echo "${PLUGDESTDIR} does not exist"
      echo "No previous install of WAS Plugin was detected"
      echo ""
   fi
}

remove_plugin_logs_85()
{
   if [[ $WASINSTANCE == "" ]]; then
      PLUGDESTDIR=/usr/WebSphere${WASLEVEL}/Plugin
      PLUGLOGDIR=/logs/WebSphere${WASLEVEL}/Plugin
   else
      WASEXTENSION="_$WASINSTANCE"
      PLUGDESTDIR=/usr/WebSphere${WASLEVEL}${WASEXTENSION}/Plugin
      PLUGLOGDIR=/logs/WebSphere${WASLEVEL}${WASEXTENSION}/Plugin
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
         if [[ `ls ${PLUGLOGDIR}/ 2> /dev/null | wc -l` -gt 0 || `ls ${PLUGLOGDIR}/install 2> /dev/null | wc -l` -gt 0 || `ls ${PLUGLOGDIR}/update 2> /dev/null | wc -l` -gt 0 ]]; then
            echo "Detected the following WAS Plugin product logs"
            echo "  at $PLUGLOGDIR"
            echo "Removing these WAS Plugin product logs in $SLEEP seconds"
            echo "  Ctrl-C to suspend"
            echo ""
            install_timer $SLEEP
            function_error_check install_timer plug
         fi
      else
         echo "There are no logs detected at $PLUGLOGDIR"
         echo "Nothing to remove"
         echo ""
      fi
   fi
   
   if [[ -d $PLUGLOGDIR && ! -f ${PLUGDESTDIR}/bin/mod_was_ap22_http.so ]]; then
      if [[ $TIMER_ACTIVATED -eq 1 ]]; then
         echo "Performing previous install log cleaning if detected"
      fi
      was_plugin_clean_logs_85 $PLUGLOGDIR
      function_error_check was_plugin_clean_logs_85 plug
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

remove_ihs_85()
{
   echo "---------------------------------------------------------------"
   echo "    Uninstall any detected IHS product                         "
   echo "---------------------------------------------------------------"
   echo ""
   
   MESSAGE=""
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
      stop_httpd_verification_85 $DESTDIR $TOOLSDIR $SLEEP ihs
      function_error_check stop_httpd_verification_85 ihs
   fi
   
   echo "---------------------------------------------------------------"
   echo "      Uninstall IHS located at dir: $DESTDIR                   "
   echo "---------------------------------------------------------------"
   echo ""
   
   if [[ -d ${DESTDIR} ]]; then      
      $IMBASEDIR/eclipse/tools/imcl uninstall $PACKAGE -installationDirectory ${DESTDIR}
      if [[ $? -ne 0 ]]; then
         echo ""
         echo "Removal of IHS failed."
         echo ""
         ERROR=1
      fi
      /fs/system/bin/eirmfs -f ${DESTDIR}
      rm -r   ${DESTDIR}
      typeset -i numFiles=`find /usr/WebSphere${IHSLEVEL}${IHSEXTENSION} -type f | wc -l`
      if [[ $numFiles == 0 ]]; then
         rmdir /usr/WebSphere${IHSLEVEL}${IHSEXTENSION}
      fi 
   else
      echo "No install of IHS was detected, nothing to uninstall"
      echo ""
   fi
   echo ""
}

#
# Mainline begins here
#

if [[ $PRODUCT == "all" && $IHSLEVEL == "" ]]; then
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

IHSLEVEL=`echo ${IHSLEVEL} | cut -c1,2`
if [[ $IHSLEVEL != 85 ]]; then
   echo ""
   echo "////////////////////////////////////////////////////////////////////////"
   echo "************    Base IHS Version $IHSLEVEL not supported    ************"
   echo "************      by this IHS uninstall script              ************"
   echo "////////////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $PRODUCT == "plugin" && $WASLEVEL == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "   Option product is set to \"plugin\", option was_version"
   echo "   is required "
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

# We are going to assume IHS and WAS levels are the same, if WAS level was not specified
# as that is the likely scenario
if [[ $PRODUCT == "all" && $WASLEVEL == "" ]]; then
   WASLEVEL=$IHSLEVEL
fi
WASLEVEL=`echo ${WASLEVEL} | cut -c1,2`

# We are going to assume IHS and WAS instances are the same, if WAS instance was not specified
# as that is the likely scenario
if [[ $PRODUCT == "all" && $IHSINSTANCE != "" && $WASINSTANCE == "" ]]; then
   WASINSTANCE=$IHSINSTANCE
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

# remove IHS 
if [[ $IHSINSTANCE == "0" ]]; then
   if [[ -d /usr/WebSphere${IHSLEVEL}/HTTPServer ]]; then
      DESTDIR="/usr/WebSphere${IHSLEVEL}/HTTPServer"
      HTTPLOG="WebSphere${IHSLEVEL}/HTTPServer"
      if [[ $PRODUCT == "all" ]]; then
         remove_ihs_${IHSLEVEL}
         remove_ihs_logs_${IHSLEVEL}
      fi
   else
      echo "Base HTTPServer${IHSLEVEL} Server root is not detected"
      echo ""
      if [[ -d /logs/WebSphere${IHSLEVEL}/HTTPServer ]]; then
         echo "/logs/WebSphere${IHSLEVEL}/HTTPServer directory exist"
         echo "Checking for IHS logs"
         HTTPLOG="WebSphere${IHSLEVEL}/HTTPServer"
         if [[ $PRODUCT == "all" ]]; then
            remove_ihs_logs_${IHSLEVEL}
         fi        
      else
         if [[ $PRODUCT == "all" ]]; then
            echo "Nor are there any logs detected"
            echo "Aborting IHS Removal as there is nothing to remove"
            exit 1
         fi         
      fi
   fi
else
   if [[ $IHSINSTANCE != "" ]]; then
      IHSEXTENSION="_${IHSINSTANCE}"
   fi
   if [[ -d /usr/WebSphere${IHSLEVEL}${IHSEXTENSION}/HTTPServer ]]; then
      DESTDIR="/usr/WebSphere${IHSLEVEL}${IHSEXTENSION}/HTTPServer"
      HTTPLOG="WebSphere${IHSLEVEL}${IHSEXTENSION}/HTTPServer"
      if [[ $PRODUCT == "all" ]]; then
         remove_ihs_${IHSLEVEL}
         remove_ihs_logs_${IHSLEVEL}
      fi      
   else
      echo "A Serverroot is not detected"
      if [[ $IHSINSTANCE == "" ]]; then
         echo "for IHS $IHSLEVEL"
      else
         echo "for IHS $IHSLEVEL Instance $IHSINSTANCE"
      fi
      echo ""
      if [ -d /logs/WebSphere${IHSLEVEL}${IHSEXTENSION}/HTTPServer ]; then
         echo "/logs/WebSphere${IHSLEVEL}${IHSEXTENSION}/HTTPServer directory exist"
         echo "Checking for IHS logs"
         HTTPLOG="WebSphere${IHSLEVEL}${IHSEXTENSION}/HTTPServer"
         if [[ $PRODUCT == "all" ]]; then
            remove_ihs_logs_${IHSLEVEL}
         fi        
      else
         if [[ $PRODUCT == "all" ]]; then
            echo "Nor are there any logs detected"
            echo "Aborting IHS removal as there is nothing to remove"
            exit 1
         fi
      fi
   fi
fi

# remove WAS plugin

if [[ $WASINSTANCE == "0" ]]; then
   if [[ -d /usr/WebSphere${WASLEVEL}/Plugin ]]; then
      PLUGDESTDIR="/usr/WebSphere${WASLEVEL}/Plugin"
      PLUGINLOG="WebSphere${WASLEVEL}/Plugin"
      remove_plugin_logs_${WASLEVEL}
      remove_plugin_${WASLEVEL}
   else
      echo "Plugin /usr/WebSphere${WASLEVEL}/Plugin root is not detected"
      echo ""
      if [[ -d /logs/WebSphere${WASLEVEL}/Plugin ]]; then
         echo "/logs/WebSphere${WASLEVEL}/Plugin directory exist"
         echo "Checking for IHS logs"
         PLUGINLOG="WebSphere${WASLEVEL}/Plugin"         
         remove_plugin_logs_${WASLEVEL}
      else
         if [[ $PRODUCT == "plugin" ]]; then
            echo "Nor are there any logs detected"
            echo "Aborting Plugin Removal as there is nothing to remove"
            exit 1
         fi
      fi
   fi
else
   if [[ $WASINSTANCE != "" ]]; then
      WASEXTENSION="_${WASINSTANCE}"
   fi
   if [[ -d /usr/WebSphere${WASLEVEL}${WASEXTENSION}/Plugin ]]; then
      PLUGDESTDIR="/usr/WebSphere${WASLEVEL}${WASEXTENSION}/Plugin"
      PLUGINLOG="WebSphere${WASLEVEL}${WASEXTENSION}/Plugin"
      remove_plugin_logs_$WASLEVEL
      remove_plugin_$WASLEVEL      
   else
      echo "A Plugin root is not detected"
      if [[ $WASINSTANCE == "" ]]; then
         echo "for WAS Plugin $WASLEVEL"
      else
         echo "for WAS Plugin $WASLEVEL Instance $WASINSTANCE"
      fi
      echo ""
      if [ -d /logs/WebSphere${WASLEVEL}${WASEXTENSION}/Plugin ]; then
         echo "/logs/WebSphere${WASLEVEL}${WASEXTENSION}/Plugin directory exist"
         echo "Checking for IHS logs"
         PLUGINLOG="WebSphere${WASLEVEL}${WASEXTENSION}/Plugin"
         remove_plugin_logs_$WASLEVEL
      else
         echo "Nor are there any logs detected"
         echo "Aborting Plugin removal as there is nothing to remove"
         exit 1
      fi
   fi
fi

if [[ $ERROR -gt 0 && $PRODUCT == "all" ]]; then
   echo "/////////////////////////////////////////////////////////////////"
   printf "************      Removal of IHS Base Level $IHSLEVEL"
   echo "        ***********"
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
   echo "************  completed with errors.  Review script   ***********"
   echo "************       output for further details         ***********"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 3
fi