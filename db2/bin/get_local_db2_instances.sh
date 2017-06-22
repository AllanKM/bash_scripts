#!/bin/ksh

get_host_info() {
	typeset var line 
	while read -r line; do
		case $line in
			systemtype* ) hardware=${line#*=};;
   		custtag* ) cust=${line#*=};;
   		realm* )
   			realm=${line#*=}
   			realm=${realm%%\.*}
   		;;
   	esac
	done < /usr/local/etc/nodecache 
}

print_host_info()
{
    printf "%-8s %-10s %-10s %-10s %-10s %-15s %-4s %-10s\n" ${db2_version} ${instance} ${cust} ${host} ${os} ${hardware} $(echo ${zone} | awk '{print toupper($1)}') ${is_staging}
}


host=`uname -n`	
INSTANCE_CMD_LIST=`find /opt /usr -name "db2ilist" 2>/dev/null | grep instance/db2ilist`
[ -n "$debug" ] && print -u2 -- "Instances: $INSTANCE_CMD_LIST"
if [ "$INSTANCE_CMD_LIST" != "" ]; then   
	os=$(uname -s)
	db2_install_type=""
	is_staging=""
	SITE=$(echo ${host} | cut -c1-2)
	get_host_info
	for INSTANCE_LIST in $INSTANCE_CMD_LIST; do
   	db2_all_cmd=$(echo $INSTANCE_LIST|sed 's/instance\/db2ilist/bin\/db2_all/g') 
   	if [ "$(ls $db2_all_cmd 2>/dev/null | grep db2_all)" != "" ]; then
      	db2_install_type="Server"
      else
         db2_install_type="Client"
   	fi
   	[ -n "$debug" ] && print -u2 -- "DB2 Install type: $db2_install_type"
   	
   	for instance in $($INSTANCE_LIST); do
			instdir=`grep -i ^$instance /etc/passwd | awk -F":" '{print $6}'`
			profile="$instdir/sqllib/db2profile"
			. $profile
			DB2VER=`db2level`
			[ -n "$debug" ] && print -u2 -- "$INSTANCE_LIST DB2 version: $DB2VER"
			DB2VER=`echo $DB2VER | tr "\n" " " | awk '{ print substr($0,index($0,"tokens are")+10,58) }' | tr -d " \"" | tr "," "_" | sed -e "s/andFixPac*k/FP/g"`
			db2_version=${db2_install_type}_$DB2VER
			print_host_info
			export LIBPATH=""
      done
   done
fi
if [ -e ~webinst/sqllib/java/db2jcc.jar ]; then
	[ -n "$debug" ] && print -u2 -- "JDBC install detected"
	java=$(find /usr/HTTPServer*/java /usr/WebSphere*/AppServer/java/bin /usr/java* -name "java" 2>/dev/null | tail -n 1)
	
	$java -cp ~webinst/sqllib/java/db2jcc.jar com.ibm.db2.jcc.DB2Jcc -version | while read -r line; do
		if [[ "$line" = *"JDBC Universal Driver"* ]]; then
			get_host_info
			instance="webinst"
			db2_version="Client_DB2JDBC_${line#*Architecture }"
			print_host_info
		fi
	done
		
else 
	[ -n "$debug" ] && print -u2 -- "JDBC not installed"
fi
exit
