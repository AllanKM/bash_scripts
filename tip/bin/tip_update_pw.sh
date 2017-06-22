#!/bin/sh
#
##########################################################################################################
# Update the TIP Tivoli Integrated Portal password
#
#   Usage:  tip_update_pw.sh -newpw <new_password> [-washome <WAS_HOME>] [-oldpw <current_pw>] 
#                            [-user <wsadmin_exec_userid>]
#                            [-traceout <wsadmin traceout path>]           
#                            [-backupcfg_-bcf] [-backupcfgONLY|-bco] [-listTIPS] 
#                            [-test] [-debug|-d] 
#   App server restart is not required 
# 
#   Assumptions: 
#   1. WAS local admin userid is tipadmin
#   Examples:
#   1. Update password for WAS HOME  /usr/WebSphere70/AppServer if no user/pw in soap.client.props
#       sudo tip_update_pw.sh -newpw PASS12XY -oldpw tipadmin
#   2. Update password for WAS HOME /opt/IBM/Netcool/tip, user/pw is in soap.client.props 
#       WH=/opt/IBM/Netcool/tip     
#       sudo tip_update_pw.sh -newpw newpass1 -washome $WH
#   3. List the WAS HOMEs for running TIPProfiles
#       tip_update_pw.sh -listTIPS     
#  
#
#   Change History:
#   2013-04-15 Initial version
#   2013-07-01 Backup fileRegistry.xml 
#   2013-10-07 Allow user supplied as an argument in case locate_user fails.
#              Allow trailing slashes in -washome. Support user specified -traceout.    
#   2013-10-08 Add a confirm selections display before making the updates.  
#   2013-10-09 Test the new password by running serverStatus.sh.
#   2014-06-12 Support JazzSMProfile that can run either SDK  1.6 or 1.7 with  different JAVA_HOME.
# 
#   TODO: 
#    1. Detect which TIP is running if more than one installed. Change the pw on that one.
#       without having to specify argument overrides..  
##########################################################################################################
VERSION=1.04d
NODE=$(hostname -s)
DATE=$(date +"%Y%m%d%H%M")
DATE1=`date +"%F"`
SCRIPTNAME=$(basename $0)
PWD=$(pwd)

# Defaults
WAS_USER=webinst  
TIPADMIN=tipadmin
DEF_OLD_TIPPW=tipadmin        
# From arguments
WAS_HOME=/usr/WebSphere70/AppServer 
PROFILE=TIPProfile  
PROFILE_OVERRIDE_IND=""
WAS_CELL=TIPCell
NEWPW=""
DEBUG=""
BACKUPCFG=n
BACKUPCFG_ONLY=n
TEST=n
HELP=n
SILENT=n
JAZZ=n
 
WAS_USER_OVERRIDE="" 
WAS_HOME_OVERRIDE_IND=""  
TRACEOUT_PATH_OVERRIDE=""

USER=$(id -u)
#SCAN_FOR_RUNNING_TIPS=n
DISPLAY_RUNNING_TIPS=n
WAS_PROFILE_HOME=""

UIDPW_IN_SOAP_PROPS=n
SLEEP_TIME_WARNINGS=3

CONTINUE_PROMPTS=n   
EI_TIP_TOOLS=/lfs/system/tools/tip


  
####
# Locate arguments
####
scan_arguments() {
  i=0
  while [ $i -le $# ]; do
    i=$((i+1))
    eval parm=\${$i:-}          
    case "$parm" in
      -help)
        HELP=y
        ;;
      -debug)
        DEBUG="-debug"
        ;;
      -test)
        TEST=y
        ;;
      -backupcfg|-bcf)
        BACKUPCFG=y
        ;;
      -backupcfgONLY|-bco)
        BACKUPCFG_ONLY=y
        ;;  
      -washome|-wh)
        i=$((i+1))
        eval WAS_HOME=\${$i:-}
        WAS_HOME_OVERRIDE_IND=y  
        ;;  
      -profile|-pr)
        i=$((i+1))
        eval PROFILE=\${$i:-}
        PROFILE_OVERRIDE_IND=y  
        ;; 
      -cell)
        i=$((i+1))
        eval WAS_CELL=\${$i:-}
        ;;                       
      -oldpw)
        i=$((i+1))
        eval OLDPW=\${$i:-}
        ;;
      -newpw)
        i=$((i+1))
        eval NEWPW=\${$i:-}
        ;; 
      -user)
        i=$((i+1))
        eval WAS_USER_OVERRIDE=\${$i:-}
        ;;  
      -traceout|-traceoutPath)
        i=$((i+1))
        eval TRACEOUT_PATH_OVERRIDE=\${$i:-}
        ;;         
      -displayTIPS|-listTIPS)
        DISPLAY_RUNNING_TIPS=y
        ;; 
      -silent|-s)
        SILENT=y
        ;; 
      -jaz|-jazz|jaz|-jaz)
        JAZZ=y
        PROFILE=JazzSMProfile
        PROFILE_OVERRIDE_IND=y
        WAS_HOME=/usr/WebSphere85/AppServer
        WAS_HOME_OVERRIDE_IND=y 
        WAS_CELL=JazzSMNode01Cell 
        ;; 
      -debug|debug|-d)
        DEBUG=y
        ;;   
      *)
        if [ "$parm" != "" ] ; then
          echo "ERROR: Invalid argument supplied: $parm - Correct and resubmit"
          exit 1
        fi  
        ;;
    esac
  done
}


