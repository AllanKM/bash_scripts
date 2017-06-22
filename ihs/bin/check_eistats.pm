#!/usr/local/bin/perl

# Description: Uses the values of the ei-stats module to determine error rate
#
# Usage
#   chk_eistats.pm

use lib "/lfs/system/tools/ihs/lib";
use url;
use Data::Dumper;

my $DEBUG = 0; # Set to 1 if you want to see debug on STDOUT
my $url =  'http://127.0.0.1/ei-stats';
if ( defined $ARGV[0] ) {
   $url = 'http://'.$ARGV[0].'/ei-stats';
}

$check = new url(
   {
    name => 'EI_Stats',
    url => $url,
    debug => $DEBUG,
    max_errors => 10,
    min_access => 10,
    interval => 7,
   } 
);

if ( $check->get_ei_stats() ) {
  print "\tError percentage OK", $check->error(), "\n";
} else {
  print "####Check of web server errors indicates problem: ", $check->error(), "\n";
}


