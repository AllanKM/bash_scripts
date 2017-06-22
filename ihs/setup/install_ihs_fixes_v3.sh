#!/bin/ksh

####################################################################################################
#
#  install_ihs_fixes_v3.sh -- script used to install fix packs for Base IHS 8.5.x.xx
#
# Usage: sudo /lfs/system/tools/ihs/setup/install_ihs_fixes_v3.sh ihs_version=<desired IHS version>  fixpackage=<fixpackage name> repository=<repository location>
#
####################################################################################################
#
#  Lou Amodeo    - 04/15/13 - Initial creation  #
#
####################################################################################################

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
   echo "********     Script install_ihs_fixes_v3.sh needs        ********" 
   echo "********              to be run with sudo                ********"
   echo "********                  or as root                     ********"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

# Set umask
umask 002

# Set default values
DESTDIR=""
TOOLSDIR="/lfs/system/tools"
IMBASEDIR="/opt/IBM/InstallationManager"
SLEEP=30
ERROR=0
FULLVERSION=""
IHSINSTANCE=""
IHSEXTENSION=""
FIXPACKAGE=""
REPOSITORY=""

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
      ihs_version=*)    VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FULLVERSION=$VALUE; fi ;;
      fixpackage=*)     VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FIXPACKAGE=$VALUE;  fi ;;
      repository=*)     VALUE=${1#*=}; if [ "$VALUE" != "" ]; then REPOSITORY=$VALUE;  fi ;;
      ihsinstnum=*)     VALUE=${1#*=}; if [ "$VALUE" != "" ]; then IHSINSTANCE=$VALUE; fi ;;
      toolsdir=*)       VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE;    fi ;;
      *)  print -u2 -- "#### Unknown argument: $1" 
          print -u2 -- "#### Usage: ${0:##*/}"
          print -u2 -- "####           ihs_version=< desired IHS version >"
          print -u2 -- "####           fixpackage=< fixpackage name >"
          print -u2 -- "####           repository=< location of the fix package repository >"
          print -u2 -- "####           [ ihsinstnum=< instance number of the desired IHS version > ]"
          print -u2 -- "####           [ toolsdir=< path to ei local tools > ]"
          print -u2 -- "#### ---------------------------------------------------------------------------"
          print -u2 -- "####             Defaults:"
          print -u2 -- "####               ihs_version   = NODEFAULT"          
          print -u2 -- "####               fixpackage    = NODEFAULT"
          print -u2 -- "####               repository    = NODEFAULT"
          print -u2 -- "####               ihsinstnum    = NULL"
          print -u2 -- "####               toolsdir      = /lfs/system/tools"
          print -u2 -- "####             Notes:  "
          print -u2 -- "####               1) ihsinstnum is used to install"
          print -u2 -- "####                  multiple of the same version"
          print -u2 -- "####                  of IHS"
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

if [[ $FIXPACKAGE == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Must specify a fixpackage of IHS to install"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $REPOSITORY == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Must specify a repository location of IHS to install"
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

IHSVERSION=`echo $FULLVERSION | cut -c1-2`
if [[ ! $IHSVERSION == 85 ]]; then
   echo "///////////////////////////////////////////////////////////////////"
   echo "************    Base IHS Version $IHSVERSION not supported  *******"
   echo "************         by this install script                 *******"
   echo "///////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

DESTDIR="/usr/WebSphere${IHSVERSION}/HTTPServer"
if [[ $IHSINSTANCE == "0" ]]; then
   DESTDIR="${DESTDIR}"
elif [[ $IHSINSTANCE != "" ]]; then
   IHSEXTENSION="_${IHSINSTANCE}"
   DESTDIR="/usr/WebSphere${IHSVERSION}${IHSEXTENSION}/HTTPServer"
else
   if [[ ! -d ${DESTDIR} ]]; then
      echo "An IHS Server root for ${DESTDIR} is not detected."
      echo "Aborting IHS fixpackage install"
      exit 1
   fi
fi

# Verify IHS is installed or exit if not
if [[ ! -f ${DESTDIR}/bin/httpd ]]; then
   echo "Base IHS install not detected"
   echo "Aborting Base IHS Update"
   echo ""
   exit 1
fi

if [[ ! -d $IHSLIBPATH ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Tools Directory $IHSLIBPATH does not exist"
   echo "      on this node"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

#-----------------------------------------------------------------------
# Stop if Installation Manager has not been installed
#-----------------------------------------------------------------------

if [ ! -d $IMBASEDIR/eclipse/tools ]; then 
   echo "Installation Manager must be installed prior to installing IHS fixpackage"
   echo ""
   exit 1
fi

#-----------------------------------------------------------------------
# Stop if fixpackage repository does not exist
#-----------------------------------------------------------------------

if [ ! -d $REPOSITORY ]; then 
   echo "Fixpackage repository $REPOSITORY does not exist"
   echo ""
   exit 1
fi

echo ""
echo "---------------------------------------------------------------"
echo "        Initiated Base IHS 8.5.x.xx fixpackage Update"
echo "---------------------------------------------------------------"
echo ""

stop_httpd_verification_85 $DESTDIR $TOOLSDIR $SLEEP ihs
function_error_check stop_httpd_verification_85 ihs
echo ""

check_fs_avail_space /tmp 620 $TOOLSDIR
function_error_check check_fs_avail_space ihs

echo "---------------------------------------------------------------"
echo " Installing fix package: $FIXPACKAGE                           "
echo " Repository location: $REPOSITORY                              "
echo
echo " /tmp/IM_IHSFIXPACKAGE.log installation details and progress "
echo
echo "---------------------------------------------------------------"
FIXPACKAGELOGFILE=/tmp/IM_IHSFIXPACKAGE.log
  
$IMBASEDIR/eclipse/tools/imcl install $FIXPACKAGE -repositories $REPOSITORY -installationDirectory $DESTDIR -log $FIXPACKAGELOGFILE -acceptLicense
if [ $? -ne 0 ]; then
     echo "Installation of fixpack: $FIXPACKAGE at: $REPOSITORY failed...."
     echo "exiting...."
     exit 1
fi

#---------------------------------------------------------------
#                 Verify PERMS if fixes were applied
#---------------------------------------------------------------
set_base_ihs_perms_85 $DESTDIR $TOOLSDIR ihs
echo ""

echo "---------------------------------------------------------------"
echo "       Running IHS Installed Version Report"
echo "---------------------------------------------------------------"
echo ""

installed_versions_85 $DESTDIR
echo ""

if [[ $ERROR -gt 0 ]]; then
   echo "/////////////////////////////////////////////////////////////////"
   printf "******   Installation of IHS fixes for version $FULLVERSION    "
   echo "  ******"
   echo "******        completed with errors.  Review script        ******"
   echo "******            output for further details               ******"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 2
fi
