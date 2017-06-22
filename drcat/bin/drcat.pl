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
use strict;

#
use POSIX qw( WNOHANG );
use EI::DirStore;
use XML::Simple;
use Data::Dumper;
use File::Path;
use Term::ANSIColor qw(:constants);


use Cwd qw(realpath);
my $delay=30;
my @valid_env = qw ( P1CS P2CS P3CS P2CI P3CI ECC );
my $tid;
my $going;
my (%cmds,%cmdinfo);
my $server;
my ( $cmdfile, $srvfile, $chkfile, $getfile );
my %submitted_to_nodes;
my %retrieved_nodes;

my @not_error=(
   '/lfs/system/.* Done',
   'percentage OK',
   'Update /lfs/system/bin/check_was'
);

my @error_strings=(
   '^####',
   '[Ee]rror'
);

my $lognumber=0;

my ( $test, $vfy, $action, $environment, $role_request, $server_request,
   $customer, $debug );

$test = 1;    # Run in test mode by default

##################################################################
## Analyse the command line
###################################################################
while (@ARGV) {
   my $thisarg = shift @ARGV;
   if ( $thisarg =~ "-t" ) {
      $test = 1;
   }
   elsif ( $thisarg =~ "-l" ) {
      $debug = 1;
   }
   elsif ( $thisarg =~ "-d" ) {
      $test = 0;
   }
   elsif ( $thisarg =~ "-v" ) {
      $vfy = 1;
   }
   elsif ( $thisarg =~ /^start$/i ) {
      $action = "Start";
   }
   elsif ( $thisarg =~ /^stop$/i ) {
      $action = "Stop";
   }
   elsif ( grep ( /$thisarg/i, @valid_env ) ) {
      $environment = $thisarg;
   }
   elsif ( $thisarg =~ /.+?\..+?/ )
   {    # something.something probably is a role name
      $role_request = $thisarg;
      debug("role request: $role_request");
   }
   elsif ( $thisarg =~ /^\D{1,3}\d{3,5}\D?/ )
   {    # look for a server name format cccnnnc ccnnnnc cnnnnn
      $server_request = $thisarg;
      debug("server request: $server_request");
   }
   else {
      $customer = $thisarg;
   }
}
if ( !$environment || !$customer || !$action ) {
   print "Usage: sudo ./drcat.pl <-t|-d> <-v> Start|Stop customer environment\n
   -l output verbose logging
   -t run in test mode
   -v execute just verify commands
   -d execute the commmands\n";
   exit;
}

realpath($0) =~ /^(.+?)\/bin\//i;    # find where this command was invoked from
my $drcatdir = $1;                   # make this our source directory

# ------------------------------------------------------------
# setup tivtask command
# -------------------------------------------------------------
my $tivcmd = "/Tivoli/scripts/tiv.task";
$tivcmd = "$drcatdir/bin/sym_tiv_task.sh" if $test;
$delay=5 if $test;

# -------------------------------------------------------------
# ensure vars in correct case
# -------------------------------------------------------------
$action   = ucfirst( lc($action) );
$customer = uc($customer);

# -------------------------------------------------------------
# create file names
# -------------------------------------------------------------
my $xmldir = "$drcatdir" . '/xml';    # where xml files are found
my $xml    = "$xmldir/" . lc("${environment}_${customer}.xml");

my $logdir = lc("$drcatdir/cust/$customer/");
if ( !-d $logdir ) {
   eval { mkpath($logdir) };
   if ($@) {
      print "Couldn't create $logdir: $@";
   }
}
unlink <${logdir}task*>;

my $tivname = env_to_tmr($environment);

my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =  localtime(time);

my $timestamp = sprintf "%4d%02d%02d_%02d%02d%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;



#===============================================================================
# read XML and build %cmds hash of commands to execute
#===============================================================================
print "
         log: $logdir
      tivcmd: $tivcmd
         xml: $xml\n" if $debug;

