#!/bin/ksh

os=$(uname -s)
host=`uname -n`
case $host in
   *e0) host=`echo $host | sed "s/e0$/e1/"`
      ;;
   [adg][ct][0-9][0-9][0-9][0-9]?e1) HOST=`echo $host | sed "s/e1$//"`
      ;;
	 rdu*|stl*|den*) host="${host}e1"
      ;;              
esac

SITE=$(echo ${host} | cut -c1-2)

get_host_info() {
   cat /usr/local/etc/nodecache | while read line; do
		typeset l linel
		linel=$line
		case $linel in
			custtag* )
				cust=${line#*= }
			;;
			systemtype* )
				hardware=${line#*= }
				hardware=${hardware#*.}
			;;
			realm* )
				zone=${line#*= }
				zone=${zone%%.*}Z
			;;
			role* )
				roles=${line#*= }
			;;
		esac
	done

}

print_host_info() {
	printf "%-8s %-10s %-10s %-10s %-10s %-15s %-4s %-10s\n" ${apptype} ${instance} ${cust} ${ihost} ${os} ${hardware} $(echo ${zone} | awk '{print toupper($1)}') ${is_staging}
}


resolve_symlinks() {
	file=$1
	ofile=$file
	while [ -L $file ]; do									# If name is a symbolic link ...
		 newname=$(file -h -- "$file")					# Resolve symbolic link
		 newname=${newname%[.\']}									# Drop trailing period in file cmd output
		 newname=${newname#*symbolic link to }	# Drop prefix string in file cmd output
		 newname=${newname#*\`}									# Drop trailing period in file cmd output

		 if [ "$newname" = "${newname#/}" ];then			# If symbolic link is not an absolute path ...
			scrdir=$(cd -P -- "$(/usr/bin/dirname -- "$(command -v -- "$file")")" && pwd -P)
			file=$scrdir/$newname							# Construct new script name and try again
		 else 
			file=$newname										# Symbolic link is an absolute path
		 fi
	done 

# have now resolved the file
	# now resolve any symlinked dirs in the path
	path=${file#/}
	unset newdir
	while [[ $path = */* ]]; do
		dir=${path%%/*}
		path=${path#*/}
		newdir="$newdir/$dir"
		if [ -L $newdir ]; then
			newdir=$(cd -P $newdir && pwd -P)
		fi
	done

	file="$newdir/$path"
	if [ -e $file ]; then
		print -u2 "\t$ofile resolves to $file"
		print $file
	fi
}

confs=$(
	for conf in /etc/apach*/httpd.conf /usr/HTTPServer/conf/httpd.conf /usr/HTTPServer*/conf/httpd.conf /projects/*/conf/*.conf; do
		if [[ $conf != *@(listen|admin|mobile|kht|mapfile)* ]]; then
			print -u2 "checking symlink $conf"
			resolve_symlinks $conf
		fi
	done | sort -u )

get_host_info

for conf in $confs; do
	print -u2 -- "Doing $conf"
	sitetag=${conf#/*/}
	sitetag=${sitetag%%/*}
	print -u2 -- "\tSitetag: $sitetag"
	if [ `uname` == "AIX" ]; then
		LIBPATH="/projects/${sitetag}/lib"
		export LIBPATH
	 elif [ `uname` == "Linux" ]; then
		LD_LIBRARY_PATH="/projects/${sitetag}/lib"
		export LD_LIBRARY_PATH
	 fi

	serverroot=$(grep -i '^[[:space:]]*serverroot' $conf | awk '{print $2}' | tr -d \")
	apachectl=$serverroot/bin/apache*ctl
	httpd=$serverroot/bin/httpd
	if [ -f $apachectl ] &&  ( [ -f ${httpd} ] || [ -f ${httpd}2 ] ); then
  		print -u2 -- "\t$apachectl -v "
  		version=`$apachectl -v | grep version: | awk '{print $3 "_" $4}' | tr " " "_"`
		apptype="IHS_"$version
		print -u2 -- "\t$apachectl -f $conf -S "
		if [[ "$roles" = *"WEBSERVER.EVENTS"* ]] || [[ "$roles" = *"WEBSERVER.SWS"* ]]; then
		   ihost=$(lssys -qe role==webserver.$sitetag.* eihostname==$host)
			if [ -z "$ihost" ]; then
				ihost=$host
			fi	
			INSTANCE_LIST=`$apachectl -f $conf -S 2>&1 | grep "^[0-9*]" | awk '{split($3,a,"/");split(a[5],b,".");print $2"_"b[1]}' | sort -u`
		else
			ihost=$host
		  INSTANCE_LIST=`$apachectl -f $conf -S 2>&1 | grep "^[0-9*]" | awk '{ print $2}' | sort -u`
		fi

		if [ -z "$INSTANCE_LIST" ]; then
			print -u2 -- "Instance list null"
			INSTANCE_LIST=$(grep -i  "^[[:space:]]*servername" $conf | awk '{print $2}')
			if [[ -z "$INSTANCE_LIST" ]]; then
				INSTANCE_LIST="HTTPServer"
			fi
		fi
		for instance in ${INSTANCE_LIST}; do 
			print_host_info
		done
   else 
		print -u2 -- "$apachectl does not exist for $conf"
	fi
done

