#!/usr/local/bin/perl-current
use strict;
use warnings;
use File::Find;
use File::Spec;
use File::Copy;
use Data::Dumper;
use Sys::Hostname;
use EI::DirStore;
use Digest::MD5;
use Cwd 'abs_path';

if (!-t) {
   my $s = int(rand(60 * 15));
   logit("Sleeping $s seconds\n");
   sleep $s;
}
my ($script_path) = abs_path($0) =~ /(.*)\//;
my $debug = 0;
if (-e './debug_cert_scan') {
   $debug = 1;
}
my $host = hostname;
my %keystores;
my @seed_dirs;
my $olddir = "";
my @xml_files;
my @java_dirs;
my $gskcmd;
my $count     = 0;
my $gpfs_scan = 0;
my (@exclude_dirs, @exclude_files);
my %password_stores;
my ($certdir, $certfile);
my (@java,    $java_keytool);
my $config;

#=============================================================================
# Find one gpfs server for each environment
#=============================================================================
my %results;
my %gpfs;
my %gpfs_servers;
dsSearch(
         %results, "SYSTEM",
         expList => ['role==gpfs.server.sync'],
         attrs   => ["realm"]
);
foreach my $server (sort keys %results) {
   my $realm = $results{$server}{'realm'}[0];
   $gpfs{$realm} = $server;
}
foreach my $realm (sort keys %gpfs) {
   my $server = $gpfs{$realm};
   $gpfs_servers{$server} = defined;
}
if (defined $gpfs_servers{$host}) {
   $gpfs_scan = 1;
}

# ================================================================================================================
# Main
# ================================================================================================================
# Parse the command line
while (@ARGV) {
   my $parm = shift;
   if ($parm =~ /debug/i) {
      $debug = 1;
   }
   else {
      if (-e $parm) {
         $config = $parm;
      }
      else {
         logit("$parm config file does not exist\n");
      }
   }
}
if (!$config) {
   logit("No valid config specified on command line, using default file");
   $config = "$script_path/conf/cert_scan.conf";
   if (!-e $config) {
      logit("default config $config does not exist\n");
      exit 2;
   }
}
debug_info("Using config $config\n");

#--------------------------------
# Read the config file
#--------------------------------
eval { open 'config', "<", $config or die "Cannot open $config $!\n"; };
if ($@) {
   print $@;
   exit;
}
else {
   readconfig($config);
}
chdir $certdir;
#--------------------------------
# build a list of keystore files, list saved in %keystores hash
#--------------------------------
find( { wanted => \&find_keystore, follow => 1, follow_skip => 2 },
	@seed_dirs );

$gskcmd='/fs/scratch/cert_info/gskcmd.sh';

#-------------------------------------------------
# find java
#-------------------------------------------------
$java_keytool = '';
print STDERR Dumper(\@java_dirs) if $debug;
foreach my $cmd (@java_dirs) {
   logit("checking for working keytool $cmd");
	$java_keytool = '';
   open("KT", "$cmd 2>&1 |");
   if ( fileno(KT) ) {
      while (<KT>) {
         if (/-delete/i) {
            $java_keytool = $cmd;
            last;
         }
      }
   }
   unlink glob "javacore.*";
   unlink glob "core.*";
   unlink glob "Snap0001.*";
   unlink glob "Snap0002.*";
	last if $java_keytool;
}
if (!$java_keytool) {
   alert("No suitable java found");
   exit;
}
else {
   logit("Using $java_keytool");
}

#--------------------------------
# Store md5 for the keyfile into %keystores
#--------------------------------
get_md5s();

#-------------------------------------------------
# get passwords for the keystores into %keystores
#-------------------------------------------------
get_passwords();
debug_info(Dumper(\%keystores));

#--------------------------------
# list the cert information
#--------------------------------
logit("Writing cert info to $certfile");
eval { open CERT, ">", $certfile or die "Error $! opening $certfile for output\n"; };
if ($@) {
   print $@;
}
else {
   list_certs();
   close CERT;
}
exit;

#-----------------------------------------------------------------------------------
# Find GSKIT
#------------------------------------------------------------------------------------
sub _find_gskit {
   my @gsdirs;
   push @gsdirs, '/usr/opt/ibm'   if -e '/usr/opt/ibm';
   push @gsdirs, '/usr/local/ibm' if -e '/usr/local/ibm';

   # are we on linux or aix
   my $os = `uname -s`;
   my $re = qr/gsk\d+capicmd/i;
   if ($os =~ /AIX/i) {
      my $bit64 = `getconf -a | grep KERN`;
      if ($bit64 =~ /64/) {
         $re = qr/gsk\d+capicmd_64/i;
      }
   }
   else {
      my $bit64 = `uname -i`;
      if ($bit64 =~ /64/) {
         $re = qr/gsk\d+capicmd_64/i;
      }
   }
   eval {
      find(sub { die "$File::Find::name" if $_ =~ /$re/ }, @gsdirs);
   };
   my ($gskit) = $@ =~ /(.+) at /;
   debug_info($gskit);
   return $gskit;
}

