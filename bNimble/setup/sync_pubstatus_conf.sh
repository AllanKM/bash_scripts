#! /bin/ksh

######################################################################
#
#  sync_pubstatus_conf.sh - Script used to sync pubstatus.conf
#
#---------------------------------------------------------------------
#
#  Steve Farrell - 8/29/2007 - Initial creation
#
######################################################################

# Set umask
umask 002

# Default Values
TOOLSDIR=/lfs/system/tools
DESTDIR=/usr/local/etc
CUSTENV=""
STACK=""

#process command-line options
until [ -z "$1" ] ; do
	case $1 in
		cust=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTTAG=$VALUE; fi ;;
		env=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTENV=$VALUE; fi ;;
		config=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CONFIG=$VALUE; fi ;;
		*) print -u2 -- "#### Unknown argument: $1"
			print -u2 -- "#### Usage: $0 [ cust=< label given the customer > ] [ env =< Environment for this install > ]"
			exit 1
         ;;
	esac
	shift
done

echo "Checking if $DESTDIR exist"
if [[ ! -d $DESTDIR ]]; then
	print "   Creating $DESTDIR directory"
	mkdir -p $DESTDIR
fi

echo "Sync pubstatus.conf"
if [ -e "/fs/projects/${CUSTENV}/${CUSTTAG}/config/${CONFIG}" ]; then
	cp /fs/projects/${CUSTENV}/${CUSTTAG}/config/${CONFIG} ${DESTDIR}/${CONFIG}
else
	print -u2 -- "#### /fs/projects/${CUSTENV}/${CUSTTAG}/config/${CONFIG} does not exist"
	exit 2
fi
