#!/bin/ksh

if [[ $# -lt 2 ]]; then
	print "Syntax: merge_plugin.sh master_plugin.xml update1_plugin.xml update2_plugin.xml ..."
	print "the master and update xmls must all be in the current directory"
	print "\nOutput is written to new_tmp.xml"
	print "the script will also do the following actions"
	print "\tremove virtualhosts with format *:nnnn"
	print "\tset all keyrings to be the same as the first keyring found in the original xml"
	print "\tremove duplicate vhost port definitions"
	exit
fi

if [ ! -f $1 ]; then
	print "$1 does not exist"
	exit
fi

if [ ! -f $2 ]; then
	print "$2 does not exist"
	exit
fi
rm -rf xml_merge 2>/dev/null
mkdir xml_merge 2>/dev/null
master_xml=$1
shift
new_xml=$@

# This awk split the individual stanzas of the plugin files into seperate files.
# As the new plugin is processed second any duplicate entries will replace the
# ones in the first file. Except in the case of vhost stanzas where the contents of
# both the first and second file are concatenanted. It also takes the first keyring
# file found in the first file and makes all other keyring/stash entries have the same 
# value
#
print "disassembling XML"
awk -v IGNORECASE=1 -v vhost="$vhost" ' 
		function repeat(string,count) {
			result=""
			while (count-->0) result= result string;
			return result
		}
		function f_print(string,outfile) {
			gsub(/^[[:space:]]*/,"",string)					# remove existing leading whitespace

			if ( string~/^<\// ) {								# </xxxxx>	end of stanza reduce tabs for next lines
				tabs--
			}
			if ( overwrite ) {
				print repeat("\t",tabs) string > outfile
				overwrite=0
			}
			else {
				print repeat("\t",tabs) string >> outfile
			}
			if ( string~/^<[^!\?\/].*[^\/]>/ ) {				# <xxxx xxxx > start of stanza increase tabs
																		# does not match on
																		# <?.....>
																		# <!....>
																		# <..../>
				tabs++
			}
		}
		tolower($0)~/<log / {
			f_print( "<Log LogLevel=\"Error\" Name=\"/logs/HTTPServer/Plugins/http_plugin.log\"/>" , outfile )
			next
		}
		tolower($0)~/keyring/ {
			if ( ! keyring ) {
				x=index($0,"Value=")+7
				keyring=substr($0,x)
				x=index(keyring,"\"")-1
				keyring=substr(keyring,1,x)
			}
			sub(/Value=\".*\"/,"Value=\""keyring"\"")
		}
		tolower($0)~/stashfile/ {
			sub(/Value=\".*\"/,"Value=\""keyring"\"")
			sub(/\.kdb/,".sth")
		}
		tolower($0)~/virtualhost.*\"\*:[0-9]{4}/ { 
				next
		}
		tolower($0)~/<virtualhostgroup/ {
			close(outfile)
			x=index($0,"Name=")+6
			file=substr($0,x)
			x=index(file,"\"")-1
			outfile="xml_merge/vhost_"substr(file,1,x)".xmlpart"
			
			if ( vhosts[outfile] ) { overwrite=0 }
			else { overwrite=1 }
			
			vhosts[outfile]=1
		}
		tolower($0)~/<servercluster/ {
			close(outfile)
			overwrite=1
			x=index($0,"Name=")+6
			file=substr($0,x)
			x=index(file,"\"")-1
			outfile="xml_merge/cluster_"substr(file,1,x)".xmlpart"
		}
		tolower($0)~/<urigroup/ {
			close(outfile)
			overwrite=1
			x=index($0,"Name=")+6
			file=substr($0,x)
			x=index(file,"\"")-1
			outfile="xml_merge/urigroup_"substr(file,1,x)".xmlpart"
		}
		tolower($0)~/<route/ {
			close(outfile)
			overwrite=1
			x=index($0,"UriGroup=")+10
			file=substr($0,x)
			x=index(file,"\"")-1
			outfile="xml_merge/route_"substr(file,1,x)".xmlpart"
		}
		tolower($0)~/<requestmetrics/ {
			close(outfile)
			overwrite=1
			if ( trailer_done ) { outfile="/dev/null" }
			else { outfile="xml_merge/trailer.xmlpart" }
			trailer_done = 1
		}	
		{
			if ( FNR==1 ) {
				if ( header_done ) { outfile = "/dev/null" }
				else { outfile = "xml_merge/header.xmlpart" }
				overwrite=1
				header_done=1
				print "\t"FILENAME
			}
 
			if (overwrite) {
				close(outfile)
				f_print($0,  outfile )
			}
			else {
				f_print($0, outfile )
			}
		}' $master_xml $new_xml
		
		# now we just put it all back together
		cd xml_merge
		print "Reassembling XML"
		cat header.xmlpart > new_tmp.xml
		
		# now append all the vhosts. we need to remove duplicate entries while doing this
		
		for vhost in $( ls vhost_* ); do
			vhostgroupline=`grep -i "<virtualhostgroup" $vhost | sort -bu`
			print "$vhostgroupline" >>new_tmp.xml
			cat $vhost | grep -iv "virtualhostgroup" | sort | uniq >>new_tmp.xml
			print "\t</VirtualHostGroup>" >>new_tmp.xml
		done
		
		for cluster in $( ls cluster_* ); do
			cat $cluster >>new_tmp.xml
			cluster=`echo $cluster | awk -v IGNORECASE=1 '{ 
				sub(/cluster_/,"");
				sub(/.xmlpart/,"");
				print 
				}'`
			urigroups=`ls urigroup_*_${cluster}_URIs.xmlpart 2>/dev/null`
			#print $urigroup
			for urigroup in $urigroups; do
					cat "$urigroup" >>new_tmp.xml
			done
			routes=`ls route_*_${cluster}_URIs.xmlpart 2>/dev/null`
			for route in $routes; do
				cat "$route" >>new_tmp.xml
			done
		done
		cat trailer.xmlpart >>new_tmp.xml
		master_xml=${master_xml##*/}
		mv new_tmp.xml ../merged_$master_xml   
	   cd ..	
		rm -rf xml_merge
		print "merged_$master_xml created - validating XML syntax"
		perl -MXML::Parser -e "XML::Parser->new( ErrorContext => 3 )->parsefile(shift)" merged_$master_xml
		
