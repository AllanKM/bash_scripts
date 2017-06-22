#!/usr/local/bin/perl
use strict;
#----------------------------------------------------------------------------------
## Multithreaded drcat
##
##  1. Pause and prompt after each sequence.
##  2. Tivtask output written to log file
##  3. -v parm added to just run the verify commands
##  4. output log file suffixed with _test.log if running in test mode
##  5. add capability to run for a single selected role
##  6. add capability to run for a single selected server
##  7. Print and highlight syserr from tivtask
##  8. Multithreading of tivtasks
##----------------------------------------------------------------------------------
use warnings;
#
use POSIX qw( WNOHANG );
use EI::DirStore;
use XML::Simple;
use Data::Dumper;
use File::Path;
use Switch;
use Cwd qw(realpath);

my ( $test,$vfy,$action,$environment,$role_request,$server_request,$customer,$debug );

$test=1;                 # Run in test mode by default

my @valid_env = qw ( CI CS STAGE P1CS P2CS P3CS P2CI P3CI );
##################################################################
## Analyse the command line
###################################################################
while (@ARGV) {
   my $thisarg = shift @ARGV;
   if ( $thisarg =~ "-t" ) {
      $test=1;
   }
   elsif ( $thisarg =~ "-l" ) {
      $debug=1;
   }
   elsif ( $thisarg =~ "-d" ) {
      $test=0;
   }
   elsif ( $thisarg =~ "-v" ) {
      $vfy=1;
   }
   elsif ( $thisarg =~ /^start$/i ) {
     $action="Start";
   }
   elsif ( $thisarg =~ /^stop$/i ) {
      $action="Stop";
   }
   elsif ( grep (/$thisarg/i,@valid_env) ) {
      $environment=$thisarg;
   }
   elsif ( $thisarg =~ /.+?\..+?/ ) {        # something.something probably is a role name
      $role_request=$thisarg;
  }
   elsif ( $thisarg =~ /^\D{1,3}\d{3,5}\D?/ ) {  # look for a server name format cccnnnc ccnnnnc cnnnnn
      $server_request=$thisarg;
  }
   else {
    $customer=$thisarg;
	 }
}
if ( ! $environment || ! $customer || ! $action ) {
   print "Usage: sudo ./drcat.pl <-t|-d> <-v> Start|Stop customer environment\n
   -l output verbose logging
   -t run in test mode
   -v execute just verify commands
   -d execute the commmands\n" ;
   exit;
}

realpath($0)=~/^(.+?)\/bin\//i;              # find where this command was invoked from
my $drcatdir = $1;                           # make this our source directory
# ------------------------------------------------------------
# # setup tivtask command
# # -------------------------------------------------------------
 my $tivcmd="/Tivoli/scripts/tiv.task";
 $tivcmd="$drcatdir/bin/sym_tiv_task.sh" if $test;

# # -------------------------------------------------------------
# # ensure vars in correct case
# # -------------------------------------------------------------
 $action = ucfirst(lc($action));
 $customer = uc($customer);

 my $xmldir = "$drcatdir" . '/xml';           # where xml files are found

 my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

 my $timestamp=sprintf "%4d%02d%02d_%02d%02d%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec;

 my $xml = "$xmldir/" . lc("${environment}_${customer}.xml");
 my $logdir = lc("$drcatdir/cust/$customer/");
 if ( ! -d $logdir ) {
eval { mkpath($logdir) };
	if ($@) {
		print "Couldn't create $logdir: $@";
	}
}
 unlink <${logdir}task*>;

print "
         log: $logdir
      tivcmd: $tivcmd
         xml: $xml\n" if $debug;

