#!/bin/ksh

####################################################################
#
#  verify_versions_installed.sh -- Displays all versions of detected
#          installed ihs related software
#
#-------------------------------------------------------------------
#
#  Todd Stephens - 8/24/07 - Initial creation
#
####################################################################

echo "               Summary of installed IHS products"
echo "------------------------------------------------------------------"
if [[ -h /etc/apachectl ]]; then
   HTTP=`ls -al /etc/apachectl | cut -d">" -f2 | cut  -d"/" -f3`
   IHSDIR=/usr/${HTTP}
   if [[ -d $IHSDIR ]]; then
      echo "IHS installed in $IHSDIR"
      FIXLEVEL=`cat ${IHSDIR}/version.signature | awk '{print $4}'`
      echo "IHS version is $FIXLEVEL"
      SDKVERSION=`${IHSDIR}/java/jre/bin/java -fullversion 2>&1`
      echo "SDK version is ${SDKVERSION}"
   else
      echo "No IHS install detected on this node"
      exit 2
   fi
else
   echo "IHS is not installed or not installed properly on this node"
   exit 1
fi

if [[ -d ${IHSDIR}/UpdateInstaller ]]; then
   FIXLEVEL=`cat ${IHSDIR}/UpdateInstaller/version.txt| grep Version: | awk {'print $2'}`
   echo "UpdateInstaller version is $FIXLEVEL"
else
   echo "No UpdateInstaller installation detected"
fi

if [[ -d ${IHSDIR}/Plugins ]]; then
   FULLVER=`grep "<version>" ${IHSDIR}/Plugins/properties/version/PLG.product | cut -d">" -f2 | cut -d"<" -f1`
   echo "Plugin version is ${FULLVER}"
else
   echo "No Plugin installation detected"
fi
echo "------------------------------------------------------------------"
echo ""
echo "Executing httpd -v command"
. ${IHSDIR}/bin/envvars
${IHSDIR}/bin/httpd -v
echo ""
