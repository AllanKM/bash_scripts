#!/bin/ksh
HOST=`hostname -s`

IHS_ID=`grep -i "^[[:space:]]*user[[:space:]]" /usr/HTTPServer/conf/httpd.conf | awk {'print $2'}`
IHS_GROUP=`grep -i "^[[:space:]]*group[[:space:]]" /usr/HTTPServer/conf/httpd.conf | awk {'print $2'}`
ROOT=`grep -i "^[[:space:]]*serverroot" /usr/HTTPServer/conf/httpd.conf | awk {'print $2'} | sort | uniq`
INFO=`ls -ld $ROOT`

OWNER=`print $INFO | awk '{print $3}'`
GROUP=`print $INFO | awk '{print $4}'`
OTHER=`print $INFO | awk '{print substr($1,9,1)}'`
if [[ $OTHER = "w" ]]; then 
	GLOBAL_WRITE=1
else
	GLOBAL_WRITE=0
fi
print "ITCS,$HOST,SVR,$ROOT,$GLOBAL_WRITE"

###############################
# Document root access rights
###############################
DOCROOT=`grep -i "^[[:space:]]*Documentroot" /usr/HTTPServer/conf/httpd.conf | awk {'print $2'} | tr -d \" | sort | uniq`
INCLUDES=`grep -i "^[[:space:]]*include" /usr/HTTPServer/conf/httpd.conf | awk {'print $2'} | tr -d \" | sort | uniq`

for INC in $INCLUDES; do
	x=`print $INC | cut -c 1`
	if [[ $x != "/" ]]; then
		INC="$ROOT/$INC"
	fi
	if [[ -f $INC ]]; then
		INCROOT=`grep -i "^[[:space:]]*Documentroot" $INC | awk {'print $2'} | sort | uniq`
		DOCROOT="$DOCROOT $INCROOT"
	fi
done

for ROOT in $DOCROOT; do
	# find files where webserver id, or group webserver id is a member of, has write access or
	# file has global write

	BAD_FILES=`find $ROOT \( -type d -o -type f \) \(  \( -perm 200 \( -user $IHS_ID -o -group $IHS_GROUP \) \)  -o \( -perm -2 \) \)	-exec ls -ld {} \; 2>/dev/null | wc -l`
	print "ITCS,$HOST,DOC,$ROOT,$BAD_FILES"
done