# ================================================================================================================
# Subroutines
# ================================================================================================================
sub readconfig {
   my ($config) = @_;

   # read directory list / excludes from external file
   my $keyword;
   my %values;
   while (my $line = <config>) {
      chomp $line;
      $line =~ s/^\s+?|\s+?$//x;
      next if ($line =~ /^\#/x || !$line);
      if (my ($key, $value) = $line =~ /(\w+?)\s*=\s*(.*)/x) {
         $keyword = $key;
         $values{$keyword} = $value;
      }
      else {
         $values{$keyword} .= $line;
      }
   }
   close 'config';
   $certdir = [ split(/\s*,\s*/x, $values{'output_to'}) ]->[0];
   if (!$certdir) {
      $certdir = "/fs/scratch/cert_info";
   }
   if (!-d $certdir) {
      mkdir $certdir, 0755;
   }
   $certfile = "$certdir/${host}_certs.txt";
   logit("Certificate info will be written to $certfile");
   if (-f $certfile) {
      unlink $certfile;
   }
   @exclude_dirs = map { qr/$_/x } split(/\s*,\s*/x, $values{'exclude_dirs'});
   debug_info(@exclude_dirs);
   @exclude_files =
     map { qr/$_/x } split(/\s*,\s*/x, $values{'exclude_files'});
   debug_info(@exclude_files);
   @seed_dirs = expand_dirs($values{'search_dirs'});
   if (scalar @seed_dirs == 0) {
      die "No directories to search specified in config\n";
   }
   debug_info(Dumper(\@seed_dirs));
   foreach (split(/\s*,\s*/x, $values{'password_stores'})) {
      if (
         my ($dir, $store_regex, $pw_regex) =
         $_ =~ /
			(.+?)\(			# everything upto ( 
			(.*)\:			# everything upto :
		 	(.*)\)			# everything to )
			/x
        ) {
         $password_stores{$dir}{'keystore'} = qr/$store_regex/x;
         $password_stores{$dir}{'password'} = qr/$pw_regex/x;
      }
      else { print STDERR "Invalid keystore definition $_\n"; }
   }
}

# =================================================================
# Perform filename expansion and check resulting directories exist
# =================================================================
sub expand_dirs {
   my ($dirlist) = @_;
   my @dirs;
   foreach (split(/\s*,\s*/x, $dirlist)) {
      foreach (glob($_)) {
         push @dirs, $_ if -d $_;
      }
   }
   return @dirs;
}

# ==========================================================
# Called by Find to check if directory/file is one we want
# ==========================================================
sub find_keystore {
   my $alias     = $File::Find::name;
   my $directory = $File::Find::dir;
   my $file      = $File::Find::fullname;
   $directory=~s/\$/\\\$/g;
   $directory=~s/\"/\\\"/g;
   $directory=~s/\`/\\\`/g;
   if ($olddir ne $directory) {
      if (map($directory =~ /$_/, @exclude_dirs)) {
         $File::Find::prune = 1;    # Skip this directory
         return;
      }

      # determine if dir is on a remote mounted filesystem
      if ($directory !~ /^\/projects/) {
         my @lines = `df \"$directory\" 2>/dev/null`;
         foreach my $line (@lines) {
            next if $line=~ /%Used/i;
            my ($dev) = split(/ /,$line);
            if ($dev =~ /:/) {
               logit("$directory is a remote filesystem on $dev - skipping");
               $File::Find::prune = 1;    # Skip this directory
               return;
            }
         }
      }
      if ($directory =~ /^\/gpfs/ && !$gpfs_scan) {
         logit("gpfs directory not searched on this server");
         $File::Find::prune = 1;          # Skip this directory
         return;
      }
      debug_info("Searching $directory");
      $olddir = $directory;
   }
   if ($file) {
      if ($file =~ /(jre|jdk).*\/bin\/keytool$/i) {
         push @java_dirs, $alias;
      }
      if (map ($file =~ /$_/, @exclude_files)) {
         return;                          # skip this file
      }
      if ($file =~ /(\.jks$|\.kdb$)/) {
         $file =~ s/\/\//\//;
         logit("Found keystore $file");
         $keystores{$file} = {} if !defined $keystores{$file};
         push @{ $keystores{$file}{'alias'} }, $alias if $alias ne $file;
      }
   }
}

#=====================================================================
# Get MD5 sum value for the file
#=====================================================================
sub md5sum {
   my $file   = shift;
   my $digest = "";
   eval {
      open(FILE, $file) or die "Can't find file $file\n";
      my $ctx = Digest::MD5->new;
      $ctx->addfile(*FILE);
      $digest = $ctx->hexdigest;
      close(FILE);
   };
   if ($@) {
      print $@;
      return "";
   }
   return $digest;
}

#=====================================================================
# Get the MD5 sums
#=====================================================================
sub get_md5s {
   for my $keystore (keys %keystores) {
      debug_info("\tGenerating MD5 sum for $keystore");
      $keystores{$keystore}{'md5'} = md5sum($keystore);
   }
}

