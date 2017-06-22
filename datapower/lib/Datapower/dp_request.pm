#!/usr/local/bin/perl
package Datapower::dp_request;
use strict;
use warnings;
use FindBin;
use lib ("$FindBin::Bin/lib", "$FindBin::Bin/../lib");
use MIME::Base64;
use Data::Dumper;
use LWP::Simple;
use base 'Exporter';
our @EXPORT = qw(new);
our @EXPORT_OK;
use Term::ReadKey;
use EI::DirStore;
use constant HEADER => '
<?xml version="1.0" encoding="UTF-8"?>
   <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
	  <soapenv:Body>
	';
use constant TRAILER => '
   </soapenv:Body>
</soapenv:Envelope>';
my $AMP  = 'https://${server}e0.event.ibm.com:5550/service/mgmt/amp/1.0';
my $SOMA = 'https://${server}e0.event.ibm.com:5550/service/mgmt/current';

sub new {
   printf STDERR "\t%s -> %s at %d\n", (caller(0))[ 0, 3, 2 ] if $ENV{DPDEBUG};
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self  = {};
   bless $self, $class;
   $self->_init(@_);
   return $self;
}

#----------------------------------------------------------------------
# setup object using parms passed to it
#----------------------------------------------------------------------
sub _init {
   my $self = shift;
   $self->_trace_sub;
   my %args = @_;
   $self->debug($ENV{'DPDEBUG'});
   foreach my $key (keys %args) {
      $self->$key($args{$key});
   }
   if (!$self->user) {
      $self->user($self->_get_user());
   }
   if (!$self->password) {
      $self->password($self->_get_password());
   }
   else {
      print "password is $self->password\n";
   }
}

#----------------------------------------------------------------------
# Lookup intranet id in dirstore
#----------------------------------------------------------------------
sub _get_user {
   my $self = shift;
   $self->_trace_sub;
   my $user = getpwuid($<);
   if (!$user) {
      print "Intranet Userid: ";
      $user = ReadLine 0;
      chomp $user;
   }
   dsConnect;
   my %results;
   dsSearch(%results, "person", expList => ["uid==$user"], attrs => ['mail']);
   dsDisconnect;
   if (%results) {
      my $intranet_id = $results{ (keys %results)[0] }{'mail'}[0];
      if (!$intranet_id) {
         print STDERR "Unable to find intranet id for $user, check mail set in dirstore";
         return;
      }
      return $intranet_id;
   }
   else {
      print STDERR "Unable to find intranet id for $user, check mail set in dirstore";
      return;
   }
}

#----------------------------------------------------------------------
# Lookup or prompt for password
#----------------------------------------------------------------------
sub _get_password {
   my $self = shift;
   $self->_trace_sub;
   my $password = $ENV{intranet_pw};
   if (!$password) {
      print STDERR "Password not set in env var\n";
      my ($id, $pw);
      if (-e glob('~/.ssh/.ip')) {
         {
            local $/ = undef;
            open FILE, "<", glob('~/.ssh/.ip') or die "Couldn't open file: $!";
            binmode FILE;
            my $file = <FILE>;
            close FILE;
            $file = decode_base64($file);
            $file = decode_base64($file);
            ($id, $pw) = $file =~ /(.*):(.*)/;
         }
         if ($id eq $self->user) {
            $password = $pw;
         }
      }
      else {
         print "Enter password for " . $self->user . ": ";
         ReadMode 'noecho';
         $password = ReadLine 0;
         chomp $password;
         ReadMode 'normal';
         print "\n";
      }
   }
   return $password;
}

#=============================================================
#
#=============================================================
sub args {
   my $self = shift;
   if (@_) {
      push @{ $self->{_args} }, shift;
   }
   return $self->{_args};
}

#----------------------------------------------------------------------
# get/set debug
#----------------------------------------------------------------------
sub debug {
   my $self = shift;
   if (@_) {
      $self->{_debug} = shift;
   }
   return $self->{_debug};
}

