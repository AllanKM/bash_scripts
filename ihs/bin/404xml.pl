#!/usr/local/bin/perl -w

# 404 XML generation script

# This is a feeder script for the FourOhFour IRC bot as well as https://w3.ei.event.ibm.com/ei/apps/fourohfour.html
# It should be cron'd on v10062 with an entry like:
# 0,5,10,15,20,25,30,35,40,45,50,55 * * * * /path/to/404xml.pl cmwimb-even 5 2>&1 >> /fs/scratch/wwsmxml/404xml.log

# For this to work on the fourohfour webpage, each of the WEBSERVER.EI.PORTAL servers needs a symlink setting up beforehand e.g.:
# /projects/w3.ei.event.ibm.com/content/ei/apps/<event-year>.xml -> /fs/scratch/wwsmxml/<event-year>.xml

# Keith White/UK/IBM - June 2012

use strict;
use lib "/lfs/system/tools/ihs/lib";
use TivTask;
use Data::Dumper;

if ( `hostname` !~ /^v10062/g ) {
	print "This script must be run on v10062\n";
	exit;
}

if ( $< != 0 ) {
	print "This script needs to be run using sudo\n";
	exit;
}

unless ( $ARGV[0] ) {
	print "Usage: $0 <event> [minutes]\n\n";
	print "e.g. $0 cmwimb-even\n\n";
	print "[minutes] defaults to 5 if not specified\n\n";
	exit;
}

my $event = $ARGV[0];
my $minutes = ( $ARGV[1] ) ? $ARGV[1] : 5;

system("mkdir -p /fs/scratch/wwsmxml");
my $xml_file = "/fs/scratch/wwsmxml/$event.xml";
my $role     = uc("wwsm-${event}-webserver");
print localtime() . " : Starting 404 XML generation for $event looking at the last $minutes minutes\n";

# set up a new TivTask to run the qazl command across all the webservers
my $qazl = EI::TivTask->new(
							 cmd     => [&qazl],
							 role    => $role,
							 workdir => '/tmp'
);
print localtime() . " : Issuing qazl command against $role\n";
my (%results) = $qazl->execute();

sub qazl {
	my $cmd_name = "${event}_qazl_list_404.sh";
	return (
		$cmd_name, <<END_CMD
#!/bin/bash
/fs/system/bin/qazl project=$event code=404 count show=uri,referer sminago=$minutes
END_CMD
	);
}

# iterate through the results and populate a hash, we want totals by URL and not by referers
print localtime() . " : Creating xml file\n";
my %data;
foreach my $key (%results) {
	foreach my $stdout ( @{ $results{$key}->{'STDOUT'} } ) {
		chomp($stdout);
		my ( $num, $url, $referer ) = $stdout =~ /\s*(.*?) (.*?) "(.*?)"/g;
		$data{$url}{'total'} += $num;
		push @{ $data{$url}{'referers'} }, "\"$referer\"";
	}
}

# now we need to sort by the 404 counts ($data{$url}{'total'}) as the bot/webpage doesn't do any ordering
my %sorted;
my $topcount = 0;
foreach my $url ( keys %data ) {
	# the map is a clever way of stripping duplicates
	@{ $sorted{ $data{$url}{'total'} }{$url} } = keys %{ { map { $_ => 1 } @{ $data{$url}{'referers'} } } };
	$topcount++;
}

# start spitting out the XML
my $timestamp = `date`;
chomp($timestamp);
my $epoch = time();

open( my $fh, '>', $xml_file ) or die $!;

print $fh qq {<fourohfour>
   <event-tag>$event</event-tag>
   <event-role>$role</event-role>
   <minutes>$minutes</minutes>
   <topcount>$topcount</topcount>
   <timestamp>$timestamp</timestamp>
   <epoch>$epoch</epoch>

};

# order by count and spit out each entry stanza
foreach my $num ( reverse sort { $a <=> $b } keys %sorted ) {
	foreach my $url ( sort keys %{ $sorted{$num} } ) {
		my $referer = join( "\n", @{ $sorted{$num}{$url} } );
		print $fh qq{      <entry>
         <num>$num</num>
         <target><![CDATA[$url]]></target>
         <ref><![CDATA[$referer]]></ref>
      </entry>

}

	}
}

print $fh "</fourohfour>";
close $fh;

# so now let's spray the file out to where it's needed
# file exists on p1 gpfs in /gpfs/scratch/g/wwsmxml/ and needs to be placed on p3 gpfs /gpfs/scratch/b/wwsmxml/ for the ircbot
# it also then has to make it's way to WEBSERVER.EI.PORTAL in /gpfs/scratch/b/wwsmxml (the file should have a symlink in /projects/w3.ei.event.ibm.com/content/ei/apps/)
print localtime() . " : Distributing file to ircmaster and WEBSERVER.EI.PORTAL nodes:\n";

# find the p1 gpfs server
my $p1_gpfs = `lssys -qe role==GPFS.SERVER.SYNC realm==g.ei.p1`;
chomp($p1_gpfs);
my $distribute = EI::TivTask->new(
								   cmd     => [&distribute],
								   servers => $p1_gpfs,
								   workdir => '/tmp'
);
(%results) = $distribute->execute();

sub distribute {
	my $cmd_name = "${event}_distribute_404_xml.sh";
	return (
		$cmd_name, <<END_CMD
#!/bin/bash
P5GPFS=`lssys -qe role==GPFS.SERVER.SYNC realm==g.ei.p5`
P3GPFS=`lssys -qe role==GPFS.SERVER.SYNC realm==g.ei.p3`
chmod 664 /gpfs/scratch/g/wwsmxml/$event.xml
# throw it to ircmaster's GPFS
scp /gpfs/scratch/g/wwsmxml/$event.xml \$P3GPFS:/gpfs/scratch/b/wwsmxml/
# now spray it out to WEBSERVER.EI.PORTAL
# p5
ssh \$P5GPFS mkdir -p /gpfs/scratch/b/wwsmxml 
scp -p /gpfs/scratch/g/wwsmxml/$event.xml \$P5GPFS:/gpfs/scratch/b/wwsmxml/
# p1
mkdir -p /gpfs/scratch/b/wwsmxml
cp -p /gpfs/scratch/g/wwsmxml/$event.xml /gpfs/scratch/b/wwsmxml/
# p3
ssh \$P3GPFS mkdir -p /gpfs/scratch/b/wwsmxml
scp -p /gpfs/scratch/g/wwsmxml/$event.xml \$P3GPFS:/gpfs/scratch/b/wwsmxml/
END_CMD
	);
}

# just in case we have any STDERR - useful to throw to a log when cron'd so we at least know something's happening
print Dumper(%results);
print localtime() . " : Done.\n\n";
