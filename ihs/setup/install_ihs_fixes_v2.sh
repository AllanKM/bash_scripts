#! /bin/ksh

################################################################
#
#  install_ihs_fixes_v2.sh -- script used to install fix packs 
#           for Base IHS
#
#---------------------------------------------------------------
#
#  Todd Stephens - 08/21/07 - Initial creation
#  Todd Stephens - 08/19/10 - Added support to install to the specified
#                               fullversion
#  Todd Stephens - 10/27/10 - Massive overhall to use the new
#                               module model as well as include
#                               an end to end methodology
#  Todd Stephens - 06/16/12 - Further cleanup and adding 70 support
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
   echo "********     Script install_ihs_fixes_v2.sh needs        ********" 
   echo "********              to be ran with sudo                ********"
   echo "********                  or as root                     ********"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

#---------------------------------------------------------------
# Install Base IHS fixes
#---------------------------------------------------------------

# Set umask
umask 002

# Set default values
FULLVERSION=""
IHSINSTANCE=""
IHSEXTENSION=""
typeset -u UPDI_LEVEL=""
BITS=32
TOOLSDIR="/lfs/system/tools"
DESTDIR=""
SLEEP=30
ERROR=0
SKIPUPDATES=0
PACKAGES=all

# Read in libraries
#IHSLIBPATH="/fs/home/todds/lfs_tools"
IHSLIBPATH="/lfs/system/tools"
funcs=${IHSLIBPATH}/ihs/lib/ihs_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

funcs=${IHSLIBPATH}/ihs/lib/ihs_install_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

funcs=${IHSLIBPATH}/was/lib/was_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

# Process command-line options

until [ -z "$1" ] ; do
   case $1 in
      ihs_version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FULLVERSION=$VALUE; fi ;;
      ihsinstnum=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then IHSINSTANCE=$VALUE; fi ;;
      bits=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then BITS=$VALUE; fi ;;
      updiVersion=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then UPDI_LEVEL=$VALUE; fi ;;
      toolsdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
      fixes=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PACKAGES=$VALUE; fi ;;
      *)  print -u2 -- "#### Unknown argument: $1"
          print -u2 -- "#### Usage: ${0:##*/}"
          print -u2 -- "####           ihs_version=< desired ihs version >"
          print -u2 -- "####           [ ihsinstnum=< Instance number of the desired ihs version > ]"
          print -u2 -- "####           [ bits=< 64 or 32 > ]"
          print -u2 -- "####           [ updiVersion=< updateInstaller version > ]"
          print -u2 -- "####           [ fixes=< a colon seperated list of fixpkg names or \"all\" > ]"
          print -u2 -- "####           [ toolsdir=< path to ei local tools > ]"
          print -u2 -- "#### ---------------------------------------------------------------------------"
          print  -u2 -- "####             Defaults:"
          print  -u2 -- "####               ihs_version = NODEFAULT"
          print  -u2 -- "####               ihsinstnum  = NULL"
          print  -u2 -- "####               bits        = 32"
          print  -u2 -- "####               updiVersion = FP00000NN - Based on ihs_version"
          print  -u2 -- "####               fixes       = all"
          print  -u2 -- "####               toolsdir    = /lfs/system/tools"
          print  -u2 -- "####             Note:  "
          print  -u2 -- "####               1) ihsinstnum is used if there"
          print  -u2 -- "####                  are multiple installs of the"
          print  -u2 -- "####                  same base version of IHS"
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

BASELEVEL=`echo $FULLVERSION | cut -c1,2`
FIXPACKLEVEL=`echo ${FULLVERSION} | awk '{print substr ($1, length($1) - 1, length($1))}'`
if [[ $BASELEVEL == 61 && $IHSINSTANCE == "" ]]; then
   if [[ -d /usr/HTTPServer61 ]]; then
      DESTDIR="/usr/HTTPServer61"
   elif [[ -d /usr/HTTPServer ]]; then
      DESTDIR="/usr/HTTPServer"
   else
      echo "A Serverroot is not detected"
      echo "for IHS 61"
      echo "Aborting Base IHS Update"
      exit 1
   fi
elif [[ $IHSINSTANCE == "0" ]]; then
   if [[ -d /usr/HTTPServer ]]; then
      DESTDIR="/usr/HTTPServer"
   else
      echo "Base HTTPServer Serverroot is not detected"
      echo "Aborting Base IHS Update"
      exit 1
   fi
else
   if [[ $IHSINSTANCE != "" ]]; then
      IHSEXTENSION="_${IHSINSTANCE}"
   fi
   if [[ -d /usr/HTTPServer${BASELEVEL}${IHSEXTENSION} ]]; then
      DESTDIR="/usr/HTTPServer${BASELEVEL}${IHSEXTENSION}"
   else
      echo "A Serverroot is not detected"
      if [[ $IHSINSTANCE == "" ]]; then
         echo "for IHS $BASELEVEL"
      else
         echo "for IHS $BASELEVEL Instance $IHSINSTANCE"
      fi
      echo "Aborting Base IHS Update"
      exit 1
   fi
