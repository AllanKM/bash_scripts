#!/usr/local/bin/perl
use strict;

use Getopt::Long;
use Sys::Hostname;
use Cwd qw/abs_path/;
use File::Basename;
use EI::DirStore;
use EI::DirStore::Util;
use XML::Simple;

my ($opt_h,$opt_f,$opt_o,$opt_d,$opt_c);
my ($config,$debug,@role_criteria,%role_criteria_results,@expList,%sysOpts,%srvlist,%rolelist,$currdir,$logdir,$cmdfile,$tivcmd,$tid,%swresults);

main();
                         
sub usage() {   
  warn "Usage: xmlgentool -f xmlfile [-d] [-o] attr<op>val [attr2<op>val2...]\n";
  warn "\n\t  where 'attr<op>val' follow the command lssys expressions rules\n";
  warn "\t  <op>            can be one of the following: ==, !=, <=, >=\n";
  warn "\t  -f xmlfile      Specify the filename for the generated xml file\n";
#  warn "\t  -c configfile   Specify the xml format config file for the generation tool\n";
  warn "\t  -d              for debug mode, if set will show detail running info\n";
  warn "\t  -o              Indicates that the specified expressions should be\n";
  warn "\t                  combined with ORs vs the default of ANDs\n";
  exit(1);                                                   
}

sub main(){
  
  initialize();
  
  searchRoles();  
  
  genXML();
}

sub initialize(){
  
  $tivcmd="/Tivoli/scripts/tiv.task";
  if(! -r $tivcmd){
    print "This script need Tivoli support, please run it at Tivoli node. Such as dt1201b";
    exit(1);
  }

  Getopt::Long::Configure("bundling");
  Getopt::Long::Configure("require_order");
  GetOptions(
  	'h'	=> \$opt_h,
  	'f:s'	=> \$opt_f,
#  	'c:s' => \$opt_c,
  	'd' => \$opt_d,
  	'o'	=> \$opt_o,
  ) or usage();
  usage() if (defined $opt_h);
  usage() if (! defined $opt_f);
#  usage() if (! defined $opt_c);
  
  if(defined $opt_d) {
    $debug=1;
  }
  else{
    $debug=0;
  }
  print "target filename is: $opt_f\n" if $debug;
  
  foreach my $exp (@ARGV) {
    push(@expList, $exp);
    $_ = uc($exp);
    if(/ROLE==/){
      /^(.*)==(.*)/;
      push(@role_criteria,$2);
    }
    print "exp: $exp\n" if $debug;
  }
  print "query: @role_criteria";
  $sysOpts{expList} = [ @expList ] if @expList;
    
  $tid=0;
  
#  if(! -r $opt_c){
#    print "Config file $opt_c can not be accessed.\n";
#    exit(1);
#  }
#  $config = XMLin($opt_c);    
#  $currdir = abs_path(dirname(__FILE__));
  $currdir="/lfs/system/tools/drcat";
  $config = XMLin("$currdir/conf/xmlgentool_config.xml");
  $logdir="/tmp/drcat_log";
  if(! -d $logdir){
    `mkdir $logdir`;
  }
  $cmdfile="$currdir/bin/xmlgentool_checksw.sh";
}

sub sortSeq{
  my $pre=sortValue($a);
  my $end=sortValue($b);
  return(-1) if ($pre > $end);
  return(1) if($pre < $end);
  return(0);
}
sub sortValue{
#7 - WAS
#6 - WPS
#5 - WEBSERVER
#4 - MQM
#4 - WBIMB
#3 - PUB
#2 - SPONG
#1 - LCS
#0 - ITM
#-1- others
  ($_)=@_;
  return(7) if (/WAS/);
  return(6) if (/WPS/);
  return(5) if (/WEBSERVER/);
  return(4) if (/MQM/);
  return(4) if (/WBIMB/);
  return(3) if (/PUB/);
  return(2) if (/SPONG/);
  return(1) if (/LCS/);
  return(0) if (/ITM/);
  return(-1);
}