###
# Prompt
###
prompt_to_continue() {
  if [ $SILENT == n ]; then
    echo "\nHit any key to continue, or cancel(CNTL-c) to quit"  
    read -r choice 
  else
    pause    
  fi
}

###
# pause 
###
pause() {
echo "\nPausing briefy"
sleep 3
echo    
}


####
# Test for root user
####
test_root_user() {
    if [ $USER != "0" ]; then
       echo "ERROR: This script requires root access...terminating"
       exit 1
    fi
}

####
# Verify required input.
####
verify_input() {
    STD_WAS=/usr/WebSphere70/AppServer
    STD_NCO=/opt/IBM/Netcool/tip
    STD_TCR=/opt/IBM/TCR/tip
    STD_TCR1=/opt/IBM/TCR1/tip
    STD_TCR31=/usr/WebSphere85/AppServer
    
    # If running backup config only, we do not need new password
    if [ $BACKUPCFG_ONLY != "y" -a $DISPLAY_RUNNING_TIPS != "y"  ]; then
        if [ "$NEWPW" == "" ]; then
            echo "ERROR: Missing new password -newpw"
            exit 1
        fi        
    fi
    # If WAS_HOME override was supplied, remove any trialing slashes that will cause problems later
    # otherwise try to locate a WASHOME 
    if [ "$WAS_HOME_OVERRIDE_IND" == "y" ]; then
        WAS_HOME=$(echo $WAS_HOME | sed "s,/*$,,") 
        [ -n "$DEBUG" ] && echo "*DEBUG* After sed WAS_HOME=$WAS_HOME"  
        if [ ! -d $WAS_HOME ]; then
            echo "ERROR:  Invalid WAS home supplied...terminating" 
            exit 1  
        fi
    # auto-discovery        
    elif [ -d $STD_WAS   ]; then WAS_HOME=$STD_WAS;  
    elif [ -d $STD_NCO   ]; then WAS_HOME=$STD_NCO;  
    elif [ -d $STD_TCR   ]; then WAS_HOME=$STD_TCR;  
    elif [ -d $STD_TCR1  ]; then WAS_HOME=$STD_TCR1; 
    elif [ -d $STD_TCR31 ]; then WAS_HOME=$STD_TCR31; 

    else  
        echo "ERROR: No WAS home located...terminating"      
    fi
          
    WAS_PROFILE_HOME="$WAS_HOME/profiles/$PROFILE" 
    [ -n "$DEBUG" ] && echo "*DEBUG* WAS_PROFILE_HOME=$WAS_PROFILE_HOME"
    # Verify WAS_HOME
    if [ ! -d "$WAS_HOME" -o ! -d "$WAS_PROFILE_HOME"  ]; then 
        echo "ERROR: WAS_HOME $WAS_HOME is not a valid location for $PROFILE"
        echo " Specify a valid -washome"
        exit 1
    fi 
      
    # Display variables now
    [ -n "$DEBUG" ] && echo "*DEBUG*  Updated variables"
    [ -n "$DEBUG" ] && echo "*DEBUG*  WAS_HOME=$WAS_HOME"
    [ -n "$DEBUG" ] && echo "*DEBUG*  PROFILE=$PROFILE  WAS_CELL=$WAS_CELL"
    [ -n "$DEBUG" ] && echo "*DEBUG*  WAS_PROFILE_HOME=$WAS_PROFILE_HOME"
    
   
    #
    # Determine if a userid/pw is included in soap.client.props and therefore not needed in wsadmin call.
    # which can occur the first time this runs. 
    #
    soap_client_props_path=$WAS_PROFILE_HOME/properties/soap.client.props
    props_login_uid=$(grep '^com.ibm.SOAP.loginUserid='   $soap_client_props_path | cut -d'=' -f 2) 
    props_logon_pwd=$(grep '^com.ibm.SOAP.loginPassword=' $soap_client_props_path | cut -d'=' -f 2) 
    if [ "$props_login_uid" != "" -a "props_logon_pwd" != "" ]; then
        [ -n "$DEBUG" ] && echo "*DEBUG* The soap.client.props contains logon userid $props_login_uid and a pw" 
        UIDPW_IN_SOAP_PROPS="y"
    else
        if [ "$OLDPW" ==  "" ]; then
            echo "WARNING: **********************************************************"
            echo "WARNING: The soap.client.props does not contain admin userid and pw"
            echo "WARNING: Current admin password not supplied in \"-oldpw\" " 
            echo "WARNING: Default password \"$DEF_OLD_TIPPW\" will be used in wsadmin call"
            echo "WARNING: **********************************************************" 
            prompt_to_continue
        fi       
    fi 
}   