my $cmdlist = XMLin( $xml, forceArray=>1 );
my %cmds;
my $server;
foreach my $role ( keys(%{$cmdlist -> {role} }) ) {
   if ( $role_request && $role_request !~ /$role/i ) {   # specific role requested and current role not it
      next;                                              # skip processing this role
   }
   my %results;
   my @expList=("role==$role");
   dsSearch(%results,"SYSTEM", expList => [@expList], attrs => ["realm"] );
   my @servers;
   foreach my $server ( keys(%results) ) {
      if ( env_to_realm($environment,$results{$server}{realm}[0])) {
         push @servers,$server;
      }
   }
	
   my $roleptr= $cmdlist->{role}->{$role};
   foreach my $middleware ( keys(%{ $roleptr->{'action'}->{$action}->{'middleware'} }) ) {
      my $middleware_ptr = $roleptr->{'action'}->{$action}->{'middleware'}->{$middleware};
      foreach my $version ( keys( %{$middleware_ptr->{version}})) {
         my $version_ptr = $middleware_ptr->{version}->{$version};
         my $version_seq=$version_ptr->{sequence};
         foreach my $app ( keys( %{$version_ptr->{application}}) ) {
            my $app_ptr = $version_ptr->{application}->{$app} ;
            my $app_seq=$app_ptr->{sequence};
            my $cmd= $app_ptr->{cmd};
            my $verify = $app_ptr->{verify};
            foreach my $server ( @servers ) {
               chomp $server;
               if ( $server_request && $server_request !~ /$server/i ) {
                  next;
               }
               $cmds{$version_seq}->{$app_seq}->{$server} -> {"cmds"} = [split(/;/,$cmd)];
					$cmds{$version_seq}->{$app_seq}->{$server} -> {"verify"} = [split(/;/,$verify)];
					$cmds{$version_seq}->{$app_seq}->{$server} -> {"comment"} = "$action $middleware $version";
					$cmds{$version_seq}->{$app_seq}->{$server} -> {"realm"} = $results{$server}{realm}[0];
            }
         }
      }
   }
}
print Dumper(\%cmds) if $debug;
#
# # finalised quickly!  Once a signal is received back
# # it finds the appropriate pipe and reads from it
#
$SIG{CHLD} = \&REAPER;
my $tid=0;
#-----------------------------------
# commands now ready for processing
#-----------------------------------
foreach my $mw_seq ( sort negativeonelast keys(%cmds) ) {
   do_app_seq($mw_seq,%{$cmds{$mw_seq}});
}


sub do_app_seq {
   my ($mw_seq,%cmds)=@_;
   foreach my $app_seq ( sort negativeonelast keys(%cmds) ) {
		print "Performing $action for $customer $environment $mw_seq $app_seq\n";
		if ( ! $vfy ) {
			do_servers(0,%{$cmds{$app_seq}});
			wait_procs();
		}
		
		do_servers(1,%{$cmds{$app_seq}});
		wait_procs();
      
		merge_logs($logdir,"${environment}_${mw_seq}_${timestamp}.log");
		
		print "\nThe entire tivtask output was logged to: ${logdir}${environment}_${mw_seq}_${timestamp}.log \n";
		print "Press <ENTER> when you are ready to continue and have reviewed the output: \n";
		my $response = <STDIN>;
		chomp $response;
   }
}

sub do_servers {
   my ($type,%cmds)=@_;
   foreach my $server ( sort keys(%cmds) ) {
		my $comment=$cmds{$server}{"comment"};
		my $realm=$cmds{$server}{"realm"};
		if ($type=="0") {
			$comment="Execute " . $comment;
			do_cmds($server,$realm,$comment,1,@{$cmds{$server}{"cmds"}});
		}
		else {
			$comment="Verify " . $comment;
			do_cmds($server,$realm,$comment,0,@{$cmds{$server}{"verify"}});
		}
   }
}

#
sub do_cmds {
	my ($server,$realm,$comment,$sep,@cmds)=@_;
	if ( ! $sep ) { 
		new_proc($server,$realm,$comment,$sep,@cmds);
	}
	else {
		for (my $i=0;$i<@cmds;$i++) {
			new_proc($server,$realm,$comment,$sep,$cmds[$i]);
		}
	}
}

sub new_proc {
	my ($server,$realm,$comment,$sep,@cmds)=@_;
	unless ( my $pid = fork()) {
		do_tivtask($tid,$server,$realm,$comment,@cmds);
	}
	$tid++;
}
#
# # Parent - wait for returned data
#  # To add - uses select to check channels!
#
#
sub wait_procs() {
	print "Tiv Tasks submitted, waiting for response\n";
	print "Wait procs\n" if $debug;
	while ( wait() != -1 ) {};
	print "Wait procs end\n" if $debug ;
	return;
}
#
sub REAPER {
	my $stiff;
	while (($stiff = waitpid(-1, &WNOHANG)) > 0) {
		print "Reaping $stiff\n" if $debug;
	}
	$SIG{CHLD} = \&REAPER;                  # install *after* calling waitpid
}

