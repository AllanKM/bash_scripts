#!/bin/sh
#
# MS backup 
# Usage:  ms_backup.sh {all] [prof] [-washome <washome>] [-descr <description>] 
#             prof      back up the profile  
#             all       back up all WAS stuff   
#             fs|sync   only full sync to fixed backup dir for the node 
#             config    run a WAS config only backup 
#             dirs      tar the bin and etc dirs - TODO 
#             msb|-msb  backup MS home directories  
#             -washome <washome>        default:  /usr/WebSphere70/AppServer  
#             -descr    description of the backup   
#    Examples:
#
#
# Script location: <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
# Backup dir:  /fs/backups/itcam/<node>    /Dateyyyymmddhhss-<desc>/
#
# Changes:
# 2014-09-24 Initial
# 2015-10-08 Support MS HOME backup 

SCRIPT_VERSION=1.06a
SCRIPTNAME=$(basename $0)
NODE=$(hostname -s)
DATE=$(date +"%Y%m%d%H%M")
WASHOME=/usr/WebSphere70/AppServer
WASPROFILE=$WASHOME/profiles/$NODE

PROJ_HOME="$WASHOME"          # Needed for full sync backup
BACKUP_LOC=/fs/backups/itcam
BACKUP_DIR=$BACKUP_LOC/$NODE

MSHOME=/opt/IBM/ITCAM

FS_DIR_LOC=""  # set in rsync function
FS_DIR_OVERRIDE=n   # always n

#arguments
DESCR="ITCAMMS_bk"
ALL="n"
CONFIG="n"
DIRS=n
PROFILE="n"
DEBUG=""
SYNC="n"
PWD="/"
ANY_SUCCESSES="n"

MS_BACKUP=n

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
     echo "No WAS-related backups created.. deleting  $BACKUP_INSTANCE"
     rm -rf $BACKUP_INSTANCE
  fi  
}

verify_input() {
    if [ ! -d $WASHOME ]; then
        echo "WebSphere home directory \"$WASHOME\" does not exist... terminating"
        exit 1    
    fi 
    if [ ! -d $WASPPROFILE ]; then
        echo "WASPPROFILE directory \"$WASPPROFILE\" does not exist... terminating"
        exit 1    
    fi 
   
}

# Locate arguments
    i=0
    while [ $i -le $# ]; do
      i=$((i + 1))
      eval parm=\${$i:-}
      case "$parm" in
        -all|all)
           ALL="y"
           ;;
        -config|config)
           CONFIG="y"
           ;;
        -msHomeBackup|-ms|-msb|ms|msb)
           MS_BACKUP=y
           ;;
        -prof)
           PROFILE="y"
           ;;
        -dirs|dirs)
           DIRS="y"
           ;; 
        -fs|fs|-sync|sync)
           SYNC="y"
           ;; 
           
        -debug|debug)
           DEBUG="debug"
           ;; 
        -washome|-wh)
           i=$((i + 1))
           eval WASHOME=\${$i:-}
           WASPPROFILE=$WASHOME/profiles/$NODE
           PROJ_HOME="$WASHOME"   
           ;;         
        -descr|-desc|desc|-ds)
           i=$((i + 1))
           eval DESCR=\${$i:-}
           ;;
         *)
           ;;
      esac
    done
    if [ $ALL == "y" ]; then 
       CONFIG="y"
       DIRS=y
    fi 
    echo "Input detected: ALL: $ALL, PROF: $PROFILE, WASHOME: $WASHOME DESCR: $DESCR"
    echo  "               SYNC: $SYNC, PROJ_HOME: $PROJ_HOME"
      
echo "$SCRIPTNAME version $SCRIPT_VERSION executing"
verify_input

if [ $(id -u) != 0 ]; then
    echo "This script requires root access"
    exit 1
fi

PWD=$(pwd) 

# Create BACKUP dirs if needed
if [ ! -d $BACKUP_LOC ]; then
    echo "Creating dir for $BACKUP_LOC"
    mkdir -m 755 $BACKUP_LOC  
    chown root:itmusers $BACKUP_LOC
fi
if [ ! -d $BACKUP_DIR ]; then
    echo "Creating dir for $BACKUP_DIR"
    mkdir -m 755 $BACKUP_DIR  
    chown root:itmusers $BACKUP_DIR
fi

