#!/bin/sh

# TODO:
#  - Derive the default project directory from washome.
#
# TIP permissions updater 
#  
# 1. Creates WAS logs directory if needed. Default /logs/was70/TIPProfile 
# 2. Creates $TIPPROFILE/logs symlink if the symlink does not exist
# 3  Updates WAS permissions and ownership as requided by TIP type 
# 4. If TCR 2.1, refreshes the special unrestricted SDK security policy jars  
#
# Usage: tip_perms.sh [-projroot $projroot] [-washome $washome ] [-tipid TCR|TAD|NCO] 
#                     [-user $user] [-group $group] [-xperms] [-logdir $logdir]   
#          -projroot $projroot  Project root directory Default: /usr/WebSphere70   
#          -washome $washome  WebSphere home Default: /usr/WebSphere70/AppServer   
#                           If projroot indicates NCO( dir contains netcool) or TCR ( dir contains TCR),
#                              washome default is $projroot/tip              
#          -tipid TCR|TAD|NCO Overrides script determined value which is based on directory name         
#          -user  $user     Owner userid     Default: TAD:  webinst  For NCO:    For TCR:  
#          -group $group    Owner group      Default: TAD:  eiadm    For NCO:    For TCR:   
#          -xperms|xwas     Bypass setting ownership and permissions 
#          -logdir $logdir  Log directory for TIPProfile/logs 
#                                            Default: /logs/was70/TIPProfile 
#                                               Recommended if only one TIP is running on this node
#                                            For logrotate and LCS, need to use /logs/was70
#          
#  Example 1:
#      WASHOME=/opt/IBM/TCR1/tip
#      PROJROOT=/opt/IBM/TCR1  
#      cd /lfs/system/tools/tip/setup            
#      sudo ./tip_perms.sh -projroot $PROJROOT -washome $WASHOME -user webinst -group itmusers 
#   Example 2:
#      PROJROOT=/opt/IBM/Netcool
#      cd  /lfs/system/tools/tip/setup
#      sudo ./tip_perms.sh -projroot $PROJROOT 
#
# Changes:
#  2013-06-07  TIP version created 
#  2013-07-10  Change NCO ownership/permissions 
#  2013-10-04  Change NCO directory ownership                   
#  2014-07-28  Simplify NCO.
#  2014-08-21  Remove some of the NCO continue prompts 
#              Create $WASLOGS/server1
#  2014-09-13  Support NCO support for /opt/IBM/Netcool/.java
#  2015-02-25  Make sure owner-perms of .java is set correctly.
#              Looks like a needed line may not have been included in the IIOSB-deployed
#              version. Setting VERSION=1.03c            
#  2015-02-26  NCO work - Go back to setting java home and below to 775
#                         Slight mod to how we set owner-perms
#  2015-04-08  Support dci-common, currently only in /logs/dci-common 
#
# Model:  /lfs/system/tools/was/setup/was_perms.ksh 
# 
VERSION=1.03e
SCRIPTNAME=$(basename $0)
SRC_POLICY_JARS=/fs/system/images/sysmgmt/analysis/AIX/TCR/2.1.1/SDK_unrestricted_security_policy_jars

# Defaults that can be overriden by arguments
WASHOME=/usr/WebSphere70/AppServer
TIPPROFILE=$WASHOME/profiles/TIPProfile
PROJROOT=/usr/WebSphere70
USERID=webinst 
GROUP=eiadm
WASLOGS=/logs/was70/TIPProfile 
 
COGNOSLOGS=/logs/was70/cognos 
TIPID=""            # TAD, NCO, TCR. The default is set using WASHOME value  

LOGPERMS=775
DATE=$(date +"%Y%m%d%H%M")
BYPASS_PERMS="n"
BYPASS_PROMPT="n"
BYPASS_POLICY_JAR_REFRESH="n"

BYPASS_SYMLINK="n"
BYPASS_COGNOS_SYMLINK="n"

