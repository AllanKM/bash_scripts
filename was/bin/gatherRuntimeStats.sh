#!/bin/ksh
# 
# Gather runtime statistics based on role, run from the DMGR node
# 
# Author:       Lou Amodeo
# Date:         19 March 2013
#
#  Change History
#
#  03-28-2013  Lou Amodeo   Add support for optional DB2 Instance Data
#
#  Usage:  sudo gatherRuntimeStats.sh version=<version> dmgrRole=<role> [clusters=<comma separated cluster names>] [noDataSources] [noJ2C] [[db2Role=<role> [db2Owner=<instanceOwner>] [db2Database=<databaseName>]] [interval=<minutes>] [repeat=<times>] [outputDir=<logDirectory>] [dropNode=<dropNode>] [dropLocation=<dropLocation>] [pushImmediate]
#

# Set defaults
HOST=`/bin/hostname -s`
VERSION="70"
DMGR_ROLE=""
CLUSTERLIST=""
DB2_ROLE=""
DB2_INSTOWNER=""
DB2_DBNAME=""
DROP_NODE=""
DROP_LOC=""
NO_DATASOURCES=""
NO_J2C=""
PUSH_IMMEDIATE=""
let INTERVAL=15
REPEAT=1
OUTPUTDIR="/tmp/GatherRuntimeStats"
USER=$SUDO_USER
PWDEXP=/lfs/system/tools/configtools/pwdexp
WASLIB="/lfs/system/tools/was/lib"
yz_passwd=""
gz_passwd=""
bz_passwd=""

#import functions to get passwords for zones
#funcs=/lfs/system/tools/configtools/lib/check_functions.sh
#[ -r $funcs ] && . $funcs || echo "#### Can't read functions file at $funcs"

get_password() {
        host=$1
        zone=$2
        trap 'stty echo && exit' INT
        stty -echo
        read in_passwd?"Enter your $zone zone password: "
        stty echo
        print ""
        
        if [[ "$in_passwd" = "" ]]
        then
        print "Error: password was not entered"
        exit 1
        fi
        
        unset DISPLAY
        rm -f /tmp/.dssh_known_hosts.$USER >/dev/null 2>&1 
        rm -f /tmp/.empty_sshkey.$USER >/dev/null 2>&1 
        print PubkeyAuthentication=no > /tmp/.empty_sshkey.$USER 

        OKAY=$(echo "$in_passwd" |$PWDEXP /usr/bin/ssh -v -t -l $USER -F /tmp/.empty_sshkey.$USER -o NumberOfPasswordPrompts=2 -o UserKnownHostsFile=/tmp/.dssh_known_hosts.$USER -o strictHostKeyChecking=no $host pwd > /dev/null)
        if [ $? -ne 0 ]
        then
        print -u2 -- "###$zone zone password entered is not correct for $USER"
        exit 1
        fi
		print -u2 -- "Password accepted"
		
		zoneLetter=`echo $2 | cut -c 1`
		case $zoneLetter in
         Y) yz_passwd=$in_passwd ;;
         G) gz_passwd=$in_passwd ;;
         B) bz_passwd=$in_passwd ;;
         *) echo "Invalid zone was entered : $2" 
            exit 1
            ;;
        esac        
}

if [ -n "$debug" ] ; then
   exp_debug="-d $debug"
fi

# Process optional command-line options
until [ -z "$1" ] ; do
    case $1 in
        version=*)        VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VERSION=$VALUE; fi ;;
        dmgrRole=*)       VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DMGR_ROLE=$VALUE; fi ;;
        clusters=*)       VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CLUSTERLIST=$VALUE; fi ;;
        noDataSources)    VALUE=${1#*=}; if [ "$VALUE" != "" ]; then NO_DATASOURCES="true"; fi ;;
        noJ2C)            VALUE=${1#*=}; if [ "$VALUE" != "" ]; then NO_J2C="true"; fi ;;
        db2Role=*)        VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DB2_ROLE=$VALUE; fi ;;
        db2Owner=*)       VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DB2_INSTOWNER=$VALUE; fi ;;
        db2Database=*)    VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DB2_DBNAME=$VALUE; fi ;;
        interval=*)       VALUE=${1#*=}; if [ "$VALUE" != "" ]; then INTERVAL=$VALUE; fi ;;
        repeat=*)         VALUE=${1#*=}; if [ "$VALUE" != "" ]; then REPEAT=$VALUE; fi ;;
        outputDir=*)      VALUE=${1#*=}; if [ "$VALUE" != "" ]; then OUTPUTDIR=$VALUE; fi ;;
        dropNode=*)       VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DROP_NODE=$VALUE; fi ;;
        dropLocation=*)   VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DROP_LOC=$VALUE; fi ;;
        pushImmediate)    VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PUSH_IMMEDIATE="true"; fi ;;
        *)  echo "### Unknown argument: $1"
	        echo "###  Usage: sudo gatherRuntimeStats.sh version=<version> dmgrRole=<role> [clusters=<comma separated cluster names>] [noDataSources] [noJ2C] [[db2Role=<role> [db2Owner=<instanceOwner>] [db2Database=<databaseName>]] [interval=<minutes>] [repeat=<times>] [outputDir=<logDirectory>] [dropNode=<dropNode>] [dropLocation=<dropLocation>] [pushImmediate]" 
            exit 1
            ;;
    esac
    shift
