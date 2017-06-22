#!/usr/local/bin/perl
use strict;

use Getopt::Long;
use Sys::Hostname;
use Switch 'Perl5','Perl6';

use EI::DirStore;
use EI::DirStore::Util;

my ($tivcmd,$logdir,$tivname,$debug,@expList,%sysOpts,$mons,$days,$years);
my ($opt_h,$opt_w,$opt_o,$opt_d,$opt_c,$opt_s);

main();

sub usage() {
  warn "Usage:sudo mq_batch_tiv.pl -w working_folder -c command_file [-s] [-o] attr<op>val [attr2<op>val2...]\n";
  warn "\n\t  where 'attr<op>val' follow the command lssys expressions rules\n";
  warn "\t  <op>               can be one of the following: ==, !=, <=, >=\n";
  warn "\t  -w working_folder  Specify the working folder which include the command file, the running\n";
  warn "\t                       results will be stored in that directroy as named task.log\n";
  warn "\t  -c command_file    Specify the command file which include the commands you want to run\n";
  warn "\t  -s                 Synchronise output to at0101a,gt0101a,dt0101a if it is set,else do nothing\n";
  warn "\t  -o                 Indicates that the specified expressions should be\n";
  warn "\t                     Combined with ORs vs the default of ANDs\n";
  exit(1);
}

sub main(){

  initialize();

  runCommand();

}

sub initialize(){

  Getopt::Long::Configure("bundling");
  Getopt::Long::Configure("require_order");
  GetOptions(
    'h'     => \$opt_h,
    'w:s'   => \$opt_w,
    'o'     => \$opt_o,
    'c:s' => \$opt_c,
    's' => \$opt_s,
  ) or usage();

  usage() if (not defined $opt_w);
  usage() if (not defined $opt_c);

  if(! -d $opt_w){
    print "         Working folder $opt_w doesn't exists.\n\n";
    usage();
  }
  if(! -r $opt_c){
    print "         Command file $opt_w/$opt_c doesn't exists.\n\n";
    usage();
  }
  
  $tivcmd="/Tivoli/scripts/tiv.task";
  if(! -r $tivcmd){
    print "Can't read Tivoli task file $tivcmd.\n\n";
    exit(1);
  }

  foreach my $exp (@ARGV) {
    push(@expList, $exp);
  }
  $sysOpts{expList} = [ @expList ] if @expList;
}

sub runCommand{
  
  my ($srvfile,$logfile,$cmdfile,%results,$cmd); #="${logdir}/verify_sw_status_srvfile.txt";
  my ($sec,$min,$hour,$day,$mon,$year,$weekday,$yeardate,$savinglightday)   =   (localtime(time));

  $sec   =   ($sec   <   10)?   "0$sec":$sec;   
  $min   =   ($min   <   10)?   "0$min":$min;   
  $hour   =   ($hour   <   10)?   "0$hour":$hour;   
  $day   =   ($day   <   10)?   "0$day":$day;   
  switch($mon) {
    case (0) { ${mons} = 'Jan';}
    case (1) { ${mons} = 'Feb';}
    case (2) { ${mons} = "Mar";}
    case (3) { ${mons} = "Apr";}
    case (4) { ${mons} = "May";}
    case (5) { ${mons} = "Jun";}
    case (6) { ${mons} = "Jul";}
    case (7) { ${mons} = "Aug";}
    case (8) { ${mons} = "Sep";}
    case (9) { ${mons} = "Oct";}
    case (10) { ${mons} = "Nov";}
    case (11) { ${mons} = "Dec";}
  }

  $mon   =   ($mon   <   9)?   "0".($mon+1):($mon+1);   

  $year   +=   1900;   

  $days = $day;
  $years = $year;

  if(! -d "$opt_w/${mons}${years}"){
    `mkdir $opt_w/${mons}${years}"`;
    `chmod 775 $opt_w/${mons}${years}"`;
  }
  $logdir="$opt_w/${mons}${years}";

  $cmdfile=$opt_c;

  my $printon=0;

  if(defined $opt_o){
    dsSearch(%results,"SYSTEM", expList => [@expList], expOp => "or",attrs => ["realm"]);
  }
  else{
    dsSearch(%results,"SYSTEM", expList => [@expList], attrs => ["realm"]);
  }
  my %srvlist;
  my @srvlist;
  foreach my $server (keys(%results)){

    my $logfilename="mq_itcs104_${server}_${days}${mons}${years}.log";
    $logfile="$logdir/${logfilename}";

    open LOGFILE, ">$logfile";

    my $realm = $results{$server}{realm}[0];
    $tivname = realm_to_tiv($realm);
    print "$server,$realm,$tivname\n";

    $srvfile = "/tmp/check_mq_status_${server}.txt";
    open SRVFILE,">$srvfile";
    print SRVFILE "${server}\n";
    close SRVFILE;
    $cmd="$tivcmd -t 600 -f $srvfile -l ${tivname} ${cmdfile} 2>&1";
    print "$cmd\n";
    my @status=`$cmd`;
    my $ignore=0;
    foreach (@status){
      if(/ITCS104 Report end/) {
        $ignore=0;
        print LOGFILE $_;   
        print LOGFILE "\n";
      }
      else{
        if (/ITCS104 Report/) {
          $ignore=1;
        }
      }
      if( $ignore == 1 ){
        print LOGFILE $_;
      }
    }

    close LOGFILE;

  }

  print "\nRunning results are saved to $logdir\n";

  return(0) if (not defined $opt_s);

  print "######################Sync Output###################################\n";
  `chmod 775 ${logdir}/*`;
  print "rsync -tzave ssh ${logdir} at1001b:/fs/system/audit/mqm/${mons}${years} 2>&1\n";
  my @status = `rsync -tzave ssh ${logdir} at1001b:/fs/system/audit/mqm 2>&1`;
  print @status;

  print "rsync -tzave ssh ${logdir} dt1201b:/fs/system/audit/mqm/${mons}${years} 2>&1\n";
  @status = `rsync -tzave ssh ${logdir} dt1201b:/fs/system/audit/mqm 2>&1`;
  print @status;

  print "rsync -tzave ssh ${logdir} gt0801b:/fs/system/audit/mqm/${mons}${years} 2>&1\n";
  @status = `rsync -tzave ssh ${logdir} gt0801b:/fs/system/audit/mqm 2>&1`;
  print @status;
}

sub realm_to_tiv() {
   my($realm)=@_;
   $_ = $realm;
   return "PX1" if(/ei.p1|cs.p1/);
   return "PX2" if(/ei.p2|cs.p2/);
   return "PX3" if(/ei.p3|cs.p3/);
   return "CI1" if(/ci.p1/);
   return "STG" if(/st.p1/);
   return "ECC" if(/ecc.p1|ecc.z1/);
   return "CI2" if(/ci.p2/);
   return "CI3" if(/ci.p3/);
   warn "unable to determine TMR for $_ \n";
   return "";
}

