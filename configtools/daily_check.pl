#!/usr/local/bin/perl
use Cwd qw(realpath);
use strict;
use warnings;
use POSIX qw( WNOHANG );
use MIME::Lite;
use XML::Simple;
use Data::Dumper;
use EI::DirStore;
use File::Basename;
my $debug = $ENV{'DEBUG'};
my %plex;
my %tmr_names = (
                 'ei.p1'  => 'PX1',
                 'cs.p1'  => 'PX1',
                 'ecc.p1' => 'ECC',
                 'ecc.z1' => 'ECC',
                 'ei.p2'  => 'PX2',
                 'cs.p2'  => 'PX2',
                 'ei.p3'  => 'PX3',
                 'cs.p3'  => 'PX3',
                 'ci.p1'  => 'CI1',
                 'ci.p2'  => 'CI2',
                 'ci.p3'  => 'CI3',
                 'cs.p5'  => 'PX5',
                 'ei.p5'  => 'PX5',
	  	 			  'sl.s1'  => 'SL',
                 'sl.s3'  => 'SL',
		 			  'sl.s5'  => 'SL'
);
my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
$year += 1900;
$mon++;
my $date = sprintf("%4d%02d%02D", ${year}, ${mon}, ${mday});

if ($#ARGV < 0) {
   print "Need to supply full path and name of xml file\n";
   exit;
}
my $xml = $ARGV[0];
if (!-e $xml) {
   print "$xml does not exist\n";
   exit;
}
elsif (!-r $xml) {
   print "Cannot open $xml for read\n";
   exit;
}

# where am I running from
realpath($0) =~ /^(.*)\//;
my $bindir = $1;
my $path   = dirname $xml;
my $file   = basename $xml;
my @used_role_sort;
chdir $path;
my ($name, $junk) = split(/\./, $file);

#my $workdir = '/fs/home/stevef/daily_check';
my $workdir = '/tmp';
my $outfile = "$workdir/${file}_${date}.sh";
my $report  = "$workdir/${file}_${date}.txt";
my $targets = "$workdir/${file}_${date}.servers";
open OUTFILE, ">$outfile" or die("couldnt open $outfile $!\n");
my $cmdlist = XMLin($xml, forceArray => [ 'role', 'mail', 'section', 'cmd', 'trigger' ], KeyAttr => undef);
my $title = $cmdlist->{"email"}->{'title'};
$title =~ s/%date%/$date/i;
print STDERR Dumper($cmdlist) if $debug;
my $mailto = $cmdlist->{"email"}->{'mail'};
print STDERR "Mailing to @{$mailto}\n";
my $hosts    = ();
my $allhosts = ();

