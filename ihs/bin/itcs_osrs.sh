#!/bin/ksh
HOST=`hostname -s`

dirwrite() {
	FILE=$1
	if [[ -h $FILE ]]; then
		# get real directory
		FILE=`ls -ld $FILE | awk '{ print $(NF) }'`
		dirwrite $FILE
	fi
		
	WRITE=`ls -ld $FILE | awk '{ if ( substr($1,9,1) == "w" ) { print 1 } else {print 0} }'`
	return $WRITE
}

ROOT=`grep -i "^[[:space:]]*serverroot" /usr/HTTPServer/conf/httpd.conf | awk {'print $2'} | tr -d \" | sort | uniq`
INCLUDES=`grep -i "^[[:space:]]*include" /usr/HTTPServer/conf/httpd.conf | awk {'print $2'} | tr -d \" | sort | uniq`

for INC in $INCLUDES; do
   x=`print $INC | cut -c 1`
   if [[ $x != "/" ]]; then
      INC="$ROOT/$INC"
   fi
	if [[ -f $INC ]]; then
		INCFP="$INCFP $INC"
	fi
	INC=${INC%/*}
	if [[ -d $INC ]]; then
		CONFS="$CONFS $INC"
	fi
done
INCLUDES=$INCFP
CONFS=`print "$CONFS $ROOT/conf" | awk '{for (x=1;x<=NF;x++) {print $(x)}}' | sort | uniq`

#########################################################################################################
#  check config dirs not writeable by other
#########################################################################################################
print "checking config dirs"
for CONF in $CONFS; do
	DIR=${CONF%/*}
	dirwrite $DIR
	if [[ $? -gt  0 ]]; then
		print "$? $FILE is globally writable"
	fi

done

#########################################################################################################
# find logs directories, default is serverroot/logs
# check log dir not writeable by other
#########################################################################################################

LOGS=`grep logs /usr/HTTPServer/conf/httpd.conf | awk '{if ( tolower($0) ~ /customlog|errorlog/) { print $5 } else { print $2} } '`

for INC in $INCLUDES; do
	INCLOG=`grep -i logs $INC | awk '{if ( tolower($0) ~ /customlog|errorlog/) { print $5 } else { print $2} } '`
	LOGS="$LOGS $INCLOG"
done

rm /tmp/5_2_osr$$ >/dev/null 2>&1

for LOG in $LOGS; do
	if [[ -e $LOG ]]; then
		if [[ -f $LOG ]]; then
			LOG=${LOG%/*}
		fi
		print $LOG	>>/tmp/5_2_osr$$
	fi
done 

LOGS=`cat /tmp/5_2_osr$$ | sort | uniq`
print "Checking log dirs"
for LOG in $LOGS; do
	# Check for files where "other" has write 
	find $LOG -follow -perm 2 -exec ls -ld {} \;
done

#########################################################################################################
# find bin
#########################################################################################################
print "checking bin dir"
find $ROOT/bin -follow -perm 2 -exec ls -ld {} \;

#########################################################################################################
# find all loaded modules
#	find loadmodule in httpd.conf
#	find loadmodule in included confs
#########################################################################################################

MODULES=`cat /usr/HTTPServer/conf/httpd.conf | grep -i "^[[:space:]]*loadmodule" |grep -v "^[[:space:]]*#" | awk {'print $3'} | sort | uniq`

for INC in $INCLUDES; do
	INCMOD=`cat $INC | grep -i "^[[:space:]]*loadmodule" |grep -v "^[[:space:]]*#" | awk {'print $3'} | sort | uniq`
	MODULES="$MODULES $INCMOD"
done

rm /tmp/5_2_osr$$ >/dev/null 2>&1
print "checking module dirs"
for MOD in $MODULES; do
	if [[ $MOD != \/* ]]; then
		MOD="${ROOT}/${MOD}"
	fi
	if [[ -e $MOD ]]; then
		if [[ -f $MOD ]]; then
			MOD=${MOD%/*}
		fi
		print $MOD >>/tmp/5_2_osr$$
	fi
done

MODULES=`cat /tmp/5_2_osr$$ | sort | uniq`
# now check each module directory

for MOD in $MODULES; do
	# test if any mods have universal write
	find $MOD -perm -2 -exec ls -ld {} \; 
done

ACCESS=`find $ROOT -name "access.conf"`
print "checking access.conf"
for ACC in $ACCESS; do
	find $ACC -follow -perm -2 -exec ls -ld {} \;
done

# check httpd.conf and access.conf 
print "checking httpd.conf"
dirwrite /usr/HTTPServer/conf/httpd.conf
if [[ $? -gt 0 ]]; then
	print "httpd.conf is globally writeable"
fi
