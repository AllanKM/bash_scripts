#!/bin/ksh

###################################################################
#
#  validate_httpd_v2.sh -- performs simple validation steps on
#                          config files
#
#------------------------------------------------------------------
#
#  Steve Farrell - Unknown    - Initial version
#  Todd Stephens - 04/15/2013 - Revamped to take arguments to
#                                 pave the way to do shared IHS
#
###################################################################

# Default values
SITETAG=HTTPServer
typeset -l DEBUG=false DETAILS=false
ERROR=0
RETURN_CODE=0
SERVERROOT_MAIN=""
LISTEN_443=false
SEQUENCE=1
KEYFILE_MAIN=""
LIB_HOME="/lfs/system/tools"

#process command-line options
until [[ -z "$1" ]] ; do
   case $1 in
      sitetag=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SITETAG=$VALUE; fi ;;
      details=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DETAILS=$VALUE; fi ;;
      debug=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DEBUG=$VALUE; fi ;;
      *)  print -u2 -- "#### Unknown argument: $1"
          print -u2 -- "#### Usage: ${0:##*/} [ sitetag = < sitetag of site > ]"
          print -u2 -- "####           [ details = < true or false > ]"
          print -u2 -- "####           [ debug = < true or false > ]"
          print -u2 -- "#### ---------------------------------------------------------------------------"
          print  -u2 -- "####             Defaults:"
          print  -u2 -- "####               sitetag = HTTPServer"
          print  -u2 -- "####               details = false"
          print  -u2 -- "####               debug   = false"
          exit 1
      ;;
   esac
   shift
done

if [[ $DEBUG != "true" && $DEBUG != "false" ]]; then
   echo "Parameter debug needs a value of \"true\" or \"false\""
   exit 1
fi

if [[ $DETAILS != "true" && $DETAILS != "false" ]]; then
   echo "Parameter details needs a value of \"true\" or \"false\""
   exit 1
fi