#=====================================================================
# Call the appriopriate password lookup routine for the type of file
#=====================================================================
sub get_passwords {
   for my $keystore (keys %keystores) {
      debug_info("\tgetting password for $keystore");
      if ($keystore =~ /\.kdb/) {
         get_kdb_password($keystore);
      }

      #   if ( $keystore =~ /\.jks/ ) {
      #      get_jks_password($keystore);
      #   }
   }
}

#===================================================================================
# Find and store kdb password
#===================================================================================
sub get_kdb_password {
   my ($keystore) = @_;
   my $sth = $keystore;
   $sth =~ s/\.kdb$/\.sth/;
   if (-r $sth) {
      debug_info("\tUsing sth file $sth");
      my $pw = decode_kdb_pw($sth);
      if ($pw =~ /Cant open/) {
         logit("#### Cannot read $sth");
      }
      elsif (!$pw) {
         logit("#### Cannot decode $sth file, no password returned");
      }
      else {
         debug_info("decode_kdb_pw returned $pw as password from $sth for $keystore");
         logit("Password for $keystore obtained from $sth");
         $keystores{$keystore}{'password'} = $pw;
      }
   }
   else {
      lookup_password_store($keystore);
   }
}

#===================================================================================
# Find and store password for jks file
#===================================================================================
sub get_jks_password {
   my ($keystore) = @_;
   @xml_files = ();
   lookup_was_password($keystore);    # Assuming WAS is what uses the jks file
   if (!defined $keystores{$keystore}{'password'}) {
      lookup_password_store($keystore);
   }
}

#======================================================================================================
# Look in alternate password files to find password
#======================================================================================================
sub lookup_password_store {
   my ($keystore) = @_;
   debug_info("looking for $keystore");
   for my $keyfile (keys %password_stores) {
      debug_info("Trying $keyfile");
      if (my $line = find_keystore_pw($keyfile, $keystore)) {
         if (my ($pw) = $line =~ /$password_stores{$keyfile}{'password'}/) {
            logit("Password for $keystore obtained from $keyfile");
            $keystores{$keystore}{'password'} = $pw;
            last;
         }
         else {
            debug_info("$keystore password not found in $keyfile");
         }
      }
   }
}

#======================================================================================================
# Read file and try to match
#======================================================================================================
sub find_keystore_pw {
   my ($keyfile, $keystore) = @_;
   (my $a, my $b, $keystore) = File::Spec->splitpath($keystore);
   debug_info("reading $keyfile for $keystore");
   if (my $rc = open KS, "<", $keyfile) {
      while (my $line = <KS>) {
         debug_info($line);
         if ($line =~ /$keystore/) {
            close KS;
            debug_info("Returning $line");
            return $line;
         }
      }
      close KS;
   }
   else {
      debug_info("failed to read $!");
   }
   debug_info("Returning null");
   return "";
}

#================================
# Search for security.xml files
#================================
sub find_security_xml {
   my ($found_file) = $_;
   my $directory = $File::Find::dir;
   $found_file =~ /^security\.xml$/ or return;

   # check if directory should be excluded
   if (map($directory =~ /$_/, @exclude_dirs)) {
      $File::Find::prune = 1;    # Skip this directory
      return;
   }
   debug_info("\tFound $File::Find::name");
   push @xml_files, $File::Find::name;
}

#=======================================================================
# Look in was security.xml files to try and find password for keystore
#=======================================================================
sub lookup_was_password {
   my ($keystore) = @_;
   find(\&find_security_xml, @seed_dirs);
   my ($a, $b, $keyfile) = File::Spec->splitpath($keystore);
   for my $xml_file (@xml_files) {
      if (my $keystore_info = search_xml($xml_file, '^\s+?\<keyStores.*' . $keyfile)) {
         $keystore_info = resolve_was_vars($keystore_info, $xml_file);
         debug_info("keystore_info -> $keystore_info");
         if (my ($path, $pw) = get_xml_password($keystore_info, $keystore)) {

            # check file or alias match keystore name
            if (match_name($keystore, $path)) {
               $pw = was_decode($pw);
               logit("Password for $keystore obtained from $xml_file");
               $keystores{$keystore}{'password'} = $pw;
               last;    # stop once we got the password
            }
         }
      }
      else {
         debug_info("$xml_file has no record of $keystore");
      }
   }
}

#======================================================================================================
#
#======================================================================================================
sub match_name {
   my ($keystore, $path) = @_;
   debug_info("match_name $keystore to $path");
   foreach my $file (($keystore, @{ $keystores{$keystore}{'alias'} })) {
      debug_info("matching >$file< to >$path<");
      if ($file eq $path) {
         debug_info("matched");
         return 1;
      }
   }
   debug_info("no match");
   return 0;
}