PROJECT_ROOT_OVERRIDE="n"
WASHOME_OVERRIDE="n"
USERID_OVERRIDE="n"
GROUP_OVERRIDE="n"
COGNOS_HOME=""

#
# Update project root and logs directories
#
# Input: $USERID $GROUP $PROJROOT $WASLOGS $WASHOME $TIPPROFILE
#
# If NCO:
#   Simplified 07-2014
#   Previously:  
#     These directories need ownership: netcool:itmusers
#	       tip, tipComponents, .java, omnibus_webgui, precision 
#     These others need ownership of root:eiadm 
#     Permissions: 755 
#
update_ownership_permissions() {
	echo
  echo "Setting ownership and permissions"
  # If standard WAS location, assume TAD and we want to use standard WAS ownership and permissions
  if [ $PROJROOT == "/usr/WebSphere70" -o $PROJROOT == "/usr/WebSphere80" -o $PROJROOT == "/usr/WebSphere85"  ]; then 
     echo " Calling standard WAS was_perms.ksh for ownership and permissions"  
     /lfs/system/tools/was/setup/was_perms.ksh 
     echo " Calling standard WAS was_perms.ksh...complete"  
  else  
     # Netcool OMNIBus WebGUI 
     if [ $TIPID == "NCO" ]; then
        ##
        #1. High level project directory 
        ##
        echo "Setting ownership/perms for NCO: $PROJROOT"
        
        # Perms are 775 for /opt/IBM/Netcool   ## Issue ! 

        echo 1. Executing: chmod -Rh 775 $PROJROOT  
        chmod -Rh 775 $PROJROOT 
        check_rc 
      	# no  echo x      chmod -Rh 770 $PROJROOT/tip  

        echo 2. Executing: chown -Rh root:itmusers $PROJROOT
      	chown -Rh root:itmusers $PROJROOT
        check_rc

        sleep 1
        
        ##
        #2. Sub-directories
        #         sudo chown -Rh netcool:itmusers /opt/IBM/Netcool/omnibus_webgui 
        #         sudo chown -Rh netcool:itmusers /opt/IBM/Netcool/tip 
        #         sudo chown -Rh netcool:itmusers /opt/IBM/Netcool/tipComponents
        ##
        dir1="/opt/IBM/Netcool/omnibus_webgui"
        dir2="/opt/IBM/Netcool/tip"
        dir3="/opt/IBM/Netcool/tipComponents"
        dir4="/opt/IBM/Netcool/.java"
        
       	echo 3. Setting different ownership for NCO sub directories
        dirs="$dir1 $dir2 $dir3 $dir4"   
        for dir in $dirs; do 
            dir_chown="chown -Rh netcool:itmusers $dir"
            if [ -d $dir ]; then 
                echo "    Executing: $dir_chown"	 
                $dir_chown
                check_rc
            else
                echo "  WARNING: directory not found: $dir"     
            fi    
        done 
        echo "Setting ownership/perms for NCO sub directories...complete"
             
          
        #3 WAS logs -- should it be 775 or 770 ?
        echo "Setting ownership/permissions of $WASLOGS to $USERID:$GROUP  775, g+s"  
        echo "    Executing:  chown -Rh $USERID:$GROUP $WASLOGS "   
        chown -Rh $USERID:$GROUP $WASLOGS  
        echo "    Executing:  chmod g+s $WASLOGS  "   
        chmod g+s $WASLOGS  
        echo "    Executing:  chmod -Rh ugo+rwx,o-w  $WASLOGS  "    
        chmod -Rh ugo+rwx,o-w  $WASLOGS    
      
        #4 Update WAS bin directories 
        echo "Setting ownership/permissions of WASHOME/bin and TIPPROFILE/bin directories"  
        echo "    Issuing  find type f -exec chmod g-x {} "      
        find  $WASHOME/bin/ -type f -exec chmod g-x {} \;   
        find  $TIPPROFILE/bin/ -type f -exec chmod g-x {} \; 
        echo "Setting ownership/permissions of WAS and TIP bin directories...complete" 
    
        #5 If /logs/dci-common exists, update 
        #      Perhaps we should set to netcool:itmusers ?
        if [ -d /logs/dci-common ]; then
            echo "Setting ownership/permissions of /logs/dci-common"  
            echo "    Executing:  chown -R root:itmusers /logs/dci-common"    	
            chown -R root:itmusers /logs/dci-common
            echo "    Executing:  chmod -R 775 /logs/dci-common"    	
            chmod -R 775 /logs/dci-common
            #echo "    Executing:  chmod g+s /logs/dci-common"
            #chmod g+s /logs/dci-common
            echo "Setting ownership/permissions of /logs/dci-common...complete"  
        fi	
      
    else
        # Not NCO   Permissions 755.  
        echo "Setting ownership and permissions of $PROJROOT to $USERID:$GROUP"
        echo "  This will take awhile"
        chown -Rh $USERID:$GROUP $PROJROOT* $WASLOGS  
        chmod g+s $PROJROOT* $WASLOGS  
        chmod -Rh ug+rwx,o-rwx $PROJROOT* $WASLOGS  
        find  $WASHOME/bin/ -type f -exec chmod g-x {} \;  
        find  $TIPPROFILE/bin/ -type f -exec chmod g-x {} \; 
        echo "Setting ownership and permissions...complete" 
    fi
  fi   
}   