done

echo ""
TIME=`date`
echo "Runtime statistics data collection starting at: ${TIME}"

#make sure version is 2 digits
VERSION=`echo $VERSION | cut -c1-2`

#set WAS location variables
WASDIR="/usr/WebSphere${VERSION}/AppServer"
WSADMIN="${WASDIR}/bin/wsadmin.sh -lang jython"

#convert interval to minutes to seconds by multiplying value by 60 
let INTERVAL=$(($INTERVAL*60))

#
# Verify this is being run from the DMGR node.
# Although this script will technically work from any federated node its best not 
# to potentially impact performance of an application server to gather these statistics.
#   

if [ "$DMGR_ROLE" = "" ]; then
   echo "dmgrRole must be specified"
   exit 1
fi

DMGRNODE=`lssys -q -e role==$DMGR_ROLE | head -1`
if [ "$DMGRNODE" != "$HOST" ]; then
   echo "Must be run from the Deployment Manager node, DMGRNODE=${DMGRNODE}"
   exit 1;
fi  

if [ ! -d "/usr/WebSphere${VERSION}/AppServer" ]; then
   echo "WebSphere is not installed on this node"
   exit 1
fi 

# If drop node was specified then drop location is required
if [ ! -z "$DROP_NODE" ]; then 
    if [ -z "$DROP_LOC" ]; then 
      echo "Drop location must be specified"
      exit 1
    fi
fi 

#
# Build a list of application server nodes to gather runtime statistics from 
# Select all nodes managed by the DMGR. If one or more clusters were specified
# then only select the nodes associated with the clusters. 
#
NODES=""
if [ -z "$CLUSTERLIST" ]; then
    DIR=`pwd`
    cd /usr/WebSphere${VERSION}/AppServer/profiles/*Manager/config/cells/*/nodes
    NODES=`find * -type d -prune  \( ! -name *Manager \)`
    echo ""
    cd $DIR
else    
    CLUSTERS=`echo $CLUSTERLIST | sed 's/,/ /g'`
    echo "Populating node list with WAS clusters: ${CLUSTERS}"
    echo ""
    for cluster in $CLUSTERS
     do  
      MEMBERS=`su - webinst -c "$WSADMIN -conntype NONE -f ${WASLIB}/cluster.py -action members -cluster $cluster 2>&1|egrep -v '^WASX|sys-package-mgr' |xargs echo|tr ' ' ','"`
      if [ ! -z "MEMBERS" ]; then
          MEMBERS=`echo $MEMBERS | sed 's/,/ /g'`
          for member in $MEMBERS
           do
             #Per EI standard cluster member name begins with 6 character node name
             node=`echo $member | cut -c1-6`
             echo "adding cluster node ${node} to list" 
             NODES=$NODES" "$node
           done 
      fi
     done  
fi

echo "Found the following WebSphere nodes:"
for node in $NODES
  do  
    echo $node
done
echo ""

# Build a list of DB2 instance nodes to gather runtime statistics from 
if [ -n "$DB2_ROLE" ]; then
   
    if [ -n "$DB2_INSTOWNER" -a -z "$DB2_DBNAME" ]; then
       echo "db2Role and db2Owner was specified and db2Database is missing. Please specify db2Database."
       exit 1
    fi
    if [ -z "$DB2_INSTOWNER" -a -n "$DB2_DBNAME" ]; then
       echo "db2Role and db2Database was specified and db2Owner is missing. Please specify db2Owner."
       exit 1
    fi
    
    DB2NODES=`lssys -q -e role==$DB2_ROLE`
    echo "Found the following DB2 nodes:"
    for db2node in $DB2NODES
      do  
        echo $db2node
    done
    echo ""
    # Merge with WebSphere nodes
    NODES=$NODES" "$DB2NODES
    
