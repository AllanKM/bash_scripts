#!/bin/ksh

###################################################################
#
# ihs_perms_v2.sh -- Set IHS permissions according to ITCS104 specs
#                      Set perms for base install and log directory
#
#------------------------------------------------------------------
#
#  Todd Stephens - 10/26/10 - Massive overall to provide 
#                               modulations and to increase
#                               speed
#  Todd Stephens - 06/16/12 - Further cleanup and adding IHS 70
#  Lou  Amodeo   - 04/26/13 - Add IHS 85
#
###################################################################

# Verify script is called via sudo or ran as root
if [[ $SUDO_USER == "" && $USER != "root" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "*******         Script ihs_perms_v2.sh needs              *******"
   echo "*******              to be ran with sudo                  *******"
   echo "*******                   or as root                      *******"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

#---------------------------------------------------------------
# Sets IHS Install Perms in accordance with EI Standards
#---------------------------------------------------------------

# Set umask
umask 002

# Set default values
DESTDIR=""
BASELEVEL=""
IHSINSTANCE=""
IHSEXTENSION=""
typeset -l PRODUCT=all
TOOLSDIR=/lfs/system/tools

# Read in libraries
#IHSLIBPATH="/fs/home/todds/lfs_tools"
IHSLIBPATH="/lfs/system/tools"
funcs=${IHSLIBPATH}/ihs/lib/ihs_install_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

# Process command-line options
until [ -z "$1" ] ; do
   case $1 in
      ihs_level=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then BASELEVEL=$VALUE; fi ;;
      ihsinstnum=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then IHSINSTANCE=$VALUE; fi ;;
      subproduct=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PRODUCT=$VALUE; fi ;;
      toolsdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
      *)  print -u2 -- "#### Unknown argument: $1"
          print -u2 -- "#### Usage: ${0:##*/}"
          print -u2 -- "####           ihs_level = < Major_Minor number of ihs
 install >"
          print -u2 -- "####           [ ihsinstnum = < Instance number of the desired IHS version > ]"
          print -u2 -- "####           [ subproduct = < IHS Subproduct (all, ihs, plugin) > ]"
          print -u2 -- "####           [ toolsdir = < path to ihs scripts > ]"
          print -u2 -- "#### ---------------------------------------------------------------------------"
          print  -u2 -- "####             Defaults:"
          print  -u2 -- "####               ihs_level   = NODEFAULT"
          print  -u2 -- "####               ihsinstnum  = NULL"
          print  -u2 -- "####               subproduct  = all"
          print  -u2 -- "####               toolsdir    = /lfs/system/tools"
          print  -u2 -- "####             Notes: "
          print  -u2 -- "####               1) ihsinstnum is used to identify"
          print  -u2 -- "####                  multiple installs of the "
          print  -u2 -- "####                  same base version of IHS"
          exit 1
      ;;
   esac
   shift
done
   
if [[ $BASELEVEL == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Must specify a base level of IHS"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $PRODUCT != "all" && $PRODUCT != "ihs" && $PRODUCT != "plugin" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Parameter subproduct needs to be one of the following:"
   echo "      ihs, plugin, or all"
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

if [[ $BASELEVEL == 61 && $IHSINSTANCE == "" ]]; then
   if [[ -d /usr/HTTPServer61 ]]; then
      DESTDIR="/usr/HTTPServer61"
   elif [[ -d /usr/HTTPServer ]]; then
      DESTDIR="/usr/HTTPServer"
   else
      echo "A Serverroot is not detected"
      echo "for IHS 61"
      echo "Aborting IHS Set Perms"
      exit 1
   fi
elif [[ $IHSINSTANCE == "0" ]]; then
   if [[ -d /usr/HTTPServer ]]; then
      DESTDIR="/usr/HTTPServer"
   else
      echo "Base HTTPServer Serverroot is not detected"
      echo "Aborting IHS Set Perms"
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
      echo "Aborting IHS Set Perms"
      exit 1
   fi
fi

if [[ $DESTDIR == "" ]]; then
   echo " Script failed to set Destdir"
   echo "Aborting IHS Set Perms"
   exit 2
fi

case $BASELEVEL in
   61)
      set_base_ihs_perms_61 $DESTDIR $TOOLSDIR $PRODUCT
   ;;
   70)
      set_base_ihs_perms_70 $DESTDIR $TOOLSDIR $PRODUCT
   ;;
   85)
      set_base_ihs_perms_85 $DESTDIR $TOOLSDIR $PRODUCT
   ;;
   *)
      echo ""
      echo "/////////////////////////////////////////////////////////////////"
      echo "**********    IHS Product baselevel $BASELEVEL not supported    *********"
      echo "**********          by this perms and ownership         *********"
      echo "**********              verification script             *********"
      echo "/////////////////////////////////////////////////////////////////"
      echo ""
      exit 1
   ;;
esac


