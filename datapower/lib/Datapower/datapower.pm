package datapower;    
use strict;
use SOAP::Lite +debug;
use Data::Dumper;
use MIME::Base64;
use Archive::Zip;
sub new {
   my ($type) = $_[0];
   my ($self) = {};
   $self->{'server'} = $_[1];
   $self->{'login'}  = $_[2];
   $self->{'passwd'} = $_[3];
   my $url  = 'https://' . $self->{'server'} . '.mydomain.org:5550/service/mgmt/current';
   my $uri  = 'http://www.datapower.com/schemas/management';
   my $soap = SOAP::Lite->proxy($url)->uri($uri)->readable('1');
   my $req  = $soap->transport->http_request;
   $req->authorization_basic($self->{'login'}, $self->{'passwd'});
   $self->{'uri'}  = $uri;
   $self->{'soap'} = $soap;
   bless($self, $type);
   return ($self);
}

sub import_domain {
   my ($self) = $_[0];    #Find yourself my $domain= $_[1]; my $depPol = $_[2]; my $file = $_[3]; my $soap = $self->
   {
      'soap'
   };
   my $depl_msg = SOAP::Data->name('dp:do-import')->attr({
                                                           'dry-run'           => 'true',
                                                           'source-type'       => 'ZIP',
                                                           'overwrite-objects' => 'true',
                                                           'overwrite-files'   => 'true',
                                                           'rewrite-local-ip'  => 'true'
                                                         }
     )->value(
              \SOAP::Data->value(
                                 SOAP::Data->name('dp:input-file')->type('')->value($file),
                                 SOAP::Data->name('dp:object')->type('')->attr({
                                                                                 'name'      => 'all-objects',
                                                                                 'class'     => 'ConfigDeploymentPolicy',
                                                                                 'overwrite' => 'true'
                                                                               }
                                 )
              )
     );
   my $imp_msg = SOAP::Data->name('dp:do-import')->attr({
                                                          'dry-run'           => 'true',
                                                          'source-type'       => 'ZIP',
                                                          'overwrite-objects' => 'true',
                                                          'overwrite-files'   => 'true',
                                                          'deployment-policy' => $depPol,
                                                          'rewrite-local-ip'  => 'true'
                                                        }
     )->value(
              \SOAP::Data->value(
                                 SOAP::Data->name('dp:input-file')->type('')->value($file),
                                 SOAP::Data->name('dp:object')->type('')->attr({
                                                                                 'name'      => 'all-objects',
                                                                                 'class'     => 'all-classes',
                                                                                 'overwrite' => 'true'
                                                                               }
                                 )
              )
     );
   my $som =
     $soap->call(SOAP::Data->name('request')->prefix('dp')->uri($self->{'uri'})->attr({ domain => $domain }) => $depl_msg);
   die $som->fault->{'faultstring'}
     if ($som->fault);
   $som = $soap->call(SOAP::Data->name('request')->prefix('dp')->uri($self->{'uri'})->attr({ domain => $domain }) => $imp_msg);
   die $som->fault->{'faultstring'}
     if ($som->fault);
}

sub export_domain {
   my ($self) = $_[0];    #Find yourself my $domain= $_[1]; my $depPol = $_[2]; my $soap = $self->
   {
      'soap'
   };
   my $exp_msg = SOAP::Data->name('dp:do-export')->attr({
                                                          'format'            => 'ZIP',
                                                          'all-files'         => 'true',
                                                          'deployment-policy' => $depPol
                                                        }
     )->value(
              \SOAP::Data->value(
                                 SOAP::Data->name('dp:object')->attr({
                                                                       name          => 'all-objects',
                                                                       class         => 'all-classes',
                                                                       'ref-objects' => 'true'
                                                                     }
                                 )
              )
     );
   my $som = $soap->call(SOAP::Data->name('request')->prefix('dp')->uri($self->{'uri'})->attr({ domain => $domain }) => $exp_msg);
   die $som->fault->{'faultstring'}
     if ($som->fault);
   return (decode_base64($som->valueof('//response/file')));
}

