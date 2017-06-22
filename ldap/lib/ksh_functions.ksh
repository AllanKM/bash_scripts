#!/bin/ksh

#---------------------------------------------------------
# color codes
#---------------------------------------------------------
   BLACK="\033[30;1;49m"
   RED="\033[31;1;49m"
   GREEN="\033[32;1;49m"
   YELLOW="\033[33;1;49m"
   BLUE="\033[34;1;49m"
   MAGENTA="\033[35;1;49m"
   CYAN="\033[36;1;49m"
   WHITE="\033[37;1;49m"
   RESET="\033[0m"

#-----------------------------------------------
# repeat a string a defined number of times 
#-----------------------------------------------
function repeat { typeset i=$1 c="$2" s="" ; while ((i)) ; do ((i=i-1)) ; s="$s$c" ; done ; echo  "$s" ; }

#-----------------------------------------------
# print string enclosed in * 
#-----------------------------------------------
function show {
   if [[ "$1" = "h:"* ]]; then
      msg="* ${@#*:} ${RESET}*"
      clean=$(echo "$msg" | sed -r "s/\x1B\[([0-9]{1,2};)?[0-1](;[0-9]{1,2})?m//g")
      len=$(( ${#clean} ))
      line=$(repeat $len \*)
      print -- "$line\n$msg\n$line"
      unset msg
   else
      print -u2 -- "$@$RESET"
   fi
}
