#!/bin/ksh
HOST=`hostname -s`
OS=`uname -s`
GROUPS=`grep -i "^%.* ALL" /etc/sudoers | tr -d \% | awk '{print $1}'`
for GROUP in $GROUPS; do
	if [[ $OS = "Linux" ]]; then
		USERS=`grep $GROUP /etc/group | awk -F\: '{print $4}' | cut -f 1 -d " " | awk -F, '{ for (x=1;x<=NF;x++) { print $(x) } }' | sort | awk '{ users=users$1"," } END { print users }'`
	else
		USERS=`lsgroup $GROUP |  awk '{ x=index($0,"users=");y=substr($0,x); z=index(y," "); print substr(y,7,z-7) }' | awk -F, '{ for (x=1;x<=NF;x++) { print $(x) } }' | sort | awk '{ users=users$1"," } END { print users }'`
	fi
	print "ITCS,$HOST,ADM,$GROUP,($USERS)"
done

for ADMIN in $admin_groups; do
	admins="$admins ! -group $ADMIN"
done
ROOT=`grep -i "^[[:space:]]*serverroot" /usr/HTTPServer/conf/httpd.conf | awk {'print $2'} | tr -d \" | sort | uniq`
DOCROOT=`grep -i "^[[:space:]]*Documentroot" /usr/HTTPServer/conf/httpd.conf | awk {'print $2'} | tr -d \" | sort | uniq`
INCLUDES=`grep -i "^[[:space:]]*include" /usr/HTTPServer/conf/httpd.conf | awk {'print $2'} | tr -d \" | sort | uniq`

for INC in $INCLUDES; do
	x=`echo $INC | cut -c 1`
	if [[ $x != "/" ]]; then
		INC="$ROOT/$INC"
	fi
	if [[ -f $INC ]]; then
		INCROOT=`grep -i "^[[:space:]]*documentroot" $INC | awk {'print $2'} | sort | uniq`
		DOCROOT="$DOCROOT $INCROOT"
	fi
done

for DIR in $DOCROOT; do
	OWNER=`ls -ld $DIR | awk '{print $4}'`

	if [[ $OS = "Linux" ]]; then
		USERS=`grep $OWNER /etc/group | awk -F\: '{print $4}' | cut -f 1 -d " " | awk -F, '{ for (x=1;x<=NF;x++) { print $(x) } }' | sort | awk '{ users=users$1"," } END { print users }'`
	else
		USERS=`lsgroup $OWNER |  awk '{ x=index($0,"users=");y=substr($0,x); z=index(y," "); print substr(y,7,z-7) }' | awk -F, '{ for (x=1;x<=NF;x++) { print $(x) } }' | sort | awk '{ users=users$1"," } END { print users }'`
	fi
	print "ITCS,$HOST,AUT,$DIR,$OWNER,($USERS)"
done

IHSID=`grep -i "^[[:space:]]*user" /usr/HTTPServer/conf/httpd.conf | grep -v "^[[:space:]]*#" | awk {'print $2'} | tr -d \" | sort | uniq`
ID=`id $IHSID`
print "ITCS,$HOST,WID,$ID"
