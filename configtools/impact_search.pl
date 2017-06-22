#!/usr/local/bin/perl -w
use strict;
use lib ".";
use FindBin;
use lib (
          "/$FindBin::Bin/lib",       "/$FindBin::Bin/../lib",
          "/$FindBin::Bin/../../lib", "$FindBin::Bin",
          "/lfs/system/tools/configtools/lib"
);
use EI::Impact::session;
use Date::Manip;
use Data::Dumper;
use Term::ANSIColor;
use Term::ANSIColor qw(:constants);
use MIME::Lite;

#======================================================
# Start of main code, parse command line parms
#======================================================
my $search = join( ' ', @ARGV ) || $ENV{'search'};
if ( !defined $search ) {
   print "Must set search string before calling e.g.\n SEARCH=\"ITCS104\" impact_search.sh\n";
   exit;
}
$search =~ s/\*//g;
$search = "*" . $search . "*";    # what to look for
my $title = $ENV{'title'} || "Impact search for $search";
my $session = EI::Impact::session->new( SITE => $ENV{site} );
$session->debug( $ENV{'debug'} ) if defined $ENV{'debug'};
my $mailmsg;
if ( $session->login() ) {
   my @srlist = $session->search( TEXT => $search );    # find all tickets containing the search arg
   @srlist = grep { $_->{'Request#'} =~ /(?:reshr|reshc)/i } @srlist;    # just want RESHR or RESHC
   if ( !@srlist ) {
      print "No tickets found matching $search\n";
      exit;
   }
   my $c = scalar @srlist;
   my $i = 1;
   my @rows;

   #============================================================================
   # Perform Impact lookups and create array of ticket details
   #============================================================================
   foreach my $sr (@srlist) {
      printf "%s; %s; %s; %s; %s;\n",
         $sr->{'Request#'},
         $sr->{'Status'},
         $sr->{'Activity Level'},
         $sr->{'Assigned To'},
         $sr->{'Details'}
         ;
   } ## end foreach my $sr (@srlist)

} ## end if ( $session->login)

#==========================================================
# Sort by complete by date, then ticket number
#==========================================================
sub mysort {
   if ( $a->[2] eq $b->[2] ) {    # rows have same date so sort on ticket number
      return $a->[0] cmp $b->[0];
   }
   else {
      return $a->[2] cmp $b->[2];
   }
} ## end sub mysort
