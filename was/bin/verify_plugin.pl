#!/usr/local/bin/perl-current
use strict;
use Data::Dumper;
use Getopt::Std;
use EI::DirStore;
use EI::DirStore::Util;
use Sys::Hostname;
use File::Basename;
use Cwd 'realpath';

if ( $#ARGV lt 0 ) {
   print
"Need to supply name of plugin file to validate and an IHS role name\n";
   exit 1;
}
my $xml         = $ARGV[0];
my $xml_cluster = $ARGV[1];
my $fullpath    = realpath($xml);

my %plugin;
my $dirstore_key;
my $header1 = 0;
my $header2 = 0;
my $badxml  = 0;
my %xmlhash;
my $debug = $ENV{'debug'};
my $details = $ENV{'details'};
my $cline;
my @xml;
my $EXIT_CODE = 0;
my $LIB_HOME = "/lfs/system/tools";

# =======================================================
# Check new xml conforms to EI standards
# =======================================================
validate_xml();

if ($xml_cluster !~ /^--no-dirstore$/ && $badxml == 0) {
   if ( not defined $ENV{DSLDAPUSER} and not defined $ENV{DSUSER} ) {
      dsConnect( user => "dsUpdate" )
         or die "Error: Couldn't connect: $dsErrMsg\n";
   }

   compare_old();
}

print "\n";
if ( $badxml == 0 ) {
   $EXIT_CODE = 0;
}
elsif ( $badxml != 0 ) {
   $EXIT_CODE = 8;
}
exit $EXIT_CODE;

#================================================================================================================
sub printHeader {
   my ($num) = @_;
   if ( $num == 1 && !$header1 ) {
      print "\nChecking plugin stanzas are complete and meet EI standards\n";
      print "------------------------------------------------------------\n";
      $header1 = 1;
   }
   else {
      print "\nValidating plugin changes from last known good configuration\n";
      print "--------------------------------------------------------------\n";
      $header2 = 1;
   }

}

sub compare_old {

#=======================================================================================
# compare current config to config stored in dirstore (if it exists)
#=======================================================================================

   # calculate dirstore key
   my $cluster;
   my $env;
   
   if ( $xml_cluster ) {
     # user supplied role name on command line
     # check the role exists
     dsSearch( my %results, "system", expList => [ "role==${xml_cluster}" ], attrs => ['hostname'] );
     if ( ! %results ) {
       if ( $details ) {
         print "Invalid role name $xml_cluster, role not assigned to any node, cannot compare against previous config\n";
       }
       $badxml = 1;
       return;
     }
   }
   else {
     if ( $details ) {
       print "No IHS Role name provided, cannot compare against previous config\n";
     }
     $badxml = 1;
     return;
   }

   # if we get here we should have a valid role name to check against

   my %results;
   dsGet( %results, "system", hostname(), attrs => ['hostenv', 'realm'] );
   my @node_env = @{ $results{'hostenv'} };
   if ( $debug ) {
     print "env is @node_env\n";
   }

   my $file = fileparse($fullpath);
   $file =~ s/^merged_//;
  
   if ( $file eq "plugin-cfg.xml" ) {
     my @plex = @{ $results{'realm'} };
     my $plexname = substr($plex[0], -2);
     if ( $debug ) {
       print "plex is $plexname \n";
     }
     $xml_cluster=~s/webserver.//i;
     $xml_cluster=~s/cluster.//i;
     $dirstore_key = "plugin.@{node_env}.${xml_cluster}.${plexname}.${file}";
   } else {
     $xml_cluster=~s/webserver.//i;
     $xml_cluster=~s/cluster.//i;
     $dirstore_key = "plugin.@{node_env}.${xml_cluster}.${file}";
   }
   
   print STDERR "using $fullpath and $dirstore_key as dirstore key\n" if $debug; 
   
   # retrieve defininition from dirstore
   my %results;
   
   print "  Using last known good config $dirstore_key\n\n";
   dsGet( %results, "software", $dirstore_key, attr => ['instances'] );
   if (%results) {

# ================================================================================
# Evidence of previous plugin config found in dirstore
# ================================================================================
      if ( compare_baseline( \%results ) ) {
         update_baseline("");
      }
   }
   else {
      update_baseline("1");
   }
}