# Determine type of TIP (TAD, NCO, TCR) based on WASHOME 
# if -tipid argument was not supplied 
# Input WASHOME Output:TIPID    
determine_default_TIPID(){
  if [ "$TIPID" == "" ]; then
    # Default is TAD  
    TIPID=TAD 
    was_home_is_nco=$(echo $WASHOME | tr '[:upper:]' '[:lower:]'   |  grep 'netcool' )
    if [ $? -eq 0 ]; then 
      [ -n "$DEBUG" ] && echo " TIPID is NCO from $WASHOME "
      TIPID=NCO
      return 
    fi  
    was_home_is_tcr=$(echo $WASHOME | tr '[:upper:]' '[:lower:]'   |  grep 'tcr' )
    if [ $? -eq 0 ]; then 
      [ -n "$DEBUG" ] && echo " TIPID is TCR from $WASHOME "
      TIPID=TCR
      return 
    fi
    proj_root_is_nco=$(echo $PROJROOT | tr '[:upper:]' '[:lower:]'   |  grep 'netcool' )
    if [ $? -eq 0 ]; then 
      [ -n "$DEBUG" ] && echo " TIPID is NCO from $PROJROOT "
      TIPID=NCO
      return 
    fi  
    proj_root_is_tcr=$(echo $PROJROOT | tr '[:upper:]' '[:lower:]'   |  grep 'tcr' )
    if [ $? -eq 0 ]; then 
      [ -n "$DEBUG" ] && echo " TIPID is TCR from $PROJROOT "
      TIPID=TCR
      return 
    fi
  fi  
}

# Update options not supplied by arguments, based on TIPID 
# Runs immediately after determine_default_TIPID which runs after the argument scan   
# Input: TIPID Output:  USERID, GROUP, PROJROOT 
# TODO - get default PROJROOT from WASHOME  
update_options() {
  # Netcool OMNIBus WebGUI 
  if   [ $TIPID == "NCO" ]; then
    if [ $PROJECT_ROOT_OVERRIDE == "n" ]; then
          PROJROOT=/opt/IBM/Netcool      
    fi  
    if [ $USERID_OVERRIDE == "n" ]; then       
          USERID=netcool
    fi
    if [ $GROUP_OVERRIDE == "n" ]; then       
          GROUP=itmusers
    fi
  # TCR  
  elif [ $TIPID == "TCR" ]; then  
    if [ $PROJECT_ROOT_OVERRIDE == "n" ]; then
          PROJROOT=/opt/IBM/TCR      
    fi  
    if [ $USERID_OVERRIDE == "n" ]; then   
          USERID=webinst     
    fi
    if [ $GROUP_OVERRIDE == "n" ]; then       
          GROUP=itmusers  
    fi
    #if [ $TIPID == "TCR" ]; then
    if [ "$COGNOS_HOME" == "" ]; then
        COGNOS_HOME=$PROJROOT/tipComponents/TCRComponent/cognos  
    fi
    #fi  
  fi
  if [ $TIPID == "NCO" -o $TIPID == "TCR" ]; then
    if [ $WASHOME_OVERRIDE == "n" ]; then
       WASHOME=$PROJROOT/tip   
    fi   
  fi  
  TIPPROFILE=$WASHOME/profiles/TIPProfile
      
}


