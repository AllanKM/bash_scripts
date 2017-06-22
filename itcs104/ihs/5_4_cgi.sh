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
	GROUP=`ls -ld $DIR | awk '{print $4}'`
	if [[ $OS = "Linux" ]]; then
		USERS=`grep $GROUP /etc/group | awk -F\: '{print $4}' | cut -f 1 -d " " | awk -F, '{ for (x=1;x<=NF;x++) { print $(x) } }' | sort | awk '{ users=users$1"," } END { print users }'`
	else
		USERS=`lsgroup $GROUP | awk -F\= '{print $3}' | cut -f 1 -d " " | awk -F, '{ for (x=1;x<=NF;x++) { print $(x) } }' | sort | awk '{ users=users$1"," } END { print users }'`
	fi

	print "ITCS,$HOST,DEV,$DIR,$GROUP,($USERS)"

	UFILES=`find $DIR \( $pubs \) ! type l -follow -perm -200 -exec ls -ld {} \; 2>/dev/null | wc -l`
	OFILES=`find $DIR ! -type l -follow -perm -2 -exec ls -ld {} \; | wc -l`
	EX=`find $DIR \( $EXC \) -type f -exec ls -ld {} \; | wc -l`
	SH=`find $DIR \( $SHL \) -type f -exec ls -ld {} \; | wc -l`
	print "ITCS,$HOST,CGI,$DIR,$UFILES,$OFILES,$EX,$SH"

done
