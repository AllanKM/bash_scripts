#=================================================================
# Handle determining what ihs installs to work with
#=================================================================
function check_instance
{
  typeset fullpath path match_string instance=$1 site_match_string=$2

  if [[ $instance = "NULL" || $instance = [aA][lL][lL] ]]; then
    instance=""
  fi

  if [[ $site_match_string = "NULL"  || $site_match_string = [aA][lL][lL] ]]; then
    match_string="/projects/*"
  else
    match_string="/projects/*${site_match_string}*"
  fi

  if [[ `find /usr/HTTPServer${instance}*/bin/ /usr/WebSphere${instance}*/HTTPServer/bin/ -name httpd 2> /dev/null | wc -l` -gt 1 ]]; then
    if [[ `find /usr/HTTPServer${instance}*/bin/ -name httpd 2> /dev/null | wc -l` -gt 0 ]]; then
      for fullpath in `find /usr/HTTPServer${instance}*/bin/ -name httpd`; do
        path=`echo $fullpath | cut -d"/" -f3`
        if [[ ! -L /usr/$path ]]; then
          if [[ `ls -1 ${match_string}/\.$path 2> /dev/null | wc -l` -gt 0 ]]; then
            set -A ihs_installs ${ihs_installs[*]} $path
          fi
        fi
      done
    fi
    if [[ `find /usr/WebSphere${instance}*/HTTPServer/bin/ -name httpd 2> /dev/null | wc -l` -gt 0 ]]; then
      for fullpath in `find /usr/WebSphere${instance}*/HTTPServer/bin/ -name httpd`; do
        path=`echo $fullpath | cut -d"/" -f3`
        if [[ ! -L /usr/$path ]]; then
          if [[ `ls -1 ${match_string}/\.$path 2> /dev/null | wc -l` -gt 0 ]]; then
            set -A ihs_installs ${ihs_installs[*]} $path
          fi
        fi
      done
    fi
  elif [[ `find /usr/HTTPServer${instance}*/bin/ -name httpd 2> /dev/null` != "" ]]; then
    path=`find /usr/HTTPServer${instance}*/bin/ -name httpd | cut -d"/" -f3`
    if [[ ! -L /usr/$path ]]; then
      if [[ `ls -1 ${match_string}/\.$path 2> /dev/null | wc -l` -gt 0 ]]; then
        set -A ihs_installs ${ihs_installs[*]} $path
      fi
    fi
  elif [[ `find /usr/WebSphere${instance}*/HTTPServer/bin/ -name httpd 2> /dev/null` != "" ]]; then
    path=`find /usr/WebSphere${instance}*/HTTPServer/bin/ -name httpd | cut -d"/" -f3`
    if [[ ! -L /usr/$path ]]; then
      if [[ `ls -1 ${match_string}/\.$path 2> /dev/null | wc -l` -gt 0 ]]; then
        set -A ihs_installs ${ihs_installs[*]} $path
      fi
    fi
  else
    echo ""
    echo "//////////////////////////////////////////////////////////////////"
    echo ""
    echo "            Did not find an IHS install on this node"
    if [[ $instance != "" ]]; then
      echo "              corresponding to instance ${instance}"
    fi
    echo ""
    echo "//////////////////////////////////////////////////////////////////"
    echo ""
    exit 2
  fi
  if [[ ${ihs_installs[*]} = "" ]]; then
    echo ""
    echo "//////////////////////////////////////////////////////////////////"
    echo ""
    echo "            Did not find any sites that are configured to"
    if [[ $instance != "" ]]; then
      echo "              use ihs instance $instance"
    else
      echo "              use any installed ihs instance"
    fi
    if [[ $site_match_string != "NULL" ]]; then
      echo "              using a sitetag search string of $site_match_string"
    fi
    echo ""
    echo "//////////////////////////////////////////////////////////////////"
    exit 2
  fi
} 

#=================================================================
# Handle determining what ihs sites to work with
#=================================================================
function check_sitetag_match
{
  typeset fullpath sitetag config httpd_pid state site_config_ihs_instance dirname match_string site_match_string=$1 ihs_installs=$2
  typeset -i x

  if [[ $site_match_string = "NULL" ||  $site_match_string = [aA][lL][lL] ]]; then
    match_string="/projects/*"
  else
    match_string="/projects/*${site_match_string}*"
  fi

  if [[ `find ${match_string}/conf/ -name '*.conf' -a \! -name '*listen*.conf' -a \! -name 'kht-*.conf' -a \! -name httpd_mobile.conf 2> /dev/null | wc -l` -gt 0 ]]; then
    for fullpath in `find ${match_string}/conf/ -name '*.conf' -a \! -name '*listen*.conf' -a \! -name 'kht-*.conf' -a \! -name httpd_mobile.conf`; do
      sitetag=`echo $fullpath | cut -d"/" -f3`
      if [[ ! -L /projects/$sitetag ]]; then
        config=`echo $fullpath | cut -d"/" -f5`
        config=$(echo ${config%.conf})
        if [[ (( $sitetag = HTTPServer* &&  $config = "httpd" ) || ( $sitetag = $config )) && ( `ls -1 /projects/${sitetag}/.HTTPServer* 2> /dev/null | wc -l` -gt 0 || `ls -1 /projects/${sitetag}/.WebSphere* 2> /dev/null | wc -l` -gt 0 ) ]]; then
          if [ -f /logs/${sitetag}/httpd.pid ]; then
            httpd_pid=`cat /logs/${sitetag}/httpd.pid`
            if [ "`ps awwx | grep $httpd_pid | grep httpd | grep ${sitetag} | grep -v grep`" != "" ]; then
              state="(Running)"
            else
              state="(Stopped)"
              rm /logs/${sitetag}/httpd.pid
            fi
          else
            state="(Stopped)"
          fi
          if [ -f /projects/${sitetag}/.HTTPServer* ]; then
            site_config_ihs_instance=`ls -1 /projects/${sitetag}/.HTTPServer* | cut -d"/" -f4 | cut -d"." -f2`
          elif [ -f /projects/${sitetag}/.WebSphere* ]; then
            site_config_ihs_instance=`ls -1 /projects/${sitetag}/.WebSphere* | cut -d"/" -f4 | cut -d"." -f2`
          fi
          let x=25-${#sitetag}
          while [[ $x -gt 0 ]]; do
            sitetag="${sitetag} "
            let x=$x-1
          done
          if [[ $site_config_ihs_instance != "" && $ihs_installs != "" ]]; then
            if [[  $ihs_installs = *${site_config_ihs_instance}* ]]; then
              set -A inst_sites "${inst_sites[@]}" "$sitetag $state   $site_config_ihs_instance"
            fi
          fi
        fi
      fi
    done
  fi
}

#=================================================================
# Handle IHS starts
#=================================================================
function startihs 
{
  typeset sitetag instance state http_check plugin_check notes summary_list_index hightlight details=$1
  typeset -i index_num alist slist rc khtagent=0 khtagent_status

  #Validate configs and status to determine if the requested list can be actioned
  #Build separate list for those requested sites that pass the test
  #and store status for those that do not for summary at the end
  echo ""
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #            Prechecks            #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  echo ""

  for index_num in $site_selection;
  do
    sitetag=`echo ${inst_sites[index_num-1]}| awk {'print $1'}`
    instance=`echo ${inst_sites[index_num-1]}| awk {'print $3'}`
    state=`echo ${inst_sites[index_num-1]}| awk {'print $2'} | sed 's/(//'| sed 's/)//'`
    notes=""

    ${lib_home}/ihs/bin/highlight.pl "Now performing pre-checks on site: ${sitetag} >>>" HEADER; echo

    if [ `uname` == "AIX" ]; then
      LIBPATH="/projects/${sitetag}/lib"
      export LIBPATH
    elif [ `uname` == "Linux" ]; then
      LD_LIBRARY_PATH="/projects/${sitetag}/lib"
      export LD_LIBRARY_PATH
    fi

    if [[ $state != "Running" ]]; then
      validate_httpd $sitetag $instance $details
      httpd_check=$?
      validate_plugin $sitetag $details
      plugin_check=$?
      if [[ $debug -eq 1 ]]; then
        echo ""
        echo "httpd_check is $httpd_check"
        echo "plugin_check is $plugin_check"
        echo "state is $state"
        echo ""
      fi
    else
      echo ""
      echo "Site is already running -- skipping validation"
      echo
    fi
    if [[ $httpd_check -eq 0 && $plugin_check -eq 0 && $state != "Running" ]]; then
      if [[ $action_list_index = "" ]]; then
        action_list_index=$index_num
      else
        action_list_index="$action_list_index $index_num"
      fi
    elif [[ $state = "Running" ]]; then
      summary_list[index_num-1]="${sitetag}|Already Running|  |GOLDEN"
      if [[ $summary_list_index = "" ]]; then
        summary_list_index="${index_num}"
      else
        summary_list_index="${summary_list_index} ${index_num}"
      fi
    else
      if [[ $httpd_check -eq 1 || $httpd_check -eq 3 ]]; then
        notes="${notes} A"
      fi
      if [[ $httpd_check -eq 2 || $httpd_check -eq 3 ]]; then
        notes="${notes} B"
      fi
      if [[ $plugin_check -eq 4 || $plugin_check -eq 12 ]]; then
        notes="${notes} C"
      fi
      if [[ $plugin_check -eq 8 || $plugin_check -eq 12 ]]; then
        notes="${notes} D"
      fi 
      if [[ $ignore_ver -eq 1 ]]; then
        notes="${notes} O"
      fi
      summary_list[index_num-1]="${sitetag}|Failed Prechecks - Start Aborted|$notes|ERROR"
      if [[ $summary_list_index = "" ]]; then
        summary_list_index="${index_num}"
      else
        summary_list_index="${summary_list_index} ${index_num}"
      fi
    fi
  done
  if [[ $debug -eq 1 ]]; then
    echo "Summary list is:"
    for slist in ${summary_list_index}; do
      echo "$slist ${summary_list[slist-1]}"
    done

    echo ""
    echo "Action_list is:"
    for alist in ${action_list_index}; do
      echo "$alist ${inst_sites[alist-1]}"
    done  
  fi
  
  echo ""
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #            Prechecks            #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #            Complete             #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  echo ""

  if [[ $action_list_index != "" ]]; then
    echo ""
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #         Start Sequence          #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    echo ""
    
    #---------------------------------------
    # Determine if any actionable sites have 
    # ITM khtagent configured
    #---------------------------------------
    echo ""
    ${lib_home}/ihs/bin/highlight.pl "Determining Install Status of ITM khtagent >>>" HEADER; echo
    echo ""

    find_khtagent
    khtagent=$?
  
    #---------------------------------------
    # Stop ITM khtagent if required
    #---------------------------------------
    if [[ $khtagent -eq 1 ]]; then
      echo ""
      ${lib_home}/ihs/bin/highlight.pl "Performing ITM khtagent stop >>>" HEADER; echo

      khtagent_stop 
      rc=$?
      if [[ $rc -eq 2 ]]; then
        for alist in ${action_list_index}; do
          sitetag=`echo ${inst_sites[alist-1]}| awk {'print $1'}`
          summary_list[alist-1]="${sitetag}|Start Failed|E|ERROR"
        done
        echo ""
        print_summary
        exit 1
      elif [[ $rc -eq 1 ]]; then
        khtagent_status=1
      else 
        khtagent_status=0
      fi
    fi

    #---------------------------------------
    # Run rc.IP_aliases
    #---------------------------------------
    echo ""
    ${lib_home}/ihs/bin/highlight.pl "Running rc.IP_aliases >>>" HEADER; echo
    echo ""

    if [[ $ignore_IP != 1 ]]; then
      /usr/local/etc/rc.IP_aliases
      if [[ $? -gt 0 ]]; then
        for alist in ${action_list_index}; do
          sitetag=`echo ${inst_sites[alist-1]}| awk {'print $1'}`
          summary_list[alist-1]="${sitetag}|Start Failed|F|ERROR"
        done
        echo ""
        print_summary
        exit 2
      else
        echo "rc.IP_aliases complete"
      fi
    else
      echo "The ignore aliases parameter has been selected -- skipping"
      echo "  action to run rc.IP_aliases"
    fi  
  
    #-----------------------------------------------
    # Perform startup sequence for each selected
    # actionable site 
    #-----------------------------------------------
    for alist in ${action_list_index}; do 
      sitetag=`echo ${inst_sites[alist-1]}| awk {'print $1'}`
      instance=`echo ${inst_sites[alist-1]}| awk {'print $3'}`

      echo ""
      ${lib_home}/ihs/bin/highlight.pl "Now performing start on sitetag: ${sitetag} >>>" HEADER; echo
      echo ""

      #-----------------------------------------------
      # Issue start command
      #-----------------------------------------------
      start_sitetag $sitetag $instance $alist

      if [[ $? -eq 0 ]]; then
        #---------------------------------------
        # check for errors in log
        #---------------------------------------
        check_httpd_log $sitetag
        if [[ $? -gt 0 ]]; then
          outcome=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'`
          notes=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[3]}'`
          notes="$notes I"
          summary_list[alist-1]="${sitetag}|${outcome}|${notes}|ERROR"
        fi

        #---------------------------------------
        # check for errors in plugin log
        #---------------------------------------
        check_plugin_log $sitetag
        if [[ $? -gt 0 ]]; then
          outcome=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'`
          notes=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[3]}'`
          notes="$notes J"
          summary_list[alist-1]="${sitetag}|${outcome}|${notes}|ERROR"
        fi
      fi
    done

    #---------------------------------------
    # Start ITM khtagent if required
    #---------------------------------------
    if [[ $khtagent -eq 1 ]]; then
      ${lib_home}/ihs/bin/highlight.pl "Performing ITM khtagent start >>>" HEADER; echo

      khtagent_start $khtagent_status
      rc=$?
      if [[ $rc -gt 0 ]]; then
        for alist in ${action_list_index}; do
          sitetag=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[1]}'`
          outcome=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'`
          notes=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[3]}'`
          highlight=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[4]}'`
          case $rc in
            1)  if [[ $highlight != "ERROR" ]]; then
                  notes="$notes K|UNKNOWN" 
                else
                  notes="$notes K|ERROR
                fi ;;
            2)  if [[ $highlight != "ERROR" ]]; then
                  notes="$notes L|UNKNOWN" 
                else
                  notes="$notes K|ERROR
                fi ;;
            3)  notes="$notes M|ERROR" ;;
          esac
          summary_list[alist-1]="${sitetag}|${outcome}|${notes}"
        done
      fi
    fi

    echo ""
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #         Start Sequence          #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #            Complete             #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    echo ""
  fi

  #---------------------------------------
  # Print Summation
  #---------------------------------------
  echo ""
  print_summary
}