####
# Scan active processes to locate for each target profile, user and WAS_HOME 
# Output: WAS_HOMES    - one line for each running TIPProfile
#         WAS_HOMES_JZ - one line for each running JazzSMProfile
#####    
WAS_HOMES=""
scan_active_processes() {
	  WAS_HOMES=""
	  WAS_HOMES_JZ=""
    # Processes running TIPProfile - 
    [ -n "$DEBUG" ] && echo "*DEBUG* scan_active_processes for TIPProfile and JazzSMProfile"
    x="$(  ps -e -o user,args | grep '\-Duser.install.root=.*/profiles/TIPProfile'    | grep -v 'grep'  )"
    x2="$( ps -e -o user,args | grep '\-Duser.install.root=.*/profiles/JazzSMProfile' | grep -v 'grep'  )"
    javas="$( echo $x  | tr ' ' '\12' | grep '^\/.*\/java/bin/java')" 
    javas2="$(echo $x2 | tr ' ' '\12' | grep '^\/.*\/java.*/bin/java')" 
     
    whs="$(   echo "$javas"  | sed 's/\/java\/bin\/java//g')" 
    whs_jz="$(echo "$javas2" | sed 's/\/java.*\/bin\/java//g')"
    
    if [ "$whs" == "" ]; then   
        [ -n "$DEBUG" ] && echo "*DEBUG*  no TIPProfile found "
    else
        [ -n "$DEBUG" ] && echo "*DEBUG*  TIPProfile Found: "
        [ -n "$DEBUG" ] && for wh in $whs;do  echo "*DEBUG*    $wh";  done
        WAS_HOMES="$whs"  
    fi
    if [ "$whs_jz" == "" ]; then   
        [ -n "$DEBUG" ] && echo "*DEBUG*  no JazzSMProfile found "
    else
        [ -n "$DEBUG" ] && echo "*DEBUG*  JazzSMProfile Found: "
        [ -n "$DEBUG" ] && for wh in $whs_jz;do  echo "*DEBUG*    $wh";  done
        WAS_HOMES_JZ="$whs_jz"  
    fi
         
            
}
####
# Display WAS_HOMES for running profiles: TIPProfile or JazzSMProfile
# Input:  $WAS_HOMES
# Output: $WAS_HOMES listed 
####
list_running_TIP_was_homes() {
    if [ "$WAS_HOMES" == "" ]; then
        scan_active_processes       
    fi  
    echo "WAS Homes for active profiles: TIPProfile:"
    if [ "$WAS_HOMES" == "" ]; then echo "    None found"
    else
        for wh in $WAS_HOMES; do  echo "   $wh";  done
    fi 
    echo "WAS Homes for active profiles: JazzSMProfile:"
    if [ "$WAS_HOMES_JZ" == "" ]; then echo "    None found"
    else
        for wh in $WAS_HOMES_JZ; do  echo "   $wh";  done
    fi        
}  

####
# Locate user for the executing TIPProfile for a specific WAS_HOME
# Input:   WAS_HOME
# Output:  LU_USER  
####
LU_USER=""
locate_user() {
    #echo "##################################################"
    #echo " Locating user in processes for $WAS_HOME" 
    #echo "    in $PROFILE"
    #echo "##################################################"
    [ -n "$DEBUG" ] && echo "*DEBUG* locate_user for $WAS_HOME"
    [ -n "$DEBUG" ] && echo "*DEBUG*                 profile $PROFILE"
    tip_process_info="$( ps -e -o user,args | grep "\-Duser.install.root=$WAS_HOME/profiles/$PROFILE"  | grep -v 'grep' )"
    if [ "$tip_process_info" == "" ]; then echo "ERROR: No $PROFILE running for $WAS_HOME"; exit 1; fi
    wh=$(echo $tip_process_info | tr ' ' '\12' | grep '^\/.*\/java.*/bin/java' | sed 's/\/java.*\/bin\/java//g' ) 
    [ -n "$DEBUG" ] && echo "*DEBUG*   WAS home process located for $wh"
    if [ "$wh" == $WAS_HOME ]; then
        LU_USER=$(echo $tip_process_info | cut -d' ' -f 1)
        if [ "$LU_USER" == "" ]; then echo "ERROR: Could not locate user for $WAS_HOME"; exit 1; fi
        [ -n "$DEBUG" ] && echo "*DEBUG* locate_user - complete - $LU_USER"
        return 0
    else
        echo "ERROR: Unable to locate a running process for $WAS_HOME"
        exit 1  
    fi      
}

