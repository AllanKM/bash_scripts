#!/bin/sh
#
# TIP backup
# Usage:  tip_backup.sh {all] [tip} [fs -ph <proj_home> -fsd <fs-dir>] [tcr [-tcrdir $TCRDIR]] [-washome <washome>] [-descr <description>] 
#             tip       back up the TIPProfile 
#             tcr       backup the TCR component directories     
#             all       back up all   
#             fs|sync   full sync to fixed backup dir for the node 
#             -fsd      overrids loc of rsync target  if fs specified  
#             -washome <washome>        default:  /usr/WebSphere70/AppServer  
#             -tcrdir  <TCR home dir>   default   <WAS_HOME>/../tipComponents/TCRComponent 
#             desc|descr   description of the backup   
#    The default WAS home directory is not good for most TIP installs
#    Examples:
#
#
# Limitations:
# 1. Does not backup the entire TCR or webGUI installation. 
#
# Backup dir:  /fs/backups/tip/<node>/Dateyyyymmddhhss-<desc>/
#
# Changes:
# 2013-05-24 MEC Fix pwd issue. Allow both descr and desc arguments.
# 2013-06-07 MEC Support flexible WASHOME and TCR component
# 2013-10-09 MEC Update descr help and argument   
# 2014-07-28 MEC Support full sync backup

SCRIPT_VERSION=1.04a
SCRIPTNAME=$(basename $0)
# Default - WASHOME can be overriden in the arguments 
WASHOME=/usr/WebSphere70/AppServer
TIPPROFILE=$WASHOME/profiles/TIPProfile
TCRDIR=$WASHOME/../tipComponents/TCRComponent
NODE=$(hostname -s)
DATE=$(date +"%Y%m%d%H%M")

PROJ_HOME=""          # Needed for full sync backup
BACKUP_LOC=/fs/backups/tip
BACKUP_DIR=$BACKUP_LOC/$NODE

FS_DIR_LOC=""
FS_DIR_OVERRIDE=n

#arguments
DESCR="TIP_bk"
ALL="n"
CONFIG="n"
TIP="n"
TCR="n"
DEBUG=""
SYNC="n"
PWD="/"
ANY_SUCCESSES="n"
check_rc() {
  if [ $? -eq 0 ]; then 
    echo "...backup step ended with rc=0"
  else
    echo "...backup step took non-zero return code"  
    echo "...backup terminating"
    cd $PWD
    cleanup
    exit 1
  fi
}

cleanup() {
  if [ $ANY_SUCCESSES == "n" ]; then
     echo "No backups created.. deleting  $BACKUP_INSTANCE"
     rm -rf $BACKUP_INSTANCE
  fi  
}

verify_input() {
	if [ $SYNC == n ]; then 	
    if [ ! -d $WASHOME ]; then
        echo "WebSphere home directory \"$WASHOME\" does not exist... terminating"
        exit 1    
    fi 
    if [ ! -d $TIPPROFILE ]; then
        echo "TIPProfile directory \"$TIPPROFILE\" does not exist... terminating"
        exit 1    
    fi 
    if [ $TCR == "y" ]; then
        TCRDIR=$WASHOME/../tipComponents/TCRComponent
        if [ ! -d $TCRDIR ]; then    
            echo "WARNING: TCR directory \"$TCRDIR\" does not exist... No TCR backup possible..continuing"
            TCR="n"
        fi
    fi  
  else
  	if [ $FS_DIR_OVERRIDE == y ]; then
  	  if [ ! -d $FS_DIR_LOC ]; then
  	  	 echo "fs override backup directory not found: $FS_DIR_LOC..terminating"
  	    	exit 1  		
      fi
    fi  
  fi  	
    echo "Pausing for 3 seconds..."
    sleep 3              
}

# Locate arguments
    i=0
    while [ $i -le $# ]; do
      #i=$(expr $i + 1)
      i=$((i + 1))
      eval parm=\${$i:-}
      case "$parm" in
        -all|all)
           ALL="y"
           ;;
        -config|config)
           CONFIG="y"
           ;;
        -tip|tip)
           TIP="y"
           ;;
        -tcr|tcr)
           TCR="y"
           ;;   
        -fs|fs|-sync|sync)
           SYNC="y"
           ;;     
        -ph|-projHome)
           i=$((i + 1))
           eval PROJ_HOME=\${$i:-}
           ;;     
        -debug|debug)
           DEBUG="debug"
           ;; 
         -fsd)
           i=$((i + 1))
           eval FS_DIR_LOC=\${$i:-}
           FS_DIR_OVERRIDE=y
           ;;           
        -washome|-wh)
           # i=$(expr $i + 1)
           i=$((i + 1))
           eval WASHOME=\${$i:-}
           TIPPROFILE=$WASHOME/profiles/TIPProfile
           ;;         
        -tcrdir)
           i=$((i + 1))
           eval TCRDIR=\${$i:-}
           ;;         
        -descr|-desc|desc|-ds)
           # i=$(expr $i + 1)
           i=$((i + 1))
           eval DESCR=\${$i:-}
           ;;
         *)
           ;;
      esac
    done
    if [ $ALL == "y" ]; then 
       TIP="y";
       TCR="y"
       CONFIG="y"
    fi 
    # echo "Input detected: ALL: $ALL, TIP: $TIP, TCR: $TCR, CONFIG: $CONFIG WASHOME: $WASHOME DESCR: $DESCR"
    echo "Input detected: ALL: $ALL, TIP: $TIP, TCR: $TCR, WASHOME: $WASHOME DESCR: $DESCR"
    echo  "               SYNC: $SYNC, PROJ_HOME: $PROJ_HOME"
    echo  "               FS_DIR_OVERRIDE: $FS_DIR_OVERRIDE "
    if [ $TCR == "y" ]; then
        echo "...TCRDIR: $TCRDIR"    
    fi 
    if [ $FS_DIR_OVERRIDE == y ]; then
        echo  "               FS_DIR_LOC: $FS_DIR_LOC"    	
    fi  
    sleep 3
    
