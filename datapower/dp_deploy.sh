#!/bin/bash

# Deployment script for ESC DataPower appliances in the EI
# (C) Copyright IBM Corporation 2015
#
# Automate and standardise DataPower deploys
#
# Keith White/UK/IBM Octover 2015

# TODO: incorporate Steve's check scripts (verify files to be copied are properly referenced for e.g.)?
# TODO: implement the --auto switch to do everything without prompts (but stop at write mem)

VERSION="0.3"

# quick and easy debug via set -x
[[ $* =~ -d|--debug ]] && set -x

# set some colours if this is a terminal (and the terminal supports it)
if [[ -t 1 ]]; then
   ncolors=$(tput colors)
   if [[ -n "$ncolors" && $ncolors -ge 8 ]]; then
      grey=$(tput bold;tput setf 0)
      blue=$(tput bold;tput setf 1)
      green=$(tput bold;tput setf 2)
      cyan=$(tput bold;tput setf 3)
      red=$(tput bold;tput setf 4)
      yellow=$(tput bold;tput setf 6)
   else
      ESC="" # escape char - in a terminal, press CTRL-V (note: capital V) and press ESCAPE
      grey="${ESC}[37;1m"
      blue="${ESC}[34;1m"
      green="${ESC}[32;1m"
      cyan="${ESC}[36;1m"
      red="${ESC}[31;1m"
      yellow="${ESC}[33;1m"
   fi
   normal=$(tput sgr0)
fi

# check we're running as root
if [[ $(whoami) != "root" ]]; then
   echo "${red}This script must be run using sudo.${normal}"
   exit
fi

###############
# Subroutines #
###############

# sub to send commands to the DataPower device
run_dp_cmds() {
   [[ -f /tmp/dp_deploy_output.txt ]] && rm -f /tmp/dp_deploy_output.txt
    cat <<EOF | ssh ${DP} | tee /tmp/dp_deploy_output.txt
${DP_USER}
${DP_PASS}
${DOMAIN}
top
co
${1}
EOF
   check_completion_status
}

# sub to handle user input
prompt() {
   if [[ $PROMPT == "true" ]]; then
      read -r -p "$@"
      echo "$REPLY" >> "$LOGFILE"
   else
      echo "${cyan}*** AUTO ***${normal} ${*}Y"
   fi
   if [[ "$REPLY" == [Aa] ]]; then
      echo "${red}*** Continuing with the rest of the deployment automatically ***${normal}"
      PROMPT=false
      REPLY=Y
      # check to see if we're going to need a password
      if [[ "${ORDER[@]}" =~ RESTART ]] || [[ "${ORDER[@]}" =~ SYNC ]]; then
         [[ $PASSWORD == "" ]] && password
         if [[ "$ENV" =~ pr ]]; then
            [[ $TITLE == "" ]] && read -r -p "${green}Enter Ack title ('${ENV} ${PLEX}' will be automatically added to the end): ${normal}" TITLE
         fi
      fi
   fi
}

# sub to check exit status of previous command
check_completion_status() {
   if [[ $? -ne 0 ]]; then
      echo "${red}ERROR: This step didn't complete successfully.${normal}"
      if [[ $PROMPT == "false" ]]; then
         exit 1
      fi
   fi
}

# sub to remove any ANSI escape sequences or CRLFs from the log file and set ownership
cleanup() {
   echo
   if [[ ${LOGFILE} != "/dev/null" ]]; then
      chown ${SUDO_USER} "$LOGFILE"
      cp "$LOGFILE" ${LOGFILE%.log}.out
      chown ${SUDO_USER} ${LOGFILE%.log}.out
      perl -pi -w -e "s/\e\[[\d;]*[a-zA-Z]|\e\\(B|\r//g;" "$LOGFILE"
      
   fi
   exit
}

#########################
# Start of main program #
#########################