# TCR EI local ldap support requires this  
# Input: $WASHOME/java/jre/lib/security           
#        /fs/system/images/TIP/SDK/unrestrictJCEPolicyFilesPriorToSR16  local_policy.jar and US_export_policy.jar 
refresh_64bit_policy_jars() {
  [ -n "$DEBUG" ] && echo "Enter refresh_64bit_policy_jars"
  
  SRCJARS=$SRC_POLICY_JARS
  # /fs/system/images/TIP/SDK/unrestrictJCEPolicyFilesPriorToSR16 
  
  JRELIBSECURITY=$WASHOME/java/jre/lib/security
  POLICYJAR=local_policy.jar
  EXPORTJAR=US_export_policy.jar 
  echo "Refreshing SDK $POLICYJAR and $EXPORTJAR for TCR use"  
  echo "   using $SRCJARS"
  if [ -e $JRELIBSECURITY/$POLICYJAR -a -e $JRELIBSECURITY/$EXPORTJAR ]; then 
    cp -p $JRELIBSECURITY/$POLICYJAR $JRELIBSECURITY/$POLICYJAR.$DATE
    cp -p $JRELIBSECURITY/$EXPORTJAR $JRELIBSECURITY/$EXPORTJAR.$DATE
    cp  $SRCJARS/$POLICYJAR  $JRELIBSECURITY
    cp  $SRCJARS/$EXPORTJAR  $JRELIBSECURITY
    echo "  copy operation executed"
  else
    echo "..ERROR Refreshing SDK jars failed.. they do not exist at:"
    echo "        $JRELIBSECURITY" 
    echo "..      Script terminating..."
    exit 1
  fi    
}   
 
pause() {
    echo "\nPausing 4 seconds"
    sleep 4
    echo    
}
# Issue prompt to contunue or briefly pause
prompt_to_continue() {
    echo 
    if [ $BYPASS_PROMPT == "n" ]; then
        echo "\nHit any key to continue, or cancel(CNTL-c) to quit"  
        read -r choice 
    else
        pause    
    fi
}
check_rc() {
  if [ $? -ne 0 ]; then 
    echo "...command failed...terminating"
    exit 1
  fi  
}

# Display all input arguments and obtain confirmation to continue  
confirm_input() {
  echo "Confirm input:\n"
  echo "..WebSphere home(-washome): $WASHOME"     
  echo "..Project root(-projroot):  $PROJROOT" 
  echo "..TIP app type(-tipid):     $TIPID" 
  echo "..User(-user):              $USERID" 
  echo "..Group(-group):            $GROUP"
  echo "..Log directory(-logdir):   $WASLOGS"
  echo "..Bypass perms/owner upd    $BYPASS_PERMS"
  if [ $TIPID == "TCR" ]; then
    echo "..Cognos home(-cognoshome)  $COGNOS_HOME"  
    echo "..Cognos logs(-cognoslogs)  $COGNOSLOGS"  
    echo "..Bypass policy jar update  $BYPASS_POLICY_JAR_REFRESH" 
  fi  
  echo 
 
  prompt_to_continue
}   
 
verify_input() {
  if [ ! -d $WASHOME ]; then
    echo "WebSphere home directory does not exist: $WASHOME...terminating"
    exit 1         
  fi
  if [ ! -d $TIPPROFILE ]; then
    echo "TIPprofile does not exist at: $TIPPROFILE...terminating"
    exit 1         
  fi
}   

