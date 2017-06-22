#!/usr/local/bin/perl
use strict;

#Check the health of IHS
#Usage:
#         check_ihs.sh  [list of sites]
#Example: check_ihs.sh rolandgarros-odd masters-odd tonys-odd
## __SCRIPTNAME - name of the script without the path
##
#
use FindBin;
use lib ("/$FindBin::Bin/../../lib", "/$FindBin::Bin/../lib", "$FindBin::Bin", "/lfs/system/tools/ihs/lib");
use Term::ANSIColor qw(:constants);

# local $Term::ANSIColor::AUTORESET = 1;
my $debug = $ENV{'debug'};
$debug = 1 if -e "debug_check_ihs";
use Data::Dumper;
use Sys::Hostname;
use EI::DirStore;
use IPC::Open3;

#================================================================================
# Add/Remove site urls
#================================================================================
my $cluster = {
     BZCDTCL002 => { EXCLUDE => [ [ "w3cdt.stg.eventsgslb.ibm.com",        "9445" ], ], },
     BZPRECL002 => { EXCLUDE => [ [ "w3pre.stg.eventsgslb.ibm.com",        "9445" ], ], },
     YZCDTCL003 => { EXCLUDE => [ [ "redirecttest.w3.ibm.com",             "443" ], ], },
     YZPRECL006 => { EXCLUDE => [ [ "w3redirect.staging.events.ihost.com", "443" ], ], },
     YZPRDCL001 => {
        EXCLUDE => [ [ "redirect.w3.ibm.com", "443" ], [ "redirect.w3.ibm.com", "80" ], ],
        URLS => [
                  [ 'www.ibm.com',  'http://www.ibm.com/Admin/whichnode', '[a-z]' ],
                  [ 'www_redirect', 'http://www.ibm.com/data/10k.txt',    '[01]' ],
                  [ 'p1_redirect',  'http://129.42.26.212/data/10k.txt',  '[01]' ],
                  [ 'p2_redirect',  'http://129.42.34.212/data/10k.txt',  '[01]' ],
                  [ 'p3_redirect',  'http://129.42.42.212/data/10k.txt',  '[01]' ],
                  [
                    'www_search',
                    'http://www.ibm.com/search/?q=%2Burl.all%3Ahttp%3A%2F%2Fwww.ibm.com%2F&realm=ibm&v=10&lang=en&cc=us', '[a-z]'
                  ],
                  [
                    'p1_search',
                    'http://p1.www.ibm.com/search/?q=%2Burl.all%3Ahttp%3A%2F%2Fwww.ibm.com%2F&realm=ibm&v=10&lang=en&cc=us',
                    '[a-z]'
                  ],
                  [
                    'p2_search',
                    'http://p2.www.ibm.com/search/?q=%2Burl.all%3Ahttp%3A%2F%2Fwww.ibm.com%2F&realm=ibm&v=10&lang=en&cc=us',
                    '[a-z]'
                  ],
                  [
                    'p3_search',
                    'http://p3.www.ibm.com/search/?q=%2Burl.all%3Ahttp%3A%2F%2Fwww.ibm.com%2F&realm=ibm&v=10&lang=en&cc=us',
                    '[a-z]'
                  ],
                  [ 'p1_netscaler', 'http://129.42.56.212/site.txt', 'www.ibm.com' ],
                  [ 'p2_netscaler', 'http://129.42.58.212/site.txt', 'www.ibm.com' ],
                  [ 'p3_netscaler', 'http://129.42.60.212/site.txt', 'www.ibm.com' ],
        ]
     },
     YZPRDCL002 => {
                     URLS => [
                               [ 'ESC', 'https://www-930.ibm.com/support/esc/home.jsp', 'Electronic Service Call' ],
                               [
                                 'ESC_rtp', 'http://rtp.www-930.events.ibm.com/support/esc/heartbeat.wss',
                                 'SUCCEEDED.*\n.*SUCCEEDED.*\n.*SUCCEEDED'
                               ],
                               [
                                 'ESC_stl', 'http://stl.www-930.events.ibm.com/support/esc/heartbeat.wss',
                                 'SUCCEEDED.*\n.*SUCCEEDED.*\n.*SUCCEEDED'
                               ],
                               [
                                 'ESC_bld', 'http://bld.www-930.events.ibm.com/support/esc/heartbeat.wss',
                                 'SUCCEEDED.*\n.*SUCCEEDED.*\n.*SUCCEEDED'
                               ],
                     ],
     },
     YZPRDCL004 => {
                     URLS => [
                               [ 'webserver.ibm.proxy_p1', 'http://129.42.26.215/site.txt', 'www.ibm.com' ],
                               [ 'webserver.ibm.proxy_p2', 'http://129.42.34.215/site.txt', 'www.ibm.com' ],
                               [ 'webserver.ibm.proxy_p3', 'http://129.42.42.215/site.txt', 'www.ibm.com' ],
                     ],
     },
     YZPRDCL006 => { EXCLUDE => [ [ "www-945.ibm.com", "9445" ], [ "www-945.ibm.com:9445", "9445" ], ], },
     YZPRDCL007 => {
                     URLS => [
                               [ 'webserver.xsr.prd',    'https://www-946.ibm.com/sslsite.txt',           'www-946.ibm.com' ],
                               [ 'webserver.xsr.prd_p1', 'https://p1.www-946.events.ibm.com/sslsite.txt', 'www-946.ibm.com' ],
                               [ 'webserver.xsr.prd_p2', 'https://p2.www-946.events.ibm.com/sslsite.txt', 'www-946.ibm.com' ],
                               [ 'webserver.xsr.prd_p3', 'https://p3.www-946.events.ibm.com/sslsite.txt', 'www-946.ibm.com' ],
                     ],
     },
     YZPRDCL011 => { EXCLUDE => [ [ "eitadmh.event.ibm.com", "9999" ], ], },
};

