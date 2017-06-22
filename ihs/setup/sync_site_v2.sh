#! /bin/ksh

########################################################################
#
#  sync_site_v2.sh -- Performs all the standard standalone site setup
#
#-----------------------------------------------------------------------
#
#  Todd Stephens - 05/02/2011 - Initial creation
#  Todd Stephens - 06/17/12 - Some cleanup and making a common interface
#
########################################################################

# Verify script is called via sudo or ran as root
if [[ $SUDO_USER == "" && $USER != "root" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "********          Script sync_site_v2.sh needs           ********"
   echo "********              to be ran with sudo                ********"
   echo "********                  or as root                     ********"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

# Set umask
umask 002

# Set default values
SITETAG=""
CUSTTAG=""
CUSTENV=""
DESTDIR=""
CONTENT=""
TOOLSDIR=/lfs/system/tools
LISTEN_FILE=""
CGI="yes"


#command-line options
until [ -z "$1" ] ; do
   case $1 in
      sitetag=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SITETAG=$VALUE; fi ;;
      custtag=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTTAG=$VALUE; fi ;;
      env=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTENV=$VALUE; fi ;;
      content=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CONTENT=$VALUE; fi ;;
      sync_cgi=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CGI=$VALUE; fi ;;
      toolsdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
      vg=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VG=$VALUE; fi ;;
      content_fs_size=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CONTENT_FS=$VALUE; fi ;;
      *)  print -u2 -- "#### Unknown argument: $1"
          print -u2 -- "#### Usage: ${0:##*/}"   
          print -u2 -- "####           sitetag=< tag associated with site >"
          print -u2 -- "####           env=< environment for this install >"
          print -u2 -- "####           content=< localdisk or shareddisk > ]"
          print -u2 -- "####           [ custtag=< tag associated with customer > ]"
          print -u2 -- "####           [ vg=< volumn group to create content filesystem > ]"
          print -u2 -- "####           [ content_fs_size=< size of content filesystem in MB > ]"
          print -u2 -- "####           [ sync_cgi=< yes or no > ]"
          print -u2 -- "####           [ toolsdir=< path to ei local tools > ]"
          print -u2 -- "#### ---------------------------------------------------------------------------"
          print  -u2 -- "####             Defaults:"
          print  -u2 -- "####               sitetag         = NODEFAULT"
          print  -u2 -- "####               env             = NODEFAULT"
          print  -u2 -- "####               content         = NODEFAULT"
          print  -u2 -- "####               custtag         = NODEFAULT"
          print  -u2 -- "####               vg              = NODEFAULT"
          print  -u2 -- "####               content_fs_size = NODEFAULT"
          print  -u2 -- "####               sync_cgi        = yes"
          print  -u2 -- "####               toolsdir        = /lfs/system/tools"
          print  -u2 -- "####             Notes:"
          print  -u2 -- "####               1) custtag is only needed"
          print  -u2 -- "####                  if content is set to shareddisk"
          print  -u2 -- "####               2) vg and content_fs_size are only"
          print  -u2 -- "####                  needed if content is set to"
          print  -u2 -- "####                  localdisk"
          print  -u2 -- "####               3) sync-cgi only has meaning when"
          print  -u2 -- "####                  content is set to localdisk"
          exit 1
      ;;
   esac
   shift
done

if [[ $SITETAG == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Must specify a sitetag"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $CUSTENV == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Must specify an ei env "
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $CONTENT != "shareddisk" && $CONTENT != "localdisk" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Option content must have a value of" 
   echo "    localdisk or shareddisk"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $CONTENT == "shareddisk" && $CUSTTAG == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Option custtag must be specified if"
   echo "    content is to be located on shared disk"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $CONTENT == "localdisk" && $VG == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Option vg must be specified if"
   echo "    content is to be located on local disk"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $CONTENT == "localdisk" && $CONTENT_FS == "" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Option content_fs_size must be specified if"
   echo "    content is to be located on local disk"
   echo "/////////////////////////////////////////////////////////////////"
   echo ""
   exit 1
fi

if [[ $CGI != "yes" && $CGI != "no" && $CONTENT == "localdisk" ]]; then
   echo ""
   echo "/////////////////////////////////////////////////////////////////"
   echo "    Option sync_cgi must be set to a value"
   echo "    of yes or no"
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

case `uname` in
   AIX) PLATFORM="aix" ;;
   Linux)
      uname -a | grep ppc
      if [[ "$?" -eq 0 ]]; then
         PLATFORM="linuxppc"
      else
         PLATFORM="linux"
      fi
   ;;
   *)
      echo ""
      echo "/////////////////////////////////////////////////////////////////"
      echo"  `uname` not supported by this install script."
      echo "/////////////////////////////////////////////////////////////////"
      echo ""
      return 2
   ;;
