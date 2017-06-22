#!/bin/ksh

###################################################################
#
# ihs_perms_v3.sh -- Set IHS permissions according to ITCS104 specs
#                      Set perms for install and log directories
#
#------------------------------------------------------------------
#
#  Lou Amodeo   - 05/08/13 - Initial version for IHS / Plugin 85
#
###################################################################

# Verify script is called via sudo or ran as root
if [[ $SUDO_USER == "" && $USER != "root" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "*******         Script ihs_perms_v3.sh needs              *******"
   echo "*******              to be run with sudo                  *******"
   echo "*******                   or as root                      *******"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

#----------------------------------------------------------------
# Sets IHS / Plugin Install Perms in accordance with EI Standards
#----------------------------------------------------------------

# Set umask
umask 002

# Set default values
DESTDIR=""
BASELEVEL=""
IHSINSTANCE=""
IHSEXTENSION=""
PLUGINLEVEL=""
PLUGININSTANCE=""
PLUGINEXTENSION=""
PLUGINDIR=""
typeset -l PRODUCT=all
TOOLSDIR=/lfs/system/tools

# Read in libraries
IHSLIBPATH="/lfs/system/tools"
funcs=${IHSLIBPATH}/ihs/lib/ihs_install_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

# Process command-line options
until [ -z "$1" ] ; do
   case $1 in
      ihs_level=*)     VALUE=${1#*=};  if [ "$VALUE" != "" ];  then BASELEVEL=$VALUE;      fi ;;
      ihsinstnum=*)    VALUE=${1#*=};  if [ "$VALUE" != "" ];  then IHSINSTANCE=$VALUE;    fi ;;
      plugin_level=*)  VALUE=${1#*=};  if [ "$VALUE" != "" ];  then PLUGINLEVEL=$VALUE;    fi ;;
      plugininstnum=*) VALUE=${1#*=};  if [ "$VALUE" != "" ];  then PLUGININSTANCE=$VALUE; fi ;;
      subproduct=*)    VALUE=${1#*=};  if [ "$VALUE" != "" ];  then PRODUCT=$VALUE;        fi ;;
      toolsdir=*)      VALUE=${1#*=};  if [ "$VALUE" != "" ];  then TOOLSDIR=$VALUE;       fi ;;
      *)  print -u2 -- "#### Unknown argument: $1"
          print -u2 -- "#### Usage: ${0:##*/}"
          print -u2 -- "####           ihs_level = < Major_Minor number of ihs install >"
          print -u2 -- "####           [ ihsinstnum = < Instance number of the desired IHS version > ]"
          print -u2 -- "####           [ was_level = < Major_Minor number of WAS Plugin install >"]
          print -u2 -- "####           [ wasinstnum = < Instance number of the desired WAS plugin version > ]"
          print -u2 -- "####           [ subproduct = < IHS Subproduct (all, ihs, plugin) > ]"
          print -u2 -- "####           [ toolsdir = < path to ihs scripts > ]"
          print -u2 -- "#### ---------------------------------------------------------------------------"
          print -u2 -- "####             Defaults:"
          print -u2 -- "####               ihs_level      = NODEFAULT"
          print -u2 -- "####               ihsinstnum     = NULL"
          print -u2 -- "####               plugin_level   = NULL"
          print -u2 -- "####               plugininstnum  = NULL"
          print -u2 -- "####               subproduct     = all"
          print -u2 -- "####               toolsdir       = /lfs/system/tools"
          print -u2 -- "####             Notes: "
          print -u2 -- "####               1) ihsinstnum is used to identify"
          print -u2 -- "####                  multiple installs of the "
          print -u2 -- "####                  same base version of IHS"
          print -u2 -- "####               2) plugin_level used to identify"
          print -u2 -- "####                  the level of the WAS Plugin"
          print -u2 -- "####               3) plugininstnum used to identify"
          print -u2 -- "####                  multiple installs of the "
          print -u2 -- "####                  same base version of WAS plugin"
          exit 1
      ;;
   esac
   shift
done

