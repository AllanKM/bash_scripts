#!/bin/ksh
#------------------------------------------------------------
# read customer config file and create cli scripts to 
# create any cert objects and add them to valcreds
#------------------------------------------------------------
me=${0##.*\/}
if [ -n "$SUDO_USER" ]; then
	print "Do not use SUDO with this script"
	exit
fi
if [[ -z "$1" ]]; then 
	print "Syntax: $me <config file name>"
	print "\ncreates files in /projects/espre/content/datapower/cliscripts"
	exit
fi 
cfg=$1
umask 2
cfg=${cfg#*datapower\/}
cfg=${cfg%%\/*}
cfg=/projects/espre/content/datapower/$cfg/configs/new_customer.cfg

if [ ! -e "$cfg" ]; then
	print "Missing or invalid cfg $cfg"
	exit
fi
cfg=$(/opt/freeware/bin/readlink -fn $cfg)
deploy=${cfg##\/projects\/espre\/content\/datapower\/}
deploy=${deploy%%\/*}

if [[ "$deploy" = ivt* ]]; then 
	domain="support_websvc_eci_ivt"
elif [[ "$deploy" = production* ]]; then
	domain="support_websvc_eci_prod"
else
	print "Ooops! dont recognise the domain for $deploy"
	exit
fi

print "switch domain $domain\ntop\nconfigure terminal" >/projects/espre/content/datapower/cliscripts/${deploy}_verify.cfg

while read line; do
	line=$(print $line | sed -e 's/^ *//' )  # strip leading whitespace
	if [[ "$line" = "#"* ]]; then
		# ignore comment lines
		continue
	elif [[ $line = "copy"* ]] && [[ $line = *"cert:///"* ]]; then
		# create cert cli file
		if [ -z "$init_cert" ]; then
			print "switch domain $domain\ntop\nconfigure terminal" >/projects/espre/content/datapower/cliscripts/${deploy}_cert.cfg
		fi
		init_cert=1
		file=$(print $line | awk '{print $(NF)}'i | tr -d "\r" )
		while [ -z "$obj" ]; do
			exec 5</dev/tty
			print "Enter object name for \"$file\""
			read -u5 obj
			obj=$(print $obj | sed -e 's/[[:space:]]//g')
			print "Use object \"$obj\" for \"$file\""
			read -u5 ans
			if [ "$ans" != 'y' ]; then
				unset obj
			fi
		done
					
		print "crypto\n\tcertificate \"$obj\" \"$file\" ignore-expiration\nexit">>/projects/espre/content/datapower/cliscripts/${deploy}_cert.cfg
		print "show certificate \"$obj\"" >>/projects/espre/content/datapower/cliscripts/${deploy}_cert.cfg
		unset ans
		
		print "Add $obj to client-ValCred ? (y/N)"
		read -u5 ans
		if [ -z "$ans" ]; then 
			ans='N'
		fi
			
		if [ "$ans" = "y" ]; then
			client_valcred=1
			print "\ncrypto\n\tvalcred \"client-ValCred\"\n\t\tcertificate \"$obj\"\n\texit\nexit" >>/projects/espre/content/datapower/cliscripts/${deploy}_cert.cfg
		fi
		unset ans
		print "Add $obj to SSLServer-ValCred ? (y/N)"
		read -u5 ans
		if [ -z "$ans" ]; then 
			ans='N'
		fi
			
		if [ "$ans" = "y" ]; then
			server_valcred=1
			print "\ncrypto\n\tvalcred \"SSLServer-ValCred\"\n\t\tcertificate \"$obj\"\n\texit\nexit" >>/projects/espre/content/datapower/cliscripts/${deploy}_cert.cfg
		fi
		unset obj
	elif [[ "$line" = *"mkdir "* ]]; then
		file=$(print $line | awk '{print $(NF)}'| tr -d "\r")
		files="$files$file:"
		print "dir $file" >>/projects/espre/content/datapower/cliscripts/${deploy}_verify.cfg
	elif [[ "$line" = *"copy "* ]]; then
		file=$(print $line | awk '{print $(NF)}' | tr -d "\r" )
		file=${file%\/*}

		if [[ "$files" != *$file:* ]]; then
			files="$files$file:"
			print "dir $file" >>/projects/espre/content/datapower/cliscripts/${deploy}_verify.cfg
		fi
				
	fi
done <$cfg

if [ -n "$init_cert" ]; then
	if [ -n "$client_valcred" ]; then
		print "\nshow valcred \"client-ValCred\"" >>/projects/espre/content/datapower/cliscripts/${deploy}_cert.cfg
	fi
	if [ -n "$server_valcred" ]; then
		print "\nshow valcred \"SSLServer-ValCred\"" >>/projects/espre/content/datapower/cliscripts/${deploy}_cert.cfg
	fi
fi

print "\n\ndeploy cert objects using "
print "\texec http://www-930pre.events.ibm.com/datapower/cliscripts/${deploy}_cert.cfg"
print "\twrite mem"

print "\nverify files using "
print "\texec http://www-930pre.events.ibm.com/datapower/cliscripts/${deploy}_verify.cfg"
