#! /bin/ksh

######################################################################
#
#  sync_config.sh - Script used to sync radius config 
#
#---------------------------------------------------------------------
#
##
####################################################################

# Set umask
umask 002

# Default Values
TOOLSDIR=/lfs/system/tools
CUSTTAG="edr"

#process command-line options
until [ -z "$1" ] ; do
        case $1 in
                custtag=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTTAG=$VALUE; fi ;;
                env=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTENV=$VALUE; fi ;;
                *)      print -u2 -- "#### Unknown argument: $1"
                        print -u2 -- "#### Usage: $0 [ custtag=< Customer > ] [ env =< Environment for this install > ]"
                        exit 1
                        ;;
        esac
        shift
done
if [ ! -d /fs/projects/${CUSTENV}/${CUSTTAG}/raddb/ ];then
   print -u2 -- "/fs/projects/${CUSTENV}/${CUSTTAG}/raddb/ does not exist"
	exit 16
fi
${TOOLSDIR}/configtools/filesync /fs/projects/${CUSTENV}/${CUSTTAG}/raddb/ /etc/${CUSTTAG}_raddb/ "avc " 1 0
${TOOLSDIR}/radius/bin/radius_perms.sh custtag=$CUSTTAG env=$CUSTENV

