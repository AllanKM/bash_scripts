#!/usr/local/bin/perl
#================================================================================
# $Revision: 1.6 $
#================================================================================
use strict;
use Data::Dumper;
use IPC::Open3;
use Sys::Hostname;
my $host     = hostname;
my $run_date = localtime;
my $fails    = 0;
my $data     = {};
my $debug=$ENV{'debug'} || '';
my $fh;
 my @abbr = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
localtime(time);
my $month = sprintf "%s%4d",$abbr[$mon],$year+=1900;
my $dir = '/fs/scratch/ldap_itcs104';
if ( ! -e $dir ) {
	print STDERR "making $dir\n";
   mkdir $dir;
}
chmod 0770,$dir;
system("chown root:eiadm $dir");

$dir.= "/$month";
if ( ! -e $dir ) {
	print STDERR " making $dir\n";
   mkdir $dir;
}
chmod 0770,$dir;
system("chown root:eiadm $dir");

my @ibmslapd = glob("/db2_*/*/idsslapd*/etc/ibmslapd.conf");
foreach my $conf (sort @ibmslapd) {
   my $file = (split('/',$conf))[2];
	print STDERR "Checking $file\n";
   my $filename = $dir .'/ldap_itcs104_'.${host}.'_'.$mday.$month.'_'.$file.'.log';
   open $fh, '>', $filename;
   $fails = 0;
   $data->{conf} = $conf;
   readconf($conf, $data);
   header($data);
   section2($data);
   section3($data);
   section4($data);
   section5($data, $conf);
   section6($data);
   trailer(); 
   close $fh;
   chmod 0660,$filename;
   system("chown root:eiadm $filename");
}

sub header {
   use Sys::Hostname;
   print $fh qq |
--------------------------------------------------------------------------------

   ITCS 104 Health check IBM Tivoli Directory Server
   Checks to ITCS specification   : Local specifications, not covered in ITCS 104 specs
   Produced by automated tool run : $host:/lfs/system/tools/ldap/bin/ldap_itcs104_scan.pl 
   Run Date                       : $run_date
   
--------------------------------------------------------------------------------
|;
}

sub trailer {
   print $fh "\n" . "*" x 80 . "\n";
   if ($fails == 0) {
      print $fh qq(
**                  Overall Status: Compliant                                 **
);
      print STDERR qq(
**                  Overall Status: Compliant                                 **
);
   }
   else {
      print $fh qq(
**                  Overall Status: Non Compliant                             **
);
      print STDERR qq(
**                  Overall Status: Non Compliant                             **
);
   }
   print $fh "\n" . "*" x 80 . "\n";
}

sub check_perms {
   my $dir   = shift;
   my $opts  = shift;
   my $perms = shift;
   my @names;
   print $fh "\t$dir Checking General users do not have ";
   foreach my $perm (@$perms) {
      if ($perm eq '0002') {
         push @names, "Write";
      }
      elsif ($perm eq '0004') {
         push @names, "Read";
      }
   }
   print $fh join("/", sort @names) . " - ";
   $perms = join(' -o -perm -', @$perms);
   my $fail;
   my $cmd = "find $dir -type f \\( -perm -$perms \\) -ls";

   print "$cmd\n" if $debug;
   open CMD, "$cmd |";
   while (my $line = <CMD>) {

                print $line if $debug;
      $fail = 1;
      $fails++;
   }
   close CMD;
   if ($fail) {
      print $fh "*FAIL*\n";
		print STDERR "\t$dir Checking General users do not have " .join("/", sort @names) . " - *FAIL*\n"
   }
   else {
      print $fh "Pass\n";
   }
}

#================================================================================
#
#================================================================================
sub section6 {
   my $data = shift;
   print $fh qq |
6 Activity auditing
===================
   Required auditing settings
      ibm-audit: true
      ibm-auditBind: true
      ibm-auditExtOp: true
      ibm-auditFailedOPonly: false
      ibm-auditSearch: true
      ibm-auditUnbind: true
      ibm-slapdLog: <log file name>
      
      actual settings:

|;
   print $fh "\t\tibm-audit: $data->{audit}\n";
   print $fh "\t\tibm-auditBind: $data->{auditBind}\n";
   print $fh "\t\tibm-auditExtOp: $data->{auditExtOp}\n";
   print $fh "\t\tibm-auditFailedOPonly: $data->{auditFailedOPonly}\n";
   print $fh "\t\tibm-auditSearch: $data->{auditSearch}\n";
   print $fh "\t\tibm-auditUnbind: $data->{auditUnbind}\n";
   print $fh "\t\tibm-slapdLog: $data->{slapdLog}\n";

   if (   $data->{audit} eq 'true'
       && $data->{auditBind}         eq 'true'
       && $data->{auditExtOp}        eq 'true'
       && $data->{auditFailedOPonly} eq 'false'
       && $data->{auditSearch}       eq 'true'
       && $data->{auditUnbind}       eq 'true'
       && -e $data->{slapdLog}) {
      print $fh "Pass\n";
   }
   else {
      print $fh "*FAIL*\n";
      $fails++;
   }
}