sub searchRoles(){
  
  print "\n#######Start query roles#######\n";
  my %results;
  my @attr = qw(role);
  $sysOpts{attrs} = [ @attr ];
  
  if(!defined @role_criteria){
    print "search all roles\n";
    $role_criteria_results{"*"}=1;
  }
  else{
    my %curr_list;
    foreach (@role_criteria){
      %curr_list=();
      dsSearch(%results, "role", name => "$_");
      if(!defined %role_criteria_results){
        foreach my $role(keys(%results)){
          $role_criteria_results{$role}=1;
        }
      }
      else{
        foreach my $role (keys(%results)){        
          if(defined $opt_o){              
            $role_criteria_results{$role}=1;              
          }
          else{
            if(exists $role_criteria_results{$role}){
              $curr_list{$role}=1;
            }
          }
        }
        if(!defined $opt_o){
          %role_criteria_results=%curr_list;          
        }
      }      
    }
  }
  if(defined $opt_o){
    dsSearch(%results,"SYSTEM", expList => [@expList], expOp => "or",attrs => ["role"]);
  }
  else{
    dsSearch(%results,"SYSTEM", expList => [@expList], attrs => ["role"]);
  }
  
  my %totalrole;
  my %totalserver;
  my $max=0;
  foreach my $server (keys(%results)){
    my %roles;
    my %servers;
    my $cnt = 0;#@{$results{$server}{role}};
    print "$server:" if $debug;
    foreach (@{$results{$server}{role}}){      
      if(exists $role_criteria_results{"*"} or exists $role_criteria_results{$_}){
        if((/WAS|WPS|WEBSERVER|SPONG|PUB|MQ|LCS|ITM|WBIMB/) and (! /WEBSERVER.CLUSTER/)) {
          print "$_ - " if $debug;
          $cnt++;
          if(exists $roles{$_}){
            $roles{$_} =[@{$roles{$_}},$server];
          }
          else{
            $roles{$_}=[$server];
          }
          if(exists $servers{$server}){
            $servers{$server} =[@{$servers{$server}},$_];
          }
          else{
            $servers{$server}=[$_];
          }
        }
      }
    }
    if(exists $totalrole{$cnt}){
      my %tmp = %{$totalrole{$cnt}};
      if($debug){
        print "tmp role $cnt:";
        foreach (keys %tmp){
          print "$_ : ";
          foreach (@{$tmp{$_}}){
            print "$_ ";
          }
        }
        print "\n";
      }
      foreach (keys %roles){
        if(exists $tmp{$_}){
          $tmp{$_}=[@{$tmp{$_}},@{$roles{$_}}];
        }
        else{
          $tmp{$_}=[@{$roles{$_}}];
        }
      }
      $totalrole{$cnt}={%tmp};
    }
    else{
      $totalrole{$cnt}={%roles} if $cnt;
    }
    
    if(exists $totalserver{$cnt}){
      my %tmp = %{$totalserver{$cnt}};
      if($debug){
        print "tmp server $cnt:";
        foreach (keys %tmp){
          print "$_ : ";
          foreach (@{$tmp{$_}}){
            print "$_ ";
          }
        }
        print "\n";        
      }
      $tmp{$server}=[@{$servers{$server}}];      
      $totalserver{$cnt}={%tmp};
    }
    else{
      $totalserver{$cnt}={%servers} if $cnt;
    }
    
    if($max < $cnt){
      $max = $cnt;
    }
    print "\n" if $debug;
  }
  print "max=$max\n" if $debug;

  for(my $i=1;$i < ($max+1);$i++){
    if(exists $totalrole{$i}){
      print "count:$i " if $debug;
      foreach my $rolename(sort sortSeq keys %{$totalrole{$i}}){
        print "$rolename:" if $debug;
        my $repeat=0;
        my $totalcnt=0;
        if($i > 1){          
          foreach my $srv (@{%{$totalrole{$i}{$rolename}}}){
            print "$srv - " if $debug;           
            if(exists $srvlist{$srv}){
              $repeat++;
              print "Role ${rolename} will be ignored because it is repeated with role: $srvlist{$srv}\n";
            }
            $totalcnt++;
          }
        }
        if($repeat eq 0){
          foreach my $srv (@{%{$totalrole{$i}{$rolename}}}){  
            $rolelist{$rolename} = "$srv";          
            $srvlist{$srv}="$rolename";
          }
        }
        elsif(! ($repeat eq $totalcnt++)){ 
            
            ####################   Here handle the mixed servers   ################################
            #  such as:   role1 include servers: server1 server2
            #             role2 include servers: server1 server3
            #             role1 has been chosen to rolelist, if add role2 , the server1 is repeated.
            #  solution:  ???
            #######################################################################################
            print "found mixed roles:$rolename Server: @{%{$totalrole{$i}{$rolename}}}\n";
        }
      }
    }
    print "\n" if $debug;
  }
  my $count = keys %rolelist;
  print "total role count:$count\n";
  print "#######End query roles.#######\n";
}