#=======================
# Unmask WAS password
#=======================
sub was_decode {
   my ($pw) = @_;
   debug_info("decoding $pw");
   $pw = `/lfs/system/tools/was/bin/PasswordDecoder.sh $pw`;
   debug_info("result $pw");
   if (($pw) = $pw =~ /.*\=\= \"(.+?)\"$/) {
      return $pw;
   }
   else {
      return "";
   }
}

#======================================================================================================
#
#======================================================================================================
sub search_xml {
   my ($xml_file, $string_to_find) = @_;
   debug_info("looking for $string_to_find in $xml_file");
   if (my $rc = open XML, "<", $xml_file) {
      while (my $line = <XML>) {
         if ($line =~ /$string_to_find/) {
            close XML;

            # resolve any was variables before returning the line
            debug_info("Returning $line");
            chomp($line);
            return $line;
         }
      }
      close XML;
   }
   debug_info("Returning null");
   return "";
}

#======================================================================================================
#
#======================================================================================================
sub get_xml_password {
   my ($keystore_info, $keystore, $xml_file) = @_;
   debug_info("\t$keystore_info");
   my ($path, $pw);
   ($pw)   = $keystore_info =~ /password=\"(.+?)\"/;
   ($path) = $keystore_info =~ /location=\"(.+?)\"/;
   if ($path & $pw) {
      return ($path, $pw);
   }
   return "";
}

#======================================================================================================
#
#======================================================================================================
sub resolve_was_vars {
   my ($line, $xml_file) = @_;
   chomp($line);
   debug_info("resolving vars in $line of $xml_file");
   my ($node) = $xml_file =~ /profiles\/(.+?)\/config/;
   my $vars_file = $xml_file;
   $vars_file =~ s/security\.xml$/nodes\/$node\/variables.xml/;
   debug_info("var file is $vars_file");
   while (my ($var_name) = $line =~ /\${(.+?)}/) {
      my $var_info = search_xml($vars_file, "symbolicName=\"$var_name\"");
      debug_info("variable definition: $var_info");
      if (my ($value) = $var_info =~ /value=\"(.+?)\"/) {
         debug_info("$var_name value is $value");
         $line =~ s/\${.+?}/$value/;
      }
      else {
         debug_info("Failed to resolve $var_name");
         return $line;
      }
   }
   return $line;
}

#==================================================
# Decode kdb stash file and return password value
#==================================================
sub decode_kdb_pw {
   my ($sth) = @_;
   my $pw = '';
   open(F, $sth) || return "Can't open $sth: $!";
   my $stash;
   read F, $stash, 1024;
   close F;
   my @unstash = map { $_ ^ 0xf5 } unpack("C*", $stash);
   foreach my $c (@unstash) {
      next if $c > 240;
      last if $c eq 0;
      $pw = $pw . sprintf "%c", $c;
   }
   return $pw;
}

#==========================================================
# Call appropriate sub to list the certs for the filetype
#==========================================================
sub list_certs {
   for my $keystore (keys %keystores) {
      $keystore =~ s/\/\//\//;
      logit("Listing certs for $keystore");
      if ($keystore =~ /\.kdb/) {
         list_kdb_certs($keystore);
      }
      elsif ($keystore =~ /\.jks/) {
         list_jks_certs($keystore);
      }
      else {
         logit("$keystore is an un-supported type");
      }
   }
}

#==========================================================
# List certs in a KDB file
#==========================================================
sub list_kdb_certs {
   my ($keystore) = @_;
   if (exists $keystores{$keystore}{'password'} && $gskcmd) {
      my $pw = $keystores{$keystore}{'password'};
      do_kdb_certs($keystore, $pw);
   }
   else {
      logit("#### No password for $keystore");
   }
}

