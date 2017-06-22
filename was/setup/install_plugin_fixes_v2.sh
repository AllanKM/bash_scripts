#! /bin/ksh

################################################################
#
#  install_plugin_fixes_v2.sh -- script used to install fix  
#           packs for websphere plugin
#
#---------------------------------------------------------------
#
#  Todd Stephens - 08/22/07 - Initial creation
#  Todd Stephens - 10/27/10 - Massive overhall to use the new
#                               module model as well as include
#                               an end to end methodology
#  Todd Stephens - 05/12/11 - Added support for was7.0
#  Todd Stephens - 10/17/12 - Cleanup and standardization
#
################################################################

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
   echo "********     Script install_plugin_fixes_v2.sh need      ********" 
   echo "********              to be ran with sudo                ********"
   echo "********                  or as root                     ********"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

#---------------------------------------------------------------
# Install WAS Plugin fixes
#---------------------------------------------------------------

# Set umask
umask 002

# Set default values
FULLVERSION=""
IHSINSTANCE=""
WASINSTANCE=""
typeset -u UPDI_LEVEL
IHSLEVEL=""
PLUGINDIR=""
BITS=32
TOOLSDIR="/lfs/system/tools"
SKIPUPDATES=0
SLEEP=30
ERROR=0
PACKAGES=all

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
      fixes=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PACKAGES=$VALUE; fi ;;
      *)  print -u2 -- "#### Unknown argument: $1"
          print -u2 -- "#### Usage: ${0:##*/}"
          print -u2 -- "####           ihs_level = < Major_Minor number of ihs install >"
          print -u2 -- "####           was_version = < desired WAS version >"
          print -u2 -- "####           [ ihsinstnum=< instance number of the desired IHS version > ]"
          print -u2 -- "####           [ wasinstnum=< instance number of the desired Plugin version > ]"
          print -u2 -- "####           [ bits = < 64 or 32 > ]"
          print -u2 -- "####           [ updiVersion = < UpdateInstaller Version > ]"
          print -u2 -- "####           [ fixes = < a colon seperated list of fixpkg names or \"all\"> ]"
          print -u2 -- "####           [ toolsdir = < path to ihs scripts > ]"
          print -u2 -- "#### ---------------------------------------------------------------------------"
          print  -u2 -- "####             Defaults:"
          print  -u2 -- "####               ihs_level   = NODEFAULT"
          print  -u2 -- "####               was_version = NODEFAULT"
          print  -u2 -- "####               ihsinstnum  = NULL"
          print  -u2 -- "####               wasinstnum  = NULL"
          print  -u2 -- "####               bits        = 32"
          print  -u2 -- "####               updiVersion = FP00000NN - Based on was_version"
          print  -u2 -- "####               fixes       = all"
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

typeset -l PACKAGES_TMP=$PACKAGES
if [[ $PACKAGES_TMP == "all" ]]; then
   PACKAGES="all"
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
      echo "Aborting WAS Plugin Update"
      exit 1
   fi
elif [[ $IHSINSTANCE == "0" ]]; then
   if [[ -d /usr/HTTPServer ]]; then
      IHSDIR="/usr/HTTPServer"
   else
      echo "Base HTTPServer Serverroot is not detected"
      echo "Aborting WAS Plugin Update"
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
      echo "Aborting WAS Plugin Update"
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
if [[ ! -d ${IHSDIR}/Plugins${BASELEVEL}${WASEXTENSION} ]]; then
   PLUGDESTDIR=${IHSDIR}/Plugins
fi
if [[ ! -d $PLUGDESTDIR ]]; then
   echo "No plugin dir detected"
   echo "   Aborting WAS Plugin Update"
   exit 1
fi
PLUGLOGDIR=/logs/${HTTPLOG}/Plugins${BASELEVEL}${WASEXTENSION}

# Verify IHS is installed or exit if not
if [[ ! -f ${IHSDIR}/bin/httpd ]]; then
   echo "Base IHS install not detected"
   echo "Aborting WAS Plugin Update"
   exit 1
fi