elif [ -n "$DB2_INSTOWNER" -a -n "$DB2_DBNAME" ]; then
       echo "dbOwner and db2Database was specified and db2Role is missing. Please specify db2Role."
       exit 1
fi 

# Obtain passwords once for each zone in the nodes list
echo "You may be prompted for a password once for each zone"
echo ""  
ZONENODES=$NODES" "$DROP_NODE
for node in $ZONENODES
  do  
  realm=`lssys $node | grep realm | grep -v authrealm | cut -c21- | cut -d. -f1`
  case $realm in
     y) if [ "$yz_passwd" = "" ]; then get_password $node "Yellow"; fi; passwd=$yz_passwd ;;
     g) if [ "$gz_passwd" = "" ]; then get_password $node "Green"; fi; passwd=$gz_passwd ;;
     b) if [ "$bz_passwd" = "" ]; then get_password $node "Blue"; fi; passwd=$bz_passwd ;;
     *) echo "Failed to determine realm for node [$node]" 
        exit 1
        ;;
  esac
done 

#Check to see if DataSources are to be excluded
if [ -z "$NO_DATASOURCES" ]; then
   dataSources="dataSources"
else
   echo ""
   echo "Excluding DataSources"
   dataSources=""
fi

#Check to see if J2C Connections are to be excluded
if [ -z "$NO_J2C" ]; then
   j2c="j2c"
else
   echo ""
   echo "Excluding J2C Connections"
   j2c=""
fi