#=================================================================
# Handle IHS stops
#=================================================================
function stopihs 
{
  typeset sitetag instance state notes summary_list_index highlight
  typeset -i index_num alist slist rc khtagent=0 khtagent_status

  #Check state of each requested site.  Build separate list
  #for those that are running and those that we can action

  for index_num in $site_selection;
  do
    sitetag=`echo ${inst_sites[index_num-1]}| awk {'print $1'}`
    instance=`echo ${inst_sites[index_num-1]}| awk {'print $3'}`
    state=`echo ${inst_sites[index_num-1]}| awk {'print $2'} | sed 's/(//'| sed 's/)//'`
    notes=""

    if [[ $state = "Stopped" ]]; then
      summary_list[index_num-1]="${sitetag}|Already Stopped| |GOLDEN"
      if [[ $summary_list_index = "" ]]; then
        summary_list_index="${index_num}"
      else
        summary_list_index="${summary_list_index} ${index_num}"
      fi
    else
      if [[ $action_list_index = "" ]]; then
        action_list_index=$index_num
      else
        action_list_index="$action_list_index $index_num"
      fi
    fi
  done

  if [[ $debug -eq 1 ]]; then
    echo "Summary list is:"
    for slist in ${summary_list_index}; do
      echo "$slist ${summary_list[slist-1]}"
    done

    echo ""
    echo "Action_list is:"
    for alist in ${action_list_index}; do
      echo "$alist ${inst_sites[alist-1]}"
    done
  fi

  if [[ $action_list_index != "" ]]; then

    if [ `uname` == "AIX" ]; then
      LIBPATH="/projects/${sitetag}/lib"
      export LIBPATH
    elif [ `uname` == "Linux" ]; then
      LD_LIBRARY_PATH="/projects/${sitetag}/lib"
      export LD_LIBRARY_PATH
    fi

    echo ""
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #         Stop Sequence           #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    echo ""

    #---------------------------------------
    # Determine if any actionable sites have 
    # ITM khtagent configured
    #---------------------------------------
    echo ""
    ${lib_home}/ihs/bin/highlight.pl "Determining Install Status of ITM khtagent >>>" HEADER; echo
    echo ""

    find_khtagent
    khtagent=$?

    #---------------------------------------
    # Stop ITM khtagent if required
    #---------------------------------------
    if [[ $khtagent -eq 1 ]]; then
      echo ""
      ${lib_home}/ihs/bin/highlight.pl "Performing ITM khtagent stop >>>" HEADER; echo

      khtagent_stop
      rc=$?
      if [[ $rc -eq 2 ]]; then
        for alist in ${action_list_index}; do
          sitetag=`echo ${inst_sites[alist-1]}| awk {'print $1'}`
          summary_list[alist-1]="${sitetag}|Start Failed|E|ERROR"
        done
        echo ""
        print_summary
        exit 1
      elif [[ $rc -eq 1 ]]; then
        khtagent_status=1
      else
        khtagent_status=0
      fi
    fi

    #-----------------------------------------------
    # Perform shutdown sequence for each selected
    # actionable site 
    #-----------------------------------------------
    for alist in ${action_list_index}; do
      sitetag=`echo ${inst_sites[alist-1]}| awk {'print $1'}`
      instance=`echo ${inst_sites[alist-1]}| awk {'print $3'}`

      echo ""
      ${lib_home}/ihs/bin/highlight.pl "Now performing stop on sitetag: ${sitetag} >>>" HEADER; echo
      echo ""

      if [ `uname` == "AIX" ]; then
        LIBPATH="/projects/${sitetag}/lib"
        export LIBPATH
      elif [ `uname` == "Linux" ]; then
        LD_LIBRARY_PATH="/projects/${sitetag}/lib"
        export LD_LIBRARY_PATH
      fi

      #-----------------------------------------------
      # Issue stop command
      #-----------------------------------------------
      stop_sitetag $sitetag $instance $alist
    done

    #---------------------------------------
    # Start ITM khtagent if required
    #---------------------------------------
    if [[ $khtagent -eq 1 ]]; then
      echo ""
      ${lib_home}/ihs/bin/highlight.pl "Performing ITM khtagent start >>>" HEADER; echo

      khtagent_start $khtagent_status
      rc=$?
      if [[ $rc -gt 0 ]]; then
        for alist in ${action_list_index}; do
          sitetag=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[1]}'`
          outcome=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'`
          notes=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[3]}'`
          highlight=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[4]}'`
          case $rc in
            1)  if [[ $highlight != "ERROR" ]]; then
                  notes="$notes K|UNKNOWN" 
                else
                  notes="$notes K|ERROR
                fi ;;
            2)  if [[ $highlight != "ERROR" ]]; then
                  notes="$notes L|UNKNOWN" 
                else
                  notes="$notes K|ERROR
                fi ;;
            3)  notes="$notes M|ERROR" ;;
          esac
          summary_list[alist-1]="${sitetag}|${outcome}|${notes}"
        done
      fi
    fi

    echo ""
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #         Stop Sequence           #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #           Complete              #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    echo ""
  fi

  #---------------------------------------
  # Print Summation
  #---------------------------------------
  echo ""
  print_summary
}

