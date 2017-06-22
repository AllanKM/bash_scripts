#!/bin/ksh

########################################################################
#
#  site_perms_v2.sh -- Sets ei standard and ITCS 104 permissions settings 
#
#-----------------------------------------------------------------------
#
#  Todd Stephens - 05/02/2011 - Initial creation
#  Todd Stephens - 06/17/12 - Clean up and common feel fixes
#
########################################################################

#Starting to modulize permissions so various scripts can set permissions
funcs=/lfs/system/tools/ihs/lib/ihs_install_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

#Default values
TOOLSDIR=/lfs/system/tools
SITELIST=""

#process command-line options
until [ -z "$1" ] ; do
   case $1 in
      sitelist=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SITELIST=$VALUE; fi ;;
      toolsdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
      *)  print -u2 -- "#### Unknown argument: $1"
          print -u2 -- "#### Usage: ${0:##*/}"
          print -u2 -- "####       [ sitelist = < list of tags associated with sites > ]"
          print -u2 -- "####       [ toolsdir = < Location of Apps Tools > ]"
          print -u2 -- "#### ---------------------------------------------------------------------------"
          print  -u2 -- "####             Defaults:"
          print  -u2 -- "####               sitelist = NODEFAULT"
          print  -u2 -- "####               toolsdir = /lfs/system/tools"
          exit 1
      ;;
   esac
   shift
done

if [[ ! -d $TOOLSDIR ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Tools Directory $TOOLSDIR does not exist"
   echo "      on this node"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $SITELIST == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "You must specify at least one sitetag for the sitelist option"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

for SITETAG in `echo $SITELIST` ; do
   if [[ ! "$SITETAG" == "" ]]; then
      if [[ -d /projects/${SITETAG} ]]; then
         set_site_perms $SITETAG $TOOLSDIR
      else
         echo "Site $SITETAG does not exist on this node"
      fi
   fi
done
