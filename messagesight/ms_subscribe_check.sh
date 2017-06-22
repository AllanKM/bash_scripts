#!/bin/bash
server=$1
if [[ "$server" = p[1-35]msa0[1-3]e[1-2]* ]]; then
   server=$(echo $server | sed -e 's/\(p[1-35]msa0[1-3]e[1-2]\).*/\1/')

   if [[ $(uname) == "AIX" ]] ; then
     server=$(host ${server}.event.ibm.com | sed -e 's/^.* is //')
   elif [[ $(uname) == "Linux" ]] ; then
     server=$(host ${server}.event.ibm.com | sed -e 's/^.* has address //')
   fi
elif [[ "$server" = s[1-9]* ]] ; then
   server=$(echo $server | cut -c -6)

   if [[ $(eilssys -l role $server|grep MESSAGESIGHT >/dev/null 2>&1) -eq 0 ]] ; then
     if [[ $(uname) == "AIX" ]] ; then
       server=$(host ${server}e1.event.ibm.com | sed -e 's/^.* is //')
     elif [[ $(uname) == "Linux" ]] ; then
       server=$(host ${server}e1.event.ibm.com | sed -e 's/^.* has address //')
     fi
   else 
     echo "$server is an invalid messagesite server"
     exit
   fi
elif [[ "$server" != 10\.* ]]; then
   echo "$server is an invalid messagesite server"
	echo "servername should be in the format p[1-35]msa0[1-3]e[1-2]"
	exit
fi

event=$2
case $event in 
   aus|cmauso|australian ) event=ausopen ;;
   wim|cmwimb|wimbledon ) event=wim ;;
   rg|cmrolg|roland ) event=rg ;;
   us|cmusta|usopen ) event=uso ;;
   cn|cmcnop|chinaopen ) event=chinaopen ;;
	* ) echo  "$event is an invalid publishing path"
		exit
	;;
esac

msgs=`/lfs/system/tools/messagesight/ms_subscribe -s $server -c 1 -t 1 -T events/${event}/tennis/# 2> /dev/null |grep 'Message:' |wc -l`

if [ $msgs -gt 0 ]; then
echo $1 ": OK"
else
echo $1 ": No messages."
fi

ssl=`echo $3 | tr '[:lower:]' '[:upper:]'`
if [ "${ssl}" == "NOSSL" ]; then
 exit
else
 msgs=`/lfs/system/tools/messagesight/ms_subscribe -z -k /lfs/system/tools/messagesight/cacerts -s $server -c 1 -t 1 -T events/${event}/tennis/# 2> /dev/null |grep 'Message:' |wc -l`

   if [ $msgs -gt 0 ]; then
    echo $1 "(SSL): OK"
   else
    echo $1 "(SSL): No messages."
   fi
fi