#=================================================================
# Handle IHS graceful stops
#=================================================================
function gracefulstopihs 
{
  typeset sitetag instance state notes summary_list_index highlight
  typeset -i index_num alist slist rc khtagent=0 khtagent_status

  #Check state of each requested site.  Build separate list
  #for those that are running and those that we can action

  for index_num in $site_selection;
  do
    sitetag=`echo ${inst_sites[index_num-1]}| awk {'print $1'}`
    instance=`echo ${inst_sites[index_num-1]}| awk {'print $3'}`
    state=`echo ${inst_sites[index_num-1]}| awk {'print $2'} | sed 's/(//'| sed 's/)//'`
    notes=""

    if [[ $state = "Stopped" ]]; then
      summary_list[index_num-1]="${sitetag}|Already Stopped| |GOLDEN"
      if [[ $summary_list_index = "" ]]; then
        summary_list_index="${index_num}"
      else
        summary_list_index="${summary_list_index} ${index_num}"
      fi
    else
      if [[ $action_list_index = "" ]]; then
        action_list_index=$index_num
      else
        action_list_index="$action_list_index $index_num"
      fi
    fi
  done

  if [[ $debug -eq 1 ]]; then
    echo "Summary list is:"
    for slist in ${summary_list_index}; do
      echo "$slist ${summary_list[slist-1]}"
    done

    echo ""
    echo "Action_list is:"
    for alist in ${action_list_index}; do
      echo "$alist ${inst_sites[alist-1]}"
    done
  fi

  if [[ $action_list_index != "" ]]; then

    if [ `uname` == "AIX" ]; then
      LIBPATH="/projects/${sitetag}/lib"
      export LIBPATH
    elif [ `uname` == "Linux" ]; then
      LD_LIBRARY_PATH="/projects/${sitetag}/lib"
      export LD_LIBRARY_PATH
    fi

    echo ""
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #    Graceful Stop Sequence       #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    echo ""

    #---------------------------------------
    # Determine if any actionable sites have 
    # ITM khtagent configured
    #---------------------------------------
    echo ""
    ${lib_home}/ihs/bin/highlight.pl "Determining Install Status of ITM khtagent >>>" HEADER; echo
    echo ""

    find_khtagent
    khtagent=$?

    #---------------------------------------
    # Stop ITM khtagent if required
    #---------------------------------------
    if [[ $khtagent -eq 1 ]]; then
      echo ""
      ${lib_home}/ihs/bin/highlight.pl "Performing ITM khtagent stop >>>" HEADER; echo

      khtagent_stop
      rc=$?
      if [[ $rc -eq 2 ]]; then
        for alist in ${action_list_index}; do
          sitetag=`echo ${inst_sites[alist-1]}| awk {'print $1'}`
          summary_list[alist-1]="${sitetag}|Start Failed|E|ERROR"
        done
        echo ""
        print_summary
        exit 1
      elif [[ $rc -eq 1 ]]; then
        khtagent_status=1
      else
        khtagent_status=0
      fi
    fi

    #-----------------------------------------------
    # Perform shutdown sequence for each selected
    # actionable site 
    #-----------------------------------------------
    for alist in ${action_list_index}; do
      sitetag=`echo ${inst_sites[alist-1]}| awk {'print $1'}`
      instance=`echo ${inst_sites[alist-1]}| awk {'print $3'}`

      echo ""
      ${lib_home}/ihs/bin/highlight.pl "Now performing graceful stop on sitetag: ${sitetag} >>>" HEADER; echo
      echo ""

      if [ `uname` == "AIX" ]; then
        LIBPATH="/projects/${sitetag}/lib"
        export LIBPATH
      elif [ `uname` == "Linux" ]; then
        LD_LIBRARY_PATH="/projects/${sitetag}/lib"
        export LD_LIBRARY_PATH
      fi

      #-----------------------------------------------
      # Issue graceful stop command
      #-----------------------------------------------
      graceful_stop_sitetag $sitetag $instance $alist
    done

    #---------------------------------------
    # Start ITM khtagent if required
    #---------------------------------------
    if [[ $khtagent -eq 1 ]]; then
      echo ""
      ${lib_home}/ihs/bin/highlight.pl "Performing ITM khtagent start >>>" HEADER; echo

      khtagent_start $khtagent_status
      rc=$?
      if [[ $rc -gt 0 ]]; then
        for alist in ${action_list_index}; do
          sitetag=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[1]}'`
          outcome=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'`
          notes=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[3]}'`
          highlight=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[4]}'`
          case $rc in
            1)  if [[ $highlight != "ERROR" ]]; then
                  notes="$notes K|UNKNOWN"
                else
                  notes="$notes K|ERROR
                fi ;;
            2)  if [[ $highlight != "ERROR" ]]; then
                  notes="$notes L|UNKNOWN" 
                else
                  notes="$notes K|ERROR
                fi ;;
            3)  notes="$notes M|ERROR" ;;
          esac
          summary_list[alist-1]="${sitetag}|${outcome}|${notes}"
        done
      fi
    fi

    echo ""
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #    Graceful Stop Sequence       #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #           Complete              #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    echo ""
  fi

  #---------------------------------------
  # Print Summation
  #---------------------------------------
  echo ""
  print_summary
}

