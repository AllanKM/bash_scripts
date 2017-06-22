#!/usr/local/bin/perl
#==============================================================================================
# Revision : $Revision: 1.3 $
# Source   : $Source: /cvsroot/hpodstools/lfs_tools/ihs/bin/ihs_itcs104_scan.pl,v $
# Date     : $Date: 2013/08/13 14:58:39 $
#
# $Log: ihs_itcs104_scan.pl,v $
# Revision 1.3  2013/08/13 14:58:39  steve_farrell
# Fix errors created by IHS7 deploy leaving dead symlinks lying around hat the script didnt handle too well
#
# Revision 1.3  2013/08/13 12:05:46  steve
# Fix problem with non-existant config files pointed to by symlinks
#
# Revision 1.2  2012/09/04 07:41:12  steve_farrell
# Add header/footer showing ITCS version, run date and overall compliance status
# Add explanation of what was checked to each test.
#
# Revision 1.6  2012/09/04 07:36:48  stevef
# Add header/footer and test explanations
#
# Revision 1.5  2012/05/10 13:11:02  stevef
# scan individual configs passed as parms
#
# Revision 1.4  2012/03/22 08:17:19  stevef
# Only go into background if running without a tty ... ie from tivtask
#
# Revision 1.3  2012/03/08 12:59:24  stevef
# print msg if no ihs configs found
#
# Revision 1.2  2012/03/07 11:51:39  stevef
# Add nohup (daemonize) mode of running
#
# Revision 1.1  2012/03/07 09:48:10  stevef
# Initial revision
#
# Revision 1.1  2012/03/07 09:21:25  steve
# Initial revision
#
#==============================================================================================

use FindBin;
use lib ("$FindBin::Bin/lib", "$FindBin::Bin/../lib");
use Data::Dumper;
use Sys::Hostname;
use EI::DirStore;
use Fcntl ':mode';
use Parse_Config;
use debug;

my $itcs_version = "Version 9.0 - September 30, 2011";
my $ihs_chapter = "2.2.3 Apache web servers";
my $run_date = localtime;
my $host = hostname;

my ($uid,$gid);

my %rules = (
   server_root => { 
      perms   => { user  => S_IWUSR,               # User write access not permitted  
                   group => S_IWGRP,               # group write access not permitted
                   other => S_IWOTH                # global write access not permitted 
                 },
      uid     => \$uid,
      gid     => \$gid,
   },
   documentroot => { 
      perms   => { user  => S_IWUSR,               # User write access not permitted  
                   group => S_IWGRP,               # group write access not permitted
                   other => S_IWOTH                # global write access not permitted 
                 },
      uid     => \$uid,
      gid     => \$gid,
      follow  => 1,
   },
   config_dirs => { 
      perms   => { user  => S_IWUSR,               # User write access not permitted  
                   group => S_IWGRP,               # group write access not permitted
                   other => S_IWOTH                # global write access not permitted 
                 },
      uid     => \$uid,
      gid     => \$gid,
      follow  => 1,
   },
   log_dirs => { 
      perms   => {
                   other => S_IWOTH                # global write access not permitted 
                 },
      follow  => 1,
   },
   
   bin_dir    => { 
      perms   => { user  => S_IWUSR,               # User write access not permitted  
                   group => S_IWGRP,               # group write access not permitted
                   other => S_IWOTH                # global write access not permitted 
                 },
      uid     => \$uid,
      gid     => \$gid,
      follow  => 1,
   },
   
   loadmodules    => { 
      perms   => { user  => S_IWUSR,               # User write access not permitted  
                   group => S_IWGRP,               # group write access not permitted
                   other => S_IWOTH                # global write access not permitted 
                 },
       uid     => \$uid,
       gid     => \$gid,
   },

   cgi_dirs   => { 
      perms   => { user  => S_IWUSR,               # User write access not permitted  
                   group => S_IWGRP,               # group write access not permitted
                   other => S_IWOTH                # global write access not permitted 
                 },
       uid     => \$uid,
       gid     => \$gid,
       follow  => 1,
       name    => ( [ qw/phf test-cgi nph-test-cgi post-query uptime upload wais.pl/ ] ),
   },
   
  shells   => { 
      perms   => { user  => S_IWUSR,               # User write access not permitted  
                   group => S_IWGRP,               # group write access not permitted
                   other => S_IWOTH                # global write access not permitted 
                 },
       uid     => \$uid,
       gid     => \$gid,
       follow  => 1, 
       name    => ( [ qw/sh bash csh ksh tsh tclsh wish perl command.com python zsh/ ] ),
   },
   
);

