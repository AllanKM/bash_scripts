package dp_functions;

#============================================
# $Revision: 1.2 $
# Author: Steve Farrell
#============================================
use strict;
use FindBin;
use lib ("/$FindBin::Bin", "/$FindBin::Bin/lib", "/$FindBin::Bin/../lib", "/lfs/system/tools/configtools/lib");
use Data::Dumper;
use IPC::Open3;
use MIME::Base64;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
$VERSION = 1.00;
@ISA     = qw(Exporter);
@EXPORT  = qw(get_dp_user parseParms ei_domain getFile getDomains getDomainConfig
  getDomainStatus readObjectStatus getFileList setObjectState save
  DomainQuiesce DomainUnquiesce);
@EXPORT_OK = qw();

my @dp = `lssys -l hostenv -x csv -e role==datapower nodestatus!=bad custtag==esc`;
#*******************************************************
# Get id/password to login to device
#*******************************************************
sub get_dp_user {
   my $serverlist = shift;
   my $dp_user    = $ENV{'dp_user'};
   if (getpwuid($<) ne 'root') {
      if (!$dp_user) {
         my $mail;
         if (grep /dpv/, @$serverlist) {    # for apim servers
            $mail = 'admin';
         }
         else {
            my $id = getlogin || getpwuid($<);
            $mail = `dsls -l mail -e person uid==${id} | grep mail`;
            $mail =~ s/^.*= //;
            chomp $mail;
         }
         $SIG{INT} = sub { ReadMode(0); print "\n"; exit; };
         use Term::ReadKey;
         print "Enter password for $mail: ";
         ReadMode('noecho');                # don't echo
         chomp(my $password = <STDIN>);
         ReadMode(0);                       # back to normal
         print "\n";

         if (!$password) {
            print STDERR "Cannot continue without password\n";
            exit;
         }
         else {
            $dp_user = "${mail}:$password";
         }
      }
   }
   else {
      if (-e '/etc/.dp_secure_backup.cfg') {
         $dp_user = `cat /etc/.dp_secure_backup.cfg | openssl enc -base64 -d | sed -e 's/;/:/'`;
      }
      else {
         print STDERR "Missing /etc/.dp_secure_backup.cfg, cant lookup dpauto password\n";
         exit;
      }
   }
   return $dp_user;
}

#*****************************************************************
# select server names from command line arg
# expanding keywords to a list of servers
#*****************************************************************
sub parseParms {
   my ($parms) = @_;
   my %serverlist;
   my $attrs = {};
   my $others;
   foreach my $parm (@$parms) {
      if ( $parm=~ /p\ddpa0\d/ &&  grep(/$parm/,@dp) ) {
         $serverlist{$parm} = 1;
      }
      elsif ($parm =~ /^p\d$/) {
			foreach my $srv ( grep /${parm}dpa0\d,PRD/,@dp ) {
				chomp $srv;
				my $s=$srv;
				$s =~ s/,(?:PRE|PRD)//;
         	$serverlist{"$s"} = 1;
			}
      }
      elsif ($parm eq 'ivt' || $parm eq 'pre' ) {
			foreach my $srv ( grep(/PRE/,@dp) ) {
				chomp $srv;
				my $s=$srv;
				$s =~ s/,(?:PRE|PRD)//;
         	$serverlist{"$s"} = 1;
			}
      }
      elsif ($parm eq 'prd') {
			foreach my $srv ( grep(/PRD/,@dp) ) {
				chomp $srv;
				my $s=$srv;
				$s =~ s/,(?:PRE|PRD)//;
         	$serverlist{"$s"} = 1;
			}
      }
      elsif ($parm =~ /^-[a-z]$/) {
         $parm =~ s/-//;
         $attrs->{$parm} = 1;
      }
      else {
         $others .= "$parm ";
      }
   }
   my @servers = keys %serverlist;
   my $servers = \@servers;
   if (!$servers) {
      print STDERR "Need to supply names of datapower devices to check\n";
      exit;
   }

   if ( (grep /dpv/,@servers) && (grep /dpa/,@servers) ) {
      print STDERR "Cannot mix APIm and ESC servers in the same command\n";
      exit;
   }
   return ($servers, $attrs, $others);
}

#*****************************************************
# return name of domain supported by EI
#*****************************************************
sub ei_domain {
   my $server = shift;
   if ( grep(/$server,PRD/,@dp)) {
      return "support_websvc_eci_prod";
   }
   elsif ( grep(/$server,PRE/,@dp)) {
      return "support_websvc_eci_ivt";
   }
   elsif ($server =~ /p2dpv0[1-2]/) {
      return "APIMgmt_938084788A";
   }
   else {
      print STDERR "dunno how $server slipped thru, but I dont know the domain for that";
      exit;
   }
}