#----------------------------------------------------------------------
# get/set userid
#----------------------------------------------------------------------
sub user {
   my $self = shift;
   if (@_) {
      $self->{_user} = shift;
   }
   return $self->{_user};
}

#----------------------------------------------------------------------
# get/set password
#----------------------------------------------------------------------
sub password {
   my $self = shift;
   $self->_trace_sub;
   if (@_) {
      $self->{_password} = shift;
   }
   return $self->{_password};
}

#----------------------------------------------------------------------
# return the list of domains
#----------------------------------------------------------------------
sub domains {
   my $self = shift;
   $self->_trace_sub;
   my $server = shift;
   return @{ $self->{_servers}->{$server} };
}

sub diff {
   my ($self, $server, $domain) = @_;
   $self->current_server($server);
   $self->type('SOMA', $domain);    # soma request to a specific domain
   $self->xml(  '<dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="' 
              . $domain . '">'
              . '<dp:get-diff>'
              . '<dp:from>'
              . '   <dp:object class="all-classes" name="all-objects" persisted="true"/>'
              . ' </dp:from>'
              . ' <dp:to>'
              . '  <dp:object class="all-classes" name="all-objects" persisted="false"/>'
              . ' </dp:to>'
              . '</dp:get-diff>'
              . '</dp:request>');
   my $response = $self->execute;
   $response = $response->getElementByTagName('dp:diff');
   $response = $response->getNextElement;
   return $response;
}

#----------------------------------------------------------------------
# Backup a domain
#----------------------------------------------------------------------
sub backup_domain {
   my ($self, $server, $domain) = @_;
   $self->current_server($server);
   $self->type('SOMA');
   $self->xml(  '<dp:request xmlns:dp="http://www.datapower.com/schemas/management">'
              . '		<dp:do-backup format="ZIP">'
              . '			<dp:domain name="'
              . $domain . '"/>'
              . '		</dp:do-backup>'
              . '	</dp:request>');
   my $response = $self->execute;
   my $file     = $response->getElementByTagName('dp:file')->text;
   $file = decode_base64($file);
   my $filename = $self->current_server . '_' . $domain . '_backup.zip';
   open BKP, ">", ${filename};
   print BKP $file;
   close BKP;
   return $filename;
}

#-------------------------------------------------------------------
# Get list of defined domains
#-------------------------------------------------------------------
sub list_domains {
   my $self = shift;
   $self->_trace_sub;
   $self->type('AMP', 'GetDomainListRequest');
   $self->xml(' ');
   my $response = $self->execute;
   return map { $_->text } $response->getElementByTagName('amp:Domain');
}

sub soma_domain {
   my $self = shift;
   $self->_trace_sub;
   return $self->{_envelope_parm};
}

sub amp_request {
   my $self = shift;
   $self->_trace_sub;
   return $self->{_envelope_parm};
}

sub envelope_parm {
   my $self = shift;
   $self->_trace_sub;
   if (@_) {
      $self->{_envelope_parm} = shift;
      if ($self->{_envelope_parm} eq '.') {
         $self->{_envelope_parm} = undef;
      }
   }
   return $self->{_envelope_parm};
}

#=============================================================
# Send request to AMP/SOMA on server
#=============================================================
sub execute {
   my $self = shift;
   $self->_trace_sub;
   if ($self->type eq 'SOMA') {
      my $dprequest = '<dp:request xmlns:dp="http://www.datapower.com/schemas/management"';
      if ($self->soma_domain) {
         $dprequest .= ' domain="' . $self->soma_domain . '"';
      }
      $dprequest .= '>';
      $self->xml(HEADER . $dprequest . $self->xml . '</dp:request>' . TRAILER);
   }
   elsif ($self->type eq 'AMP') {
      my $dprequest = '<dp:' . $self->amp_request . ' xmlns:dp="http://www.datapower.com/schemas/appliance/management/1.0">';
      $self->xml(HEADER . $dprequest . $self->xml . '</dp:' . $self->amp_request . '>' . TRAILER);
   }
   else {
      return;
   }
   my %router = (
                 AMP  => \&AMP_request,
                 SOMA => \&SOMA_request
   );
   my $proc     = $router{ $self->type };
   my $response = $self->$proc;
   $self->envelope_parm('.');
   $self->xml(undef);
   return $response;
}

