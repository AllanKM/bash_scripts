#!/bin/ksh

####################################################################
#
#  verify_versions_installed_v3.sh -- Displays all versions of detected
#          installed ihs or plugin software
#
#-------------------------------------------------------------------
#
#  Lou Amodeo      05/10/13   Version verification for WAS v8.5.x.x
#
####################################################################

#Verify script is called via sudo
if [[ $SUDO_USER == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "********    Script verify_versions_installed.sh needs    ********"
   echo "********               to be ran with sudo               ********"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

#Read in libraries
funcs=/lfs/system/tools/ihs/lib/ihs_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

funcs=/lfs/system/tools/was/lib/was_functions_v2.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

#Define default values
DESTDIR=""
SERVERROOT_LIST=""
PRODUCT="ihs"

#process command-line options
until [ -z "$1" ] ; do
   case $1 in
      serverroot=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SERVERROOT_LIST=$VALUE; fi ;;
      product=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ];    then PRODUCT=$VALUE;         fi ;;
      *)  print -u2 -- "#### Unknown argument: $1"
          print -u2 -- "#### Usage: ${0:##*/}"
          print -u2 -- "####           [ serverroot = < IHS install root directory > ]"
          print -u2 -- "####           [ product = < plugin | ihs ]"
          print -u2 -- "####            Note:  Leave serverroot blank to detect all ihs or plugin products"
          print -u2 -- "#### -----------------------------  ----------------------------------------------"
          print -u2 -- "####            Defaults:"
          print -u2 -- "####              serverroot = NO DEFAULT" 
          print -u2 -- "####              product = ihs"
          exit 1
      ;;
   esac
   shift
done

if [[ ! $PRODUCT == "ihs" && ! $PRODUCT == "plugin" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "          Invalid product of $PRODUCT was specified"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit
fi

if [[ $SERVERROOT_LIST == "" ]]; then
  if [[ $PRODUCT == "ihs" ]]; then
     SERVERROOT_LIST=`ls -d /usr/WebSphere85*/HTTPServer 2> /dev/null`
  else
     SERVERROOT_LIST=`ls -d /usr/WebSphere85*/Plugin     2> /dev/null`
  fi
fi

if [[ $SERVERROOT_LIST == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "             No $PRODUCT Products detected on this node"
   echo "         in any serverroot that adheres to EI Standards"
   echo "               per DOC-0047DH"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit
fi

for DESTDIR in $SERVERROOT_LIST
do
   case $DESTDIR in
   
      /usr/WebSphere85*/HTTPServer)
         if [[ $PRODUCT == "ihs" ]]; then
             NONSTD="false"
         else
             NONSTD="true"
         fi
      ;;

      /usr/WebSphere85*/Plugin) 
         if [[ $PRODUCT == "plugin" ]]; then
             NONSTD="false"
         else
             NONSTD="true"
         fi
      ;;

      *) NONSTD="true"
      ;;
   esac
   
   if [[ $NONSTD == "true" ]]; then 
         echo "///////////////////////////////////////////////////////////////////////////////"
         echo "    Requested server root $DESTDIR is not to the EI $PRODUCT Standards"
         echo "      per DOC-0047DH (/usr/WebSphere85*/Plugin or /usr/WebSphere85*/HTTPServer)"
         echo "      and is not handled by this script"
         echo "      Aborting Version Verification Script"
         echo "      for this requested server root"
         echo "///////////////////////////////////////////////////////////////////////////////"
         echo ""
         continue
   fi

   if [[ -d ${DESTDIR} ]]; then 
      echo ""
      if [[ $PRODUCT == "ihs" ]]; then
         installed_versions_85 $DESTDIR
      else
         installed_versions_plugin_85 $DESTDIR
       fi
      echo ""
   else
      echo ""
      echo "/////////////////////////////////////////////////////////////////"
      echo "    ServerRoot ${DESTDIR} does not exist on this node"
      echo "/////////////////////////////////////////////////////////////////"
      echo ""
   fi

done
