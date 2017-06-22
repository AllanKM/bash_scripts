#!/bin/ksh

HOST=`hostname -s`

# ITSC104 rules - Section 5 block 3 - default access rules - optional

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

for CONF in $CONFS; do
	( awk -v HOST=$HOST '
	   tolower($0)~/<directory \/>/,tolower($0)~/<\/directory>/ {
	      order="order[[:blank:]]+deny[[:blank:]]*,[[:blank:]]*allow"
	      deny="deny[[:blank:]]+from[[:blank:]]+all"
	      options="options[[:blank:]]+none"
	      allowoveride="allowoverride[[:blank:]]none"
	      if ( tolower($0)~/<directory[[:blank:]]\/>/) {
	         dir[1]=0
	         dir[2]=0
	         dir[3]=0
	         dir[4]=0
	      }
	      if (tolower($0)~order) { dir[1]="1"}
	      if (tolower($0)~deny ) { dir[2]="1" }
	      if (tolower($0)~options) { dir[3]="1" }
	      if (tolower($0)~allowoveride) { dir[4]="1" }
	      if ( tolower($0)~/<\/directory>/) {
	         print "ITCS,"HOST",DAR,"FILENAME","dir[1]","dir[2]","dir[3]","dir[4]
	      }
	   }
	
	' $CONF ) | sort | uniq
done