esac

# Defining Global Base
if [[ -d /fs/projects/sws/${CUSTENV}/${SITETAG} ]]; then
   GLOBAL_BASE="/fs/projects/sws/${CUSTENV}/${SITETAG}"
else
   echo "Can not find global master base directory"
   echo "Aborting site sync"
   exit 1
fi

echo "Checking if IHS is installed"
DESTDIR=`grep -i serverroot ${GLOBAL_BASE}/conf/${SITETAG}.conf | awk '{print $NF}'`
if [[ ! -f ${DESTDIR}/bin/httpd ]]; then
  echo "   IHS code is not installed at $DESTDIR"
  echo "   on this node, aborting"
  exit 2
fi

echo "Checking if /projects exist"
if [[ ! -d /projects  ]]; then
  echo "   /projects does not exist on this node, aborting"
  exit 2
fi

echo ""
echo "Creating/Sync'ing site $SITETAG serving from $CONTENT"
echo ""

SHORTHOST=`/bin/hostname -s`
SERVICEHOST=`lssys -q -e role==webserver.${SITETAG}.${CUSTENV}.* eihostname==${SHORTHOST}`

echo "Verifying/Creating site directory structure"
cat ${GLOBAL_BASE}/conf/dirlist.cfg | ${TOOLSDIR}/configtools/create_directories