sub genXML(){
  my($middleware,$action,$version,$sequence,$app_instance,$action_command,$verification_command,$appsequence,$perl);
  my $xmlfile = lc("${opt_f}");
  if ( -r $xmlfile ) {
    print "Reading in previously generated entries in XML file: $xmlfile";
    $perl= XMLin( $xmlfile,  forceArray=>1) or print "Failed to parse xml in file $xmlfile: $!";
    my $isdefined;
    eval { $isdefined =$perl->{querycmd}};
    if($isdefined){
      my %hash=%{$perl};
      $hash{querycmd}="@expList";
      $perl=\%hash;
    }
  }
  foreach my $role (keys %rolelist){
    %swresults=();
    my $srv = $rolelist{$role};
    print "\n#######Start check software for role:$role ";
    checkSW($srv); 
    foreach my $app (sort keys %swresults){
      if($app =~/WAS/){
        print "app:$app - version:$swresults{$app}{version} - directory:$swresults{$app}{directory} - status:$swresults{$app}{status}\n" if ($debug);

        foreach (@{${$swresults{$app}}{appname}}){
          #create_xml($middleware,$action,$role,$version,$sequence,$app,$action_command,$verification_command,$appsequence,\$perl);
          my $appname=`echo $_|cut -f1 -d:`;
          my $status=`echo $_|cut -f2 -d:`; 
          trim($appname);
          trim($status);
          if($status ==1) {
            genMiddlewareXml($app, $role,$swresults{$app}{version},$swresults{$app}{directory},"",$appname,\$perl);
          }
        }
      }
      else{
        #if($swresults{$app}{status} == 1){ #software is installed and running
        if ($swresults{$app}{status}){ #software is installed (whatever running or not)
          genMiddlewareXml($app, $role,"all",$swresults{$app}{directory},$swresults{$app}{config_file},"all",\$perl);
        }
        
        if ($debug){
          my $sta = "installed" if ($swresults{$app}{status});
          $sta = "not install" unless $swresults{$app}{status};
          print "app:$app - directory:$swresults{$app}{directory} - config file:$swresults{$app}{config_file} - status:$sta\n";
        }
      }
    }
    print "\n#######End check software for role:$role\n";       
  }

  my $xml= XMLout( $perl ) or print "Failed to generate XML: $!";
  open(XMLFILE,">$xmlfile") or print "Failed to open $xmlfile: $!";
  print XMLFILE $xml;
}