# show usage if required
if [[ $# -eq 0 ]] || [[ $* =~ -h ]]; then
   echo
   echo "$(basename $0) v${VERSION}"
   echo
   echo "A deployment script for ESC DataPower appliances in the EI."
   echo "Automates and standardises DataPower deploys."
   echo "Keith White/UK/IBM"
   echo
   echo "Usage: sudo $0 -f [package_name]"
   echo
   echo -e " -f, --file=[package_name]\t Package zip filename e.g. prd_2015.10.23.zip or production_AudaxFix_cli_1.0.0.zip"
   echo -e " -s, --skip-backups\t\t Skip the backup steps"
   echo -e " -d, --debug\t\t\t show debug info (via set -x)"
   echo
   echo -e "Note: the environment (ivt or production) is taken from the package filename which should be of the format [ivt|prd|prod|production]_packagename*.zip"
   echo
   exit
fi

# set some variables
HOSTNAME=$(hostname)
PASSWORD=""
PW_FILE="/etc/.dp_secure_backup.cfg"
PW_FILE_DECODED=$(cat $PW_FILE | perl -e "use MIME::Base64;while (<>) { print decode_base64(\"\$_\"); }")
DP_USER=${PW_FILE_DECODED%;*}
DP_PASS=${PW_FILE_DECODED#*;}

# check we're running on w30141
if [[ $HOSTNAME != "w30141" ]]; then
   echo "${red}You should only run this from the PreProd ESC webserver (WEBSERVER.ESC.PRE) - w30141.${normal}"
   exit
fi

# process command line arguments
PROMPT=true
while [[ $# -gt 0 ]]; do
   case $1 in
      -f)
         PACKAGE_FILE=$2
         shift; shift
      ;;
      --file=*)
         PACKAGE_FILE=${1/--file=/}
         shift;
      ;;
      -s|--skip-backups)
         SKIP_BKP=1
         shift
      ;;
      -n|--nolog)
         NOLOG=true
         shift
      ;;
      -d|--debug)
         shift
      ;;
      *)
         echo "${red}Invalid argument. Try '$0 --help' for usage details${normal}"
         exit
      ;;
   esac
done

# trap ctrl-c so we can remove ANSI escape sequences from the log file
trap cleanup SIGINT

