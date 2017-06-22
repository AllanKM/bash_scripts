#!/usr/local/bin/perl -w
#==============================================================================================
# Revision : $Revision: 1.6 $
# Source   : $Source: /cvsroot/hpodstools/lfs_tools/ihs/bin/itcs104_report.pl,v $
# Date     : $Date: 2014/09/01 07:49:50 $
#
# $Log: itcs104_report.pl,v $
# Revision 1.6  2014/09/01 07:49:50  steve_farrell
# Publish reports to all bzportal web servers
#
# Revision 1.3  2014/08/20 08:37:27  steve
# Working version with PX5 and CI1
#
# Revision 1.5  2014/05/02 12:33:12  steve_farrell
# add PX5 as a target for scans
#
# Revision 1.4  2014/01/23 14:06:11  steve_farrell
# Add support for CI1 and new IHS default install location
#
# Revision 1.3  2013/10/21 12:43:10  steve_farrell
# Handle dirstore lookup for servers with no defined roles
#
# Revision 1.2  2013/08/13 14:58:39  steve_farrell
# Fix errors created by IHS7 deploy leaving dead symlinks lying around hat the script didnt handle too well
#
# Revision 1.2  2013/08/13 12:06:26  steve
# Fix problem with non-existant config files pointed to by symlinks
#
# Revision 1.1  2012/05/16 14:00:36  steve_farrell
# Install new IHS ITCS104 scanning scripts
#
# Revision 1.5  2012/05/10 13:09:16  stevef
# working as of May 2012
#
# Revision 1.4  2012/04/10 09:45:01  stevef
# freeze at semi working level
#
# Revision 1.3  2012/04/05 10:13:35  stevef
# Working upto copy to webserver. Change of plan in next update :-(
#
# Revision 1.2  2012/03/08 13:00:29  stevef
# Multiple fixes, tested working against plex
#
use strict;

use Data::Dumper;
use EI::DirStore;
use MIME::Lite;
use File::Find;
use Date::Format;
use Sys::Hostname;
use Term::ANSIColor;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use FindBin;

use lib ("$FindBin::Bin/lib", "$FindBin::Bin/../lib");
use debug;

use TivTask;

my $sleep            = 300;
my $workdir          = glob '/tmp';
my $scriptdir        = "$FindBin::Bin";
my $auditdir         = '/fs/system/audit/ihs';
my $auditgpfsdir     = '/gpfs/system/audit/ihs';
my $ihs_itcs104_scan = "$scriptdir/ihs_itcs104_scan.pl";

#my $tivtask = "$scriptdir/tivtask.sh";    # simulated tivtask
my %results;
my %month_name_to_number =
  ('jan', 1, 'feb', 2, 'mar', 3, 'apr', 4, 'may', 5, 'jun', 6, 'jul', 7, 'aug', 8, 'sep', 9, 'oct', 10, 'nov', 11, 'dec', 12);
my @month_name = qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;

#
#goto REPORTS;
my $scan = EI::TivTask->new(
                            cmd     => [&scan_cmd],
                            delay   => 300,
                            workdir => $workdir
);
parse_parms($scan, \@ARGV);

print "Sumitting scans \n";
(%results) = $scan->execute();
report_failures(\%results);
waitscan:
print "waiting for scans to complete\n";
$scan->cmd_name('ihs_itcs104_scan.pl');
$scan->_wait_for_complete();

# copy from /fs/scratch to /fs/audit on CS gpfs servers
print "copy scans to audit\n";
my $copy_audit = EI::TivTask->new(
                                  cmd     => [&copy_audit],
                                  role    => 'gpfs.server.sync',
                                  async   => 1,
                                  delay   => 60,
                                  workdir => $workdir
);
(%results) = $copy_audit->execute();
report_failures(\%results);
REPORTS:
generate_reports();
COPYWEB:
print "copy reports to web\n";
# publish results to web
my $keystore='/lfs/system/tools/bNimble/etc/ei_gz_pubtool_shared.jks';
my $keystore_pw='cYsNM36S';

chdir '/fs/system/audit/ihs/';

my $pub = `/usr/java6/jre/bin/java -Djavax.net.ssl.trustStore=${keystore} -Djavax.net.ssl.trustStorePassword=${keystore_pw} -Djavax.net.ssl.keyStore=${keystore} -Djavax.net.ssl.keyStorePassword=${keystore_pw} -Xmx128M -jar /lfs/system/tools/bNimble/lib/Transmit.jar --Target-URL https://eibzpub.event.ibm.com:6329/Dist-bzptl3s/ei/apps/ihs_itcs104 --Preserve-Modified-Time --Site bzportal_full  data.js `;

