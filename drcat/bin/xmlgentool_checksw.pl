#!/usr/local/bin/perl

my ($wasdir,$ihsdir,$itmdir,$lcsdir,$spongdir,$pubdir);
my ($check_wasstatus,$check_ihsstatus,$check_itmstatus,$check_lcsstatus,$check_spongstatus,$check_pubstatus);
my ($programstatus,$notinstallmsg,$installmsg,$msg,$debug);

main();

sub main{
  
  initialize();
  checkWAS();
  checkIHS();
  checkLCS();
  checkPUB();
  checkSpong();
  checkITM();
  #checkDaedalus();#daedalus
  checkMQ();
}

sub initialize(){

  $programstatus="XmlGen:CheckSoftware";
  
  $wasdir="/usr/WebSphere";
  $ihsdir="/usr/HTTPServer";
  $itmdir="/opt/IBM/ITM";
  $lcsdir="/opt/HPODS/LCS";
  $spongdir="/usr/local/spong";
  $pubdir="/opt/IBM/bNimble2";
  
  $check_wasstatus="/lfs/system/tools/was/bin/servstatus.ksh";
  $check_ihsstatus="ps -eoargs= |sort |uniq -c |grep h[t]tpd";
  $check_itmstatus="ps -ef |grep /opt/IBM/ITM |grep agent";
  $check_lcsstatus="/lfs/system/bin/check_lcs.sh";
  $check_spongstatus="/lfs/system/bin/check_spong.sh";
  $check_pubstatus="/lfs/system/bin/check_bNimble.sh";
  $check_daedalus="ps -eoargs= |awk '/di[k]ran/ {print $1,$NF}' | grep java";
  
  $notinstallmsg="isn't installed in";
  $installmsg="is installed in";
  $debug=0;
  
  while (@ARGV){
    my $thisarg = shift @ARGV;
    if ( $thisarg =~ "-debug" ){
      $debug=1;
    }
  }  
}

sub checkWAS{
  my @wasdirs = glob($wasdir . "*");
  if(! @wasdirs) {
    $msg = $notinstallmsg;
    outPut("WAS",$wasdir . "*",$msg);    
  }
  else{
    foreach (@wasdirs){     
      print $_ ." directory is found.\n" if $debug;      
      if(/WebSphere51/){
        $wasdir=$_ ."/AppServer";
        if((-d $wasdir ."/bin") and (-r $wasdir ."/bin/startNode.sh")){
          checkSubWAS($wasdir,"51");
        }
        else{          
          $wasdir=$_ . "/DeploymentManager";
          if((-d $wasdir ."/bin") and (-r $wasdir ."/bin/startManager.sh")){
            checkSubWAS($wasdir,"51");
          }
          else{
            $msg = $notinstallmsg;
            outPut("WAS51",$wasdir ,$msg);            
          }
        }        
      }
      elsif(/WebSphere60/){
        $wasdir=$_ . "/AppServer";
        if((-d $wasdir ."/bin") and (-r $wasdir ."/bin/startManager.sh") and (-r $wasdir ."/bin/startNode.sh")){
          checkSubWAS($wasdir,"60");
        }
        else{
          $msg = $notinstallmsg;
          outPut("WAS60",$wasdir,$msg);
        }
      }
      elsif(/WebSphere61/){
        $wasdir=$_ . "/AppServer";
        if((-d $wasdir ."/bin") and (-r $wasdir ."/bin/startManager.sh") and (-r $wasdir ."/bin/startNode.sh")){
          checkSubWAS($wasdir,"61");
        }
        else{
          $msg = $notinstallmsg;
          outPut("WAS61",$wasdir,$msg);
        }        
      }
    }
  }
}