#---------------------------------------------------------------------------------
# Generate script to be distributed
#---------------------------------------------------------------------------------
my $runtype;
if (defined $cmdlist->{'nohup'}) {
   $runtype = 1;
}
print OUTFILE qq (#!/bin/ksh);
if ($runtype) {
   print OUTFILE qq (
		if [ -z "\$1" ]; then
			cp \$0 ${report}_data.sh
			chmod +x ${report}_data.sh
			nohup ${report}_data.sh >${report}_data.txt 1 2>&1 &
			exit
		fi
	);
}
print OUTFILE qq (
function report {
      output1=`print -- \$output | tr -d "# \\n\\t"`
      if [ -n "\$output1" ]; then
         print -- "\$output" | taglines
      else
         print "No output !!!!" | taglines
      fi
}

function taglines {
   IFS=""
   print "\\\$CHECK\\\$,\$HOST,\$SECSORT,\$SORT,"CHECK",\$CHECK"
   print "\\\$CHECK\\\$,\$HOST,\$SECSORT,\$SORT,"TITLE",\$SECTION"
	while read x; do
		print "\\\$CHECK\\\$,\$HOST,\$SECSORT,\$SORT,\\"\$x\\""
	done
}
CTR=0
HOST=`hostname -s`
HOST=\${HOST\%\%e0}
print \$HOST
);

#-----------------------------------------------------------------------------------
# end of generated script template
#-----------------------------------------------------------------------------------
my $section_count=0;
foreach my $role (@{ $cmdlist->{"role"} }) {
   $hosts = ();

   #-----------------------------------
   # get list of affected servers
   #-----------------------------------
   my $rolename = $role->{"name"};
   my $limit    = $role->{"limit"};
   my $include  = $role->{"include"};
   my $exclude  = $role->{"exclude"};
   my $sections = $role->{"section"};
   $section_count+=scalar @{$sections};
   print STDERR "Start of role $rolename\n" if $debug;
   my $rsort = $role->{"sort"};
   if (!$rsort) { $rsort = 1; }

   # check for duplicate sort number
   if (defined $used_role_sort[$rsort]) {
      print STDERR "\tDuplicate role sort number $rsort detected\n" if $debug;
      my $max_sort = scalar @used_role_sort;
      my $i;
      for ($i = $rsort ; $i <= $max_sort + 1 ; $i++) {
         if (!defined $used_role_sort[$i]) {
            print STDERR "\tAssigning role sort value $i\n" if $debug;
            $rsort = $i;
            $used_role_sort[$i] = 1;
            last;
         }
      }
   }
   else {
      $used_role_sort[$rsort] = 1;
   }
   #=============================================================
   # Build a list of affected nodes 
   #=============================================================
   my %results;
   #=============================================================
   #  Using supplied role name and a dirstore lookup 
   #=============================================================
   if ($rolename &&  $rolename !~/(?:lssys|==|!=|[vws]\d{5})/ ) {    # lookup role
      my @expList;
      $role = uc($role);
      push @expList, "role==$rolename";
      push @expList, "nodestatus!=BAD";
      if ($limit) {
         @expList = (@expList, split(/ /, $limit));
      }
      dsSearch(%results, "SYSTEM", expList => [@expList], attrs => [ "realm", "eihostname", "systemtype" ]);
      print STDERR Dumper(\%results) if $debug;
      foreach my $host (keys %results) {
         print STDERR "$host is a " . $results{$host}{systemtype}[0]."\n" if $debug;
         #=============================================================
         # translate service nodes to real node 
         #=============================================================
         if ($results{$host}{systemtype}[0] eq 'SERVICE') {
            print STDERR "$host is a SERVICE node, " if $debug;
            push @{$results{$results{$host}{eihostname}[0]}{realm}},$results{$host}{realm}[0];
            $host = $results{$host}{eihostname}[0];
            
            print STDERR "using $host instead\n" if $debug;
         }
         $hosts->{$host}    = 1;
         $allhosts->{$host} = 1;
      }
   }
   #=============================================================
   # Use a lssys lookup
   #=============================================================
   if ( $rolename =~ /lssys|==|!=/ ) {
      my $cmd = 'lssys -lrealm,eihostname,systemtype -xcsv -e ';
      
      while ( $rolename =~ /([\w\.\*\-]+(?:\=\=|\!\=)[\w\.\*\-]+)\s?/ig ) {
         $cmd .= " $1";
      }      
      print STDERR "Using $cmd\n" if $debug;
      my @nodes = `$cmd`;
      print STDERR Dumper(\@nodes) if $debug;
      foreach my $node ( @nodes ) {
         next if $node =~/#/;
         chomp $node;
         my ($host,$realm,$eihostname,$systemtype) = split(/,/,$node);
         #=============================================================
         # translate service nodes to real node 
         #=============================================================         
         if ($systemtype eq 'SERVICE') {
            print STDERR "$host is a SERVICE node, " if $debug;
            push @{$results{$eihostname}{realm}},$realm;
            $host = $eihostname;
            print STDERR "using $host instead\n" if $debug;
         }
         else {
            print STDERR "$host is a \"$systemtype\"\n" if $debug;
         }
         $hosts->{$host}    = 1;
         $allhosts->{$host} = 1;
         push @{$results{$host}{'realm'}},$realm;
      }
   }
   #=============================================================
   # name is a node name(s) 
   #=============================================================
   if ( $rolename =~/[vws]\d{5}/ ) {
      print STDERR "Looking up specific node names $rolename\n" if $debug;
      my @nodes = split(/,/,$rolename);
      print STDERR Dumper(\@nodes) if $debug;
      my $rc = dsConnect();
      if ( $rc ) {
         my %dsresults;
         foreach my $host ( @nodes ) {
            print STDERR "dsGet $host\n" if $debug;
           	$rc = dsGet( %dsresults, 'system', $host, attrs => [ "realm", "eihostname", "systemtype" ] );
     	      print "Dirstore error: $dsErrMsg\n" if ! $rc;
     	      print STDERR Dumper(\%dsresults) if $debug;
     	      if ($dsresults{systemtype}[0] eq 'SERVICE') {
               print STDERR "$host is a SERVICE node, " if $debug;
               

               $host = $dsresults{eihostname}[0];
               print STDERR "using $host instead\n" if $debug;
            }  
            push @{$results{$host}{realm}},$dsresults{realm}[0];
     	      $hosts->{$host}    = 1;
            $allhosts->{$host} = 1;
         }
        	dsDisconnect(); 
      }
      print STDERR Dumper(\%results) if $debug;
   }
#=============================================================
# add in any extra include= nodes
#=============================================================
   if ($include) {
      my @inc = split(/[\s,\|]/, $include);
      foreach my $host (@inc) {
         $hosts->{$host}    = 1;
         $allhosts->{$host} = 1;
      }
   }
   #=============================================================
   #  remove any excluded nodes 
   #=============================================================
   if ($exclude) {
      my @exc = split(/[\s,\|]/, $exclude);
      foreach my $host (@exc) {
         delete $hosts->{$host};
      }
   }
   
   #=============================================================
   # %hosts hash should now has all the affected nodes
   #=============================================================
   my $runon;
   foreach my $host (sort keys %{$hosts}) {
      my ($realm) = $results{$host}{'realm'}[0] =~ /\.(.*)/;
      print STDERR "realm= $realm\n" if $debug;
      my $tmr = $tmr_names{$realm};
      $plex{$tmr} = {};
      $runon .= $host . "* | ";
   }
   $runon =~ s/\| $//;
   #=============================================================
   # output the case statement with commands to run
   #=============================================================
   print OUTFILE "case \$HOST in\n";
   print OUTFILE "\t$runon\)\n";
   my @used_section_sort;

   foreach my $sect (@{$sections}) {
#      $section_count++;
      my $check = $sect->{'check'};
      if ($sect->{name} =~ /{(.+?)}/) {
         $check = $1;
         $sect->{name} =~ s/{.+?}//;
      }
      my $sort = $sect->{'sort'};
      if (!$sort) { $sort = 1; }

      # check for duplicate sort number
      if (defined $used_section_sort[$sort]) {
         print STDERR "\t\tDuplicate section sort number detected\n" if $debug;
         my $max_sort = scalar @used_section_sort;
         my $i;
         for ($i = $sort ; $i <= $max_sort + 1 ; $i++) {
            if (!defined $used_section_sort[$i]) {
               print STDERR "\t\tAssigning section sort value $i\n" if $debug;
               $sort = $i;
               $used_section_sort[$i] = 1;
               last;
            }
         }
      }
      else {
         $used_section_sort[$sort] = 1;
      }
      my @cmds = $sect->{'cmd'};
      my $name = $sect->{'name'};
      print STDERR "\tsort info: role sort: $rsort\tsection sort: $sort\t$name\n" if $debug;
      print OUTFILE "\t\tSECSORT=$rsort\n";
      print OUTFILE "\t\tSORT=$sort\n";
      print OUTFILE "\t\tSECTION=\"$name\"\n";

      if ( $check ) {
         print STDERR "Writing script for ".$sect->{name}." with check ".$check."\n" if $debug;
         print OUTFILE "\t\tCHECK=\"$check\"\n";
      }
      else {
         print STDERR "Writing script for ".$sect->{name}." with unset check \n" if $debug;
         print OUTFILE "\t\tunset CHECK\n" ;
      }
      print OUTFILE "\t\toutput=\$(\n(\n";

      foreach my $cmd (@cmds) {
         foreach my $line (@{$cmd}) {
            print OUTFILE "\t\t$line\n";
         }
      }
      print OUTFILE "\t\t) 2\>\&1\n)\n";
      print OUTFILE "\t\treport\n";
      print STDERR "End of role\n" if $debug;
   }
   print OUTFILE "\t;;\n";
   print OUTFILE "\*\)\n;;\nesac\n";
}
print STDERR "Input: ".$section_count."\n" if $debug;
chmod 0755, $outfile;
open TARGETS, ">$targets" or die("Couldnt open $targets $!\n");
foreach my $host (keys %{$allhosts}) {
   print TARGETS "$host\n";
}
close TARGETS;
close OUTFILE;
chmod 0644, $targets;

#---------------------------------------------------------------
# submit to Tivoli
#---------------------------------------------------------------
exit if $debug;
$SIG{CHLD} = \&REAPER;
print STDERR "Submit jobs to Tivoli\n";
my $cat_cmd = "cat ";
foreach my $plex (keys %plex) {
   my $datafile = "$workdir/${file}_${date}_$plex.txt";
   $cat_cmd .= $datafile . " ";
   print "$plex being submitted\n";
   new_proc($plex, $outfile, $datafile);
}
&wait_procs();
print STDERR "$cat_cmd \| DAILY_CHECK_COUNT=$section_count ${bindir}/daily_check_report.pl \>$report\n";
my @output = `$cat_cmd | DAILY_CHECK_COUNT=$section_count ${bindir}/daily_check_report.pl >$report`;
if (exists $cmdlist->{'alert'}) {
   open REPORT, "<$report" or die "COuldnt open report $!\n";
   my $itmcmd;
   my $all;
   if (defined $cmdlist->{'alert'}->{'cmd'}) {
      $itmcmd = $cmdlist->{'alert'}->{'cmd'};
   }
   else {
      $itmcmd = '/opt/IBM/ITMscripts/ITM_to_Omni';
   }
   if (defined $cmdlist->{'alert'}->{'all'}) {
      $all = 1;
   }
   else {
      $all = 0;
   }
   print STDERR "Alerting enabled\n";
   my $alertmsg;
   if (defined $cmdlist->{'alert'}->{'msg'}) {
      $alertmsg = $cmdlist->{'alert'}->{'msg'};
   }
   else {
      $alertmsg = "Daily_check alert: one or more tests failed";
   }
   if (defined $cmdlist->{'alert'}->{'trigger'}) {
      if ($debug) {
         foreach my $trigger (@{ $cmdlist->{'alert'}->{'trigger'} }) {
            print STDERR "Trigger: $trigger\n" if $debug;
         }
      }
      my $seq = 0;
    readfile: foreach my $line (<REPORT>) {
         chomp($line);    # remove the newline from $line.
         my $savemsg = $alertmsg;
         foreach my $trigger (@{ $cmdlist->{'alert'}->{'trigger'} }) {
            if ($line =~ /$trigger/i) {
               my ($node) = split(/ /, $line);
               $node     =~ s/://g;
               $line     =~ s/^.+?:\s*//;
               $alertmsg =~ s/\$NODE/$node/ig;
               $alertmsg =~ s/\$MSG/$line/ig;
               print STDERR "$itmcmd -k ALERT$seq -h $node -G 12 -p 300 \"$alertmsg\"\n";
               system("$itmcmd", '-k', "ALERT$seq", '-h', "$node", "-G", "12", "-p", "300", "$alertmsg") if !$debug;
               $seq++;
               last readfile if !$all;    # stop on first error
               last;                      # only one alert for each failure
            }
         }
         $alertmsg = $savemsg;
      }
   }
   close REPORT;
}
if (!$runtype) {
   my $from;
   if (defined $cmdlist->{'email'}->{'from'}) {
      $from = $cmdlist->{'email'}->{'from'};
   }
   else {
      $from = 'daily_check@events.ihost.com';
   }
   $mailto = join(",", @{$mailto});
   local $/ = undef;
   open FILE, "$report" or die "Couldn't open file: $!";
   binmode FILE;
   my $data = <FILE>;
   close FILE;
   my $message = MIME::Lite->new(
                                 From    => $from,
                                 To      => $mailto,
                                 Subject => $title,
                                 Data    => $data
   );
   $message->attr("content-type" => "text/html");
   $message->send();
}
exit;

sub new_proc {
   my ($plex, $script, $outfile) = @_;
   unless (my $pid = fork()) {
      print STDERR "/Tivoli/scripts/tiv.task -t 600 -l $plex -f $targets $script >$outfile\n";
      my @output = `/Tivoli/scripts/tiv.task -t 600 -l $plex -f $targets $script >$outfile`;

      #my @output=`~/events/sym_tiv_task.sh -t 600 -l $plex -f $targets $script >>$outfile`;
      exit;
   }
}

sub wait_procs() {
   print STDERR "Tiv Tasks submitted, waiting for response\n";
   print STDERR "Wait procs\n";
   while (wait() != -1) { print STDERR "waiting\n"; sleep 1; }
   print STDERR "Wait procs end\n";
   return;
}

sub REAPER {
   my $stiff;
   while (($stiff = waitpid(-1, &WNOHANG)) > 0) {
      print "Reaping $stiff\n";
   }
   $SIG{CHLD} = \&REAPER;    # install *after* calling waitpid
}
