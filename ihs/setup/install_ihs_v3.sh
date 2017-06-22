#!/bin/ksh

###################################################################
#
#  install_ihs_v3.sh -- This script is used to install ihs 
#      8.5.x.x in accordance with ITCS104 and EI Standards
#
###################################################################
#
#  Lou Amodeo - 04/12/2013 - Initial creation
#  Lou Amodeo - 12/02/2013 - Add 8.5.5.1 fixpack
#  Lou Amodeo - 04/29/2014 - Add 8.5.5.2 fixpack
#  Lou Amodeo - 01/08/2015 - Add 8.5.5.4 fixpack
#  Lou Amodeo - 09/03/2015 - Add 8.5.5.6 fixpack
#
##################################################################

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
   echo "*******       Script install_ihs_v3.sh needs              *******"
   echo "*******              to be run with sudo                  *******"
   echo "*******                   or as root                      *******"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi


#---------------------------------------------------------------
# IHS install according to EI standards
#---------------------------------------------------------------

# Set umask
umask 002

# Set default values
TIMER_ACTIVATED=0
FULLVERSION=""
IHSINSTANCE=""
IHSEXTENSION=""
IHS_FS_SIZE=1024
PROJECT_FS_SIZE=512
PROJECTS_LINK=""
DESTDIR=""
TOOLSDIR=/lfs/system/tools
SLEEP=15
ERROR=0
VG=""

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
      projects_size=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROJECT_FS_SIZE=$VALUE; fi ;;
      projects_link=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROJECT_LINK=$VALUE; fi ;;
      ihsinstnum=*)     VALUE=${1#*=}; if [ "$VALUE" != "" ]; then IHSINSTANCE=$VALUE; fi ;;
      vg=*)             VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VG=$VALUE; fi ;;
      toolsdir=*)       VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
      *)  print -u2 -- "#### Unknown argument: $1" 
          print -u2 -- "#### Usage: ${0:##*/}"
          print -u2 -- "####           ihs_version=< desired IHS version >"         
          print -u2 -- "####           vg=< volume group where ihs binaries are installed >"
          print -u2 -- "####           [ ihsinstnum=< instance number of the desired IHS version > ]"
          print -u2 -- "####           [ projects_size=< size of /projects in MB > ]"
          print -u2 -- "####           [ projects_link=< /projects link location > ]"
          print -u2 -- "####           [ toolsdir=< path to ei local tools > ]"
          print -u2 -- "#### ---------------------------------------------------------------------------"
          print -u2 -- "####             Defaults:"
          print -u2 -- "####               ihs_version   = NODEFAULT"
          print -u2 -- "####               vg            = NODEFAULT"
          print -u2 -- "####               ihsinstnum    = NULL"
          print -u2 -- "####               projects_size = 512"
          print -u2 -- "####               projects_link = NODEFAULT"
          print -u2 -- "####               toolsdir      = /lfs/system/tools"
          print -u2 -- "####             Notes:  "
          print -u2 -- "####               1) In order to use projects_link"
          print -u2 -- "####                  you must specify a projects_size"
          print -u2 -- "####                  of zero"
          print -u2 -- "####               2) ihsinstnum is used to install"
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