sub do_kdb_certs {
   my ($keystore, $pw) = @_;

   # list all certs
   # list ca certs, mark ca
   my $tmp_keystore = '/tmp/$$certscan.kdb';
   debug_info("$gskcmd -cert -list -db $keystore -pw \"$pw\"");
   copy($keystore, '/tmp/$$certscan.kdb');
   my $days = `$gskcmd -keydb -expiry -db \'$tmp_keystore\' -pw \"$pw\" 2>&1`;
   logit("$gskcmd -keydb -expiry -db \'$tmp_keystore\' -pw \"$pw\"");
   if ( $days =~/expired/gism ) {
      alert("$keystore stashed password is expired");
		return;      # dont bother trying to list certs we cant open keystore if pw is expired
   }
#   Password Expiry Time : November 1, 2033 6:14:07 PM GMT+00:00
   elsif ( $days =~ /\s(\w+)\s+(\d+),\s+(\d+)\s\d+:/gism ) {
      my $day=$2;
      my $month=$1;
      my $year=$3;
      if ( $year < 2025 ) {
         alert("$keystore stashed pw expires on $day $month $year");
      }
   }
#   Tuesday, 30 September 2031 19:06:16 PM UTC
   elsif ( $days =~ /\w+,\s+(\d+)\s+(\w+)\s+(\d+)\s+\d+:/gism ) {
      my $day=$1;
      my $month=$2;
      my $year=$3;
      if ( $year < 2025 ) {
         alert("$keystore stashed pw expires on $day $month $year");
      }
   }
   elsif ( $days =~/(?:Validity|Password\s+Expiry\s+Time\s+):\s+(\d)+/gism ) {
      $days=$1;
      if ( $days != "0" ) {
         alert("$keystore stashed pw expires in $days days");
      }
   }
   else {
      alert("$keystore returned $days");
   }
   my @certs = `$gskcmd -cert -list -db \'$tmp_keystore\' -pw \"$pw\" 2>&1`;
   if ($? > 0 || grep(/JDK/, @certs)) {
      if (grep(/no key was found/i, @certs)) {
         logit("$keystore has no keys");
      }
      elsif (grep(/Error: 70/i, @certs)) {
         alert("$keystore password expired");
      }
      elsif (grep(/expired/i, @certs)) {
         alert("$keystore password expired");
      }
      elsif (grep (/An invalid password/i, @certs)) {
         alert("$keystore sth file contains invalid password");
      }
      else {

         #?????? not sure what this alert is about
         alert("$keystore returned " . join("\n", @certs));
         @certs = ("label: Java failure", "entry type: ");
         output($keystore, format_certs($keystore, \@certs, "personal"));
      }
   }
   else {
      debug_info("return code from $gskcmd $?");

      # lose the header rows
      shift @certs;
      if ($certs[0] =~ /(- has private key|! trusted)/) {
         shift @certs;
      }
      debug_info(Dumper(\@certs));

      # list the CA certs
      debug_info("$gskcmd -cert -list ca -db \"$keystore\" -pw \"$pw\"");
      my @cacerts = `$gskcmd -cert -list ca -db \'$tmp_keystore\' -pw \"$pw\"`;

      # now mark each as personal or ca
      foreach my $cert (@cacerts) {
         my $type;
         if   ($cert =~ /^(\*|\-)/) { $type = "personal"; }    # line starting *- or - are personal
         else                       { $type = 'ca'; }
         for (my $i = 0 ; $i < @certs ; $i++) {
            $cert =~ s/^[\*\-\!\s]*//;
            $certs[$i] =~ s/^[\*\-\!\s]*//;
            debug_info("comparing \"$certs[$i]\" against \"$cert\"");
            if ($certs[$i] eq $cert) {
               debug_info("matched");
               $certs[$i] = "type=$type " . $cert;
               last;
            }
         }
      }
      debug_info(Dumper(\@certs));

      # mark any without a type= as personal
      for (my $i = 0 ; $i < @certs ; $i++) {
         if ($certs[$i] !~ /^type=/) {
            $certs[$i] =~ s/^[\*\-\!\s]*//;
            $certs[$i] = "type=personal " . $certs[$i];
         }
      }
      debug_info(Dumper(\@certs));
      ######## now go find the details for the cerrts
      foreach my $cert (@certs) {
         debug_info('listing $cert');
         my ($type, $cert) = $cert =~ /type=(\w+?) (.*)/;
         chomp($cert);
         $cert =~ s/^\s+|\s+$//g;
         $cert =~ s/^\"|\"$//g;
         my @certinfo;
         my $timeout = 30;
         my $pid;
         debug_info("$gskcmd -cert -details -db $keystore -pw \"$pw\" -label \"$cert\"");

         # GSK7CMD has a nasty habit of hanging for no apparent reason, so next bit
         # launches it with a max execution time and kills it if it overruns
         eval {
            local $SIG{ALRM} = sub {
               logit("$pid timed out after $timeout seconds - killing $pid");
               alert("Timeout listing $keystore $cert");
               kill 9, $pid;
               close P;
               sleep 1;
            };
            alarm $timeout;
            $pid = open P, "-|", "$gskcmd -cert -details -db \'$tmp_keystore\' -pw \"$pw\" -label \"$cert\"";

            #logit("Started $pid");
            @certinfo = <P>;
            alarm 0;
         };
         output($keystore, format_certs($keystore, \@certinfo, $type));
      }
   }
   unlink($tmp_keystore);
}

#============================
# List certs in a JKS file
#============================
sub list_jks_certs {
   my ($keystore) = @_;
   debug_info("listing $keystore");
   if (defined $keystores{$keystore}{'password'}) {
      debug_info("$java_keytool -list -v -keystore $keystore -storepass \"$keystores{$keystore}{'password'}\"");
      my @certinfo = `$java_keytool -list -v -keystore \"$keystore\" -storepass \"$keystores{$keystore}{'password'}\" 2>&1`;
      output($keystore, format_certs($keystore, \@certinfo));
   }
   else {
      my @certinfo = `echo "" | $java_keytool -list -v -keystore \"$keystore\" 2>&1`;
      output($keystore, format_certs($keystore, \@certinfo));
   }
}