#**************************************************************
# copy a file from datapower and base64 decode it
#**************************************************************
sub getFile {
   my ($dp_user, $server, $domain, $file, $attrs) = @_;
   if (!"$dp_user") {
      $dp_user = get_dp_user;
   }
   my $post = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
<soapenv:Body>
<dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="$domain">
<dp:get-file name="$file"/>
</dp:request>
</soapenv:Body>
</soapenv:Envelope>
EOF
   my ($response, $error) = SOMA($dp_user, $server, $post, $attrs);
   if ($response =~ /dp:file/s) {
      $response =~ s/.+?dp:file.+?>//s;
      $response =~ s/<\/dp:file>.*$//s;
      return decode_base64($response);
   }
   else {
      print STDERR "$response\n$error";
      exit;
   }
}

#**************************************************************
# Perform SOMA request
#**************************************************************
sub SOMA {
   my ($dp_user, $server, $post, $attrs) = @_;
   $post =~ s/\n//g;
   $post =~ s/\"/\\\"/g;
   my $response;
   my $error;
   my $cmd = "curl -s -K - -d \"$post\" https://$server.event.ibm.com:5550/service/mgmt/current";
   my $pid = open3(\*WRITER, \*READER, \*ERROR, $cmd);
   {
      print WRITER "user = $dp_user\n";
      close WRITER;
      while (my $line = <READER>) {
         $response .= $line;
      }
      {
         local $/;
         while (my $line = <ERROR>) {
            $error .= $line;
         }
      }
   }
   waitpid($pid, 0) or die "$!\n";
   close READER;
   close ERROR;
   if ($attrs->{'k'}) {
      print STDERR "Saving response to disk\n";
      open(my $fh, ">", "${server}_" . $attrs->{'domain'} . "_" . $attrs->{request} . ".txt");
      print $fh $response;
      close $fh;
   }
   return ($response, $error);
}

#**************************************************************
# Perform AMP request
#**************************************************************
sub AMP {
   my ($dp_user, $server, $post, $attrs) = @_;
   $post =~ s/\n//g;
   $post =~ s/\"/\\\"/g;
   my $response;
   my $error;
   my $cmd = "curl -s -K - -d \"$post\" https://$server.event.ibm.com:5550/service/mgmt/amp/1.0";
   my $pid = open3(\*WRITER, \*READER, \*ERROR, $cmd);
   {
      print WRITER "user = $dp_user\n";
      close WRITER;
      while (my $line = <READER>) {
         $response .= $line;
      }
      {
         local $/;
         while (my $line = <ERROR>) {
            $error .= $line;
         }
      }
   }
   waitpid($pid, 0) or die "$!\n";
   close READER;
   close ERROR;
   if ($attrs->{'k'}) {
      print STDERR "Saving response to disk\n";
      open(my $fh, ">", "${server}_" . $attrs->{'domain'} . "_" . $attrs->{request} . ".txt");
      print $fh $response;
      close $fh;
   }
   return ($response, $error);
}

#**************************************************************
# get domain list
#**************************************************************
sub getDomains {
   my ($dp_user, $server, $attrs) = @_;
   if (!"$dp_user") {
      $dp_user = get_dp_user;
   }
   my $post = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
<soapenv:Body>
<dp:GetDomainListRequest xmlns:dp="http://www.datapower.com/schemas/appliance/management/1.0"/>
</soapenv:Body>
</soapenv:Envelope>
EOF
   my ($response, $error) = AMP($dp_user, $server, $post, $attrs);
   if ($response =~ /amp:domain/is) {
      my @domains;

      #      <amp:Domain>support_websvc_eci_alpha</amp:Domain>
      while ($response =~ /\<amp:domain>([^\<]+)/gis) {
         push @domains, $1;
      }
      return @domains;
   }
   else {
      print STDERR "$response\n$error";
      exit;
   }
}

