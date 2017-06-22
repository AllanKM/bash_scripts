#! /bin/ksh

########################################################################
#
#  sync_appdirs.sh -- Performs all the standard application directory
#                     setup
#-----------------------------------------------------------------------
#
#  Todd Stephens - 08/29/2007 - Initial creation
#
########################################################################

# Set umask
umask 002

# Default Values
APP=""
CUSTTAG=""
CUSTENV=""
TOOLSDIR=/lfs/system/tools
SYNCDIRS="bin code config etc lib properties"

#command-line options
until [ -z "$1" ] ; do
        case $1 in
                app=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then APP=$VALUE; fi ;;
                cust=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTTAG=$VALUE; fi ;;
                env=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTENV=$VALUE; fi ;;
                root=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DESTDIR=$VALUE; fi ;;
                toolsdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
                *)      print -u2 -- "#### Unknown argument: $1"
                        print -u2 -- "#### Usage: $0 [ app=< application associated with directories to be created > ]"
                        print -u2 -- "#### Usage: $0 [ cust=< label given the customer > ] [ env =< Environment for this install > ]"
                         print -u2 -- "####          [ toolsdir=< location of eilocal tools directory ]"
                        exit 1
                        ;;
        esac
        shift
done

echo "Checking if /projects exist"
lsfs /projects > /dev/null 2>&1
if [[ ! -d /projects || $? -gt 0 ]]; then
  print -u2 -- "####  /projects filesystem does not exist on this node, aborting"
  exit 2
fi

echo "Checking if you defined the application name"
if [[ $APP == "" ]]; then
   print -u2 -- "####  You must specify an application to sync"
   exit 1
else
   echo "   application defined as $APP"
fi

# Determine which standard to follow
if [[ -d /fs/${CUSTTAG}/${CUSTENV} ]]; then
   GLOBAL_BASE="/fs/${CUSTTAG}/${CUSTENV}"
elif [[ -d /fs/projects/${CUSTENV}/${CUSTTAG} ]]; then
   GLOBAL_BASE="/fs/projects/${CUSTENV}/${CUSTTAG}"
else
   print -u2 -- "#### Can not find global master base directory"
   print -u2 -- "#### Aborting application directory sync"
   exit 1
fi

if [ -f "${GLOBAL_BASE}/${APP}/config/dirlist.cfg" ]; then
	echo "Creating Application directories"
	cat ${GLOBAL_BASE}/${APP}/config/dirlist.cfg | ${TOOLSDIR}/configtools/create_directories
fi

echo "Sync directories like bin,lib,etc,properties and code from shared filesystem to localdisk"

for DIR in $SYNCDIRS ; do
	if [ -d ${GLOBAL_BASE}/${APP}/${DIR} ]; then 
		${TOOLSDIR}/configtools/filesync ${GLOBAL_BASE}/${APP}/${DIR}/ /projects/${APP}/${DIR}/ "avc --exclude=RCS " 0 1
	fi
done

if [ -f "/projects/${APP}/config/logrotate" ]; then
	echo "Adding logrotate stanza for $APP"
	cp /projects/${APP}/config/logrotate /etc/logrotate.d/${APP}
	chown root:system /etc/logrotate.d/${APP}
	chmod 444 /etc/logrotate.d/${APP}
	logrotate -f /etc/logrotate.conf
fi