sub compare_baseline {
   my ($results) = @_;
   my $changed = 0;

   # ==========================================
   # turn dirstore entry into a usable hash
   # ==========================================
   my %old_plugin;
   foreach my $instance ( @{ $results->{'instances'} } ) {
      my ( $cluster, $urigroup, $servers ) = split( ":", $instance );
      $old_plugin{$cluster}{'uri'} = $urigroup;
      $servers =~ s/\[|\]//g;
      push( @{ $old_plugin{$cluster}{'servers'} }, split( ",", $servers ) );
   }

   # ==========================================
   # check all apps in %old_plugin are still in %plugin
   # ==========================================
   foreach my $cluster ( keys %old_plugin ) {
      if ( !exists $xmlhash{$cluster} ) {
         printHeader(2);
         warn "#### $cluster has been removed\n";
         $changed = 1;
      }
   }

   # ==========================================
   # check all apps in %plugin are in %old_plugin
   # ==========================================
   # print Dumper(\%old_plugin);
   foreach my $cluster ( keys %xmlhash ) {
      if (  $cluster eq "routes"
         || $cluster eq "urigroups"
         || $cluster eq "virtualhostgroups" )
      {
         next;
      }
      if ( !exists $old_plugin{$cluster} ) {
         printHeader(2);
         print "#### $cluster has been added\n";
         $changed = 1;
      }
      else {

         # check if app was deployed and still is
         if ( !exists $xmlhash{'routes'}{$cluster}
            && $old_plugin{$cluster}{'uri'} == 1 )
         {
            printHeader(2);
            warn
"#### Uri_group or route statement for $cluster has been removed\n";
            $changed = 1;
         }
         if ( exists $xmlhash{'routes'}{$cluster}
            && $old_plugin{$cluster}{'uri'} == 0 )
         {
            printHeader(2);
            print
"#### $cluster app has been deployed, Uri-group and Route statements now exist\n";
            $changed = 1;
         }

         # check same servers are defined
         foreach my $server ( keys %{ $xmlhash{$cluster}{'hosts'} } ) {
            if ( !grep( $server, @{ $old_plugin{$cluster}{'servers'} } ) ) {
               printHeader(2);
               print "#### Server $server has been added to cluster $cluster\n";
               $changed = 1;
            }
         }
         foreach my $server ( @{ $old_plugin{$cluster}{'servers'} } ) {
            chomp $server;
            my $found = 0;
            foreach my $old_server ( keys %{ $xmlhash{$cluster}{'hosts'} } ) {
               if ( $old_server =~ /^$server/i ) {
                  $found = 1;
                  last;
               }
            }
            if ( !$found ) {
               printHeader(2);
               warn
                 "#### Server $server has been removed from cluster $cluster\n";
               $changed = 1;
            }
         }
      }
   }
   return $changed;
}

sub update_baseline {

#======================================================================================
# prompt user to confirm if basline in dirstore should be created/updated
#======================================================================================
   my ($msg) = @_;
   if ($msg) {
      print qq[
No last known good configuration info is available in dirstore, 
review any preceeding messages and if necessary resolve any
problems before proceeding.
 
Enter y to store the current plugin status 
otherwise enter n to abort, resolve the errors and retry (y/n): ];
   }
   else {
      print qq(
Review and confirm that the preceeding messages are expected 
If they are ok then enter y to store the current plugin status
otherwise enter n to abort, resolve the errors and retry (y/n): );
   }
   my $response;
   while ( $response !~ /(y|n)/i ) {
      if ($response) {
         print "$response is an invalid response\n";
      }
      $response = <STDIN>;
      chomp $response;
   }
   if ( lc($response) eq "y" ) {
      save_baseline();
   }
   else {
      $badxml = 1;
   }
}

sub save_baseline {

#======================================================================================
# Store plugin info in dirstore attributes
#======================================================================================
   my %dirstore_entry;
   foreach my $cluster ( keys %xmlhash ) {
      if (  $cluster eq "routes"
         || $cluster eq "urigroups"
         || $cluster eq "virtualhostgroups" )
      {
         next;
      }
      my $attr     = "$cluster:";
      my $urigroup = "0";
      if ( exists $xmlhash{'routes'}{$cluster} ) {
         $urigroup = "1";
      }
      my $hosts = join( ",", sort keys %{ $xmlhash{$cluster}{'hosts'} } );
      $hosts =~ s/,$//;
      push @{ $dirstore_entry{'instances'} },
        "${cluster}:${urigroup}:[${hosts}]";
   }
   update_dirstore( $dirstore_key, \%dirstore_entry );
   dsDisconnect();
}