if [[ $VG == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Must specify a Volume Group for install"
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
DESTDIR="/usr/WebSphere${BASELEVEL}/HTTPServer"
if [[ $IHSINSTANCE == "0" ]]; then
   DESTDIR="${DESTDIR}"
elif [[ $IHSINSTANCE != "" ]]; then
   IHSEXTENSION="_${IHSINSTANCE}"
   DESTDIR="/usr/WebSphere${BASELEVEL}${IHSEXTENSION}/HTTPServer"
else
   if [[ -d ${DESTDIR} ]]; then
      echo "Directory ${DESTDIR} already exists.  Either remove"
      echo "  this directory/install or rerun this command"
      echo "  with the instnum option"
      echo ""
      exit 2
   fi
fi
HTTPLOG="WebSphere${BASELEVEL}${IHSEXTENSION}/HTTPServer"
SRCDIR="/fs/system/images/websphere/8.5/supplements"
PACKAGE="com.ibm.websphere.IHS.v85"
FEATURE="arch.64bit"
DOTVER="8.5.5.0"
IMBASEDIR="/opt/IBM/InstallationManager"
IMSHAREDDIR="/usr/IMShared"
LOGFILE="/tmp/IM_IHSInstall.log"

#----------------------------------------------------------------------------
# Set platform specific properties
#----------------------------------------------------------------------------

set_install_properties ()
{   
    INSTDIR="/fs/system/images/websphere/8.5/supplements"
    PACKAGE="com.ibm.websphere.IHS.v85"

    if [ "$FULLVERSION" == "85000" ]; then
        DOTVER="8.5.0.0"
        FIXPACKAGES=""
        FIXREPOSITORIES=""
    elif [ "$FULLVERSION" == "85001" ]; then
        DOTVER="8.5.0.1"
        FIXPACKAGES="com.ibm.websphere.IHS.v85"
        FIXREPOSITORIES="/fs/system/images/websphere/8.5/fixes/85001/supplements"
    elif [ "$FULLVERSION" == "85500" ]; then
        DOTVER="8.5.5.0"
        FIXPACKAGES="com.ibm.websphere.IHS.v85"
        FIXREPOSITORIES="/fs/system/images/websphere/8.5/fixes/85500/supplements"
    elif [ "$FULLVERSION" == "85501" ]; then
        DOTVER="8.5.5.1"
        FIXPACKAGES="com.ibm.websphere.IHS.v85 8.5.0.0-WS-WASIHS_GSKit-MultiOS-IFPI09443"
        FIXREPOSITORIES="/fs/system/images/websphere/8.5/fixes/85501/supplements /fs/system/images/websphere/8.5/ifixes/ifpi09443"
    elif [ "$FULLVERSION" == "85502" ]; then
        DOTVER="8.5.5.2"
        FIXPACKAGES="com.ibm.websphere.IHS.v85 8.5.5.2-WS-WASIHS-MultiOS-IFPI22070"
        FIXREPOSITORIES="/fs/system/images/websphere/8.5/fixes/85502/supplements /fs/system/images/websphere/8.5/ifixes/ifpi22070"
    elif [ "$FULLVERSION" == "85504" ]; then
        DOTVER="8.5.5.4"
        FIXPACKAGES="com.ibm.websphere.IHS.v85 8.5.5.4-WS-WASIHS-MultiOS-IFPI31516"
        FIXREPOSITORIES="/fs/system/images/websphere/8.5/fixes/85504/supplements /fs/system/images/websphere/8.5/ifixes/ifpi31516/8.5.5.4"
    elif [ "$FULLVERSION" == "85506" ]; then
        DOTVER="8.5.5.6"
        FIXPACKAGES="com.ibm.websphere.IHS.v85"
        FIXREPOSITORIES="/fs/system/images/websphere/8.5/fixes/85506/supplements"
    else
        echo "Not configured to install IBM HTTPServer version $FULLVERSION"
        echo "exiting..."
        exit 1
    fi
}

install_was_aix ()
{   
    OSDIR="aix"
    CHMOD="chmod -h"
    CHMODR="chmod -hR"
    XARGS="xargs -I{} "
    FS_TABLE="/etc/filesystems"
    SYSTEM_GRP="system"
}

install_was_linux_x86 ()
{
    OSDIR="linux"
    CHMOD="chmod "
    CHMODR="chmod -R "
    XARGS="xargs -i{} "
    FS_TABLE="/etc/fstab"
    SYSTEM_GRP="root"

    #java -version hangs on SLES 9 unless the following ulimit command is executed
    # as mentioned at http://www-1.ibm.com/support/docview.wss?uid=swg21182138
    ulimit -s 8196
}

install_was_linux_ppc () 
{
    OSDIR="linuxppc"
    CHMOD="chmod "
    CHMODR="chmod -R "
    XARGS="xargs -i{} "
    FS_TABLE="/etc/fstab"
    SYSTEM_GRP="root"

    #java -version hangs on SLES 9 unless the following ulimit command is executed
    # as mentioned at http://www-1.ibm.com/support/docview.wss?uid=swg21182138
    ulimit -s 8196
}

install_ihs_85 ()
{
   echo "---------------------------------------------------------------"
   echo "      Exit if IHS is already installed at this location        "
   echo "---------------------------------------------------------------"
   echo ""
   if [[ -d $DESTDIR ]]; then
      echo "IHS is already installed at: $DESTDIR, exiting"
      exit 1
   fi
   
   #-----------------------------------------------------------------------
   # Stop if Installation Manager has not been installed
   #-----------------------------------------------------------------------
   if [ ! -d $IMBASEDIR/eclipse/tools ]; then 
      echo "Installation Manager must be installed prior to installing IHS "
      echo ""
      exit 1
   fi

   #-----------------------------------------------------------------------
   # Stop if repository does not exist
   #-----------------------------------------------------------------------
   if [ ! -f ${SRCDIR}/repository.config ]; then 
      echo "Installation repository $SRCDIR/repository.config does not exist"
      echo ""
      error_message_ihs 2
   fi

   echo "---------------------------------------------------------------"
   echo "                    Install Base IHS"
   echo "---------------------------------------------------------------"
   echo ""
   echo "Installing IHS ${BASELEVEL}"
   echo "  to directory $DESTDIR"
   echo "  from ${SRCDIR}"
   echo "   in $SLEEP seconds"
   echo "     Ctrl-C to suspend"
   echo ""

   install_timer $SLEEP
   function_error_check install_timer ihs
  
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

   echo "----------------------------------------------------------------------"
   echo "Installing IBM Http Server version: $FULLVERSION "
   echo ""
   echo "/tmp/IM_IHSInstall.log installation details and progress"
   echo "----------------------------------------------------------------------"
   
   $IMBASEDIR/eclipse/tools/imcl install $PACKAGE,$FEATURE -repositories $SRCDIR/repository.config -installationDirectory $DESTDIR -sharedResourcesDirectory $IMSHAREDDIR -properties user.ihs.httpPort=80 -log $LOGFILE -accessRights admin -acceptLicense

   # Verify that something was installed
   if [[ ! -f ${DESTDIR}/bin/httpd ]]; then
      echo "Failed to install IBM HTTPServer $DOTVER.  Exiting...."
      error_message_ihs 3
   fi
   
   echo "---------------------------------------------------------------"
   echo "Installing IBM HTTPServer fixes                                "
   echo ""
   echo "---------------------------------------------------------------"
   echo "FIXPACKAGES="$FIXPACKAGES
   echo "FIXREPOSITORIES="$FIXREPOSITORIES
   
   # Move the list of fix repositories to an array that can be indexed
   typeset -i IDX=0
   REPOSARRAY[0]=""
   for REPOS in ${FIXREPOSITORIES[@]}
   do
      REPOSARRAY[${IDX}]=${REPOS}
      IDX=IDX+1
   done
   
   IDX=0
   for FIXPACKAGE in ${FIXPACKAGES[@]}
   do
      REPOS=${REPOSARRAY[${IDX}]}    
      echo "Installing fixpackage: ${FIXPACKAGE} at: ${REPOS}"
      ${TOOLSDIR}/ihs/setup/install_ihs_fixes_v3.sh ihs_version=${BASELEVEL} fixpackage=${FIXPACKAGE} repository=${REPOS} ihsinstnum=${IHSINSTANCE}
      if [ $? -ne 0 ]; then
         echo "Installation of fixpackage: ${FIXPACKAGE} at: ${REPOS} failed."
         echo "exiting...."
         exit 1
      fi
      IDX=IDX+1
   done

   # The IHS.product file will contain the $DOTVER requested after any fixpackages have been applied. 
   PRODFILE="IHS.product"
   echo "Checking $PRODFILE file for $DOTVER"
   grep version\>${DOTVER} ${DESTDIR}/properties/version/${PRODFILE}
   if [ $? -ne 0 ]; then 
      echo "Failed to install IBM HTTPServer $DOTVER.  Exiting...."
      exit 1
   fi
   
   echo ""
   echo "---------------------------------------------------------------"
   echo "Setting up Base IHS log directory according to the"
   echo "  EI standards for an IHS webserver"
   echo "---------------------------------------------------------------"
   echo ""
   
   if [[ -d ${DESTDIR}/logs/ && ! -L ${DESTDIR}/logs/ ]]; then
      if [[ ! -d /logs/${HTTPLOG} ]]; then
         echo "    Creating /logs/${HTTPLOG}"
         mkdir -p /logs/${HTTPLOG}
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
   
}


#---------------------------------------------------------------
# Commands that run on all platforms
#---------------------------------------------------------------

#-----------------------------------------------------------------------
# Install based on platform                                             
#-----------------------------------------------------------------------
case `uname` in 
    AIX) install_was_aix ;;
    Linux)
        case `uname -i` in
            ppc*)   install_was_linux_ppc ;;
            x86*)   install_was_linux_x86 ;;
        esac
    ;;
    *)
        print -u2 -- "${0:##*/}: `uname` not supported by this install script."
        exit 1
    ;;
esac
set_install_properties

install_ihs_85

echo "---------------------------------------------------------------"
echo "            Performing Post Install Setup"
echo "---------------------------------------------------------------"
echo ""
echo "Setting up /projects filesystem according to the "
echo "  EI standards for an IHS webserver"
echo ""

#See if /projects is a link to /www or otherwise not a candidate for a
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

#---------------------------------------------------------------
# Set PERMS
#---------------------------------------------------------------
set_base_ihs_perms_85 $DESTDIR $TOOLSDIR ihs

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