chdir '/fs/system/audit/ihs/'. time2str("%b%Y",time);

$pub = ` /usr/java6/jre/bin/java -Djavax.net.ssl.trustStore=${keystore} -Djavax.net.ssl.trustStorePassword=${keystore_pw} -Djavax.net.ssl.keyStore=${keystore} -Djavax.net.ssl.keyStorePassword=${keystore_pw} -Xmx128M -jar /lfs/system/tools/bNimble/lib/Transmit.jar --Target-URL https://eibzpub.event.ibm.com:6329/Dist-bzptl3s/ei/apps/ihs_itcs104/details --Preserve-Modified-Time --Site bzportal_full  *fails* `;

print "Cleanup old files on webservers\n";
# clean up old detail files
my $cleanup_web = EI::TivTask->new(
                                  cmd     => [&cleanup_web],
                                  role    => 'WEBSERVER.CLUSTER.BZPRDCL002',
											 debug   =>1,
                                  async   => 1,
                                  delay   => 30,
                                  workdir => $workdir
);
(%results) = $cleanup_web->execute();
report_failures(\%results);
exit;

#=====================================================================================
# Create reports from audit files
#=====================================================================================
sub generate_reports {
   print "Generating reports\n";
   my @audit_dirs;    # unsorted list of directory names
   find sub {
      push @audit_dirs, "$File::Find::name"
        if (-d $File::Find::name && $File::Find::name =~ /[^\d]{3}\d{4}$/);
   }, $auditdir;
   my %audit_dirs;    # hash used for sorting
                      # create hash yyyymm => directory
                      # using NNNyyyy field from file name
                      # convert NNN to number and move after yyyy
   %audit_dirs = map { (sprintf "%4d%02d", substr($_, -4, 4), $month_name_to_number{ lc substr($_, -7, 3) }) => $_; } @audit_dirs;
   my (%scanned, %failed);

   # sort the hash and return last dir
   @audit_dirs = (map { $audit_dirs{$_} } sort keys %audit_dirs)[-1];

   #====================================================
   # Get results/fails files from last 2 audits
   #====================================================
   # %results->cust->role->server->config->errors
   #                                     ->failsfile
   #                             ->nodestatus
   #                             ->scandate
   my @files;
   debug("checking files in " . join(" ", @audit_dirs));
   find sub {
      push @files, "$File::Find::name\n"
        if ($File::Find::name =~ /ihs_itcs104_/);
   }, @audit_dirs;
   my %files;

   #==============================================================================
   # find the latest report files for each server
   #==============================================================================
   my %no_webserver_role;
   foreach my $file (@files) {
      chomp $file;

      #$ENV{'debug'}=0;
      my ($server, $scandate) = $file =~ /ihs_itcs104_([^_]+)_.*?(\d{1,2}[^\d]{3}20\d{2})/isxm;
      next if !$server;
      my ($role, $cust, $nodestatus) = server_info($server);
      next if !$role && !$cust && !$nodestatus;    # Not in dirstore so ignore it, probably old file lying around
      $no_webserver_role{$server} = undef if $role !~ /webserver\./i;
      $scanned{$server} = $role;

      #================================================
      # get config file name from scan file name
      #================================================
      my ($config) = $file =~ /_-(.*)/;
      if (!defined $config) {
         $config = 'shouldnt_get_this_report_script_bug';
      }
      else {
         $config =~ s/-/\//g;
         $config =~ s/(?:\.log|\.txt)$//;
         $config = '/' . $config;
      }

      #=========================
      # get count of errors
      #=========================
      my $count = 0;

      #debug("opening $file errors: $count");
      if ($file =~ /_fails_/i) {
         open FILE, '<', "$file";
         while (<FILE>) {

            #  debug($_);
            $count++ if $_ =~ /\*FAIL\*/;
         }
         close FILE;
      }

      #debug("close $file errors: $count");
      #=========================
      # remove path from file
      #=========================
      $file = (split /\//, $file)[-1];    # get just the filename without path
      my ($day, $month, $year) = $scandate =~ /(\d{1,2})([^\d]+)(\d+)/isxm;

      #      $ENV{'debug'}=1 if $server eq 'v10028';
      $scandate = sprintf "%4d%02d%02d", $year, $month_name_to_number{ lc $month }, $day;
      debug("\nfile: ${file}");
      debug("scandate: $scandate");
      debug("config:$config");

      # have we seen this server/config before
      if (defined $files{$cust}{$role}{$server}{$config}) {
         debug("seen $server $config before");
         $files{$cust}{$role}{$server}{'nodestatus'} = $nodestatus;
         if ($file =~ /_fails_/i) {
            if ($files{$cust}{$role}{$server}{$config}{'date'} <= $scandate) {
               debug("Saving the new data");
               $files{$cust}{$role}{$server}{$config} = {
                                                          date   => $scandate,
                                                          errors => $count,
                                                          fail   => $file
               };
            }
            else {
               debug("but its old data");
            }
         }
         else {
            debug("its not a fail file");
            if ($files{$cust}{$role}{$server}{$config}{'date'} < $scandate) {
               debug("but has newer data so removing old data");

               #               delete $files{$cust}{$role}{$server}{$config};
               #               delete $files{$cust}{$role}{$server} if keys %{$files{$cust}{$role}{$server}} < 2;
               #               delete $files{$cust}{$role} if ! keys %{$files{$cust}{$role}} ;
               #               delete $files{$cust} if ! keys %{$files{$cust}} ;
               $files{$cust}{$role}{$server}{$config}{'date'} = $scandate;
               delete $files{$cust}{$role}{$server}{$config}{'fail'};
               delete $files{$cust}{$role}{$server}{$config}{'errors'};
            }
            else {
               debug("and is old data anyway");
            }
         }
      }

      # new server/config
      else {
         $files{$cust}{$role}{$server}{'nodestatus'} = $nodestatus;
         if ($file =~ /_fails_/i) {
            debug("its a new fail file");
            $files{$cust}{$role}{$server}{$config} = {
                                                       date   => $scandate,
                                                       errors => $count,
                                                       fail   => $file
            };
         }
         else {
            debug("its a new summary file");
            $files{$cust}{$role}{$server}{$config}{'date'} = $scandate;
         }
      }
   }
   foreach my $cust (sort keys %files) {
      foreach my $role (sort keys %{ $files{$cust} }) {
         foreach my $server (sort keys %{ $files{$cust}{$role} }) {
            foreach my $config (sort keys %{ $files{$cust}{$role}{$server} }) {
               next if $config eq "nodestatus";
               if (!defined $files{$cust}{$role}{$server}{$config}{'fail'}) {
                  delete $files{$cust}{$role}{$server}{$config};
               }
               else {
                  $failed{$server} = undef;
               }
            }
            if (keys %{ $files{$cust}{$role}{$server} } == 1) {
               delete $files{$cust}{$role}{$server};
            }
         }
         if (keys %{ $files{$cust}{$role} } == 0) {
            delete $files{$cust}{$role};
         }
      }
      if (keys %{ $files{$cust} } == 0) {
         delete $files{$cust};
      }
   }
   my $scan_count   = keys %scanned;
   my $failed_count = keys %failed;

   #===============================================================
   # now have a hash of failure info
   # write out the data json file
   #===============================================================
   open HTML, ">", "$auditdir/data.js";
   print HTML "results={\n";
   my $cu = keys %files;
   foreach my $cust (sort keys %files) {
      print HTML "\t" x 1 . "\"$cust\":{\n";
      my $r = keys %{ $files{$cust} };
      foreach my $role (sort keys %{ $files{$cust} }) {
         print HTML "\t" x 2 . "\"$role\":{\n";
         my $s = keys %{ $files{$cust}{$role} };
         foreach my $server (sort keys %{ $files{$cust}{$role} }) {
            print HTML "\t" x 3 . "\"$server\":{\n";
            print HTML "\t" x 4 . "\"s\":\"$files{$cust}{$role}{$server}{'nodestatus'}\",\n";
            my $c = (keys %{ $files{$cust}{$role}{$server} }) - 1;
            foreach my $config (sort keys %{ $files{$cust}{$role}{$server} }) {
               next if $config eq "nodestatus";
               my ($scandate) = $files{$cust}{$role}{$server}{$config}{'fail'} =~ /fails_([^_]+)/i;
               printf HTML '"%s":"%s:%s:%d"',
                 $config,
                 $scandate,
                 $files{$cust}{$role}{$server}{$config}{'errors'},
                 $files{$cust}{$role}{$server}{$config}{'date'};
               print HTML "," if --$c;
               print HTML "\n";
            }
            print HTML "\t" x 3 . "}";    # closes $server
            print HTML "," if --$s;
            print HTML "\n";
         }
         print HTML "\t" x 2 . "}";       # closes $role
         print HTML "," if --$r;
         print HTML "\n";
      }
      print HTML "\t" x 1 . "}";          # closes $cust
      print HTML "," if --$cu;
      print HTML "\n";
   }
   print HTML "}\n";                      # closes json={

   # do dirstore lookup for all webservers;
   # compare dirstore list with @files server names
   my %servers;
   dsConnect();
   dsSearch(
            %servers, "system",
            expList => [ "role==WEBSERVER.*", "role!=retired" ],
            attrs   => [ "custtag",           "nodestatus" ]
   );
   dsDisconnect();
   my $dirstore_count = keys %servers;
   foreach my $file (sort @files) {
      my ($server) = $file =~ /ihs_itcs104_([^_]+)/;
      if (exists $servers{$server}) {
         delete $servers{$server};
      }
   }
   print HTML "missing = [\n";
   my $s = keys %servers;
   foreach my $server (sort keys %servers) {
      print HTML "[";
      print HTML "\"$server\",";
      print HTML "\"$servers{$server}{'custtag'}[0]\",";
      print HTML "\"$servers{$server}{'nodestatus'}[0]\"";
      print HTML "]";
      print HTML "," if --$s;
      print HTML "\n";
   }
   print HTML "]\n";
   my $no_webserver_role = keys %no_webserver_role;
   $s = keys %servers;
   print HTML "sc=\"$scan_count\"\ndc=\"$dirstore_count\"\nmc=\"$s\"\nfc=\"$failed_count\"\nrc=\"$no_webserver_role\"\n";
   print HTML "rcl=\"" . join(",", sort keys %no_webserver_role) . "\"\n";
   my ($min, $hour, $day, $month, $year) = (localtime)[ 1, 2, 3, 4, 5 ];
   my $today = sprintf "%4d/%02d/%02d %02d:%02d", $year + 1900, $month + 1, $day, $hour, $min;
   print HTML "report_date=\"$today\"\n";
   system("chmod 2755 $auditdir/data.js");
   system("chgrp eiadm $auditdir/data.js");
}
#=============================================================
# 
#=============================================================
sub server_info {
   my ($server) = @_;
   my %results;
   debug("dirstore lookup $server");
   dsConnect();
   dsGet(%results, 'system', $server, attrs => [qw(custtag role nodestatus)]);
   dsDisconnect();
   if (%results) {
      my $prefered = "";
      foreach my $role (sort @{ $results{'role'} }) {
         if ($role =~ /WEBSERVER\.CLUSTER/ismx) {    # use cluster role if found
            $prefered = $role;
            last;
         }
         elsif ($role =~ /WEBSERVER\./i) {
            if ($role !~ /WEBSERVER.EI.\d+/i) {
               $prefered = $role;                    # use webserver role but keep looking for better one
            }
         }
         elsif ($role =~ /WAS\./i && $prefered !~ /WEBSERVER/) {
            $prefered = $role;
         }
         elsif ($role =~ /MQ\./i && $prefered !~ /(?:WAS|WEBSERVER)/i) {
            $prefered = $role;
         }
         elsif ($prefered !~ /(?:WAS|WEBSERVER|MQ)/i) {
            $prefered = $role;
         }
      }
      debug("returning " . $prefered . " " . $results{'custtag'}[0] . " " . $results{'nodestatus'}[0] . "\n");
      return ($prefered, $results{'custtag'}[0], $results{'nodestatus'}[0]);
   }
   return undef;
}
#=============================================================
# 
#=============================================================
sub best_role {
   my (@roles) = @_;
   my $prefered;
   foreach my $role (@roles) {
      if ($role =~ /WEBSERVER.CLUSTER/i) {    # use cluster role if found
         $prefered = $role;
         last;
      }
      elsif ($role =~ /WEBSERVER\./i) {
         if ($role !~ /WEBSERVER.EI.\d+/i) {
            $prefered = $role;                # use webserver role but keep looking for better one
         }
      }
      elsif ($role =~ /WAS\./i && $prefered !~ /WEBSERVER/) {
         $prefered = $role;
      }
      elsif ($role =~ /MQ\./i && $prefered !~ /(?:WAS|WEBSERVER)/i) {
         $prefered = $role;
      }
      elsif ($prefered !~ /(?:WAS|WEBSERVER|MQ)/i) {
         $prefered = $role;
      }
   }
   debug("returning $prefered");
   return $prefered;
}

#=================================================================
# list servers for a role name
#=================================================================
sub role_list {
   my ($role) = @_;
   my %results;
   dsConnect();
   dsSearch(
            %results, "system",
            expList => ["role==$role"],
            attrs   => ["custtag"]
   );
   dsDisconnect();
   return keys %results;
}
#=============================================================
# 
#=============================================================
sub cleanup_web {
	print "Building cleanup web cmd\n";
   my $cmd_name = "cleanup_web.sh";
   return (
      $cmd_name, <<END_CLEANUP_WEB_CMD
   #!/bin/ksh
find /projects/eibzpt/content/ei/apps/ihs_itcs104/details -mtime +60 -exec rm -f {} \\\;
END_CLEANUP_WEB_CMD
   );
}
#=============================================================
# 
#=============================================================
sub copy_audit {
   my $cmd_name = "copy_scan_to_audit.sh";
   return (
      $cmd_name, <<END_SCAN_COPY_CMD
   #!/bin/ksh
   month=`date +"%b%Y"`
   auditdir="$auditgpfsdir/\$month/"
   hostname=\`hostname -s\`

   for target in \$(lssys -qe role==gpfs.server.sync | grep -E "^v"); do
      for dir in \$(ls /gpfs/scratch); do
         srcdir=/gpfs/scratch/\$dir/ihs_itcs104
         if [ -e \$srcdir/ihs_itcs104* ]; then
            if [[ "\$target" == "\$hostname" ]]; then
               if [ ! -d \$auditdir ]; then
                  print "making target directory"
                  mkdir -p \$auditdir
                  chmod -R 2770 \$auditdir
                  chown -R root:eiadm \$auditdir
               fi
               print "copy \$srcdir/ihs_itcs104_* \$auditdir"
               cp \$srcdir/ihs_itcs104_* \$auditdir
            else
               print "rsync \$srcdir/ihs_itcs104_* \$target:\$auditdir"
               rsync -avc --recursive --exclude="*~" \$srcdir/ihs_itcs104_* \$target:\$auditdir
            fi
         fi
      done
   done
   for dir in \$(ls /gpfs/scratch); do
      srcdir=/gpfs/scratch/\$dir/ihs_itcs104
      if [ -e \$srcdir ]; then
         print "Cleaning \$srcdir/ihs_itcs104"
         rm -f \$srcdir/ihs_itcs104_*
         rm -f \$srcdir/_*
      fi
   done 
END_SCAN_COPY_CMD
   );
}
#=============================================================
# 
#=============================================================
sub scan_cmd {
   my $cmd_name = "itcs104_scan_cmd.sh";
   return (
      $cmd_name, <<END_SCAN_CMD
   #!/bin/ksh
   # check if I'm already running
   cmd='ihs_itcs104_scan.pl'
   running=\$(ps -eo "%a" | grep \$cmd | grep -vc grep)
   if [ \$running -eq 0 ]; then
      if [ -e $ihs_itcs104_scan ]; then  
         $ihs_itcs104_scan
      else
         print -u2 -- "$ihs_itcs104_scan does not exist"
      fi
   else
      print -u2 -- "IHS scan already running"
   fi
END_SCAN_CMD
   );
}
#=============================================================
# 
#=============================================================
sub parse_parms {
   my ($tivtask, $parms) = @_;
   my @plex = qw/PX1 ECC PX2 CI1 CI2 PX3 CI3 PX5/;    # default plex environments to scan
   my %plex = map { $_ => 1 } @plex;
   foreach my $arg (@$parms) {
      debug($arg);
      if ($arg =~ /webserver\./i) {                   # matches a role name
         debug("role $arg");
         $tivtask->role($arg);
      }
      elsif ($arg =~ /(?:[vwz]\d{5}|[adg][ct]\d{4}[a-c])/i) {    # matches server name v10000 dt1201b etc
         debug("Add server $arg");
         $tivtask->servers($arg);
      }
      elsif ($plex{ uc $arg }) {
         debug("Add plex $arg");
         $tivtask->plex(uc $arg);                                # matches a plex name
      }
      else {
         print "Dont know what to do with \"$arg\"\n";
      }
   }
}
#=============================================================
# 
#=============================================================
sub report_failures {
   my $results = shift;

   # report any failures to run here
   foreach my $server (keys %$results) {
      if (defined $results->{$server}{'STDERR'}) {
         print STDERR "Failures on $server\n";
         foreach my $line (@{ $results->{$server}{'STDERR'} }) {
            print STDERR $line;
         }
      }
   }
}