sub do_tivtask {
	my ($tid,$server,$realm,$comment,@cmds)=@_;
	print "taskid $tid\n" if $debug;
	my $srvfile="${logdir}task${tid}_${server}_srvfile.txt";
	open SRVFILE,">$srvfile";
	print SRVFILE "$server\n";
	close SRVFILE;

	my $logfile="${logdir}task${tid}_${server}.log";
	open LOGFILE, ">$logfile";

	my $cmdfile="${logdir}task${tid}_${server}_cmdfile.txt";
	open CMD,">$cmdfile";
	print CMD "\n\tHOSTNAME=`/bin/hostname -s`\n";
	print CMD "\tif [[ \"\$HOSTNAME\" == $server\* ]] ; then\n";
	print CMD "\t\t# $comment\n";
	foreach my $cmd ( @cmds ) {
		print CMD "\t\teval $cmd\n";
	}
	print CMD "\tfi\n";
	close CMD;
	my $tivname=realm_to_tiv($realm);
	my $printon=0;
	if (  $debug) {
		print "Thread $tid started for server: $server cmd: @cmds\nThread $tid ";
		print qq ($tivcmd -t 600 -f $srvfile -l $tivname $cmdfile 2>&1);
		print "\n";
	}
	open (CMD, "$tivcmd -t 600 -f $srvfile -l $tivname $cmdfile 2>&1 |" ) || die "cant fork $!" ;

	my $color;
	while ( <CMD> ) {
		print LOGFILE $_;
		if ( /Task Endpoint:/ ) {
			/:\s+?(.+?)\s/;
			print "\nServer:$1\n";
			next;
		}
		if ( /--Standard Output--/ ) {
			$color="\033[00m";
			$printon=1;
			next;
		}
		if ( /--Standard Error Output--/ ) {
			$color="\n\033[1;31m";
			next;
		}
		if ( /##################################################/ ) {
			$color="\033[00m";
			print "$color";
			$printon=0;
			next;
		}
		if ( $printon ) {
			print ${color}.$_;
		}
	}
	close LOGFILE;
	if ( ! $debug ) {
		unlink $cmdfile;
		unlink $srvfile;
	}
	print "$tid completed\n" if $debug ;
	exit();
}

################################################################
# Lookup TMR for server using realm
################################################################
sub realm_to_tiv {
   my ($realm)=@_;
   switch ($realm) {
      case /ei.p1|cs.p1/ { return "PX1"; }
      case /ei.p2|cs.p2/ { return "PX2"; }
      case /ei.p3|cs.p3/ { return "PX3"; }
      case /ci.p1/ { return "CI1"; }
      case /st.p1/ { return "STG"; }
      case /ecc.p1/{  return "ECC"; }
      case /ci.p2/ { return "CI2"; }
      case /ci.p3/ { return "CI3"; }
      else { warn "unable to determine TMR for $server $realm \n";
         return "";
      }
   }
}

#########################################################
# convert environment name to list of realms in dirstore
#########################################################
sub env_to_realm {
   my ($environment,$realm) = @_;
   $environment=uc($environment);
   my $realmlist = {
            CI => ['*ci*'],
            CS => ['*cs*','*ei*'],
            STAGE => ['*.st.p1'],
            P1CS => ['*.cs.p1','*.ei.p1'],
            P2CS => ['*.cs.p2','*.ei.p2'],
            P3CS => ['*.cs.p3','*.ei.p3'],
            P2CI => ['*.ci.p2'],
            P3CI => ['*.ci.p3'] };

   if ( defined $realmlist -> {$environment} ) {
      foreach my $env_realm ( @{$realmlist -> {$environment} } ) {
         $env_realm=~s/\./\\\./g;
         $env_realm=~s/\*/\.\*/g;
         if ( $realm=~/$env_realm/i ) { return 1; }
      }
   }
   return 0;
}


########################################################################################
# Sort commands into requested sequence  middleware sequence, server, command sequence
########################################################################################
sub negativeonelast {
  if ($a == -1 || $b == -1 )  {
    return $b <=> $a || $a cmp $b || $a <=> $b;
  } else {
    return $a<=>$b || $a cmp $b || $a <=> $b;
  }
}

sub merge_logs {
	my ($logdir,$log) = @_;
	$log="${logdir}${log}";
	print "merging to $log\n" if $debug;
	open "LOG",">$log" or die ("cannot open log $log for writing error: $!\n");
	print "listing $logdir\n" if $debug;
	opendir my($dh), "$logdir" or die "Couldn't open log dir $logdir error: $!";
	my @files = readdir $dh;
	closedir $dh;
	print scalar(@files)." files returned\n" if $debug;
	my %hash;
	
	@files=grep(/task\d{1,3}_\w+?\.log/,@files);
	print scalar(@files)." task files found\n" if $debug;
	foreach my $file (@files) {
		$file=~/task(\d+?)_(.+?)\./;
		$hash{$2}{$1}=1;
	}
	print Dumper(\%hash) if $debug;
	
	# sort the log files and copy into common log 
	foreach $server ( sort { $a cmp $b } keys(%hash) ) {
		foreach my $tasklog (sort {$a <=> $b} keys %{$hash{$server}} ) {
			$tasklog="${logdir}task${tasklog}_${server}.log";
			print "Source log: $tasklog\n" if $debug;
			open PART,"<$tasklog" or die ("cannot open $tasklog\n");
			while ( <PART> ) {
				print LOG $_;
			}
			close PART;
			
			unlink($tasklog) or die "cannot delete task file $tasklog $!\n";
		}
	}
	close LOG;
}