#================================================================================
#
#================================================================================
sub section5 {
   my $data    = shift;
   my $confdir = shift;
   $confdir =~ s/\/ibmslapd.conf//;
   print $fh qq |
5 OSR's
=======
|;

   print $fh "\tGeneral users must not have write access to config directories\n";
   check_perms($confdir,                         { type => 'f' }, [qw(0002)]);
   print $fh "\n\tGeneral users must not have read or write access to log directories\n";
   check_perms("/logs/$data->{slapdDbInstance}", { type => 'f' }, [qw(0002 0004)]);
   print $fh "\n\tGeneral users must not have write access to code directories\n";
   check_perms("/opt/IBM/ldap",                  { type => 'f' }, [qw(0002)]);
}

#================================================================================
#
#================================================================================
sub section3 {
   my $data = shift;
#
#3 Authorization
#===============
#   Standard requirements apply
#
#3.1 Business use notice
#=======================
#   Not applicable

   print $fh qq |
3.2 User resources
==================
   Anonymous searches must be denied
|;
   print $fh "\tibm-slapdAllowAnon: $data->{slapdAllowAnon} - ";
   if (lc($data->{slapdAllowAnon}) eq lc("false")) {
      print $fh "Pass\n";
   }
   else {
      print $fh "*FAIL*\n";
      $fails++;
   }
}

#================================================================================
#
#================================================================================
sub section4 {
   my $data = shift;

#4 Information protection / confidentiality
#==========================================
   print $fh qq |
4.1 Encryption
==============

	Non SSL connections are not permitted unless client application does not support SSL connections
	ibm-slapdSecurity must be set to SSL or SSLOnly
|;
   if ( $data->{slapdSslKeyDatabase} =~/(?:sma|edr)/i ) {
      print $fh "\t$data->{slapdDbInstance} is used by TADDM which does not support SSL ldap connections\n";
   }
   print $fh "\t\tibm-slapdSecurity: $data->{slapdSecurity} - ";
   if ( $data->{slapdSslKeyDatabase} =~/(?:sma|edr)/i ) {
      if (lc($data->{slapdSecurity}) ne lc('SSL')) {
         print $fh "*FAIL*\n";
         print STDERR "Check ibm-slapdSecurity = SSL|SSLOnly    *FAIL*\n";
         $fails++;
      }
      else {
         print $fh "Pass\n";
      }
   }
   else {
      if (lc($data->{slapdSecurity}) ne lc('SSLOnly')) {
         print $fh "*FAIL*\n";
         print STDERR "Check ibm-slapdSecurity = SSL|SSLOnly    *FAIL*\n";
         $fails++;
      }
      else {
         print $fh "Pass\n";
      }
   }
   print $fh qq |	
	
	Certificates must be issued by IBM Internal Certificate authority or purchased from a recognised Certificate authority.	
|;
   cert($data);
   print $fh "\n\n\tibm-slapdSslAuth must be one of serverAuth / serverClientAuth\n";
   if ($data->{slapdDbInstance} eq 'ldapauth') {
      print $fh "Server used for login authentication\n";
   }
   print $fh "\tibm-slapdSslAuth: $data->{slapdSslAuth} - ";
   if ($data->{slapdSslAuth} !~ /(?:serverAuth|serverClientAuth)/i) {
      print $fh "*FAIL*\n";
      print STDERR "\tibm-slapdSslAuth: $data->{slapdSslAuth} - *FAIL*\n";
      $fails++;
   }
   else {
      if ($data->{slapdDbInstance} eq 'ldapauth' && $data->{slapdSslAuth} != /serverClientAuth/i) {
         print $fh "*FAIL*\n";
         print STDERR "\tibm-slapdSslAuth: $data->{slapdSslAuth} - *FAIL*\n";
         $fails++;
      }
      else {
         print $fh "Pass\n";
      }
   }
   my @ciphers = qw ( aes128 aes192 aes256 crypt sha ssha md5 sha224 sha256 sha384 sha512 ssha224 ssha256 ssha384 ssha512 );
   print $fh qq |	
   Password encryption,ibm-slapdPwEncryption must be one of:
|;
   print $fh "\t".join(" / ", @ciphers) . "\n";
   print $fh "\tibm-slapdPwEncryption: $data->{slapdPwEncryption} - ";
   if (!grep(/$data->{slapdPwEncryption}/i, @ciphers)) {
      print $fh "*FAIL*\n";
      print STDERR "\tibm-slapdPwEncryption: $data->{slapdPwEncryption} - *FAIL*\n";
      $fails++;
   }
   else {
      print $fh "Pass\n";
   }
}