fi
if [[ $UPDI_LEVEL == "" ]]; then
   UPDI_LEVEL="FP00000${FIXPACKLEVEL}"
fi

# Verify IHS is installed or exit if not
if [[ ! -f ${DESTDIR}/bin/httpd ]]; then
   echo "Base IHS install not detected"
   echo "Aborting Base IHS Update"
   echo ""
   exit 1
fi

case $BASELEVEL in
   61)
      echo ""
      echo "---------------------------------------------------------------"
      echo "        Initiated Base IHS Update"
      echo "---------------------------------------------------------------"
      echo ""
     
      stop_httpd_verification_61 $DESTDIR $TOOLSDIR $SLEEP ihs
      function_error_check stop_httpd_verification_61 ihs
      echo ""

      check_fs_avail_space /tmp 620 $TOOLSDIR
      function_error_check check_fs_avail_space ihs

      #---------------------------------------------------------------
      #                Install UpdateInstaller
      #---------------------------------------------------------------
      UpdateInstaller_61 $FULLVERSION $BASELEVEL $DESTDIR $BITS $UPDI_LEVEL $TOOLSDIR ihs $SLEEP
      if [[ $? -gt 0 ]]; then
         SKIPUPDATES=1
      fi

      #---------------------------------------------------------------
      #                Install Base IHS Fixpacks
      #---------------------------------------------------------------
      install_ihs_fixes_61 $FULLVERSION $DESTDIR $BITS $TOOLSDIR $SLEEP $SKIPUPDATES $PACKAGES
      RETURN_CODE=$?
      if [[ $RETURN_CODE -eq 1 ]]; then
         ERROR=1
      elif [[ $RETURN_CODE -gt 1 && $RETURN_CODE -ne 200 ]]; then
         echo "    Installation of one or more IHS/SDK Fixpacks"
         echo "      Failed"
         echo ""
         ERROR=1
      elif [[ $RETURN_CODE -ne 200 ]]; then
         echo "    IHS/SDK Fixpacks install Successful"
         echo ""
      fi

      #---------------------------------------------------------------
      #                 Verify PERMS if fixes where attempted
      #---------------------------------------------------------------
      set_base_ihs_perms_61 $DESTDIR $TOOLSDIR ihs
      echo ""
 
   ;;
   70)
      echo ""
      echo "---------------------------------------------------------------"
      echo "        Initiated Base IHS Update"
      echo "---------------------------------------------------------------"
      echo ""
     
      # Verify IHS is installed or exit if not
      if [[ ! -f ${DESTDIR}/bin/httpd ]]; then
         echo "Base IHS install not detected"
         echo "Aborting Base IHS Update"
         echo ""
         exit 1
      fi

      stop_httpd_verification_70 $DESTDIR $TOOLSDIR $SLEEP ihs
      function_error_check stop_httpd_verification_70 ihs
      echo ""

      check_fs_avail_space /tmp 620 $TOOLSDIR
      function_error_check check_fs_avail_space ihs

      #---------------------------------------------------------------
      #                Install UpdateInstaller
      #---------------------------------------------------------------
      UpdateInstaller_70 $FULLVERSION $BASELEVEL $DESTDIR $BITS $UPDI_LEVEL $TOOLSDIR ihs $SLEEP
      if [[ $? -gt 0 ]]; then
         SKIPUPDATES=1
      fi

      #---------------------------------------------------------------
      #                Install Base IHS Fixpacks
      #---------------------------------------------------------------
      install_ihs_fixes_70 $FULLVERSION $DESTDIR $BITS $TOOLSDIR $SLEEP $SKIPUPDATES $PACKAGES
      RETURN_CODE=$?
      if [[ $RETURN_CODE -eq 1 ]]; then
         ERROR=1
      elif [[ $RETURN_CODE -gt 1 && $RETURN_CODE -ne 200 ]]; then
         echo "    Installation of one or more IHS/SDK Fixpacks"
         echo "      Failed"
         echo ""
         ERROR=1
      elif [[ $RETURN_CODE -ne 200 ]]; then
         echo "    IHS/SDK Fixpacks install Successful"
         echo ""
      fi

      #---------------------------------------------------------------
      #                 Verify PERMS if fixes where attempted
      #---------------------------------------------------------------
      set_base_ihs_perms_70 $DESTDIR $TOOLSDIR ihs
      echo ""
 
   ;;
   *)
      echo ""
      echo "/////////////////////////////////////////////////////////////////"
      echo "************    Base IHS Version $BASELEVEL not supported    ************"
      echo "************    by this fixpacks install script      ************"
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

installed_versions_${BASELEVEL} $DESTDIR
echo ""


if [[ $ERROR -gt 0 ]]; then
   echo "/////////////////////////////////////////////////////////////////"
   printf "******   Installation of Base IHS fixes for version $FULLVERSION"
   echo "  ******"
   echo "******        completed with errors.  Review script        ******"
   echo "******            output for further details               ******"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 2
fi

