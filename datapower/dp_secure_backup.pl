#!/usr/local/bin/perl
#=============================================================
# $Revision: 1.6 $
#=============================================================
# has to run on w20006
# 1. perform SOMA secure backup
# 2. get filelist for backup dir
# 3. copy files to local backup dir
# 4. verify files copied successfully
use strict;
use FindBin;
use MIME::Base64;
use lib ("$FindBin::Bin/lib", "/$FindBin::Bin/../lib", "$FindBin::Bin");
use Data::Dumper;
use ParseXML::ParseXML;
use Term::ReadKey;
use Sys::Hostname;
my $host = hostname;
my $time = sprintf "%4d-%02d-%02d_%02d%02d", (localtime)[5] + 1900, (localtime)[4] + 1, (localtime)[3], (localtime)[ 2, 1 ];
my $cert = 'ECI_SecureBackup_2014';
my $target;
my %servers;
my $count = 0;
my $pwfile;
my @prd = `lssys -q -e role==datapower custtag==esc nodestatus==live hostenv==prd`;
my @ivt = `lssys -q -e role==datapower custtag==esc nodestatus==live hostenv==pre`;

my ($user, $password);

if ($< != 0) {
   print "This script must be run as root or use SUDO\n";
   exit(0);
}
if (-r '/etc/.dp_secure_backup.cfg') {
   $pwfile = '/etc/.dp_secure_backup.cfg';
}
elsif (-r $ENV{"HOME"} . '/.dp_secure_backup.cfg') {
   $pwfile = $ENV{"HOME"} . '/.dp_secure_backup.cfg';
}

#=============================================================
# Parse the cmd line
#=============================================================
foreach my $arg (@ARGV) {
   my $arg_lc = $arg;
   if ($arg =~ /p\ddpa0\d/i && ( grep(/$arg/,@prd ) || grep(/$arg/,@ivt ) ) ) {
      $servers{$arg} = 1;
   }
	elsif ( $arg =~/^prd$/i ) {
		foreach my $dp ( @prd ) {
			chomp $dp;
			$servers{$dp}=1;
		}
	}
	elsif ( $arg =~/^ivt$/i ) {
		foreach my $dp ( @ivt ) {
			chomp $dp;
			$servers{$dp}=1;
		}
	}
   elsif ($arg =~ /^mypw$/i) {
      save_pw($ENV{"HOME"} . '/.dp_secure_backup.cfg');
      exit;
   }
   elsif ($arg =~ /^pw$/i) {
      save_pw('/etc/.dp_secure_backup.cfg');
      exit;
   }
	else {
		print "Don't know what to do with $arg\n";
	}
}
if (!keys %servers) {
   logmsg("Missing Datapower server name(s)");
   exit 4;
}
print Dumper(\%servers);