#=============================================================
#
#=============================================================
sub type {
   my $self = shift;
   if (@_) {
      $self->{_type} = shift;
      if (@_) {
         $self->envelope_parm(shift);
      }
   }
   return $self->{_type};
}

#-------------------------------------------------------------------
# Applicance Management Protocol request
#-------------------------------------------------------------------
sub AMP_request {
   my $self = shift;
   $self->_trace_sub;
   my $server  = $self->current_server;
   my $browser = LWP::UserAgent->new;
   my $url     = "https://${server}e0.event.ibm.com:5550/service/mgmt/amp/1.0";
   my $req     = HTTP::Request->new(POST => $url);
   $req->content($self->xml);
   $req->authorization_basic($self->user, $self->password);

   if ($self->debug) {
      print "-" x 80 . "\n" . $req->as_string() . "-" x 80 . "\n";
   }
   my $res = $browser->request($req) if $self->debug < 2;
   if ($res->is_success) {
      if ($self->debug) {
         print "-" x 80 . "\n" . $res->as_string() . "-" x 80 . "\n";
      }
      return ParseXML::ParseXML->new($res->decoded_content);
   }
   else {
      print "Error: " . $res->status_line . "\n";
      return;
   }
}

#=============================================================
#
#=============================================================
sub xml {
   my $self = shift;
   if (@_) {
      $self->{_xml} = shift;
      $self->{_xml} =~ s/^\s+// if $self->{_xml};
   }
   return $self->{_xml};
}

#------------------------------------------------------------------
# Save config
#------------------------------------------------------------------
sub save {
   my ($self, $server, $domain) = @_;
   print "Saving $server: $domain\n";
   $self->current_server($server);
   $self->type('SOMA');
   $self->xml(  '<dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain ="' 
              . $domain . '">'
              . '    <dp:do-action>'
              . '      <SaveConfig/>'
              . '    </dp:do-action>'
              . '</dp:request>');
   my $response = $self->execute;
}

#------------------------------------------------------------------
# Get a list of files
#------------------------------------------------------------------
sub file_list {
   my ($self, $server, $domain) = @_;
   my $file_system = shift;
   $self->current_server($server);
   ($file_system) = $file_system =~ /([\w\-\_]+:)/;
   $self->type('SOMA');
   $self->xml(  '< dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="' 
              . $domain . '" >'
              . '   <dp:get-filestore location="'
              . $file_system . '"/>'
              . ' < /dp:request>');
   my $response = $self->execute;
   return $response;
}

#------------------------------------------------------------------
# Set state of an object enabled/ disabled
#------------------------------------------------------------------
sub set_object_state {
   my ($self, $server, $domain, $class, $name, $state) = @_;
   $self->current_server($server);
   $self->type('SOMA');
   $self->xml(  '<dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="' 
              . $domain . '">'
              . '   <dp:modify-config>'
              . '      <'
              . $class
              . ' name="'
              . $name . '">'
              . '        <mAdminState>'
              . $state
              . '</mAdminState>'
              . '      </'
              . $class . '>'
              . '   </dp:modify-config>'
              . '</dp:request>');
   my $response = $self->execute;
}