#=================================================================
# Handle IHS restarts
#=================================================================
function restartihs 
{
  typeset sitetag instance state http_check plugin_check notes notes_tmp summary_list_index highlight details=$1
  typeset -i stop_rc index_num alist slist rc khtagent=0 khtagent_status

  #Validate configs and status to determine if the requested list can be actioned
  #Build separate list for those requested sites that pass the test
  #and store status for those that do not for summary at the end
  echo ""
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #            Prechecks            #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  echo ""

  for index_num in $site_selection;
  do
    sitetag=`echo ${inst_sites[index_num-1]}| awk {'print $1'}`
    instance=`echo ${inst_sites[index_num-1]}| awk {'print $3'}`
    state=`echo ${inst_sites[index_num-1]}| awk {'print $2'} | sed 's/(//'| sed 's/)//'`
    notes=""

    ${lib_home}/ihs/bin/highlight.pl "Now performing pre-checks on site: ${sitetag} >>>" HEADER; echo

    if [ `uname` == "AIX" ]; then
      LIBPATH="/projects/${sitetag}/lib"
      export LIBPATH
    elif [ `uname` == "Linux" ]; then
      LD_LIBRARY_PATH="/projects/${sitetag}/lib"
      export LD_LIBRARY_PATH
    fi

    validate_httpd $sitetag $instance $details
    httpd_check=$?
    validate_plugin $sitetag $details
    plugin_check=$?
    if [[ $debug -eq 1 ]]; then
      echo ""
      echo "httpd_check is $httpd_check"
      echo "plugin_check is $plugin_check"
      echo "state is $state"
      echo ""
    fi

    if [[ $httpd_check -eq 0 && $plugin_check -eq 0 ]]; then
      if [[ $action_list_index = "" ]]; then
        action_list_index=$index_num
      else
        action_list_index="$action_list_index $index_num"
      fi
    else
      if [[ $httpd_check -eq 1 || $httpd_check -eq 3 ]]; then
        notes="${notes} A"
      fi
      if [[ $httpd_check -eq 2 || $httpd_check -eq 3 ]]; then
        notes="${notes} B"
      fi
      if [[ $plugin_check -eq 4 || $plugin_check -eq 12 ]]; then
        notes="${notes} C"
      fi
      if [[ $plugin_check -eq 8 || $plugin_check -eq 12 ]]; then
        notes="${notes} D"
      fi 
      if [[ $ignore_ver -eq 1 ]]; then
        notes="${notes} O"
      fi
      summary_list[index_num-1]="${sitetag}|Failed Prechecks - Restart Aborted|$notes|ERROR"
      if [[ $summary_list_index = "" ]]; then
        summary_list_index="${index_num}"
      else
        summary_list_index="${summary_list_index} ${index_num}"
      fi
    fi
  done

  if [[ $debug -eq 1 ]]; then
    echo "Summary list is:"
    for slist in ${summary_list_index}; do
      echo "$slist ${summary_list[slist-1]}"
    done

    echo ""
    echo "Action_list is:"
    for alist in ${action_list_index}; do
      echo "$alist ${inst_sites[alist-1]}"
    done  
  fi
  
  echo ""
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #            Prechecks            #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #            Complete             #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  echo ""

  if [[ $action_list_index != "" ]]; then
    echo ""
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #        Restart Sequence         #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    echo ""
    
    #---------------------------------------
    # Determine if any actionable sites have 
    # ITM khtagent configured
    #---------------------------------------
    echo ""
    ${lib_home}/ihs/bin/highlight.pl "Determining Install Status of ITM khtagent >>>" HEADER; echo
    echo ""

    find_khtagent
    khtagent=$?
  
    #---------------------------------------
    # Stop ITM khtagent if required
    #---------------------------------------
    if [[ $khtagent -eq 1 ]]; then
      echo ""
      ${lib_home}/ihs/bin/highlight.pl "Performing ITM khtagent stop >>>" HEADER; echo

      khtagent_stop 
      rc=$?
      if [[ $rc -eq 2 ]]; then
        for alist in ${action_list_index}; do
          sitetag=`echo ${inst_sites[alist-1]}| awk {'print $1'}`
          summary_list[alist-1]="${sitetag}|Restart Failed|E|ERROR"
        done
        echo ""
        print_summary
        exit 1
      elif [[ $rc -eq 1 ]]; then
        khtagent_status=1
      else 
        khtagent_status=0
      fi
    fi

    #---------------------------------------
    # Run rc.IP_aliases
    #---------------------------------------
    echo ""
    ${lib_home}/ihs/bin/highlight.pl "Running rc.IP_aliases >>>" HEADER; echo
    echo ""

    if [[ $ignore_IP != 1 ]]; then
      /usr/local/etc/rc.IP_aliases
      if [[ $? -gt 0 ]]; then
        for alist in ${action_list_index}; do
          sitetag=`echo ${inst_sites[alist-1]}| awk {'print $1'}`
          summary_list[alist-1]="${sitetag}|Restart Failed|F|ERROR"
        done
        echo ""
        print_summary
        exit 2
      else
        echo "rc.IP_aliases complete"
      fi
    else
      echo "The ignore aliases parameter has been selected -- skipping"
      echo "  action to run rc.IP_aliases"
    fi  
  
    #-----------------------------------------------
    # Perform restartup sequence for each selected
    # actionable site 
    #-----------------------------------------------
    for alist in ${action_list_index}; do 
      sitetag=`echo ${inst_sites[alist-1]}| awk {'print $1'}`
      instance=`echo ${inst_sites[alist-1]}| awk {'print $3'}`
      state=`echo ${inst_sites[alist-1]}| awk {'print $2'} | sed 's/(//'| sed 's/)//'`
      notes_tmp=""
      stop_rc=0

      echo ""
      ${lib_home}/ihs/bin/highlight.pl "Now performing restart on sitetag: ${sitetag} >>>" HEADER; echo
      echo ""

      #-----------------------------------------------
      # Issue stop command
      #-----------------------------------------------
      echo "Issue stop command ..."
      if [[ $state = "Stopped" ]]; then
        echo "IHS is already stopped -- Skipping stop command"
        notes_tmp="R"
      else
        stop_sitetag $sitetag $instance $alist
        stop_rc=$?
      fi
      
      if [[ $stop_rc -eq 0 ]]; then
        #-----------------------------------------------
        # Issue start command
        #-----------------------------------------------
        echo ""
        echo "Issue start command ..."
        start_sitetag $sitetag $instance $alist

        if [[ $? -eq 0 ]]; then
          #---------------------------------------
          # check for errors in log
          #---------------------------------------
          check_httpd_log $sitetag
          if [[ $? -gt 0 ]]; then
            outcome=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'`
            notes=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[3]}'`
            notes="$notes I"
            summary_list[alist-1]="${sitetag}|${outcome}|${notes}|ERROR"
          fi

          #---------------------------------------
          # check for errors in plugin log
          #---------------------------------------
          check_plugin_log $sitetag
          if [[ $? -gt 0 ]]; then
            outcome=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'`
            notes=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[3]}'`
            notes="$notes J"
            summary_list[alist-1]="${sitetag}|${outcome}|${notes}|ERROR"
          fi
        fi
      
        #---------------------------------------
        # Add any shutdown messages to the notes
        #---------------------------------------
        if [[ $notes_tmp != "" ]]; then
          outcome=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'`
          notes=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[3]}'`
          notes="$notes $notes_tmp"
          highlight=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[4]}'`

          if [[ $highlight != "ERROR" ]]; then
            summary_list[alist-1]="${sitetag}|${outcome}|${notes}|UNKNOWN"
          else
            summary_list[alist-1]="${sitetag}|${outcome}|${notes}|ERROR"
          fi

        fi
      else
        outcome=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'`
        notes=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[3]}'`
        notes="$notes AA"
        highlight=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[4]}'`

        summary_list[alist-1]="${sitetag}|${outcome}|${notes}|$highlight"
      fi
    done

    #---------------------------------------
    # Start ITM khtagent if required
    #---------------------------------------
    if [[ $khtagent -eq 1 ]]; then
      ${lib_home}/ihs/bin/highlight.pl "Performing ITM khtagent start >>>" HEADER; echo

      khtagent_start $khtagent_status
      rc=$?
      if [[ $rc -gt 0 ]]; then
        for alist in ${action_list_index}; do
          sitetag=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[1]}'`
          outcome=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'`
          notes=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[3]}'`
          highlight=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[4]}'`
          case $rc in
            1)  if [[ $highlight != "ERROR" ]]; then
                  notes="$notes K|UNKNOWN" 
                else
                  notes="$notes K|ERROR
                fi ;;
            2)  if [[ $highlight != "ERROR" ]]; then
                  notes="$notes L|UNKNOWN" 
                else
                  notes="$notes K|ERROR
                fi ;;
            3)  notes="$notes M|ERROR" ;;
          esac
          summary_list[alist-1]="${sitetag}|${outcome}|${notes}"
        done
      fi
    fi

    echo ""
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #       Restart Sequence          #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #           Complete              #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    echo ""
  fi

  #---------------------------------------
  # Print Summation
  #---------------------------------------
  echo ""
  print_summary
}

#=================================================================
# Handle IHS graceful restarts
#=================================================================
function gracefulrestartihs 
{
  typeset sitetag instance state http_check plugin_check notes notes_tmp summary_list_index highlight details=$1
  typeset -i stop_rc index_num alist slist rc khtagent=0 khtagent_status

  #Validate configs and status to determine if the requested list can be actioned
  #Build separate list for those requested sites that pass the test
  #and store status for those that do not for summary at the end
  echo ""
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #            Prechecks            #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  echo ""

  for index_num in $site_selection;
  do
    sitetag=`echo ${inst_sites[index_num-1]}| awk {'print $1'}`
    instance=`echo ${inst_sites[index_num-1]}| awk {'print $3'}`
    state=`echo ${inst_sites[index_num-1]}| awk {'print $2'} | sed 's/(//'| sed 's/)//'`
    notes=""

    ${lib_home}/ihs/bin/highlight.pl "Now performing pre-checks on site: ${sitetag} >>>" HEADER; echo

    if [ `uname` == "AIX" ]; then
      LIBPATH="/projects/${sitetag}/lib"
      export LIBPATH
    elif [ `uname` == "Linux" ]; then
      LD_LIBRARY_PATH="/projects/${sitetag}/lib"
      export LD_LIBRARY_PATH
    fi

    validate_httpd $sitetag $instance $details
    httpd_check=$?
    validate_plugin $sitetag $details
    plugin_check=$?
    if [[ $debug -eq 1 ]]; then
      echo ""
      echo "httpd_check is $httpd_check"
      echo "plugin_check is $plugin_check"
      echo "state is $state"
      echo ""
    fi

    if [[ $httpd_check -eq 0 && $plugin_check -eq 0 ]]; then
      if [[ $action_list_index = "" ]]; then
        action_list_index=$index_num
      else
        action_list_index="$action_list_index $index_num"
      fi
    else
      if [[ $httpd_check -eq 1 || $httpd_check -eq 3 ]]; then
        notes="${notes} A"
      fi
      if [[ $httpd_check -eq 2 || $httpd_check -eq 3 ]]; then
        notes="${notes} B"
      fi
      if [[ $plugin_check -eq 4 || $plugin_check -eq 12 ]]; then
        notes="${notes} C"
      fi
      if [[ $plugin_check -eq 8 || $plugin_check -eq 12 ]]; then
        notes="${notes} D"
      fi
      if [[ $ignore_ver -eq 1 ]]; then
        notes="${notes} O"
      fi
      summary_list[index_num-1]="${sitetag}|Failed Prechecks - Restart Aborted|$notes|ERROR"
      if [[ $summary_list_index = "" ]]; then
        summary_list_index="${index_num}"
      else
        summary_list_index="${summary_list_index} ${index_num}"
      fi
    fi
  done

  if [[ $debug -eq 1 ]]; then
    echo "Summary list is:"
    for slist in ${summary_list_index}; do
      echo "$slist ${summary_list[slist-1]}"
    done

    echo ""
    echo "Action_list is:"
    for alist in ${action_list_index}; do
      echo "$alist ${inst_sites[alist-1]}"
    done
  fi

  echo ""
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #            Prechecks            #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #            Complete             #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  echo ""

  if [[ $action_list_index != "" ]]; then
    echo ""
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #    Graceful Restart Sequence    #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    echo ""

    #---------------------------------------
    # Determine if any actionable sites have 
    # ITM khtagent configured
    #---------------------------------------
    echo ""
    ${lib_home}/ihs/bin/highlight.pl "Determining Install Status of ITM khtagent >>>" HEADER; echo
    echo ""

    find_khtagent
    khtagent=$?

    #---------------------------------------
    # Stop ITM khtagent if required
    #---------------------------------------
    if [[ $khtagent -eq 1 ]]; then
      echo ""
      ${lib_home}/ihs/bin/highlight.pl "Performing ITM khtagent stop >>>" HEADER; echo

      khtagent_stop
      rc=$?
      if [[ $rc -eq 2 ]]; then
        for alist in ${action_list_index}; do
          sitetag=`echo ${inst_sites[alist-1]}| awk {'print $1'}`
          summary_list[alist-1]="${sitetag}|Restart Failed|E|ERROR"
        done
        echo ""
        print_summary
        exit 1
      elif [[ $rc -eq 1 ]]; then
        khtagent_status=1
      else
        khtagent_status=0
      fi
    fi

    #---------------------------------------
    # Run rc.IP_aliases
    #---------------------------------------
    echo ""
    ${lib_home}/ihs/bin/highlight.pl "Running rc.IP_aliases >>>" HEADER; echo
    echo ""

    if [[ $ignore_IP != 1 ]]; then
      /usr/local/etc/rc.IP_aliases
      if [[ $? -gt 0 ]]; then
        for alist in ${action_list_index}; do
          sitetag=`echo ${inst_sites[alist-1]}| awk {'print $1'}`
          summary_list[alist-1]="${sitetag}|Restart Failed|F|ERROR"
        done
        echo ""
        print_summary
        exit 2
      else
        echo "rc.IP_aliases complete"
      fi
    else
      echo "The ignore aliases parameter has been selected -- skipping"
      echo "  action to run rc.IP_aliases"
    fi

    #-----------------------------------------------
    # Perform restartup sequence for each selected
    # actionable site 
    #-----------------------------------------------
    for alist in ${action_list_index}; do
      sitetag=`echo ${inst_sites[alist-1]}| awk {'print $1'}`
      instance=`echo ${inst_sites[alist-1]}| awk {'print $3'}`
      state=`echo ${inst_sites[alist-1]}| awk {'print $2'} | sed 's/(//'| sed 's/)//'`
      notes_tmp=""
      stop_rc=0

      echo ""
      ${lib_home}/ihs/bin/highlight.pl "Now performing graceful restart on sitetag: ${sitetag} >>>" HEADER; echo
      echo ""

      #-----------------------------------------------
      # Issue graceful stop command
      #-----------------------------------------------
      echo "Issue graceful stop command ..."
      if [[ $state = "Stopped" ]]; then
        echo "IHS is already stopped -- Skipping graceful stop command"
        notes_tmp="Z"
      else
        graceful_stop_sitetag $sitetag $instance $alist
        stop_rc=$?
      fi

      if [[ $stop_rc -eq 0 ]]; then
        #-----------------------------------------------
        # Issue start command
        #-----------------------------------------------
        echo ""
        echo "Issue start command ..."
        start_sitetag $sitetag $instance $alist

        if [[ $? -eq 0 ]]; then
          #---------------------------------------
          # check for errors in log
          #---------------------------------------
          check_httpd_log $sitetag
          if [[ $? -gt 0 ]]; then
            outcome=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'`
            notes=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[3]}'`
            notes="$notes I"
            summary_list[alist-1]="${sitetag}|${outcome}|${notes}|ERROR"
          fi

          #---------------------------------------
          # check for errors in plugin log
          #---------------------------------------
          check_plugin_log $sitetag
          if [[ $? -gt 0 ]]; then
            outcome=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'`
            notes=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[3]}'`
            notes="$notes J"
            summary_list[alist-1]="${sitetag}|${outcome}|${notes}|ERROR"
          fi
        fi

        #---------------------------------------
        # Add any shutdown messages to the notes
        #---------------------------------------
        if [[ $notes_tmp != "" ]]; then
          outcome=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'`
          notes=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[3]}'`
          notes="$notes $notes_tmp"
          highlight=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[4]}'`

          if [[ $highlight != "ERROR" ]]; then
            summary_list[alist-1]="${sitetag}|${outcome}|${notes}|UNKNOWN"
          else
            summary_list[alist-1]="${sitetag}|${outcome}|${notes}|ERROR"
          fi

        fi
      else
        outcome=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'`
        notes=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[3]}'`
        notes="$notes AB"
        highlight=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[4]}'`

        summary_list[alist-1]="${sitetag}|${outcome}|${notes}|$highlight"
      fi
    done

    #---------------------------------------
    # Start ITM khtagent if required
    #---------------------------------------
    if [[ $khtagent -eq 1 ]]; then
      ${lib_home}/ihs/bin/highlight.pl "Performing ITM khtagent start >>>" HEADER; echo

      khtagent_start $khtagent_status
      rc=$?
      if [[ $rc -gt 0 ]]; then
        for alist in ${action_list_index}; do
          sitetag=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[1]}'`
          outcome=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'`
          notes=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[3]}'`
          highlight=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[4]}'`
          case $rc in
            1)  if [[ $highlight != "ERROR" ]]; then
                  notes="$notes K|UNKNOWN"
                else
                  notes="$notes K|ERROR
                fi ;;
            2)  if [[ $highlight != "ERROR" ]]; then
                  notes="$notes L|UNKNOWN" 
                else
                  notes="$notes K|ERROR
                fi ;;
            3)  notes="$notes M|ERROR" ;;
          esac
          summary_list[alist-1]="${sitetag}|${outcome}|${notes}"
        done
      fi
    fi

    echo ""
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #    Graceful Restart Sequence    #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #           Complete              #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
    ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
    echo ""
  fi

  #---------------------------------------
  # Print Summation
  #---------------------------------------
  echo ""
  print_summary
}