#===================================
# Format certs
#===================================
sub format_certs {
   my ($keystore, $certinfo_ref, $certtype) = @_;
   chomp @{$certinfo_ref};
   my %standard_cert;
   my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime;
   my @certs;
   for (my $i = 0 ; $i < @{$certinfo_ref} ; $i++) {
      my $line = $certinfo_ref->[$i];
      if ($line =~ /^(alias name|label)\s*?: (.*)/i) {
         my $label = $2;
         debug_info(Dumper(\%standard_cert));
         push @certs, {%standard_cert};
         my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();
         my $data_date = sprintf("%4d-%02d-%02d-%02s.%02d.00.000000", $year + 1900, $mon + 1, $mday, $hour, $min);
         %standard_cert = (
                           'label'       => $label,
                           'owner'       => undef,
                           'file'        => $keystore,
                           'issuer'      => undef,
                           'type'        => $certtype,
                           'fingerprint' => undef,
                           'keysize'     => undef,
                           'serial'      => undef,
                           'start_date'  => undef,
                           'end_date'    => undef,
                           'data_date'   => $data_date,
                           'md5'         => $keystores{$keystore}{'md5'},
                           'host'        => $host
         );
         debug_info("initialized..." . Dumper(\%standard_cert));
         next;
      }
      elsif ($line =~ /^certificate\[(\d)/i) {    # handle key chains ... only want the personal key
         if ($1 > 1) {                            # ignore everything above key 1
                                                  # skip to next label
            until ($line =~ /^alias name:/i || $i == @{$certinfo_ref}) {
               $i++;
               $line = $certinfo_ref->[$i];
               if (!defined $line) { last; }
               debug_info("Skipping $line");
            }
            $i--;
         }
         next;
      }
      elsif ($line =~ /^entry type: (.*)/i) {
         $standard_cert{'type'} = $1;
         next;
      }
      elsif ($line =~ /^owner: (.*)/i) {
         $standard_cert{'owner'} = $1;
         next;
      }
      elsif ($line =~ /^(trust status|trusted)\s*?: enabled/i) {
         $standard_cert{'type'} = $certtype;
         next;
      }
      elsif ($line =~ /^issued by: (.*)/i) {
         $standard_cert{'issuer'} = $1;
         $i++;
         while (   $certinfo_ref->[$i] !~ /^[\w\s]+?:/i
                && $i <= @{$certinfo_ref}) {
            $line = $certinfo_ref->[$i];
            $line =~ s/^\s+|\s+$//;
            $standard_cert{'issuer'} .= ", " . $line;
            $i++;
         }
         $i--;
         next;
      }
      elsif ($line =~ /^subject\s*?: (.*)/i) {
         $standard_cert{'owner'} = $1;
         $i++;
         while (   $certinfo_ref->[$i] !~ /^[\w\s]+?:/i
                && $i <= @{$certinfo_ref}) {
            $line = $certinfo_ref->[$i];
            $line =~ s/^\s+|\s+$//;
            $standard_cert{'owner'} .= ", " . $line;
            $i++;
         }
         $i--;
         next;
      }
      elsif ($line =~ /^issuer\s*?: (.*)/i) {
         $standard_cert{'issuer'} = $1;
         next;
      }
      elsif ($line =~ /^serial number: (.*)/i) {
         $standard_cert{'serial'} = $1;
         next;
      }
      elsif ($line =~ /^serial\s?: (.*)/i) {
         $standard_cert{'serial'} = $1;
         next;
      }
      elsif ($line =~ /^key size\s*?: (.*)/i) {
         $standard_cert{'keysize'} = $1;
         next;
      }
      elsif ($line =~ /: sha1 :/i) {
         $line = $certinfo_ref->[ $i + 1 ];
         $line =~ s/^\s+//;
         $standard_cert{'fingerprint'} = $line;
         $line = $certinfo_ref->[ $i + 2 ];
         $line =~ s/^\s+//;
         $standard_cert{'fingerprint'} .= " " . $line;
         $standard_cert{'fingerprint'} =~ s/\s/:/g;
         $i = $i + 2;
         next;
      }
      elsif ($line =~ /(md5: |^finger\s?print\s*?:) (.*)/i) {
         $standard_cert{'fingerprint'} = $2;
         next;
      }
      elsif ($line =~ /^valid:? from:.*until/i) {
         my ($start, $end) = format_valid_from($line);
         $standard_cert{'start_date'} = $start;
         $standard_cert{'end_date'}   = $end;
         next;
      }
      elsif ($line =~ /^valid from\s*?:/i) {
         my ($start) = format_valid_from($line);
         $standard_cert{'start_date'} = $start;
         next;
      }
      elsif ($line =~ /^to\s*?:/i) {
         my ($end) = format_valid_from($line);
         $standard_cert{'end_date'} = $end;
         next;
      }
      elsif ($line =~ /^valid:? from:/i) {
         my ($start, $end) = format_valid_from($line);
         $standard_cert{'start_date'} = $start;
         $standard_cert{'end_date'}   = $end;
         next;
      }
      elsif ($line =~ /^not before :/i) {
         my ($start) = format_valid_from($line);
         $standard_cert{'start_date'} = $start;
         next;
      }
      elsif ($line =~ /^not after :/i) {
         my ($end) = format_valid_from($line);
         $standard_cert{'end_date'} = $end;
         next;
      }
      debug_info("unhandled line $i:$line");
   }
   push @certs, {%standard_cert};
   shift @certs;
   debug_info("returning ... " . Dumper(\@certs));
   return @certs;
}

#================================================
# convert ascii string to hex
#================================================
sub ascii_to_hex ($) {
   (my $str = shift) =~ s/(.|\n)/sprintf("%02lx", ord $1)/eg;
   return $str;
}

#================================================
# Format and print debugging info
#================================================
sub debug_info {
   my ($msg) = @_;
   my $me = (caller(1))[3];
   if ($me) {
      ($me) = $me =~ /::(.*)/;
   }
   else {
      $me = "Main";
   }
   printf STDERR "%-20s: %s\n", $me, $msg if $debug;
}

#================================================
# Write cert info to file
#================================================
sub output {
   my ($keystore, @certs) = @_;
   debug_info("Writing" . Dumper(\@certs) . " to file");
   if (scalar @certs eq 0) {
      alert("error formatting $keystore no results to output");
   }
   foreach my $cert (@certs) {
      debug_info(Dumper($cert));
      logit("writing $cert->{'label'}");
      my $lastkey = ((sort keys %{$cert})[-1]);
      foreach my $keyword (sort keys %{$cert}) {
         print CERT $cert->{$keyword} if defined $cert->{$keyword};
         if   ($lastkey eq $keyword) { print CERT "\n"; }
         else                        { print CERT "|"; }
      }
   }
}

#=========================================================
# Make Valid from date format the same
#=========================================================
sub format_valid_from {
   my ($line) = @_;
   my %mon2num = qw( jan 1 feb 2 mar 3 apr 4 may 5 jun 6 jul 7 aug 8 sep 9 oct 10 nov 11 dec 12);
   my ($fmonth, $fday, $fyear, $tmonth, $tday, $tyear);

   # Valid from: Wed Sep 16 16:49:03 UTC 2009 until: Mon Sep 16 16:49:03 UTC 2013
   if ($line =~ /^Valid From: [MTWFS][a-z]{2}\s/i) {
      debug_info("matched date format 1");
      ($fmonth, $fday, $fyear, $tmonth, $tday, $tyear) = $line =~ /
         :\s            # find first :space follwed by
         \w{3}          # 3 word characters followed by
         \s             # space
         (\w{3})        # capture next 3 word chars
         \s             # space
         (\d{1,2})      # capture upto 2 numbers
         .+?            # skip anything upto 
         (\d{4})        # capture a 4 digit number 
         .+?:\s         # skip everything until :space
         \w{3}          # skip next 3 word chars
         \s             # skip space
         (\w{3})        # capture next 3 word chars
         \s             # skip space
         (\d{1,2})      # capture upto 2 numbers
         .+?            # skip eveything upto 
         (\d{4})        # capture 4 digit number
         /x;
      $fmonth = $mon2num{ lc substr($fmonth, 0, 3) };
      $tmonth = $mon2num{ lc substr($tmonth, 0, 3) };
   }

   # Not Before : February 13, 2010 10:09:10 PM GMT+00:00
   # Not After : May 23, 2013 12:00:00 AM GMT+00:00
   elsif ($line =~ /^Not (before|after)\s?:/i) {
      debug_info("matched date format 2");
      ($fmonth, $fday, $fyear) = $line =~ /
         :\s            # find first :space follwed by
         (\w+?)           # word characters followed by
         \s             # space
         (\d{1,2})      # capture upto 2 numbers
         ,\s              # comma follwed by space
         (\d{4})/x;    # capture a 4 digit number
      debug_info("month=$fmonth day=$fday year=$fyear");
      $fmonth = $mon2num{ lc substr($fmonth, 0, 3) };
      return (sprintf("%4d%02d%02d", $fyear, $fmonth, $fday));
   }

   # Valid From: Thursday, 06 January 2011 14:23:19 PM To: Monday, 04 January 2021 14:23:19 PM
   elsif ($line =~ /^Valid:? From: \w+?, \d{1,2} /i) {
      debug_info("matched date format 3");
      ($fday, $fmonth, $fyear, $tday, $tmonth, $tyear) = $line =~ /
            ,\s         # find first ,space
            (\d{1,2})   # capture upto 2 numbers (fday)
            \s          # skip space
            (\w+?)      # capture next word (fmonth) until
            \s          # skip ,space
            (\d{4})     # capture 4 digit number (fyear)
            .*,\s       # skip everything until next ,space
            (\d{1,2})   # capture upto 2 digit number (tday)
            \s          # space
            (\w+?)      # capture next word (tmonth) until
            \s          # space
            (\d{4})     # cpature 4 digit number (tyear)
         /x;
      $fmonth = $mon2num{ lc substr($fmonth, 0, 3) };
      $tmonth = $mon2num{ lc substr($tmonth, 0, 3) };
   }

   # Valid From: Wednesday, November 9, 1994 12:00:00 AM UTC To: Thursday, January 7, 2010 11:59:59 PM UTC
   # or
   # Valid: From: Thursday, April 17, 1997 12:00:00 AM UTC To: Monday, October 24, 2011 11:59:59 PM UTC
   elsif ($line =~ /^Valid:? From: [MTWFS][a-z]+?,/i) {
      debug_info("matched date format 4");
      ($fmonth, $fday, $fyear, $tmonth, $tday, $tyear) = $line =~ /
            ,\s         # find first ,space
            (\w+?)      # capture next word (fmonth) until
            \s          # skip space
            (\d{1,2})   # capture upto 2 numbers (fday)
            ,\s         # skip ,space
            (\d{4})     # capture 4 digit number (fyear)
            .*,\s       # skip everything until next ,space
            (\w+?)      # capture next word (tmonth) until
            \s          # space
            (\d{1,2})   # capture upto 2 digit number (tday)
            ,\s         # skip ,space
            (\d{4})     # cpature 4 digit number (tyear)
         /x;
      $fmonth = $mon2num{ lc substr($fmonth, 0, 3) };
      $tmonth = $mon2num{ lc substr($tmonth, 0, 3) };
   }

   # Valid from: 9/3/09 3:45 PM until: 9/3/13 3:45 PM
   elsif ($line =~ /^Valid From: \d{1,2}\/\d{1,2}\/\d{2}/i) {
      debug_info("matched date format 5");
      ($fmonth, $fday, $fyear, $tmonth, $tday, $tyear) = $line =~ /
            (\d{1,2})   # capture 2 digit number (fmonth)
            \/          # slash
            (\d{1,2})   # capture 2 digit number (fday)
            \/          # slash
            (\d{2})     # capture 2 digit number (fyear)
            .+?         # skip until next matching string
            (\d{1,2})   # capture 2 digit number (tmonth)
            \/          # slash
            (\d{1,2})   # capture 2 digit number (tday)
            \/          # slash
            (\d{2})     # capture 2 digit number (tyear)
         /x;
      if   ($fyear > 50) { $fyear = $fyear + 1900; }
      else               { $fyear = $fyear + 2000; }
      if   ($tyear > 50) { $tyear += 1900; }
      else               { $tyear += 2000; }
   }

   # To: Sun Jun 23 12:14:45 GMT 2019]
   elsif ($line =~ /^to\: \w+ \w+ \d{1,2} /i) {
      debug_info("matched date format 6");
      ($fmonth, $fday, $fyear) = $line =~ /
            :\s\w+\s    # skip to after first word (day of week)
            (\w+)\s     # capture month
            (\d{1,2})   # capture upto 2 numbers (fday)
            .+
            (\d{4})   # capture year
         /x;
      $fmonth = $mon2num{ lc substr($fmonth, 0, 3) };
      return (sprintf("%4d%02d%02d", $fyear, $fmonth, $fday));
   }

   # Valid From   : Monday, 29 January 1996 00:00:00 AM
   # To           : Saturday, 25 May 2019 16:39:40 PM
   elsif ($line =~ /^(Valid From|to)\s*?: \w+?, \d{1,2} /i) {
      debug_info("matched date format 7");
      ($fday, $fmonth, $fyear) = $line =~ /
            ,\s         # find first ,space
            (\d{1,2})   # capture upto 2 numbers (fday)
            \s          # skip space
            (\w+?)      # capture next word (fmonth) until
            \s          # skip ,space
            (\d{4})     # capture 4 digit number (fyear)
         /x;
      $fmonth = $mon2num{ lc substr($fmonth, 0, 3) };
      return (sprintf("%4d%02d%02d", $fyear, $fmonth, $fday));
   }
   else { alert("date format $line not recognised"); }
   return (sprintf("%4d%02d%02d", $fyear, $fmonth, $fday), sprintf("%4d%02d%02d", $tyear, $tmonth, $tday));
}

#===================================
# Print log information
#===================================
sub logit {
   my ($msg) = @_;
   my ($sec, $min, $hour, $day, $month, $year) = localtime();
   printf "[%02d/%02d %02d:%02d:%02d] %s\n", $month + 1, $day, $hour, $min, $sec, $msg;
}

#===============================================
# Alert on failures
#===============================================
sub alert {
   my ($msg, $tiv) = @_;
   if ($tiv) {
      system("/opt/IBM/ITMscripts/ITM_to_Omni -k alert$count -g12 -p300 \"Cert_scan - $msg\"");
      $count++;
   }
   if (!fileno('FAILS')) {
      my $fail_file = $certfile;
      $fail_file =~ s/_certs.txt/_fails.txt/;
      open 'FAILS', '>>', "$fail_file";
   }
   logit("$host - $msg");
   print FAILS "$host - $msg\n";
}