sub genMiddlewareXml{
  my ($middleware, $role,$version,$app_dir,$config_file,$app_instance,$perl) = @_;
  my ($tmp_middleware,$mydefined,$sequence,$action,$verification_command,$action_command,$appsequence);
  $tmp_middleware = $middleware;
  if($middleware=~ /WAS/){
    $middleware="WAS";
  }
  $action="Start";
  
  eval {$sequence=$config->{Prod}->{$middleware}->{StartSequence}};
  
  eval {$action_command=$config->{Prod}->{$middleware}->{StartCommand}};
  #print "action_command: $action_command \n";
  eval {$verification_command = $config->{Prod}->{$middleware}->{VerifyStartCommand}};
  if($middleware =~ /WAS/){
    eval {$mydefined =$config->{Prod}->{$middleware}->{AppSequence}->{App}->{$app_instance}};
    unless($mydefined){
      eval {$appsequence=$config->{Prod}->{$middleware}->{AppSequence}->{App}->{default}->{StartSequence}};
    }
    else{
      eval {$appsequence=$config->{Prod}->{$middleware}->{AppSequence}->{App}->{$app_instance}->{StartSequence}};
    }

    $action_command=~ s/\$appdir\$/$app_dir/;
    $action_command=~ s/\$appname\$/$app_instance/;
    $verification_command=~ s/\$appname\$/$app_instance/;
    $verification_command=~ s/\$appdir\$/$app_dir/;
  }else{
    $appsequence=3;
    if($middleware =~ /bNimble/){
      $action_command=~ s/\$configfile\$/$config_file/;
    }
  }
  if($middleware =~ /WAS|IHS|bNimble|ITM|LCS|SPONG|MQ|WBIMB/){
    create_xml($tmp_middleware,$action,$role,$version,$sequence,$app_instance,$action_command,$verification_command,$appsequence,$perl);
  }
  
  $action="Stop";
  eval {$sequence=$config->{Prod}->{$middleware}->{StopSequence}};
  eval {$action_command=$config->{Prod}->{$middleware}->{StopCommand}};
  eval {$verification_command = $config->{Prod}->{$middleware}->{VerifyStopCommand}};
  if($middleware =~ /WAS/ ){
    eval {$mydefined =$config->{Prod}->{$middleware}->{AppSequence}->{App}->{$app_instance}};
    unless($mydefined){
      eval {$appsequence=$config->{Prod}->{$middleware}->{AppSequence}->{App}->{default}->{StopSequence}};
    }
    else{
      eval {$appsequence=$config->{Prod}->{$middleware}->{AppSequence}->{App}->{$app_instance}->{StopSequence}};
    }
    $action_command=~ s/\$appdir\$/$app_dir/;
    $action_command=~ s/\$appname\$/$app_instance/;
    $verification_command=~ s/\$appname\$/$app_instance/;
    $verification_command=~ s/\$appdir\$/$app_dir/;
  }else{
    $appsequence=3;
    if($middleware =~ /bNimble/){
      $action_command=~ s/\$configfile\$/$config_file/;
    }
  }
  if($middleware =~ /WAS|IHS|bNimble|ITM|LCS|SPONG|MQ|WBIMB/){
    create_xml($tmp_middleware,$action,$role,$version,$sequence,$app_instance,$action_command,$verification_command,$appsequence,$perl);
  }
    
}