#=============================================================
# Read external password file
#=============================================================
if ($pwfile) {
   if (!open P, '<', "$pwfile") {
      alert($host, "Datapower backups failed missing id/pw");
      logmsg("Can't open $pwfile: $!");
      exit;
   }
   my $pwdata = <P>;
   close P;
   $pwdata = decode_base64($pwdata);
   ($user, $password) = split(/;/, $pwdata);
}
else {
   $user = _get_user();
   $password = _get_password($user) if $user;
}
$user     =~ s/^\s+|\s+$//;
$password =~ s/^\s+|\s+$//;
if (!$user || !$password) {
   alert($host, "Datapower backup failed, missing id/pw");
   logmsg("Datapower backup failed, missing id/pw");
   exit;
}
foreach my $server (sort keys %servers) {

   #=============================================================
   # Check backup directory exists
   #=============================================================
   $target = '/fs/backups/datapower/' . $server . "/" . $time;
   my $path;
   foreach my $dir (split(/\//, $target)) {
      next if !$dir;
      $path .= "/$dir";
      if (!-e $path) {
         logmsg("Make backup directory $path");
         mkdir($path, 0750);
         `/usr/bin/chgrp eiadm $path`;
      }
   }

   #=============================================================
   # Start backup process
   #=============================================================
   if (secure_backup($server)) {

      #=============================================================
      # retrieve backup files
      #=============================================================
      my @files = list_files($server);
      foreach my $file (@files) {
         get_file($server, $file);
      }

      #=============================================================
      # Check they copied ok
      #=============================================================
      verify_files($server);
   }
}
exit;

#=============================================================
# Save the id/pw to be used to connect to the datapower
#=============================================================
sub save_pw {
   my $pwfile   = shift;
   my $user     = _get_user();
   my $password = _get_password($user) if $user;
   if ($user && $password) {
      my $pwdata = encode_base64("$user;$password");
      open P, '>', "$pwfile" or die "Can't open $pwfile: $!";
      print P $pwdata;
      close P;
   }
}

#----------------------------------------------------------------------
# Lookup intranet id in dirstore
#----------------------------------------------------------------------
sub _get_user {
   print "Datapower Userid: ";
   $user = ReadLine 0;
   chomp $user;
   return $user;
}

#----------------------------------------------------------------------
# Lookup or prompt for password
#----------------------------------------------------------------------
sub _get_password {
   my $user = shift;
   print "Enter password for " . $user . ": ";
   ReadMode 'noecho';
   $password = ReadLine 0;
   chomp $password;
   ReadMode 'normal';
   print "\n";
   return $password;
}

#=============================================================
# Compare file size in manifest to actual size on disk
#=============================================================
sub verify_files {
   my $server = shift;
   logmsg("Verify files");
   my $xml;
   if (-e "$target/backupmanifest.xml") {
      {
         local $/ = undef;
         open FILE, "$target/backupmanifest.xml" or die "Couldn't open file: $!";
         binmode FILE;
         $xml = <FILE>;
         close FILE;
      }
   }
   else {
      logmsg("$server backup failed, $target/backupmanifest.xml cannot be read");
      alert($server, "Datapower secure backup has failed on $server, raise incident to Apps queue");
      return;
   }
   my $xml   = ParseXML::ParseXML->new($xml);
   my $files = $xml->getElementByTagName('files');
   foreach my $file ($files->getElementByTagName('file')) {
      my $filename = $file->getElementByTagName('filename')->text;
      next if $filename eq "backupmanifest.xml";
      my $filesize       = $file->getElementByTagName('filesize')->text;
      my $checksum       = $file->getElementByTagName('checksum')->text;
      my $local_filename = "$target/${filename}";
      my $local_filesize = -s $local_filename;

      #      my $local_checksum = (split(/\s+/, `/usr/bin/md5sum $local_filename`))[0];
      if ($filesize != $local_filesize) {
         alert($server, "secure backup failed verification");
         logmsg("$local_filename file size mismatch");
      }
      else {
         logmsg("$local_filename transfered OK");
      }
   }
}
exit;

#=============================================================
# Write a log msg to STDERR
#=============================================================
sub logmsg {
   my $msg = shift;
   my $time = printf STDERR "%4d-%02d-%02d %02d:%02d:%02d %s\n", (localtime)[5] + 1900, (localtime)[4] + 1, (localtime)[3],
     (localtime)[ 2, 1, 0 ], $msg;
}

#=============================================================
# get a file from the datapower
#=============================================================
sub get_file {
   my ($server, $file) = @_;
   logmsg("Copy $file to local server $target/${file}");
   my $result = execute_soma($server, "<dp:get-file name=\"temporary:///securebackup/$file\"/>");
   if ($result) {
      my $content64 = $result->getElementByTagName('dp:file')->text;
      my $content   = decode_base64($content64);
      open F, ">", "$target/${file}";
      print F $content;
      close F;
   }
   else {
      alert($server, "secure backup failed retrieving files");
      logmsg("Copy failed for $file");
   }
}

#=============================================================
# Perform the secure backup
#=============================================================
sub secure_backup {
   my $server = shift;
   logmsg("Perform secure backup on $server");
   my $request = <<EOF;
<dp:do-action>
<SecureBackup>
<cert>$cert</cert>
<destination>temporary://securebackup</destination>
<include-iscsi>on</include-iscsi>
<include-raid>on</include-raid>
</SecureBackup>
</dp:do-action>
EOF
   my $response = execute_soma($server, $request);
   if ($response) {
      logmsg("Secure backup complete");
      return 1;
   }
   else {
      alert($server, "secure backup failed");
      logmsg("Secure backup failed");
      return;
   }
}

#=============================================================
# List files on securebackup directory
#=============================================================
sub list_files {
   my $server = shift;
   logmsg("Get list of backup files");
   my @files;
   my $response = execute_soma($server, '<dp:get-filestore location="temporary:"/>');
   if ($response) {
      foreach my $dir ($response->getElementByTagName('directory')) {
         if ($dir->attr('name') =~ /^temporary:\/securebackup/) {
            foreach my $file ($dir->getElementByTagName('file')) {
               push @files, $file->attr('name');
            }
         }
      }
      return @files;
   }
   else {
      alert($server, "secure backup failed listing files");
      logmsg("List files failed");
      return;
   }
}

#=============================================================
# Execute the SOMA request
#=============================================================
sub execute_soma {
   my ($server, $request_xml) = @_;
   $request_xml =~ s/^\s+|\s+$//;
   my $req_url = "https://${server}.event.ibm.com:5550/service/mgmt/current";
   $request_xml = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
<env:Body>
<dp:request xmlns:dp="http://www.datapower.com/schemas/management" domain="default">
$request_xml
</dp:request>
</env:Body>
</env:Envelope>
EOF
   my $result = `echo user = \"$user:$password\" | curl -s -S -D - -K - -d '$request_xml' $req_url`;
   my ($dp_result, $dp_fault);
   my ($httprc, $is_success) = $result =~ /^HTTP.+?(\d\d\d)\s(.*)/;
   $result =~ s/.*\<\?xml/\<\?xml/ism;
   $is_success =~ s/^\s+|\s+$//g;

   if ($httprc == 200) {
      my $response = ParseXML::ParseXML->new($result);
      if ($result =~ /dp:result/imsx) {
         $dp_result = $response->getElementByTagName('dp:result')->text;
         $dp_result =~ s/^\s+//isxm;
         $dp_result =~ s/\s+$//isxm;
         logmsg("dp_result: $dp_result") if $ENV{debug};
      }
      if ($result =~ /<faultstring>/imsx) {
         $dp_fault = $response->getElementByTagName('faultstring')->text;
      }
      
      
      if (
         $is_success eq "Good"
         && $httprc == 200 
         && (!$dp_result || $dp_result eq "OK") 
         && !$dp_fault
        ) {
         return $response;
      }
      else {
         logmsg(  "\n\n$server returned  httprc: " . $httprc
                . "\n\tis_success: " . $is_success
                . "\n\tdp_result:  $dp_result "
                . "\n\tdp_fault: $dp_fault\n\n");
         logmsg($result) if $ENV{debug};
         return;
      }
   }
   else {
      logmsg("$server returned  is_success: $httprc");
   }
}

#=============================================================
# Send ITM alert
#=============================================================
sub alert {
   my ($server, $message) = @_;
   $message = "PAGE-0000 - $message";
   my @alert_args = ('/opt/IBM/ITMscripts/ITM_to_Omni', '-k', 'alert' . $count++ , '-h', $server, '-G', 11, '-p', 300, $message);

   #=============================================================
   # send alert to ITM if not running from a TTY
   #=============================================================
   if (!-t STDIN) {
      system(@alert_args);
   }
}