sub validate_xml {

   unless ( open (FILE, "<$xml")) {
      print "Can't open $xml: $!\n";
      $badxml++;
      return;
   }
       
   @xml = <FILE>;
   close FILE;

   for ( $cline = 0 ; $cline < @xml ; $cline++ ) {

      # Handle virtualhostgroup stanzas
      if ( $xml[$cline] =~ /^\s*?<virtualhostgroup/i ) {
         print "virtual hostgroup at $cline\n" if $debug;
         check_virtualhostgroup();
         print "at line $cline\n$xml[$cline]" if $debug;
      }
      elsif ( $xml[$cline] =~ /^\s*?<servercluster/i ) {
         print "servercluster at $cline\n" if $debug;
         check_servercluster();
         print "at line $cline\n$xml[$cline]" if $debug;
      }
      elsif ( $xml[$cline] =~ /^\s*?<urigroup/i ) {
         print "urigroup at $cline\n" if $debug;
         check_urigroup();
         print "at line $cline\n$xml[$cline]" if $debug;
      }
      elsif ( $xml[$cline] =~ /^\s*?<route/i ) {
         print "route at $cline\n" if $debug;
         check_route();
         print "at line $cline\n$xml[$cline] " if $debug;
      }
      print "$cline\n" if $debug;
   }
   print Dumper( \%xmlhash ) if $debug;

   # check a route statement exists for each servercluster
   my %keyrings;
   foreach my $cluster ( keys %xmlhash ) {
      if (  $cluster eq "routes"
         || $cluster eq "urigroups"
         || $cluster eq "virtualhostgroups" )
      {
         next;
      }
      if ( !exists $xmlhash{'routes'}{$cluster} ) {
         warn "  Error: Missing <Route> statement for Cluster $cluster\n" if $details;
         $badxml++;
      }

      # create a hash of keyrings used
      foreach my $host ( keys %{ $xmlhash{$cluster}{'hosts'} } ) {
         $keyrings{ $xmlhash{$cluster}{'hosts'}{$host}{'keyring'} }++;
      }
   }

   #print Dumper (\%keyrings);
   # Route statements have valid cluster/vhost/urigroups
   foreach my $cluster ( keys %{ $xmlhash{'routes'} } ) {
      my $urigroup         = $xmlhash{'routes'}{$cluster}{'urigroup'};
      my $virtualhostgroup = $xmlhash{'routes'}{$cluster}{'virtualhostgroup'};

      # do we have a cluster of this name ?
      if ( !exists $xmlhash{$cluster} ) {
         warn "  Error: Invalid <Route> - ServerCluster $cluster not found\n" if $details;
         $badxml++;
      }

      # do we have urigroup
      if ( !exists $xmlhash{'urigroups'}{$urigroup} ) {
         warn "  Error: Invalid <Route> - UriGroup $urigroup not found\n" if $details;
         $badxml++;
      }

      # do we have virtualhostgroup
      if ( !exists $xmlhash{'virtualhostgroups'}{$virtualhostgroup} ) {
         warn "  Error: Invalid <Route> - VirtualHostGroup $virtualhostgroup not found\n" if $details;
         $badxml++;
      }

      # Check clusters using https
      foreach my $server ( keys %{ $xmlhash{$cluster}{'hosts'} } ) {
         if ( $xmlhash{$cluster}{'hosts'}{$server}{'protocol'} !~ /HTTPS/i ) {
            warn "  Warn: Server $server in cluster $cluster not using HTTPS\n" if $details;
         }
      }
   }

   # If more than one keyring used
   # find which keyring has largest number of servers
   if ( scalar keys %keyrings > 1 ) {
      my $max;
      my $keyring;
      foreach my $key ( keys %keyrings ) {
         if ( $keyrings{$key} > $max ) {
            $max     = $keyrings{$key};
            $keyring = $key;
         }
      }

      # find clusters not using the most common keyring
      foreach my $cluster ( keys %xmlhash ) {
         if (  $cluster eq "routes"
            || $cluster eq "urigroups"
            || $cluster eq "virtualhostgroups" )
         {
            next;
         }
         foreach my $host ( keys %{ $xmlhash{$cluster}{'hosts'} } ) {
            if ( $xmlhash{$cluster}{'hosts'}{$host}{'keyring'} ne $keyring ) {
               warn "  Warn: $cluster server $host using invalid keyring $xmlhash{$cluster}{'hosts'}{$host}{'keyring'}\n" if $details;
            }
         }
      }
   }
}

