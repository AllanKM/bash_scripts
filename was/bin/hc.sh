#!/bin/ksh

#====================================================================================
# Wrapper for Curl to lookup keystore and password required to access 
# was nodes with client authentication enabled
#
# $author:
# $Revision:
#==================================================================================== 

# check if curl requires -k 
curl --help | while read line; do
   if [[ "$line" = *'--insecure'* ]]; then
		k="-k"
		continue
	fi
done


host=$(uname -n)
while [ -n "$1" ]; do
	arg=$1
	if [[ "$1" = @(http|https)://* ]]; then
		url=$1
   elif [[ "$arg" = -auth=* ]]; then
		arg=${arg#*=}
		args="-u $arg $args"
   else 
		args="$args $arg"
	fi
	shift
done
if [ -z "$url" ] || [[ "$url" != @(http|https)://* ]]; then 
	print -u2 -- "#### Missing or invalid url"
	exit 4
fi
args="$args $url"
[ -n "$debug" ] && print -u2 -- "doing hc using $url"
if [[ "$url" = "https://"* ]]; then 
	[ -n "$debug" ] && print -u2 -- "this is a https request"
	#=========================================
	# read nodecache file to get server realm
	#=========================================
	if [ -r /usr/local/etc/nodecache ]; then
		while read line; do
	  		if [[ "$line" = realm* ]]; then
				realm=${line#*= }
			fi
		done < /usr/local/etc/nodecache
	fi
		
	if [ -z "$realm" ]; then
		print -u2 -- "#### Cannot determine zone for $host"
		exit 4
	fi
		
	zone=${realm%%.*}
	keyfile=/lfs/system/tools/was/etc/ei.${zone}z.was.client.pem
	if [ ! -e $keyfile ]; then
		print "$keyfile does not exist"
		exit 4
	fi

	#=========================================
	# lookup and decode the password
	#=========================================	
	if [ -r /lfs/system/tools/was/etc/was_passwd ]; then
		while read line; do
			if [[ "$line" = "clientauth_${zone}z="* ]]; then
				base64pw=${line#*=}
			fi 
		done < /lfs/system/tools/was/etc/was_passwd
	else
		print -u2 -- "#### cannot read /lfs/system/tools/was/etc/was_passwd"
		exit 4
	fi	
	
	if [ -z "$base64pw" ]; then
		print -u2 -- "#### cannot find password for $keyfile in /lfs/system/tools/was/etc/was_passwd"
		exit 4
	fi	
	
	pw=$(print $base64pw | /usr/local/bin/perl -ne 'use MIME::Base64; print decode_base64($_);')
	
	#=========================================
	# do the heathcheck
	#=========================================
	[ -n "$debug" ] && print "curl $k -s -L --cert $keyfile --pass $pw $args | /usr/bin/lynx --dump --stdin"
	
	response=$(/usr/bin/curl $k -s -L --cert $keyfile --pass $pw $args)
	#=========================================
	# if we get html response then use 
	# lynx to present it
	#=========================================
	if [[ "$response" = *"<"@(html|head|body|title|h1|h2|h3)">"* ]]; then
		print $response | /usr/bin/lynx --dump --stdin
	#=========================================
	# otherwise just print it out 
	#=========================================		
	else
		print -r "$response"
	fi
else
	[ -n "$debug" ] && print -u2 -- "Using standard lynx"
	# not an ssl url to just use straight lynx
	/usr/bin/lynx --dump $args
fi