#------------------------------------------------------------------
# Add certificate object to valcred
#------------------------------------------------------------------
sub cert_valcred {
   return;
   my $self = shift;
   my ($domain, $cert_object, $valcred_type) = @_;
   if (valid_domain($self, $domain)) {
      if ($valcred_type eq "server-ValCred" || $valcred_type eq "client-ValCred") {
         my $request_xml = HEADER . '<dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="' . $domain . '">
		     <dp:get-config class="CryptoValCred" name="' . $valcred_type . '"/>
		  </dp:request>
		  ' . TRAILER;
         my $response = SOMA_request($self, $request_xml);
         my $cred = $response->getElementByTagName('CryptoValCred')->as_text;
         if ($cred) {

            # add the cert object to the cred
            $cred =~ s/<\/mAdminState>
         /<\/mAdminState>
         <Certificate class="CryptoCertificate">$cert_object<\/Certificate>/xism;
            my $request_xml =
                HEADER
              . '<dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="'
              . $domain . '">
     <dp:set-config>
     ' . $cred . '
     </dp:set-config>
     </dp:request>
   ' . TRAILER;
            my $response = SOMA_request($self, $request_xml);
            foreach my $result ($response->getElementByTagName('dp:response')) {
               print $result->getElementByTagName('dp:result')->text . "\n";
            }
         }
         else {
            print "didnt find client-valcred\n";
            exit;
         }
      }
      else {
         print "$valcred_type is invalid ValCred type\n";
         exit;
      }
   }
}

#------------------------------------------------------------------
# Create a certificate object
#------------------------------------------------------------------
sub create_cert {
   return;
   my $self = shift;
   my ($domain, $cert_object, $filename) = @_;
   if (valid_domain($self, $domain)) {
      my $request_xml = HEADER . '<dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="' . $domain . '">
     <dp:set-config>
        <CryptoCertificate name="' . $cert_object . '">
            <Filename>' . $filename . '</Filename>
            <IgnoreExpiration>on</IgnoreExpiration>
        </CryptoCertificate>
        </dp:set-config>
     </dp:request>
   ' . TRAILER;
      my $response = SOMA_request($self, $request_xml);
      print $response->as_text;
      foreach my $result ($response->getElementByTagName('dp:response')) {
         print $result->getElementByTagName('dp:result')->text . "\n";
      }
   }
}

#==============================================================================
# Get status of requested domains
#==============================================================================
sub domain_status {
   my ($self, $server, $domain) = @_;
   $self->_trace_sub;
   $self->current_server($server);
   $self->type('AMP', 'GetDomainStatusRequest');
   $self->xml('<dp:Domain>' . $domain . '</dp:Domain>');
   my $response = $self->execute;
   my $status   = {};
   foreach my $status_response ($response->getElementByTagName('amp:GetDomainStatusResponse')) {

      foreach my $domain ($status_response->getElementByTagName('amp:Domain')) {
         $status->{ $domain->attr('name') } = {
                                                opstate     => $domain->getElementByTagName('amp:OpState')->text,
                                                configstate => $domain->getElementByTagName('amp:ConfigState')->text,
                                                debugstate  => $domain->getElementByTagName('amp:DebugState')->text,
         };
      }
   }
   return $status;
}

#------------------------------------------------------------------
# Get config info for certificates
#------------------------------------------------------------------
sub cert_config {
   my ($self, $server, $domain) = @_;
   $self->current_server($server);
   $self->type('SOMA',$domain);
   $self->xml('   <dp:get-config class="CryptoCertificate"/>');
   my $response    = $self->execute;
   my %cert_config = map {
      $_->attr("name") => {
                            "state"    => $_->getElementByTagName('mAdminState')->text,
                            "filename" => $_->getElementByTagName('Filename')->text,
                            "exp"      => $_->getElementByTagName('IgnoreExpiration')->text,
        }
   } $response->getElementByTagName('CryptoCertificate');
   return \%cert_config;
}

#------------------------------------------------------------------
# Get config info for valcreds
#------------------------------------------------------------------
sub valcred_config {
   my ($self, $server, $domain) = @_;
   $self->current_server($server);
   $self->type('SOMA',$domain);
   $self->xml(' <dp:get-config class="CryptoValCred"/>');
   my $response       = $self->execute;
   my %valcred_config = map {
      $_->attr("name") => {
                            "state" => $_->getElementByTagName('mAdminState')->text,
                            "certs" => { map { $_->text => defined } $_->getElementByTagName('Certificate') }
        }
   } $response->getElementByTagName('CryptoValCred');
   return \%valcred_config;
}

