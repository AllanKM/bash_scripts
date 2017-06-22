#!/bin/ksh

		print "Reassembling XML"
		cat header.xmlpart > new_tmp.xml
		
		# now append all the vhosts. we need to remove duplicate entries while doing this
		
		for vhost in $( ls vhost_* ); do
			vhostgroupline=`grep -i "<virtualhostgroup" $vhost | sort | uniq`
			print "\t$vhostgroupline" >>new_tmp.xml
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
			urigroup=`ls urigroup_*_${cluster}_URIs.xmlpart`
			cat "$urigroup" >>new_tmp.xml
			cat "route_${cluster}.xmlpart" >>new_tmp.xml
		done
		cat trailer.xmlpart >>new_tmp.xml
		rm *.xmlpart
		
		print "validating XML syntax"
		perl -MXML::Parser -e "XML::Parser->new( ErrorContext => 3 )->parsefile(shift)" new_tmp.xml
		