#
my $host     = hostname;
my $eistats  = "/lfs/system/tools/ihs/bin/check_eistats.pm";
my $checkURL = "/lfs/system/tools/ihs/bin/chk_url_clientauth.pm";

#
my $wanted = join(' ', @ARGV);
my $confs = {};
my @stack;
my $defined_ips = defined_ips();
my $listeners   = listeners();
dsConnect();
find_ihs_configs();
dsDisconnect();
print Dumper($confs) if $debug;

#========================================================================================
# main code
#========================================================================================
$ENV{'chk_url_caller'} = 'check_ihs';
foreach my $conf (sort keys %{$confs}) {
   next if !exists $confs->{$conf}->{'documentroot'};
   my $custtag = $confs->{$conf}->{'custtag'};
   if (!$wanted || $custtag =~ /$wanted/i) {
      print BOLD CYAN '-' x 20
        . "$confs->{$conf}->{'custtag'} $confs->{$conf}->{'servername'} $confs->{$conf}->{'version'} "
        . '-' x 20 . "\n";
      if (checkIHS($conf, $confs->{$conf})) {
         checkConf($conf, $confs->{$conf});
         checkStats($confs->{$conf}->{'server_ip'});
         checkVIPS($confs->{$conf}) if $confs->{$conf}->{'vips'};
         checkSites($confs->{$conf});
         print "\n";
      } ## end if ( checkIHS( $confs->...))
   } ## end if ( !$wanted || $wanted...)
} ## end foreach my $conf ( sort keys...)