#=================================================================
# Handle IHS/Plugin configtest
#=================================================================
function configtestihs
{
  typeset sitetag instance http_check plugin_check notes summary_list_index details=$1
  typeset -i index_num

  #Will perform configuration checks on all selected sites
  echo ""
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #     Site Configuration Tests    #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  echo ""

  for index_num in $site_selection;
  do
    sitetag=`echo ${inst_sites[index_num-1]}| awk {'print $1'}`
    instance=`echo ${inst_sites[index_num-1]}| awk {'print $3'}`
    notes=""

    ${lib_home}/ihs/bin/highlight.pl "Now performing configuration tests on site: ${sitetag} >>>" HEADER; echo

    if [ `uname` == "AIX" ]; then
      LIBPATH="/projects/${sitetag}/lib"
      export LIBPATH
    elif [ `uname` == "Linux" ]; then
      LD_LIBRARY_PATH="/projects/${sitetag}/lib"
      export LD_LIBRARY_PATH
    fi

    validate_httpd $sitetag $instance $details
    httpd_check=$?
    validate_plugin $sitetag $details
    plugin_check=$?
    if [[ $debug -eq 1 ]]; then
      echo ""
      echo "httpd_check is $httpd_check"
      echo "plugin_check is $plugin_check"
      echo "state is $state"
      echo ""
    fi

    if [[ $httpd_check -ne 0 || $plugin_check -ne 0 ]]; then
      if [[ $httpd_check -eq 1 || $httpd_check -eq 3 ]]; then
        notes="${notes} A"
      fi
      if [[ $httpd_check -eq 2 || $httpd_check -eq 3 ]]; then
        notes="${notes} B"
      fi
      if [[ $plugin_check -eq 4 || $plugin_check -eq 12 ]]; then
        notes="${notes} C"
      fi
      if [[ $plugin_check -eq 8 || $plugin_check -eq 12 ]]; then
        notes="${notes} D"
      fi
      if [[ $ignore_ver -eq 1 ]]; then
        notes="${notes} O"
      fi
      summary_list[index_num-1]="${sitetag}|Failed Site Configuration Tests|$notes|ERROR"
    else
      summary_list[index_num-1]="${sitetag}|Completed Site Configuration Tests|$notes|GOLDEN"
    fi
    if [[ $summary_list_index = "" ]]; then
      summary_list_index="${index_num}"
    else
      summary_list_index="${summary_list_index} ${index_num}"
    fi
  done

  echo ""
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #    Site Configuration Tests     #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #           Complete              #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  echo ""
 
  #---------------------------------------
  # Print Summation
  #---------------------------------------
  echo ""
  print_summary
}

#=================================================================
# Handle IHS status
#=================================================================
function statusihs 
{
  typeset header doc http_code return_code fqn config apachectl state sitetag instance notes summary_list_index details=$1
  typeset -i index_num

  #Will perform status checks on all selected sites
  echo ""
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #        Site Status Tests        #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  echo ""

  for index_num in $site_selection;
  do
    sitetag=`echo ${inst_sites[index_num-1]}| awk {'print $1'}`
    instance=`echo ${inst_sites[index_num-1]}| awk {'print $3'}`
    notes=""

    ${lib_home}/ihs/bin/highlight.pl "Now performing status tests on site: ${sitetag} >>>" HEADER; echo; echo

    if [ `uname` == "AIX" ]; then
      LIBPATH="/projects/${sitetag}/lib"
      export LIBPATH
    elif [ `uname` == "Linux" ]; then
      LD_LIBRARY_PATH="/projects/${sitetag}/lib"
      export LD_LIBRARY_PATH
    fi

    state=`verify_state $sitetag`

    if [[ $state = "Running" ]]; then

      config=`sitetag_config $sitetag`
      apachectl=`sitetag_apachectl $instance`

      if [[ $sitetag == "HTTPServer" ]]; then
        fqn="localhost"
      else
        fqn=`sed -n '2 p' /projects/${sitetag}/conf/listen.conf | awk '{print $2}' | awk -F: '{print $1}'`
      fi


      #------------------------------------------------
      # show IHS server-status header
      #------------------------------------------------
      ${lib_home}/ihs/bin/highlight.pl "Show Server Status Header for Site -->" SUBHEADER; echo
      lynx -dump http://${fqn}/server-status 2>&1 | grep Restart 2>&1 >/dev/null
      return_code=$?
      if [[ $return_code -gt 0 ]]; then
        echo
        if [[ $details = "true" ]]; then
          echo
          header=`curl -s -I -v http://${fqn}/server-status 2>&1`
          echo "$header"
          echo
        fi
        echo "  Server Status module not installed or URI server-status unreachable"
        notes="${notes} V"
        summary_list[index_num-1]="${sitetag}|Completed Site Status Test|$notes|UNKNOWN"
      else
        doc=`lynx -dump http://${fqn}/server-status | awk ' /workers$/ { print; exit } { print } '` 
        if [[ $details = "true" ]]; then
          echo
          header=`curl -s -I -v http://${fqn}/server-status 2>&1`
          echo "$header"
        fi
        echo "$doc"
      fi
      echo

      #------------------------------------------------
      # show configured vhosts
      #------------------------------------------------
      ${lib_home}/ihs/bin/highlight.pl "List Configured VHost(s) -->" SUBHEADER; echo; echo
      https=0
      http=0
      other=0
      vhosts=`$apachectl -f /projects/${sitetag}/conf/$config -S 2>&1 | awk '{print $1"+"$2"+"$3}'`
      for vhost in $vhosts; do
        if echo $vhost | grep ":443" >/dev/null; then
          https=`expr $https + 1`
        elif echo $vhost | grep ":80" >/dev/null; then
          http=`expr $http + 1`
        elif echo $vhost | grep ":[1-9]" >/dev/null; then
          other=`expr $other + 1`
        fi 
        if [[ $details = "true" ]]; then
          echo $vhost | grep ":[1-9]"| awk -F "+" '{print $1"\t"$2" "$3}'
        fi
      done
      if [[ $details = "true" && $https -eq 0 && $http -eq 0 && $other -eq 0 ]]; then
        echo "  No vhost found"
      fi
      if [[ $details != "true" ]]; then
        print "  Defined vhosts\n  -----------------------------------------------"
        print "  http:\t$http\thttps:\t$https\tOther:\t$other"
      fi
      echo

      global_http_request $fqn
      if [[ $? -gt 0 ]]; then
        notes="$notes W"
        summary_list[index_num-1]="${sitetag}|Failed Site Status Test|$notes|ERROR"
      fi

      if [[ $https -gt 0 ]]; then
        default_ssl_http_request $fqn
        if [[ $? -gt 0 ]]; then
          notes="$notes X"
          summary_list[index_num-1]="${sitetag}|Failed Site Status Test|$notes|ERROR"
        fi
      fi

      if [[ $notes = "" ]]; then
        summary_list[index_num-1]="${sitetag}|Completed Site Status Test|$notes|GOLDEN"
      fi
    else 
      echo "  Site has no detected root process"
      echo
      notes="$notes Y"
      summary_list[index_num-1]="${sitetag}|Completed Site Status Test|$notes|UNKNOWN"
    fi
  done

  echo ""
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #       Site Status Tests         #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #           Complete              #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  echo ""

  #---------------------------------------
  # Print Summation
  #---------------------------------------
  echo ""
  print_summary  
}

