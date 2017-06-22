#!/bin/ksh

HOST=`hostname -s`
pubs="! -user root ! -user pubinst ! -user icom "
ihsid="webinst"
admin_groups="apps eiadm "
EXPLOITABLE="phf test-cgi nph-test-cgi post-query uptime upload wais.pl"
SHELL="sh bash csh ksh tsh tclsh wish perl command.com"

for FILE in $EXPLOITABLE; do
   EXC="$EXC -name $FILE "
done

for FILE in $SHELL; do
   SHL="$SHL -name $FILE "
done

ROOT=`grep -i "^[[:space:]]*serverroot" /usr/HTTPServer/conf/httpd.conf | awk {'print $2'} | tr -d \" | sort | uniq`
INCLUDES=`grep -i "^[[:space:]]*include" /usr/HTTPServer/conf/httpd.conf | awk {'print $2'} | tr -d \" | sort | uniq`

CONFS="$INCLUDES $ROOT/conf/httpd.conf"
rm /tmp/5_4_cgi$$ >/dev/null 2>&1

for CONF in $CONFS; do
	x=`print $CONF | cut -c 1`
	if [[ $x != "/" ]]; then
		CONF="$ROOT/$CONF"
	fi
	if [[ -f $CONF ]]; then  
		awk '
			/^\s*#/ { next }
			tolower($0) ~ /scriptalias/ { print $3
				next
			}
		' $CONF | tr -d \" >>/tmp/5_4_cgi$$
	fi
done
CGIDIRS=`cat /tmp/5_4_cgi$$ | sort | uniq`

for DIR in $CGIDIRS; do

print "Scanning $DIR for files with invalid owner "
	find $DIR \( $pubs \) ! type l -follow -perm -200 -exec ls -ld {} \; 2>/dev/null
print "scanning $DIR for files with global write access"
	find $DIR ! -type l -follow -perm -2 -exec ls -ld {} \;
print "scanning $DIR for banned executables"
	find $DIR \( $EXC \) -type f -exec ls -ld {} \;
print "scanning $DIR for shells"
	find $DIR \( $SHL \) -type f -exec ls -ld {} \; 

done