sub checkSubWAS(){
  my($currwasdir,$wasversion)=@_;
    if((-d $currwasdir . "/bin") and (-r $currwasdir . "/bin/startServer.sh")){
      $msg = $installmsg;  
      my $cmd= $check_wasstatus . " $wasversion 2>&1";
      print "check was status cmd is $cmd.\n" if $debug;
      my @status = `$cmd`;
      my $runningcnt;  
      foreach (@status){
        if(/directory not found/){
          $msg = $notinstallmsg;
        }
        if(/##STOPPED##/){   #such as:          gt0703a_ibm_ied             ##STOPPED##
          my $endpos;
          my $appname;
          my $runningstatus;
          if(($endpos=index($_,"##STOPPED##")) != -1){
            $appname = substr($_,0,$endpos); #appname = gt0703a_ibm_ied             
            $appname=`echo $appname|cut -f3- -d_`;
            #if(($endpos = rindex($appname,"_")) !=-1){
            #  $appname = substr($appname,$endpos+1,length($appname)-$endpos-1); #appname = ied                 
            #}
            $runningstatus = "STOPPED";
          }
          chomp($appname);
          trim($appname);
          print "$programstatus:WASInstance: $appname Version:$wasversion Directory:$currwasdir/bin Status:$runningstatus\n";
        }
        if(/RUNNING/){
          if(/RUNNING COUNT/){             #such as:  RUNNING COUNT = 2
            my $start=index($_,"=");
            $runningcnt = substr($_,$start+1,length($_)-$start);
            chomp $runningcnt;
            trim($runningcnt);
            print "Running Count: $runningcnt  \n" if $debug;
          }
          else{                           #such as:   gt0703a_ibm_investor        RUNNING      454868   Feb 26 17:38
            my $endpos;
            my $appname;
            my $runningstatus;
            if(($endpos=index($_,"NOT RUNNING")) != -1){
              $appname = substr($_,0,$endpos);    #appname= gt0703a_ibm_investor      
              $runningstatus ="NOT RUNNING";
            }
            elsif(($endpos=index($_,"RUNNING")) != -1){
              $appname = substr($_,0,$endpos);    #appname = gt0703a_ibm_investor  
              $runningstatus = "RUNNING";
            }
            $appname=`echo $appname|cut -f3- -d_`;
            #if(($endpos = rindex($appname,"_")) !=-1){
            #  $appname = substr($appname,$endpos+1,length($appname)-$endpos-1); #appname = investor
            #}            
            chomp($appname);
            trim($appname);
            print "$programstatus:WASInstance: $appname Version:$wasversion Directory:$currwasdir/bin Status:$runningstatus\n";
          }
        }
      }
    }
    else{
      $msg = $notinstallmsg;
    }
    outPut("WAS $wasversion",$currwasdir,$msg) if($msg eq $notinstallmsg);
}

sub checkIHS{
  if((!-d $ihsdir . "/bin") or (! -r $ihsdir . "/bin/apachectl")){  
    $msg = $notinstallmsg;    
  }
  else{           
    $msg = $installmsg;
    my @status = `$check_ihsstatus 2>&1`;    #check ihs status
    $msg = "isn't running" unless @status;
    foreach (@status){      
      print $_ . "\n" if $debug;
    }
  }  
  outPut("IHS",$ihsdir,$msg);   
}

sub checkITM{
  if((! -d $itmdir . "/bin") or (! -r $itmdir. "/bin/itmcmd")) {  
    $msg = $notinstallmsg;    
  }
  else{
    $msg = $installmsg;
    my @status = `$check_itmstatus 2>&1`;    #check itm status
    $msg = "isn't running" unless @status;
    foreach (@status){
      print $_ . "\n" if $debug;
    }
  }
  outPut("ITM",$itmdir,$msg); 
}

sub checkLCS{
  if((! -d $lcsdir . "/bin") or (! -r $lcsdir. "/bin/lcs") or (! -r $lcsdir."/bin/rc.lcs_client")){  
    $msg = $notinstallmsg;    
  }
  else{
    $msg = $installmsg;
    my @status = `$check_lcsstatus 2>&1`;    #run check_lcs.sh
    foreach (@status){
      if(/LCS not running/){
        $msg = "isn't running";
      }
      elsif(/Found instance/){
        $msg = $installmsg;
      }
      elsif(/Missing LCS client process/){
        $msg = "isn't running";
      }
      print $_ . "\n" if $debug;
    }
  }
  outPut("LCS",$lcsdir,$msg);
}

