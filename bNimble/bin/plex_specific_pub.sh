#! /bin/ksh

##########################################################################
#
# plex_specific_pub.sh -- Script to alter target list of a running bNimble
#                          process to allow for rolling deploys
#
#-------------------------------------------------------------------------
#
# History -
#
#   08/06/2009 - Todd Stephens - Initial version
#
###########################################################################

# Functions
USAGE() {
   print -u2 --  "#### Usage: $0 conf=<absolute path to configuration file> plex=[<plex or list of plexes separated by commas you want publish to flow to>] [verbose=1] [debug=<value>]"
}

# Set defaults
CONFIG=""
PLEX=""
NUM=0
VERBOSE=0
DEBUG=0
   
# Process command-line options
until [ -z "$1" ] ; do
   case $1 in
      conf=*)      VALUE=${1#*=}; if [[ "$VALUE" != "" ]]; then CONFIG=$VALUE; fi ;;
      plex=*)      VALUE=${1#*=}; if [[ "$VALUE" != "" ]]; then typeset -u PLEX=$VALUE; set -A PUB_PLEXES `echo $PLEX | sed 's/,/ /g'`; fi ;;
      debug=*)     VALUE=${1#*=}; if [[ "$VALUE" != "" ]]; then DEBUG=$VALUE; fi ;;
      verbose=*)     VALUE=${1#*=}; if [[ "$VALUE" != "" ]]; then VERBOSE=$VALUE; fi ;;

      *)           print -u2 --  "#### Unknown argument: $1"
                   USAGE
                   exit 1
                   ;;
      esac
      shift
done

# Check for required parameters
if [[ $CONFIG == "" && $PLEX == "" ]]; then
   print -u2 -- "#### Must specify a config and a plex to pub to"
   USAGE
   exit 2
elif [[ $CONFIG == "" ]]; then
   print -u2 -- "#### Must specify a config"
   USAGE
   exit 2
elif [[ $PLEX == "" ]]; then
   print -u2 -- "#### Must specify one or more plexes to pub to"
   USAGE
   exit 2
fi


# Process Config file
for i in `cat $CONFIG                   \
             | grep -v "[[:space:]]*#"  \
             | sed 's/^[[:space:]][[:space:]]*//g'  \
             | sed 's/[[:space:]][[:space:]]*$//'  \
             | sed 's/:[[:space:]]*/%%/'  \
             | sed 's/[[:space:]][[:space:]]*/,/g'`
do
   PARM=`echo $i | awk -F%% '{print $1}'`
   VAL=`echo $i | awk -F%% '{print $2}'`

   case $PARM in
      NODE)     NODE=$VAL ;;
      PORT)     PORT=$VAL ;;
      METHOD)   METHOD=$VAL ;;
      *)        DIST_Stanza[$NUM]=$PARM
                TARGETS[$NUM]=$VAL
                let NUM="$NUM + 1"
                ;;
   esac
done