daemonize('/fs/scratch/ihs_itcs104/'.hostname.'_scan.log') if ! -t;                  # Nohup myself if run via tivtask;

my @configs = find_ihs_configs(\@ARGV);

if ( scalar @configs == 0 ) {
   print STDERR "No IHS configs detected\n";
   exit;
}
else {
   debug(@configs);
}
debug("scanning IHS configs");
foreach my $conf ( sort @configs ) {
   next if -l $conf || ! $conf || ! -e $conf;

   my $config_data=parse_ihs_config($conf,{output_dir => '/fs/scratch/ihs_itcs104'} );

   my $report_fh = $config_data->report_fh;
   debug( "report file: $config_data->reportname");
   
   $uid=$config_data -> server_uid;
   $gid=$config_data -> server_gid;
   
#   $config_data -> check_rights('test_dirs',$rules{'documentroot'});
#   exit;

#================================================================
# Print header
#================================================================   

print $report_fh "-" x 80 ."\n";
print $report_fh qq (
   ITCS 104 Health check for Chapter $ihs_chapter
   Checks to ITCS specification   : $itcs_version
   Produced by automated tool run : $host:$FindBin::Bin/ihs_itcs104_scan.pl 
   Run Date			  : $run_date
   
);
print $report_fh "-" x 80 ."\n";

   # now do the work of finding and reporting issues
#================================================================
# 1.1.1 WebAdmins
#================================================================   
   print $report_fh qq(
   1.1 Userids
      Webserver Administrator/Webmaster
      ---------------------------------
      An ID having full system or security admnistration authority
      Can access the server either locally or remotely
      Admin rights granted thru SUDO
   );
      
   $config_data -> show_web_admins();
#================================================================
# 1.1.2 report Web Authors - write access to Docroot dirs
#================================================================
   print $report_fh qq(
    Web Authors
    -----------
     An ID having read and write access to the document tree
   );
   $config_data -> show_web_authors();

#================================================================
# 1.1.3 $report_fh Web developers - write access to cgi dirs
#================================================================
   print $report_fh qq(
   Web Developers
   --------------
      An author ID having additional authority to install and modify CGI scripts
   );
   $config_data -> show_web_developers();
#================================================================
# 1.1.4 $report_fh server owner
#================================================================   
   print $report_fh qq( 
   Web Server ID
   -------------
      ID which runs the web server
   );
   printf $report_fh "\t\tuser: %s\n\t\tgroup: %s\n",$config_data->server_user,$config_data->server_group;
#================================================================
# 2 Authentication
#   No checks made at the IHS server level
#================================================================
#================================================================
# 3.2 user resources
#================================================================
   print $report_fh qq(
   3.2 User Resources
   ------------------
      IBM Confidential Information
      ----------------------------
      Not stored on EI systems
      Document Tree
      -------------
      Confidential data not stored on EI systems
   );
   
#================================================================
# 4.1 SSL certificates
#================================================================
   print $report_fh qq(
   4.1 Encryption
   --------------
      Data Transmission
      -----------------
         SSL
   );
   $config_data -> ssl_vhost_certificates();
#================================================================
# 5.1.1 Server root
#================================================================   
   print $report_fh qq(
   5.1 Operating system resources
   ------------------------------
      Server Root
      -----------
   );
   print $report_fh $config_data->showrules($rules{'server_root'});
   $config_data -> check_rights('server_root',$rules{'server_root'});
   
#================================================================
# 5.1.2 Document roots
#================================================================  
   print $report_fh qq(
   Document Root
   -------------
   This directive sets the directory from which httpd will serve files.
   Unless matched by a directive like Alias, the server appends the path from the requested URL to the document root to make the path to the document.
   );
      print $report_fh $config_data->showrules($rules{'documentroot'});
   $config_data -> check_rights('documentroot',$rules{'documentroot'});
#================================================================
# 5.1.3 OSR's
#================================================================   
   print $report_fh qq( 
   Apache OSRs
   -----------
      OSRs for webservers are directories and files which contain executables, libraries, modules, configuration files and other configuration objects. By default they are located within the ServerRoot but may have other locations if specified by configuration statements and compiled-in defaults.
      General users at an operating system level may be allowed read (or read & execute) access to the following OSR directories and files:
    
      Configuration File Directory
      ----------------------------
   );
   print $report_fh $config_data->showrules($rules{'config_dirs'});
   $config_data -> check_rights('config_dirs',$rules{'config_dirs'});
#================================================================
# 5.1.4 Log directories  
#================================================================   
   my $self = shift;   
   print $report_fh qq(
      logs Directory
      ----------------------------
   );
      print $report_fh $config_data->showrules($rules{'log_dirs'});
   $config_data -> check_rights('log_dirs',$rules{'log_dirs'});
   
#================================================================
# 5.1.5 Bin directory  
#================================================================
   print $report_fh qq(
      Bin Directory
      -------------
   );   
         print $report_fh $config_data->showrules($rules{'bin_dir'});
   $config_data -> check_rights('bin_dir',$rules{'bin_dir'});
#================================================================
# 5.1.6 Modules  
#================================================================
   print $report_fh qq(
      Load Module/LibExec Modules
      ---------------------------
   );
         print $report_fh $config_data->showrules($rules{'loadmodules'});
   $config_data -> check_rights('loadmodules',$rules{'loadmodules'});

#================================================================
# 5.1.7 Default rule (optional)  
#================================================================            
   print $report_fh qq(
      Default Access Rule (optional)
      -------------------
      The following directives have to be put into the main apache configuration file near the beginning before any other Directory statements:
         <Directory />
           Order Deny,Allow
           Deny from all
           Options None
           AllowOverride None
         </Directory>
   );
   
   $config_data -> check_default_rule();
   
#================================================================
# 5.1.8 CGI directories  
#================================================================            
         
   my $disallowed = join(', ',@{$rules{'cgi_dirs'}{name}});
   print $report_fh qq(
      CGI Scripts 
      -----------
   );
   print $report_fh $config_data->showrules($rules{'cgi_dirs'});
   $config_data -> check_rights('cgi_dirs',$rules{'cgi_dirs'});
   
#================================================================
# 5.1.9 Shell or script interpreters  
#================================================================   

   print $report_fh qq(
      Shell or script interpreters
      ----------------------------
   );
   print $report_fh $config_data->showrules($rules{'shells'});
   $config_data -> check_rights('cgi_dirs',$rules{'shells'});

#================================================================
# 6.1 Logging  
#================================================================   
  print $report_fh qq(
  6.1 Activity auditing
  ---------------------
   TransferLog
   -----------
   Web Server Log where activity is stored
   Defined by TransferLog directive in Server Configuration file
   );
   $config_data -> logs();

#================================================================
# Footer... overall status
#================================================================   
   print $report_fh "\n". "*" x 80 ."\n";
   if ( $config_data->{compliant} ) {
       print $report_fh qq(
**                  Overall Status: Compliant                                 **
);
   }
   else {
             print $report_fh qq(
**                  Overall Status: Non Compliant                             **
);
   }
   print $report_fh "\n". "*" x 80 ."\n";
}

sub daemonize {
   my $log=shift;
   use POSIX qw(setsid);
   POSIX::setsid or die "setsid: $!";
   my $pid = fork();
   if ($pid < 0) {     # fork failed
       die "fork: $!";
   } elsif ($pid) {    # original paren script
      exit 0;
   }
   # daemon continues here
   chdir "/";
   umask 0;
   foreach (0 .. (POSIX::sysconf (&POSIX::_SC_OPEN_MAX) || 1024)) {
       POSIX::close $_ 
   }
   open (STDIN, "</dev/null");
   open (STDOUT, ">$log");
   open (STDERR, ">&STDOUT");
}
