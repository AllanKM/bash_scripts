#!/usr/local/bin/perl -w
use strict;
use FindBin;
use lib ("/$FindBin::Bin", "/$FindBin::Bin/lib", "/$FindBin::Bin/../lib", "/lfs/system/tools/configtools/lib");
use dp_functions;
use Data::Dumper;
my $ignore_list = qr/TCP\sconnection\sattempt|
      LDAP\sauthentication:\sCould\snot\sbind|
      logged\s(?:out|into)|
      failed\sto\slog\sin|
      RBM:\sAuthentication\sfailed|
      could\snot\sestablish\sSSL\sfor\sincoming\sconnection|
      illegal\schar|
      peer\sdid\snot\ssend\sa\scertificate|
      Error\sparsing\sresponse|
      \[mgmt\]\[error\].*SNMP|
      default\srule|
      Compilation\swarning:|
      mismatched|
      compiling|
      target\(eci-log\):/ix;
my ($serverlist, $attrs) = parseParms(\@ARGV);
my $dp_user = get_dp_user($serverlist);

foreach my $server (sort @$serverlist) {
   my $domain = ei_domain($server);
   eval { viewlog($dp_user, $server, 'default', 'logtemp:///default-log', $attrs); };
   eval { viewlog($dp_user, $server, $domain,   'logtemp:///default-log', $attrs); };
}

sub viewlog {
   my ($dp_user, $server, $domain, $file, $attrs) = @_;
   my $filedata = getFile($dp_user, $server, $domain, $file, $attrs);

   #   my $filedata=`cat p2dpa03_defaultDomain.20140923071554`;
   # Domain configuration has been saved
   # Configuration saved successfully
   my ($start_date, $start_time) = $filedata =~ /(\d{8})T(\d{6})Z/is;
   my ($end_date,   $end_time)   = $filedata =~ /.*(\d{8})T(\d{6})Z/is;
   my $lastpos;
   if (!$attrs->{'f'}) {
      while ($filedata =~ /(?:Domain configuration has been modified|Configuration saved successfully)/gis) {
         $lastpos = $-[0] if $-[0] > 0;
      }
      $filedata = substr($filedata, $lastpos) if $lastpos;
   }
   $SIG{PIPE} = 'IGNORE';

   #***********************************
   # add server/domain/log details
   #***********************************
	my $f;
	my $localfile;
	if ( $attrs->{'s'} ) {
		my $localfile=$file;
		$localfile=~s/^.*\/\/\///;
		$localfile="${server}_${domain}_${localfile}";
		print STDERR "saving ${localfile}\n";
		open($f,'>',"${localfile}") or die "error ! $!\n";;
	}
	else {
		open( $f, '|-', 'less');
	}
   print $f "*" x 60 . "\n   $server $domain $file \n";
   printf $f "   %04d-%02d-%02d %02d:%02d:%02d to %04d-%02d-%02d %02d:%02d:%02d\n",
     substr($start_date, 0, 4), substr($start_date, 4, 2), substr($start_date, 6, 2),
     substr($start_time, 0, 2), substr($start_time, 2, 2), substr($start_time, 4, 2),
     substr($end_date,   0, 4), substr($end_date,   4, 2), substr($end_date,   6, 2),
     substr($end_time,   0, 2), substr($end_time,   2, 2), substr($end_time,   4, 2);
   if ($lastpos) {
      print $f "    truncated at last write mem \n";
   }
   if (!$attrs->{'f'}) {
      print $f "    filtered results use -f to see full log\n";
   }
   print $f "*" x 60 . "\n";
   foreach my $line (split(/\n/, $filedata)) {
      if ($attrs->{'f'}) {
         print $f "$line\n";
      }
      elsif ($line !~ $ignore_list) {
         eval { print $f "$line\n" };
      }
   }
   close $f or die "Cant close less $!";
   return;
}