sub check_virtualhostgroup {

   # <virtualhostgroup .... >
   #  <virtualhost ..... >
   # </virtualhostgroup>

   # save virtualhost name
   whoami();
   my $vhost_name;
   if ( $xml[$cline] =~ /name\=\"(.+?)\"/i ) {
      $vhost_name = $1;
      $xmlhash{'virtualhostgroups'}{$1} = 1;
   }
   else {
      warn "  Error: Malformed <VirtualHostGroup> at line $cline\n           ^$xml[$cline]" if $details;
      $badxml++;
   }
   $cline++;
   my $host_count = 0;
   while ( $cline < @xml && $xml[$cline] !~ /^\s*?<\/virtualhostgroup>/i ) {
      if ( $xml[$cline] =~ /^\s*?<!--/ || $xml[$cline] =~ /^\s*$/ ) {
         $cline++;
         next;
      }
      if ( $xml[$cline] =~ /<virtualhost/i ) {
         check_virtualhost();
         $host_count++;
      }
      else {
         warn "  Error: Invalid line in <Virtualhostgroup> stanza at line $cline\n           ^$xml[$cline]" if $details;
         $badxml++;
      }
      $cline++;
   }
   if ( $host_count < 1 ) {
      warn "  Error: Empty <VirtualHostGroup> stanza $vhost_name at line $cline\n           ^$xml[$cline]" if $details;
      $badxml++
   }
}

sub check_servercluster {

   # <ServerCluster
   #     <Server
   #        <Transport
   #           <Property
   #        </Transport>
   #     </Server>
   #     <PrimaryServers>
   #         <Server
   #     </PrimaryServers>
   # </servercluster>
   whoami();
   my $cluster;
   if ( $xml[$cline] =~ /name=\"(.+?)\"/i ) {
      $cluster = $1;
   }
   else {
      warn "  Error: Malformed <serverCluster> at line $cline\n           ^$xml[$cline]";
      $badxml++;
   }
   $cline++;
   while ( $cline < @xml && $xml[$cline] !~ /^\s*?<\/servercluster>/i ) {
      if ( $xml[$cline] =~ /^\s*?<!--/ || $xml[$cline] =~ /^\s*$/ ) {
         $cline++;
         next;
      }
      elsif ( $xml[$cline] =~ /^\s*?<server /i ) {
         check_server($cluster);
      }
      elsif ( $xml[$cline] =~ /^\s*?<primaryservers>/i ) {
         check_primaryservers($cluster);
      }
      elsif ( $xml[$cline] =~ /^\s*?<backupservers>/i ) {
         check_backupservers($cluster);
      }
      else {
         warn "  Error:  Invalid line in <ServerCluster> stanza at line $cline\n           ^$xml[$cline]";
         $badxml++;
      }
      $cline++;
   }

}

sub check_server {

   #     <Server
   #        <Transport
   #           <Property
   #        </Transport>
   #     </Server>
   whoami();
   my ($cluster) = @_;
   my $server_name;
   if ( $xml[$cline] =~ /name=\"(.+?)\"/i ) {
      push @{ $xmlhash{$cluster}{'servers'} }, $1;
   }
   else {
      warn "  Error: Malformed <server> at line $cline\n           ^$xml[$cline]";
      $badxml++;
   }
   if ( $xml[$cline] =~ "\/>" ) {    # single line definition
      print " Return from check_transport at $cline\n" if $debug;
      return;
   }

   $cline++;
   while ( $cline < @xml && $xml[$cline] !~ /^\s*?<\/server>/i ) {
      if ( $xml[$cline] =~ /^\s*?<!--/ || $xml[$cline] =~ /^\s*$/ ) {
         $cline++;
         next;
      }
      if ( $xml[$cline] =~ /^\s*?<transport\s/i ) {
         check_transport($cluster);
         print "$xml[$cline]" if $debug;
      }
      else {
         warn "  Error: Invalid line in <Server> stanza at line $cline\n           ^$xml[$cline]";
         $badxml++;
      }
      $cline++;
   }
}

