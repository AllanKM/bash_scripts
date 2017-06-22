#!/bin/ksh

HOST=`hostname -s`

# ITSC104 rules
ihsid="webinst"
admin_groups="apps eiadm "

ROOT=`grep -i "^[[:space:]]*serverroot" /usr/HTTPServer/conf/httpd.conf | awk {'print $2'} | tr -d \" | sort | uniq`
INCLUDES=`grep -i "^[[:space:]]*include" /usr/HTTPServer/conf/httpd.conf | awk {'print $2'} | tr -d \" | sort | uniq`

for INC in $INCLUDES; do
	x=`print $INC | cut -c 1`
	if [[ $x != "/" ]]; then
		INC="$ROOT/$INC"
	fi
	if [[ -f $INC ]]; then
		CONFS="$CONFS $INC"
	fi
done
CONFS="$CONFS $ROOT/conf/httpd.conf"

# is mod_autoindex installed, required for auto listing
# is Options indexes or +indexes defined
rm /tmp/5_3_auto$$ >/dev/null 2>&1
print "Checking for invalid autoindex keywords"
for CONF in $CONFS; do
	awk -v HOST=$HOST '
		tolower($0) ~ /<directory/ { indir=$2
			next	
		 }
		tolower($0) ~ /<\/directory/ { indir="" 
			next
		}
		tolower($0) ~ /-indexes/ {
			next
		}
		tolower($0) ~ /indexes/ {
			if ( tolower($0) !~ /^[[:space:]]*#/) {
				if ( indir="" ) { 
				   print "Invalid autoindex config in "FILENAME }
			}
		}
	' $CONF >>/tmp/5_3_auto$$
done
cat /tmp/5_3_auto$$ | sort | uniq
