#!/bin/ksh

#=====================================================
# Find what dir I am installed in as my function
# script will be in the same one
#===================================================== 
SELF_PATH=$(cd -P -- "$(dirname -- "$0")" && pwd -P) && SELF_PATH=$SELF_PATH/$(basename -- "$0")

# resolve symlinks
while [ -h $SELF_PATH ]; do
    DIR=$(dirname -- "$SELF_PATH")
    SYM=$(readlink $SELF_PATH)
    SELF_PATH=$(cd $DIR && cd $(dirname -- "$SYM") && pwd)/$(basename -- "$SYM")
done

SELF_PATH=${SELF_PATH%\/*}

#=====================================================
# load support functions from the same dir
#=====================================================
. $SELF_PATH/ticket_functions.sh

#=====================================================
# curl requires -k parm if not using version 7.9
#===================================================== 
k="-k"
if curl -V | grep "7.9" >/dev/null ; then
   unset k
fi

#=====================================================
# 
#=====================================================
OLDIFS=$IFS
XML=${TICKET_CONFIG-~/.impact_test.xml}

cookie_jar=/tmp/$(whoami)_$$_cookies
[ -n "$debug" ] && print -u2 "${YELLOW}Cookie jar${RESET}: $cookie_jar"

#======================================================
# Start of main code, parse command line parms
#======================================================
if [[ $# -gt 7 ]]; then
   print -u2 -- "\n${RED}Wow! loadsa parms .... Remember to surround <subject> and <details> with quotes${RESET}\n" 
   syntax
   exit
fi

if [[ $# -lt 6 ]]; then
   print -u2 -- "\n${RED}Must supply at least 6 parameters${RESET}\n"
   syntax
   exit
fi

#======================================================
# Handle the ticket type parm
#======================================================
SEVERITY=4
PRIORITY=3

typeset -u TYPE
TYPE=$1
if [[ "$TYPE" = *":"* ]]; then
   SEVERITY=${TYPE#*\:}
   TYPE=${TYPE%:*}
fi

if [[ "$SEVERITY" != [1-4] ]]; then
   print -u2 -- "Severity must be 1,2,3 or 4"
   exit
fi

if [[ "$TYPE" != "I" && "$TYPE" != "SR" ]]; then
   print -u2 -- "\n\tInvalid ticket type $TYPE\n\n"
   syntax
fi

if [[ -n "$SR" && $TYPE != "I" ]]; then
   print -u2 -- "SR=$SR ignored, can only link Incidents to SR's"
   unset SR
fi

if [ "$TYPE" = "SR" ]; then
   TYPE="Service Request"
else
   TYPE="Incident"
fi

#==================================================
# Handle the customer parm, validity will be 
# tested later after retrieving valid values
# from Impact
#==================================================
typeset -u CUSTOMER
CUSTOMER=$2

#==================================================
# Handle the team parm *activity level*
#==================================================
typeset -u OWNER
typeset -u ACTIVITY
typeset -u TEAM

TEAM=$3

OWNER="QUEUE"                       # default to putting ticket on the team queue
if [[ "$TEAM" = *":"* ]]; then
   OWNER=${TEAM#*:}
   TEAM=${TEAM%:*}
fi

if [[ "$TEAM" = "APPS" ]]; then 
   ACTIVITY="Application"
elif [[ "$TEAM" = "IO" ]]; then 
   ACTIVITY="Infrastructure"
elif [[ "$TEAM" = "EST" ]]; then 
   ACTIVITY="Monitoring"
elif [[ "$TEAM" = "WM" ]]; then 
   ACTIVITY="Webmaster"
elif [[ "$TEAM" = "NET" ]]; then 
   ACTIVITY="Networking"
elif [[ "$TEAM" = "PE" ]]; then 
   ACTIVITY="Project"
elif [[ "$TEAM" = "MON" ]]; then 
   ACTIVITY="Monitoring"
elif [[ "$TEAM" = "SD" ]]; then 
   ACTIVITY="Service Desk"
elif [[ "$TEAM" = "IMPACT" ]]; then 
   ACTIVITY="IMPACT"
else
   print -u2 -- "Unrecognised team $TEAM"
   exit
fi

#================================================
# Handle the category parm
#================================================
typeset -u CATEGORY
CATEGORY=$4

#================================================
# Handle the subcategory parm
#================================================
typeset -u SUBCATEGORY
SUBCATEGORY=$5

#================================================
# Handle the subject parm
#================================================
SUBJECT=$6
[ -n "$debug" ] && print -u2 -- "${YELLOW}subject: $SUBJECT${RESET}"

if [[ -z "$SUBJECT" ]]; then
   print -u2 -- "Must supply ticket subject line\n\n"
   syntax
fi

#================================================
# Handle the description parm
# value can come from a number of sources
# 1. the parm can be a filename 
# 2. if stdin is piped then read from stdin
# 3. the value of parm 7
# 4. if non of the above use the subject
#================================================
parm7=$7
if [ -r "$parm7" ]; then
  while read line; do
      DETAIL="$DETAIL\n$line"
   done <$parm7
   
elif [ -n "$parm7" ]; then 
   DETAIL="$parm7"
elif [[ "$( tty )" = *'not a tty'* ]]; then
   while read line; do
      DETAIL="$DETAIL\n$line"
   done
else
   DETAIL="$SUBJECT"
fi

DETAIL=$(urlencode "$DETAIL")
SUBJECT=$(urlencode "$SUBJECT")

[ -n "$debug" ] && print -u2 -- "${YELLOW}detail: $DETAIL${RESET}"

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
if [ "$USERID" = "auto-ticket" ]; then
   PASSWORD=$(/usr/local/bin/perl -ne 'use MIME::Base64; print decode_base64($_);' /etc/.impact)
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
FULLNAME="$FIRSTNAME $LASTNAME"  
USERID_ENC=$(urlencode "$USERID")
FIRSTNAME=$(urlencode "$FIRSTNAME")
LASTNAME=$(urlencode "$LASTNAME")

LOGIN_POST="GoToURL=&LoginAttempts=1&Password=$PASSWORD&UserID=$USERID_ENC&submit_request="

#================================================
# Print some debugging info
#================================================
if [ -n "$debug" ]; then
   print -u2 -- "${YELLOW}userid${RESET}: $USERID"
   print -u2 -- "${YELLOW}userid_enc${RESET}: $USERID_ENC"
   print -u2 -- "${YELLOW}password${RESET}: $PASSWORD"
   print -u2 -- "${YELLOW}customer${RESET}: $CUSTOMER"
   print -u2 -- "${YELLOW}URL${RESET}: $URL"
fi

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
	if [[ $COMPLETE_BY = 20[0-9][0-9]/[0-1][0-9]/[0-3][0-9]" "[0-2][0-9]":"[0-5][0-9] ]]; then
		CB='Y'
      CB_SEC=0
      CB_YEAR=${COMPLETE_BY%%\/*}
      COMPLETE_BY=${COMPLETE_BY#*\/}
      CB_MONTH=${COMPLETE_BY%%\/*}
      COMPLETE_BY=${COMPLETE_BY#*\/}
      CB_DAY=${COMPLETE_BY%% *}
      COMPLETE_BY=${COMPLETE_BY#* }
      CB_HOUR=${COMPLETE_BY%%:*}
      COMPLETE_BY=${COMPLETE_BY#*:}
      CB_MIN=$COMPLETE_BY
      if [[ $CB_HOUR -gt 12 ]]; then
         CB_AMPM="PM"
         CB_HOUR=$((CB_HOUR-12))
      else
         CB_AMPM="AM"
		fi
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

#================================================
# Goto login page to get the cookies set
#================================================
if [ -n "$debug" ]; then
   print -u2 -- "${CYAN}Get login page${RESET}"
else
   print -n -u2 -- "Gathering info ."
fi

[ -n "$debug" ] && print -u2 -- "curl $k -s -b $cookie_jar -c $cookie_jar \"$URL/loginPage.asp?ErrorState=&LoginAttempts=\" >/dev/null"
curl $k -s -b $cookie_jar -c $cookie_jar "$URL/loginPage.asp?ErrorState=&LoginAttempts=" >/dev/null 

#================================================
# POST login details
#================================================
[ -n "$debug" ] && print -u2 -- "curl $k -s -L -b $cookie_jar -c $cookie_jar -d \"$LOGIN_POST\" \"$URL/Login.asp\""
curl $k -s -L -b $cookie_jar -c $cookie_jar -d "$LOGIN_POST" "$URL/Login.asp" |&
exec 4>&p
exec 5<&p

[ -n "$debug" ] && print -u2 -- "Logging into Impact"
while read -u5 line; do
		[ "$debug" = "1" ] && print -u2 -- "$line"
      if [[ "$line" = *"ifrmLeftNavigator"* ]]; then
         loginok=1

      elif [[ "$line" = *"Your login id and password do not match our records"* ]]; then
         print -u2 -- "Userid/password incorrect"
         exit 2
      fi
done
exec 4>&-

if [ -z "$loginok" ]; then
   print -u2 -- "Impact login failed"
   exit 2
fi

[ -n "$debug" ] && print -u2 -- "Login successful"

#================================================
# GET contactid
#================================================
if [ -z "$debug" ]; then
   print -n -u2 -- "."
else
   print -u2 -- "${CYAN}Get contactid${RESET} for Firstname: $FIRSTNAME  lastname: $LASTNAME"
fi

curl $k -s -L -b $cookie_jar -c $cookie_jar "$URL/RetrievePotentialContacts.asp?AddContactAllowed=1&FirstName=$FIRSTNAME&LastName=$LASTNAME&AreaCode=&PhoneNumber=&EmailAddress=&Address=&City=&CompanyName=&DepartmentName=&Title=&PostalCode=" |&
exec 4>&p
exec 5<&p

while read -u5 line; do
   [ "$debug" = "2" ] && print -u2 -- "$line"
   if [[ "$line" = *([:blank:])"ReturnContact"* ]]; then
      line=${line%\)*}
      CONTACTID=${line##*,\ }
      break
   fi
done
exec 4>&-
   
if [ -z "$CONTACTID" ]; then
   print -u2 -- "Failed to obtain Impact ticket Contact ID check FIRSTNAME/LASTNAME settings in config XML"
   exit 2
fi

[ -n "$debug" ] && print -u2 -- "${YELLOW}Using Contactid${RESET}: $CONTACTID"

#================================================
# POST project values
# Get PROJECTID and FOLDERID 
#================================================
if [ -z "$debug" ]; then
   print -n -u2 -- "."
else
   print -u2 -- "${CYAN}Get projectid(s) for contactid:$CONTACTID${RESET}"
fi

curl $k -s -L -b $cookie_jar -c $cookie_jar -d "CallerMode=T&ContactId=$CONTACTID&ProjectId=" "$URL/RetrieveContactProjects.asp" |&
exec 4>&p
exec 5<&p

typeset -u LINEU
typeset -u project_name
while read -u5 line; do
	[ "$debug" -gt "3" ] && print -u2 -- ">> $line"
   LINEU=$line
   if [[ "$LINEU" = *([:blank:])"VAR ARR"[0-9]* ]]; then
      line=${line#*\"}
      project_name=${line%%\"*}
      line=${line%\",*}
      line=${line#*,\"}
	
    if [[ "$project_name" = *'SERVICE REQUEST' ]] ; then
         #====================================================
         # Always saved project id for service request
         # incase we need to link new request to existing SR
         #====================================================
		[ -n "$debug" ] && print -u2 -- "matched $line"
         SRFOLDERID=${line##*,\"}
         SRPROJECTID=${line%%\"*}
      fi
    [ -n "$debug" ] && print -u2 -- "Type: $TYPE"
    if [[ "$project_name" = *"$TYPE" ]] ; then
         FOLDERID=${line##*,\"}
         PROJECTID=${line%%\"*}   
      fi
   fi
done

exec 4>&-

  
[ -n "$debug" ] && print -u2 -- "${YELLOW}PROJECTID${RESET}: $PROJECTID ${YELLOW}FOLDERID${RESET}: $FOLDERID" \
            "\n${YELLOW}SRPROJECTID${RESET}: $SRPROJECTID ${YELLOW}SRFOLDERID${RESET}: $SRFOLDERID"

#================================================
# GET customer values  
#================================================
if [ -z "$debug" ]; then
   print -n -u2 -- "."
else
   print -u2 -- "${CYAN}Get customer names${RESET}"
fi
# RequestEAEmbedded.asp?ProjectId=-2147483312&RequestId=-2147483648&CategoryCode=C2007&SubCategoryCode=S0026&ServiceCatalogId=&ContactId=-2146687670&SearchForMainAttributes=Y&ClassType=R&ClassTypeCode=&SetUpForCopy=N&CallerMode=T
# RequestEAEmbedded.asp?ProjectId=-2147483312&RequestId=&CategoryCode=&SubCategoryCode=&ServiceCatalogId=&ContactId=-2146949030&SearchForMainAttributes=Y&ClassType=R&ClassTypeCode=&SetUpForCopy=Y&CallerMode=T
# RequestEAEmbedded.asp?ProjectId=-2147483312&RequestId=&CategoryCode=&SubCategoryCode=&ServiceCatalogId=&ContactId=-2146949022&SearchForMainAttributes=Y&ClassType=R&ClassTypeCode=&SetUpForCopy=N&CallerMode=T
[ "$debug" = "4" ] && print -u2 -- "curl $k -s -L -b $cookie_jar -c $cookie_jar $URL/RequestEAEmbedded.asp?ProjectId=$PROJECTID&RequestId=&CategoryCode=&SubCategoryCode=&ServiceCatalogId=&ContactId=$CONTACTID&SearchForMainAttributes=Y&ClassType=R&ClassTypeCode=&SetUpForCopy=N&CallerMode=T"
curl $k -s -L -b $cookie_jar -c $cookie_jar "$URL/RequestEAEmbedded.asp?ProjectId=$PROJECTID&RequestId=-2147483648&CategoryCode=&SubCategoryCode=&ServiceCatalogId=&ContactId=$CONTACTID&SearchForMainAttributes=Y&ClassType=R&ClassTypeCode=&SetUpForCopy=N&CallerMode=T" |&
exec 4>&p
exec 5<&p
while read -u5 line; do
   [ "$debug" = "4" ] && print -u2 -- "${RED}$line${RESET}"
   if [[ "$line" = *"id='RESHCUSTOMER'"* ]]; then
      printon=1
   fi
   if [ -n "$printon" ]; then 
      if [[ "$line" = *"<option value="* && "$line" != *"Please Select"* ]]; then
         [ "$debug" = "4" ] && print -u2 -- "${RED}$line${RESET}"
         cust=${line#*\>}
         cust=${cust%\<*}
         if [[ "$cust" = "$CUSTOMER" ]]; then
            custok=1
            break
         else
            cust_list="$cust_list\n\t$cust"
         fi
      fi
      if [[ "$line" = *+("</TD>"|"</select>")* ]]; then
         break
      fi
   fi
done          
exec 4>&-
   
if [ -z "$custok" ]; then
   print -u2 -- "Invalid customer $CUSTOMER specified valid values are: $cust_list"
   exit
fi

[ -n "$debug" ] && print -u2 -- "${YELLOW}Customer: $CUSTOMER${RESET}"

#=====================================================================
# Get activity levels for the projectid matching the type of ticket
# activities is the Queue on which to place the ticket  
#=====================================================================
if [ -z "$debug" ]; then
   print -n -u2 -- "."
else
   print -u2 -- "${CYAN}Get activities for projectid: $PROJECTID${RESET}"
fi

typeset -u activity_name
curl $k -s -L -b $cookie_jar -c $cookie_jar "$URL/RetrieveActivityLevels.asp?ProjectId=$PROJECTID&CallerMode=T" |&
exec 4>&p
exec 5<&p

while read -u5 line; do
   LINEU=$line
   [ "$debug" = "5" ] && print -u2 -- "${RED}$line${RESET}"
   if [[ "$LINEU" = *([:blank:])"VAR ARR"[0-9]* ]]; then
      line=${line#*\"}
      activity_name=${line%%\",*}
         
      if [[ "$activity_name" = *"$ACTIVITY"* ]] ; then
         [ "$debug" = "5" ] && print -u2 -- "Matched $line${RESET}"
         line=${line#*\",\"}
         ACTIVITYID=${line%%\",*}
         [ "$debug" = "5" ] && print -u2 -- "\t${GREEN}found $activity_name:$ACTIVITYID;${RESET}"
         activityok=1
         break
      else
         activity_list="$activity_list\n\t$activity_name"
      fi
   fi
done
exec 4>&-
   
if [ -z "$activityok" ]; then
   print -u2 -- "Invalid activity $ACTIVITY specified, valid values are: $activity_list"
   exit
fi
[ -n "$debug" ] && print -u2 -- "${YELLOW}Activityid${RESET}: $ACTIVITYID"

#==============================================================
# POST categorys for the projectid matching the type of ticket
#==============================================================
if [ -z "$debug" ]; then
   print -n -u2 -- "."
else
   print -u2 -- "${CYAN}Get categories for projectid: $PROJECTID${RESET}"
fi

typeset -u category_name
curl $k -s -L -b $cookie_jar -c $cookie_jar -d "CallerMode=T&ProjectId=$PROJECTID" "$URL/RetrieveCategories.asp" |&
exec 4>&p
exec 5<&p
while read -u5 line; do
   LINEU=$line
   [ "$debug" = "6" ] && print -u2 -- "${RED}$line${RESET}"
   if [[ "$LINEU" = *([:blank:])"VAR ARR"[0-9]* ]]; then
      line=${line#*\"}
      category_name=${line%%\"*}
      if [[ "$category_name" = *"$CATEGORY"* ]]; then
         line=${line#*,\"}
         CATEGORYID=${line%%\"*}
         [ -n "$debug" ] && print -u2 -- "\t${GREEN}found $category_name:$CATEGORYID;${RESET}"
         categoryok=1
         break
      else
         category_list="$category_list\n\t$category_name"
      fi
   fi
done
exec 4>&-
   
if [ -z "$categoryok" ]; then
   print -u2 -- "Invalid category code $CATEGORY specified, valid values are: $category_list"
   exit
fi
 [ -n "$debug" ] && print -u2 -- "${YELLOW}Categoryid${RESET}: $CATEGORYID"
 
#==================================================
# GET subcategorys for the projectid and category
#================================================== 
if [ -z "$debug" ]; then
   print -n -u2 -- "."
else
   print -u2 -- "${CYAN}Get subcategories for projectid: $PROJECTID  categoryid: $CATEGORYID${RESET}"
fi

typeset -u subcategory_name
curl $k -s -L -b $cookie_jar -c $cookie_jar -d " " "$URL/RetrieveSubCategories.asp?ProjectId=$PROJECTID&Category=$CATEGORYID&CallerMode=T" |&
exec 4>&p
exec 5<&p
while read -u5 line; do
   LINEU=$line
   [ "$debug" = "7" ] && print -u2 -- "${RED}$line${RESET}"
   if [[ "$LINEU" = *([:blank:])"VAR ARR"[0-9]* ]]; then 
      subcategory=${line#*\"}
      subcategory_name=${subcategory%%\"*}
      if [[ "$subcategory_name" = *"$SUBCATEGORY"* ]]; then   
         subcategoryid=${subcategory#*,\"}
         SUBCATEGORYID=${subcategoryid%%\"*}
         [ "$debug" = "7" ] && print -u2 -- "\t${GREEN}$subcategory_name:$SUBCATEGORYID;${RESET}"
         subcategoryok=1
         break
      else
         subcategory_list="$subcategory_list\n\t$subcategory_name"
      fi
   fi
done
exec 4>&-
   
if [ -z "$subcategoryok" ]; then
   print -u2 -- "Invalid subcategory code $SUBCATEGORY specified, valid values are: $subcategory_list"
   exit
fi
[ -n "$debug" ] && print -u2 -- "${YELLOW}Subcategory${RESET}: $SUBCATEGORYID" 

#====================================
# Get id for activitylevel queue
#==================================== 
if [ -z "$debug" ]; then 
   print -n -u2 -- "."
else
   print -u2 -- "${CYAN}Get ownerid for ticket${RESET}"
fi
   
curl $k -s -L -b $cookie_jar -c $cookie_jar -d "ActivityLevelID=$ACTIVITYID&CallerMode=T&CategoryCode=$CATEGORYID&FolderID=$FOLDERID&OverrideOwningResource=false&ProjectID=$PROJECTID&RecordingResource=$CONTACTID&SubcategoryCode=$SUBCATEGORYID" "$URL/RetrieveResourcesToAssign.asp" |&
exec 4>&p
exec 5<&p
typeset -u owner_name
while read -u5 line; do
   [ "$debug" = "8" ] && print -u2 -- "${RED}$line${RESET}"
   if [[ "$line" = *([:blank:])"var arr"[0-9]* ]]; then
      line=${line#*\"}
      owner_name=${line%% hrs*}
      owner_name=${owner_name% *}
      if [[ "$owner_name" = *"$OWNER"* ]]; then
         line=${line%\"*}
         OWNERID=${line##*\"}
         [ "$debug" = "8" ] && print -u2 -- "${RED}$owner_name\t$OWNERID${RESET}"
         ownerok=1
         break
      else
         owner_list="$owner_list\n\t$owner_name"
      fi
   fi   
done

if [ -z "$ownerok" ]; then
   print -u2 -- "Invalid owner $OWNER specified, valid values are: $owner_list"
   exit
fi

[ -n "$debug" ] && print -u2 -- "${YELLOW}Ownerid${RESET}: $OWNERID"


#========================================
# Create the new ticket 
#========================================
   TTS=$(date +"%s")
   TTS=$((TTS+68446))		# dont ask why 68446 value obtained by experimentation !

	
	data="ActivityLevelId=$ACTIVITYID"
	data="$data&AssetEnabledFlag=Y"
	data="$data&CallerMode=T"
	data="$data&CategoryCode=$CATEGORYID"
   data="$data&CloseOnComplete=false"
   data="$data&ContactId=$CONTACTID"
   data="$data&ContactNote="
   data="$data&CurrentAssetID="
   data="$data&Description=$DETAIL"
   data="$data&EAA="
   data="$data&EAARESHCUSTOMER=$CUSTOMER"
   data="$data&EAAStandardRFSCloseCodes=%20"
   data="$data&ExternalReference="
   data="$data&FolderID=$FOLDERID"
   data="$data&IsLoaded=Y"
   data="$data&IsUnLoaded=N"
   data="$data&ModuleId=-2147483648"        # -2147483648 = not specified
   data="$data&OpenedAMPM=$AMPM"
   data="$data&OpenedDay=$DAY"
   data="$data&OpenedHour=$HOUR"
   data="$data&OpenedMinute=$MIN"
   data="$data&OpenedMonth=$MONTH"
   data="$data&OpenedSeconds=$SEC"
   data="$data&OpenedYear=$YEAR"
   data="$data&OwningResource=$OWNERID"
   data="$data&ParentRequests="
   data="$data&PerformClose=N"
   data="$data&Priority=$PRIORITY"
   data="$data&ProjectEnhancedCategorizationEnabled=N"
   data="$data&ProjectId=$PROJECTID"
   data="$data&ProjectQueueRankingEnabled=N"
   data="$data&ProjectResolutionEnabled=N"
   data="$data&ReceivedAMPM=$AMPM"
   data="$data&ReceivedDay=$DAY"
   data="$data&ReceivedHour=$HOUR"
   data="$data&ReceivedMinute=$MIN"
   data="$data&ReceivedMonth=$MONTH"
   data="$data&ReceivedSeconds=$SEC"
   data="$data&ReceivedYear=$YEAR"
   data="$data&RequestId=-2147483648"          # -2147483648 = not specified
   data="$data&ResolutionId=-2147483648"       # -2147483648 = not specified
   data="$data&ResolvedImmediate=false"
   data="$data&SaveInProgress=true"
   data="$data&ScheduledCompleteByAMPM=$CB_AMPM"
   data="$data&ScheduledCompleteByDay=$CB_DAY"
   data="$data&ScheduledCompleteByHour=$CB_HOUR"
   data="$data&ScheduledCompleteByMinute=$CB_MIN"
   data="$data&ScheduledCompleteByMonth=$CB_MONTH"
   data="$data&ScheduledCompleteBySeconds=$CB_SEC"
   data="$data&ScheduledCompleteByYear=$CB_YEAR"
   data="$data&ScheduledCompletionFlag=$CB"
   data="$data&SelectedAssets="
   data="$data&ServiceCatalogId="
   data="$data&Severity=$SEVERITY"
   data="$data&Source=Phone"
   data="$data&SubcategoryCode=$SUBCATEGORYID"
   data="$data&Subject=$SUBJECT"
   data="$data&TTS=$TTS"
   data="$data&WhiteboardIssueId="
			
	
	print -u2 -- "Creating ticket"
	
	if [ -n "$debug" ]; then
	  OLDIFS=$IFS
	  IFS="\&"
	  for attr in $data; do
	     print -u2 -- $attr
	  done
	  IFS=$OLDIFS
	fi

curl $k -s -L -b $cookie_jar -c $cookie_jar -d "$data" "$URL/ResourceFinalAdd.asp" |&
exec 4>&p
exec 5<&p
while read -u5 line; do
   [ "$debug" = "8" ] && print -u2 -- "${RED}$line${RESET}"
   if [[ $line = *"var arrRequest = new Array"* ]]; then
    [ "$debug" -gt "3" ] && print -u2 -- "Matched: $line${RESET}"
      set -- $(IFS=\"; set -- ${line}; print $*)
      TICKET="${8}${6}"
   fi
done
exec 4>&-

#=========================================================
# check ticket was created
#=========================================================
if [[ "$TICKET" = +("RESHI"|"RESHR")* ]]; then
   print "Ticket $TICKET created"
else
   print "Add failed"
	exit
fi

#=========================================================
# Do we need to link to an existing SR ?
#=========================================================
if [ -n "$SR" ]; then
  
	typeset -u USR
	USR=$SR
   typeset -u TICKET
   
   # make sure SR is just the number
   SR=${USR#@(RESHI|RESHR)}
   # get Ticket number
   TICKET=${TICKET#@(RESHI|RESHR)}


                   
#https://testimpact.rny.ihost.com/IM/scripts/PersistRequestLinkAdd.asp?CallerMode=T&Project=-2147483323&ProjectId=-2147483326&Relationship=P&RequestId=276&RequestNumber=190

	[ -n "$debug" ] && print -u2 --  "curl $k -s -L -b $cookie_jar -c $cookie_jar -d \"CallerMode=T&Project=$SRPROJECTID&ProjectId=$PROJECTID&Relationship=P&RequestId=$TICKET&RequestNumber=$SR\" \"$URL/PersistRequestLinkAdd.asp\""
   curl $k -s -L -b $cookie_jar -c $cookie_jar -d "CallerMode=T&Project=$SRPROJECTID&ProjectId=$PROJECTID&Relationship=P&RequestId=$TICKET&RequestNumber=$SR" "$URL/PersistRequestLinkAdd.asp" |&
   exec 4>&p
   exec 5<&p
   while read -u5 line; do
		[ -n "$debug" ] && print -u2 -- $line
      # var arrStatus = new Array("true","")
      # var arrStatus = new Array("false","One of the request records does not exist for this request_link record.")
      if [[ "$line" = *"var arrStatus = new Array("* ]]; then
         line=${line#*\"}
         link_status=${line%%\"*}
         line=${line#*\",\"}
         link_msg=${line%\"*}         
         break
      fi
   done
   exec 4>&-
   if [[ "$link_status" = "true" ]]; then
      print "Linked to RESHR${SR}"
   else
      print "Link failed: $link_msg"
   fi 
fi
 
 rm -f $cookie_jar