####
# Backup fileRegistry.xml 
# Input: WAS_PROFILE_HOME WAS_USER  
#### 
backup_fileRegistry() {
    echo "#######################"
    echo " Backing File registry  "
    echo "#######################"   
    FILE_REGISTRY_XML="$WAS_PROFILE_HOME/config/cells/${WAS_CELL}/fileRegistry.xml"
    if [ ! -f $FILE_REGISTRY_XML ]; then
        echo "ERROR: - File registry xml does not exist at $FILE_REGISTRY_XML...terminating"   
        exit 1
    fi 
    echo "File registry is at $FILE_REGISTRY_XML"
    if [ $TEST == "n" ]; then
        echo "Backing up current fileRegistry.xml to $FILE_REGISTRY_XML_$DATE"
        su - $WAS_USER -c "cp -p $FILE_REGISTRY_XML $FILE_REGISTRY_XML.$DATE"
    else
        echo "** test run ** Backing up current fileRegistry.xml bypassed"
    fi    
}
  
####
# Backup profile config and files relevant for working being done by this script
# Input: WAS_PROFILE_HOME $PROFILE
# EI WAS backup script in /lfs/system/tools/was/bin/was_backup_config.sh
####
backup_config() {
    ARCHIVE_DAYS=30
    ARCHIVEDIR="/fs/backups/was"
    echo "##################################################"
    echo " Backing up $PROFILE config "
    echo "   in $WAS_PROFILE_HOME    "
    echo "##################################################" 
    echo "****WARNING****************************************************"
    echo "*** Never restore a config backup in a TIP/Jazz environment.***" 
    echo "*** It may regress TIP application(s) because TIP           ***"
    echo "*** service may update only installedApps directory and     ***"
    echo "*** not the profile config directory                        ***"
    echo "***************************************************************" 
    
    prompt_to_continue
    
    ls $ARCHIVEDIR/${NODE} >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        [ -n "$DEBUG" ] && echo "  *DEBUG* Creating directory $ARCHIVEDIR/${NODE}" 
	      mkdir -p              $ARCHIVEDIR/${NODE}
	      chgrp -R eiadm        $ARCHIVEDIR/${NODE}
	      chmod -R g+rwxs,o-rwx $ARCHIVEDIR/${NODE}
    fi
    #Backup WAS configs
    ZIPNAME=$ARCHIVEDIR/${NODE}/${PROFILE}_config_${DATE1}.zip
    
    echo "Launching WAS backup to create $ZIPNAME"
    echo "  running ${WAS_PROFILE_HOME}/bin/backupConfig.sh"
  
    ${WAS_PROFILE_HOME}/bin/backupConfig.sh  $ZIPNAME  -nostop -logfile ${WAS_PROFILE_HOME}/logs/wasconfig_backup_$DATE1.log
    
    if [ -f "$ZIPNAME" ]; then
	      chgrp eiadm     $ZIPNAME
	      chmod g+rw,o-rw $ZIPNAME
    fi
    #Backup specific files  
    SOAP_CLIENT_PROPS=$WAS_PROFILE_HOME/properties/soap.client.props
    TARNAME=$ARCHIVEDIR/${NODE}/tipfiles_${DATE1}.tar
    tar -cf $TARNAME $SOAP_CLIENT_PROPS 
    [ -n "$DEBUG" ] && echo "  *DEBUG*  Created $TARNAME"   
    
    #Remove config/file backups older than x days
    [ -n "$DEBUG" ] && echo "  *DEBUG*  Removing older than $ARCHIVE_DAYS days archives " 
    find $ARCHIVEDIR/${NODE} -type f -name "$PROFILE_config*.zip" -mtime +$ARCHIVE_DAYS -exec rm -f {} \;
    find $ARCHIVEDIR/${NODE} -type f -name "tipfiles*.tar"          -mtime +$ARCHIVE_DAYS -exec rm -f {} \;
   
    echo "Backing up $PROFILE config...complete"   
}  