if [[ $BASELEVEL == "" && $PLUGINLEVEL == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "   Must specify a base level for either IHS or the WAS Plugin    "
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $BASELEVEL == "" && $PRODUCT != "plugin" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Must specify a base level of IHS"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $PLUGINLEVEL == "" && $PRODUCT != "ihs" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Must specify a plugin level for version 8.5.x.x"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

BASELEVEL=`echo ${BASELEVEL} | cut -c1,2`
if [[ $BASELEVEL != "" && $BASELEVEL != "85" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    IHS level $BASELEVEL is not supported by this script"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

PLUGINLEVEL=`echo ${PLUGINLEVEL} | cut -c1,2`
if [[ $PLUGINLEVEL != "" && $PLUGINLEVEL != "85" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Plugin level $PLUGINLEVEL is not supported by this script    "
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

if [[ $PRODUCT == "all" || $PRODUCT == "ihs" ]]; then
   if [[ $IHSINSTANCE == "0" ]]; then
      if [[ -d /usr/WebSphere${BASELEVEL}/HTTPServer ]]; then
         DESTDIR="/usr/WebSphere${BASELEVEL}/HTTPServer"
      else
         echo "Base HTTPServer Server root is not detected"
         echo "Aborting IHS/Plugin Set Perms"
         exit 1
      fi
   else
      if [[ $IHSINSTANCE != "" ]]; then
         IHSEXTENSION="_${IHSINSTANCE}"
      fi
      if [[ -d /usr/WebSphere${BASELEVEL}${IHSEXTENSION}/HTTPServer ]]; then
         DESTDIR="/usr/WebSphere${BASELEVEL}${IHSEXTENSION}/HTTPServer"
      else
         echo "A Server root is not detected"
         if [[ $IHSINSTANCE == "" ]]; then
            echo "for IHS $BASELEVEL"
         else
            echo "for IHS $BASELEVEL Instance $IHSINSTANCE"
         fi
         echo "Aborting IHS/PLugin Set Perms"
         exit 1
      fi
   fi
fi

if [[ $PRODUCT == "all" || $PRODUCT == "plugin" ]]; then
    if [[ $PLUGININSTANCE == "0" ]]; then
      if [[ -d /usr/WebSphere${PLUGINLEVEL}/Plugin ]]; then
         PLUGINDIR="/usr/WebSphere${PLUGINLEVEL}/Plugin"
      else
         echo "Plugin root is not detected"
         echo "Aborting IHS/Plugin Set Perms"
         exit 1
      fi
    else
      if [[ $PLUGININSTANCE != "" ]]; then
         PLUGINEXTENSION="_${PLUGININSTANCE}"
      fi
      if [[ -d /usr/WebSphere${PLUGINLEVEL}${PLUGINEXTENSION}/Plugin ]]; then
         PLUGINDIR="/usr/WebSphere${PLUGINLEVEL}${PLUGINEXTENSION}/Plugin"
      else
         echo "A Server root is not detected"
         if [[ $PLUGININSTANCE == "" ]]; then
            echo "for Plugin $PLUGINLEVEL"
         else
            echo "for WAS Plugin $PLUGINLEVEL Instance $PLUGININSTANCE"
         fi
         echo "Aborting IHS/PLugin Set Perms"
         exit 1
      fi
    fi
fi

if [[ $DESTDIR == "" ]]; then 
   if [[ $PRODUCT == "all" || $PRODUCT == "ihs" ]]; then
      echo " Script failed to set Destdir"
      echo "Aborting IHS/Plugin Set Perms"
      exit 2
   fi
fi

if [[ $PLUGINDIR == "" ]]; then
   if [[ $PRODUCT == "all" || $PRODUCT == "plugin" ]]; then
      echo " Script failed to set Plugindir"
      echo "Aborting IHS/PLugin Set Perms"
      exit 2
   fi
fi

if [[ $PRODUCT == "all" || $PRODUCT == "ihs" ]]; then
    echo " Setting IHS / Plugin permissions"
    set_base_ihs_perms_85 $DESTDIR $TOOLSDIR $PRODUCT $PLUGINDIR
else
    echo " Setting Plugin permissions"
    set_plugin85_perms $PLUGINDIR
fi
