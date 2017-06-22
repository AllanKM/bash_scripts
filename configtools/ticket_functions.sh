get_ticket_time_values() {
   #================================================
   # Get date/time
   #================================================
   SEC=$(date +"%S")
   MIN=$(date +"%M")
   HOUR=$(date +"%I")
   AMPM=$(date +"%p")
   DAY=$(date +"%d")
   MONTH=$(date +"%m")
   YEAR=$(date +"%Y")
   
   #================================================
   # Get COMPLETE BY time/date details
   #================================================
   if [ -n "$COMPLETE_BY" ]; then
      date -d "$COMPLETE_BY" >/dev/null 2>&1
      if [ $? -eq 0 ]; then
         
         CB_SEC=$(date -d "$COMPLETE_BY" +"%S")
         CB_MIN=$(date -d "$COMPLETE_BY" +"%M")
         CB_HOUR=$(date -d "$COMPLETE_BY" +"%I")
         CB_AMPM=$(date -d "$COMPLETE_BY" +"%p")
         CB_DAY=$(date -d "$COMPLETE_BY" +"%d")
         CB_MONTH=$(date -d "$COMPLETE_BY" +"%m")
         CB_YEAR=$(date -d "$COMPLETE_BY" +"%Y")
      else
         print "Invalid complete by date\n use date format yyyy/mm/dd hh:mm"
         exit
      fi
   else
      CB='N'
      CB_SEC=$SEC
      CB_MIN=$MIN
      CB_HOUR=$HOUR
      CB_AMPM=$AMPM
      CB_DAY=$DAY
      CB_MONTH=$MONTH
      CB_YEAR=$YEAR
   fi

}

