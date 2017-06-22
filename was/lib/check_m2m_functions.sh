#!/bin/ksh

#
#    *role*|role2*)
#        ARGS="app app app app";
#    
#     app|app1)
#      $checkURL .....
#-----------------------------------------------------------------------------
# Get user input 
#-----------------------------------------------------------------------------
function wait_input {
   max=$1
   unset answer
      while [ -z "$answer" ] ; do
         read answer
         if [ "$answer" -lt 1 ] || [ "$answer" -gt $max ]; then
            print --u2 -- "$answer is an invalid response"
            unset answer
         fi
      done
      answer=$((answer-1))
      print $answer
}
#-----------------------------------------------------------------------------
# parse check_was.sh for requested app
#-----------------------------------------------------------------------------
function get_url {
   find_add=$1
   typeset -u find_role
   find_role=$2
   typeset -u role
   set -A applist
   set -A caseapplist
   set -A approlelist
   
   #-----------------------------------------------------------------------------
   # Get list of WAS roles
   #-----------------------------------------------------------------------------   
   roles=$( dsls -q role was.*)
    
   #-----------------------------------------------------------------------------
   # parse check_was.sh for requested app
   #-----------------------------------------------------------------------------   
   while read line; do
   
      if [[ "$line" = *([:alnum:]|.|-|\|)*")" ]] then
         #-------------------------
         # found a case statement
         #-------------------------
			caseline=${line%\)*}
		fi
		
	   if [[ $line =  *"ARGS="*"$1"* ]]; then
	      #----------------------
	      # Case mapping roles to appnames
	      #----------------------
         
         unset caseapplist
         apps=${line#*ARGS=\"}
         apps=${apps%\"*}
         
         #-----------------------------
         # expand name of matching app
         #-----------------------------
         for app in $apps; do
            if [[ "$app" = *"$1"* ]]; then
               #print -u2 -- "$app matches $1"
               if [[ "${applist[*]}" != *" $app "* ]]; then
                  applist[${#applist[*]}]=" $app "
               fi
               if [[ "${caseapplist[*]}" != *" $app "* ]]; then
                  caseapplist[${#caseapplist[*]}]=" $app "
               fi
            fi
         done 
         
         #--------------------------------------------
         # expand caseline roles into full role name
         #--------------------------------------------
         caseline=`print $caseline | sed -e 's/|/ /g'`
         for role in $caseline; do
            for defrole in $roles; do
               if [[ "$defrole" != "WAS.DM."* ]] && [[ "$defrole" = $role ]]; then
                  approlelist[${#approlelist[*]}]="${caseapplist[*]}:$defrole" 
               fi
            done
         done
      elif [[ $line =  *"\$checkURL"* ]]; then
         for app in `print $caseline | sed -e 's/|/ /g'`; do     
            hc[${#hc[*]}]=" $app :$line"
         done   
		
		fi
	
	done < /lfs/system/bin/check_was.sh

   #------------------------------------
   # if multiple matching app names list them
   #------------------------------------
	if [[ ${#applist[*]} -gt 1 ]]; then 
	  i=1
	  print -u2 -- "Multiple apps match, select number of app to use"
	  for app in ${applist[*]}; do
	     print -u2 -- "\t$i\t$app"
	     i=$((i+1))
	  done
	  selected=$(wait_input ${#applist[*]} )
	else
	  #---------------------------------------
	  # only 1 app matched so use it
	  #---------------------------------------
	  selected=0
	fi
	
	app=${applist[$selected]}
	app=${app## }
	app=${app%% }
	
   #------------------------------------------
   # Get array of roles using selected app
   #------------------------------------------
	set -A rolelist
	i=0
	while [ $i -lt ${#approlelist[*]} ]; do
	  if [[ ${approlelist[$i]} = *"$app"* ]]; then
	     
	     #---------------------------------------------------------------------------------
	     # if we were passed a role to use and we find the app defined to it, then use it
	     #---------------------------------------------------------------------------------
	     if [[ -n "$find_role" ]] && [[ ${approlelist[$i]} = *"$find_role"* ]]; then
	        unset rolelist
	        rolelist[0]=${approlelist[$i]}
	        break;
	     else
	        #----------------------------------------------
	        # make a list of all roles using the app
	        #---------------------------------------------- 
	        rolelist[${#rolelist[*]}]=${approlelist[$i]}
	     fi
	  fi
	  i=$((i+1))
	done
	
	#------------------------------------------
   # If more than one role uses app list them
   #------------------------------------------
	if [[ ${#rolelist[*]} -gt 1 ]]; then
	  i=1
	  r=0
     print -u2 -- "Multiple Roles defined with app $app, select number of role to use"
     while [ $r -lt ${#rolelist[*]} ]; do
         role=${rolelist[$r]}
         role=${role#*:}
        print -u2 -- "\t$i\t$role"
        i=$((i+1))
        r=$((r+1))
     done
      selected=$(wait_input ${#rolelist[*]} )
   else
      #-------------------------------------
      # only one role uses the app 
      #-------------------------------------
      selected=0
   fi
   
   #---------------------------------------
   # Now have appname, and role
   #---------------------------------------
   role=${rolelist[$selected]}
   role=${role#*:}
   
   #---------------------------------------
   # Get the URL for the appname, and role
   #---------------------------------------
   i=0
   while [ $i -lt ${#hc[*]} ]; do
   
      if [[ ${hc[$i]} = *" $app "* ]]; then
         # url is 3rd word
         url=${hc[$i]#*:}
         url=${url#* }        # $checkURL
         url=${url#* }        # $APP
         url=${url%% *}       # Pattern
      fi
      i=$((i+1))
   done
   
   print "$role@$url"
}