echo "$SCRIPTNAME version $VERSION executing"
if [ $(id -u) != 0 ]; then
    echo "This script requires root access"
    exit 1
fi

# Locate arguments especially ones that override defaults
    i=0
    while [ $i -le $# ]; do
      i=$((i + 1))
      eval parm=\${$i:-}
      case "$parm" in
        -debug|debug)
           DEBUG="debug"
           ;; 
        -bypassPrompt|-bp|-silent|bp|silent)
           BYPASS_PROMPT="y"
           ;;    
        -xwas|bypassperms|xperms|bperms|-xperms|-bperms)
           BYPASS_PERMS="y"
           ;; 
        -bypassPolicyUpdate|-bpu|bpu)
           BYPASS_POLICY_JAR_REFRESH="y"
           ;; 
        -washome|-wh)
           i=$((i + 1))
           eval WASHOME=\${$i:-}
           WASHOME_OVERRIDE="y"
           TIPPROFILE=$WASHOME/profiles/TIPProfile
           ;; 
        -projroot|-pr)
           i=$((i + 1))
           eval PROJROOT=\${$i:-}
           PROJECT_ROOT_OVERRIDE="y"
           ;;                    
        -user|-u)
           i=$((i + 1))
           eval USERID=\${$i:-}
           USERID_OVERRIDE="y"
           ;;         
        -group|-g)
           i=$((i + 1))
           eval GROUP=\${$i:-}
           GROUP_OVERRIDE="y"
           ;; 
      	-logdir|-waslogs|waslogs|-ld)
           i=$((i + 1))
           eval WASLOGS=\${$i:-}
           ;;  
      	-cognoslogs)
           i=$((i + 1))
           eval COGNOSLOGS=\${$i:-}
           ;;  
      	-cognoshome)
           i=$((i + 1))
           eval COGNOS_HOME=\${$i:-}
           ;;      
        -tipid)
           i=$((i + 1))
           eval TIPID_OVERRIDE_VALUE=\${$i:-}
           TIPID_OVERRIDE_VALUE=$(echo $TIPID_OVERRIDE_VALUE | tr '[:lower:]' '[:upper:]')
           TIPID=$TIPID_OVERRIDE_VALUE
           ;;                                      
         *)
           ;;
      esac
    done
    [ -n "$DEBUG" ] && echo "After argument scan: "
    [ -n "$DEBUG" ] && echo "  Input detected: DEBUG=$DEBUG, BYPASS_PERMS=$BYPASS_PERMS, USERID=$USERID, GROUP=$GROUP"
    [ -n "$DEBUG" ] && echo "  PROJROOT=$PROJROOT, WASHOME=$WASHOME, WASLOGS=$WASLOGS"
    [ -n "$DEBUG" ] && echo "  TIPID=$TIPID"
    # If -tipid not supplied, determine the value lased on WASHOME 
    determine_default_TIPID
    [ -n "$DEBUG" ] && echo "After determine_default_TIPID TIPID=$TIPID"
    update_options
    [ -n "$DEBUG" ] && echo "After update_options: PROJROOT=$PROJROOT, WASHOME=$WASHOME USERID=$USERID, GROUP=$GROUP "
    
# Confirm and the input before continuing
confirm_input

verify_input

echo "TIP app based on WASHOME is: $TIPID"

# 1. Create WAS logs directory and symlink if needed
# TODO - improve this  - it doewsn't support the WAS log override capability 
echo "Examine logs directory:  $WASLOGS" 
if [ ! -d $WASLOGS ]; then
    echo "...Try to create directory $WASLOGS"   
    echo $WASLOGS | grep '/logs/was70' > /dev/null 2>&1 
    if [ $? -eq 0 ]; then 
      # Fix this in case WASLOGS override supplied
      if [ ! -d /logs/was70 ]; then
        echo "...Creating directory /logs/was70"
        mkdir -m $LOGPERMS /logs/was70
        chown -R $USERID:$GROUP /logs/was70
      fi
    fi       
    mkdir -m $LOGPERMS $WASLOGS 
    if [ $? -ne 0 ]; then 
        echo "....Creating directory failed....please correct problem and resubmit"
        exit 1
    else
        echo "....Directory created $WASLOGS"     
    fi       