my $cmdlist = XMLin( $xml, forceArray => 1 );
foreach my $role ( keys( %{ $cmdlist->{role} } ) ) {
   if ( $role_request && $role_request !~ /$role/i ) {    # specific role requested and current role not it
      next;    # skip processing this role
   }
   my %results;
   my @expList = ("role==$role");
   debug(Dumper(\@expList));
   dsSearch( %results, "SYSTEM", expList => [@expList], attrs => ["realm"] );
   debug(Dumper(\%results));
   my @servers;
   foreach my $server ( keys(%results) ) {
      if ( env_to_realm( $environment, $results{$server}{realm}[0] ) ) {
         if ( $server_request && $server_request !~ /$server/i ) {
            next;
         }
         push @servers, $server;
      }
   }
 
   
   debug(Dumper( \@servers ));
   my $roleptr = $cmdlist->{role}->{$role};
   foreach my $middleware ( keys( %{ $roleptr->{'action'}->{$action}->{'middleware'} } ) )   {
      my $middleware_ptr =  $roleptr->{'action'}->{$action}->{'middleware'}->{$middleware};
      foreach my $version ( keys( %{ $middleware_ptr->{version} } ) ) {
         my $version_ptr = $middleware_ptr->{version}->{$version};
         my $version_seq = $version_ptr->{sequence};
         
         foreach my $node( @servers ) {
            $cmdinfo{$version_seq}->{"servers"}{$node}=defined;
         }
         
         $cmdinfo{$version_seq}->{"apps"}->{$middleware}=defined;
         
         foreach my $app ( keys( %{ $version_ptr->{application} } ) ) {
            my $app_ptr = $version_ptr->{application}->{$app};
            my $app_seq = $app_ptr->{sequence};
            my $cmd     = $app_ptr->{cmd};
            if ( $cmd=~/\bsudo\b/ ) {
               $cmd=~s/\bsudo\b/export SUDO_USER="root";/g;
            }
    
                    
            my $verify  = $app_ptr->{verify};
            if ( $verify=~/\bsudo\b/ ) {
               $verify=~s/\bsudo\b/export SUDO_USER="root";/g;
            }
            
            foreach my $server (@servers) {
               chomp $server;
               if ( $server_request && $server_request !~ /$server/i ) {
                  next;
               } 
               
               my $cmdptr=\@{$cmds{$version_seq}->{$server}->{$app_seq}->{"cmds"}};
               
               if ( scalar @{$cmdptr} >0 ) {
                  @{$cmdptr} = ( @{$cmdptr}, split( /;/, $cmd ) );
               }
               else {
                  @{$cmdptr} = ( split( /;/, $cmd ) );
               }
               
               for( my $l=0;$l<scalar @{$cmdptr}; $l++ ) {
                  if ( $cmdptr->[$l]=~/SUDO_USER/ ) {
                        splice @{$cmdptr},
                        $l+1,
                        1,
                        ($cmdptr->[$l+1],'unset SUDO_USER');
                     $l+=2;
                  }
               }
               
               $cmdptr=\@{$cmds{$version_seq}->{$server}->{$app_seq}->{"verify"}};
               if ( scalar @{$cmdptr} >0 ) {
                  @{$cmdptr} = ( @{$cmdptr}, split( /;/, $verify ) );
               }
               else {
                  @{$cmdptr} = ( split( /;/, $verify ) );
               }
               
               for( my $l=0;$l<scalar @{$cmdptr}; $l++ ) {
                  if ( $cmdptr->[$l]=~/SUDO_USER/ ) {
                  
                     splice @{$cmdptr},
                        $l+1,
                        1,
                        ($cmdptr->[$l+1],'unset SUDO_USER');
                     $l+=2;
                  
                  
                  }
               }
             
               
               $cmds{$version_seq}->{$server}->{$app_seq}->{"comment"} = "$role $action $middleware $version step:$version_seq sub_step:$app_seq";
               $cmds{$version_seq}->{$server}->{$app_seq}->{"realm"} = $results{$server}{realm}[0];
            }
         }
      }
   }
}
debug(Dumper( \%cmds ));
debug(Dumper( \%cmdinfo ));

#-----------------------------------
# commands now ready for processing
# %cmds now contains all the commands in major/minor/host sequence
#-----------------------------------

