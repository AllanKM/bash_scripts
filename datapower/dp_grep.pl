#!/usr/local/bin/perl
#===============================================================================
# scan DP log for a timestamp range
#===============================================================================
use strict;
use Data::Dumper;
use warnings;
use constant debug => 0;
my $from;
my $to;
my $args=$#ARGV +1;

if ( $args > 0 ) {
   $from
        = `/opt/freeware/bin/date -d "$ARGV[0] minutes ago" +'%Y%m%dT%H%M00Z'`
        ;
   if ( $args > 1 ) {
      if ( $ARGV[1] > $ARGV[0] ) {
         print STDERR "To must be later than from\n";
         exit;
      }
      $to = `/opt/freeware/bin/date -d "$ARGV[1] minutes ago" +'%Y%m%dT%H%M00Z'`;
   }
   else {
      $to = `/opt/freeware/bin/date +'%Y%m%dT%H%M00Z'`;
   }
}
if ( $from ) {
   $from =~ s/^\s+|\s+$//g;
   $to   =~ s/^\s+|\s+$//g;
}
my $count   = 1;
my $context = 0;
print STDERR " from $from to $to\n" if $from;
while (<STDIN>) {
    if (m/\d{8}T\d{6}Z/) {
        my ($tm) = $_ =~ /(\d{8}T\d{6}Z)/;
        if ( ! $from || ( ( $tm cmp $from ) >= 0 && ( $tm cmp $to ) <= 0 ) ) {
            print $_;
            $context = $count;
        }
    }
    elsif ( $context > 0 ) {
        print $_;
        $context--;
    }
}