fi
if [ ! -d $WASLOGS/server1 ]; then
    echo "...Try to create directory $WASLOGS/server1"
	  mkdir -m $LOGPERMS $WASLOGS/server1
	  chown -R $USERID:$GROUP $WASLOGS/server1
fi
	  
echo "...setting ownership of $WASLOGS to $USERID:$GROUP" 
chown -R $USERID:$GROUP $WASLOGS
chmod -R $LOGPERMS $WASLOGS 

# 1.2 Create Cognos logs directory 
if [ $TIPID == "TCR" ]; then
  if [ ! -d $COGNOSLOGS ]; then  
    echo "...Creating directory $COGNOSLOGS"   
    mkdir -m $LOGPERMS $COGNOSLOGS 
    if [ $? -ne 0 ]; then 
        echo "....Creating directory failed....please correct problem and resubmit"
        exit 1
    else
        echo "....Directory created $COGNOSLOGS"     
    fi                 
  fi  
  echo "...setting ownership and permissions of $COGNOSLOGS to $USERID:$GROUP" 
  chown -R $USERID:$GROUP $COGNOSLOGS
  chmod -R $LOGPERMS $COGNOSLOGS
fi  
    
# 2.1 Create a symlink TIPProfile/logs --> /logs/was70/TIPProfile
#     All TIP types( TAD, NCO, TCR, etc) 
#     TODO - improve this. 
if [ -L $TIPPROFILE/logs ]; then
    ## echo "TIPProfile/logs is already a symlink..remove it "  
    ## #mv $TIPPROFILE/logs $TIPPROFILE/logs.bkup
    ## rm -f $TIPPROFILE/logs
    echo "...TIPProfile/logs is already a symlink..leave it alone"  
    BYPASS_SYMLINK="y"
else  
    echo "...Renaming WAS TIPProfile/logs directory to logs.$DATE"  
    mv $TIPPROFILE/logs $TIPPROFILE/logs.$DATE 
fi
if [ $BYPASS_SYMLINK == "n" ]; then
  echo "...Creating symlink for $TIPPROFILE/logs to $WASLOGS" 
  ln -s  $WASLOGS  $TIPPROFILE/logs 
fi  
  
# 2.2 If TCR create the COGNOS logs symlink  -->  /logs/was70/cognos   
if [ $TIPID == "TCR" ]; then
    if [ -L $COGNOS_HOME/logs ]; then  
        echo "...cognos/logs is already a symlink..leave it alone"  
        BYPASS_COGNOS_SYMLINK="y"
    else  
        echo "...Renaming cognos_home/logs directory to logs.$DATE"  
        mv $COGNOS_HOME/logs  $TIPPROFILE/logs.$DATE 
    fi
    if [ $BYPASS_COGNOS_SYMLINK == "n" ]; then
        echo "...Creating symlink for $COGNOS_HOME/logs to $COGNOSLOGS " 
        ln -s  $COGNOSLOGS  $COGNOS_HOME/logs 
    fi
fi      



# 3. Update WAS permissions 
#    The WAS script will set perms to 770 and ownership to webinst:eiadm 
if [ $BYPASS_PERMS == "n" ]; then
    update_ownership_permissions
else
    echo "WAS Ownership/permissions bypassed by request"   
fi

# 4. Refresh the security policy jars on TCR systems
if [ $TIPID == "TCR" ]; then
  if [ $BYPASS_POLICY_JAR_REFRESH == "n" ]; then
    refresh_64bit_policy_jars 
  else
    echo "TCR TIP refresh of policy jars bypassed on request"  
  fi
fi
echo "$SCRIPTNAME completed" 

exit 0