# determine which environment we're deploying to based on the package filename
ENV_NAME=${PACKAGE_FILE%_cli_*}
ENV_NAME=${ENV_NAME%\.\zip}
ENV=${ENV_NAME%%_*}
PACKAGE_NAME=${ENV_NAME#*_}
if [[ $ENV =~ pr.?d ]]; then
   ENV="prd"
   DPS="p1dpa01 p1dpa02 p3dpa01 p3dpa02 p5dpa01 p5dpa02"
   DOMAIN="support_websvc_eci_prod"
else
   DPS="p3dpa03 p3dpa04"
   DOMAIN="support_websvc_eci_ivt"
fi

# setup the logfile
TIMESTAMP=$(date +\%Y.\%m.\%d_\%H-\%M-\%S)
LOGFILE="/logs/dp_deploys/dp_deploy_${ENV}_${PACKAGE_NAME}_${TIMESTAMP}_${HOSTNAME}.log"

if [[ $NOLOG ]]; then
   LOGFILE="/dev/null"
fi

###################
# Main code block #
###################

# we put the main routine in a code block in order to redirect all the output to the logfile
{
   echo "${red}"$(basename $0)" v${VERSION}${normal}"
   echo "Running on ${cyan}${HOSTNAME}${normal}, invoked by ${cyan}${SUDO_USER}${normal} on $(date)"
   echo "Logging to ${cyan}${LOGFILE}${normal}"
   echo "Deploying ${cyan}${PACKAGE_FILE}${normal} to ${green}${DPS} ${cyan}(${ENV})${normal}"
   echo
   
   # scp the files from the dropzone and unpack them
   prompt "${yellow}Transfer and extract ${blue}${PACKAGE_FILE}${yellow} from dropzone (w30128)? ${normal}"
   if [[ "$REPLY" == [Yy] ]]; then
      echo -n "   ${yellow}Please enter your ${blue}Blue Zone${yellow} password: ${normal}"
      stty -echo
      read -r BZ_PASSWORD
      stty echo
      echo
      echo "   ${blue}Changing permissions of ${normal}w30128:/projects/datapower/htdocs/${PACKAGE_FILE}${blue}...${normal}"
      echo "$BZ_PASSWORD" | /usr/bin/pwdexp ssh -t ${SUDO_USER}@w30128 "sudo chmod a+r /projects/datapower/htdocs/${PACKAGE_FILE}"
      echo "   ${blue}scp'ing ${cyan}${PACKAGE_FILE}${blue}...${normal}"
      echo "$BZ_PASSWORD" | /usr/bin/pwdexp scp -p ${SUDO_USER}@w30128:/projects/datapower/htdocs/${PACKAGE_FILE} /tmp/
      check_completion_status
      echo "   ${blue}Unzipping...${normal}"
      unzip -q /tmp/${PACKAGE_FILE} -d /projects/espre/content/datapower
      check_completion_status
      echo "   ${blue}Moving ${normal}${PACKAGE_FILE}${blue} to /projects/espre/content/datapower/backups/...${normal}"
      mv /tmp/${PACKAGE_FILE} /projects/espre/content/datapower/backups/
      check_completion_status
   fi
   
   # run backups
   if [[ $SKIP_BKP != 1 ]]; then
      prompt "${yellow}Run secure backup? ${normal}"
      if [[ "$REPLY" == [Yy] ]]; then
         if [[ "$LOGFILE" == "/dev/null" ]]; then
            echo "   ${blue}Secure backup script running (will take several minutes)...${normal}"
            /lfs/system/tools/datapower/dp_secure_backup.pl ${ENV}
         else
            echo "   ${blue}Secure backup script running (will take several minutes) - see ${normal}${LOGFILE}${blue} for progress...${normal}"
            /lfs/system/tools/datapower/dp_secure_backup.pl ${ENV} >> "$LOGFILE" 2>&1
         fi
         check_completion_status
      fi
      prompt "${yellow}Run user backup? ${normal}"
      if [[ "$REPLY" == [Yy] ]]; then
         if [[ "$LOGFILE" == "/dev/null" ]]; then
            echo "   ${blue}User backup script running (will take several minutes)...${normal}"
            su - ${SUDO_USER} -c /lfs/system/tools/datapower/dp_backup.sh ${ENV}
         else
            echo "   ${blue}User backup script running (will take several minutes) - see ${normal}${LOGFILE}${blue} for progress...${normal}"
            su - ${SUDO_USER} -c /lfs/system/tools/datapower/dp_backup.sh ${ENV} >> "$LOGFILE"
         fi
         check_completion_status
      fi
   fi
   
   # run a before check_dp
   prompt "${yellow}Run a 'before' check_dp? ${normal}"
   if [[ "$REPLY" == [Yy] ]]; then
      echo "   ${blue}Sending output of check_dp.pl to ${normal}/tmp/check_dp_before_${ENV}.txt${blue}...${normal}"
      rm -f /tmp/check_dp_before_${ENV}.txt
      /lfs/system/tools/datapower/check_dp.pl ${ENV} 2>&1 | tee -a /tmp/check_dp_before_${ENV}.txt "$LOGFILE" >/dev/null
   fi
   
   # install the package on each device
   prompt "${yellow}Install package to each ${cyan}${ENV}${yellow} device (with confirmation)? ${normal}"
   if [[ "$REPLY" == [Yy] ]]; then
      for DP in $DPS; do
         prompt "   ${yellow}Install ${green}${PACKAGE_NAME}${yellow} to ${cyan}${DP}${yellow}? ${normal}"
         if [[ "$REPLY" == [Yy] ]]; then
            echo "      ${blue}Deploying to ${cyan}${DP}${blue}...${normal}"
            read -r -d '' CMDS << EOF
exec http://www-930pre.events.ibm.com/datapower/${ENV_NAME}/configs/new_customer.cfg
exit
EOF
            run_dp_cmds "$CMDS"
            echo
            if [[ $(grep "Finished script 'http://www-930pre.events.ibm.com/datapower/${ENV_NAME}/configs/new_customer.cfg' successfully" /tmp/dp_deploy_output.txt) ]]; then
               echo "${green}Script executed successfully${normal}"
            else
               echo "${red}ERROR: Check the above output ^^^"
               echo "Did not find a ${blue}Finished script 'http://www-930pre.events.ibm.com/datapower/${ENV_NAME}/configs/new_customer.cfg' successfully${red} message${normal}"
               exit 2
            fi
         fi
      done
   fi
   
   # write mem once the customer has confirmed success
   read -p  "${yellow}Finalise the change with 'write mem' on each device ${red}(wait for customer confirmation!)${yellow}? ${normal}"
   if [[ "$REPLY" == [Yy] ]]; then
      for DP in $DPS; do
         prompt "   ${yellow}Save config (write mem) on ${cyan}${DP}${yellow}? ${normal}"
         if [[ "$REPLY" == [Yy] ]]; then
            echo "      ${blue}Saving config on ${cyan}${DP}${blue}...${normal}"
            read -r -d '' CMDS << EOF
write mem
y
exit
EOF
            run_dp_cmds "$CMDS"
            echo
            if [[ $(grep "Configuration saved successfully\." /tmp/dp_deploy_output.txt) ]]; then
               echo "${green}Config saved successfully${normal}"
            else
               echo "${red}ERROR: Check the above output ^^^"
               echo "Did not find a ${blue}Configuration saved successfully.${red} message${normal}"
               exit 3
            fi
         fi
      done
   else
      # offer to backout the change
      prompt "   ${red}No write mem! ${yellow}Backout the change by restarting the ${cyan}${DOMAIN}${yellow} domain? ${normal}"
      if [[ "$REPLY" == [Yy] ]]; then
         for DP in $DPS; do
            prompt "      ${yellow}Restart domain on ${cyan}${DP}${yellow}? ${normal}"
            if [[ "$REPLY" == [Yy] ]]; then
               echo "         ${blue}Restarting domain on ${cyan}${DP}${blue} ${red}(ignore the 'Do you want to continue?' prompt)${blue}...${normal}"
               read -r -d '' CMDS << EOF
restart domain
y
exit
EOF
               run_dp_cmds "$CMDS"
               echo
            fi
         done
      fi
   fi
   
   # run an after check_dp and compare the output
   prompt "${yellow}Run an 'after' check_dp and compare with 'before' output? ${normal}"
   if [[ "$REPLY" == [Yy] ]]; then
      echo "   ${blue}Sending output of check_dp.pl to ${normal}/tmp/check_dp_after_${ENV}.txt${blue}...${normal}"
      rm -f /tmp/check_dp_after_${ENV}.txt
      /lfs/system/tools/datapower/check_dp.pl ${ENV} 2>&1 | tee -a /tmp/check_dp_after_${ENV}.txt "$LOGFILE" >/dev/null
      echo "   ${blue}Output of ${normal}diff /tmp/check_dp_before_${ENV}.txt /tmp/check_dp_after_${ENV}.txt${blue}:${normal}"
      diff /tmp/check_dp_before_${ENV}.txt /tmp/check_dp_after_${ENV}.txt
      if [[ $? -ne 0 ]]; then
         echo "${red}^^^ Please review the diff output above.${normal}"
      else
         echo "${green}Before and after output from check_dp.pl are identical.${normal}"
      fi
   fi
   
   # finish up
   echo
   echo "${green}Deploy complete, have a nice day.${normal}"
} 2>&1 | tee -a "$LOGFILE"

# strip the ANSI color codes from the logfile before finishing
cleanup
