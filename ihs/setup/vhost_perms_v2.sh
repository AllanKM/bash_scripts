#!/bin/ksh

########################################################################
#
#  site_perms.sh -- Sets ei standard and ITCS 104 permissions settings 
#
#-----------------------------------------------------------------------
#
#  Todd Stephens - 05/02/2011 - Initial creation
#
########################################################################

#Starting to modulize permissions so various scripts can set permissions
funcs=/lfs/system/tools/ihs/lib/htdig_functions.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

funcs=/lfs/system/tools/ihs/lib/ihs_install_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

#Default values
DESTDIR=/usr/HTTPServer
TOOLSDIR=/lfs/system/tools
SITELIST=""

#process command-line options
until [ -z "$1" ] ; do
   case $1 in
      serverroot=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DESTDIR=$VALUE; fi ;;
      sitelist=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SITELIST=$VALUE; fi ;;
      *)  print -u2 -- "#### Unknown argument: $1"
          print -u2 -- "#### Usage: ${0:##*/} [ serverroot = < IHS install root directory > ]"
          print -u2 -- "####       [ site = < list of tags associated with sites > ]"
          print -u2 -- "####       [ toolsdir = < Location of Apps Tools > ]"
          print -u2 -- "#### ---------------------------------------------------------------------------"
          print  -u2 -- "####             Defaults:"
          print  -u2 -- "####               serverroot    = /usr/HTTPServer"
          print  -u2 -- "####               sitelist      = NODEFAULT"
          print  -u2 -- "####               toolsdir      = /lfs/system/tools"
          exit 1
      ;;
   esac
   shift
done

for SITETAG in `echo $SITELIST` ; do
   if [[ ! "$SITETAG" == "" ]]; then
      if [[ -d /projects/${SITETAG} ]]; then
         set_site_perms $SITETAG $TOOLSDIR
      else
         echo "Site $SITETAG does not exist on this node"
      fi
      if [[ -d /projects/${SITETAG}/search ]]; then
       	 htdig_perms $SITETAG
      fi
   fi
done

if [[ $SITELIST == "" ]]; then
   # Determine HTTP Dir
   HTTPDIR=`echo ${DESTDIR} | cut -d"/" -f3`
   if [[ -d /projects/${HTTPDIR} ]]; then  
      set_global_server_perms $HTTPDIR
   else
      echo "Global Site $HTTPDIR does not exist on this node"
   fi
fi