#=================================================
# Loop thru each middleware def in sequence
# main processing loop
#=================================================
foreach my $mw_seq ( sort negativeonelast keys(%cmds) ) {
   %retrieved_nodes=();
   print BOLD, WHITE, "Doing $action sequence $mw_seq ",
      join(",",  sort( keys(  %{$cmdinfo{$mw_seq}{'apps'}} ) ) ),
      " on ",
      join(",",keys(%{$cmdinfo{$mw_seq}{'servers'}})),"\n",RESET;
   
   create_tiv_task_scripts( \%{ $cmds{$mw_seq} }, $mw_seq );
   
   send_to_tivoli();
   
   wait_for_completion($mw_seq);
   merge_logs($mw_seq);
   my $i=0;
   print BOLD, YELLOW, "\nSequence result summary\n=======================\n";
   foreach my $node ( sort keys(%submitted_to_nodes) ) {
      
      eval{
         print BOLD, RED, "$node\t",BOLD, YELLOW,
         "max rc: $submitted_to_nodes{$node}{'maxrc'}\t",
         "errors: $submitted_to_nodes{$node}{'errs'}\t\t", RESET;
   };
      $i++;
      if ( $i%2==0 ) { 
         print "\n"; 
      } 
   }
   print "\n\n";
   my $response;
   while ( uc($response) ne "C" ) {
      print BOLD, WHITE, "Enter L to view log or C to continue or Q to quit: ", RESET;
      $response = <STDIN>;
      chomp $response;
      if ( uc($response) eq "Q" ) {
         exit;
      }
      if ( uc($response) eq "L" ) {
         system("vi", "${logdir}${customer}_${action}_${environment}_${mw_seq}.log");
      }
   }
   
   %retrieved_nodes=();
   %submitted_to_nodes=();
   # REMOVE WORK FILES  
   unlink glob "${logdir}*servers.txt";
   unlink glob "${logdir}*check.sh";
   unlink glob "${logdir}*get.sh";
   
}

#=================================================
# Loop thru each host in sequence
#=================================================
sub create_tiv_task_scripts {
   my ( $mw_ref, $mw_seq ) = @_;
   debug($mw_seq);
   create_files($mw_seq);
   foreach my $host ( sort keys( %{$mw_ref} ) ) {
      add_commands_to_script( \%{ $mw_ref->{$host} }, $host );
   }
   close CMDFILE;
   close SRVFILE;
}

#=================================================
# Loop thru each host def in sequence
#=================================================
sub add_commands_to_script {
   my ($host_ref,$host) = @_;
   debug();
   print CMDFILE qq/
if [[ "\$host" = ${host}* ]]; then
         /;
   print SRVFILE "$host\n";
   foreach my $app_seq ( sort negativeonelast keys( %{$host_ref} ) ) {
      
      $submitted_to_nodes{$host} = defined;
      my $app_ref = \%{ $host_ref->{$app_seq} };
      my $comment = $app_ref->{'comment'};
      my $cmd_list = join( "\n\tprint \"rc=\"\$?\n\t", @{ $app_ref->{'cmds'} } );
      my $verify_list = join( "\n\tprint \"rc=\"\$?\n\t", @{ $app_ref->{'verify'} } );


      #--------------------
      if ( !$vfy ) {
         print CMDFILE qq/
   print -- "-------- $comment -------"
   $cmd_list
   print "rc="\$?
            /;
      }
      print CMDFILE qq/
   print -- "------------------------------------- Verify steps -----------------------------------"
   $verify_list
   print "rc="\$?
         /;
   }
   print CMDFILE "\nfi\n";
}
#===============================================================================
# Send sequence commands to tivoli for execution
#===============================================================================
sub send_to_tivoli {
   debug( qq/${tivcmd}, "-t", "600", "-f", "$srvfile", "-l", "$tivname", "$cmdfile"/ );
   open "SUBLOG",">","${cmdfile}.log";
   open( TIV, "${tivcmd} -t 600 -f $srvfile -l $tivname $cmdfile 2>&1 |" );
   local $Term::ANSIColor::AUTORESET = 1;
   my $show = 0;
   my $ep;
   #==========================================================================
   # Show any errors in submitting the scripts
   # =========================================================================
   while (<TIV>) {
      print SUBLOG $_;
      if (/Task Endpoint:/) {
         ( $a, $b, $ep ) = split( " ", $_ );
         next;
      }
		if ( /No nodes matched selection criteria/ ) {
			chomp;
			print RED, "##### $tivname reports $_ cannot continue\n", RESET;
			exit;
		}
      if (/^(.+?) \(Endpoint\)/) {
         $ep   = $1;
         $show = 1;
      }
      if (/------Standard Output------/) {
         $show = 1;
         next;
      }
      if (/------Standard Error Output------/) {
         $show = 1;
         next;
      }
      if (/############################################################################/ ) {
         $show = 0;
         next;
      }
      if ($show) {
         print RED, "$ep: ",BLUE, "$_", RESET;       
      }
   }
   close TIV;
   close SUBLOG;
}