#================================================================================
#
#================================================================================
sub section2 {
   my $data = shift;

#2 Authentication
#================
#  Standard requirements apply
   print $fh qq |
2.1 Reusable passwords
======================
   System ids
     default user idsldap is not to be used but is required for s/w maintenance. Password for it must conform to the requirements for non-expiring passwords.
     idsldap: must be configured with security settings which pass non-expiring password rules
|;
   user_check('idsldap');
   print $fh qq |   
    ITDS instance id and database access id must conform to the requirements for non-expiring passwords.
|;
   user_check($data->{slapdDbInstance});
   user_check($data->{slapdDbUserID});
#   print $fh qq |
#
#2.2 Authentication tickets/tokens
#=================================
#   Not applicable
#
#2.3 Passphrases
#===============
#   Not applicable
#   |;
}

#================================================================================
#
#================================================================================
sub user_check {
   my $user = shift;
   my @rows = `/fs/system/bin/chk_nonexpiring_pwd_rules $user`;
   my $pass = 0;
   foreach my $line (@rows) {
      if ($line =~ /(?:passess ITCS Non-Expiring Rules|must have maxage set to 0)/i) {
         $pass = 1;
      }
   }
   if ($pass) {
      printf $fh "\t$user non-expiring password check - %s\n", 'PASS';
   }
   else {
      printf $fh "\t$user non-expiring password check - %s\n", 'FAIL';
      printf STDERR "\t$user non-expiring password check - %s\n", 'FAIL';
      $fails++;
   }
}

#================================================================================
#
#================================================================================
sub readconf {
   my ($conf, $data) = @_;
   open CONF, "<", $conf;
   while (my $line = <CONF>) {
      if (
         $line =~ /^\s*ibm-(
         slapdDbUserID|
         slapdDbInstance|
         slapdAllowAnon|
         slapdSecurity|
         slapdSslAuth|
         slapdSslKeyDatabase|
         slapdSslCertificate|
         slapdPwEncryption|
         audit\w*?|
         slapdlog
         ):\s*(.*)$/ix
        ) {
         $data->{$1} = $2;
      }
   }
   close CONF;
}

sub cert {
   my $data  = shift;
   my $gskit = __gskit();
   my $valid = 0;
   if ($gskit) {
      my $pw = __decode_sth($data);
      my $gscmd =
        "$gskit -cert -details -db \"$data->{slapdSslKeyDatabase}\" -pw \"$pw\" -label \"$data->{slapdSslCertificate}\"";
      my $pid = open3(\*WRITER, \*READER, \*ERROR, $gscmd);
      my ($stdout, $stderr);
      {
         local $/;
         $stdout = <READER>;
      }
      {
         local $/;
         $stderr = <ERROR>;
      }
      waitpid($pid, 0) or die "$!\n";
      close WRITER;
      close READER;
      close ERROR;
      foreach my $line (split(/\n/, $stdout)) {
         if ($line =~ /^(?:Issuer|Owner|Not|Subject)/i) {
            if ($line =~ /Issuer/i) {
               if ($line =~ /(?:IBM|International Business Machines|Equifax|Verisign|Geotrust)/i) {
                  $valid = 1;
               }
            }
            print $fh "\t$line\n";
         }
      }
      if ($valid) {
         print $fh "\tValid cetificate - Pass\n";
      }
      else {
         print $fh "\tValid cetificate - *FAIL*\n";
      }
   }
   else {
      print $fh "Cannot find GSkit\n";
   }
}
##----------------------------------------------------------------------------------------------------------
## Decrypt stashed password
##----------------------------------------------------------------------------------------------------------
sub __decode_sth {
   my $data = shift;
   my $file = $data->{slapdSslKeyDatabase};
   $file =~ s/\.kdb/\.sth/;
   my $pw = '';
   open(F, $file) || die "Can't open $file: $!";
   my $stash;
   read F, $stash, 1024;
   my @unstash = map { $_ ^ 0xf5 } unpack("C*", $stash);

   foreach my $c (@unstash) {
      last if $c eq 0;
      $pw = $pw . sprintf "%c", $c;
   }
   return $pw;
}

sub __gskit {
   my @gskit =
     sort grep (!/gsk8capicmd$/, (glob("/usr/local/ibm/*/bin/gsk*capicmd* /usr/opt/ibm/*/bin/gsk*capicmd*")));
   if (grep /gsk8/, @gskit) {
      @gskit = grep /gsk8/, @gskit;
   }
   return $gskit[-1] if @gskit;
} ## end sub __gskit
1;