#=================================================================
# Handle IHS fullstatus
#=================================================================
function fullstatusihs
{
  typeset test_phrase header doc http_code return_code fqn state sitetag notes summary_list_index details=$1
  typeset -i index_num
  typeset wait_conn startup read_req send_rep keepalive dns_look close_conn logging grace_fin idle_clean

  #Will perform status checks on all selected sites
  echo ""
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #     Site Full Status Tests      #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  echo ""

  for index_num in $site_selection;
  do
    sitetag=`echo ${inst_sites[index_num-1]}| awk {'print $1'}`
    notes=""

    if [[ $details = "true" ]]; then
      test_phrase=" "
    else
      test_phrase=" tests "
    fi

    ${lib_home}/ihs/bin/highlight.pl "Now performing full status${test_phrase}on site: ${sitetag} >>>" HEADER; echo

    state=`verify_state $sitetag`

    if [[ $state = "Running" ]]; then

      if [[ $sitetag == "HTTPServer" ]]; then
        fqn="localhost"
      else
        fqn=`sed -n '2 p' /projects/${sitetag}/conf/listen.conf | awk '{print $2}' | awk -F: '{print $1}'`
      fi

      lynx -dump http://${fqn}/server-status 2>&1 | grep Restart 2>&1 >/dev/null
      return_code=$?
      if [[ $return_code -gt 0 ]]; then
        echo
        if [[ $details = "true" ]]; then
          echo
          header=`curl -s -I -v http://${fqn}/server-status 2>&1`
          echo "$header"
          echo
        fi
        echo "  Server Status module not installed or URI server-status unreachable"
        echo
        notes="${notes} V"
        summary_list[index_num-1]="${sitetag}|Completed Site Status Test|$notes|UNKNOWN"
        continue
      fi

      doc=`lynx -width 250 -dump http://${fqn}/server-status`

      if [[ $details = "true" ]]; then
        lynx -dump http://${fqn}/server-status
      else
        doc=`lynx -width 250 -dump http://${fqn}/server-status`
      
        #------------------------------------------------
        # show IHS server-status header
        #------------------------------------------------
        echo
        ${lib_home}/ihs/bin/highlight.pl "Show Server Status Header for Site -->" SUBHEADER; echo
        lynx -dump http://${fqn}/server-status | awk 'NR==1,NR==7'
        echo "$doc" | awk '/Current Time:/,/workers$/'
        echo
  
        #------------------------------------------------
        # show IHS server connections
        #------------------------------------------------
        ${lib_home}/ihs/bin/highlight.pl "Show Server Connections for Site -->" SUBHEADER; echo; echo
        wait_conn=`echo "$doc" | grep " _ " | wc -l`
        startup=`echo "$doc" | grep " S " | wc -l`
        read_req=`echo "$doc" | grep " R " | wc -l`
        send_rep=`echo "$doc" | grep " W " | wc -l`
        keepalive=`echo "$doc" | grep " K " | wc -l`
        dns_look=`echo "$doc" | grep " D " | wc -l`
        close_conn=`echo "$doc" | grep " C " | wc -l`
        logging=`echo "$doc" | grep " L " | wc -l`
        grace_fin=`echo "$doc" | grep " G " | wc -l`
        idle_clean=`echo "$doc" | grep " I " | wc -l`
        echo "  Waiting for Connections = $wait_conn   Starting Up = $startup   Reading Requests = $read_req"
        echo "  Sending Reply = $send_rep   Keepalive = $keepalive   DNS Lookup = $dns_look"
        echo "  Closing Connection = $close_conn   Logging = $logging   Gracefully Finishing = $grace_fin"
        echo "  Idle Cleanup of Worker = $idle_clean"
        echo 
  
        #------------------------------------------------
        # show request that are being replied to
        #------------------------------------------------
        ${lib_home}/ihs/bin/highlight.pl "Show Active Request for Site -->" SUBHEADER; echo; echo
        echo "$doc" | grep " W " | awk '{print "  " $13 "\t" $14}' | sort | uniq -c
        echo
      fi
      summary_list[index_num-1]="${sitetag}|Completed Site Status Test|$notes|GOLDEN"
    else
      echo "  Site has no detected root process"
      echo
      notes="$notes Y"
      summary_list[index_num-1]="${sitetag}|Completed Site Status Test|$notes|UNKNOWN"
    fi
  done

  echo ""
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #    Site Full Status Tests       #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #           Complete              #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  #                                 #" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "                  ###################################" BOLD; echo
  echo ""

  #---------------------------------------
  # Print Summation
  #---------------------------------------
  echo ""
  print_summary
}

function global_http_request
{
  typeset return_code http_code doc fqn=$1

  #------------------------------------------------
  # Test http global host
  #------------------------------------------------
  if [[ $action = "status" ]]; then
    ${lib_home}/ihs/bin/highlight.pl "Test Global Vhost via site.txt -->" SUBHEADER; echo; echo
  else
    echo "Verify global server http response ..."
    echo
  fi
  http_code=`curl -s -I -w "%{http_code}" http://${fqn}/site.txt -o /dev/null`
  doc=`curl -s -I -v http://${fqn}/site.txt 2>&1`
  return_code=$?
  if [[ $details = "true" ]]; then
    echo "$doc"
  fi
  echo "  ////////////////////////////////"
  if [[ $return_code -ne 0 || $http_code != "200" ]]; then
    print "  ////\c"
    ${lib_home}/ihs/bin/highlight.pl "  HTTP Request Failed   " ERROR
    print "////"
    return_code=1
  else
    print "  ///\c"
    ${lib_home}/ihs/bin/highlight.pl "  HTTP Request Succeeded  " GOLDEN
    print "///"
    return_code=0
  fi
  echo "  ////////////////////////////////"
  echo ""
  return $return_code
}

function default_ssl_http_request
{
  typeset return_code http_code doc ssl_option fqn=$1

  #------------------------------------------------
  # Test https default host if one is defined
  #------------------------------------------------
  if [[ $action = "status" ]]; then
    ${lib_home}/ihs/bin/highlight.pl "Test Default SSL VirtualHost via site.txt -->" SUBHEADER; echo; echo
  else
    echo "Verify default ssl virtualhost http response ..."
    echo
  fi
  if [[ `uname` = Linux ]]; then
    ssl_option="-k"
  else
    ssl_option=""
  fi
  http_code=`curl $ssl_option -s -I -w "%{http_code}" https://${fqn}/sslsite.txt -o /dev/null`
  doc=`curl $ssl_option -s -I -v https://${fqn}/sslsite.txt 2>&1`
  return_code=$?
  if [[ $details = "true" ]]; then
    echo "$doc"
  fi
  echo "  ////////////////////////////////"
  if [[ $return_code -ne 0 || $http_code != "200" ]]; then
    print "  ////\c"
    ${lib_home}/ihs/bin/highlight.pl "  HTTP Request Failed   " ERROR
    print "////"
    return_code=1
  else
    print "  ///\c"
    ${lib_home}/ihs/bin/highlight.pl "  HTTP Request Succeeded  " GOLDEN
    print "///"
    return_code=0
  fi
  echo "  ////////////////////////////////"
  echo ""
  return $return_code
}

function verify_state 
{
  typeset httpd_pid sitetag=$1

  if [ -f /logs/${sitetag}/httpd.pid ]; then
    httpd_pid=`cat /logs/${sitetag}/httpd.pid`
    if [ "`ps -ef | grep $httpd_pid | grep httpd | grep root | grep ${sitetag} | grep -v grep`" != "" ]; then
      echo "Running"
    else
      echo "Stopped"
      rm /logs/${sitetag}/httpd.pid
    fi
  else
    echo "Stopped"
  fi
}

function sitetag_config 
{
  typeset config sitetag=$1 

  if [[ $sitetag = HTTPServer* ]]; then
    config="httpd.conf"
  else
    config="${sitetag}.conf"
  fi

  echo $config
}

function sitetag_apachectl
{
  typeset apachectl instance=$1

  if [[ $instance = HTTPServer* ]]; then
    apachectl="/usr/${instance}/bin/apachectl"
  elif [[ $instance = WebSphere* ]]; then
    apachectl="/usr/${instance}/HTTPServer/bin/apachectl"
  fi

  echo $apachectl
}