#===============================================================================
# Wait for asynchronous commands to complete by sending tiv scripts to 
# query if drcat_{seq}_cmds.sh is running
#===============================================================================
sub wait_for_completion {
   my ( $mw_seq) =@_;
   debug("Waiting for :".join(",",keys(%submitted_to_nodes )));

   # =======================================================================
   # wait for cmds to complete
   # =======================================================================
   my $active = 1;

   local $SIG{USR1} = "doneit";

   # a) submitted_to_nodes has list of servers check was sent to
   # b) build list of nodes its still running on
   # subtract b from a to get list of nodes its complete on
   # c) retrieved_nodes has list of nodes data retrieved from
   # d) subtract c from b to get list to send retrieve command to
   # send tiv cmd, show output, append to log file
   #  add d) to c)
   # repeat until d is null
   
   while ( $active == 1 ) {
      if ( scalar(keys(%retrieved_nodes)) == scalar(keys(%submitted_to_nodes)) ) {
         # wait for recover to complete 
         while ( $tid != 0 ) {
            sleep 5;
         }
         $active = 0;
      }
      else {
         debug("sleep");
         sleep $delay;
         
         # a) list of nodes we sent commands to
         my %complete_nodes = %submitted_to_nodes;
   
         # b) build list of nodes its still running on
         my $running_ref = get_active_nodes();

         # c) subtract b from a to get list of nodes its complete on
         foreach my $node ( keys %{$running_ref} ) {
            delete $complete_nodes{$node};
         }

         # subtract c from b to get list to send retrieve command to
         foreach my $node ( keys(%retrieved_nodes) ) {
            delete $complete_nodes{$node};
         }
         
    #     foreach my $node ( keys(%complete_nodes) ) {
    #        $retrieved_nodes{$node}=defined;
    #     }
         debug(" sent to   : ".join(",",keys(%submitted_to_nodes)));
         debug(" running   : ".join(",",keys(%{$running_ref})));
         debug(" retrieved : ".join(",",keys(%retrieved_nodes)));
         debug(" complete  : ".join(",",keys(%complete_nodes)));
         #  complete_nodes now contains list of nodes to recover the log from
         if ( scalar(keys(%complete_nodes)) ) {
            recover_log($mw_seq, \%complete_nodes );  
         }
      }
   }
}

#===============================================================================
# Interupt from asynchronous log recover to tell us its finished  
#===============================================================================
sub doneit {
   
   close SHY;
   debug("Retrieved nodes=".Dumper(\%retrieved_nodes));
   while (<RHX>) {
      chomp;
      my ($node,$maxrc,$errs)=split(":",$_);
      $retrieved_nodes{$node}=defined;
      $submitted_to_nodes{$node}= {'maxrc'=> $maxrc,
         'errs'=>$errs };
   }
   debug("Retrieved nodes=".Dumper(\%retrieved_nodes));
   close RHX;
   my $stiff = waitpid( $tid, &WNOHANG );
   $tid = 0;
}

#===============================================================================
# Use tiv to send command to query if actions have completed
# return list of nodes commands still running on  
#===============================================================================
sub get_active_nodes {
   debug();
   my $ep;
   my %running;
   open( TIV, "$tivcmd -t 600 -f $srvfile -l $tivname $chkfile 2>&1 |" );

   while (<TIV>) {
      if (/Task Endpoint/) {
         ( $a, $b, $ep ) = split( " ", $_ );
      }
      if (/drcat_\d{1,3}_cmds.sh/) {
         print STDERR BOLD YELLOW "##### still running on $ep\n";
         $running{$ep} = defined;
      }
   }
   return \%running;
}

