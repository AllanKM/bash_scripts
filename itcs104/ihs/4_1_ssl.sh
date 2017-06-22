#!/bin/ksh

HOST=`hostname -s`

ROOT=`grep -i "^[[:space:]]*serverroot" /usr/HTTPServer/conf/httpd.conf | awk {'print $2'} | tr -d \" | sort | uniq`
DOCROOT=`grep -i "^[[:space:]]*Documentroot" /usr/HTTPServer/conf/httpd.conf | awk {'print $2'} | tr -d \" | sort | uniq`
INCLUDES=`grep -i "^[[:space:]]*include" /usr/HTTPServer/conf/httpd.conf | awk {'print $2'} | tr -d \" | sort | uniq`
i=0
for INC in $INCLUDES; do
	x=`print $INC | cut -c 1`
	if [[ $x != "/" ]]; then
		INC="$ROOT/$INC"
	fi
	if [[ -f $INC ]]; then
		awk -v HOST=$HOST 'tolower($0)~ /virtualhost.+:443/, tolower($0) ~ /\<\/virtualhost/ { 
			if ( tolower($0) ~ /<virt/ ) {
				vhost=$0
			}; 
			if (tolower($0)~ /sslenable/) {
				print "ITCS,"HOST",SSL,"vhost","$0
			}
		 }' $INC

		CERT=`awk 'tolower($0)~ /virtualhost.+:443/, tolower($0) ~ /\<\/virtualhost/ { 
			 if (tolower($0)~ /sslservercert/) {
					print $0
					exit
				} 
			}' $INC `
		if [ ! -z "$CERT" ] ; then
			CERTS[$i]=$(print $CERT | cut -d" " -f2-10)
			i=$((i+1))
		fi
	fi
done
# now list certificateS

KDB=`grep -i "^[[:space:]]*keyfile" /usr/HTTPServer/conf/httpd.conf | awk {'print $2'} | tr -d \"`
if [ -z "$KDB" ]; then
	for INC in $INCLUDES; do
		KDB=`grep -i "^[[:space:]]*keyfile" $INC | awk {'print $2'} | tr -d \"`
	done
fi
if [ -z "$KDB" ]; then
	print "ITCS,$HOST,CRT,Missing cert file"
	exit
fi
STH="${KDB%\.*}.sth"
KDBPW=`/lfs/system/tools/itcs104/ihs/get_kdb_pw.pl $STH`
j=0
while [ $j -lt $i ]; do
	CERT=${CERTS[$j]}
	j=$((j+1))
	JAVA_HOME=/usr/HTTPServer/java/jre gsk7cmd -cert -details -db $KDB -pw $KDBPW -label "$CERT" | 
		awk -v HOST=$HOST 'BEGIN {
			ORS=",";
			print "ITCS,"HOST",CRT"
		};
		/^Label:/ { 
			print $2
		};
		/^Issued By/ { 
			for (x=3;x<=NF;x++) { 
				auth=auth$(x)" " 
			} 
			print auth
		}; 
		/Subject:/ { 
			print $2 
		}; 
		/Valid From:/ { 
			ORS="";
			gsub(/,/,"")
			if ($4 == "January" ) { print "01/" }
			if ($4 == "February" ) { print "02/" }
			if ($4 == "March" ) { print "03/" }
			if ($4 == "Aprilr" ) { print "04/" }
			if ($4 == "May" ) { print "05/" }
			if ($4 == "June" ) { print "06/" }
			if ($4 == "July" ) { print "07/" }
			if ($4 == "August" ) { print "08/" }
			if ($4 == "September") { print "09/" }
			if ($4 == "October" ) { print "10/" }
			if ($4 == "November" ) { print "11/" }
			if ($4 == "December" ) { print "12/" }
    		printf "%02s/%4s,",$5,$6
			print $7","
			if ($12 == "January" ) { print "01/" }
			if ($12 == "February" ) { print "02/" }
			if ($12 == "March" ) { print "03/" }
			if ($12 == "Aprilr" ) { print "04/" }
			if ($12 == "May" ) { print "05/" }
			if ($12 == "June" ) { print "06/" }
			if ($12 == "July" ) { print "07/" }
			if ($12 == "August" ) { print "08/" }
			if ($12 == "September") { print "09/" }
			if ($12 == "October" ) { print "10/" }
			if ($12 == "November" ) { print "11/" }
			if ($12 == "December" ) { print "12/" }
    		printf "%02s/%4s,",$13,$14
			print $15"\n"
			
			ORS="," 
		}
		END {print "\n"}'

done