echo ""
echo "Sync from global directories to localdisk"
echo ""
echo "    bin dir ...."
${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/bin/ /projects/${SITETAG}/bin/ "avc --exclude=RCS" 0 1

echo ""
echo "    conf dir ...."
${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/conf/ /projects/${SITETAG}/conf/ "avc --exclude=RCS --exclude=plugin-cfg*.xml* --exclude=*listen*.conf --exclude=kht-${SITETAG}*.conf --exclude=dirlist.cfg" 0 1

echo ""
echo "    key dir ...."
${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/key/ /projects/${SITETAG}/key/ "avc --exclude=RCS --exclude=*plugin*" 0 1

echo ""
echo "    modules dir ...."
if [[ -d ${GLOBAL_BASE}/modules/${PLATFORM} ]]; then
   ${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/modules/${PLATFORM}/ /projects/${SITETAG}/modules/ "avc --exclude=RCS" 0 1
else
   ${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/modules/ /projects/${SITETAG}/modules/ "avc --exclude=RCS" 0 1
fi

if [[ $SERVICEHOST != "" ]]; then
   IPALIAS=`lssys -1l ipalias $SERVICEHOST`
   for IP_ENTRY in $IPALIAS
   do
      if [[ $IP_ENTRY == *\@real* ]]; then
         REALIP=`echo $IP_ENTRY | sed "s/\@real//"`
      else
         VIP=$IP_ENTRY
      fi
   done
   LISTEN_FILE="/projects/${SITETAG}/conf/listen_${SERVICEHOST}.conf"
   grep "^LoadModule ibm_ssl_module" /projects/${SITETAG}/conf/${SITETAG}.conf > /dev/null 2>&1 
   if [[ $? -eq 0 ]]; then
      USE_SSL=0
   elif [[ $? -eq 1 ]]; then
      USE_SSL=1
   fi

   echo ""

   if [[ -f $LISTEN_FILE ]]; then
      echo "Verifying Listen file is current"
      ENTRY1=""
      ENTRY2=""
      ENTRY3=""
      ENTRY4=""
      eval $(awk '{print "ENTRY"NR"="$2}' $LISTEN_FILE)
      if [[ $ENTRY1 == "" || $ENTRY2 == "" ]]; then
         echo "    Listen file is incomplete removing"
         rm $LISTEN_FILE
      elif [[ ( $ENTRY3 == "" || $ENTRY4 == "" ) && $USE_SSL -eq 0 ]]; then
         echo "    Listen file does not contain listen statments for port 443"
         echo "    yet server is configured for ssl"
         echo "    Listen file is incomplete removing"
         rm $LISTEN_FILE
      elif [[ ( $ENTRY3 != "" || $ENTRY4 != "" ) && $USE_SSL -eq 1 ]]; then
         echo "    Listen file contains listen statements for port 443"
         echo "    yet server s not configured for ssl"
         echo "    Listen file contains incorrect info removing"
         rm $LISTEN_FILE
      else
         IP1=$( echo ${ENTRY1%:*} )
         PORT1=$( echo ${ENTRY1##*:} )
         IP2=$( echo ${ENTRY2%:*} )
         PORT2=$( echo ${ENTRY2##*:} )
         if [[ $IP1 != $VIP || $PORT1 != 80 || $IP2 != $REALIP || $PORT2 != 80 ]]; then
            echo "    Listen file contains incorrect info for port 80"
            echo "    Removing"
            rm $LISTEN_FILE
         fi
 
         if [[ $USE_SSL -eq 0 ]]; then
            IP3=$( echo ${ENTRY3%:*} )
            PORT3=$( echo ${ENTRY3##*:} )
            IP4=$( echo ${ENTRY4%:*} )
            PORT4=$( echo ${ENTRY4##*:} )
            if [[ $IP3 != $VIP || $PORT3 != 443 || $IP4 != $REALIP || $PORT4 != 443 ]]; then
               echo "    Listen file contains incorrect info for port 443"
               echo "    Removing"
               rm $LISTEN_FILE
            fi
         fi
      fi 
   fi
   if [[ ! -f $LISTEN_FILE ]]; then
      echo "Create custom file containing the service specific ips"
      echo "Listen ${VIP}:80" > $LISTEN_FILE
      echo "Listen ${REALIP}:80" >> $LISTEN_FILE
      if [[ $USE_SSL -eq 0 ]]; then
         echo "Listen ${VIP}:443" >> $LISTEN_FILE
         echo "Listen ${REALIP}:443" >> $LISTEN_FILE
      fi
   fi
   if [[ -L /projects/${SITETAG}/conf/listen.conf ]]; then
      echo "Verifying listen.conf symlink"
      LISTEN_LINK=`ls -l /projects/${SITETAG}/conf/listen.conf | awk '{print $NF}'`
      if [[ $LISTEN_LINK != $LISTEN_FILE ]]; then
         echo "    Listen.conf link incorrect replacing"
         ln -fs $LISTEN_FILE /projects/${SITETAG}/conf/listen.conf
      fi
   fi
   if [[ ! -L /projects/${SITETAG}/conf/listen.conf ]]; then
      echo "Creating listen.conf symlink"
      ln -s $LISTEN_FILE /projects/${SITETAG}/conf/listen.conf
   fi
else
   echo "This server does not have a service host which this script does not"
   echo "support.  Skipping listen.conf setup"
fi
 
if [[ $CONTENT == "localdisk" ]]; then
   echo "Content is being setup to serve from localdisk"
   if [[ ! -d /projects/${SITETAG}/content ]]; then
      echo "   Content filesystem does not exist --- creating content filesystem"
      if [[ ! -d /projects/${SITETAG} ]]; then
         echo "   Site directory does not exist --- creating site \(${SITETAG}\) directory"
         mkdir /projects/${SITETAG}
      fi
      /fs/system/bin/eimkfs /projects/${SITETAG}/content ${CONTENT_FS}M $VG
   fi
   echo "Sync content dirs"

   if [[ $CGI == "yes" ]]; then
      echo ""
      echo "    cgi-bin dir ...."
      ${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/content/cgi-bin/ /projects/${SITETAG}/content/cgi-bin/ "avc --exclude=RCS" 1 1

      echo ""
      echo "    fcgi-bin dir ...."   
      ${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/content/fcgi-bin/ /projects/${SITETAG}/content/fcgi-bin/ "avc --exclude=RCS" 1 1
   fi

   echo ""
   echo "    data dir ...."   
   ${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/content/data/ /projects/${SITETAG}/content/data/ "avc --exclude=RCS" 1 0

   echo ""
   echo "    etc dir ...."
   ${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/content/etc/ /projects/${SITETAG}/content/etc/ "avc --exclude=RCS" 1 0

   echo ""
   echo "    htdocs dir ...." 
   ${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/content/htdocs/ /projects/${SITETAG}/content/htdocs/ "avc --exclude=RCS" 1 0 
fi

if [[ $CONTENT == "shareddisk" ]]; then
   echo "Content is being setup to serve from shareddisk"
   if [[ ! -L /projects/${SITETAG}/content ]]; then
      if [[ -d /fs/projects_isolated/${CUSTTAG}/${SITETAG} ]]; then
         echo "   Content symlink does not exist --- creating symlink to shared content"
         ln -fs /fs/projects_isolated/${CUSTTAG}/${SITETAG}/content /projects/${SITETAG}/content
      else
         echo "   Shared content dir does not exist in expected location"
         echo "      Create symlink to content manually once that becomes available"
      fi
   fi
fi

if [[ ! -d /projects/${SITETAG}/nodeid ]]; then
   echo "nodeid dir does not exist --- creating nodeid dir"
   mkdir /projects/${SITETAG}/nodeid
fi

if [[ -f /projects/${SITETAG}/nodeid/whichnode.txt ]]; then
   echo "Verifying that whichnode.txt is still accurate"
   LINE_1=""
   LINE_2=""
   LINE_3=""
   LINE_4=""
   LINE_5=""
   LINE_6=""
   LINE_7=""
   LINE_8=""
   eval $(awk '{print "LINE_"NR"="$1}' /projects/${SITETAG}/nodeid/whichnode.txt) 
   if [[ $LINE_2 != ${SITETAG} ]]; then
      echo "   SITETAG does not match"
      echo "    Removing whichnode.txt file"
      rm /projects/${SITETAG}/nodeid/whichnode.txt
   elif [[ $LINE_8 == "" ]]; then
      if [[ $LINE_5 != $SHORTHOST ]]; then
         echo "    SHORTHOST does not match"
         echo "    Removing whichnode.txt file"
         rm /projects/${SITETAG}/nodeid/whichnode.txt
      fi
   elif [[ $LINE_5 != $SERVICEHOST || $LINE_8 != $SHORTHOST ]]; then
      if [[ $LINE_5 != $SERVICEHOST ]]; then
         echo "    SERVICEHOST does not match"
      fi
      if [[ $LINE_8 != $SHORTHOST ]]; then
         echo "    SHORTHOST does not match"
      fi
      echo "    Removing whichnode.txt file"
      rm /projects/${SITETAG}/nodeid/whichnode.txt
   fi 
fi
if [[ ! -f /projects/${SITETAG}/nodeid/whichnode.txt ]]; then
   echo "Creating whichnode.txt"
   echo "sitetag" > /projects/${SITETAG}/nodeid/whichnode.txt
   echo "$SITETAG " >> /projects/${SITETAG}/nodeid/whichnode.txt
   echo "" >> /projects/${SITETAG}/nodeid/whichnode.txt
   if [[ $SERVICEHOST != "" ]]; then
      echo "Service Host " >> /projects/${SITETAG}/nodeid/whichnode.txt
      echo "$SERVICEHOST" >> /projects/${SITETAG}/nodeid/whichnode.txt
      echo "" >> /projects/${SITETAG}/nodeid/whichnode.txt
   fi
   echo "Installed on ei host" >> /projects/${SITETAG}/nodeid/whichnode.txt
   echo "$SHORTHOST" >> /projects/${SITETAG}/nodeid/whichnode.txt
fi

if [ -f /projects/${SITETAG}/.ihs_level_* ]; then
  rm /projects/${SITETAG}/.ihs_level_*
fi

echo "Set the IHS install dir flag"
HTTPDIR=`echo ${DESTDIR} | cut -d"/" -f3`
if [ -f /projects/${SITETAG}/.HTTPServer* ]; then
  rm /projects/${SITETAG}/.HTTPServer*
fi
if [ -f /projects/${SITETAG}/.WebSphere* ]; then
  rm /projects/${SITETAG}/.WebSphere*
fi
touch /projects/${SITETAG}/.${HTTPDIR}

if [ -f /projects/${SITETAG}/conf/mime.types ]; then
   echo "Custom mime.types file found checking symlink"
   if [ ! -L ${DESTDIR}/mime_custom/${SITETAG}_mime.types ]; then
      echo "   Symlink not found creating"
      if [ ! -d ${DESTDIR}/mime_custom ]; then
         mkdir ${DESTDIR}/mime_custom
      fi
      ln -s /projects/${SITETAG}/conf/mime.types ${DESTDIR}/mime_custom/${SITETAG}_mime.types
   fi
fi
