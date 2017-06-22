#!/usr/bin/perl

###############################################################################
# Script Name - socketCheck.pl
# Auther - Chris Kalamaras
# Purpose - This script will check connectivity to a host:port combination
#           The script will take host and port parameters specified at command line
#
#           USAGE: ./socketCheck.pl -h <host or ip> -p <port>
###############################################################################

use IO::Socket;
use Getopt::Std;
use Net::hostent;


# "$timeOut" - sets timeout interval for socket connection.  Default is 15 seconds
$timeout = "15";

sub sock_conn {
  my ($myServer, $myPort) = @_;
  chomp $myServer;
  chomp $myPort;
  if (gethostbyname($myServer) == undef) {
    print "Hostname \"$myServer\" unknown.\n";
    exit;
  }
  $sock = IO::Socket::INET->new(
                PeerAddr => $myServer,
                PeerPort => $myPort,
                Proto    => 'tcp',
                Timeout  => $timeout);
  close($sock);
  if ($sock == undef){
    $myStatus = 0;
  } else {
    $myStatus = 1;
  }
  return($myStatus);
}

################ MAIN SECTION ##############

getopts('h:p:');

$myStatus = 1;
my $myServer = $opt_h, $myPort = $opt_p;

if (!($opt_h && $opt_p)) {
  print "\n";
  print "   USAGE: $0 -h <host or ip> -p <port>\n";
  exit;
}

$Output =  &sock_conn($myServer, $myPort);

if ($Output == 0) {
#   print "Cannot connect to port $myPort on $myServer ==>> FAILURE\n";
     die "Cannot connect to port $myPort on $myServer!\n";
} elsif ($Output == 1) {
    print "OK\n";
}