echo "$SCRIPTNAME version $SCRIPT_VERSION executing"
verify_input

if [ $(id -u) != 0 ]; then
    echo "This script requires root access"
    exit 1
fi

PWD=$(pwd) 

# Create tip and tip/<node> if needed
if [ ! -d $BACKUP_LOC ]; then
    echo "Creating dir for $BACKUP_LOC"
    mkdir -m 755 $BACKUP_LOC  
fi
if [ ! -d $BACKUP_DIR ]; then
    echo "Creating dir for $BACKUP_DIR"
    mkdir -m 755 $BACKUP_DIR  
fi

#
# full rsync backup requested
#
if [ $SYNC == "y" ]; then
    echo "Full sync *only* backup requested..."	
    fs_dir=$BACKUP_DIR/full_sync
    echo "   to $fs_dir"
	  if [ "$PROJ_HOME" == "" ]; then echo "  PROJ_HOME is required...terminating"; exit 1; fi
	  if [ ! -d $PROJ_HOME ]; then echo "  $PROJ_HOME not found....terminating"; exit 1; fi  	
	  
	  if [ $FS_DIR_OVERRIDE == n ]; then 
	  	if [ ! -d  $fs_dir ]; then
	  	  	echo "Creating full sync dir $fs_dir"
	  	  	mkdir -m 770 $fs_dir  
	  	  	check_rc
	  	fi	
	  	fs_loc=$( echo $PROJ_HOME | tr '/' '_')
	  	if [ ! -d $fs_dir/${fs_loc}_backup ]; then 
	      	echo "Creating full sync dir for project: $fs_dir/${PROJ_HOME}_backup "
	  	  	mkdir -m 770 $fs_dir/${fs_loc}_backup
	  	  	check_rc
	  	fi	
	  	FS_DIR_LOC=$fs_dir/${fs_loc}_backup
	  fi
	  	
	  # rcmd="rsync -avq $PROJ_HOME $fs_dir/${fs_loc}_backup"
	  rcmd="rsync -avq $PROJ_HOME $FS_DIR_LOC"
	  echo " Executing after 3 secs: "
	  echo "   $rcmd"
	  sleep 3
	  $rcmd
	  check_rc
	  
	  echo "Full sync backup ...completed rc=0"	
	  exit 0
fi
# Create a directory for this backup instance  
#
BACKUP_INSTANCE=$BACKUP_DIR/"backup".$DATE.$DESCR
echo "BACKUP_INSTANCE: $BACKUP_INSTANCE"
if [ ! -d $BACKUP_INSTANCE ]; then
    echo "Creating dir for $BACKUP_INSTANCE"
    mkdir -m 755 $BACKUP_INSTANCE  
fi

#
# Backup TIPProfile - the safe way 
# TIPProfile will be the top dir of the backup
# TODO: Good to have WAS down - add check to see if it's running 
#
if [ $TIP == "y" ] ; then
  if [ -d $TIPPROFILE ]; then
    echo "Backing up TIPProfile at $TIPPROFILE"
    echo " .... this will take awhile.. "
    PROFILE_zip=$BACKUP_INSTANCE/TIPProfile.$DATE.$DESCR.zip
    cd $TIPPROFILE/../ 
    zip -qry $PROFILE_zip TIPProfile
    # test existance of file ? 
    check_rc 
    ANY_SUCCESSES="y" 
    cd $PWD   
  else
    echo "No TIPProfile located on this server at $TIPPROFILE"
    cleanup
    echo "...terminating"
    exit 1
  fi  
fi  


#
# Backup TCR component directory 
# TCRComponent  will be the top dir of the backup
#
if [ $TCR == "y" ] ; then
    echo "Backing up TCR directory at $TCRDIR"
    TCR_zip=$BACKUP_INSTANCE/TCRdir.$DATE.$DESCR.zip
    cd $TCRDIR/../ 
    zip -qry $TCR_zip TCRComponent
    check_rc 
    ANY_SUCCESSES="y" 
    cd $PWD   
fi  

#
# Backup TIPProfile config
#   -nostop -profileName TIPProfile -trace  -user tipadmin    
# 
if [ $CONFIG == "y" ] ; then
    BACKUP_zip=$BACKUP_INSTANCE/WebSphereTIPProfileConfig_$DATE.zip
    trace=""
    if [ DEBUG == "debug" ]; then
        trace=" -trace "  
    fi  
    cd  $TIPPROFILE/bin  
    echo "Backing up  WebSphere config for TIPProfile"   
    ./backupConfig.sh $BACKUP_zip -nostop -profileName TIPProfile $trace
    check_rc 
    echo "Backing up  WebSphere config for TIPProfile...complete"
    ANY_SUCCESSES="y" 
    cd $PWD   
fi  
  

#
# Cleanup if needed
#
cleanup 

#
echo "$SCRIPTNAME completed rc=0" 

exit 0