#
# Backup MS HOME requested ?
#
if [[ $MS_BACKUP == y ]]; then
    echo "MS HOME $MSHOME dir backup requested"	  
 	  MS_BACKUP_INSTANCE=$BACKUP_DIR/MS_backup      # For now only one copy ..   .$DATE.$DESCR
    echo "MS_BACKUP_INSTANCE: $MS_BACKUP_INSTANCE"
    if [ ! -d $MS_BACKUP_INSTANCE ]; then
        echo "Creating dir for $MS_BACKUP_INSTANCE"
        mkdir -m 755 $MS_BACKUP_INSTANCE 
        chown root:itmusers $MS_BACKUP_INSTANCE
    fi
    rcmd="rsync -avq $MSHOME $MS_BACKUP_INSTANCE"
	  echo " Executing after 3 secs: "
	  echo "   $rcmd"
	  sleep 3
	  echo "     ... starting now"
	  $rcmd
	  check_rc
	  echo "MS HOME dir backup ...completed"	  
	  echo "Done"	
	  #exit 0
fi


#
# WAS full rsync backup only requested ?
#
if [ $SYNC == "y" ]; then
    echo "Full sync *only* backup requested..."	
    echo "   of $PROJ_HOME"
    fs_dir=$BACKUP_DIR/full_sync
    echo "   to $fs_dir"
	  if [ "$PROJ_HOME" == "" ]; then echo "  PROJ_HOME is required...terminating"; exit 1; fi
	  if [ ! -d $PROJ_HOME ]; then echo "  $PROJ_HOME not found....terminating"; exit 1; fi  	
	  
	  if [ $FS_DIR_OVERRIDE == n ]; then 
	  	if [ ! -d  $fs_dir ]; then
	  	  	echo "Creating full sync dir $fs_dir"
	  	  	mkdir -m 770 $fs_dir  
	  	  	chown root:itmusers $fs_dir 
	  	  	check_rc
	  	fi	
	  	fs_loc=$( echo $PROJ_HOME | tr '/' '_')
	  	if [ ! -d $fs_dir/${fs_loc}_backup ]; then 
	      	echo "Creating full sync dir for project: $fs_dir/${PROJ_HOME}_backup "
	  	  	mkdir -m 770 $fs_dir/${fs_loc}_backup
	  	  	chown root:itmusers $fs_dir/${fs_loc}_backup
	  	  	check_rc
	  	fi	
	  	FS_DIR_LOC=$fs_dir/${fs_loc}_backup
	  fi
	  echo "   to $FS_DIR_LOC"
	  	
	  rcmd="rsync -avq $PROJ_HOME $FS_DIR_LOC"
	  echo " Executing after 3 secs: "
	  echo "   $rcmd"
	  sleep 3
	  $rcmd
	  check_rc
	  
	  echo "Full sync backup ...completed rc=0"
	  echo "Done"	
	  exit 0
fi

# Not a full sync back 
# Create a directory for this backup instance  
#
BACKUP_INSTANCE=$BACKUP_DIR/"backup".$DATE.$DESCR
echo "BACKUP_INSTANCE: $BACKUP_INSTANCE"
if [ ! -d $BACKUP_INSTANCE ]; then
    echo "Creating dir for $BACKUP_INSTANCE"
    mkdir -m 755 $BACKUP_INSTANCE 
    chown root:itmusers $BACKUP_INSTANCE
fi

#
# Backup Profile - the safe way 
# Profile will be the top dir of the backup
#
if [ "$PROFILE" == "y" ] ; then
  if [ -d $WASPROFILE ]; then
    echo "Backing up profile at $WASPROFILE"
    echo " .... this will take awhile.. "
    PROFILE_zip=$BACKUP_INSTANCE/$NODE_profile.$DATE.$DESCR.zip
    cd $WASPROFILE/../ 
    zip -qry $PROFILE_zip TIPProfile
    # test existance of file ? 
    check_rc 
    ANY_SUCCESSES="y" 
    cd $PWD   
  else
    echo "No dir located at $WASPROFILE"
    cleanup
    echo "...terminating"
    exit 1
  fi  
fi  


#
# Backup TIPProfile config
#   -nostop -profileName Nnode> -trace  -user tipadmin    
# 
# hold this 
#if [ $CONFIG == "y" ] ; then
#    BACKUP_zip=$BACKUP_INSTANCE/WebSphere_$NODE_ProfileConfig_$DATE.zip
#    trace=""
#    if [ DEBUG == "debug" ]; then
#        trace=" -trace "  
#    fi  
#    cd  $WASPPROFILE/bin  
#    echo "Backing up  WebSphere config for profile $NODE"   
#    ./backupConfig.sh $BACKUP_zip -nostop -profileName $NODE $trace
#    check_rc 
#    echo "Backing up  WebSphere config ...complete"
#    ANY_SUCCESSES="y" 
#    cd $PWD   
#fi  
  

#
# Cleanup if needed
#
cleanup 

#
echo "$SCRIPTNAME completed rc=0" 

exit 0