########################################################
#check config file
########################################################
checkSingleConfFile(){
   typeset USER_ID USER_ID_COUNT USER_GROUP USER_GROUP_COUNT SERVERROOT SERVERROOT_MAIN SERVERROOT_COUNT \
           COREDUMPDIRECTORY COREDUMPDIRECTORY_COUNT MODULE DOCUMENTROOT SSLENABLE KEYFILE KEYFILE_MAIN \
           KEYFILE_COUNT MIME MIME_COUNT MIME_REAL MODSSL SSLCACHEPORT SSLCACHEPORT_COUNT RETURN_CODE=0 \
           CONF_FILE=$1 TYPE=$2

   ####################################################
   #check User 
   ####################################################
   USER_ID_COUNT=`cat $CONF_FILE|grep -wi "^[[:space:]]*User"| wc -l`
   if [[ $USER_ID_COUNT -gt 1 && $TYPE = "main" ]]; then
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
         echo "      Error: Can not have multiple User settings"
      fi
      RETURN_CODE=1
   fi
   for USER_ID in `cat $CONF_FILE|grep -wi "^[[:space:]]*User"|awk {'print $NF'}`; do
      if [[ $DEBUG == "true" ]]; then
         echo "      User:$USER_ID"
      fi
      if [[ $USER_ID != "webinst" && $TYPE == "main" ]]; then
         if [[  $DETAILS == "true" || $DEBUG == "true"  ]]; then
            echo "      Error: User not set to EI Standard IHS User webinst: $USER_ID"
         fi
         RETURN_CODE=1
      elif [[ $USER_ID != "" && $TYPE == "include" ]]; then
         if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
            echo "      Error: Parameter User not allowed in Include files"
         fi
         RETURN_CODE=1
      fi
      if [[ $TYPE == "main" ]]; then
         grep -w $USER_ID /etc/passwd > /dev/null 2>&1
         if [[ $? -ne 0 ]]; then
            if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
               echo "      Error: User $USER_ID is not a local id on this server"
            fi
            RETURN_CODE=1
         fi
      fi
   done
   if [[ $TYPE == "main" && $USER_ID == "" ]]; then
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
         echo "      Error: User not defined in site's main config"
      fi
      RETURN_CODE=1
   fi  

   ####################################################
   #check Group
   ####################################################
   USER_GROUP_COUNT=`cat $CONF_FILE|grep -wi "^[[:space:]]*Group"| wc -l`
   if [[ $USER_GROUP_COUNT -gt 1 && $TYPE = "main" ]]; then
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
         echo "      Error: Can not have multiple Group settings"
      fi
      RETURN_CODE=1
   fi
   for USER_GROUP in `cat $CONF_FILE|grep -wi "^[[:space:]]*Group"|awk {'print $NF'}`; do
      if [[ $DEBUG == "true" ]]; then
         echo "      Group:$USER_GROUP"
      fi
      if [[ $USER_GROUP != "apps" && $TYPE == "main" ]]; then  
         if [[ $DETAILS == "true" || $DEBUG == "true"  ]]; then
            echo "      Error: Group not set to EI Standard IHS Group apps: $USER_GROUP"
         fi
         RETURN_CODE=1
      elif [[ $USER_GROUP != "" && $TYPE == "include" ]]; then
         if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
            echo "      Error: Parameter Group not allowed in Include files"
         fi
         RETURN_CODE=1
      fi
      if [[ $TYPE == "main" ]]; then
         grep -w $USER_GROUP /etc/group > /dev/null 2>&1
         if [[ $? -ne 0 ]]; then
            if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
               echo "      Error: Group $USER_GROUP is not a local group on this server"
            fi
            RETURN_CODE=1
         fi
      fi
   done
   if [[ $TYPE == "main" && $USER_GROUP == "" ]]; then
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
         echo "      Error: Group not defined in site's main config"
      fi
      RETURN_CODE=1
   fi  

   ####################################################
   #check ServerRoot
   ####################################################
   SERVERROOT_COUNT=`cat $CONF_FILE|grep -wi "^[[:space:]]*ServerRoot"| wc -l`
   if [[ $SERVERROOT_COUNT -gt 1 && $TYPE = "main" ]]; then
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
         echo "      Error: Can not have multiple ServerRoot settings"
      fi
      RETURN_CODE=1
   fi
   for SERVERROOT in `cat $CONF_FILE|grep -wi "^[[:space:]]*ServerRoot"|awk {'print $2'}| tr -d \"`; do
      if [[ $DEBUG == "true" ]]; then
         echo "      ServerRoot:$SERVERROOT"
      fi
   
      if [[ $TYPE == "main" ]]; then
         SERVERROOT_MAIN=$SERVERROOT
      elif [[ $TYPE == "include" ]]; then
         if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
            echo "      Error: Parameter ServerRoot not allowed in Include files"
         fi
         RETURN_CODE=1
      fi
           
      if [[ ! -d $SERVERROOT_MAIN && $TYPE == main ]]; then
         if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
            echo "      Error: ServerRoot $SERVERROOT"
            echo "               does not exist"
         fi
         SERVERROOT_MAIN=""
         RETURN_CODE=1
      fi
   done
   if [[ $TYPE == "main" && $SERVERROOT == "" ]]; then
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
         echo "      Error: ServerRoot not defined in site's main config"
      fi
      RETURN_CODE=1
   fi  

   ####################################################
   #check Core Dump Directory
   ####################################################
   COREDUMPDIRECTORY_COUNT=`cat $CONF_FILE|grep -wi "^[[:space:]]*CoreDumpDirectory"| wc -l`
   if [[ $COREDUMPDIRECTORY_COUNT -gt 1 && $TYPE = "main" ]]; then
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
         echo "      Error: Can not have multiple CoreDumpDirectory settings"
      fi
      RETURN_CODE=1
   fi
   for COREDUMPDIRECTORY in `cat $CONF_FILE|grep -wi "^[[:space:]]*CoreDumpDirectory"|awk {'print $NF'}`; do
      if [[ $DEBUG == "true" ]]; then
         echo "      CoreDumpDirectory:$COREDUMPDIRECTORY"
      fi
      if [[ $TYPE = "include" ]]; then
         if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
            echo "      Error: Parameter CoreDumpDirectory not allowed in Include files"
         fi
         RETURN_CODE=1
      fi
      if [[ ! -d $COREDUMPDIRECTORY && $TYPE = "main" ]]; then
         if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
            echo "      Error: CoreDumpDirectory $COREDUMPDIRECTORY"
            echo "               does not exist"
         fi
         RETURN_CODE=1
      fi
   done
   if [[ $TYPE == "main" && $COREDUMPDIRECTORY == "" ]]; then
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
         echo "      Error: CoreDumpDirectory not defined in site's main config"
      fi
      RETURN_CODE=1
   fi  
   
   ####################################################
   #check custom mime.types
   ####################################################
   if [[ $SERVERROOT_MAIN = "" && $TYPE = "main"  && `cat $CONF_FILE|grep -wi "^[[:space:]]*TypesConfig"` != "" ]]; then
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
         echo "      Error: ServerRoot is not defined or is defined incorrectly -- Unable to check custom mime.types settings"
      fi
      RETURN_CODE=1
   fi
   MIME_COUNT=`cat $CONF_FILE|grep -wi "^[[:space:]]*TypesConfig"| wc -l`
   if [[ $MIME_COUNT -gt 1 && TYPES = "main" ]]; then
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
         echo "      Error: Can not have multiple TypesConfig settings"
      fi
      RETURN_CODE=1
   fi
   for MIME in `cat $CONF_FILE|grep -wi "^[[:space:]]*TypesConfig"|awk {'print $NF'}`; do
      if [[ $DEBUG == "true" ]]; then
         echo "      TypesConfig:$MIME"
      fi
      if [[ $TYPE = "include" ]]; then
         if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
            echo "      Error: TypesConfig parameter not allowed in includes"
         fi
         RETUEN_CODE=1
      fi
      if [[ $SERVERROOT_MAIN != "" && $TYPE = "main" ]]; then
         if [ ! -L ${SERVERROOT_MAIN}/$MIME ]; then
            if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
               echo "      Error: mime_custom symlink does not exist"
            fi
            RETURN_CODE=1
         fi
         if [ -L ${SERVERROOT_MAIN}/$MIME ]; then
            MIME_REAL=`ls -l ${SERVERROOT_MAIN}/$MIME | awk {'print $NF'}`
            if [ ! -f $MIME_REAL ]; then
               if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
                  echo "      Error: Custom mime.types file $MIME_REAL"
                  echo "               does not exist"
               fi
               RETURN_CODE=1
            fi
         fi
      fi
   done

   ####################################################
   #check LoadModules
   ####################################################
   if [[ $SERVERROOT_MAIN = "" && $TYPE = "main" ]]; then
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
         echo "      Error: ServerRoot is not defined or is defined incorrectly -- Unable to check Standard Modules"
      fi
      RETURN_CODE=1
   fi
   if [[ $SERVERROOT_COUNT -gt 1 ]]; then
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then 
         echo "      Error: Multiple ServerRoots defined -- Unable to check Standard Module Settings"
      fi
      RETURN_CODE=1
   fi
   for MODULE in `cat $CONF_FILE|grep -wi "^[[:space:]]*LoadModule"|awk {'print $NF'}`; do
      if [[ $DEBUG == "true" ]]; then
         echo "      LoadModule:$MODULE"
      fi
      if [[ $TYPE = "include" && $CONF_FILE != *kht-*.conf && $MODULE = *khtapache*.so ]]; then
         if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
            echo "      Error: Module $MODULE"
            echo "               should not be defined within Include Files"
            echo "               other then the khtapache module in the"
            echo "               khtagent Include"
         fi
         RETURN_CODE=1
      fi
      if [[ $SERVERROOT_MAIN != "" && $MODULE != /* && $TYPE = "main" ]]; then
         if [[ $SERVERROOT_COUNT = 1 ]]; then
            if [[ ! -f ${SERVERROOT_MAIN}/$MODULE ]]; then
               if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
                  echo "      Error: Standard Module $MODULE"
                  echo "               does not exist"
               fi
               RETURN_CODE=1
            fi
         fi
      fi
      if [[ $MODULE == /* && ( $TYPE = "main" || ( $CONF_FILE != *kht-*.conf && $MODULE = *khtapache*.so ) ) ]]; then
         if [[ ! -f $MODULE ]]; then
            if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
               echo "      Error: Custom Module $MODULE"
               echo "               does not exist"
            fi
            RETURN_CODE=1
         fi
      fi
   done

   ####################################################
   #check Document Root
   ####################################################
   for DOCUMENTROOT in `cat $CONF_FILE|grep -wi "^[[:space:]]*DocumentRoot"|cut -f2- -d "/" | tr -d \" | sort | uniq`; do
      if [[ $DEBUG == "true" ]]; then
         echo "      DocumentRoot:/$DOCUMENTROOT"
      fi
      if [[ ! -d "/"$DOCUMENTROOT ]]; then
         if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
            echo "      Error: DocumentRoot "/"$DOCUMENTROOT"
            echo "               does not exist"
         fi
         RETURN_CODE=1
      fi
   done
    
   #####################################################
   #check Key File
   #####################################################
   if [[ $TYPE = "main" && `cat $CONF_FILE|grep -wi "^[[:space:]]*SSLEnable"` != "" ]]; then
      SSLENABLE="true"
   fi
   KEYFILE_COUNT=`cat $CONF_FILE|grep -wi "^[[:space:]]*KeyFile"| wc -l`
   if [[ $KEYFILE_COUNT -gt 1 && $TYPE = "main" ]]; then
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
         echo "      Error: Can not have multiple KeyFile settings"
      fi
      RETURN_CODE=1
   fi
   for KEYFILE in `cat $CONF_FILE|grep -wi "^[[:space:]]*KeyFile"|awk {'print $2'}`; do
      if [[ $TYPE == "main" ]]; then
         KEYFILE_MAIN=$KEYFILE
         if [[ $DEBUG == "true" ]]; then
            echo "      Main KeyFile:$KEYFILE_MAIN"
         fi
         if [[ ! -f $KEYFILE_MAIN ]]; then
            if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
               echo "      Error: Main KeyFile $KEYFILE"
               echo "               does not exist"
            fi
            RETURN_CODE=1
         fi
      fi
      if [[ $TYPE == include ]]; then
         if [[ $DEBUG == "true" ]]; then
            echo "      KeyFile:$KEYFILE"
         fi
         if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
            echo "      Error: Parameter KeyFile not allowed in Include files"
         fi
         RETURN_CODE=1
      fi
   done
   if [[ $KEYFILE_MAIN == "" && $SSLENABLE == true ]]; then
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
         echo "      Error: SSL enabled and no Keyfile defined"
      fi
      RETURN_CODE=1
   fi 
   if [[ $KEYFILE_MAIN != "" && $SSLENABLE != true ]]; then
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
         echo "      Error: Keyfile defined but there is no SSLEnabled Virtualhost in the main config"
      fi
      RETURN_CODE=1
   fi

   ####################################################
   #check SSL Cache Port
   ####################################################
   if [[ $TYPE = "main" && `cat $CONF_FILE|grep -wi "^[[:space:]]*LoadModule[[:space:]]*ibm_ssl_module[[:space:]]*modules/mod_ibm_ssl.so"` != "" ]]; then
      MODSSL="true"
   fi
   SSLCACHEPORT_COUNT=`cat $CONF_FILE|grep -wi "^[[:space:]]*SSLCachePortFilename"| wc -l`
   if [[ $SSLCACHEPORT_COUNT -gt 1 && $TYPE = "main" ]]; then
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
         echo "      Error: Can not have multiple SSLCachePortFilename settings"
      fi
      RETURN_CODE=1
   fi
   if [[ $MODSSL = "true" && $SITETAG != HTTPServer* && `cat $CONF_FILE|grep -wi "^[[:space:]]*SSLCachePortFilename"` = "" && $TYPE = "main" && `cat $CONF_FILE|grep -wi "^[[:space:]]*SSLCacheDisable"` = "" ]]; then
      if [[  $DETAILS == "true" || $DEBUG == "true" ]]; then 
         echo "      Error: For IHS Service Instances with SSL enabled and SSLCache enabled, SSLCachePortFilename must be defined"
      fi
      RETURN_CODE=1
   fi
   for SSLCACHEPORT in `cat $CONF_FILE|grep -wi "^[[:space:]]*SSLCachePortFilename"| awk '{print $NF}'`; do
      if [[ $TYPE = "include" ]]; then
         if [[  $DETAILS == "true" || $DEBUG == "true" ]]; then
            echo "      Error: Parameter SSLCachePortFilename not allowed in Include files"
         fi
         RETURN_CODE=1
      fi
      SSLCACHEPORTPATH=${SSLCACHEPORT%/*}
      if [[ $SSLCACHEPORTPATH != "/logs/${SITETAG}" && $TYPE = "main" ]]; then
         if [[  $DETAILS == "true" || $DEBUG == "true" ]]; then
            echo "      Error: SSLCachePortFilename $SSLCACHEPORT"
            echo "               must be placed in the log directory of the site"
         fi
         RETURN_CODE=1
      fi
   done

   ####################################################
   #check Custom Log
   ####################################################
   for CUSTOMLOG in `cat $CONF_FILE|grep -wi "^[[:space:]]*CustomLog"|awk '{for(i=1;i<=NF;i++) {if($i ~ /-logroot/) {print $(i+1)}}}' | sort | uniq`; do
      if [[ $DEBUG == "true" ]]; then
         echo "      CustomLog:$CUSTOMLOG"
      fi
      CUSTOMLOGNAME=`echo $CUSTOMLOG|awk -F/ '{print $NF}'`
      CUSTOMLOGDIR=${CUSTOMLOG%${CUSTOMLOGNAME}}
      CUSTOMLOGDIR=${CUSTOMLOGDIR%\/}
      if [[ $DEBUG == "true" ]]; then
         echo "      CustomLog Directory:$CUSTOMLOGDIR"
      fi
      if [[ ! -d $CUSTOMLOGDIR ]]; then
         if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
            echo "      Error: CustomLog Directory $CUSTOMLOGDIR"
            echo "               does not exist"
         fi
         RETURN_CODE=1
      fi
   done 

   ###################################################
   #check Error Log
   ###################################################
   for ERRORLOG in `cat $CONF_FILE|grep -wi "^[[:space:]]*ErrorLog"|awk '{for(i=1;i<=NF;i++) {if($i ~ /-logroot/) {print $(i+1)}}}' | sort | uniq`; do
      if [[ $DEBUG == "true" ]]; then
         echo "      ErrorLog:$ERRORLOG"
      fi
      ERRORLOGNAME=`echo $ERRORLOG|awk -F/ '{print $NF}'`
      ERRORLOGDIR=${ERRORLOG%${ERRORLOGNAME}}
      ERRORLOGDIR=${ERRORLOGDIR%\/}
      if [[ $DEBUG == "true" ]]; then
         echo "      ErrorLog Directory:$ERRORLOGDIR"
      fi
      if [[ ! -d $ERRORLOGDIR ]]; then
         if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
            echo "      Error: ErrorLog Directory $ERRORLOGDIR"
            echo "               does not exist"
         fi
         RETURN_CODE=1
      fi
   done 

   #######################################################
   # Return Code
   #######################################################
   return $RETURN_CODE
}

checkConfFile(){
   typeset STATUS_CODE=0 MAIN_STATUS_CODE=0 INCLUDE_STATUS_CODE=0 
 
   #######################################################
   #check config file httpd_conf
   #######################################################
   if [[ $SITETAG == HTTPServer* ]]; then
      HTTPD_CONF=/projects/${SITETAG}/conf/httpd.conf
   else
      HTTPD_CONF=/projects/${SITETAG}/conf/${SITETAG}.conf
   fi
   if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
      echo "  Checking Main Site Config File"
      echo "    $HTTPD_CONF"
   fi
   if [[ -f $HTTPD_CONF ]]; then
      checkSingleConfFile $HTTPD_CONF main
      MAIN_STATUS_CODE=$?
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
         if [[ $MAIN_STATUS_CODE -eq 0 ]]; then
            echo ""
            echo "  ################################################"
            print "  #### \c"
            ${LIB_HOME}/ihs/bin/highlight.pl " Verification of Main Config Completed " GOLDEN_SUM
            print "####"
            echo "  ################################################"
            echo ""
         else
            echo ""
            echo "  ###############################################"
            print "  #### \c"
            ${LIB_HOME}/ihs/bin/highlight.pl "  Verification of Main Config Failed   " ERROR_SUM
            print "####"
            echo "  ###############################################"
            echo ""
         fi
      fi
   else
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
         echo "      Error: Main Site Config does not exist"
         echo "      Check Failed"
         echo ""
         echo "  ###############################################"
         print "  #### \c"
         ${LIB_HOME}/ihs/bin/highlight.pl "  Verification of Main Config Failed   " ERROR_SUM
         print "####"
         echo "  ###############################################"
         echo ""
      fi
      STATUS_CODE=1
      return $STATUS_CODE
   fi

   #################################################
   #check include config file
   #################################################

   if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
      echo "  Checking Included Config Files"
   fi
   for INCLUDE in `grep -wi "^[[:space:]]*include" $HTTPD_CONF |grep -vi .*listen.* | awk {'print $2'} | tr -d \" | sort | uniq`; do
      if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
         echo "    ${SEQUENCE}: $INCLUDE"
         SEQUENCE=`expr $SEQUENCE + 1`
      fi
      if [[ -f $INCLUDE ]]; then
         checkSingleConfFile $INCLUDE include 
         INCLUDE_STATUS_CODE=$?
         if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
            echo ""
            echo "  #####################################################"
            if [[ $INCLUDE_STATUS_CODE -eq 0 ]]; then
               print "  ####\c"
               ${LIB_HOME}/ihs/bin/highlight.pl "  Verification of Include Config Completed   " GOLDEN_SUM
               print "####"
            else
               print "  ####\c"
               ${LIB_HOME}/ihs/bin/highlight.pl "    Verification of Include Config Failed    " ERROR_SUM
               print "####"
            fi
            echo "  #####################################################"
            echo ""
         fi
      else
         if [[ $DETAILS == "true" || $DEBUG == "true" ]]; then
            echo "      Error: Include file $INCLUDE"
            echo "               does not exist"
            echo ""
            echo "  #####################################################"
            print "  ####\c"
            ${LIB_HOME}/ihs/bin/highlight.pl "    Verification of Include Config Failed    " ERROR_SUM
            print "####"
            echo "  #####################################################"
            echo ""
         fi
         INCLUDE_STATUS_CODE=1
      fi
   done
   if [[ $INCLUDE == "" && ( $DETAILS == "true" || $DEBUG == "true" ) ]]; then
      echo "    No include config files found in main config"
      echo ""
      echo "  #####################################################"
      print "  ####\c"
      ${LIB_HOME}/ihs/bin/highlight.pl "  Verification of Include Config Completed   " GOLDEN_SUM
      print "####"
      echo "  #####################################################"
      echo ""
   fi
   STATUS_CODE=$(( MAIN_STATUS_CODE + INCLUDE_STATUS_CODE ))
   return $STATUS_CODE
}

#######################################################
#
# main function
#
#######################################################

${LIB_HOME}/ihs/bin/highlight.pl  "Performing IHS Advanced Config File Verification -->" SUBHEADER; echo
echo ""
checkConfFile
RETURN_CODE=$?
echo "  ////////////////////////////////"
if [[ $RETURN_CODE -ne 0 ]]; then
   print "  ////\c"
   ${LIB_HOME}/ihs/bin/highlight.pl "  Verification Failed   " ERROR
   print "////"
   EXIT_CODE=2
else
   print "  ////\c"
   ${LIB_HOME}/ihs/bin/highlight.pl " Verification Completed " GOLDEN
   print "////"
   EXIT_CODE=0
fi
echo "  ////////////////////////////////"
echo ""
exit $EXIT_CODE