get_login_details() {
   XML=${TICKET_CONFIG-~/.impact_test.xml}

   cookie_jar=/tmp/$(whoami)_$$_cookies
   [ -n "$debug" ] && print -u2 "${YELLOW}Cookie jar${RESET}: $cookie_jar"

   #================================================
   # Get login info from xml
   #================================================
   if [ -f $XML ]; then
      while read xml; do
         if [[ "$xml" = *"<USERID>"* && -z "$USERID" ]]; then
            USERID=${xml#*\>}
            USERID=${USERID%\<*}
         elif [[ "$xml" = *"<PASSWORD>"* && -z "$PASSWORD" ]]; then
               PASSWORD=${xml#*\>}
               PASSWORD=${PASSWORD%\<*}
         elif [[ "$xml" = *"<FIRSTNAME>"* && -z "$FIRSTNAME" ]]; then
               FIRSTNAME=${xml#*\>}
               FIRSTNAME=${FIRSTNAME%\<*}
         elif [[ "$xml" = *"<LASTNAME>"* && -z "$LASTNAME" ]]; then
               LASTNAME=${xml#*\>}
               LASTNAME=${LASTNAME%\<*}
         elif [[ "$xml" = *"<URL>"*  && -z "$URL" ]]; then
               URL=${xml#*\>}
               URL=${URL%\<*}
         fi           
      done <$XML
   fi
   
   #================================================
   # Check for missing URL information
   #================================================
   if [ -z "$URL" ]; then
      print -u2 -- "Missing <URL> from config XML"
      select env in Test Production; do
         print $env 
         case $env in
            Test) URL=https://impactdev.rny.ihost.com/IM/scripts
            print '<URL>'$URL'</URL>' >>$XML
            break
            ;;
            Production) URL=https://impact-enterprise.rny.ihost.com/IM/scripts
            print '<URL>'$URL'</URL>' >>$XML
            break
            ;;
         esac
       done
       [ -z "$URL" ] && exit
   fi
   #================================================
   # Check for missing USERID information
   #================================================
   if [ -z "$USERID" ]; then
      # prompt for it
      print -u2 -- "Missing <USERID>...</USERID> in $XML"
      USERID=$(prompt "Enter Impact userid: ")
      if [ -n "$USERID" ]; then
         print '<USERID>'$USERID'</USERID>' >> $XML
      else
         print -u2 -- "Unable to continue without a userid"
         exit 2
      fi
   fi
   #================================================
   # Check for missing PASSWORD information
   #================================================
   if [ -z "$PASSWORD" ]; then
      # prompt for it
      print -u2 -- "Missing <PASSWORD>...</PASSWORD> in $XML"
      PASSWORD=$(prompt pw "Enter password for $USERID: ")
      if [ -n "$PASSWORD" ]; then
         print '<PASSWORD>'$PASSWORD'</PASSWORD>' >> $XML
      else
         exit 2
      fi
   fi
   #================================================
   # Check for missing FIRSTNAME information
   #================================================
   if [ -z "$FIRSTNAME" ]; then
      print -u2 -- "Missing <FIRSTNAME>...</FIRSTNAME> in $XML"
      FIRSTNAME=$(prompt "First name of contactid: ")
      if [ -n "$FIRSTNAME" ]; then
         print '<FIRSTNAME>'$FIRSTNAME'</FIRSTNAME>' >> $XML
      else
         exit 2
      fi
   fi
   #================================================
   # Check for missing LASTNAME information
   #================================================
   if [ -z "$LASTNAME" ]; then
      print -u2 -- "Missing <LASTNAME>...</LASTNAME> in $XML"
      LASTNAME=$(prompt "Last name of contactid: ")
      if [ -n "$LASTNAME" ]; then
         print '<LASTNAME>'$LASTNAME'</LASTNAME>' >> $XML
      else
         exit 2
      fi
   fi
   
   #================================================
   # Encode values to escape special chars etc
   #================================================  
   USERID_ENC=$(urlencode "$USERID")
   FIRSTNAME=$(urlencode "$FIRSTNAME")
   LASTNAME=$(urlencode "$LASTNAME")
}


#================================================
# Perform Impact login
#================================================
login_impact() {
   LOGIN_POST="GoToURL=&LoginAttempts=1&Password=$PASSWORD&UserID=$USERID_ENC&submit_request="

   #================================================
   # Goto login page to get the cookies set
   #================================================
   if [ -n "$debug" ]; then
      print -u2 -- "${CYAN}Get login page${RESET}"
   else
      print -n -u2 -- "Gathering info ."
   fi
   
   curl $k -s -b $cookie_jar -c $cookie_jar "$URL/LoginPage.asp?ErrorState=&LoginAttempts=" >/dev/null 
   
   #================================================
   # POST login details
   #================================================
   curl $k -s -L -b $cookie_jar -c $cookie_jar -d "$LOGIN_POST" "$URL/Login.asp" |&
   exec 4>&p
   exec 5<&p
   
   [ -n "$debug" ] && print -u2 -- "Logging into Impact"
   while read -u5 line; do
         [ "$debug" -gt 1 ] && print -u2 -- "$line"
         if [[ "$line" = *"ResourceViewRequests.asp"* ]]; then
            loginok=1
   
         elif [[ "$line" = *"Your login id and password do not match our records"* ]]; then
            print -u2 -- "Userid/password incorrect"
            exit 2
         fi
   done
   exec 4>&-
   
   #======================================================
   # die if login failed
   #======================================================
   loginok=1
   if [ -z "$loginok" ]; then
      print -u2 -- "Impact login failed"
      exit 2
   fi
   unset loginok
   
   [ -n "$debug" ] && print -u2 -- "Login successful"
   print ""
   
}
#------------------------------------------------------------------------------------------
# Show command syntax
#------------------------------------------------------------------------------------------
syntax_close() {
   print -u2 -- "close_ticket.sh <ticket>\n ticket must start RESHC RESHI or RESHR"
   exit
}
#------------------------------------------------------------------------------------------
# Show command syntax
#------------------------------------------------------------------------------------------
syntax() {
   print -- " Function: Create impact Incident and Service Request tickets from the command line\n\n"
   print -- " Syntax:" 
   print -- '   ticket.sh <type> <customer> <team>[:name] <category> <subcategory> "<subject>" ("<details>")'
   print -- "\t\tor"
   print -- '  SR=<request#> ticket.sh <type> <customer> <team>[:name] <category> <subcategory> "<subject>" ("<details>")\n'
   print " where:"
   print "\t${CYAN}type${RESET} = I for incident, SR for Service Request"
   print "\t\tfollowed by an optional severity code 1-4 eg sr:1 or i:3"
   print "\t\tif not specified the default severity of 3 is used"
   print "\t${CYAN}customer${RESET} = Name of the affected customer"
   print "\t${CYAN}team${RESET} = Queue on which to create the ticket"
   print "\t\t${CYAN}apps${RESET} = Application Team"
   print "\t\t${CYAN}io${RESET} = Infrastructure Ops"
   print "\t\t${CYAN}est${RESET} = Extended support team"
   
   print "\t\tteam can be followed by :name_of_person_in_team to assign to an individual" 
   print "\t\t\teg:${GREEN} apps:farrell${RESET}" 
   print "\t${CYAN}Category${RESET} = Appropriate category for the Queue/error"
   print "\t${CYAN}Subcategory${RESET} = Appropriate subcategory for the Queue/error"
   print "\t${CYAN}Subject${RESET} = One line description for the ticket"
   print "\t${CYAN}Details${RESET} = full description. If not specified <subject> will be used."
   print "\t\tDetails may be supplied in 3 ways"
   print "\t\t\t1) piped from stdin eg ${GREEN}"
   print "\t\t\t   cat text.file | ticket.sh sr wwsm apps:farrell middleware ear \"subject line\""
   print "\t\t\t   ticket.sh sr wwsm apps:farrell middleware ear \"subject line\" < text.file"
   print "\t\t\t${RESET}2) filename  eg ${GREEN}"
   print "\t\t\t   ticket.sh sr wwsm apps:farrell middleware ear \"subject line\" text.file"
   print "\t\t\t${RESET}3) as a parameter  eg ${GREEN}"
   print "\t\t\t   ticket.sh sr wwsm apps:farrell middleware ear \"subject line\" \"detailed description\"${RESET}"
       
   print "\t\t*Note* subject and details need to be enclosed in quotes"
   print -- "  If the SR environment variable is set to a service request number, as shown in the 2nd syntax line,"
   print -- "  and the request is to create an incident then the resulting ticket will be linked to the SR"
   
   print -- "\nSeveral key values are required to complete the login to impact, these may either be stored in"
   print -- "an xml config file or passed as environment variables. The name of the XML config file defaults to "
   print -- "\t~/.impact.xml"
   print -- "but may be changed by setting the TICKET_CONFIG var, e.g ${BLUE}TICKET_CONFIG=another.xml ./ticket.sh sr .....${RESET}"
   print -- "the format of the xml is as follows "
   print -- "
        <USERID>${YELLOW}your impact userid${RESET}</USERID>
        <PASSWORD>${YELLOW}your impact password${RESET}</PASSWORD>
        <FIRSTNAME>${YELLOW}the firstname of the person to be made the contact for the ticket${RESET}</FIRSTNAME>
        <LASTNAME>${YELLOW}the surname of the person to be made the contact for the ticket${RESET}</LASTNAME>
        <URL>https://impactdev.rny.ihost.com/IM/scripts</URL>
     "
   print -- " Alternatively the same values can be set using environment variables, if both an XML and an environment var"
   print -- "is used the environment var will supercede the value in the XML"
   print -- "e.g ${BLUE}USERID=myimpactid PASSWORD=mypassword ./ticket.sh sr .... ${RESET}"
   print -- "will login with "myimpactid" using "mypassword" instead of the values in the XML file"
   print -- "This is of particular use for changing the Contactid for any tickets created, if you want so assign different"  
   print -- "contactid use the FIRSTNAME/LASTNAME env vars to define the name of the person to be used e.g"
   print -- "${BLUE}FIRSTNAME=\"john\" LASTNAME=\"doe\" ./ticket.sh sr ...${RESET} will lookup the contactid with name \"john doe\""
   print -- "and make them the contact id of the ticket."

   exit
}

#============================================================================
# Get lines between start and end strings
#============================================================================
capture_grid() {
   exec 4>&p
   exec 5<&p
   
   gridvar=$1
   [ -n "$debug" ] && print -u2 -- "griddata will be saved to $gridvar"
   while read -u5 line; do
      [ "$debug" -gt 1 ] && print -u2 -- "$line"
      if [[ "$line" = *([:blank:])"var "* ]]; then
         unset gData
      fi
      
      if [ -n "$gData" ]; then
         GridData="${GridData}$line"
      fi
      
      if [[ "$line" = *([:blank:])"var GridData ="* ]]; then
         [ -n "$debug" ] && print -u2 -- "Found griddata line"
         GridData=$line
         gData=1
      fi
   done
   exec 4>&-
   
   GridData=${GridData#*var GridData = \[}
   GridData=${GridData%\]*}
   if [ "$gridvar" = "TASKS" ]; then
      [ -n "$debug" ] && print -u2 -- "${CYAN}$GridData$RESET" 
   fi
   OLDIFS=$IFS
   IFS=\]
   [ -n "$debug" ] && print -u2 -- "Save data to array $gridvar"
   set -A $gridvar $GridData
   IFS=$OLDIFS
}

#============================================================================
# Split Griddata
#============================================================================
grid_values() {
   [ "$debug" -gt 1 ] && print -u2 -- "split grid line into values"
   entry="$1"
   [ "$debug" -gt 2 ] && print -u2 -- "$entry"
   typeset var i
   i=0
   while [[ "$entry" = *\",\"* ]]; do
      value=${entry%%\",\"*}
      value=${value#*\<font}
      value=${value#*\>}
      value=${value%%\<*}
      values[$i]="$value"
      [ "$debug" -gt 1 ] && print -u2 -- "\t$i =\"${values[$i]}\""
      i=$((i+1))
      entry=${entry#*\",\"}
   done
   value=$entry
   value=${value#*\<font}
   value=${value#*\>}
   value=${value%%\<*}  
   values[$i]=$value
   [ "$debug" -gt 1 ] && print -u2 -- "Exit griddata"
}
#============================================================================
# Split Task Griddata
#============================================================================
task_values() {
   if [ -n "$1" ]; then 
      [ "$debug" -gt 1 ] && print -u2 -- "split task grid line into values"
      entry="$1"
      [ "$debug" -gt 2 ] && print -u2 -- "${RED}$entry${RESET}"
      typeset var i
      
      value=${entry%%\<\/a\>\<\/B\>*}
    print -u2 -- $value
	value=${value##*\>}
	print -u2 -- $value
        values[0]=$value
    print -u2 -- ${values[0]}
    entry=${entry#*\<\/B\>}
     i=1
      while [[ "$entry" = *\<B\>* ]]; do
    	print -u2 -- ${values[0]}
         value=${entry%%\<\/B\>*}
         value=${value%%\<\/FONT\>*}   
         value=${value##*\>}
         value=${value#*\&nbsp;}
         values[$i]="$value"
         [ "$debug" -gt 1 ] && print -u2 -- "\t${YELLOW}$i =\"${values[$i]}\"$RESET"
         i=$((i+1))
         entry=${entry#*\<\/B\>}
      done
      value=$entry
      value=${value##*\>}
      value=${value#*\&nbsp;}
      values[$i]="$value"
      [ "$debug" -gt 1 ] && print -u2 -- "Exit task griddate"
   fi
}

#------------------------------------------------------------------------------------------
# encode parms for url
#------------------------------------------------------------------------------------------
urlencode() {
   arg="$1"
   print -- "$arg" | awk '{
      
      gsub(/%/,"%25")
      
      gsub(/ /,"%20")
      gsub(/\"/,"%22")
      gsub(/#/,"%23")
      gsub(/&/,"%26")
      gsub(/\(/,"%28")
      gsub(/\)/,"%29")
      gsub(/\+/,"%2B")
      gsub(/\,/,"%2C")
      gsub(/-/,"%2D")
      gsub(/\//,"%2F")
      gsub(/:/,"%3A")
      gsub(/;/,"%3B")
      gsub(/</,"%3C")
      gsub(/\=/,"%3D")
      gsub(/>/,"%3E")
      gsub(/\?/,"%3F")
      gsub(/@/,"%40")
      gsub(/\\/,"%5C")
      gsub(/\|/,"%7C")
      
      x=x$0"%0A"
    }
    END { sub(/%0A$/,"",x)
      print x
    }'    
}

function prompt {
   trap 'stty echo; echo "CTRL-C" >&2; exit' INT

   if [[ "$1" = "pw" ]]; then
      prompt=$2
      pw=1
   else
      prompt=$1
   fi
   
   print -u2 -n -- "$prompt" 
   while [ -z "$answer" ]; do
      [ -n "$pw" ] && stty -echo
      read answer
      [ -n "$pw" ] && stty echo
      if [ -z "$answer" ]; then
         print -u2 -n -- "Invalid response\n$1"
      fi
   done
   print $answer
}

#=====================================================
# curl requires -k parm if not using version 7.9
#===================================================== 
k="-k"
if curl -V | grep "7.9" >/dev/null ; then
   unset k
fi

#---------------------------------------------------------
# color codes
#---------------------------------------------------------
BLACK="\033[30;1;49m"
RED="\033[31;1;49m"
GREEN="\033[32;1;49m"
YELLOW="\033[33;3;49m"
BLUE="\033[34;49;1m"
MAGENTA="\033[35;49;1m"
CYAN="\033[36;49;1m"
WHITE="\033[37;49;1m"
RESET="\033[0m"