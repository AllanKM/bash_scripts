#!/bin/ksh
#Check the health of bNimble
#Usage:
#         check_bNimble.sh [site-tag or cust-tag]
#Example: check_bNimble.sh events

#All errors messages begin the line with "###"
#To look for just errors, run:  check_bNimble.sh | grep \#

ARGS=$*

funcs=/lfs/system/tools/bNimble/lib/bNimble_functions.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

funcs=/lfs/system/tools/configtools/lib/check_functions.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

if [ $# -eq 0 ]; then
   #no args passed, lets look for PUB related roles
   getRoles
   for ROLE in $ROLES; do
      typeset -l ROLE
      if [[ "$ROLE" = "pub"* ]]; then
         ARGS="$ARGS $ROLE"
      fi
   done
fi

date "+%T Checking bNimble"
CONFIG=`ps -eoargs= | awk '/b[n|N]imble.*\/config\// {print "/projects/" $NF }'`
if [ -z "$CONFIG" ]; then
	print -u2 -- "##### bNimble not running"
	exit 1
fi

# see if there is a kdb file we can use 
ETC=`echo $CONFIG | awk -F"/" '{print  "/" $2 "/" $3 "/etc/*"}'`
CERTS=`ls $ETC 2>/dev/null | grep -E ".kdb|.sth"`

# analyse the bNimble config file 
LOG=`awk '/ LOG_PATH/ {logpath=$4}; / LOG_NAME/ { logname=$4}; / MAIN_SITE/ {main=$4}; END{print logpath main"/"logname}' $CONFIG`

URLS=`awk '{
      if ( tolower($0)~/define port/ ) {
	         port= $4
      }
      if ( tolower($0)~/ssl.*=/) {
         if (tolower($3)~/true/) {
            http="https"
         }
         else {
            http="http"
         }
      };
      if ( tolower($0)~/name.*=/) {
         name=$3
      }
      if (tolower($0)~/com.ibm.events.bnimble.plugin.distributor.distributor/) {
         print http "://localhost:" port "/" name
      }
   }  ' $CONFIG`

if [ ! -z "$CERTS" ]; then
	URLS="$CERTS $URLS"
fi

PUB_ROOT=`awk '/Document-Root/ {print $3}' $CONFIG | sort | uniq`
			# checkDaedalus

if [ ! -z "$PUB_ROOT" ]; then
	checkPubStatus $LOG $PUB_ROOT
fi

if [ ! -z "$URLS" ]; then
	checkStatus $URLS
fi

# Deprecated
#for TAG in $ARGS ; do
#   typeset -l TAG
#   case $TAG in
#      *pub.ibm.endpoint|www.ibm.com|ibmcom|ibmstg|ibmsrv|ibm|*ibm.endpoint.stage.gz*)
#         checkDaedalus
#         ;;
#	esac
#done
echo "###### $0 Done"
