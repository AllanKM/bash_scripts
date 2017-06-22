#!/bin/ksh

HOST=`hostname -s`
ihsid="webinst"
admin_groups="apps eiadm "

for ADMIN in $admin_groups; do
	admins="$admins ! -group $ADMIN"
done

INCLUDES=`cat /usr/HTTPServer/conf/httpd.conf | grep -i "^[[:space:]]*include" | grep -v "^[[:space:]]*#" | awk {'print $2'} | tr -d \" | sort | uniq`

INCLUDES="$INCLUDES /usr/HTTPServer/conf/httpd.conf"
rm /tmp/6_1_logging$$ >/dev/null 2>&1
for INC in $INCLUDES; do
	x=`print $INC | cut -c 1`
	if [[ $x != "/" ]]; then
		INC="$ROOT/$INC"
	fi
	if [[ -f $INC ]]; then
		awk -v HOST=$HOST '
			tolower($0) ~ /^[ \t]*transferlog/ { sub(/^[ \t]+/, "");print "ITCS,"HOST",TFL,"$0 }
			tolower($0) ~ /^[ \t]*customlog/ { sub(/^[ \t]+/, "");print "ITCS,"HOST",AUD,"$0 }
		' $INC >>/tmp/6_1_logging$$
	fi
done

cat /tmp/6_1_logging$$ | sort | uniq
