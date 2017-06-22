#!/bin/ksh

####################################################################
#
#  verify_versions_installed_v2.sh -- Displays all versions of detected
#          installed ihs related software
#
#-------------------------------------------------------------------
#
#  Todd Stephens - 08/24/07 - Initial creation
#  Todd Stephens - 10/05/10 - Updated this to handle multiple IHS
#                               Installs as well as not having a
#                               dependacy on /etc/apachectl
#  Todd Stephens - 10/26/10 - Updated this touse the new modular
#                               model
#  Todd Stephens - 05/29/11 = Made it smarter to find all installed
#                               ihs components unless you specify
#                               a serverroot
#  Todd Stephens - 10/04/12 - Clean up function
#
####################################################################

# Verify script is called via sudo
if [[ $SUDO_USER == "" && $USER != "root" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "*******   Script verify_version_installed_v2.sh needs     *******"
   echo "*******              to be ran with sudo                  *******"
   echo "*******                   or as root                      *******"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

#---------------------------------------------------------------
# Determine what is installed and what versions those are
#---------------------------------------------------------------

# Set umask
umask 002

# Set default values
IHSLEVEL=""
IHSINSTANCE=""
IHSEXTENSION=""
DESTDIR=""
SERVERROOT_LIST=""


# Read in libraries
IHSLIBPATH="/lfs/system/tools"
funcs=${IHSLIBPATH}/ihs/lib/ihs_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

funcs=${IHSLIBPATH}/was/lib/was_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

# Process command-line options
until [ -z "$1" ] ; do
   case $1 in
      ihs_level=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then IHSLEVEL=$VALUE; fi ;;
      ihsinstnum=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then IHSINSTANCE=$VALUE; fi ;;
      *)  print -u2 -- "#### Unknown argument: $1"
          print -u2 -- "#### Usage: ${0:##*/}"
          print -u2 -- "####           [ ihs_level = < Major_Minor number of ihs install > ]"
          print -u2 -- "####           [ ihsinstnum=< instance number of the desired IHS version > ]"
          print -u2 -- "#### ---------------------------------------------------------------------------"
          print  -u2 -- "####            Defaults:"
          print  -u2 -- "####               ihs_level   = NULL"
          print  -u2 -- "####               ihsinstnum  = NULL"
          print  -u2 -- "####            Notes:"
          print  -u2 -- "####               1) Use no options to"
          print  -u2 -- "####                  detect all ihs products"
          print  -u2 -- "####               2) ihs_level with the optional"
          print  -u2 -- "####                  ihsinstnum is used to identify"
          print  -u2 -- "####                  multiple installs of the "
          print  -u2 -- "####                  same base version of IHS"
          print  -u2 -- "####                  if you want to detect products"
          print  -u2 -- "####                  installed in a particular"
          print  -u2 -- "####                  location"
          exit 1
      ;;
   esac
   shift
done

if [[ $IHSLEVEL != "" ]]; then
   if [[ $IHSLEVEL == 61 && $IHSINSTANCE == "" ]]; then
      SERVERROOT_LIST="/usr/HTTPServer61"
   elif [[ $IHSINSTANCE == "0" ]]; then
      SERVERROOT_LIST="/usr/HTTPServer"
   else
      if [[ $IHSINSTANCE != "" ]]; then
         IHSEXTENSION="_${IHSINSTANCE}"
      fi
      SERVERROOT_LIST="/usr/HTTPServer${IHSLEVEL}${IHSEXTENSION}"
   fi
fi

if [[ $SERVERROOT_LIST == "" ]]; then
   SERVERROOT_LIST=`ls -d /usr/HTTPServer* 2> /dev/null`
fi

if [[ $SERVERROOT_LIST == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "             No IHS Products detected on this node"
   echo "         in any serverroot that adheres to EI Standards"
   echo "               per DOC-0047DH (/usr/HTTPServer*)"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit
fi

for DESTDIR in $SERVERROOT_LIST
do
   if [[ -d ${DESTDIR} ]]; then
      BASELEVEL=`echo ${DESTDIR%%_*}|awk '{print substr($1, length($1)-1,length($1))}'`
      case $BASELEVEL in
         61|er)
            echo ""
            installed_versions_61 $DESTDIR
            echo ""
         ;;
         70)
            echo ""
            installed_versions_70 $DESTDIR
            echo ""
         ;;
         *)
            echo ""
            echo "/////////////////////////////////////////////////////////////////"
            echo "************    Base IHS Version $BASELEVEL not supported    ************"
            echo "************         by this install script          ************"
            echo "/////////////////////////////////////////////////////////////////"
            echo ""
            continue
         ;;
      esac
   else
      echo ""
      echo "/////////////////////////////////////////////////////////////////"
      echo "    ServerRoot ${DESTDIR} does not exist on this node"
      echo "/////////////////////////////////////////////////////////////////"
      echo ""
      continue
   fi
done
