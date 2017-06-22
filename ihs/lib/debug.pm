#==============================================================================================
# Revision : $Revision: 1.1 $
# Source   : $Source: /cvsroot/hpodstools/lfs_tools/ihs/lib/debug.pm,v $
# Date     : $Date: 2012/05/16 14:00:36 $
#
# $Log: debug.pm,v $
# Revision 1.1  2012/05/16 14:00:36  steve_farrell
# Install new IHS ITCS104 scanning scripts
#
# Revision 1.3  2012/03/08 12:02:35  stevef
# Detect if running on console and only colour msgs if true
#
# Revision 1.2  2012/03/07 09:48:33  stevef
# remove linefeed from msg 
#
# Revision 1.1  2012/03/07 09:21:25  steve
# Initial revision
#
#==============================================================================================
#!/usr/local/bin/perl -w
package debug;
use Term::ANSIColor;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

use Exporter;        # load Exporter module
use vars qw(@ISA @EXPORT @EXPORT_OK);
@ISA=qw(Exporter);   # Inherit from Exporter
@EXPORT_OK=qw();     # symbols exported on request
@EXPORT=qw(debug);

#================================================
# Format and print debugging info
#================================================
#--------------------------------------------------------
# Print debugging information
#--------------------------------------------------------
sub debug {
   my ($msg) = @_;
   if ( $ENV{'debug'} ) {
      $msg = '' if !$msg;
      chomp $msg;
      my $line     = ( caller(0) )[2];
      my $calledby = "Main";
      if ( ( defined( scalar caller(1) ) ) ) {
         $calledby = ( caller(1) )[3];
         $calledby =~ s/^.+?:://;
      }
      if ( -t STDERR ) {                              # only colour msgs if running from console
         print STDERR YELLOW "$line:$calledby: ";
         print STDERR CYAN "$msg\n";
      }
      else {
         print STDERR "$line:$calledby: ";
         print STDERR "$msg\n";
      }
   }
}
1;