sub checkSpong{
  if(! -d $spongdir . "/bin"){
    $msg=$notinstallmsg;
  }
  else{
    $msg = $installmsg;
    my @status = `$check_spongstatus 2>&1`;    #run check_spong.sh
    foreach (@status){
      if(/Spong not running/){
        $msg = "isn't running";
      }       
      print $_ . "\n" if $debug;
    }
  }
  outPut("SPONG",$spongdir,$msg);
}

sub checkPUB{
  if((! -d $pubdir . "/lib") or (! -r $pubdir ."/lib/Transmit.jar")){   
    $msg=$notinstallmsg;
  }
  else{
    $msg = $installmsg;
    my $status = 1;
    my @status = `$check_pubstatus 2>&1`; #run check_bNimble.sh
    foreach (@status){
      if(/bNimble not running/){
        $status = 0;
        $msg = "isn't running";
        outPut("bNimble",$pubdir,$msg);
      }
      print $_ . "\n" if $debug;
    }
    if($status){ #find the config file  
      @status = `ps -ef |grep java |grep /opt/IBM/bNimble2/lib |grep .conf`;
      #such as: pubinst   8308  8307  0 Mar23 ?        00:00:02 /usr/bin/java -Xms128M -Xmx512M -classpath 
      #         /opt/IBM/bNimble2/lib/bNimblePublishing2013.jar com.ibm.webos.daedalus.Daedalus esc/config/EndpointV2_ESCEndNodes.conf
      #the config file is: esc/config/EndpointV2_ESCEndNodes.conf
      foreach (@status) {
        if(not /grep .conf/){
          my $end_pos=rindex($_,".conf")+5;
          my $start_pos=rindex($_," ",$end_pos-1)+1;
          my $config_file=substr($_,$start_pos,($end_pos - $start_pos));
          $config_file="/projects/$config_file";
          print "$programstatus:bNimble $msg $pubdir ConfigFile:$config_file\n";
        }
      }
    }    
  }
  #outPut("bNimble",$pubdir,$msg);
}

sub checkMQ{
  my $mqtype;
  $_=`lssys -n |grep role`;
  if(/MQ/){
    $mqtype="MQ";
  }
  else {
    if(/WBIMB/){
      $mqtype="WBIMB";
    }
    else {
      $mqtype="MQ";
    }
  }
  my @status = `dspmqver 2>&1`;
  my $status = 1; # 0-not install 1-install 2-installed but not running
  foreach (@status){
    if(/not found/){
      $status = 0;
      $msg=$notinstallmsg;
    }
  }
  if ($status & (! -d "/var/mqm/qmgrs/")){
    $status = 0;
    $msg=$notinstallmsg;
  }
  my @qms;
  if ($status){
    @qms = ` ls /var/mqm/qmgrs |grep -v \@SYSTEM | grep -v DUMMY 2>&1`;
    if(not @qms){
      $status = 0;
      $msg = $notinstallmsg;
    }
  }
  if ($status){
    $msg = $installmsg;
    foreach (@qms) {
      my $qms = $_;
      chomp($qms);
      trim($qms);
      my @rts = `dspmq -m ${qms} 2>&1` ; # su - mqm -c "dmpmqaut -m ${qms} -t qmgr 2>&1"`;
      $status = 2;
      foreach (@rts){
        if(/STATUS\(Running\)/){
          print "$programstatus:$mqtype $msg /var/mqm QueueManager:${qms} Status:Running\n";
          $status = 1;
          break;
        }
      }
      if($status == 2){
        print "$programstatus:$mqtype $msg /var/mqm QueueManager:${qms} Status:Stopped\n";
      }
      $status = 2;
    }
  }
  if ( not $status){
    outPut("$mqtype","/var/mqm",$msg);
  }
}

sub outPut{
  my($name,$dir,$outmsg)=@_;
  print "$programstatus:$name $outmsg $dir\n";
}

sub trim{
  for(shift(@_)){
    s/^\s+//; 
    s/\s+$//;
  }
}