function find_khtagent
{
  typeset alist sitetag config x

  for alist in $action_list_index; do
    sitetag=`echo ${inst_sites[alist-1]} | awk {'print $1'}`
    config=`sitetag_config $sitetag`

    grep -Ei '^[[:blank:]]*include[[:blank:]]*"?.*/conf/kht.*.conf' /projects/${sitetag}/conf/$config >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      x=`echo $site_selection | sed 's/ /+/g'`
      if [[ $x = *+* ]]; then
        echo "Found a configured ITM khtagent in at least one"
        echo "  actionable site"
      else
        echo "Found a configured ITM khtagent"
      fi
      return 1
    fi
  done
  x=`echo $site_selection | sed 's/ /+/g'`
  if [[ $x = *+* ]]; then
    echo "Did not find a configured ITM khtagent in any"
    echo "  actionable site.  Skipping ITM khtagent"
    echo "  processing"
  else
    echo "Did not find a configured ITM khtagent"
  fi
  return 0
}    
  
function khtagent_stop
{
  if [[ -z "$ignore_itm" ]]; then
    #---------------------------------------
    # stop ITM khtagent 
    #---------------------------------------
    /lfs/system/tools/configtools/countprocs.sh 1 khtagent > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      $itm_agent stop ht
      sleep 5
      /lfs/system/tools/configtools/countprocs.sh 1 khtagent > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        echo "Failed to stop ITM khtagent ... please resolve"
        return 2
      fi
      echo "ITM khtagent stopped successfully"
      return 0
    else
      echo "No ITM khtagent detected running ... skipping action to perform stop"
      echo "  on ITM khtagent "
      return 1
    fi
  else
    echo "The ignore itm parameter has been selected -- skipping stop"
    echo "  ITM khtagent function"
    return 0
  fi
}


function khtagent_start
{
  typeset -i rc=$1

  if [[ $rc = "" ]]; then
    rc=0
  fi

  if [[ -z "$ignore_itm" ]]; then
    #---------------------------------------
    # start ITM khtagent 
    #---------------------------------------
    if [[ $rc -eq 0 ]]; then 
      $itm_agent start ht 
      sleep 5
      /lfs/system/tools/configtools/countprocs.sh 1 khtagent > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo "Failed to start ITM khtagent ... please resolve"
        return 3
      fi
      echo "ITM khtagent started successfully"
      return 0
    else
      echo "ITM khtgent was not found running at the beginning of the start sequence -- skipping"
      echo "  action to perform start on ITM khtagent"
      return 1
    fi
  else
    echo "The ignore itm parameter has been selected -- skipping start"
    echo "  ITM khtagent function"
    return 2
  fi
}

function start_sitetag
{
  typeset notes vhosts https fqn config apachectl count outcome notes count procs items highlight sitetag=$1 instance=$2 alist=$3
  typeset -i rc

  [ `uname` == "AIX" ] && slibclean

  print "Starting IHS"

  config=`sitetag_config $sitetag`
  apachectl=`sitetag_apachectl $instance`
  notes=""

  if [[ $sitetag == "HTTPServer" ]]; then
    fqn="localhost"
  else
    fqn=`sed -n '2 p' /projects/${sitetag}/conf/listen.conf | awk '{print $2}' | awk -F: '{print $1}'`
  fi

  vhosts=`$apachectl -f /projects/${sitetag}/conf/$config -S 2>&1 | awk '{print $1"+"$2"+"$3}'`
  for vhost in $vhosts; do
    if echo $vhost | grep ":443" >/dev/null; then
      https=1
    fi
  done

  umask 0022
  $apachectl -f /projects/${sitetag}/conf/${config} -k start
  if [ $? -eq 0 ]; then
    #-------------------------------------------------------
    # wait for 3 httpd processes or timeout after 10 secs
    #-------------------------------------------------------
    count=0
    while [[ procs=$(ps awwx | grep -c "[/.]projects[/.]${sitetag}[/.]conf[/.]${config} -k start") -lt 3 && $count -lt 10 ]]; do
      print -n "Procs: $procs  \r"
      sleep 1
      count=`expr $count + 1`
    done

    echo "Procs: $procs  "

    if [ $count -eq 10 ]; then
      echo "Failed to start 3 httpd processes within 10 seconds"
      echo
      if [[ `echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'` = "" ]]; then
        summary_list[alist-1]="${sitetag}|Start Status Unknown|G|UNKNOWN"
      else
        if [[ $action = "graceful-restart" ]]; then
          summary_list[alist-1]="${sitetag}|Gracefully Restart Status Unknown|G|UNKNOWN"
        else
          summary_list[alist-1]="${sitetag}|Restart Status Unknown|G|UNKNOWN"
        fi
      fi 
      rc=1
    else
      echo
      global_http_request $fqn
      if [[ $? -gt 0 ]]; then
        notes="$notes W"
      fi

      if [[ $https -gt 0 ]]; then
        default_ssl_http_request $fqn
        if [[ $? -gt 0 ]]; then
          notes="$notes X"
        fi
      fi

      if [[ $notes != "" ]]; then
        if [[ `echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'` = "" ]]; then
          summary_list[alist-1]="${sitetag}|Start failed|$notes|ERROR"
        else
          if [[ $action = "graceful-restart" ]]; then
            summary_list[alist-1]="${sitetag}|Graceful Restart Failed|$notes|ERROR"
          else
            summary_list[alist-1]="${sitetag}|Restart Failed|$notes|ERROR"
          fi
        fi
        rc=1
      else        
        if [[ `echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'` = "" ]]; then 
          summary_list[alist-1]="${sitetag}|Started Successfully| |GOLDEN"
        else
          if [[ $action = "graceful-restart" ]]; then
            summary_list[alist-1]="${sitetag}|Gracefully Restarted Successfully| |GOLDEN"
          else
            summary_list[alist-1]="${sitetag}|Restarted Successfully| |GOLDEN"
          fi
        fi
        rc=0
      fi
    fi
  else
    echo "IHS failed to start"
    echo
    if [[ `echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'` = "" ]]; then
      summary_list[alist-1]="${sitetag}|Start Failed|H|ERROR"
    else
      if [[ $action = "graceful-restart" ]]; then
        summary_list[alist-1]="${sitetag}|Graceful Restart Failed|H S|ERROR"
      else
        summary_list[alist-1]="${sitetag}|Restart Failed|H S|ERROR"
      fi
    fi
    rc=1
  fi

  # Add any other info notes
  if [[ $ignore_ver -eq 1 || $ignore_IP -eq 1 ]]; then
    outcome=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[2]}'`
    notes=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[3]}'`
    highlight=`echo ${summary_list[alist-1]} | awk '{split($0,items,"|")} END{print items[4]}'`

    if [[ $ignore_ver -eq 1 ]]; then
        notes="${notes} O"
    fi

    if [[ $ignore_IP -eq 1 ]]; then
      notes="${notes} N"
    fi

    if [[ $highlight != "ERROR" ]]; then
      highlight="UNKNOWN"
    fi

    summary_list[alist-1]="${sitetag}|${outcome}|$notes|$highlight"
  fi

  return $rc
}

function stop_sitetag
{
  typeset config apachectl count outcome notes count procs items sitetag=$1 instance=$2 alist=$3
  typeset -i rc

  print "Stopping IHS"

  config=`sitetag_config $sitetag`
  apachectl=`sitetag_apachectl $instance`

  $apachectl -f /projects/${sitetag}/conf/${config} -k stop
  if [ $? -eq 0 ]; then
    #-------------------------------------------------------
    # wait for httpd processes to die or timeout after 30 secs
    #-------------------------------------------------------
    count=0
    while [[ procs=$(ps awwx| grep -c "[/.]projects[/.]${sitetag}[/.]conf[/.]${config} -k start") -gt 0 && $count -lt 30 ]]; do
      print -n "Procs: $procs  \r"
      sleep 1
      count=`expr $count + 1`
    done

    echo "Procs: $procs  "

    if [ $count -eq 30 ]; then
      echo "Failed to stop all httpd processes within 30 seconds"
      summary_list[alist-1]="${sitetag}|Stop Status Unknown|P|UNKNOWN" 
      rc=1
    else 
      summary_list[alist-1]="${sitetag}|Stopped Successfully| |GOLDEN"
      rc=0
    fi
  else
    echo "IHS failed to stop"
    summary_list[alist-1]="${sitetag}|Stop Failed|Q|ERROR"
    rc=1
  fi
  return $rc
}

function graceful_stop_sitetag
{
  typeset config apachectl count outcome notes count procs items sitetag=$1 instance=$2 alist=$3
  typeset -i rc

  print "Gracefully Stopping IHS"

  config=`sitetag_config $sitetag`
  apachectl=`sitetag_apachectl $instance`
  
  shutdown_timer=`cat /projects/${sitetag}/conf/$config | grep -i GracefulShutdownTimeout | awk '{print $2}'`
  if [[ $shutdown_timer != "" ]]; then
    shutdown_timer=`expr $shutdown_timer + 10`
  else
    shutdown_timer=30
  fi
 
  $apachectl -f /projects/${sitetag}/conf/${config} -k graceful-stop
  if [ $? -eq 0 ]; then
    #-------------------------------------------------------
    # wait for httpd processes to die or timeout after \$shutdown_timer secs
    #-------------------------------------------------------
    count=0
    while [[ procs=$(ps -eoargs= | grep -c "[/.]projects[/.]${sitetag}[/.]conf[/.]${config} -k start") -gt 0 && $count -lt $shutdown_timer ]]; do
      print -n "Procs: $procs  \r"
      sleep 1
      count=`expr $count + 1`
    done

    echo "Procs: $procs  "

    if [ $count -eq $shutdown_timer ]; then
      echo "Failed to gracefully stop all httpd processes within $shutdown_timer seconds"
      summary_list[alist-1]="${sitetag}|Graceful Stop Status Unknown|T|UNKNOWN" 
      rc=1
    else 
      summary_list[alist-1]="${sitetag}|Gracefully Stopped Successfully| |GOLDEN"
      rc=0
    fi
  else
    echo "IHS failed to gracefully stop"
    summary_list[alist-1]="${sitetag}|Graceful Stop Failed|U|ERROR"
    rc=1
  fi
  return $rc
}

