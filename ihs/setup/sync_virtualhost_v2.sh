#! /bin/ksh

########################################################################
#
#  sync_virtualhost.sh -- Performs all the standard virtualhost setup
#
#-----------------------------------------------------------------------
#
#  Todd Stephens - 08/29/2007 - Initial creation
#  TOdd Stephens - 05/28/2008 - Modified logic for finding global dirs
#
########################################################################

# Set umask
umask 002

# Default Values
SITETAG=""
CUSTTAG=""
CUSTENV=""
DELETE_FLAG=1
TOOLSDIR=/lfs/system/tools

#command-line options
until [ -z "$1" ] ; do
        case $1 in
                site=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SITETAG=$VALUE; fi ;;
                delete_flag=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DELETE_FLAG=$VALUE; fi ;;
                cust=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTTAG=$VALUE; fi ;;
                env=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTENV=$VALUE; fi ;;
                toolsdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
                *)      print -u2 -- "#### Unknown argument: $1"
                        print -u2 -- "#### Usage: $0 [ site=< sitetag associated with virtualhost > ]"
                        print -u2 -- "#### Usage: $0 [ cust=< label given the customer > ] [ env =< Environment for this install > ]"
                         print -u2 -- "####          [ toolsdir=< location of eilocal tools directory ]"
                        exit 1
                        ;;
        esac
        shift
done

# Determine if global master exist
if [ -d /fs/projects/${CUSTENV}/${CUSTTAG} ]; then
   GLOBAL_BASE="/fs/projects/${CUSTENV}/${CUSTTAG}"
else
   echo "Can not find global master base directory"
   echo "Aborting httpserver sync"
   exit 1
fi

echo "Checking if IHS is installed"
IHSINSTALLROOT=`grep -i serverroot ${GLOBAL_BASE}/HTTPServer/conf/httpd.conf | awk '{print $NF}'`
if [[ ! -f ${IHSINSTALLROOT}/bin/httpd ]]; then
   echo "   IHS code is not installed at $IHSINSTALLROOT"
   echo "   on this node, aborting"
   exit 2
fi

echo "Checking if /projects exist"
if [[ ! -d /projects  ]]; then
  echo "   /projects does not exist on this node, aborting"
  exit 2
fi

echo "Checking if you defined site"
if [[ $SITETAG == "" ]]; then
   echo "   You must specify a site to sync"
   exit 1
else
   echo "   site defined as $SITETAG"
fi

echo "Create virtualhost dirs"
cat ${GLOBAL_BASE}/${SITETAG}/config/dirlist.cfg | ${TOOLSDIR}/configtools/create_directories

echo "Sync from global directories to localdisk"
${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/${SITETAG}/config/ /projects/${SITETAG}/config/ "avc --exclude=RCS" 0 $DELETE_FLAG
${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/${SITETAG}/cgi-bin/ /projects/${SITETAG}/cgi-bin/ "avc --exclude=RCS" 0 $DELETE_FLAG
${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/${SITETAG}/fcgi-bin/ /projects/${SITETAG}/fcgi-bin/ "avc --exclude=RCS" 0 $DELETE_FLAG


if [[ ! -f /projects/${SITETAG}/content/Admin/whichnode.txt ]]; then
   echo "Creating whichnode.txt"
   SHORTHOST=`/bin/hostname -s`
   mkdir -p /projects/${SITETAG}/content/Admin/
   echo $SHORTHOST > /projects/${SITETAG}/content/Admin/whichnode.txt
fi
