#!/usr/local/bin/perl -w
#============================================
# $Revision: 1.1 $
# Author: Steve Farrell
#============================================
use strict;
use FindBin;
use lib ("/$FindBin::Bin", "/$FindBin::Bin/lib", "/$FindBin::Bin/../lib", "/lfs/system/tools/configtools/lib");
use Data::Dumper;
use dp_functions;
my ($serverlist, $attrs) = parseParms(\@ARGV);
my $dp_user = get_dp_user($serverlist);

foreach my $server (sort @$serverlist) {
my $custs = {};
   my $domain = ei_domain($server);
   $domain = 'default';
   my $filedata = getFile($dp_user, $server, $domain, 'logtemp:///default-log', $attrs);
   my $lastpos;
   if (!$attrs->{'f'}) {
      while ($filedata =~ /(?:Domain configuration has been modified|Configuration saved successfully)/gis) {
         $lastpos = $-[0] if $-[0] > 0;
      }
      $filedata = substr($filedata, $lastpos) if $lastpos;
   }
   my ($start_date, $start_time) = $filedata =~ /(\d{8})T(\d{6})Z/is;
   my ($end_date,   $end_time)   = $filedata =~ /.*(\d{8})T(\d{6})Z/is;
   $start_date = sprintf "%04d-%02d-%02d", substr($start_date, 0, 4), substr($start_date, 4, 2), substr($start_date, 6, 2);
   $start_time = sprintf "%02d:%02d:%02d",
     substr($start_time, 0, 2), substr($start_time, 2, 2), substr($start_time, 4, 2),
     $end_date = sprintf "%04d-%02d-%02d",
     substr($end_date, 0, 4), substr($end_date, 4, 2), substr($end_date, 6, 2);
   $end_time = sprintf "%02d:%02d:%02d", substr($end_time, 0, 2), substr($end_time, 2, 2), substr($end_time, 4, 2);
   print "Server: ${server} incoming requests from $start_date $start_time to $end_date $end_time\n";
   foreach my $line (split(/\n/, $filedata)) {

      #      *** RECEIVED ECI REQUEST [616P47L8VT] FROM [Unisys]
      if ($line =~ /RECEIVED ECI REQUEST.+?FROM\s*\[(\w+)\]/i) {
         $custs->{$1}++;
      }
   }
   foreach my $key (sort { "\L$a" cmp "\L$b" } keys %$custs) {
      printf "\t %03d %s\n", $custs->{$key}, $key;
   }
}