sub create_xml {
  
  my($middleware,$action,$role,$version,$sequence,$app,$action_command,$verification_command,$appsequence,$perl)=@_;
  my $defined;
  if ( defined ${$perl}){
    eval { $defined = ${$perl} -> {role} };
    unless ($defined) {
      #No roles defined in this xML file .. that seems strange! .. the eval returned an error
      #print "Warning: No roles defined , yet this file existed",
      #      "Updating XML file with this new role: $role\n";

      ${$perl} = { 'role' => { "$role" => { 
        'action' => {"$action" => {
          'middleware' => { "$middleware" => { 
            'version' => { "$version"=> {
              'sequence' => $sequence,
              'application' => {  "$app" => {
                'sequence' => "$appsequence",
                'cmd' => "$action_command",
                'verify' => "$verification_command"
                }}
              }}
            }}
          }}
        }}
      };   
    }
    eval { $defined = ${$perl}-> {role} -> {$role} };

    unless ($defined) {
      #print "Update the listing in this XML file with this new role, $role\n";
      my %hash = %{ ${$perl} -> {role}};
      $hash{$role} = { 'action' => {"$action" => {
        'middleware' => { "$middleware" => { 
          'version' => { "$version"=> {
            'sequence' => $sequence,
            'application' => {"$app" => {
              'sequence' => "$appsequence",
              'cmd' => "$action_command",
              'verify' => "$verification_command"
            }}
          }}
        }}
      }}};
      ${$perl} -> {role} = \%hash;
    }

    eval {  $defined = ${$perl}-> {role} -> {$role} -> {action} -> {$action}  };

    unless ($defined) {
      #print "Updating the existing $role entry in this XML file with this new $action action entry\n";
      my %hash = %{ ${$perl} -> {role} -> {$role} -> {action}};
      $hash{$action} = {'middleware' =>{ "$middleware" => { 
        'version' => { "$version"=> {
          'sequence' => $sequence,
          'application' => {  "$app" => {
            'sequence' => "$appsequence",
            'cmd' => "$action_command",
            'verify' => "$verification_command"
            }}
        }}
      }}};
      ${$perl} -> {role} -> {$role} -> {action} = \%hash;
    }

    eval {  $defined = ${$perl}-> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware} };

    unless ($defined) {
      #print "Updating the existing $role entry in this XML file with this new $middleware entry\n";
      my %hash = %{${$perl} -> {role} -> {$role} -> {action} -> {$action} -> {middleware}};
      $hash{$middleware} =
      { 'version' => { "$version"=> {
        'sequence'=>$sequence,
        'application' => {  "$app" => {
          'sequence' => "$appsequence",
          'cmd' => "$action_command",
          'verify' => "$verification_command"
        }}
      }}};
      ${$perl} -> {role} -> {$role} -> {action} -> {$action} -> {middleware} = \%hash;
    }

    eval {  $defined = ${$perl}-> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
                -> {version} -> {$version} };

    unless ($defined) {
      #print "Updating the existing $role entry in this XML file with this new version $version entry\n";
      my %hash = %{${$perl} -> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware} -> {version}};
        $hash{$version} = {
          'sequence' => $sequence,
          'application' => {  "$app" => {
            'sequence' => "$appsequence",
            'cmd' => "$action_command",
            'verify' => "$verification_command"
          }}
        };
        ${$perl} -> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware} -> {version} = \%hash;
    }

    eval {  $defined = ${$perl}-> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
                -> {version} -> {$version}-> {application} -> {$app} };

    unless ($defined) {
      #print "Updating the existing $role entry in this XML file with an a new entry for this application\n";
      
      my %hash = %{ ${$perl} -> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
                          -> {version} -> {$version} -> {application} };
      $hash{$app} = {
        'sequence' => "$appsequence",
        'cmd' => "$action_command",
        'verify' => "$verification_command"
        };
      ${$perl} -> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
                          -> {version} -> {$version} -> {application} = \%hash;
    }
  } else {
    #New XML file needed
    ${$perl} = {'querycmd'=>"@expList", 'role' => { "$role" => { 'action' => {
      "$action" => {'middleware' => { "$middleware" => { 'version' => { "$version"=> {
        'sequence' => $sequence,
        'application' => {  "$app" => {
          'sequence' => "$appsequence",
          'cmd' => "$action_command",
          'verify' => "$verification_command"
        }}
      }}}}}
    }}}};
  }
  return $perl;
}

sub checkSW(){
  my($srv)=@_;
  my (%systems,$realm);
  dsGet(%systems, "system", "$srv",attrs => [qw(realm)]);
  $realm=$systems{realm}[0];
  print "realm: $realm server:$srv\n\n";
  do_tivtask($tid,$srv,$realm);
  $tid++;
}

