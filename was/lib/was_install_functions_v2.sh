#!/bin/ksh

function error_message_plug
{
   typeset CODE=$1

   if [[ $CODE == "" ]]; then
      echo "Function error_message needs CODE defined"
      echo "Setting it to default of 2"
      echo ""
      CODE=2
   fi

   echo "/////////////////////////////////////////////////////////////////"
   printf "******      Installation of WAS Plugin version $FULLVERSION"
   echo "      *******"
   echo "******     failed to complete due to errors.  Review      *******"
   echo "******         script output for further details          *******"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit $CODE
}

function was_plugin_uninstall_61
{
   typeset PLUGDESTDIR=$1 LASTLINES WAS_PLUGIN=0 

   if [[ $PLUGDESTDIR == "" ]]; then
      echo "Function was_plugin_uninstall_61 needs PLUGDESTDIR defined"
      exit 1
   fi

   if [[ -d ${PLUGDESTDIR} ]]; then
      if [[ -f ${PLUGDESTDIR}/bin/mod_was_ap20_http.so ]]; then
         echo "Previous WAS Plugin install detected at $PLUGDESTDIR"
         if [[ -f ${PLUGDESTDIR}/uninstall/uninstall ]]; then
            if [[ -f ${PLUGDESTDIR}/logs/uninstall/log.txt ]]; then
               echo "    A previous WAS Plugin uninstall log detected"
               echo "      Removing"
               rm ${PLUGDESTDIR}/logs/uninstall/*
               if [[ $? -gt 0 ]]; then
                  echo "    Removal of previous WAS Plugin uninstall logs"
                  echo "      Failed"
                  return 3
               fi
            fi
            echo "    Running WAS Plugin uninstall script"
            echo "    Tail ${PLUGDESTDIR}/logs/uninstall/log.txt for uninstall details and progress"
            ${PLUGDESTDIR}/uninstall/uninstall -silent
            if [[ -f ${PLUGDESTDIR}/logs/uninstall/log.txt ]]; then
               LASTLINES=`tail -3 ${PLUGDESTDIR}/logs/uninstall/log.txt`
               if [[ "$LASTLINES" != "" ]]; then
                  echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
                  if [[ $? -eq 0 ]]; then
                     echo "    WAS Plugin uninstall Successful"
                     WAS_PLUGIN=1
                  else
                     echo "    WAS Plugin uninstall Failed"
                     echo "    Last few lines of install log contain:"
                     echo "$LASTLINES"
                     echo ""
                     echo "    Please check install log for further details"
                     return 3
                  fi
               else
                  echo "    WAS Plugin uninstall log is empty"
                  echo "    WAS Plugin uninstall Failed"
                  return 3
               fi
            else
               echo "    Failed to find WAS Plugin uninstall log"
               echo "    WAS Plugin uninstall Failed"
               return 3
            fi
         else
            echo "No WAS Plugin uninstall program exist in"
            echo "    ${PLUGDESTDIR}"
            echo "WAS Plugin uninstall Failed"
            return 3
         fi
      fi
      if [[ -f ${PLUGDESTDIR}/bin/mod_was_ap20_http.so ]]; then
         echo "    The attempt at uninstalling the WAS Plugin"
         echo "      Failed"
         return 2
      else
         if [[ $WAS_PLUGIN -eq 0 ]]; then
            echo "Even though ${PLUGDESTDIR} exist"
            echo "  no viable WAS Plugin install detected"
            echo "    Continuing ................."
            echo ""
         fi
         cd /tmp
         echo "    Removing plugin dir ${PLUGDESTDIR}"
         rm -r ${PLUGDESTDIR}
         if [[ $? -gt 0 ]]; then
            echo "    Removal of WAS Plugin directory"
            echo "      Failed"
            return 3
         fi
      fi
   fi
}

function was_plugin_uninstall_70
{
   typeset PLUGDESTDIR=$1 LASTLINES WAS_PLUGIN=0 

   if [[ $PLUGDESTDIR == "" ]]; then
      echo "Function was_plugin_uninstall_70 needs PLUGDESTDIR defined"
      exit 1
   fi

   if [[ -d ${PLUGDESTDIR} ]]; then
      if [[ -f ${PLUGDESTDIR}/bin/mod_was_ap22_http.so ]]; then
         echo "Previous WAS Plugin install detected at $PLUGDESTDIR"
         if [[ -f ${PLUGDESTDIR}/uninstall/uninstall ]]; then
            if [[ -f ${PLUGDESTDIR}/logs/uninstall/log.txt ]]; then
               echo "    A previous WAS Plugin uninstall log detected"
               echo "      Removing"
               rm ${PLUGDESTDIR}/logs/uninstall/*
               if [[ $? -gt 0 ]]; then
                  echo "    Removal of previous WAS Plugin uninstall logs"
                  echo "      Failed"
                  return 3
               fi
            fi
            echo "    Running WAS Plugin uninstall script"
            echo "    Tail ${PLUGDESTDIR}/logs/uninstall/log.txt for uninstall details and progress"
            ${PLUGDESTDIR}/uninstall/uninstall -silent
            if [[ -f ${PLUGDESTDIR}/logs/uninstall/log.txt ]]; then
               LASTLINES=`tail -3 ${PLUGDESTDIR}/logs/uninstall/log.txt`
               if [[ "$LASTLINES" != "" ]]; then
                  echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
                  if [[ $? -eq 0 ]]; then
                     echo "    WAS Plugin uninstall Successful"
                     WAS_PLUGIN=1
                  else
                     echo "    WAS Plugin uninstall Failed"
                     echo "    Last few lines of install log contain:"
                     echo "$LASTLINES"
                     echo ""
                     echo "    Please check install log for further details"
                     return 3
                  fi
               else
                  echo "    WAS Plugin uninstall log is empty"
                  echo "    WAS Plugin uninstall Failed"
                  return 3
               fi
            else
               echo "    Failed to find WAS Plugin uninstall log"
               echo "    WAS Plugin uninstall Failed"
               return 3
            fi
         else
            echo "No WAS Plugin uninstall program exist in"
            echo "    ${PLUGDESTDIR}"
            echo "WAS Plugin uninstall Failed"
            return 3
         fi
      fi
      if [[ -f ${PLUGDESTDIR}/bin/mod_was_ap22_http.so ]]; then
         echo "    The attempt at uninstalling the WAS Plugin"
         echo "      Failed"
         return 2
      else
         if [[ $WAS_PLUGIN -eq 0 ]]; then
            echo "Even though ${PLUGDESTDIR} exist"
            echo "  no viable WAS Plugin install detected"
            echo "    Continuing ................."
            echo ""
         fi
         cd /tmp
         echo "    Removing plugin dir ${PLUGDESTDIR}"
         rm -r ${PLUGDESTDIR}
         if [[ $? -gt 0 ]]; then
            echo "    Removal of WAS Plugin directory"
            echo "      Failed"
            return 3
         fi
      fi
   fi
}

function was_plugin_clean_logs_61
{
   typeset PLUGLOGDIR=$1 NOTHING_FOUND_INSTALL=0 NOTHING_FOUND_UPDATE=0

   if [[ $PLUGLOGDIR == "" ]]; then
      echo "Function was_plugin_clean_logs_61 needs PLUGLOGDIR defined"
      exit 1
   fi

   if [[ -d ${PLUGLOGDIR} ]]; then
      if [[ `ls ${PLUGLOGDIR} | egrep -v ".*.log|uninstall"` != "" ]]; then
         echo "Previous Plugin Log Directory detected at ${PLUGLOGDIR}"
         if [[ -d ${PLUGLOGDIR}/install ]]; then
            echo "    Cleaning WAS Plugin install logs"
            rm -r ${PLUGLOGDIR}/install
            if [[ $? -gt 0 ]]; then
               echo "    Removal of WAS Plugin install logs"
               echo "      Failed"
               return 3
            fi
            NOTHING_FOUND_INSTALL=0
         else
            NOTHING_FOUND_INSTALL=1
         fi
         if [[ -d ${PLUGLOGDIR}/update ]]; then
            echo "    Cleaning WAS Plugin update logs"
            rm -r ${PLUGLOGDIR}/update
            if [[ $? -gt 0 ]]; then
               echo "    Removal of WAS Plugin update logs"
               echo "      Failed"
               return 3
            fi
            NOTHING_FOUND_UPDATE=0
         else
            NOTHING_FOUND_UPDATE=1
         fi
         echo ""
      else
         NOTHING_FOUND_INSTALL=1
         NOTHING_FOUND_UPDATE=1
      fi
   else
      NOTHING_FOUND_INSTALL=1
      NOTHING_FOUND_UPDATE=1
   fi

   if [[ $NOTHING_FOUND_INSTALL -eq 1 && $NOTHING_FOUND_UPDATE -eq 1 ]]; then
      return 100
   fi
}

function was_plugin_clean_logs_70
{
   typeset PLUGLOGDIR=$1 NOTHING_FOUND_INSTALL=0 NOTHING_FOUND_UPDATE=0

   if [[ $PLUGLOGDIR == "" ]]; then
      echo "Function was_plugin_clean_logs_70 needs PLUGLOGDIR defined"
      exit 1
   fi

   if [[ -d ${PLUGLOGDIR} ]]; then
      if [[ `ls ${PLUGLOGDIR} | egrep -v ".*.log|uninstall"` != ""  ]]; then
         echo "Previous Plugin Log Directory detected at ${PLUGLOGDIR}"
         if [[ -d ${PLUGLOGDIR}/install ]]; then
            echo "    Cleaning WAS Plugin install logs"
            rm -r ${PLUGLOGDIR}/install
            if [[ $? -gt 0 ]]; then
               echo "    Removal of WAS Plugin install logs"
               echo "      Failed"
               return 3
            fi
            NOTHING_FOUND_INSTALL=0
         else
            NOTHING_FOUND_INSTALL=1
         fi
         if [[ -d ${PLUGLOGDIR}/update ]]; then
            echo "    Cleaning WAS Plugin update logs"
            rm -r ${PLUGLOGDIR}/update
            if [[ $? -gt 0 ]]; then
               echo "    Removal of WAS Plugin update logs"
               echo "      Failed"
               return 3
            fi
            NOTHING_FOUND_UPDATE=0
         else
            NOTHING_FOUND_UPDATE=1
         fi
         echo ""
      else
         NOTHING_FOUND_INSTALL=1
         NOTHING_FOUND_UPDATE=1
      fi
   else
      NOTHING_FOUND_INSTALL=1
      NOTHING_FOUND_UPDATE=1
   fi

   if [[ $NOTHING_FOUND_INSTALL -eq 1 && $NOTHING_FOUND_UPDATE -eq 1 ]]; then
      return 100
   fi
}

function was_plugin_clean_logs_85
{
   typeset PLUGLOGDIR=$1 NOTHING_FOUND_INSTALL=0 NOTHING_FOUND_UPDATE=0

   if [[ $PLUGLOGDIR == "" ]]; then
      echo "Function was_plugin_clean_logs_85 needs PLUGLOGDIR defined"
      exit 1
   fi

   if [[ -d ${PLUGLOGDIR} ]]; then
      if [[ `ls ${PLUGLOGDIR} | egrep -v ".*.log|uninstall"` != ""  ]]; then
         echo "Previous Plugin Log Directory detected at ${PLUGLOGDIR}"
         if [[ -d ${PLUGLOGDIR}/install ]]; then
            echo "    Cleaning WAS Plugin install logs"
            rm -r ${PLUGLOGDIR}/install
            if [[ $? -gt 0 ]]; then
               echo "    Removal of WAS Plugin install logs"
               echo "      Failed"
               return 3
            fi
            NOTHING_FOUND_INSTALL=0
         else
            NOTHING_FOUND_INSTALL=1
         fi
         if [[ -d ${PLUGLOGDIR}/update ]]; then
            echo "    Cleaning WAS Plugin update logs"
            rm -r ${PLUGLOGDIR}/update
            if [[ $? -gt 0 ]]; then
               echo "    Removal of WAS Plugin update logs"
               echo "      Failed"
               return 3
            fi
            NOTHING_FOUND_UPDATE=0
         else
            NOTHING_FOUND_UPDATE=1
         fi
         echo ""
      else
         NOTHING_FOUND_INSTALL=1
         NOTHING_FOUND_UPDATE=1
      fi
   else
      NOTHING_FOUND_INSTALL=1
      NOTHING_FOUND_UPDATE=1
   fi

   if [[ $NOTHING_FOUND_INSTALL -eq 1 && $NOTHING_FOUND_UPDATE -eq 1 ]]; then
      return 100
   fi
}

function install_plugin_fixes_61
{
   typeset FULLVERSION=$1 IHSBASELEVEL=$2 IHSDIR=$3 PLUGDESTDIR=$4 BITS=$5 TOOLSDIR=$6 SLEEP=$7 SKIPUPDATES=$8 PACKAGES=$9 WASSRCDIR SRCDIR RESPDIR FIXRESPFILE FIXPKG FIXTYPE FIXPACKID LIST SPLITPACKAGES SLEEP LINENUM CURFIXLEVEL NEWFIXLEVEL SDKVERSION ERROR LASTLINES CHMOD CHMODR XARGS FS_TABLE 
   typeset BASELEVEL=`echo $FULLVERSION | cut -c1,2`

   if [[ $FULLVERSION == "" ]]; then
      echo "Function install_plugin_fixes_61 needs FULLVERSION defined"
      exit 1
   fi

   if [[ $IHSBASELEVEL == "" ]]; then
      echo "Function install_plugin_fixes_61 needs IHSBASELEVEL defined"
      exit 1
   fi

   if [[ $IHSDIR == "" ]]; then
      echo "Function install_plugin_fixes_61 needs IHSDIR defined"
      exit 1
   fi

   if [[ $PLUGDESTDIR == "" ]]; then
      echo "Function install_plugin_fixes_61 needs PLUGDESTDIR defined"
      exit 1
   fi

   if [[ $BITS == "" ]]; then
      echo "Function install_plugin_fixes_61 needs BITS defined"
      exit 1
   fi

   if [[ $TOOLSDIR == "" ]]; then
      echo "Function install_plugin_fixes_61 needs TOOLSDIR defined"
      exit 1
   fi

   if [[ $SLEEP == "" ]]; then
      echo "Function install_plugin_fixes_61 needs SLEEP defined"
      exit 1
   fi

   if [[ $SKIPUPDATES == "" ]]; then
      echo "Function install_plugin_fixes_61 needs SKIPUPDATES defined"
      exit 1
   fi

   if [[ $PACKAGES == "" ]]; then
      echo "Function install_plugin_fixes_61 needs PACKAGES defined"
      echo "Specify \"all\" to install all packages for this fixlevel"
      exit 1
   fi

   echo "---------------------------------------------------------------"
   echo "                Install WAS Plugin Fixpacks"
   echo "---------------------------------------------------------------"
   echo ""

   # Verify IHS is installed or exit if not
   if [[ ! -f ${IHSDIR}/bin/httpd ]]; then
      echo "Base IHS install not detected"
      echo "Skipping updates"
      echo ""
      return 1
   fi

   # Verify WAS Plugin is installed or exit if not
   if [[ ! -f ${PLUGDESTDIR}/bin/mod_was_ap20_http.so ]]; then
      echo "WAS Plugin install not detected"
      echo "Skipping updates"
      echo ""
      return 1
   fi

   if [[ $SKIPUPDATES -eq 1 ]]; then
      echo "Install of UpdateInstaller required to install fixes"
      echo "  Failed"
      echo "Skipping updates"
      echo ""
      return 1
   fi

   os_specific_parameters_61 $BITS plug
   function_error_check os_specific_parameters_61 plug

   SRCDIR="${WASSRCDIR}/supplements/fixes/${FULLVERSION}/plugin"
   RESPDIR=${TOOLSDIR}/was/responsefiles
   FIXRESPFILE="v${BASELEVEL}silent.plugin.fixes.script"

   if [[ -d ${SRCDIR} ]]; then
      cd ${SRCDIR}
   else
      echo "Image fixes directory for WAS Plugin fullversion ${FULLVERSION}"
      echo "  does not exist"
      echo "Skipping updates"
      echo ""
      return 1
   fi

   if [[ $PACKAGES == "all" ]]; then
      ls *.pak > /dev/null 2>&1
      if [[ $? -eq 0 ]]; then
         PACKAGE_LIST=`ls *.pak`
      fi
   else
      SPLITPACKAGES=`echo ${PACKAGES} | sed 's/\:/\\\n/g'`
      PACKAGE_LIST=`echo ${SPLITPACKAGES}`
      for ITEM in $PACKAGE_LIST; do
         ls $ITEM > /dev/null 2>&1
         if [[ $? -ne 0 ]]; then
            echo "Package $ITEM does not exist at"
            echo "  ${SRCDIR}"
            echo "Check the requested fixes list"
            echo "Skipping updates"
            echo ""
            return 1
         fi
      done
   fi

   for FIXPKG in $PACKAGE_LIST
   do
     FIXPACKID=${FIXPKG%.*}
     if [[ -f ${PLUGDESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt ]];
then
        LASTLINES=`tail -3 ${PLUGDESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt`
        if [[ "$LASTLINES" != "" ]]; then
           echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
           if [[ $? -eq 0 ]]; then
              FIXPKG=""
           fi
        fi
     fi
     if [[ ${FIXPKG} != "" ]]; then
        LIST_TMP="${LIST_TMP}${FIXPKG}\n"
     fi
   done
   if [[ $LIST_TMP != "" ]]; then
      LIST=`echo $LIST_TMP | grep -n pak |sed 's/^\([0-9]*\):/\1.- /'`
   else
      if [[ $SPLITPACKAGES != "" ]]; then
         echo "All requested fixes are already successfully installed"
         echo "  Aborting Fixpack install"
      else
         echo "All fixes required of WAS Plugin version $FULLVERSION"
         echo "  are successfully installed"
         echo "  Aborting Fixpack install"
      fi
      echo ""
      return 200
   fi

   if [[ ! -f ${IHSDIR}/UpdateInstaller/update.sh ]]; then
      echo "Cannot find ${IHSDIR}/UpdateInstaller/update.sh"
      echo "Skipping updates"
      echo ""
      return 1
   elif [[ $LIST != "" ]]; then
      echo "Applying fixpacks in this order"
      echo "  to base WAS Plugin 61"
      echo "  located in $PLUGDESTDIR"
      echo "  to obtain WAS Plugin fixlevel $FULLVERSION"
      echo "  in $SLEEP seconds"
      echo "    Ctrl-C to suspend"
      echo ""
      echo "$LIST"
      echo ""
      install_timer $SLEEP
      function_error_check install_timer plug

      LINENUM=1
      echo "Beginning fixpack installation process"
      echo "################################################################################"
      echo ""
      for FIXPKG in $LIST; do
         if [[ $FIXPKG == *.pak ]]; then
            echo "${LINENUM}) ${FIXPKG%.*}"
            echo "--------------------------------------------------------------------------------"
            echo ${FIXPKG} | grep -q SDK
            if [[ $? -eq 0 ]]; then
               FIXTYPE=SDK
            else
               echo ${FIXPKG} | grep -q IFP
               if [[ $? -eq 0 ]]; then
                  FIXTYPE=IF
               else
                  FIXTYPE=`echo $FIXPKG | cut  -d'-' -f5 | cut -c 1,2`
               fi
            fi
            if [[ $FIXTYPE != "SDK" && $FIXTYPE != "IF" && $FIXTYPE != "FP" && $FIXTYPE != "RP" ]]; then
               echo "$FIXPKG "
               echo "    is not a supported FIXTYPE by this script"
               ERROR=1
               (( LINENUM = LINENUM + 1 ))
               echo ""
               continue
            fi
            if [[ ! -f ${RESPDIR}/${FIXRESPFILE} ]]; then
               echo "  File ${RESPDIR}/${FIXRESPFILE} does not exist"
               echo "  Use Tivoli SD tools to push ${TOOLSDIR}/ihs files to this server"
               echo ""
               return 2
            else
               if [[ $FIXPKG == *WS-PLG* ]]; then
                  CURFIXLEVEL=`grep "<version>" ${PLUGDESTDIR}/properties/version/PLG.product | cut -d">" -f2 | cut -d"<" -f1`
               fi
               FIXPACKID=${FIXPKG%.*}
               echo "    Installing fixpack $FIXPACKID"
               echo "    Tail ${PLUGDESTDIR}/log/update/${FIXPACKID}.install/updatelog.txt for installation details and progress"
               cp ${RESPDIR}/${FIXRESPFILE} /tmp/${FIXRESPFILE}
               if [[ $? -gt 0 ]]; then
                  echo "    Copying of response file to tmp dir"
                  echo "      Failed"
                  echo ""
                  return 3
               fi
               cd /tmp
               sed -e "s%maintenance.package=.*%maintenance.package=${SRCDIR}/${FIXPKG}%" ${FIXRESPFILE}  > ${FIXRESPFILE}.custom && mv ${FIXRESPFILE}.custom  ${FIXRESPFILE}
               if [[ $? -gt 0 ]]; then
                  echo "    Edit to response file for maintenance package id "
                  echo "      Failed"
                  echo ""
                  return 3
               fi
               sed -e "s%product.location=.*%product.location=${PLUGDESTDIR}%" ${FIXRESPFILE}  > ${FIXRESPFILE}.custom && mv ${FIXRESPFILE}.custom  $FIXRESPFILE
               if [[ $? -gt 0 ]]; then
                  echo "    Edit to response file for product location"
                  echo "      Failed"
                  echo ""
                  return 3
               fi
               #Install fix using created response file
               if [[ -f ${PLUGDESTDIR}/log/update/${FIXPACKID}.install/updatelog.txt ]]; then
                  echo "    A previous version of the install log for this fixpack was detected"
                  echo "        Removing"
                  rm ${PLUGDESTDIR}/log/update/${FIXPACKID}.install/*
                  if [[ $? -gt 0 ]]; then
                     echo "    Removal of previous version install logs"
                     echo "      Failed"
                     echo ""
                     return 3
                  fi
               fi
               ${IHSDIR}/UpdateInstaller/update.sh -options /tmp/${FIXRESPFILE} -silent
               case $FIXTYPE in
                  FP|RP)
                     NEWFIXLEVEL=`grep "<version>" ${PLUGDESTDIR}/properties/version/PLG.product | cut -d">" -f2 | cut -d"<" -f1`
                     if [[ $NEWFIXLEVEL == $CURFIXLEVEL ]]; then
                        echo "    WAS Plugin Version info has not updated."
                        echo "    WAS Plugin Fixpack install Failed"
                        echo "    Please check log file for errors"
                        ERROR=1
                     else
                        echo "    WAS Plugin Fix install Successful"
                        printf "    "
                        was_plugin_version_61 $PLUGDESTDIR short
                     fi
                  ;;
                  SDK)
                     if [[ -f ${PLUGDESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt ]]; then
                        LASTLINES=`tail -3 ${PLUGDESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt`
                        if [[ "$LASTLINES" != "" ]]; then
                           echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
                           if [[ $? -eq 0 ]]; then
                              echo "    SDK Fixpack install Successful"
                              printf "    "
                              was_plugin_sdk_version_61 $PLUGDESTDIR
                           else
                              echo "    SDK Fixpack install Failed"
                              echo "    Last few lines of install log contain:"
                              echo "$LASTLINES"
                              echo ""
                              echo "    Please check install log for further details"
                              ERROR=1
                           fi
                        else
                           echo "    SDK Fixpack install log is empty"
                           echo "    SDK Fixpack install Failed"
                           ERROR=1
                        fi
                     else
                        echo "    Failed to find SDK Fixpack install log"
                        echo "    SDK Fixpack install Failed"
                        ERROR=1
                     fi
                  ;;
                  IF)
                     if [[ -f ${PLUGDESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt ]]; then
                        LASTLINES=`tail -3 ${PLUGDESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt`
                        if [[ "$LASTLINES" != "" ]]; then
                           echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
                           if [[ $? -eq 0 ]]; then
                              echo "    Interim Fixpack install Successful"
                           else
                              echo "    Interim Fixpack install Failed"
                              echo "    Last few lines of install log contain:"
                              echo "$LASTLINES"
                              echo ""
                              echo "    Please check install log for further details"
                              ERROR=1
                           fi
                        else
                           echo "    Interim Fixpack install log is empty"
                           echo "    Interim Fixpack install Failed"
                           ERROR=1
                        fi
                     else
                        echo "    Failed to find Interim Fixpack install log"
                        echo "    Interim Fixpack install Failed"
                        ERROR=1
                     fi
                  ;;
               esac
            fi
            echo ""
            (( LINENUM = LINENUM + 1 ))
            stop_httpd_verification_$IHSBASELEVEL $IHSDIR $TOOLSDIR $SLEEP plug 4
            function_error_check stop_httpd_verification_$IHSBASELEVEL ihs
            echo ""
         fi
      done
      echo "################################################################################"
   else
      echo "No fixes found to apply in ${SRCDIR}"
      echo ""
      return 200
   fi

   if [[ $ERROR -gt 0 ]]; then
      return 2
   fi
}

function install_plugin_fixes_70
{
   typeset FULLVERSION=$1 IHSBASELEVEL=$2 IHSDIR=$3 PLUGDESTDIR=$4 BITS=$5 TOOLSDIR=$6 SLEEP=$7 SKIPUPDATES=$8 PACKAGES=$9 WASSRCDIR SRCDIR RESPDIR FIXRESPFILE FIXPKG FIXTYPE FIXPACKID LIST SPLITPACKAGES SLEEP LINENUM CURFIXLEVEL NEWFIXLEVEL SDKVERSION ERROR LASTLINES CHMOD CHMODR XARGS FS_TABLE 
   typeset BASELEVEL=`echo $FULLVERSION | cut -c1,2`

   if [[ $FULLVERSION == "" ]]; then
      echo "Function install_plugin_fixes_70 needs FULLVERSION defined"
      exit 1
   fi

   if [[ $IHSBASELEVEL == "" ]]; then
      echo "Function install_plugin_fixes_70 needs IHSBASELEVEL defined"
      exit 1
   fi

   if [[ $IHSDIR == "" ]]; then
      echo "Function install_plugin_fixes_70 needs IHSDIR defined"
      exit 1
   fi

   if [[ $PLUGDESTDIR == "" ]]; then
      echo "Function install_plugin_fixes_70 needs PLUGDESTDIR defined"
      exit 1
   fi

   if [[ $BITS == "" ]]; then
      echo "Function install_plugin_fixes_70 needs BITS defined"
      exit 1
   fi

   if [[ $TOOLSDIR == "" ]]; then
      echo "Function install_plugin_fixes_70 needs TOOLSDIR defined"
      exit 1
   fi

   if [[ $SLEEP == "" ]]; then
      echo "Function install_plugin_fixes_70 needs SLEEP defined"
      exit 1
   fi

   if [[ $SKIPUPDATES == "" ]]; then
      echo "Function install_plugin_fixes_70 needs SKIPUPDATES defined"
      exit 1
   fi

   if [[ $PACKAGES == "" ]]; then
      echo "Function install_plugin_fixes_70 needs PACKAGES defined"
      echo "Specify \"all\" to install all packages for this fixlevel"
      exit 1
   fi

   echo "---------------------------------------------------------------"
   echo "                Install WAS Plugin Fixpacks"
   echo "---------------------------------------------------------------"
   echo ""

   # Verify IHS is installed or exit if not
   if [[ ! -f ${IHSDIR}/bin/httpd ]]; then
      echo "Base IHS install not detected"
      echo "Skipping updates"
      echo ""
      return 1
   fi

   # Verify WAS Plugin is installed or exit if not
   if [[ ! -f ${PLUGDESTDIR}/bin/mod_was_ap22_http.so ]]; then
      echo "WAS Plugin install not detected"
      echo "Skipping updates"
      echo ""
      return 1
   fi

   if [[ $SKIPUPDATES -eq 1 ]]; then
      echo "Install of UpdateInstaller required to install fixes"
      echo "  Failed"
      echo "Skipping updates"
      echo ""
      return 1
   fi

   os_specific_parameters_70 $BITS plug
   function_error_check os_specific_parameters_70 plug

   SRCDIR="${WASSRCDIR}/supplements/fixes/${FULLVERSION}/plugin"
   RESPDIR=${TOOLSDIR}/was/responsefiles
   FIXRESPFILE="v${BASELEVEL}silent.plugin.fixes.script"

   if [[ -d ${SRCDIR} ]]; then
      cd ${SRCDIR}
   else
      echo "Image fixes directory for WAS Plugin fullversion ${FULLVERSION}"
      echo "  does not exist"
      echo "Skipping updates"
      echo ""
      return 1
   fi

   if [[ $PACKAGES == "all" ]]; then
      ls *.pak > /dev/null 2>&1
      if [[ $? -eq 0 ]]; then
         PACKAGE_LIST=`ls *.pak`
      fi
   else
      SPLITPACKAGES=`echo ${PACKAGES} | sed 's/\:/\\\n/g'`
      PACKAGE_LIST=`echo ${SPLITPACKAGES}`
      for ITEM in $PACKAGE_LIST; do
         ls $ITEM > /dev/null 2>&1
         if [[ $? -ne 0 ]]; then
            echo "Package $ITEM does not exist at"
            echo "  ${SRCDIR}"
            echo "Check the requested fixes list"
            echo "Skipping updates"
            echo ""
            return 1
         fi
      done
   fi

   for FIXPKG in $PACKAGE_LIST
   do
     FIXPACKID=${FIXPKG%.*}
     if [[ -f ${PLUGDESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt ]];
then
        LASTLINES=`tail -3 ${PLUGDESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt`
        if [[ "$LASTLINES" != "" ]]; then
           echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
           if [[ $? -eq 0 ]]; then
              FIXPKG=""
           fi
        fi
     fi
     if [[ ${FIXPKG} != "" ]]; then
        LIST_TMP="${LIST_TMP}${FIXPKG}\n"
     fi
   done
   if [[ $LIST_TMP != "" ]]; then
      LIST=`echo $LIST_TMP | grep -n pak |sed 's/^\([0-9]*\):/\1.- /'`
   else
      if [[ $SPLITPACKAGES != "" ]]; then
         echo "All requested fixes are already successfully installed"
         echo "  Aborting Fixpack install"
      else
         echo "All fixes required of WAS Plugin version $FULLVERSION"
         echo "  are successfully installed"
         echo "  Aborting Fixpack install"
      fi
      echo ""
      return 200
   fi

   if [[ ! -f ${IHSDIR}/UpdateInstaller/update.sh ]]; then
      echo "Cannot find ${IHSDIR}/UpdateInstaller/update.sh"
      echo "Skipping updates"
      echo ""
      return 1
   elif [[ $LIST != "" ]]; then
      echo "Applying fixpacks in this order"
      echo "  to base WAS Plugin 70"
      echo "  located in $PLUGDESTDIR"
      echo "  to obtain WAS Plugin fixlevel $FULLVERSION"
      echo "  in $SLEEP seconds"
      echo "    Ctrl-C to suspend"
      echo ""
      echo "$LIST"
      echo ""
      install_timer $SLEEP
      function_error_check install_timer plug

      LINENUM=1
      echo "Beginning fixpack installation process"
      echo "################################################################################"
      echo ""
      for FIXPKG in $LIST; do
         if [[ $FIXPKG == *.pak ]]; then
            echo "${LINENUM}) ${FIXPKG%.*}"
            echo "--------------------------------------------------------------------------------"
            echo ${FIXPKG} | grep -q SDK
            if [[ $? -eq 0 ]]; then
               FIXTYPE=SDK
            else
               echo ${FIXPKG} | grep -q IFP
               if [[ $? -eq 0 ]]; then
                  FIXTYPE=IF
               else
                  FIXTYPE=`echo $FIXPKG | cut  -d'-' -f5 | cut -c 1,2`
               fi
            fi
            if [[ $FIXTYPE != "SDK" && $FIXTYPE != "IF" && $FIXTYPE != "FP" && $FIXTYPE != "RP" ]]; then
               echo "$FIXPKG "
               echo "    is not a supported FIXTYPE by this script"
               ERROR=1
               (( LINENUM = LINENUM + 1 ))
               echo ""
               continue
            fi
            if [[ ! -f ${RESPDIR}/${FIXRESPFILE} ]]; then
               echo "  File ${RESPDIR}/${FIXRESPFILE} does not exist"
               echo "  Use Tivoli SD tools to push ${TOOLSDIR}/ihs files to this server"
               echo ""
               return 2
            else
               if [[ $FIXPKG == *WS-PLG* ]]; then
                  CURFIXLEVEL=`grep "<version>" ${PLUGDESTDIR}/properties/version/PLG.product | cut -d">" -f2 | cut -d"<" -f1`
               fi
               FIXPACKID=${FIXPKG%.*}
               echo "    Installing fixpack $FIXPACKID"
               echo "    Tail ${PLUGDESTDIR}/log/update/${FIXPACKID}.install/updatelog.txt for installation details and progress"
               cp ${RESPDIR}/${FIXRESPFILE} /tmp/${FIXRESPFILE}
               if [[ $? -gt 0 ]]; then
                  echo "    Copying of response file to tmp dir"
                  echo "      Failed"
                  echo ""
                  return 3
               fi
               cd /tmp
               sed -e "s%maintenance.package=.*%maintenance.package=${SRCDIR}/${FIXPKG}%" ${FIXRESPFILE}  > ${FIXRESPFILE}.custom && mv ${FIXRESPFILE}.custom  ${FIXRESPFILE}
               if [[ $? -gt 0 ]]; then
                  echo "    Edit to response file for maintenance package id "
                  echo "      Failed"
                  echo ""
                  return 3
               fi
               sed -e "s%product.location=.*%product.location=${PLUGDESTDIR}%" ${FIXRESPFILE}  > ${FIXRESPFILE}.custom && mv ${FIXRESPFILE}.custom  $FIXRESPFILE
               if [[ $? -gt 0 ]]; then
                  echo "    Edit to response file for product location"
                  echo "      Failed"
                  echo ""
                  return 3
               fi
               #Install fix using created response file
               if [[ -f ${PLUGDESTDIR}/log/update/${FIXPACKID}.install/updatelog.txt ]]; then
                  echo "    A previous version of the install log for this fixpack was detected"
                  echo "        Removing"
                  rm ${PLUGDESTDIR}/log/update/${FIXPACKID}.install/*
                  if [[ $? -gt 0 ]]; then
                     echo "    Removal of previous version install logs"
                     echo "      Failed"
                     echo ""
                     return 3
                  fi
               fi
               ${IHSDIR}/UpdateInstaller/update.sh -options /tmp/${FIXRESPFILE} -silent
               case $FIXTYPE in
                  FP|RP)
                     NEWFIXLEVEL=`grep "<version>" ${PLUGDESTDIR}/properties/version/PLG.product | cut -d">" -f2 | cut -d"<" -f1`
                     if [[ $NEWFIXLEVEL == $CURFIXLEVEL ]]; then
                        echo "    WAS Plugin Version info has not updated."
                        echo "    WAS Plugin Fixpack install Failed"
                        echo "    Please check log file for errors"
                        ERROR=1
                     else
                        echo "    WAS Plugin Fix install Successful"
                        printf "    "
                        was_plugin_version_61 $PLUGDESTDIR short
                     fi
                  ;;
                  SDK)
                     if [[ -f ${PLUGDESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt ]]; then
                        LASTLINES=`tail -3 ${PLUGDESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt`
                        if [[ "$LASTLINES" != "" ]]; then
                           echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
                           if [[ $? -eq 0 ]]; then
                              echo "    SDK Fixpack install Successful"
                              printf "    "
                              was_plugin_sdk_version_61 $PLUGDESTDIR
                           else
                              echo "    SDK Fixpack install Failed"
                              echo "    Last few lines of install log contain:"
                              echo "$LASTLINES"
                              echo ""
                              echo "    Please check install log for further details"
                              ERROR=1
                           fi
                        else
                           echo "    SDK Fixpack install log is empty"
                           echo "    SDK Fixpack install Failed"
                           ERROR=1
                        fi
                     else
                        echo "    Failed to find SDK Fixpack install log"
                        echo "    SDK Fixpack install Failed"
                        ERROR=1
                     fi
                  ;;
                  IF)
                     if [[ -f ${PLUGDESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt ]]; then
                        LASTLINES=`tail -3 ${PLUGDESTDIR}/logs/update/${FIXPACKID}.install/updatelog.txt`
                        if [[ "$LASTLINES" != "" ]]; then
                           echo $LASTLINES | grep INSTCONFSUCCESS > /dev/null
                           if [[ $? -eq 0 ]]; then
                              echo "    Interim Fixpack install Successful"
                           else
                              echo "    Interim Fixpack install Failed"
                              echo "    Last few lines of install log contain:"
                              echo "$LASTLINES"
                              echo ""
                              echo "    Please check install log for further details"
                              ERROR=1
                           fi
                        else
                           echo "    Interim Fixpack install log is empty"
                           echo "    Interim Fixpack install Failed"
                           ERROR=1
                        fi
                     else
                        echo "    Failed to find Interim Fixpack install log"
                        echo "    Interim Fixpack install Failed"
                        ERROR=1
                     fi
                  ;;
               esac
            fi
            echo ""
            (( LINENUM = LINENUM + 1 ))
            stop_httpd_verification_$IHSBASELEVEL $IHSDIR $TOOLSDIR $SLEEP plug 4
            function_error_check stop_httpd_verification_$IHSBASELEVEL ihs
            echo ""
         fi
      done
      echo "################################################################################"
   else
      echo "No fixes found to apply in ${SRCDIR}"
      echo ""
      return 200
   fi

   if [[ $ERROR -gt 0 ]]; then
      return 2
   fi
}