#******************************************************************
# Retrieve object configuration from device
#******************************************************************
sub getDomainConfig {
   my ($dp_user, $server) = @_;
   if (!"$dp_user") {
      $dp_user = get_dp_user;
   }
   my $post = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
<soapenv:Body>
<dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="default">
<dp:get-config/>
</dp:request>
</soapenv:Body>
</soapenv:Envelope>
EOF
   my ($response, $error) = SOMA($dp_user, $server, $post);
   my $domains = {};
   if ($response =~ /dp:config/is) {
      while ($response =~ /(\<Domain .+?name=\"([^\"]+).+?\<\/Domain\>)/gis) {
         my $domain = $1;
         my ($name) = $domain =~ /name=\"([^\"]+)/is;
         while (
            $domain =~ /
	           \<([^\>]+)>
	           ([^\<]+)
	           /gisx
           ) {
            my ($attr) = (split(/\s/, $1))[0];
            my ($value) = $2;
            $domains->{$name}->{ lc($attr) } = $value;
         }
      }
      return $domains;
   }
   else {
      print STDERR "$response\n$error";
      exit;
   }
}

#******************************************************************
# Retrieve object configuration from device
#******************************************************************
sub getDomainStatus {
   my ($dp_user, $server, $domain) = @_;
   if (!"$dp_user") {
      $dp_user = get_dp_user;
   }
   my $post = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
<soapenv:Body>
<dp:GetDomainStatusRequest xmlns:dp="http://www.datapower.com/schemas/appliance/management/1.0">
<dp:Domain>
$domain
</dp:Domain>
</dp:GetDomainStatusRequest>
</soapenv:Body>
</soapenv:Envelope>
EOF
   my ($response, $error) = AMP($dp_user, $server, $post);
   my $domains = {};
   if ($response =~ /amp:Domain/is) {

      # <?xml version="1.0" encoding="UTF-8"?>
      # <env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
      # <env:Body><amp:GetDomainStatusResponse xmlns:amp="http://www.datapower.com/schemas/appliance/management/1.0">
      # <amp:Domain name="support_websvc_eci_ivt"><amp:OpState>up</amp:OpState><amp:ConfigState>saved</amp:ConfigState>
      # <amp:DebugState>true</amp:DebugState></amp:Domain></amp:GetDomainStatusResponse></env:Body></env:Envelope>
      my ($status) = $response =~ /(<amp:domain\s.+?<\/amp:domain>)/is;
      while (
         $status =~ /
	           \<([^\>]+)>
	           ([^\<]+)
	           /gisx
        ) {
         my ($attr) = (split(/\s/, $1))[0];
         my ($value) = $2;
         $domains->{$domain}->{ lc($attr) } = $value;
      }
      return $domains;
   }
   else {
      print STDERR "$post\n$response\n$error";
      exit;
   }
}

#**************************************************************
# get domain object status
#**************************************************************
sub readObjectStatus {
   my ($dp_user, $server, $domain) = @_;
   if (!"$dp_user") {
      $dp_user = get_dp_user;
   }
   my $post = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
<soapenv:Body>
<dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="$domain">
<dp:get-status class="ObjectStatus"/>
</dp:request>
</soapenv:Body>
</soapenv:Envelope>
EOF
   my ($response, $error) = SOMA($dp_user, $server, $post);
   if ($response =~ /dp:status/s) {
      my $objects;
      while ($response =~ /(<objectstatus.+?<\/objectstatus>)/gis) {
         my $object = $1;
         my $obj;
         my $name;
         while (
            $object =~ /
	           \<([^\>]+)>
	           ([^\<]+)
	           /gisx
           ) {
            my ($attr) = (split(/\s/, $1))[0];
            my ($value) = $2;
            if (lc($attr) eq 'name') {
               $name = $value;
            }
            elsif ($attr !~ /^\//) {
               $attr =~ s/\///g;
               chomp $value;
               $obj->{ lc($attr) } = $value;
            }
         }
         $objects->{$name} = $obj;
      }
      return $objects;
   }
   else {
      print STDERR "$post\n$response\n$error";
      exit;
   }
}

#******************************************************************
# Get list of files
#******************************************************************
sub getFileList {
   my ($dp_user, $server, $domain, $directory, $attrs) = @_;
   if (!"$dp_user") {
      $dp_user = get_dp_user;
   }
   my $post = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
<soapenv:Body>
<dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="$domain">
<dp:get-filestore/>
</dp:request>
</soapenv:Body>
</soapenv:Envelope>
EOF
   if ($attrs->{'k'}) {
      $attrs->{'domain'}  = $domain;
      $attrs->{'request'} = 'filelist';
   }
   my ($response, $error) = SOMA($dp_user, $server, $post, $attrs);
   if ($response =~ /dp:filestore/s) {

      #       $response =~ /(<location.+?<\/location>)/gis;
      #       my $location=$1;
      #       followtree($location,0);
   }
   else {
      print STDERR "$post\n$response\n$error";
      exit;
   }
}
my $i = 0;

sub followtree {
   my ($data, $depth) = @_;
   print "followtree $depth\n";
   while ($data =~ /<directory(.*)<\/directory>/gis) {
      my $directory = $1;
      $i++;
      exit if $i > 20;
      my ($name) = $directory =~ /name=\"([^\"]+)/;
      print "\t" x $depth . "$name \n";
      followtree($directory, $depth + 1);
   }
}

#******************************************************************
# Save domain
#******************************************************************
sub save {
   my ($dp_user, $server, $domain) = @_;
   if (!"$dp_user") {
      $dp_user = get_dp_user;
   }
   my $post = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
<soapenv:Body>
<dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="$domain">
<dp:do-action><SaveConfig/></dp:do-action>
</dp:request>
</soapenv:Body>
</soapenv:Envelope>
EOF
   my ($response, $error) = SOMA($dp_user, $server, $post);
   if ($response =~ /dp:result/s) {
      my ($result) = $response =~ /<dp:result>(.*)<\/dp:result>/is;
      $result =~ s/^\s+|\s+$//gis;
      if ($result !~ /OK/i) {
         print STDERR "$post\n$response\n$error";
         exit;
      }
      else {
         print "$domain saved\n";
         return 1;
      }
   }
   else {
      print STDERR "$post\n$response\n$error";
      exit;
   }
}

#------------------------------------------------------------------
# Set state of an object enabled/ disabled
#------------------------------------------------------------------
sub setObjectState {
   my ($dp_user, $server, $domain, $class, $name, $state) = @_;
   if (!"$dp_user") {
      $dp_user = get_dp_user;
   }
   if ($state !~ /(?:enabled|disabled)/i) {
      print STDERR "Invalid state $state\n";
      exit;
   }
   my $post = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
<soapenv:Body>
<dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="$domain">
<dp:modify-config>
<$class name="$name">
<mAdminState>$state</mAdminState>
</$class>
</dp:modify-config>
</dp:request>
</soapenv:Body>
</soapenv:Envelope>
EOF
   my ($response, $error) = SOMA($dp_user, $server, $post);
   if ($response =~ /dp:result/s) {
      my ($result) = $response =~ /<dp:result>(.*)<\/dp:result>/is;
      $result =~ s/^\s+|\s+$//gis;
      if ($result !~ /OK/i) {
         print STDERR "$post\n$response\n$error";
         exit;
      }
      else {
         print "$class $name $state\n";
         return 1;
      }
   }
   else {
      print STDERR "$post\n$response\n$error";
      exit;
   }
}

#------------------------------------------------------------------
# Disable Domain
#------------------------------------------------------------------
sub DomainQuiesce {
   my ($dp_user, $server, $domain) = @_;
   if (!"$dp_user") {
      $dp_user = get_dp_user;
   }
   my $post = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
<soapenv:Body>
<dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="default">
<dp:do-action>
<DomainQuiesce>
<name>$domain</name>
<timeout>60</timeout>
</DomainQuiesce>
</dp:do-action>
</dp:request>
</soapenv:Body>
</soapenv:Envelope>
EOF
   my ($response, $error) = SOMA($dp_user, $server, $post);
   if ($response =~ /dp:result/s) {
      my ($result) = $response =~ /<dp:result>(.*)<\/dp:result>/is;
      $result =~ s/^\s+|\s+$//gis;
      if ($result !~ /OK/i) {
         print STDERR "$post\n$response\n$error";
         exit;
      }
      print "Domain $domain disabled\n";
      return 1;
   }
   else {
      print STDERR "$post\n$response\n$error";
      exit;
   }
}

#------------------------------------------------------------------
# Enable Domain
#------------------------------------------------------------------
sub DomainUnquiesce {
   my ($dp_user, $server, $domain) = @_;
   if (!"$dp_user") {
      $dp_user = get_dp_user;
   }
   my $post = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
<soapenv:Body>
<dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="default">
<dp:do-action>
<DomainUnquiesce>
<name>$domain</name>
</DomainUnquiesce>
</dp:do-action>
</dp:request>
</soapenv:Body>
</soapenv:Envelope>
EOF
   my ($response, $error) = SOMA($dp_user, $server, $post);
   if ($response =~ /dp:result/s) {
      my ($result) = $response =~ /<dp:result>(.*)<\/dp:result>/is;
      $result =~ s/^\s+|\s+$//gis;
      if ($result !~ /OK/i) {
         print STDERR "$post\n$response\n$error";
         exit;
      }
      print "Domain $domain enabled\n";
      return 1;
   }
   else {
      print STDERR "$post\n$response\n$error";
      exit;
   }
}
1;