sub swStatus{
  
  my (%result,$appname,$version,$dir,$status,$config_file);
  ($_)=@_;
  chmod $_;
  print "$_\n" if $debug;  
  
  s/XmlGen:CheckSoftware://;
  if(/WASInstance:/){
    s/WASInstance://;
    /^(.*)Version:(.*)/;
    $appname = $1;
    $_ = $2;
    /^(.*)Directory:(.*)/;
    $version = $1;
    $_ = $2;
    /^(.*)Status:(.*)/;
    $dir = $1;
    $_ = $2;
    if(/NOT RUNNING/){
      $status = 2;
    }
    else{
      if(/RUNNING/){
        $status = 1;
      }
      else{
        $status = 0;
      }
    }
    #$status = $2;
    trim($appname);
    trim($version);
    trim($dir);
    trim($status);
    my $wasname="WAS$version";
    print "$wasname\n" if $debug;
    $appname="$appname:$status";
    if(exists $swresults{$wasname}){
      %result=(appname=>[@{${$swresults{$wasname}}{appname}},"$appname"],version=>$version,directory=>$dir,status=>$status);
      $swresults{$wasname}={%result};
    }
    else{
      %result=(appname=>["$appname"],version=>$version,directory=>$dir,status=>$status);
      $swresults{$wasname}={%result};      
    }
  }
  else{
    return(0) if(/WAS/);
    if(/is installed in/){
      $status=1;
      /^(.*)is installed in(.*)/;
      $appname=$1;
      $dir=$2;
      if(/bNimble/){
        $_ = $dir;
        /^(.*)ConfigFile:(.*)/;
        $dir = $1;
        $config_file=$2;
      }
    }
    if(/isn\'t running/){
      $status=2;
      /^(.*)isn\'t running(.*)/;  
      $appname=$1;
      $dir=$2;
    }
    if(/isn\'t installed in/){
      $status=0;
      /^(.*)isn\'t installed in(.*)/;        
      $appname=$1;
      $dir=$2;
    }    
    trim($appname);
    trim($dir);
    trim($config_file);
    %result=(appname=>$appname,directory=>$dir,status=>$status,config_file=>$config_file);
    $swresults{$appname}={%result};
  }
  print "appname:$appname,version:$version,dir:$dir,status:$status,config_file:$config_file\n" if $debug;
}

sub trim{
  for(shift(@_)){
    s/^\s+//; 
    s/\s+$//;
  }
}

sub do_tivtask() {
	my ($tid,$server,$realm)=@_;
	print "taskid $tid\n" if $debug;
	my $srvfile="${logdir}/task${tid}_${server}_srvfile.txt";
	open SRVFILE,">$srvfile";
	print SRVFILE "$server\n";
	close SRVFILE;

	my $logfile="${logdir}/task${tid}_${server}.log";
	open LOGFILE, ">$logfile";

	
	my $tivname=realm_to_tiv($realm);
	my $printon=0;
	if (  $debug) {
		print "Thread $tid started for server: $server cmd: Check Software Install Status\nThread $tid ";
		print qq ($tivcmd -t 600 -f $srvfile -l $tivname $cmdfile 2>&1);
		print "\n";
	}
	my $cmd="$tivcmd -t 600 -f $srvfile -l $tivname $cmdfile 2>&1";
	print "$cmd\n";
	my $color;
  my @status=`$cmd`;
  foreach (@status){
		print LOGFILE $_;
		if (/XmlGen:CheckSoftware/){
		  swStatus($_);
		}
		elsif ( /--Standard Error Output--/ ) {
			$color="\n\033[1;31m";
			$printon =1;
		}		
	}
	close LOGFILE;
	if ( ! $debug ) {
		unlink $srvfile;
	}
}

sub realm_to_tiv() {
   my($realm)=@_;
   $_ = $realm;
   return "PX1" if(/ei.p1|cs.p1/);
   return "PX2" if(/ei.p2|cs.p2/);
   return "PX3" if(/ei.p3|cs.p3/);
   return "CI1" if(/ci.p1/);      
   return "STG" if(/st.p1/);      
   return "ECC" if(/ecc.p1/);      
   return "CI2" if(/ci.p2/);      
   return "CI3" if(/ci.p3/);
   warn "unable to determine TMR for $_ \n";
   return "";
}