####
# Check traceout path for write access by wsadmin.sh 
# In production NCO netcool, the default path didn't have write access
# Input: $TRACEOUT $WAS_USER
####
check_traceout()  {
     [ -n "$DEBUG" ] && echo "  *DEBUG* Checking ability to write to $TRACEOUT"
     # Verify permissions
     echo "  Testing ability of $WAS_USER to write to traceout $TRACEOUT"
     su - $WAS_USER -c "umask 007; touch $TRACEOUT"
     if [ $? -ne 0 ]; then
         echo "   write test failed on $TRACEOUT with $WAS_USER"
         if [ -f $TRACEOUT ]; then  
             echo "    changing ownership and permissions to $WAS_USER perms 770"
             chown $WAS_USER $TRACEOUT
             chmod 770       $TRACEOUT
         else
             echo "    creating $TRACEOUT with owner $WAS_USER perms 770" 
             touch           $TRACEOUT              # > /dev/null 2>&1         
             chown $WAS_USER $TRACEOUT
             chmod 770       $TRACEOUT
         fi         
         echo "    Try again"      
         su - $WAS_USER -c "umask 007; touch $TRACEOUT"
         if [ $? -eq 0 ]; then
             echo "     Touch was successful"
         else
             echo "     Touch failed - you may need run this script with -traceout to specify"
             echo "     another location for traceout file"          
         fi 
     fi
     echo "  Testing ability... complete" 
}

####
# Update password
#   Execute "wadamin -c" which will execute the command and automatically do a save.
#   WAS local mode not supported. 
#   App server recycle not required after using command AdminTask.updateUser.
#   If old password supplied, we pass user(tipadmin) and password in the wsadmin connect argument even if
#   logon userid and password is included in soap.client.props. 
#   If wasamin userid/pw is stored in soap.client.props as expected, the WAS userid/pw is not required.
#   UIDPW_IN_SOAP_PROPS="n" indicates soap.client.props doesn't contain userid and pw
#   Input: WAS_PROFILE_HOME NEWPW OLDPW WAS_USER
#
#   soap props           -oldpw           
#   contain uid/pw       supplied        CONNARGS, etc 
#   ---------------      --------        ----------------------------------
#      Y                    Y            $OLDPW and user tipadmin included
#      Y                    N            no userid/pw included
#      N                    Y            $OLDPW and user tipadmin included 
#      N                    N            WARNING displayed earlier, 
#                                          $DEF_OLD_TIPPW and user tipadmin included
#### 

update_password() {
     echo "###########################"
     echo " Updating tipadmin password "
     echo "###########################" 
     echo "Updating WAS \"tipadmin\" password for WAS profile: $WAS_PROFILE_HOME"
     echo " running under user $WAS_USER" 
     TRACEOUT=$WAS_PROFILE_HOME/logs/wsadmin.chgpw.traceout
     if [ "$TRACEOUT_PATH_OVERRIDE" != "" ]; then  #  -a -f $TRACEOUT_PATH_OVERRIDE ]; then
         TRACEOUT=$TRACEOUT_PATH_OVERRIDE 
     fi  
     echo " wsadmin traceout path is $TRACEOUT"
     check_traceout
     
     LOGGING="-tracefile $TRACEOUT"
     WSADMIN=${WAS_PROFILE_HOME}/bin/wsadmin.sh  
     if [ "$OLDPW" != "" ]; then
         CONNARGS="-conntype SOAP -user $TIPADMIN -password $OLDPW"
     elif [ $UIDPW_IN_SOAP_PROPS == "n" ]; then
         # warnings displayed earlier  
         CONNARGS="-conntype SOAP -user $TIPADMIN -password $DEF_OLD_TIPPW"
     else    
         CONNARGS="-conntype SOAP "      
     fi 
       
     ADMIN_CMD="\"AdminTask.updateUser('[-uniqueName uid=$TIPADMIN,o=defaultWIMFileBasedRealm -password  $NEWPW]')\"" 
     WSADMIN_UPDATE_USER_CMD="$WSADMIN $CONNARGS -lang jython $LOGGING -c $ADMIN_CMD"
     [ -n "$DEBUG" ] && echo "  *DEBUG* Calling wsadmin with " 
     [ -n "$DEBUG" ] && echo "  *DEBUG*  WSADMIN_UPDATE_USER_CMD=$WSADMIN_UPDATE_USER_CMD"
     # Previous as an example:  result=`su - $WAS_USER -c "$WSADMIN_UPDATE_USER_CMD | grep -v '^WASX'"`
     # Capture all output not just grep -v '^WASX'"
     
     if [ $TEST == "n" ]; then
         echo " Calling wsadmin" 
         result=$(su - $WAS_USER -c "$WSADMIN_UPDATE_USER_CMD")
         rc=$?
         echo "  return code: $rc"
         print $result
         # Can this rc be 0 and the wsadmin work "failed" 
         if [ $rc -eq 0 ]; then 
             echo "Updating WAS wsadmin password complete"  
             echo "Updating WAS \"tipadmin\" password...complete" 
         else
             echo
             echo "       ERROR: Updating WAS wsadmin password failed. Terminating $SCRIPTNAME"
             exit 1  
         fi
     else
         echo "** test mode ** - Call to wsadmin bypassed "
     fi      
}

