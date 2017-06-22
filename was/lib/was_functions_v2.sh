#!/bin/ksh

function was_plugin_version_61
{
   typeset FULVER BITS PLUGINROOT=$1
   typeset -l OUTPUT=$2

   if [[ $PLUGINROOT == "" ]]; then
      echo "Function was_plugin_version_61 needs PLUGINROOT defined"
      exit 1
   fi

   if [[ -f ${PLUGINROOT}/bin/mod_was_ap20_http.so ]]; then
      if [[ $OUTPUT != "short" ]]; then
         PLUGINDIR=${PLUGINROOT:##*/}
         echo "Location: $PLUGINDIR"
      fi
      if [[ -f ${PLUGINROOT}/uninstall/version.txt ]]; then
         BITS=`cat ${PLUGINROOT}/uninstall/version.txt | grep Architecture | awk -F : '{print substr($2, length($2) - 1, length($2))}'`
      fi
      if [[ -f ${PLUGINROOT}/properties/version/PLG.product ]]; then
         FULLVER=`grep "<version>" ${PLUGINROOT}/properties/version/PLG.product | cut -d">" -f2 | cut -d"<" -f1`
         if [[ ( $BITS == "32" || $BITS == "64" ) && $OUTPUT != "short" ]]; then
            echo "Installed from a $BITS Bit Supplement"
         fi
         echo "Plugin version is ${FULLVER}"
      else
         echo "Can not determine WAS Plugin version"
         return 2
      fi
   else
      echo "WAS Plugin is not installed"
      return 2
   fi
}

function was_plugin_version_70
{
   typeset FULVER BITS PLUGINROOT=$1
   typeset -l OUTPUT=$2

   if [[ $PLUGINROOT == "" ]]; then
      echo "Function was_plugin_version_70 needs PLUGINROOT defined"
      exit 1
   fi

   if [[ -f ${PLUGINROOT}/bin/mod_was_ap22_http.so ]]; then
      if [[ $OUTPUT != "short" ]]; then
         PLUGINDIR=${PLUGINROOT:##*/}
         echo "Location: $PLUGINDIR"
      fi
      if [[ -f ${PLUGINROOT}/uninstall/version.txt ]]; then
         BITS=`cat ${PLUGINROOT}/uninstall/version.txt | grep Architecture | awk -F : '{print substr($2, length($2) - 1, length($2))}'`
      fi
      if [[ -f ${PLUGINROOT}/properties/version/PLG.product ]]; then
         FULLVER=`grep "<version>" ${PLUGINROOT}/properties/version/PLG.product | cut -d">" -f2 | cut -d"<" -f1`
         if [[ ( $BITS == "32" || $BITS == "64" ) && $OUTPUT != "short" ]]; then
            echo "Installed from a $BITS Bit Supplement"
         fi
         echo "Plugin version is ${FULLVER}"
      else
         echo "Can not determine WAS Plugin version"
         return 2
      fi
   else
      echo "WAS Plugin is not installed"
      return 2
   fi
}

was_plugin_version_85 ()
{
   typeset FULVER BITS PLUGINROOT=$1
   typeset -l OUTPUT=$2

   if [[ $PLUGINROOT == "" ]]; then
      echo "Function was_plugin_version_85 needs PLUGINROOT defined"
      exit 1
   fi

   if [[ -f ${PLUGINROOT}/bin/64bits/mod_was_ap22_http.so ]]; then      
      if [[ -f ${PLUGINROOT}/properties/version/PLG.product ]]; then
         FULLVER=`grep "<version>" ${PLUGINROOT}/properties/version/PLG.product | cut -d">" -f2 | cut -d"<" -f1`         
         echo "Plugin version is ${FULLVER}"
      else
         echo "Can not determine WAS Plugin version"
         return 2
      fi
   else
      echo "WAS Plugin is not installed"
      return 2
   fi
}

function was_plugin_sdk_version_61
{
   typeset FIXLEVEL PLUGINROOT=$1

   if [[ $PLUGINROOT == "" ]]; then
      echo "Function was_plugin_sdk_version_61 needs PLUGINROOT defined"
      exit 1
   fi

   if [[ -f ${PLUGINROOT}/java/jre/bin/java ]]; then
      FIXLEVEL=`${PLUGINROOT}/java/jre/bin/java -fullversion 2>&1`
      echo "WAS Plugin SDK version is $FIXLEVEL"
   else
      echo "WAS Plugin SDK is not installed"
      return 2
   fi
}

function was_plugin_sdk_version_70
{
   typeset FIXLEVEL PLUGINROOT=$1

   if [[ $PLUGINROOT == "" ]]; then
      echo "Function was_plugin_sdk_version_61 needs PLUGINROOT defined"
      exit 1
   fi

   if [[ -f ${PLUGINROOT}/java/jre/bin/java ]]; then
      FIXLEVEL=`${PLUGINROOT}/java/jre/bin/java -fullversion 2>&1`
      echo "WAS Plugin SDK version is $FIXLEVEL"
   else
      echo "WAS Plugin SDK is not installed"
      return 2
   fi
}

was_plugin_sdk_version_85 ()
{
   typeset FIXLEVEL PLUGINROOT=$1

   if [[ $PLUGINROOT == "" ]]; then
      echo "Function was_plugin_sdk_version_85 needs PLUGINROOT defined"
      exit 1
   fi

   if [[ -f ${PLUGINROOT}/java/jre/bin/java ]]; then
      FIXLEVEL=`${PLUGINROOT}/java/jre/bin/java -fullversion 2>&1`
      echo "WAS Plugin SDK version is $FIXLEVEL"
   else
      echo "WAS Plugin SDK is not installed"
      return 2
   fi
}
