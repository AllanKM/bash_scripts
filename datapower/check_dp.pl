#!/usr/local/bin/perl
#============================================
# $Revision: 1.2 $
# Author: Steve Farrell
#============================================
use strict;
use FindBin;
use Term::ANSIColor;
use lib ("/$FindBin::Bin", "/$FindBin::Bin/lib", "/$FindBin::Bin/../lib", "/lfs/system/tools/configtools/lib");
use Data::Dumper;
use dp_functions;
my ($serverlist, $attrs) = parseParms(\@ARGV);
my $dp_user = get_dp_user($serverlist);

foreach my $server (sort @$serverlist) {
   my @domains;
   if ($attrs->{'a'}) {
      @domains = getDomains($dp_user, $server);
   }
   else {
      push @domains, 'default';
      push @domains, ei_domain($server);
   }
   my ($cfg) = getDomainConfig($dp_user, $server);
   foreach my $domain (@domains) {
      my ($status) = getDomainStatus($dp_user, $server, $domain);
      my $opstate = $status->{$domain}->{'amp:opstate'};
      $opstate = colored($opstate, "red bold") if $opstate ne 'up';
      my $adminstate = $cfg->{$domain}->{madminstate};
      $adminstate = colred($adminstate, "red bold") if $adminstate ne "enabled";
      my $configstate = $status->{$domain}->{'amp:configstate'};
      $configstate = colored($configstate, "red bold") if $configstate ne 'saved';
      printf "%s %s AdminState: %s OpState: %s ConfigState: %s  DebugState: %s\n",
        colored($server, "yellow bold"),
        colored($domain, "yellow bold"),
        $adminstate,
        $opstate,
        $configstate,
        $status->{$domain}->{'amp:debugstate'};
      my $objects = readObjectStatus($dp_user, $server, $domain);
      printf "%-34s", colored("Certificate Status", "yellow bold");
      showobjects($objects, qr/CryptoCertificate/);
      printf "%-34s", colored("Validation Credentials", "yellow bold");
      showobjects($objects, qr/CryptoValCred/);
      printf "%-34s", colored("MQ Queue Manager", "yellow bold");
      showobjects($objects, qr/MQQM/);
      printf "%-34s", colored("MultiProtocol Gateway", "yellow bold");
      showobjects($objects, qr/HTTP.*Source.*|MQSourceProtocolHandler/);
      print "\n";
   }
}

sub showobjects {
   my ($objects, $class) = @_;
   my $err_count = 0;
   print "\n" if $attrs->{'d'};
   foreach my $object (sort { lc($a) cmp lc($b) } keys %$objects) {
      if ($objects->{$object}->{class} =~ $class) {
         my $opstate = $objects->{$object}->{opstate};
         $opstate = colored($opstate, "red bold") if $opstate eq 'down';
         my $adminstate = $objects->{$object}->{adminstate};
         $adminstate = colored($adminstate, "red bold") if $adminstate ne 'enabled';
         my $configstate = $objects->{$object}->{configstate};
         $configstate = colored($configstate, "red bold") if $configstate ne 'saved';
         if ($attrs->{'d'}) {
            printf "   %-50s OpState: %-4s AdminState: %-8s ConfigState: %-7s ",
              $object,
              $opstate,
              $adminstate,
              $configstate,
              $objects->{$object}->{errorcode};
            if ($objects->{$object}->{errorcode}) {
               printf "Error: %s\n", $objects->{$object}->{errorcode};
            }
            else {
               print "\n";
            }
         }
         elsif ($opstate =~ /down/ || $adminstate !~ /enabled/ || $configstate !~ /saved/) {
            $err_count++;
         }
      }
   }
   if (!$attrs->{'d'}) {
      if ($err_count > 0) {
         print colored("Fail, $err_count errors", "red bold") . "\n";
      }
      else {
         print "OK\n";
      }
   }
}