#===============================================================================
# Create the scripts to be send to nodes  
#===============================================================================
sub create_files {
   my ($mw_seq) = @_;
   debug($mw_seq);

   #-------------------------------------------------------------------
   # create the script to be submitted by tivoli
   #-------------------------------------------------------------------
   $cmdfile = "${logdir}${customer}_${action}_${environment}_${mw_seq}_cmds.sh";
   $srvfile = "${logdir}${customer}_${action}_${environment}_${mw_seq}_servers.txt";
   $chkfile = "${logdir}${customer}_${action}_${environment}_${mw_seq}_check.sh";
   $getfile = "${logdir}${customer}_${action}_${environment}_${mw_seq}_get.sh";

   open "SRVFILE", ">", "$srvfile";
   open "CMDFILE", ">", "$cmdfile";
   open "CHKFILE", ">", "$chkfile";
   open "GETFILE", ">", "$getfile";

   #------------------------
   print CMDFILE qq (#!/bin/ksh
# move script to /tmp and re-execute with nohup
if [ -z "\$1" ]; then
   cp \$0 /tmp/drcat_${mw_seq}_cmds.sh
   chmod +x /tmp/drcat_${mw_seq}_cmds.sh
   nohup /tmp/drcat_${mw_seq}_cmds.sh 1 >/tmp/drcat_${mw_seq}_output.txt 2>&1 &
   print -u2 --  "DRCAT running: " `ps -ef | grep "/tmp/drcat_" | grep -v grep `
   exit
fi
host=`hostname -s`
   );

   print CHKFILE qq(#!/bin/ksh
ps -ef | grep drcat_${mw_seq}_cmds.sh | grep -v grep
      );
   close CHKFILE;

   print GETFILE qq(#!/bin/ksh
cat /tmp/drcat_${mw_seq}_output.txt
   );
   close GETFILE;
}

################################################################
# Lookup TMR for server using realm
################################################################
sub realm_to_tiv {
   debug();
   my ($realm) = @_;
   if ( $realm =~ /ei.p1|cs.p1/ ) {
      return "PX1";
   }
   if ( $realm =~ /.z1/ ) {
      return "ECC";
   }
   elsif ( $realm =~ /ei.p2|cs.p2/ ) {
      return "PX2";
   }
   elsif ( $realm =~ /ei.p3|cs.p3/ ) {
      return "PX3";
   }
   elsif ( $realm =~ /ci.p1/ ) {
      return "CI1";
   }
   elsif ( $realm =~ /st.p1/ ) {
      return "STG";
   }
   elsif ( $realm =~ /ecc.p1/ ) {
      return "ECC";
   }
   elsif ( $realm =~ /ci.p2/ ) {
      return "CI2";
   }
   elsif ( $realm =~ /ci.p3/ ) {
      return "CI3";
   }
   else {
      warn "unable to determine TMR for $server $realm \n";
      return "";
   }
}

#########################################################
# convert environment name to list of realms in dirstore
#########################################################
sub env_to_realm {
   debug();
   my ( $environment, $realm ) = @_;
   $environment = uc($environment);
   my $realmlist = {
      CI    => ['*ci*'],
      CS    => [ '*cs*', '*ei*' ],
      STAGE => ['*.st.p1'],
      ECC   => ['*.z1'],
      P1CS  => [ '*.cs.p1', '*.ei.p1' ],
      P2CS  => [ '*.cs.p2', '*.ei.p2' ],
      P3CS  => [ '*.cs.p3', '*.ei.p3' ],
      P2CI  => ['*.ci.p2'],
      P3CI  => ['*.ci.p3']
   };

   if ( defined $realmlist->{$environment} ) {
      foreach my $env_realm ( @{ $realmlist->{$environment} } ) {
         $env_realm =~ s/\./\\\./g;
         $env_realm =~ s/\*/\.\*/g;
         if ( $realm =~ /$env_realm/i ) { return 1; }
      }
   }
   return 0;
}

#########################################################
# convert environment name to TMR
#########################################################
sub env_to_tmr {
   
   my ( $environment ) = @_;
   debug();
   $environment = uc($environment);
   my $realmlist = {
      ECC   => 'ECC',
      P1CS  => 'PX1',
      P2CS  => 'PX2',
      P3CS  => 'PX3',
      P2CI  => 'CI2',
      P3CI  => 'CI3'
   };
   debug($realmlist->{$environment});
   return $realmlist->{$environment};
}

########################################################################################
# Sort commands into requested sequence  middleware sequence, server, command sequence
########################################################################################
sub negativeonelast {
   if ( $a == -1 || $b == -1 ) {
      return $b <=> $a || $a cmp $b || $a <=> $b;
   }
   else {
      return $a <=> $b || $a cmp $b || $a <=> $b;
   }
}

#===============================================================================
# Show debugging messages
#===============================================================================
sub debug {
   my ($msg) = @_;
   return if !$debug;

   my ( $a, $b, $no, $subroutine ) = caller(1);
   if ( !$subroutine ) {
      ( $a, $b, $no, $subroutine ) = caller(0);
   }
   local $Term::ANSIColor::AUTORESET = 1;
   $no = sprintf( "%04s", $no );
   if ($msg) {
      $msg =~ s/\n/\n\t\t\t/g;
      print STDERR BOLD RED "$no $subroutine :$msg\n";
   }
   else {
      print STDERR BOLD RED "$no $subroutine :\n";

   }
}

