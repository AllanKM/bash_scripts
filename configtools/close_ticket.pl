#!/usr/local/bin/perl -w
use strict;
use Data::Dumper;
use FindBin;
use lib (
          "/$FindBin::Bin/lib",       "/$FindBin::Bin/../lib",
          "/$FindBin::Bin/../../lib", "$FindBin::Bin",
          "/lfs/system/tools/configtools/lib"
);
use EI::Impact::session;

#--------------------------------------------------------------------------------------------
# Close Impact ticket
# 1. Login to Impact
# 2 search for ticket
# 3. Get ticket to be closed
# 4. set completion code EA
# 5. Add a closed task
#--------------------------------------------------------------------------------------------
my $impact = EI::Impact::session->new( SITE => 'test' );
my ( $resolution, $cause );
my $ticket = shift @ARGV;
if ( !defined $ticket || $ticket !~ /resh[crip]\d+/i ) {
   print "$ticket is an invalid ticket number\n" if defined $ticket;
   print "Missing ticket number\n"               if !defined $ticket;
   syntax();
   exit 4;
} ## end if ( !defined $ticket ...)
my $close_code = shift @ARGV;
if ( !defined $close_code ) {
   print "Missing Close code\n";
   syntax();
   exit 4;
}
if ( $ticket =~ /resh[ip]/i ) {
   $resolution = shift @ARGV;
   if ( !defined $resolution ) {
      print "Missing Resolution code\n";
      syntax();
      exit 4;
   }
   $cause = shift @ARGV;
   if ( !defined $cause ) {
      print "Missing Cause code\n";
      syntax();
      exit 4;
   }
} ## end if ( $ticket =~ /resh[ip]/i)
my $text = shift @ARGV;
if ( !defined $text ) {
   print "Missing Text\n";
   syntax();
   exit 4;
}
if (@ARGV) {
   print "Too many parms.....\n";
   syntax();
   exit 4;
}
if ( $impact->login ) {
   $impact->debug( $ENV{'debug'} ) if defined $ENV{'debug'};
   if (
        $impact->close_ticket(
                               TICKET          => $ticket,
                               CLOSE_CODE      => $close_code,
                               RESOLUTION_CODE => $resolution,
                               CAUSE_CODE      => $cause,
                               TEXT            => $text,
        )
     ) {
      print "$ticket closed\n";
   } ## end if ( $impact->close_ticket...)
} ## end if ( $impact->login )
else {
   exit 4;
}

sub syntax {
   print <<ENDCOMMON;
   
   Syntax:
   
ENDCOMMON
   if ( !defined $ticket || $ticket =~ /resh[rc]/i ) {
      print <<ENDCR
     for RESHC/R tickets 
     $0 <ticket> <close code> "<text for close task>"
     
ENDCR
   } ## end if ( !defined $ticket ...)
   if ( !defined $ticket || $ticket =~ /resh[ip]/i ) {
      print <<ENDI
     for RESHI tickets
     $0 <ticket> <close code> <resolution code> <cause code> "<text for close and resolved task>"
ENDI
   } ## end if ( !defined $ticket ...)
} ## end sub syntax