case $BASELEVEL in
   61)
      echo ""
      echo "---------------------------------------------------------------"
      echo "        Initiated WAS Plugin Update"
      echo "---------------------------------------------------------------"
      echo ""
     
      # Verify WAS Plugin is installed or exit if not
      if [[ ! -f ${PLUGDESTDIR}/bin/mod_was_ap20_http.so ]]; then
         echo "WAS Plugin install not detected"
         echo "Aborting WAS Plugin Update"
         echo ""
         exit 1
      fi

      stop_httpd_verification_$IHSLEVEL $IHSDIR $TOOLSDIR $SLEEP plug 
      function_error_check stop_httpd_verification_$IHSLEVEL plug
      echo ""

      check_fs_avail_space /tmp 620 $TOOLSDIR
      function_error_check check_fs_avail_space plug

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
      install_plugin_fixes_61 $FULLVERSION $IHSLEVEL $IHSDIR $PLUGDESTDIR $BITS $TOOLSDIR $SLEEP $SKIPUPDATES $PACKAGES
      RETURN_CODE=$?
      if [[ $RETURN_CODE -eq 1 ]]; then
         ERROR=1
      elif [[ $RETURN_CODE -gt 1 && $RETURN_CODE -ne 200 ]]; then
         echo "    Installation of one or more WAS Plugin/SDK Fixpacks"
         echo "      Failed"
         echo ""
         ERROR=1
      elif [[ $RETURN_CODE -ne 200 ]]; then
         echo "    WAS Plugin/SDK Fixpacks install Successful"
         echo ""
      fi

      #---------------------------------------------------------------
      #                 Verify PERMS if fixes where attempted
      #---------------------------------------------------------------
      set_base_ihs_perms_$IHSLEVEL $IHSDIR $TOOLSDIR plugin
      echo ""
 
   ;;
   70)
      echo ""
      echo "---------------------------------------------------------------"
      echo "        Initiated WAS Plugin Update"
      echo "---------------------------------------------------------------"
      echo ""
     
      # Verify WAS Plugin is installed or exit if not
      if [[ ! -f ${PLUGDESTDIR}/bin/mod_was_ap22_http.so ]]; then
         echo "WAS Plugin install not detected"
         echo "Aborting WAS Plugin Update"
         echo ""
         exit 1
      fi

      stop_httpd_verification_$IHSLEVEL $IHSDIR $TOOLSDIR $SLEEP plug 
      function_error_check stop_httpd_verification_$IHSLEVEL plug
      echo ""

      check_fs_avail_space /tmp 620 $TOOLSDIR
      function_error_check check_fs_avail_space plug

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
      install_plugin_fixes_70 $FULLVERSION $IHSLEVEL $IHSDIR $PLUGDESTDIR $BITS $TOOLSDIR $SLEEP $SKIPUPDATES $PACKAGES
      RETURN_CODE=$?
      if [[ $RETURN_CODE -eq 1 ]]; then
         ERROR=1
      elif [[ $RETURN_CODE -gt 1 && $RETURN_CODE -ne 200 ]]; then
         echo "    Installation of one or more WAS Plugin/SDK Fixpacks"
         echo "      Failed"
         echo ""
         ERROR=1
      elif [[ $RETURN_CODE -ne 200 ]]; then
         echo "    WAS Plugin/SDK Fixpacks install Successful"
         echo ""
      fi

      #---------------------------------------------------------------
      #                 Verify PERMS if fixes where attempted
      #---------------------------------------------------------------
      set_base_ihs_perms_$IHSLEVEL $IHSDIR $TOOLSDIR plugin
      echo ""
   ;; 
   *)
      echo ""
      echo "/////////////////////////////////////////////////////////////////"
      echo "***********    WAS Plugin Version $BASELEVEL not supported    ***********"
      echo "***********     by this fixpacks install script       ***********"
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


if [[ $ERROR -gt 0 ]]; then
   echo "/////////////////////////////////////////////////////////////////"
   printf "******  Installation of WAS Plugin fixes for version $FULLVERSION"
   echo " ******"
   echo "******        completed with errors.  Review script        ******"
   echo "******            output for further details               ******"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 2
fi