sub upload_cert {
   my ($self) = $_[0];    #Find yourself my $cert = $_[1]; my $soap = $self->
   {
      'soap'
   };
   my $cert_name    = $cert->{'cert_name'};
   my $key_name     = $cert->{'key_name'};
   my $cert_data    = encode_base64($cert->{'cert_data'});
   my $key_data     = encode_base64($cert->{'key_data'});
   my $cert_message = SOAP::Data->name('dp:set-file')->attr({ name => "cert:///" . $cert_name })->type('')->value($cert_data);
   my $key_message  = SOAP::Data->name('dp:set-file')->attr({ name => "cert:///" . $key_name })->type('')->value($key_data);
   my $som = $soap->call(
        SOAP::Data->name('request')->prefix('dp')->uri($self->{'uri'})->attr({ 'domain' => $cert->{'region'} }) => $cert_message);
   my $som = $soap->call(
         SOAP::Data->name('request')->prefix('dp')->uri($self->{'uri'})->attr({ 'domain' => $cert->{'region'} }) => $key_message);
}

sub create_cert_objects {
   my ($self) = $_[0];    #Find yourself my $cert = $_[1]; my $app = $_[2]; my $soap = $self->
   {
      'soap'
   };
   my $cert_dest = "cert:///" . $cert->{'cert_name'};
   my $cert_name = $app;
   if ($cert->{'key_name'}) {
      my $key_dest = "cert:///" . $cert->{'key_name'};
      my $key_name = $app;
   }
   my $cert_message = SOAP::Data->name('dp:set-config')->value(
                                                  \SOAP::Data->value(
                                                     SOAP::Data->attr({ 'name' => $cert_name })->name('CryptoCertificate')->value(
                                                                   \SOAP::Data->value(
                                                                      SOAP::Data->type('')->name('Filename')->value($cert_dest),
                                                                      SOAP::Data->type('')->name('Password')->value(''),
                                                                      SOAP::Data->type('')->name('PasswordAlias')->value('off'),
                                                                      SOAP::Data->type('')->name('IgnoreExpiration')->value('off')
                                                                   )
                                                     )
                                                  )
   );
   my $som = $soap->call(
        SOAP::Data->name('request')->prefix('dp')->uri($self->{'uri'})->attr({ 'domain' => $cert->{'region'} }) => $cert_message);
   if ($key_name) {
      my $key_message = SOAP::Data->name('dp:set-config')->value(
             \SOAP::Data->value(
                SOAP::Data->attr({ 'name' => $key_name })->name('CryptoKey')->value(
                   \SOAP::Data->value(
                      SOAP::Data->type('')->name('Filename')->value($key_dest), SOAP::Data->type('')->name('Password')->value(''),
                      SOAP::Data->type('')->name('PasswordAlias')->value('off'),
                   )
                )
             )
      );
      my $som = $soap->call(
         SOAP::Data->name('request')->prefix('dp')->uri($self->{'uri'})->attr({ 'domain' => $cert->{'region'} }) => $key_message);
   }
}

sub backup_file {
   my ($self) = $_[0];    #Find yourself my $domain = $_[1]; my $file = $_[2]; $self->
   {
      'domain'
   }
   = $domain;
   my $soap = $self->{'soap'};
   my $bak =
     SOAP::Data->name('do-backup')->attr({ format => 'ZIP' })->value(\SOAP::Data->name('domain')->attr({ name => $domain }));
   my $som = $soap->request($bak);
   die $som->fault->{faultstring}
     if ($som->fault);
   my $tmp = new IO::Handle;
   open $tmp, '>', $file;

   if ($file eq '-') {
      print STDOUT decode_base64($som->valueof('//response/file'));
   }
   else {
      print $tmp decode_base64($som->valueof('//response/file'));
   }
}

return (1);    #package files must always return 1.
