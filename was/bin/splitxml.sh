#!/bin/ksh

master_xml=$1

if [ ! -f "$master_xml" ]; then
	print "Syntax: splitxml.sh plugin_cfg_xml_file_name"
	print "\nSplits each stanza in plugin_cfg.xml into seperate files"
	print "each file is named the same as the stanza and suffixed with .xmlpart"
	print "to remove stanzas just erase the files and run joinxml.sh to "
	print "create new_tmp.xml"
	exit
fi

# This awk split the individual stanzas of the plugin files into seperate files.
# As the new plugin is processed second any duplicate entries will replace the
# ones in the first file. Except in the case of vhost stanzas where the contents of
# both the first and second file are concatenanted. It also takes the first keyring
# file found in the first file and makes all other keyring/stash entries have the same 
# value
#
rm *.xmlpart 1>/dev/null 2>/dev/null

print "disassembling XML"
awk -v IGNORECASE=1 '
		tolower($0)~/<log / {
			print "\t<Log LogLevel=\"Error\" Name=\"/logs/HTTPServer/Plugins/http_plugin.log\"/>" >> outfile
			next
		}
		tolower($0)~/keyring/ {
			if ( ! keyring ) {
				x=index($0,"value=")+7
				keyring=substr($0,x)
				x=index(keyring,"\"")-1
				keyring=substr(keyring,1,x)
			}
			sub(/value=\".*\"/,"Value=\""keyring"\"")
		}
		tolower($0)~/stashfile/ {
			sub(/value=\".*\"/,"Value=\""keyring"\"")
			sub(/\.kdb/,".sth")
		}
		tolower($0)~/<virtualhostgroup/ {
			x=index($0,"Name=")+6
			file=substr($0,x)
			x=index(file,"\"")-1
			outfile="vhost_"substr(file,1,x)".xmlpart"
			
			if ( vhosts[outfile] ) { overwrite=0 }
			else { overwrite=1 }
			
			vhosts[outfile]=1
		}
		tolower($0)~/<servercluster/ {
			overwrite=1
			x=index($0,"Name=")+6
			file=substr($0,x)
			x=index(file,"\"")-1
			outfile="cluster_"substr(file,1,x)".xmlpart"
		}
		tolower($0)~/<urigroup/ {
			overwrite=1
			x=index($0,"Name=")+6
			file=substr($0,x)
			x=index(file,"\"")-1
			outfile="urigroup_"substr(file,1,x)".xmlpart"
		}
		tolower($0)~/<route/ {
			overwrite=1
			x=index($0,"ServerCluster=")+15
			file=substr($0,x)
			x=index(file,"\"")-1
			outfile="route_"substr(file,1,x)".xmlpart"
		}
		tolower($0)~/<requestmetrics/ {
			overwrite=1
			if ( trailer_done ) { outfile="/dev/null" }
			else { outfile="trailer.xmlpart" }
			trailer_done = 1
		}	
		{
			if ( FNR==1 ) {
				if ( header_done ) { outfile = "/dev/null" }
				else { outfile = "header.xmlpart" }
				overwrite=1
				header_done=1
				print "\t"FILENAME
			}
 
			if (overwrite) {
				close(outfile)
				print $0 > outfile 
				overwrite=0
			}
			else {
				print $0 >> outfile 
			}
		}' $master_xml 
		