####
# Update soap.client.props with WAS admin userid and encoded password  
# Input: WAS_USER(usually webinst) WAS_PROFILE_HOME 
#        WAS_HOME $TIPADMIN $NEWPW
####
update_props_file() {
    #[ -n "$DEBUG" ] && echo "  *DEBUG* update_props_file - entry"
    SEC_LOGIN_USER=$TIPADMIN
    SEC_USER_PW=$NEWPW
    WAS_PROPS=$WAS_PROFILE_HOME/properties
    USERID_PROP="com.ibm.SOAP.loginUserid"
    PASSWORD_PROP="com.ibm.SOAP.loginPassword"
    echo "###########################"
    echo " Updating soap.client.props "
    echo "###########################"
    echo "Updating soap.client.props with the userid and the new password"
    [ -n "$DEBUG" ] && echo "  *DEBUG* WAS_PROPS=$WAS_PROPS  WAS_USER=$WAS_USER"
    
    # 1. Save current copy of soap.client.props
    [ -n "$DEBUG" ] && echo "  *DEBUG* Backup props to soap.client.props.$DATE"  
    su - $WAS_USER -c "cp -p $WAS_PROPS/soap.client.props $WAS_PROPS/soap.client.props.$DATE" 
    [ $? -ne 0 ] && echo "  ERROR: Backup props failed. Script terminating." &&  exit 1
       
    # 2. Update soap.clients.props to include WAS admin userid and encoded password
    if [ $TEST == "n" ]; then
        [ -n "$DEBUG" ] && echo "  *DEBUG* Update userid and password in $WAS_PROPS/soap.client.props" 
        su - $WAS_USER -c "sed -e \"s/^$USERID_PROP=.*/$USERID_PROP=$SEC_LOGIN_USER/g; 
                                    s/^$PASSWORD_PROP=.*/$PASSWORD_PROP=$SEC_USER_PW/g;
                                  \" $WAS_PROPS/soap.client.props.$DATE > $WAS_PROPS/soap.client.props"   
        [ $? -ne 0 ] && echo "  ERROR: Update failed. Script terminating." && exit 1
        # 3. Modify PropFilePasswordEncoder.sh if not done already  
        grep -i createBackup $WAS_HOME/bin/PropFilePasswordEncoder.sh > /dev/null 2>&1
	      if [[ $? -ne 0 ]]; then
	          [ -n "$DEBUG" ] && echo " *DEBUG* Modifying PropFilePasswordEncoder.sh to include createBackup=false property" 
	          # Instruct PropFilePasswordEncoder utility NOT to create a .bak file with the password in clear text
	  	      su - $WAS_USER -c "cp -p $WAS_HOME/bin/PropFilePasswordEncoder.sh $WAS_HOME/bin/PropFilePasswordEncoder.sh.$DATE"
  		      echo "" >> $WAS_HOME/bin/PropFilePasswordEncoder.sh.$DATE
		      	su - $WAS_USER -c "sed -e \"s/-classpath/-Dcom.ibm.websphere.security.util.createBackup=false -classpath/
			                                \"  $WAS_HOME/bin/PropFilePasswordEncoder.sh.$DATE > $WAS_HOME/bin/PropFilePasswordEncoder.sh"
	      fi
	      # 4. Encode the password 
	      [ -n "$DEBUG" ] && echo "  *DEBUG* Encode password $WAS_PROPS/soap.client.props"
		    su - $WAS_USER -c "$WAS_HOME/bin/PropFilePasswordEncoder.sh $WAS_PROPS/soap.client.props com.ibm.SOAP.loginPassword"  #  $PROFILE"
			 	  
		 	  login_line_user=$(grep ^$USERID_PROP   $WAS_PROPS/soap.client.props)
		    login_line_pswd=$(grep ^$PASSWORD_PROP $WAS_PROPS/soap.client.props)
		    pswd_enc=$(echo $login_line_pswd | sed -e "s/^$PASSWORD_PROP=//")
		    if [ -n "$DEBUG" ]; then
		        echo "  *DEBUG* Property lines updated" 
		        echo "  *DEBUG*   $login_line_user"
		        echo "  *DEBUG*   $login_line_pswd"                                     
		    fi    
		    # 5. Reverse the encoding for validation 
		    #    Pass profile name. 
	      echo "Updating soap.client.props complete. Encoded pw is:  $pswd_enc "
	      # If TIP profile call PasswordDecoder.sh as always
	      if [[ $PROFILE  == TIPProfile ]]; then   
	          pswd_line=$($EI_TIP_TOOLS/bin/PasswordDecoder.sh $pswd_enc $WAS_HOME )
	      else
	          pswd_line=$($EI_TIP_TOOLS/bin/PasswordDecoder.sh $pswd_enc $WAS_HOME $PROFILE)
	      fi    
	      pswd=$(echo $pswd_line | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
	      if [ $SEC_USER_PW == $pswd ]; then
	          echo "   Password successfully encoded in properties is: $pswd"
	      else
	          echo "ERROR: Password client props encoding/decoding problem" 
	          exit 1  
	      fi   
	  else
	      echo "** test run ** Update soap.client.props bypassed" 
	  fi    
	  #[ -n "$DEBUG" ] && echo "  *DEBUG* update_props_file - exit"
}

####
# Help display
####
display_help() {
  cat   << EOF  
  $SCRIPTNAME $VERSION TIP tipadmin password update tool
  
  This tool updates the tipadmin password and updates the userid/pw in soap.client.props.    
 
  Requirements:
  1. The WebSphere app server must be running 
  2. Root access (sudo) required
  Notes:
  1. After running, tipadmin userid/pw not required for WAS stop or wsadmin
  2. Userid used by this script to run wsadmin and copy/create files is 
     the userid running the current WAS process  
  3. The password update takes effect immediately. The next WAS stop will not require userid/pw.       
       
  $SCRIPTNAME -newpw <new_password> [-washome <WAS_HOME>] [-oldpw <current pw>] 
              [-user <wsadmin_exec_userid>]
              [-traceout <wsadmin traceout path>]     
              [-backupcfg] [-backupcfgONLY] [-listTIPS] [-test] [-debug]
 
    -newpw <new password> New password (un-encrypted)
                          No default. 
    -washome <was home>   WebSphere HOME directory. 
                          Generally required. Default is /usr/WebSphere70/AppServer  
    -profile|-pr <prof>   Profile name. 
                          Default is TIPProfile   
    -cell <cell>    >     WAS cell bame. Default is TIPCell                                          
    -oldpw <current pw>   Current tipadmin password. 
                          Required the first time unless userid/pw is in soap.client.props.  
                          Default: tipadmin 
    -user <wsadmin_user>  Userid override to use in wsadmin call. The search of running processes is bypassed
    -traceout <wsadmin traceout path>
                          Override to default wsadmin traceout at TIPProfile/logs  
    -backupcfg|-bcf       Backup the WAS config before updating password. 
    -backupcfgONLY|-bco   Only runs the WAS config backup. 
    -debug                Enables DEBUG mode to display DEBUG messages.  
    -help                 Displays help 
    -test                 Runs tool in test mode. No password update.  
                          No wsadmin call. No updates to soap.client.props.
    -listTIPS             Lists the WAS HOME for all running TIPProfiles
  
  Examples:
  1. Update password for WAS HOME  /usr/WebSphere70/AppServer if no user/pw in soap.client.props
      sudo ./tip_update_pw.sh -newpw PASS12XY -oldpw tipadmin
  2. Update password for WAS HOME /opt/IBM/Netcool/tip, user/pw is in soap.client.props      
      sudo ./tip_update_pw.sh -newpw passabcd -washome /opt/IBM/Netcool/tip
  3. List the WAS HOMEs for running TIPProfiles
       ./tip_update_pw.sh -listTIPS     
EOF
  
}  

####
# Confirm selections 
####
confirm_selections() {
    echo "########################"
    echo " Confirm selections "
    echo "########################"  
 
    echo "..WebSphere home(-washome)  : $WAS_HOME"   
    echo "..WAS profile home          : $WAS_PROFILE_HOME" 
    echo "..WAS cell                  : $WAS_CELL" 
    echo "..User(-user)               : $WAS_USER" 
    echo "..Old pw (-oldpw)           : $OLDPW"   
    echo "..New password (-newpw)     : $NEWPW" 
      
    echo "..Backup WAS config         : $BACKUPCFG"
    echo "..test mode(-test)          : $TEST"  
    echo "..traceout override         : $TRACEOUT_PATH_OVERRIDE"
    echo "..Debug mode                : $DEBUG" 
    echo  
    
    prompt_to_continue
}
####
#   Test password 
#   To call: test_password [<userid> <password>]  
####
test_password() {
    if [ $# -eq 2 ]; then 
        user=$1
        pw=$2 
    fi  
    echo "#######################################"
    echo " Testing password we just updated  " 
    echo "#######################################"
    test_serverStatus "$user"  "$pw"                   
    if [ $? -eq 0 ]; then
        echo "    ...PASSED"  
    else
        echo "    ...FAILED... see WAS messages below" 
        echo "    ...Please rerun in debug mode and check messages carefully"
        echo "    ...$STATUS_MSG"
        echo "    ...====================================================="      
        exit 1  
    fi  
}  

####
# Test using serverStatus command  
# Input:   $WAS_PROFILE_HOME, 
#          arg1=userid  arg2=password - both optional
# Output:  STATUS, rc 
#          STATUS_MSG  
# To call:  test_serverStatus <userid> <pw>
# If no arguments, serverStatus called with no userid/pw passed 
# If the userid/password is not correct, this command fails to execute.  
####
test_serverStatus() {
    [ -n "$DEBUG" ] && echo "*DEBUG* test_serverStatus called with args: $*"
    USER_PW_ARGS=""
    if [ $# -eq 2 ]; then 
        user=$1
        pw=$2 
        USER_PW_ARGS="-username $1 -password $2"
    fi           
    CMD="$WAS_PROFILE_HOME/bin/serverStatus.sh server1 $USER_PW_ARGS"
    [ -n "$DEBUG" ] && echo "*DEBUG*  Execute under $WAS_USER: $CMD" 
    response=$(su - $WAS_USER -c $CMD ) 
    success_msg=$(echo $response | tail -1 | grep STARTED) 
    if [ "$success_msg" == ""  ]; then 
        STATUS="fail"
        STATUS_MSG="serverStatus response: \n$response"
        rc=16 
    else
        STATUS="ok"
        rc=0    
    fi 
    [ -n "$DEBUG" ] && echo "*DEBUG*  server STARTED - $STATUS" 
    return $rc
}
    


##################################
#  M A I N
################################## 
echo "Executing $SCRIPTNAME version $VERSION" 

scan_arguments $*

echo "#######################################"
echo "#                                     #"                           
echo "#  EI tipadmin password update tool   #"
echo "#                                     #" 
echo "#######################################"
[ -n "$DEBUG" ] && echo "*DEBUG* Input and default values:"
[ -n "$DEBUG" ] && echo "*DEBUG*        WAS_HOME=$WAS_HOME BACKUPCFG=$BACKUPCFG BACKUPCFG_ONLY=$BACKUPCFG_ONLY NEWPW=$NEWPW"
[ -n "$DEBUG" ] && echo "*DEBUG*        WAS_USER=$WAS_USER OLDPW=$OLDPW DEBUG=$DEBUG WAS_USER_OVERRIDE=$WAS_USER_OVERRIDE"
[ -n "$DEBUG" ] && echo "*DEBUG*        TRACEOUT_PATH_OVERRIDE=$TRACEOUT_PATH_OVERRIDE"
[ -n "$DEBUG" ] && echo "*DEBUG*        WAS_CELL=$WAS_CELL"

if [ $HELP == "y" ]; then
    display_help
    exit 0
fi  

# Test for root user
test_root_user
 

# Verify input 
verify_input 


# Special command - display WAS homes for the executing TIPProfiles ?
if [ $DISPLAY_RUNNING_TIPS == "y" ]; then
    list_running_TIP_was_homes
    echo "TIPS display completed"   
    exit 0    
fi

# Backup config only requested ?
# For now,  this needs to be after verify_input and therefore a new password is needed
if [ $BACKUPCFG_ONLY == "y" ]; then
    backup_config  
    echo "A backup-only operation was requested; script is exiting"  
    exit 0 
fi  
 
# Backup config requested as part of this run ?
if [ $BACKUPCFG == "y" ]; then
    backup_config  
fi  

prompt_to_continue

# Locate user associated with the supplied WAS_HOME 
# if "user" override not supplied in arguments  
# Also validate there is a WAS process for the requested WAS_HOME 
if [ "$WAS_USER_OVERRIDE" == "" ]; then 
    locate_user
    WAS_USER=$LU_USER
    echo "Userid running $PROFILE at $WAS_HOME is \"$WAS_USER\" " 
else
    WAS_USER=$WAS_USER_OVERRIDE
    echo "Userid override supplied for running wsadmin: \"$WAS_USER\" " 
fi    

# Confirm selection and discoveries
confirm_selections 

# Backup the file registry xml
backup_fileRegistry
 
# Change the password in wsadmin 
update_password

# Update soap.client.props and then encode the password
update_props_file

# Test the updated password 
if [ $TEST == "n" ]; then
    test_password tipadmin $NEWPW
fi

# Done
echo
echo "Executing $SCRIPTNAME completed" 
exit 0


