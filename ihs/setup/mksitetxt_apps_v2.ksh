#!/usr/bin/ksh 

#
# mksitetxt_apps.ksh: Script to create site.txt for the specified event
#			and push to appropriate directory
#
# carolami 3/20/06:  added chown pubinst.apps to original mksitetxt.ksh
# todds    8/20/07:  Will continue by redoing this copy since our leader
#                    started this one
# todds    8/20/10:  Removed the dependancy on /etc/apachectl
# todds    9/14/10:  Added the code to handle cluster builds versus
#                        standalone builds
# todds   06/27/11:  Added code to determine serverroot and act accordingly

echo "Setting umask"
umask 002

# Default values
DESTDIR=""
EVENT=""
SITENAME=""
INSTALL_TYPE="cluster"

# Process command-line options
until [ -z "$1" ] ; do
   case $1 in
      type=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then INSTALL_TYPE=$VALUE; fi ;;
      sitetag=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then EVENT=$VALUE; fi ;;
      name=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SITENAME=$VALUE; fi ;;
      ihs_level=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then IHSLEVEL=$VALUE; fi ;;
      *)  print -u2 -- "#### Unknown argument: $1"
          print -u2 -- "#### Usage: ${0:##*/} [ sitetag = < site name > ]"
          print -u2 -- "####            [ name = < long site name > ]"
          print -u2 -- "####            [ type = < install type > ]"
          print -u2 -- "####            [ ihs_level = < ihs level of server > ]"
          print -u2 -- "#### ---------------------------------------------------------------------------"
          print  -u2 -- "####             Defaults:"
          print  -u2 -- "####               sitetag   = NODEFAULT"
          print  -u2 -- "####               name      = NODEFAULT"
          print  -u2 -- "####               type      = cluster"
          print  -u2 -- "####               ihs_level = NODEFAULT"
          print  -u2 -- "####             Note:  ihs_level only needed if"
          print  -u2 -- "####                    type is cluster"
          exit 1
      ;;
   esac
   shift
done

if [[ $INSTALL_TYPE != "cluster" && $EVENT == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Option sitetag must be specified if"
   echo "    type is not cluster"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $SITENAME == "" && $EVENT != "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Option name must be specified if"
   echo "    sitetag is specified"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi


HTTPDIR="HTTPServer"

global_server ()
{
   if [[ ! -f /projects/${HTTPDIR}/content/site.txt ]]; then 
      echo "Create global server site.txt"
      echo "Global HTTPServer on `hostname -s`" > /projects/${HTTPDIR}/content/site.txt
      echo "Virtualhost list:" >> /projects/${HTTPDIR}/content/site.txt
   fi
   if [[ ! -h /projects/${HTTPDIR}/content/sslsite.txt ]]; then
      echo "Creating sslsite.txt link"
      ln -s site.txt /projects/${HTTPDIR}/content/sslsite.txt
   fi
}

virtualhost ()
{
   if [[ ! -f /projects/${EVENT}/content/site.txt ]]; then
      echo "Create $EVENT site.txt"
      echo "${SITENAME}" > /projects/${EVENT}/content/site.txt
   fi

   if [[ ! -h /projects/${EVENT}/content/sslsite.txt ]]; then
      echo "Creating sslsite.txt link"
      ln -s site.txt /projects/${EVENT}/content/sslsite.txt
   fi

   if [[ -f /projects/${HTTPDIR}/content/site.txt ]]; then
      cat /projects/${HTTPDIR}/content/site.txt | grep "${SITENAME}" > /dev/null 2>&1
      if [[ $? -gt 0 ]]; then
         echo "Updating Global Server site.txt"
         echo "  ${SITENAME}" >> /projects/${HTTPDIR}/content/site.txt
         sed '/^ \{2\}/d' /projects/${HTTPDIR}/content/site.txt > /projects/${HTTPDIR}/content/site_tmp.txt
         sed -n '/^ \{2\}/p' /projects/${HTTPDIR}/content/site.txt | sort >> /projects/${HTTPDIR}/content/site_tmp.txt
         cp /projects/${HTTPDIR}/content/site_tmp.txt /projects/${HTTPDIR}/content/site.txt
         rm /projects/${HTTPDIR}/content/site_tmp.txt
         /lfs/system/tools/ihs/setup/vhost_perms.sh
      fi
   fi
}

site ()
{
   if [[ ! -f /projects/${EVENT}/content/htdocs/site.txt ]]; then
      echo "Create $EVENT site.txt"
      echo "${SITENAME}" > /projects/${EVENT}/content/htdocs/site.txt 
   fi

   if [[ ! -h /projects/${EVENT}/content/htdocs/sslsite.txt ]]; then
      echo "Creating sslsite.txt link"
      ln -s site.txt /projects/${EVENT}/content/htdocs/sslsite.txt
   fi
}

if [[ $EVENT == "HTTPServer" ]]; then
	print -u2 -- "Doing global server"
   global_server
else
   if [[ $INSTALL_TYPE == "cluster" ]]; then
		print -u2 -- "Doing virtualhost server $INSTALL_TYPE"
      virtualhost
   else
		print -u2 -- "Doing site server $INSTALL_TYPE"
      site
   fi
fi