sub check_primaryservers {

   #     <PrimaryServers>
   #         <Server
   #     </PrimaryServers>
   whoami();
   $cline++;
   while ( $cline < @xml && $xml[$cline] !~ /^\s*?<\/primaryservers>/i ) {
      if ( $xml[$cline] =~ /^\s*?<!--/ || $xml[$cline] =~ /^\s*$/ ) {
         $cline++;
         next;
      }
      if ( $xml[$cline] =~ /^\s*?<server\s/i ) {
         check_pserver();
      }
      else {
         warn "  Error: Invalid line in <PrimaryServer> stanza at line $cline\n           ^$xml[$cline]";
         $badxml++;
      }
      $cline++;
   }
}

sub check_backupservers {

   #     <BackupServers>
   #         <Server
   #     </BackupServers>
   whoami();
   $cline++;
   while ( $cline < @xml && $xml[$cline] !~ /^\s*?<\/backupservers>/i ) {
      if ( $xml[$cline] =~ /^\s*?<!--/ || $xml[$cline] =~ /^\s*$/ ) {
         $cline++;
         next;
      }
      if ( $xml[$cline] =~ /^\s*?<server\s/i ) {
         check_pserver();
      }
      else {
         warn "  Error: Invalid line in <BackupServer> stanza at line $cline\n           ^$xml[$cline]";
         $badxml++;
      }
      $cline++;
   }

}

sub check_transport {

   #        <Transport
   #           <Property
   #        </TransporT>
   # <Transport Hostname="v10062" Port ="9999" Protocol ="https">
   whoami();
   my ($cluster) = @_;
   my $hostname;
   my $protocol;
   if ( $xml[$cline] =~ /hostname\=\"(.+?)\"/i ) {
      $hostname = $1;
   }
   else {
      warn "  Error: Malformed <Transport> at line $cline\n           ^$xml[$cline]";
      $badxml++;
   }
   if ( $xml[$cline] =~ /protocol\s*?\=\s*?\"(.+?)\"/i ) {
      $protocol = $1;
   }
   else {
      warn "  Error: Malformed <Transport> at line $cline\n           ^$xml[$cline]";
      $badxml++;
   }

   if ( $xml[$cline] =~ "\/>" ) {    # single line definition
      print " Return from check_transport at $cline\n" if $debug;
      return;
   }
   $cline++;
   while ( $cline < @xml && $xml[$cline] !~ /^\s*?<\/transport>/i ) {
      if ( $xml[$cline] =~ /^\s*?<!--/ || $xml[$cline] =~ /^\s*$/ ) {
         $cline++;
         next;
      }
      if ( $xml[$cline] =~ /^\s*?<property/i ) {
         check_tproperty( $cluster, $hostname );
      }
      else {
         warn "  Error: Invalid line in <Transport> stanza at line $cline\n           ^$xml[$cline]";
         $badxml++;
      }
      $cline++;
   }
   if ( $hostname && $protocol ) {
      $xmlhash{$cluster}{'hosts'}{$hostname}{'protocol'} = $protocol;
   }
   print " Return from check_transport at $cline\n" if $debug;
}

sub check_urigroup {

   #   <UriGroup
   #      <Uri
   #   </UriGroup>
   whoami();

   my $urigroup;
   my $uri = 0;

   if ( $xml[$cline] =~ /name\=\"(.+?)\"/i ) {
      $xmlhash{'urigroups'}{$1} = 1;
      print "$1\n" if $debug;
   }
   else {
      warn "  Error: Malformed <UriGroup> at line $cline\n           ^$xml[$cline]" if $details;
      $badxml++;
   }

   $cline++;
   while ( $cline < @xml && $xml[$cline] !~ /^\s*?<\/urigroup>/i ) {
      if ( $xml[$cline] =~ /^\s*?<!--/ || $xml[$cline] =~ /^\s*$/ ) {
         $cline++;
         next;
      }
      if ( $xml[$cline] =~ /^\s*?<uri\s/i ) {
         $uri = 1;
         check_uri();
      }
      else {
         warn "  Error: Invalid line in <Urigroup> stanza at line $cline\n           ^$xml[$cline]" if $details;
         $badxml++;
      }
      $cline++;
   }
   if ( $uri < 1 ) {
      warn "  Error: Empty <UriGroup> stanza at line $cline\n           ^$xml[$cline]" if $details;
   }
}