#========================================================================================
# subroutines
#========================================================================================
sub checkSites {
   my $data = shift;
   header('Checking Sites');
   my $custtag = $data->{'custtag'};

   # add local host to vhosts
   $data->{'vhosts'}->{ $data->{'server_ip'} } = {
                                                   servername => $data->{'servername'},
                                                   'site.txt' => $data->{'site.txt'},
                                                   sitetext   => $data->{'sitetext'},
   };
   foreach my $vhost (sort keys %{ $data->{'vhosts'} }) {
      if (!$data->{'vhosts'}->{$vhost}->{'protected'}) {    # if access restriced by password we cant test it
         my $servername = $data->{'vhosts'}->{$vhost}->{'servername'};
         my @ips = split(/ +/, $vhost);
         my $proto;
         my $uri;
         my $sitetext;
         $uri = 'site.txt' if $data->{'vhosts'}->{$vhost}{'site.txt'};
         if ($data->{'vhosts'}->{$vhost}->{'ssl'}) {
            $proto = 'https';
         }
         else {
            $proto = 'http';
         }
         foreach my $ip (sort @ips) {
            print "testing $ip " if $debug;
            if ($ip =~ /\*:/) {
               my $server_ip = $data->{'server_ip'};
               $server_ip =~ s/:.*$//;
               $ip        =~ s/\*:/$server_ip:/;
            }
            print "as $ip\n" if $debug;

            #=================================================
            # check if this is on the exclude list
            #=================================================
            my $skip = 0;
            if (exists $cluster->{$custtag}->{'EXCLUDE'}) {
               foreach my $exclude (@{ $cluster->{$custtag}->{'EXCLUDE'} }) {
                  my $ex_name = $exclude->[0];
                  my $ex_port = $exclude->[1];
                  if ($servername =~ /$ex_name/ && $ip =~ /:$ex_port/) {
                     $skip = 1;
                     last;
                  }
               }
            }
            if (!$skip) {
               if ($data->{'vhosts'}->{$vhost}->{'site.txt'}) {
                  if ($data->{'vhosts'}->{$vhost}->{'sitetext'}) {
                     $sitetext = $data->{'vhosts'}->{$vhost}->{'sitetext'};
                     $sitetext =~ s/^[\"\']|[\"\']$//;
                     $sitetext =~ s/[\(\)\{\}\[\]]/\./g;    # change brackets etc to wildcard .
                     $sitetext = "'" . $sitetext . "'";
                  }
                  else {
                     $sitetext = '[a-z]';                   # find any lowercase char
                  }
               }
               else {
                  $sitetext = '';
               }
               my $cmd = "$checkURL \"$servername\" \"$proto://$ip/$uri\" $sitetext";
               do_cmd($cmd) if $uri;
            }
         } ## end foreach my $ip ( sort @ips )
      } ## end if ( !$data->{'vhosts'...})
   } ## end foreach my $vhost ( sort keys...)
   if (exists $cluster->{ $data->{custtag} }->{'URLS'}) {
      foreach my $url_list (@{ $cluster->{ $data->{custtag} }->{'URLS'} }) {
         my $servername = $url_list->[0];
         my $url        = $url_list->[1];
         $url =~ s/^[\'\"]//g;
         $url = "'" . $url . "'";
         my $sitetext = $url_list->[2];
         $sitetext =~ s/^[\"\']|[\"\']$//;
         $sitetext = "'" . $sitetext . "'";
         my $cmd = "$checkURL \"$servername\" $url $sitetext";
         do_cmd($cmd);
      } ## end foreach my $url_list ( @{ $urls...})
   } ## end if ( exists $urls->{ $data...})
} ## end sub checkSites

#================================================================================
# check VIPS are defined to loopback
#================================================================================
sub checkVIPS {
   my $data = shift;
   my $vips = $data->{'vips'};
   header('Checking VIPS defined to loopback adapter');
   foreach my $vip (sort keys %{$vips}) {
      my $servername = $data->{'servername'};
      my $found;
      $vip =~ s/:.*//;
      foreach my $vhost (keys %{ $data->{'vhosts'} }) {
         print "searching for $vip in $vhost\n" if $debug;
         if ($vhost =~ /$vip/) {
            $servername = $data->{'vhosts'}->{$vhost}->{'servername'};
            $servername =~ s/:\d*//;
            $found = 1;
            last;
         } ## end if ( $vhost =~ /$vip/ )
      } ## end foreach my $vhost ( keys %{...})
      if ($found) {
         if (!live_ip($vip)) {
            printf "%s%s#### %s not defined%s\n", BOLD, RED, $vip, RESET;
         }
         else {
            print "\tFound VIP $vip for $servername\n";
         }
      } ## end if ($found)
   } ## end foreach my $vip ( sort keys...)
} ## end sub checkVIPS

#================================================================================
# Show server stats
#================================================================================
sub checkStats {
   my $ip = shift;
   header('Checking ei-stats over a 7 second interval');
   do_cmd("$eistats $ip");
}

#================================================================================
# Check conf correct
#================================================================================
sub checkConf {
   my ($conf, $data) = @_;
   header('Checking config');
   my ($sitetag) = (split('/', $data->{'documentroot'}))[2];
   my $apachectl = (glob "$data->{'serverroot'}/bin/apache*ctl")[0];
   if (uc($^O) eq "AIX") {
      $ENV{'LIBPATH'} = "/projects/${sitetag}/lib";
   }
   elsif (uc($^O) eq 'LINUX') {
      $ENV{'LD_LIBRARY_PATH'} = "/projects/${sitetag}/lib";
   }
   else {
      print "$^O is not supported\n";
      exit;
   }
   my $cmd = "$apachectl -t -f $conf 2>&1";
   do_cmd($cmd);
} ## end sub checkConf

#================================================================================
# Check IHS running
#================================================================================
sub checkIHS {
   my ($conf, $data) = @_;
   header('Checking IHS process');

   # check if httpd process is running
   #
   if (is_httpd_running($conf, $data->{'serverroot'})) {
      $data->{server_ip} = find_allowed_ip($data);
      if ($data->{'server_ip'}) {
         my $cmd = "lynx --dump http://$data->{'server_ip'}/server-status";
         print YELLOW "$cmd\n" if $debug;
         open CMD, "$cmd |";
         while (my $line = <CMD>) {
            $line =~ s/^\s+|\s+$//g;
            print "\t$line\n";
            if ($line =~ /total accesses/i) {
               last;
            }
         } ## end while ( my $line = <CMD> )
      } ## end if ( $data->{'server_ip'...})
      else {
         print BOLD RED "#### Server misconfigured, cannot access /server-status\n";
         print RESET;
         return;
      }
      return 1;
   } ## end if ( is_httpd_running(...))
   else {
      print BOLD RED "#### HTTP daemon for version $data->{'version'} not running\n";
      print RESET;
      return;
   }
} ## end sub checkIHS

#--------------------------------------------------------------
# Find ip in the allowed list that is defined to this server
#--------------------------------------------------------------
sub find_allowed_ip {
   my $data = shift;
   my $server_ip;

   # start with defined ips
   # if * check for allows
   # if restricted by allows
   my @ips = @{$defined_ips};
   print "pass 1 ip's we dont have a listen for \npotential ips -> " . Dumper(\@ips) if $debug;
   print "Listens -> " . Dumper($data->{'listen'}) if $debug;
   for (my $i = @ips - 1 ; $i >= 0 ; $i--) {
      my $matched;
      foreach my $listen (@{ $data->{'listen'} }) {
         my ($ip, $port) = split(/:/, $listen);
         if ($ip eq '*' || $ip eq $ips[$i]) {
            $matched = 1;
            last;
         }
      }
      if (!$matched) {
         print "no listen matches deleting $ips[$i]\n" if $debug;
         splice(@ips, $i, 1);
      }
   }
   print "2nd pass apply allow restrictions \npotential ips -> " . Dumper(\@ips) if $debug;
   print "Allows -> " . Dumper($data->{'allows'}) if $debug;

   # 2nd pass check matching allows
   for (my $i = @ips - 1 ; $i >= 0 ; $i--) {
      my $matched;
      foreach my $allow (@{ $data->{'allows'} }) {
         chomp $allow;
         if ($ips[$i] =~ /$allow/) {
            $matched = 1;
            last;
         }
      }
      if (!$matched) {
         print "no allow matches deleting $ips[$i]\n" if $debug;
         splice(@ips, $i, 1);
      }
   }
   my $matched;
   foreach my $ip (@ips) {
      if ($ip eq '127.0.0.1') {
         $matched = 1;
      }
   }
   if ($matched) {
      return '127.0.0.1';
   }
   else {
      return $ips[0];
   }
} ## end sub find_allowed_ip

#--------------------------------------------------------------
# Check ip address being listened on
#--------------------------------------------------------------
sub listening {
   my $ip = shift;
   my $port;
   ($ip, $port) = split(/:/, $ip);
   print "is $ip:$port active " if $debug;
   $ip =~ s+\*+\/\*+;
   foreach my $listner (@{$listeners}) {
      if ($listner =~ /(?:$ip)[:\.]$port/) {
         print "yes\n" if $debug;
         return 1;
      }
   } ## end foreach my $listner ( @{$listeners...})
   print "no\n" if $debug;
   return;
} ## end sub listening

#--------------------------------------------------------------
# Build list of active listen addresses
#--------------------------------------------------------------
sub listeners {
   my @listeners;
   open CMD, "netstat -na |";
   while (my $line = <CMD>) {
      if ($line =~ /^tcp.*listen/i) {
         push @listeners, (split(/ +/, $line))[3];
      }
   }
   close CMD;
   return \@listeners;
} ## end sub listeners

#--------------------------------------------------------------
# Check if httpd process is running
#--------------------------------------------------------------
sub is_httpd_running {
   my ($conf, $root) = @_;
   my $http_regex = build_regex([ glob("$root/bin/httpd*") ]);
   my $conf_regex = build_regex([ '/etc/apache2/httpd.conf', $conf ]);
   my $running    = 0;
   print "looking for running httpd using regex $http_regex  $conf_regex: " if $debug;
   open CMD, "ps -ef |";
   while (my $line = <CMD>) {
      if ($line =~ /$http_regex/) {
         if ($line !~ /-f/ || $line =~ /$conf_regex/) {
            close CMD;
            print "found it\n" if $debug;
            return 1;
         }
      }
   } ## end while ( my $line = <CMD> )
   close CMD;
   print "not running\n" if $debug;
   return;
} ## end sub is_httpd_running

#--------------------------------------------------------------------
# Build a regex for all possible routes to a file following symlinks
#--------------------------------------------------------------------
sub build_regex {
   my ($file_list) = @_;
   my $regex = "(?:";
   my %files;
   while (@$file_list) {
      my $file = shift @$file_list;
      my @parts = split(/\//, $file);
      shift @parts if $file =~ /^\//;
      my $f;
      while (@parts) {
         my $part = shift @parts;
         $f .= "/$part";
         print "looking for $f -" if $debug;
         if (-l $f) {
            my $l = readlink $f;
            print " its a symlink to $l" if $debug;
            if ($l !~ /^\// || $l =~ /^\.\//) {    # no starting / or ./
               my ($pre) = $f =~ /(.*)\//;
               $l =~ s/^\.\///;
               $l = $pre . '/' . $l;
            }
            $l .= '/' . join('/', @parts);
            $l =~ s/\/$//;
            push @$file_list, $l;
         }
         elsif (@parts) {
            my $target = $f . '/' . join('/', @parts);
            if (-e $target) {
               $files{$target} = undef;
            }
         }
         else {
            if (-e $f) {
               $files{$f} = undef;
            }
         }
         print "\n" if $debug;
      }
   }
   $regex .= join('|', keys %files) . ")";
   return $regex;
}

#--------------------------------------------------------------
# find IHS configs
#--------------------------------------------------------------
sub find_ihs_configs {
   my @roles;
   my $server_type = 'sws';
   my %results;
   my $rc = dsSearch(
                     %results, "system",
                     expList => ["eihostname==$host"],
                     attrs   => ['role']
   );
   foreach my $eihost (sort keys %results) {
      foreach my $role (@{ $results{$eihost}{'role'} }) {
         push @roles, $role if $role =~ /webserver\./i;
      }
   }
   if (!@roles) {
      print "No roles found\n" if $debug;
      my %results;
      $rc          = dsGet(%results, "system", $host, attrs => ['role']);
      @roles       = @{ $results{'role'} };
      $server_type = 'Global';
   } ## end if ( !@roles )
   foreach my $role (@roles) {
      print "got Webserver roles, see if we can get useful info from them\n" if $debug;
      my %results;
      $rc = dsGet(%results, "role", $role, attrs => ['rolevar']);
      my $conf = "/projects/HTTPServer/conf/httpd.conf";    # assume global conf in standard location
      foreach my $var (@{ $results{'rolevar'} }) {
         my ($value) = $var =~ /:(.*)/;
         if ($var =~ /IHSDIR:/) {
            if (   -e "$value/conf/httpd.conf"
                && -l "$value/conf/httpd.conf") {

               # if its a symlink then we can use it, we dont keep httpd.conf in the IHSDIR directory
               $conf = readlink "$value/conf/httpd.conf";
            }
         }
         if ($server_type eq 'sws' && $var =~ /SITETAG:/) {
            my $conf = "/projects/$value/conf/$value.conf";
            if (-e $conf) {
               $confs->{$conf}->{type}    = $server_type;
               $confs->{$conf}->{custtag} = uc($value);
               parse_config($conf, $confs->{$conf});
            }
         } ## end if ( $server_type eq 'sws'...)
         elsif ($server_type eq 'Global' && $var =~ /CUSTTAG:/) {
            if (-e $conf) {
               $confs->{$conf}->{type}    = $server_type;
               $confs->{$conf}->{custtag} = uc($value);
               parse_config($conf, $confs->{$conf});
            }
         } ## end elsif ( $server_type eq 'Global'...)
      } ## end foreach my $var ( @{ $results...})
   } ## end foreach my $role (@roles)
                   # quick and dirty provisioned node fix
   my $nodecusttag;
   open 'node', '<', '/usr/local/etc/nodecache';
   while (my $line = <node>) {
      if ($line =~ /^role\s/) {
         ($nodecusttag) = $line =~ /webserver.cluster.([ybg]z\w\w\wcl\d\d\d)/i;
      }
   }
   close 'node';
   my @confs = `ls /projects/*/conf/*.conf | grep -vE 'listen|kht|mobile'`;
   foreach my $conf (@confs) {
      chomp $conf;
      my $custtag;
      if ( ! $nodecusttag ) {
         $custtag = (split(/\//,$conf))[-1];
         $custtag =~s/.conf(?:ig)?$//;
      }
      print "found $conf -> $custtag\n" if $debug;
      
      if (-e $conf) {
         $confs->{$conf}->{type}    = $server_type;
         $confs->{$conf}->{custtag} = uc($custtag);
         parse_config($conf, $confs->{$conf});
      }
   }
} ## end sub find_ihs_configs

#--------------------------------------------------------------
# Parse the config
#--------------------------------------------------------------
sub parse_config {
   my ($conf, $data) = @_;
   my $fh = (split '/' . $conf)[-1];
   my ($keep_allows, $authtype);
   open $fh, "<", "$conf";
   while (my $line = <$fh>) {

      # DOCUMENTROOT
      if ($line =~ /documentroot\s+([^\s]*)/i) {
         $data->{'documentroot'} = $1;
         if (-e $data->{'documentroot'} . '/site.txt') {
            $data->{'site.txt'} = $data->{'documentroot'} . '/site.txt';
            open TXT, '<', $data->{'site.txt'};
            while (my $line = <TXT>) {
               $line =~ s/^\s+//;
               if ($line) {
                  $data->{'sitetext'} = $line;
                  $data->{'sitetext'} =~ s/^\s+|\s+$//g;
                  last;
               }
            }
            close TXT;
         }
         next;
      } ## end if ( $line =~ /documentroot\s+([^\s]*)/i)
          # SERVERROOT
      if ($line =~ /^\s*?serverroot\s+([^\s]*)/i) {
         $data->{'serverroot'} = $1;
         $data->{'serverroot'} =~ s/^[\s\"\']+//;
         $data->{'serverroot'} =~ s/[\s\"\']+$//;
         $data->{'version'} = server_version($data->{'serverroot'});
         next;
      }

      # SERVERNAME
      if ($line =~ /^\s*?servername\s+([^\s]*)/i) {
         $data->{'servername'} = $1;
         next;
      }

      # AUTH TYPE
      if ($authtype && $line =~ /^\s*?authtype\s+basic/i) {
         $data->{'protected'} = 1;
      }

      # </LOCATION />
      if ($line =~ /^\s*?<Location\s+\/>/i) {
         $authtype = 1;
      }

      # </LOCATION /server-status>
      if ($line =~ /^\s*?<Location\s+\/server-status>/i) {
         $keep_allows = 1;
      }

      # </LOCATION>
      if ($line =~ /^\s*?<\/Location>/i) {
         $keep_allows = 0;
         $authtype    = 0;
      }

      # ALLOW FROM
      if ($keep_allows && $line =~ /^\s*?allow\s+from/i) {
         push @{ $data->{'allows'} }, (split(/ +/, $line))[-1];
      }

      # LISTEN
      if ($line =~ /^\s*?listen\s+([^\s]*)/i) {
         my $ip = $1;
         if ($ip !~ /:/) {
            $ip = "*:$ip";
         }
         push @{ $data->{'listen'} }, $ip;
         if ($ip =~ /^129\./) {
            $data->{'vips'}->{$ip} = undef;
         }
         next;
      } ## end if ( $line =~ /^\s*?listen\s+([^\s]*)/i)

      # SSLENABLE
      if ($line =~ /^\s*?sslenable\s+([^\s]*)/i) {
         $data->{'ssl'} = '1';
         next;
      }

      # INCLUDE
      if ($line =~ /^\s*?include\s+([^\s]*)/i) {
         parse_config($1, $data);
         next;
      }

      # <VIRTUALHOST ip:port ip:port>
      if ($line =~ /^\s*?<virtualhost\s+(.[^>]*)/i) {
         print $line if $debug;
         my @vhost = split(/ +/, $1);
         my $vhosts;
         foreach my $vhost_ip (@vhost) {
            $vhost_ip =~ s/\>//;
            print "found vhost ip $vhost_ip\n" if $debug;
            if ($vhost_ip =~ /^129\./) {    # 129 addresses are vips
               my $vip = $vhost_ip;
               $vip =~ s/:.*//;
               $data->{'vips'}->{$vip} = undef;
            }
            if (live_ip($vhost_ip)) {       # if defined to the OS
               $vhosts .= "$vhost_ip ";
            }
            else {
               print "vhost ip $vhost_ip not added not defined to server\n"
                 if $debug;
            }
         } ## end foreach my $vhost_ip (@vhost)
         push @stack, $data;
         $data->{'vhosts'}->{$vhosts} = { conf => $conf };
         $data = $data->{'vhosts'}->{$vhosts};
         next;
      } ## end if ( $line =~ /^\s*?<virtualhost\s+(.[^>]*)/i)

      # </VIRTUALHOST>
      if ($line =~ /^\s*?<\/virtualhost>/i) {
         $data = pop @stack;
         next;
      }
   } ## end while ( my $line = <$fh> )
   close $fh;
} ## end sub parse_config

#---------------------------------------------------------------
# check if ip is defined to this server
#---------------------------------------------------------------
sub live_ip {
   my $ip = shift;
   $ip =~ s/:\d*>?//;
   return 1 if $ip eq '*';
   foreach my $inet (@{$defined_ips}) {
      return 1 if $ip eq $inet;
   }
   return;
} ## end sub live_ip

#--------------------------------------------------------------
# Find version of IHS or Apache
#--------------------------------------------------------------
sub server_version {
   my $root = shift;
   if (-e "$root/properties/version/IHS.product") {
      open PROP, "<", "$root/properties/version/IHS.product";
      while (my $line = <PROP>) {
         if ($line =~ /<version>/i) {
            my ($version) = $line =~ />([^<]+)/;
            return $version;
         }
      } ## end while ( my $line = <PROP>)
      close PROP;
   } ## end if ( -e "$root/properties/version/IHS.product")
   elsif (-e "$root/bin/apache2ctl") {
      open CMD, "$root/bin/apache2ctl -v |";
      while (my $line = <CMD>) {
         if ($line =~ /version/i) {
            my ($version) = $line =~ /version:\s(.*)/i;
            return $version;
         }
      } ## end while ( my $line = <CMD> )
   } ## end elsif ( -e "$root/bin/apache2ctl")
   else {
      print "Cant determine version for $root\n";
      return 'Unknown';
   }
} ## end sub server_version

#--------------------------------------------------------------
# get ips defined to the server
#--------------------------------------------------------------
sub defined_ips {
   my $ifconfig;
   if (-e "/sbin/ifconfig") {
      $ifconfig = "/sbin/ifconfig";
   }
   else {
      $ifconfig = "/usr/sbin/ifconfig";
   }
   my @ips;
   open "CMD", "$ifconfig -a |";
   while (<CMD>) {
      if (/(?:inet|inet addr:)/i) {
         s/(?:inet(\d)? addr:|inet)//;
         s/^\s+//g;
         /(.+?)\s/;
         push @ips, $1;
      } ## end if (/(?:inet|inet addr:)/i)
   } ## end while (<CMD>)
   return \@ips;
} ## end sub defined_ips

sub do_cmd {
   my $cmd = shift;
   printf "%s%s%s%s\n", BOLD, YELLOW, $cmd, RESET if $debug;
   open CMD, "$cmd |";
   while (my $line = <CMD>) {
      $line =~ s/^\s+//g;
      print "\t$line";
   }
   close CMD;
} ## end sub do_cmd

sub header {
   my $text = shift;
   my $msg = sprintf "%s%s%02d:%02d:%02d $text%s\n", BOLD, GREEN, (localtime(time))[ 2, 1, 0 ], RESET;
   print "$msg";
} ## end sub header