#------------------------------------------------------------------
# Get status info for all objects
#------------------------------------------------------------------
sub object_status {
   my ($self, $server, $domain) = @_;
   my %objectclass = map { lc($_) => defined } @_;
   $self->type('SOMA',$domain);
   $self->xml('<dp:get-status class="ObjectStatus"/>');
   my $response = $self->execute;
   my $status   = {};
   foreach my $object ($response->getElementByTagName('ObjectStatus')) {

      #      print $object->getElementByTagName('Name')->text . " " . $object->getElementByTagName('Class')->text ." \n";
      if (!%objectclass || defined $objectclass{ lc($object->getElementByTagName('Class')->text) }) {
         $status->{ $object->getElementByTagName('Class')->text }->{ $object->getElementByTagName('Name')->text } = {
                                                               "opstate"     => $object->getElementByTagName('OpState')->text,
                                                               "adminstate"  => $object->getElementByTagName('AdminState')->text,
                                                               "configstate" => $object->getElementByTagName('ConfigState')->text,
         };
      }
   }
   return $status;
}

#---------------------------------------------------------------
# SOAP request to retrieve a file
#---------------------------------------------------------------
sub get_file {
   my ($self, $server, $domain, $filename) = @_;
   $self->current_server($server);
   $self->type('SOMA');
   $self->xml(
      '<dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="' . $domain . '">
			<dp:get-file name="' . $filename . '"/>				
		</dp:request>'
   );
   my $response = $self->execute;
   my $file     = $response->getElementByTagName('dp:file')->text;
   $file = decode_base64($file);
   $filename =~ s/^.*:\/\/\///;
   $filename = $server . "_${domain}_${filename}.txt";
   open LOG, ">", ${filename};
   print LOG $file;
   close LOG;
   return $filename;
}

sub delete_file {
   my $self   = shift;
   my $domain = shift;
   my $file   = shift;
   if (valid_domain($self, $domain)) {
      my $request_xml = HEADER . '<dp:request xmlns:dp="http://www.datapower.com/schemas/management"> domain="' . $domain . '"
            <dp:do-action>
               <DeleteFile>
                  <File>' . $file . '</File>
               </DeleteFile>
            </dp:do-action>
         </dp:request>' . TRAILER;
      my $response = SOMA_request($self, $request_xml);
   }
}

#=============================================================
#  Add server
#=============================================================
sub server {
   my $self = shift;
   $self->_trace_sub;
   if (@_) {
      my $server = shift;
      $self->current_server($server);
      @{ $self->{_servers}->{$server} } = $self->list_domains;
   }
   return sort(keys %{ $self->{_servers} });
}

#=============================================================
#
#=============================================================
sub current_server {
   my $self = shift;
   $self->_trace_sub;
   if (@_) {
      $self->{_server} = shift;
   }
   return $self->{_server};
}

#-------------------------------------------------------------------
# Configuration request
#-------------------------------------------------------------------
sub SOMA_request {
   my $self = shift;
   $self->_trace_sub;
   my $server  = $self->current_server;
   my $browser = LWP::UserAgent->new;
   my $url     = "https://${server}e0.event.ibm.com:5550/service/mgmt/current";
   my $req     = HTTP::Request->new(POST => $url);
   $req->content($self->xml);
   $req->authorization_basic($self->user, $self->password);

   if ($self->debug) {
      print "-" x 80 . "\n" . $req->as_string() . "-" x 80 . "\n";
   }
   my $res = $browser->request($req) if $self->debug < 2;
   if ($res->is_success) {
      if ($self->debug) {
         print "-" x 80 . "\n" . $res->as_string() . "-" x 80 . "\n";
      }
      return ParseXML::ParseXML->new($res->decoded_content);
   }
   else {
      print "Error: " . $res->status_line . "\n";
      return;
   }
}

sub _trace_sub {
   my $self   = shift;
   my $caller = (caller(2))[3];
   if (defined $caller) {
      printf STDERR "\t%s -> %s at %d\n", $caller, (caller(1))[ 3, 2 ] if $self->debug;
   }
   else {
      printf STDERR "\t%s -> %s at %d\n", (caller(1))[ 0, 3, 2 ] if $self->debug;
   }
}
1;