sub check_route {

   # <route ....../>
   whoami();
   my $servercluster;
   my $urigroup;
   my $virtualhostgroup;
   while ( $xml[$cline] !~ /\/>/ ) { # turn multiline statement into single line
      chomp $xml[$cline];
      $xml[$cline] = $xml[$cline] . $xml[ $cline + 1 ];
      splice( @xml, $cline + 1, 1 );
   }
   if ( $xml[$cline] =~ /servercluster\=\"(.+?)\"/i ) {
      $servercluster = $1;
   }
   else {
      warn "  Error: Malformed <Route> (missing servercluster) at line $cline\n           ^$xml[$cline]";
      $badxml++;
   }
   if ( $xml[$cline] =~ /urigroup\=\"(.+?)\"/i ) {
      $urigroup = $1;
   }
   else {
      warn "  Error: Malformed <Route> (missing urigroup) at line $cline\n           ^$xml[$cline]";
      $badxml++;
   }
   if ( $xml[$cline] =~ /virtualhostgroup\=\"(.+?)\"/i ) {
      $virtualhostgroup = $1;
   }
   else {
      warn "  Error: Malformed <Route> (missing virtualhostgroup) at line $cline\n           ^$xml[$cline]";
      $badxml++;
   }
   if ( $servercluster && $urigroup && $virtualhostgroup ) {
      $xmlhash{'routes'}{$servercluster}{'urigroup'} = $urigroup;
      $xmlhash{'routes'}{$servercluster}{'virtualhostgroup'} =
        $virtualhostgroup;
   }

}

sub check_uri {
   whoami();
   if ( $xml[$cline] =~ /^\s.*?name\=\".*?\"\/>\s*?$/i ) {
      return;
   }
   else {
      warn "  Error: Invalid line in <Uri> stanza at line $cline\n           ^$xml[$cline]" if $details;
      $badxml++;
   }
   return;
}

sub check_tproperty {
   whoami();
   my ( $cluster, $hostname ) = @_;
   if ( $xml[$cline] =~ /name\=\"keyring\"/i ) {
      if ( $xml[$cline] =~ /value\=\"(.+?)\"/i ) {
         $xmlhash{$cluster}{'hosts'}{$hostname}{'keyring'} = $1;
      }
   }
   return;
}

sub check_pserver {
   whoami();
   if ( $xml[$cline] =~ /name\=\".+?\"\/>\s*?$/i ) {
      return;
   }
   else {
      warn "  Error: Malformed <Server> at line $cline\n           ^$xml[$cline]" if $details;
      $badxml++;
   }
   return;
}

sub check_virtualhost {
   whoami();
   if ( $xml[$cline] =~ /name\=\".+?\:\d*\"\//i ) {
      return;
   }
   else {
      warn "  Error: Malformed <VirtualHost> at line $cline\n           ^$xml[$cline]" if $details;
      $badxml++;
   }
}

sub whoami {
   my @parms = caller(1);
   print $parms[3] . "\n" if $debug;

}

#------------------------------------------------------------------------------------------------
# update_dirstore: check if entry already exists and use dsUpdate if it does, use dsAdd to
# create it if it doesnt
#------------------------------------------------------------------------------------------------
sub update_dirstore {
   my ( $dirstore_key, $dirstore_entry_ref ) = @_;
   my %entry;
   dsGet( %entry, "software", $dirstore_key );
   if (%entry) {
      print "Updating $dirstore_key\n";
      dsUpdate( "SOFTWARE", $dirstore_key, %{$dirstore_entry_ref},
         type => "replace" );
   }
   else {
      print "Adding $dirstore_key\n";
      dsAdd( "software", $dirstore_key, %{$dirstore_entry_ref} )
        or die("failed to add $dirstore_key $dsErrMsg");
   }
}