function validate_httpd 
{
  typeset apachectl_cmd config sitetag=$1 instance=$2 details=$3
  typeset -i rc=0 configtest_rc=0

  config=$(sitetag_config $sitetag)
  apachectl_cmd=$(sitetag_apachectl $instance)

  echo ""
  ${lib_home}/ihs/bin/highlight.pl "Performing IHS Config File Syntax Validation -->" SUBHEADER; echo
  if [[ $details = "true" ]]; then
    echo ""
    print "  \c"
    $apachectl_cmd -f /projects/${sitetag}/conf/${config} -t
    configtest_rc=$?
    echo
  else
    $apachectl_cmd -f /projects/${sitetag}/conf/${config} -t > /dev/null 2>&1
    configtest_rc=$?
  fi

  if [[ $configtest_rc -gt 0 ]]; then
    echo "  //////////////////////////////"
    print "  ////\c"
    ${lib_home}/ihs/bin/highlight.pl "  Validation Failed   " ERROR
    print "////"
    rc=1
  else
    echo "  //////////////////////////////"
    print "  ////\c"
    ${lib_home}/ihs/bin/highlight.pl " Validation Completed " GOLDEN
    print "////"
  fi
  echo "  //////////////////////////////"

  echo ""
  if [[ "$ignore_ver" != "1" ]]; then
    if [[ -x $validate_httpd ]]; then
      $validate_httpd sitetag=$sitetag details=$details
      rc=`expr $rc + $?`
    fi
  else
    ${lib_home}/ihs/bin/highlight.pl "Performing IHS Advanced Config File Verification -->" SUBHEADER; echo
    echo ""
    echo "The ignore conf parameter has been selected -- skipping advanced verification of IHS configs"
    echo ""
  fi
  return $rc
}

function validate_plugin 
{
  typeset sitetag=$1 details=$2 config plugin plugin_real plugin_syntax_check
  typeset -i rc=0 plugin_syntax_rc=0

  config=$(sitetag_config $sitetag)

  grep -Ei '^[[:blank:]]*WebSpherePluginConfig' /projects/${sitetag}/conf/${config} >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    plugin=`grep -iE '^[[:blank:]]*webspherepluginconfig' /projects/${sitetag}/conf/${config} | awk '{print $2}'`
    if [[ ! -z "$plugin" ]]; then 
      ${lib_home}/ihs/bin/highlight.pl "Performing Websphere Plugin XML Syntax Validation -->" SUBHEADER; echo
      plugin_real=`ls -l $plugin | awk '{print $NF}'`
      cd /projects/${sitetag}/conf
      perl -MXML::Parser -e "XML::Parser->new( ErrorContext => 3 )->parsefile(shift)" $plugin_real > /dev/null 2>&1
      plugin_syntax_rc=$?
      if [[ $details = "true" ]]; then
        if [ -f $plugin_real ]; then
          plugin_syntax_check=`perl -MXML::Parser -e "XML::Parser->new( ErrorContext => 3 )->parsefile(shift)" $plugin 2>&1`
          if [[ $plugin_syntax_check = "" ]]; then
            echo ""
            echo "  Syntax Ok"
            echo ""
          else
            print "  \c"
            echo "$plugin_syntax_check"
            echo ""
          fi
        else
          echo ""
          echo "  Plugin file $plugin_real"
          echo "    pointed to from symlink $plugin"
          echo "    does not exist"
          echo ""
        fi
      fi
      if [[ $plugin_syntax_rc -gt 0 ]]; then
        echo "  //////////////////////////////"
        print "  ////\c"
        ${lib_home}/ihs/bin/highlight.pl " Validation Failed    " ERROR
        print "////"
        rc=`expr $rc + 4`
      else
        echo "  //////////////////////////////"
        print "  ////\c"
        ${lib_home}/ihs/bin/highlight.pl " Validation Completed " GOLDEN
        print "////"
      fi
      echo "  //////////////////////////////"
    fi
    echo ""
    if [ "$ignore_ver" != "1" ]; then
      if [[ -x $validate_plugin ]]; then
        $validate_plugin sitetag=$sitetag details=$details
        rc=`expr $rc + $?`
      fi
    else
      ${lib_home}/ihs/bin/highlight.pl "Performing WebSphere Plugin Advanced XML Verification -->" SUBHEADER; echo
      echo ""
      echo "The ignore conf parameter has been selected -- skipping advanced verification of"
      echo "  Websphere Plugin config"
      echo ""
    fi
  fi
  return $rc
}

function check_httpd_log 
{
  typeset -i rc=0

  if [[ -x $http_log_check ]]; then
    $http_log_check
    rc=`expr $rc + $?`
  fi
  return $rc
}

function check_plugin_log 
{
  typeset -i rc=0

  if [[ -x $plugin_log_check ]]; then
    $plugin_log_check
    rc=`expr $rc + $?`
  fi
  return $rc
}

function print_summary 
{
  typeset sitetag outcome notes items notes_list highlight
  typeset -i index_num x

  echo ""
  print "                                   \c"
  ${lib_home}/ihs/bin/highlight.pl "\"Command Summary\"" UNDERLINE; echo
  echo ""
  ${lib_home}/ihs/bin/highlight.pl "          Site Tag                           Outcome                     Notes" BOLD; echo
  ${lib_home}/ihs/bin/highlight.pl "  -------------------------  ----------------------------------------  ---------" BOLD; echo

  for index_num in ${site_selection}; do
    sitetag=`echo ${summary_list[index_num-1]} | awk '{split($0,items,"|")} END{print items[1]}'`
    outcome=`echo ${summary_list[index_num-1]} | awk '{split($0,items,"|")} END{print items[2]}'`
    notes=`echo ${summary_list[index_num-1]} | awk '{split($0,items,"|")} END{print items[3]}'`
    highlight=`echo ${summary_list[index_num-1]} | awk '{split($0,items,"|")} END{print items[4]}'`
    if [[ $notes != "" && $notes != " " ]]; then
      notes_list="${notes_list} ${notes}"
      notes_tmp=$notes
      notes_tmp=`echo ${notes_tmp}| sed 's/ /\\\n/g'`
      notes_tmp=`print ${notes_tmp}|sort`
      notes=`echo ${notes_tmp}`
    fi

    let x=25-${#sitetag}
    while [[ $x -gt 0 ]]; do
      sitetag="${sitetag} "
      let x=$x-1
    done

    let x=40-${#outcome}
    while [[ $x -gt 0 ]]; do
      outcome="${outcome} "
      let x=$x-1
    done

    let x=9-${#notes}
    while [[ $x -gt 0 ]]; do
      notes="${notes} "
      let x=$x-1
    done

    print "  \c"
    ${lib_home}/ihs/bin/highlight.pl "${sitetag}  ${outcome}  $notes" ${highlight}; echo
  done

  echo ""
  print "  Color Key: \c"
  ${lib_home}/ihs/bin/highlight.pl " Successful - No Issues " GOLDEN
  print " \c"
  ${lib_home}/ihs/bin/highlight.pl " Unknown - Needs Review " UNKNOWN
  print " \c"
  ${lib_home}/ihs/bin/highlight.pl " Error - Needs Correction " ERROR; echo

  if [[ $notes_list != "" ]]; then
    notes_list=`echo ${notes_list}| sed 's/ /\\\n/g'`
    notes_list=`print ${notes_list}|sort|uniq`
    key_values=`echo ${notes_list}`

    echo ""
    echo "  Code Key:"

    for klist in ${key_values}; do
      case $klist in
        A) echo "    A - Failed IHS Config File Syntax Validation";;
        B) echo "    B - Failed IHS Advanced Config File Verification";;
        C) echo "    C - Failed WebSphere Plugin XML Syntax Validation";;
        D) echo "    D - Failed WebSphere Plugin Advanced XML Verification";;
        E) echo "    E - ITM khtagent failed to stop - IHS Start was aborted";;
        F) echo "    F - rc.IP_Aliases returned a non zero code - IHS Start was aborted";;
        G) echo "    G - IHS failed to start 3 httpd processes within 10 seconds";;
        H) echo "    H - IHS Start command failed returning a non zero code";;
        I) echo "    I - Errors detected in IHS log";;
        J) echo "    J - Errors detected in Wepsphere Plugin log";;
        K) echo "    K - ITM khtagent was not found running at the beginning of the $action sequence -- skipped"
           echo "          action to perform start on ITM khtagent";;
        L) echo "    L - The ignore itm parameter was selected -- skipped ITM khtagent handling";;
        M) echo "    M - ITM khtagent failed to start";;
        N) echo "    N - The ignore aliases parameter was selected -- skipped action to run rc.IP_aliases";;
        O) echo "    O - The ignore conf parameter was selected -- skipped action to run advanced"
           echo "          verification of IHS / Websphere Plugin config files";;
        P) echo "    P - IHS failed to stop all httpd processes within 30 seconds";;
        Q) echo "    Q - IHS Stop command failed returning a non zero code";;
        R) echo "    R - IHS was not running when restart command was issued";;
        S) echo "    S - IHS is not running";;
        T) echo "    T - IHS failed to gracefully stop all httpd processes within $shutdown_timer seconds";;
        U) echo "    U - IHS Graceful Stop failed returning a non zero code";;
        V) echo "    V - Server Status module not installed or URI server-status unreachable";;
        W) echo "    W - Global Server did not respond correctly to site.txt";;
        X) echo "    X - Default SSL VirtualHost did not respond correctly to site.txt";;
        Y) echo "    Y - Site has no detected active root process";;
        Z) echo "    Z - IHS was not running when graceful restart command was issued";;
       AA) echo "   AA - Restart Aborted";;
       AB) echo "   AB - Graceful Restart Aborted";;
      esac
    done
  fi
  echo ""
}