#===============================================================================
# Merge the logs from each recover to a single sequence log  
#===============================================================================
sub merge_logs {
   debug();
   my ($mw_seq)=@_;
   system("cat ${logdir}drcat_*_output.log >${logdir}${customer}_${action}_${environment}_${mw_seq}_tivtask.log" );
   system("cat ${logdir}drcat_*_clean.log >${logdir}${customer}_${action}_${environment}_${mw_seq}.log" );
   unlink glob("${logdir}drcat_*_output.log");
   unlink glob("${logdir}drcat_*_clean.log");
}

#===============================================================================
# Check if output looks like an error condition, or should be ignored
#===============================================================================
sub hilite_line {
   my ($stderr,$line)=@_;
   my $err_flag=0;
   
   if ( $stderr ) {          # its from stderr so most likely an error 
      $err_flag=1; 
   }
   
   # does line match one of the error strings
   foreach my $regex ( @error_strings ) {
      if ( $line=~/$regex/ ) { $err_flag=1; }
   } 

   # does line match one of the looks like an error but isnt strings
   foreach my $regex ( @not_error ) {
      if ( $line=~/$regex/ ) { $err_flag=0; }
   } 
     
   return $err_flag;
}
#===============================================================================
# retrieve the log of the commands executed on each node
#===============================================================================
sub recover_log {
   my ($mw_seq,$complete_ref) = @_;
   my $parent = $$;
   debug();
   
   # =============================================
   # If previous fork still running just return
   # =============================================
   if ($tid) { return; }

   # create list of servers where output needs to be recovered
 
   my $srvfile = "${logdir}${customer}_${action}_${environment}_${mw_seq}_get_servers.txt";
   open "GETSERVERS", ">", "$srvfile";
   foreach my $node ( keys( %{$complete_ref} ) ) {
      print GETSERVERS "$node\n";
   } 
   close GETSERVERS;
         
   #================================================================================
   # from here down runs asynchronously in a seperate thread
   #================================================================================
   pipe(RHX,SHY);
   defined( my $pid = fork ) or die "couldn't fork: $!";
   my $ep;
   my $show;
   my $stderr;
   my ($srvclr,$textclr);
   my %counts;
   $lognumber++;
   if ( $pid == 0 ) {
      debug("Retrieving output");
      open "LOG",">","${logdir}drcat_".$lognumber."_output.log";
      open "CLEANLOG",">","${logdir}drcat_".$lognumber."_clean.log";
      open( TIV1, "${tivcmd} -t 600 -f $srvfile -l $tivname $getfile 2>&1 |" );
      while (<TIV1>) {
         print LOG "$_";
         if (/Task Endpoint:/) {
            ( $a, $b, $ep ) = split( " ", $_ );
            print "\n";
            $counts{$ep}{'errs'}=0;
            $counts{$ep}{'maxrc'}=0;
            next;
         }
         if (/^(.+?) \(Endpoint\)/) {
            $ep   = $1;
            $show = 1;
         }
         if (/------Standard Output------/) {
            $show = 1;
            $stderr=0;
            next;
         }
         if (/rc=/) {
            my ($rc)=$_=~/rc=(\d+?)/;
            debug("rc extracted $rc");
            if ( $counts{$ep}{'maxrc'} < $rc ) {
               $counts{$ep}{'maxrc'}=$rc;
            }
         }
         if (/------Standard Error Output------/) {
            $show = 1;
            $stderr=1;
            next;
         }
         if (/############################################################################/) {
            $show = 0;
            next;
         }
         if ($show) {
            if ( hilite_line($stderr,$_) ) {
              print RED, " $ep: " ,BOLD, WHITE, "$_", RESET;
              print CLEANLOG ">$ep: $_";
              $counts{$ep}{'errs'}++;
            } 
            
            else {
               print RED, " $ep: " ,BOLD, BLUE, "$_", RESET;
               print CLEANLOG " $ep: $_";
            }  
         }
      }
      close LOG;
      close CLEANLOG;
      close TIV;
      foreach my $node ( keys(%counts) ) {
         print SHY "$node:$counts{$node}{'maxrc'}:$counts{$node}{'errs'}\n";
      }
      unlink glob $srvfile;
      kill "USR1", $parent;
      exit;
   }
   $tid = $pid;
}