if [[ $DEBUG -eq 1 || $DEBUG -gt 2 ]]; then
  echo "Plex(es) to pub to is/are" ${PUB_PLEXES[*]}
  echo "Node is" $NODE
  echo "Port is" $PORT
  echo "Method is" $METHOD
  echo "Distributor Stanzas are" ${DIST_Stanza[*]}
  echo "Targets are" ${TARGETS[*]}
  echo "Num of Dist Stanzas is" ${#DIST_Stanza[*]}
  echo "Num of Targets is" ${#TARGETS[*]}
fi

# Determine if we are running on the correct node for this config
HOST=`/bin/hostname -s`
if [[ $HOST != $NODE ]]; then
   echo "This config must be run from node $NODE!  Exiting..."
   exit 3
fi

# Process each distributor stanza
index=0
while [ $index -lt ${#DIST_Stanza[*]} ]
do
   echo "${TARGETS[$index]}" | while IFS="," read f1 f2 f3
   do
      P1=$f1
      P2=$f2
      P3=$f3
   done
   if [[ $DEBUG -gt 1 ]]; then
      echo
      /lfs/system/bin/pubtool2 -action status -distributor $METHOD://localhost:$PORT/${DIST_Stanza[$index]}| grep http
      echo
      echo "Stanza is" ${DIST_Stanza[$index]}
      echo "P1 endoint is" $P1
      echo "P2 endoint is" $P2
      echo "P3 endoint is" $P3
      echo
   fi
   index2=0
   while [ $index2 -lt ${#PUB_PLEXES[*]} ]
   do
      ENDPOINT=$(eval echo \$${PUB_PLEXES[$index2]})
      RESULT=`/lfs/system/bin/pubtool2 -action status -distributor $METHOD://localhost:$PORT/${DIST_Stanza[$index]}| grep "$ENDPOINT"`
      if [[ $VERBOSE -eq 1 ]]; then
         echo "Status result is:"
         echo $RESULT
      fi
      if [[ $RESULT == "" ]]; then
         echo "Adding endpoint" $ENDPOINT
         ADD_RESULT=`/lfs/system/bin/pubtool2 -action add -distributor $METHOD://localhost:$PORT/${DIST_Stanza[$index]} -endpoint $ENDPOINT`
         if [[ $VERBOSE -eq 1 ]]; then
            echo "Add command result is:"
            print -u2 -- "$ADD_RESULT"
         fi
      fi
      if [[ $P1 == $ENDPOINT ]]; then
         P1=""
      elif [[ $P2 == $ENDPOINT ]]; then
         P2=""
      elif [[ $P3 == $ENDPOINT ]]; then
         P3=""
      fi      
      let index2="$index2 + 1"
   done  
   if [[ $P1 != "" ]]; then
      RESULT1=""
      RESULT1=`/lfs/system/bin/pubtool2 -action status -distributor $METHOD://localhost:$PORT/${DIST_Stanza[$index]}| grep "$P1"`
      if [[ $RESULT1 != "" ]]; then
         echo "Removing endpoint" $P1
         REMOVE_RESULT=`/lfs/system/bin/pubtool2 -action remove -distributor $METHOD://localhost:$PORT/${DIST_Stanza[$index]} -endpoint $P1`
         if [[ $VERBOSE -eq 1 ]]; then
            echo "Remove command result is:"
            print -u2 -- "$REMOVE_RESULT"
         fi
      fi
   fi
   if [[ $P2 != "" ]]; then
      RESULT2=""
      RESULT2=`/lfs/system/bin/pubtool2 -action status -distributor $METHOD://localhost:$PORT/${DIST_Stanza[$index]}| grep "$P2"`
      if [[ $RESULT2 != "" ]]; then
         echo "Removing endpoint" $P2
         REMOVE_RESULT=`/lfs/system/bin/pubtool2 -action remove -distributor $METHOD://localhost:$PORT/${DIST_Stanza[$index]} -endpoint $P2`
         if [[ $VERBOSE -eq 1 ]]; then
            echo "Remove command result is:"
            print -u2 -- "$REMOVE_RESULT"
         fi
      fi
   fi
   if [[ $P3 != "" ]]; then
      RESULT3=""
      RESULT3=`/lfs/system/bin/pubtool2 -action status -distributor $METHOD://localhost:$PORT/${DIST_Stanza[$index]}| grep "$P3"`
      if [[ $RESULT3 != "" ]]; then
         echo "Removing endpoint" $P3
         REMOVE_RESULT=`/lfs/system/bin/pubtool2 -action remove -distributor $METHOD://localhost:$PORT/${DIST_Stanza[$index]} -endpoint $P3`
         if [[ $VERBOSE -eq 1 ]]; then
            echo "Remove command result is:"
            print -u2 -- "$REMOVE_RESULT"
         fi
      fi
   fi
   let index="$index + 1"
done
echo ""
echo ""
index=0
while [ $index -lt ${#DIST_Stanza[*]} ]
do
   echo "The remaining targets for stanza" ${DIST_Stanza[$index]} ":"
   /lfs/system/bin/pubtool2 -action status -distributor $METHOD://localhost:$PORT/${DIST_Stanza[$index]}| grep http
   let index="$index + 1"
   echo ""
done