let count=0 
while [ $count -lt $REPEAT ]
do
   # For each node generate WAS, CPU info.  (Need to add DB2 instance stats to this) 
   DATESTAMP=`date +%Y%m%d-%H%M%S`
   mkdir -p ${OUTPUTDIR}/${DATESTAMP} 
   chmod -R 777 ${OUTPUTDIR}
   if [ $REPEAT > 1 ]; then
      echo "" 
      echo "Beginning Iteration #$(($count+1)) at: $DATESTAMP "
   fi 
   
   for node in $NODES
   do
     echo "Processing node: $node"  
     realm=`lssys $node | grep realm | grep -v authrealm | cut -c21- | cut -d. -f1`
     case $realm in
       y) passwd=$yz_passwd ;;
       g) passwd=$gz_passwd ;;
       b) passwd=$bz_passwd ;;
       *) echo "Failed to determine realm for node [$node]" 
        exit 1
        ;;
     esac   
     db2Node=`lssys $node | grep DB2 | grep -v CLIENT`
     if [ -z "$db2Node" ]; then
         NodeType="WAS" 
         /lfs/system/tools/was/bin/genCapacityData.sh version=$VERSION file=${OUTPUTDIR}/${DATESTAMP}/${node}.${DATESTAMP}.WAS.genCapacityData.txt node=${node} ${dataSources} ${j2c} data=all  2>&1 > /dev/null
     else
         NodeType="DB2" 
         if [ -n "$DB2_INSTOWNER" -a -n "$DB2_DBNAME" ]; then
            #generate db2 replication queue latency data
            echo "$passwd" | $PWDEXP $exp_debug ssh -t $USER@$node "sudo su - ${DB2_INSTOWNER} -c "/fs/system/tools/db2/bin/qlatencyreport.ksh ${DB2_DBNAME}" 2>&1 > /dev/null
            #generate db2 session data
            echo "$passwd" | $PWDEXP $exp_debug ssh -t $USER@$node "sudo su - ${DB2_INSTOWNER} -c "/fs/system/tools/db2/bin/db_app_session_count.ksh ${DB2_DBNAME}" 2>&1 > /dev/null
            echo "$passwd" | $PWDEXP $exp_debug scp -r $USER@$node:/logs/${DB2_INSTOWNER}/perf ${OUTPUTDIR}/${DATESTAMP}/ 2>&1 > /dev/null
            mv ${OUTPUTDIR}/${DATESTAMP}/perf/${DB2_DBNAME}_app_session_count.out  ${OUTPUTDIR}/${DATESTAMP}/${node}.${DATESTAMP}.DB2.${DB2_DBNAME}_sessions.txt
            mv ${OUTPUTDIR}/${DATESTAMP}/perf/${DB2_DBNAME}_qlatency.out           ${OUTPUTDIR}/${DATESTAMP}/${node}.${DATESTAMP}.DB2.${DB2_DBNAME}_qlatency.txt
            rm -r ${OUTPUTDIR}/${DATESTAMP}/perf
         fi
     fi    
     #generate cpu data  
     echo "$passwd" | $PWDEXP $exp_debug ssh $USER@$node "vmstat 2 3 > /tmp/${node}.${DATESTAMP}.${NodeType}.vmstat.txt" 2>&1 > /dev/null
     #download cpu data output file 
     echo "$passwd" | $PWDEXP $exp_debug scp $USER@$node:/tmp/${node}.${DATESTAMP}.${NodeType}.vmstat.txt ${OUTPUTDIR}/${DATESTAMP}/${node}.${DATESTAMP}.${NodeType}.vmstat.txt 2>&1 > /dev/null
   done
   
   # Add collection of DB2 data
   
   # Copy files to drop location if requested, This will publish files for each iteration to make the information
   # avaiable as soon as its collected rather than waiting until the end of the run.    
   if [ ! -z "$DROP_NODE"  -a ! -z "$PUSH_IMMEDIATE" ]; then    
       echo "Copying files to drop location: $DROP_NODE:$DROP_LOC/${DATESTAMP}"
       realm=`lssys $DROP_NODE | grep realm | grep -v authrealm | cut -c21- | cut -d. -f1`
       case $realm in
        y) passwd=$yz_passwd ;;
        g) passwd=$gz_passwd ;;
        b) passwd=$bz_passwd ;;
        *) echo "Failed to determine realm for DROP_NODE [$DROP_NODE]" 
           exit 1
           ;;
       esac 
       echo "$passwd" | $PWDEXP ssh $USER@$DROP_NODE "mkdir -p ${DROP_LOC}" 
       echo "$passwd" | $PWDEXP scp -r ${OUTPUTDIR}/${DATESTAMP} $USER@$DROP_NODE:$DROP_LOC   
       echo "$passwd" | $PWDEXP ssh $USER@$DROP_NODE "chgrp -R eiadm ${DROP_LOC}/${DATESTAMP} && find ${DROP_LOC}/${DATESTAMP} -type f -exec chmod 664 {} \; && find ${DROP_LOC}/${DATESTAMP} -type d -exec chmod 775 {} \;"
   fi      
      
   let count=$(($count+1)) 
   if [ "$count" != "$REPEAT" ]; then
       echo " "
       echo "Waiting ${INTERVAL} seconds before next iteration"
       sleep ${INTERVAL}
   fi     
done
  
# Copy files to drop location if requested  
if [ ! -z "$DROP_NODE" -a -z "$PUSH_IMMEDIATE" ]; then    
     echo "Copying files to drop location: $DROP_NODE:$DROP_LOC"
     realm=`lssys $DROP_NODE | grep realm | grep -v authrealm | cut -c21- | cut -d. -f1`
     case $realm in
       y) passwd=$yz_passwd ;;
       g) passwd=$gz_passwd ;;
       b) passwd=$bz_passwd ;;
       *) echo "Failed to determine realm for DROP_NODE [$DROP_NODE]" 
        exit 1
        ;;
     esac 
     echo "$passwd" | $PWDEXP ssh $USER@$DROP_NODE "mkdir -p ${DROP_LOC}" 
     echo "$passwd" | $PWDEXP scp -r ${OUTPUTDIR}/ $USER@$DROP_NODE:$DROP_LOC   
     echo "$passwd" | $PWDEXP ssh $USER@$DROP_NODE "chgrp -R eiadm ${DROP_LOC} && find ${DROP_LOC} -type f -exec chmod 664 {} \; && find ${DROP_LOC} -type d -exec chmod 775 {} \;"
fi   

chmod -R 775 ${OUTPUTDIR} 
chown -R $USER:eiadm ${OUTPUTDIR}
echo ""
echo "Local output is located at: ${OUTPUTDIR}"
echo ""
TIME=`date`
echo "Runtime statistics data collection has completed at: ${TIME}" 