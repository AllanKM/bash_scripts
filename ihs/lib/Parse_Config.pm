#==============================================================================================
# Revision : $Revision: 1.6 $
# Source   : $Source: /cvsroot/hpodstools/lfs_tools/ihs/lib/Parse_Config.pm,v $
# Date     : $Date: 2015/11/17 20:20:55 $
#
# $Log: Parse_Config.pm,v $
# Revision 1.6  2015/11/17 20:20:55  keith_white
# Removed Term::ANSIColor use of colored() which is now deprecated
#
# Revision 1.5  2014/04/30 08:48:47  steve_farrell
# Exclude partial config files being treated as main configs
# Add PX5
#
# Revision 1.4  2014/01/23 14:06:11  steve_farrell
# Add support for CI1 and new IHS default install location
#
# Revision 1.3  2013/08/13 14:58:39  steve_farrell
# Fix errors created by IHS7 deploy leaving dead symlinks lying around hat the script didnt handle too well
#
# Revision 1.1  2013/08/13 12:07:55  steve
# Initial revision
#
# Revision 1.2  2012/09/04 07:41:12  steve_farrell
# Add header/footer showing ITCS version, run date and overall compliance status
# Add explanation of what was checked to each test.
#
# Revision 1.7  2012/09/04 07:37:56  stevef
# Add rule print routine
#
# Revision 1.1  2012/05/16 14:00:36  steve_farrell
# Install new IHS ITCS104 scanning scripts
#
# Revision 1.6  2012/05/10 13:11:28  stevef
# detect OS arch and invoke 64/32 bit gskit as appropriate
#
# Revision 1.5  2012/03/23 14:24:58  stevef
# Major rewrite of the logging of failure msgs
#
# Revision 1.4  2012/03/22 16:15:58  stevef
# Remove files older than 1 hour to allow rerunning from commandline without manual cleanup
#
# Revision 1.3  2012/03/22 13:52:37  stevef
# Output failing msgs to console if attached to a tty
# Filter configs to scan using cmdline parms are regex string
#
# Revision 1.2  2012/03/07 11:52:23  stevef
# add daemonzie (nohup) mode of running
#
# Revision 1.1  2012/03/07 09:48:33  stevef
# Initial revision
#
# Revision 1.1  2012/03/07 09:21:25  steve
# Initial revision
#
#==============================================================================================

package Parse_Config;
use strict;
use warnings;
use Exporter;
use File::Find;
use File::Basename;
use File::Spec;
use File::stat;
use Sys::Hostname;
use Fcntl ':mode';
use Data::Dumper;
use EI::DirStore;
use Term::ANSIColor;
use Term::ANSIColor qw(:constants);

use FindBin;
use lib ("$FindBin::Bin/lib", "$FindBin::Bin/../lib");
use debug;
use resolv_symlink;

our @ISA    = qw(Exporter);
our @EXPORT = qw( find_ihs_configs parse_ihs_config );

my $report_fh;          # file handle for the report;

#==========================================================================
# regular expressions used to parse the config data and find output
#==========================================================================
my %re = (
   scriptalias => qr/
      \n                            # after a new line
      \s*?                          # skip any whitespace
      scriptalias                   # word scriptalias
      \s+?                          # followed by whitespace
      \S+                           # non whitespace
      \s+                           # whitespace
      (\S+)                         # capture non whitespace
   /isx,
   directorystanza => qr/
      \n                            # new line
      \s*?                          # whitespace
      <directory                    # start of <directory
      \s+                           # whitespace
      (\S+?)                        # directory name
      \s*?                          # whitespace
      >                             # >
      (.*?)                         # directory keywords
      <\/directory>                 # end of directory stanza
   /isx,
   defaultdirectoryrule => qr/
      \n                            # new line
      \s*?                          # whitespace
      <directory                    # start of directory stanza
      \s+?                          # whitespace
      \/>                           # end of directory keyword
      (.+?)                         # stanza keywords
      <\/directory>                 # end of stanza
   /isx,
   execcgi => qr/
      \n                            # newline
      \s*?                          # whitespace
      options                       # options keyword
      .*?                           # anything
      \s                            # whitespace
      execcgi                       # execcgi
      \s                            # whitespace
   /isx,
   addhandler => qr/
      \n
      \s*?
      addhandler
      \s+
      \S+
      (cgi|script|php)
      \s
   /isx,
   include => qr/
      \n                            # newline
      \s*?                          # whitespace
      include                       # include keyword
      \s+?                          # whitespace
      (\S+)                         # name of include file
   /isx,
   loadmodule => qr/
      \n                            # newline
      \s*?                          # whitespace
      loadmodule                    # loadmodule keyword
      \s+?                          # whitespace
      \S+                           # module internal alias
      \s+                           # whitespace
      (\S+)                         # module file
   /isx,
   logfile => qr/
      \n                                        # newline
      \s*?                                      # whitespace
      (                                         # capture start
      (?:customlog|errorlog|rewritelog)\s       # customlog errorlog rewitelog keywords
      .*?                                       # everyting else
      )                                         # end capture
      \n                                        # end of line
   /isx,
   ssl_vhost => qr/                            # <Virtualhost 9.11.12.153:443>
      \n                                        # newline
      \s*?                                      # whitespace
      \<virtualhost                             # virtualhost keyword
      \s+
      (\S+):443
      \s*?>
      (   
      .*?                                       # everyting else
      ) 
      <\/virtualhost>                           # end capture
   /isx,
   sslcert => qr/                         # SSLServerCert      wwwtest
      \n                                        # newline
      \s*?                                      # whitespace
      SSLServerCert                             # Cert keyword
      \s+
      (   
      \S+                                       # everyting else
      )                                         # end capture
   /isx,
   
   logfile => qr/
      ^\s*(?:customlog|errorlog|rewritelog)\s
   /isx,
   
   eirotate => qr/
      \-logroot\s([^\s]*)
   /ix,
   
   virtualhost => qr/
      ^\s*\<virtualhost\s*(\S*)\s*\>
      /isx,
      
   end_virtualhost => qr/
      ^\s*\<\/virtualhost>
      /isx,
);

#========================================================================================
# Creates object and initialises with config data
#========================================================================================
sub parse_ihs_config {
   my ( $config,$parm_ref ) = @_;
   my $self = {
      main_config  => undef,
      config_files => undef,
      config_dirs  => undef,
      documentroot => undef,
      cgi_dirs     => undef,    #hash
      server_uid   => undef,
      server_gid   => undef,
   #   test_dirs    => [ '/fs/scratch/stevef' ],
      server_user  => undef,
      server_group => undef,
      ssl_vhost    => undef,    # hash -> hash -> array
      keystore     => undef,    # string
      server_root  => undef,    # string
      log_dirs     => undef,    # hash
      bin_dir      => undef,    # string
      loadmodules  => undef,    # array
      log_config   => undef,    # hash -> hash -> array
      default_rule => undef,    # string
      compliant => 1,           # assume its compliant 
   };
   my $output_dir;
   if ( $parm_ref && exists $parm_ref -> {'output_dir'} ) {
      $output_dir= $parm_ref->{'output_dir'};
      $output_dir =~ s/\/$//;
   }
   else {
      $output_dir = '/fs/scratch/ihs_itcs104';
   }
   
   if ( ! $output_dir ) {
      die "output dir not set\n";
   }
   
   # make sure output directory exists
   if ( ! -d "$output_dir" ) {
      `mkdir -p $output_dir`;
      `chgrp eiadm $output_dir`;
      `chmod -R 2770 $output_dir`;
   }
   
   my @mname=qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
   my ($day, $month, $year ) = (localtime)[ 3, 4, 5 ];
   my $date = sprintf("%0d%s%4d",$day,$mname[$month],$year+1900);
   my ($custtag) = (split /\//, $config)[2];
   
   my $conf_string = $config;
   $conf_string =~ s/\//-/g;
   $self->{'server'}=_sws_node_lookup($custtag,hostname);
   
   $self -> {'server'} = $self->{'server'} || hostname;
   
   $self->{'reportname'} = "$output_dir/ihs_itcs104_$self->{'server'}_${date}_${conf_string}.log";
   open $report_fh, '>', $self->{'reportname'} or die "Cannot open $self->{'reportname'} $!\n";
   $self->{'faillog'} = "$output_dir/ihs_itcs104_$self->{'server'}_fails_${date}_${conf_string}.txt";
   
   parse_config( $self, $config );
   my $arr_ptr = \@{ $self->{loadmodules} };
   for ( my $i = 0 ; $i < @$arr_ptr ; $i++ ) {
      if ( $arr_ptr->[$i] !~ /^\// ) {
         $arr_ptr->[$i] = $self->{server_root} . "/" . $arr_ptr->[$i];
      }
   }
   bless $self;
   return $self;
}
#================================================================================
# 
#================================================================================
sub reportname {
   my $self = shift;
   if (@_) { $self->{'reportname'} = shift; }
   $self->{'reportname'};
}
#================================================================================

sub showrules {
   my $self  = shift;
   my $rules = shift;
   debug( Dumper($rules) );
   my $perms = "\tCompliant if ";
   my (@usr,@grp,@oth);
   if ( defined $rules->{follow} ) {
      $perms .= "ALL subdirs/files do";
   }
   else {
      $perms .= "the named dir/file does";
   }
   $perms .= " not match :-\n";
   if ( defined $rules->{name} ) {
  	   $perms .= " " x 10 . "name: " . join(", ",@{$rules->{name}}). "\n";
   }
   
   if ( defined $rules->{uid} ) {
      push @usr, "owner = " . $self->server_user;
   }
   if ( defined $rules->{gid} ) {
      push @grp,"group = " . $self->server_group;
   }
   if ( defined $rules->{perms} ) {
      $perms .= " "x 20 . "or\n" if defined $rules->{name};
      $perms .= " "x 10 . "permissions: ";
      if ( defined $rules->{perms}->{user} ) {
         push @usr,"owner perms = ". substr(_mode_to_symbolic($rules->{perms}->{user}),0,3);
      }
      if ( defined $rules->{perms}->{group} ) {
         push @grp,"group perms = ". substr(_mode_to_symbolic($rules->{perms}->{group}),3,3);
      }
      if ( defined $rules->{perms}->{other} ) {
         push @oth,"other perms = ".substr( _mode_to_symbolic($rules->{perms}->{other}),6,3);
      }
   }
   $perms .= "(" if @usr > 1;
   $perms .= join(" and ",@usr) if @usr;
   $perms .= ")" if @usr > 1;
   
   $perms .= "\n". " " x 20 . "or " if @usr;
   
   $perms .= "(" if @grp > 1;
   $perms .= join(" and ",@grp) if @grp;
   $perms .= ")" if @grp > 1;
   
   $perms .= "\n". " " x 20 . "or " if @usr || @grp;
   
   $perms .= "(" if @oth > 1;
   $perms .= join(" and ",@oth) if @oth;
   $perms .= ")" if @oth > 1;
   
   $perms .= "\n\n";

   return $perms;
}

# 
#================================================================================
sub report_fh {
   my $self = shift;
   if (@_) { $report_fh = shift; }
   $report_fh;
}
#================================================================================
# Write message on console using STDERR
#================================================================================
sub _status {
   my ($msg) = @_;
   my ($sec ,$min, $hour, $day, $month, $year ) = (localtime)[ 0,1,2,3, 4, 5 ];
   $month++;
   $year += 1900;
   $msg =~s/\n+$//;
   print STDERR CLEAR if -t STDERR; 
   printf STDERR "[%4d/%02d/%02d %02d:%02d:%02d] %s\n",$year,$month,$day,$hour,$min,$sec,$msg;
}

#================================================================================
# Read config file and extract useful data
#================================================================================
sub parse_config {
   my ( $self, $config ) = @_;
   
   if ( !$self->{main_config} ) {
      _status("*****************************************\n\t\t\tParsing $config\n\t\t      *******************************************\n");
      $self->{main_config} = $config;
   }
   else {
      $self->{config_files}->{$config} = undef;
   }
   my $config_dir = ( fileparse($config) )[1];
   $config_dir =~ s/\/$//;
   $self->{config_dirs}->{$config_dir} = defined;
   
   if ( open "CFG", "<", $config ) {
      local $/ = undef;
      my $config_data = <CFG>;
      close CFG;
      my $value;

      #======================================================
      # find CGI dirs
      # scriptalias
      #======================================================
      # addhandler cgi-script
      while ( $config_data =~ /$re{'scriptalias'}/g ) {
         debug("$1 added to cgi dirs");
         my $dir = strip($1);
         $dir =~ s/\/$//;
         $self->{cgi_dirs}->{$dir} = undef if -e $dir;
      }

      #========================================================
      # get SSL vhosts and certs
      #========================================================
      while ( $config_data =~ /$re{ssl_vhost}/g ) {
         my $vhost      = $1;
         my $vhost_data = $2;
         $self->{'ssl_vhost'}->{$config}->{$vhost} = undef;
         while ( $vhost_data =~ /$re{'sslcert'}/g ) {
            push @{ $self->{'ssl_vhost'}->{$config}->{$vhost} }, $1;
         }
      }

      #========================================================
      # get directory stanzas with option execcgi enabled
      #========================================================
      while ( $config_data =~ /$re{'directorystanza'}/g ) {

         # have a directory block
         my $dir_name = strip($1);
         my $keywords = $2;
         $dir_name =~ s/\/$//;    # remove trailing /

         #does dir have execcgi option
         if ( $keywords =~ /$re{'execcgi'}/ ) {
            $self->{cgi_dirs}->{$dir_name} = undef if -e $dir_name;
         }

         # or addhandler for cgi type files
         elsif ( $keywords =~ /$re{'addhandler'}/ ) {
            $self->{cgi_dirs}->{$dir_name} = undef if -e $dir_name;
         }
      }

      #========================================================
      # Default directory rule
      #========================================================
      if ( $config_data =~ /$re{'defaultdirectoryrule'}/ ) {
         $self->{default_rule} = strip($1);
      }

      #========================================================
      # get User and UID
      #========================================================
      $value = get_single_value( "user", \$config_data );
      if ($value) {
         $self->{server_user} = $value;
         $self->{server_uid} = ( getpwnam($value) )[2] || -1;
         debug("user: $self->{server_user} uid: $self->{server_uid}");
      }

      #========================================================
      # get Group and GID
      #========================================================
      $value = get_single_value( "group", \$config_data );
      if ($value) {
         $self->{server_group} = $value;
         $self->{server_gid} = getgrnam($value) || -1;
         debug("group: $self->{server_group} gid: $self->{server_gid}");
      }

      #========================================================
      # get Document root
      #========================================================
      $value = get_single_value( "documentroot", \$config_data );
      if ($value) {
         $self->{documentroot}->{$value} = undef;
      }

      #========================================================
      # get Server root
      #========================================================
      $value = get_single_value( "serverroot", \$config_data );
      if ($value) {
         $self->{server_root} = $value;
         $self->{bin_dir}     = $self->{server_root} . "/bin";
      }

      #========================================================
      # get Keystore
      #========================================================
      $value = get_single_value( "keyfile", \$config_data );
      if ($value) {
         $self->{keystore} = $value;
      }

      #========================================================
      # get Include files and parse them aswell
      #========================================================
      while ( $config_data =~ /$re{'include'}/g ) {
         my $conf = strip($1);
         parse_config( $self, $conf );
      }

      #========================================================
      # Loadmodules
      #========================================================
      while ( $config_data =~ /$re{'loadmodule'}/g ) {
         push @{ $self->{loadmodules} }, strip($1);
      }

      #========================================================
      # Logfiles
      #========================================================
      my @config_data = split( /\n/, $config_data );
      my $vhost = "default";
      foreach my $line (@config_data) {
         if ( $line =~ /$re{logfile}/ ) {
            my $log;
            push @{ $self->{'log_config'}->{$config}->{$vhost} },
              $line;    # save config line
            if ( $line =~ /eirotate/i ) {
               ($log) = $line =~ /$re{'eirotate'}/;
            }
            else {
               $log = ( split( /\s+/, $line ) )[1];
            }
            if ( ! $log ) {
               _status("Faled to handle $line properly");
            }
            if ( $log !~ /^\// ) {
               $log = $self->{'server_root'} . '/' . $log;
            }
            ($log) = $log =~ /(.*)\//;    # upto last /
            $self->{log_dirs}->{$log} = undef;    # save log dir
         }
         if ( $line =~ /$re{virtualhost}/ ) {
            $vhost = $1;
         }
         if ( $line =~ /$re{end_virtualhost}/ ) {
            $vhost = "default";
         }
      }
   }
   else {
      warn "Cannot open $self->{$config}->{name} $!\n";
   }
}

#================================================================================
# Object accessor for server uid
#================================================================================
sub server_uid {
   my $self = shift;
   if (@_) { $self->{'server_uid'} = shift; }
   $self->{'server_uid'};
}
#================================================================================
# Object accessor for server user
#================================================================================
sub server_user {
   my $self = shift;
   if (@_) { $self->{'server_user'} = shift; }
   $self->{'server_user'};
}
#================================================================================
# Object accessor for server gid
#================================================================================
sub server_gid {
   my $self = shift;
   if (@_) { $self->{'server_gid'} = shift; }
   $self->{'server_gid'};
}
#================================================================================
# Object accessor for server group
#================================================================================
sub server_group {
   my $self = shift;
   if (@_) { $self->{'server_group'} = shift; }
   $self->{'server_group'};
}
#================================================================================
# Object accessor for default rule
#================================================================================
sub default_rule {
   my $self = shift;
   if (@_) { $self->{'default_rule'} = shift; }
   $self->{'default_rule'};
}
#============================================================
# retrieve value of first occurance of a supplied keyword
#============================================================
sub get_single_value {
   my ( $keyword, $data_ref ) = @_;
   if ( $$data_ref =~ /\n\s*?${keyword}\s+?(\S+)/is ) {
      return strip($1);
   }
   return;
}
#============================================================
# remove leading / trailing whitespace and quotes
#============================================================
sub strip {
   my ($string) = @_;
   $string =~ s/^[\"\s]+//;
   $string =~ s/[\"\s]+$//;
   return $string;
}

#================================================================================
#
#================================================================================
sub show_web_admins {
   my $self = shift;
   _status("show web admins\n");
   my @groups;
   open CMD, "<", "/etc/sudoers" or die "cannot open /etc/sudoers $!\n";
   while (<CMD>) {
      if (/^%.*ALL=ALL/) {
         my ($group) = $_ =~ /%(\w+?)\s/;
         push @groups, $group;
      }
   }
   close CMD;
   foreach my $group (@groups) {
      my ( $name, $members ) = ( getgrnam($group) )[ 0, 3 ];
      if ($name) {
         print $report_fh "\t\tgroup: $group\n";
         print $report_fh "\t\tmembers: ";
         fmt_members($members);
         print $report_fh "\n\n";
      }
      else {
         print $report_fh "\t\t$group does not exist\n\n";
      }
   }
}

# -----------------------------------------------------------------------------------
# report Web Authors - write access to Docroot dirs
#------------------------------------------------------------------------------------
sub show_web_authors {
   my $self = shift;
   _status("show web authors\n");
   report_dir( "Document tree", $self->{'documentroot'} );
}

# -----------------------------------------------------------------------------------
# report Web Developers - write access to cgi-bin dirs
#------------------------------------------------------------------------------------
sub show_web_developers {
   my $self = shift;
   _status("show web developers\n");
   if ( $self->{'cgi_dirs'} ) {
      report_dir( "CGI directory", $self->{'cgi_dirs'} );
   }
   else {
      print $report_fh "\t\tNo CGI directories\n\n";
   }
}

#-----------------------------------------------------------------------------------
# Report 4.1 Encryption
#------------------------------------------------------------------------------------
sub ssl_vhost_certificates {
   my $self = shift;
   _status("SSL certificates\n");
   if ( !$self->{'ssl_vhost'} ) {
      print $report_fh "\t\tNo SSL vhosts defined - Compliant\n";
      return;
   }
   my $gskit = _find_gskit();
   debug($gskit);
   my $keystore = $self->{'keystore'};
   my $certlist;
   foreach my $config ( sort keys %{ $self->{'ssl_vhost'} } ) {
      my $vhost_ref = $self->{'ssl_vhost'}->{$config};
      foreach my $vhost ( sort keys %$vhost_ref ) {
         my $cert_ref = $vhost_ref->{$vhost};
         if ( defined $cert_ref ) {
            foreach my $cert ( sort @$cert_ref ) {
               $certlist .= "\n\t\t$config\t$vhost:443\t$cert\n";
            }
         }
         else {
            $certlist .= "\n\t\t$config\t$vhost:443\t*DEFAULT*";
         }
      }
   }
   if ( !-e $gskit ) {
      fail($self,"cert","gskit command not found, cannot process keystore $keystore for $certlist");
      print $report_fh "*FAIL* gskit command not found, cannot process keystore $keystore for $certlist\n";
      return;
   }
   if ( !$keystore ) {
      fail($self,"cert","Server configured with SSL vhosts but no keystore for $certlist");
      print $report_fh "*FAIL* Server configured with SSL vhosts but no keystore for $certlist\n";
      return;
   }
   elsif ( !-e $keystore ) {
      fail($self,"cert","$keystore does not exist for $certlist");
      print $report_fh "*FAIL* ${keystore} does not exist for $certlist\n";
      return;
   }
   my $keystore_pw;
   $keystore_pw = decode_pw( $self,$self->{'keystore'} )
     if defined $self->{'keystore'};
   debug("$keystore_pw");
   if ($keystore_pw) {
      debug("listing certificates");
      foreach my $config ( sort keys %{ $self->{'ssl_vhost'} } ) {

         # $ssl_vhost is a hash ref
         debug("$config");
         my $vhost_ref = $self->{'ssl_vhost'}->{$config};
         foreach my $vhost ( sort keys %$vhost_ref ) {
            debug("$vhost");
            my $cert_ref = $vhost_ref->{$vhost};
            if ( defined $cert_ref ) {
               foreach my $cert ( sort @$cert_ref ) {
                  debug("$cert");
                  printcert( $self,$self->{'keystore'}, $keystore_pw, $config, $vhost, $cert, $gskit );
               }
            }
            else {
               debug("default cert");
               printcert( $self,$self->{'keystore'}, $keystore_pw, $config, $vhost, '', $gskit );
            }
         }
      }
   }
}

#-----------------------------------------------------------------------------------
# Find GSKIT
#------------------------------------------------------------------------------------
sub _find_gskit {
   my @gsdirs;
   push @gsdirs, '/usr/opt/ibm' if  -e '/usr/opt/ibm' ;
   push @gsdirs, '/usr/local/ibm' if  -e '/usr/local/ibm' ;
   # are we on linux or aix 
   my $os = `uname -s`;
   my $re = qr/gsk\d+capicmd/i;
   if ( $os =~/AIX/i ) { 
      my $bit64 = `getconf -a | grep KERN`; 
      if ( $bit64 =~/64/ ) {
          $re=qr/gsk\d+capicmd_64/i;
      }
   }
   else {
      my $bit64 = `uname -i`;
      if ( $bit64 =~/64/ ) {
          $re=qr/gsk\d+capicmd_64/i;
      }
   }
      
   eval {
      find( sub { die "$File::Find::name" if $_ =~ /$re/ },
         @gsdirs );
   };
   my ($gskit) = $@ =~ /(.+) at /;
   debug($gskit);
   return $gskit;
}

#================================================
# print certificate details
#================================================
sub printcert {
   my ($self, $keystore, $keystore_pw, $conf, $vhost, $cert, $gskit ) = @_;
   
   my %monthname_to_number =
     qw(JANUARY 1 FEBRUARY 2 MARCH 3 APRIL 4 MAY 5 JUNE 6 JULY 7 AUGUST 8 SEPTEMBER 9
     OCTOBER 10 NOVEMBER 11 DECEMBER 12);
   my %monthshortname_to_number =
     qw(JAN 1 FEB 2 MAR 3 APR 4 MAY 5 JUN 6 JUL 7 AUG 8 SEP 9
     OCT 10 NOV 11 DEC 12);
   print $report_fh "\t$conf\t$vhost:443\n";
   if ($cert) {
      $gskit .= " -cert -details -label \"$cert\"";
   }
   else {
      $gskit .= " -cert -getdefault";
   }
   $gskit .= " -db \"$keystore\" -pw \"$keystore_pw\"";
   debug($gskit);
   my @certinfo = `$gskit`;
   if ( $? == 0 ) {
      
      for ( my $i = 0 ; $i < @certinfo ; $i++ ) {
         debug($certinfo[$i]);
         
         if ( $certinfo[$i] =~ /(?:label|
                  issuer|
                  issued\sby|
                  subject|
                  not\sbefore|
                  not\safter|
                  valid\sfrom|
                  valid\sto)
                  \s*?:/ix ) {
                     
            if ( $certinfo[$i] =~/label/isxm ) {
               ($cert) = $certinfo[$i] =~ /:(.*)/isxm;
               chomp $cert;
            }         
            debug("using $certinfo[$i]");
            print $report_fh "\t   $certinfo[$i]";

            # fail if after expire date
            my ( $cday,$cmonth,$cyear,$checkdate);
            if ( $certinfo[$i] =~ /valid from.*to:/i ) {
               # Valid From: Wednesday, 20 April 2011 15:26:36 PM To: Thursday, 22 May 2014 19:54:18 PM
               # Valid From: Wednesday, 24 December 2008 16:48:45 PM To: Sunday, 24 January 2010 16:48:45 PM
               ( $cday, $cmonth, $cyear ) = $certinfo[$i] =~ /to:.*,\s+(\d+)\s+(\w+)\s+(\d{4})/i;
               
               $cmonth = $monthname_to_number{ uc $cmonth };
               $checkdate=1;
            } 
            elsif ( $certinfo[$i] =~ /after\s+:/i ) {
               # Not After : September 10, 2012 7:38:28 PM GMT+82:34:58
               ( $cmonth, $cday, $cyear ) = $certinfo[$i] =~ /:\s+(\w+)\s+(\d{1,2}),\s+(\d{4})/;
               $cmonth = $monthname_to_number{ uc $cmonth };
               $checkdate=1;
            }
            if ( $checkdate ) {
               my ( $day, $month, $year ) = (localtime)[ 3, 4, 5 ];
               $month++;
               $year += 1900;
               my $cdate = sprintf "%4d%02d%02d", $cyear, $cmonth, $cday;
               my $date  = sprintf "%4d%02d%02d", $year,  $month,  $day;
               if ( $date > $cdate ) {
                  fail($self,"cert","$keystore $cert certificate expired");
                  print $report_fh "*FAIL* $keystore $cert certificate expired\n";
               }
            }
         }
      }
      print $report_fh "\n";
   }
   else {
      my $failmsg;
      print $report_fh "\t*FAIL* ";
      foreach (@certinfo) {
         last if /command usage/i;
         $failmsg .= $_;
         print $report_fh "\t   $_";
      }
      fail($self,"cert",$failmsg);
   }
}

#================================================
# decode_pw - get password from kdb stash file
#================================================
sub decode_pw {
   my ($self,$keystore) = @_;
   my $stash = $keystore;
   $stash =~ s/.kdb/.sth/;
   my $pw;
   if ( -e $stash ) {
      if ( open "F", "<", "$stash" ) {
         my $data;
         read F, $data, 1024;
         my @unstash = map { $_ ^ 0xf5 } unpack( "C*", $data );
         foreach my $c (@unstash) {
            last if $c eq 0;
            $pw .= sprintf "%c", $c;
         }
         debug("password: $pw");
         return $pw;
      }
      else {
         fail($self,"cert","Can't open stash file $stash: $!");
         return undef;
      }
   }
   else {
      fail($self,"cert","Stash file for $keystore does not exist");
      return;
   }
}

# -----------------------------------------------------------------------------------
# report user/group info for a hash of directories
#------------------------------------------------------------------------------------
sub report_dir {
   my ( $title, $dir_ref ) = @_;
   foreach my $dir ( sort keys %$dir_ref ) {
      _status("report dir $dir\n");
      debug("$title: $dir");
      print $report_fh "\t$title: $dir\n";
      if ( -l $dir ) {
         $dir = realname($dir);
         print $report_fh "-> $dir ";
      }
      if ( -e $dir ) {
         my $gid = ( stat $dir )->gid;
         debug("gid:$gid");
         my ($group) = ( getgrgid $gid )[0];
         if ($group) {
            my ($members) = ( getgrgid $gid )[3];
            print $report_fh "\t\tgroup: $group\n\t\tmembers: ";
            fmt_members($members);
            print $report_fh "\n\n";
         }
         else {
            print $report_fh "\t\tgroup: $gid  does not exist\n";
            print $report_fh "\t\tmembers: Cannot determine members\n\n";
         }
      }
      else {
         print $report_fh "\t\tDirectory does not exist\n\n";
      }
   }
}

#=================================================
# format member list
#=================================================
sub fmt_members {
   my ($members) = @_;
   my $l = 0;
   foreach my $member ( sort split( /\s+/, $members ) ) {
      print $report_fh "$member ";
      $l += length($member) + 1;
      if ( $l > 80 ) {
         print $report_fh "\n\t\t\t";
         $l = 0;
      }
   }
}

#==========================================================================
# compare file permissions against ITCS permitted settings
#==========================================================================
sub check_rights {
   my ( $self, $target, $rules ) = @_;
   
   # if config subject pointed to by target does not exist just return
   return if ! exists $self->{$target};
   
   # use target to lookup the list of files/directories to scan
   $target = $self->{"$target"};
   if ( !defined $target ) {
      print $report_fh "None found\n";
      return;
   }
   
   # see if we were passed 1 file, and array of files or a hash and convert all to an array
   my $type = ref $target || 'STRING';
   debug("$target is of type $type");
   my @targets;
   if ( $type eq "ARRAY" ) {
      @targets = @{$target};
   }
   elsif ( $type eq 'HASH' ) {
      @targets = keys %$target;
   }
   else {
      push @targets, $target;
   }
   
   # check just the named file, or all the files below it  
   if ( $rules->{'follow'} ) {    # want to check all files/dirs below
      foreach my $target (@targets) {
         _status("check_rights $target\n");
         scan_directory( $self, $target, $rules );
         if ( $rules->{'name'} ) {
            findfiles($self, $target, $rules);
         }
      }
   }
   else {                         # just check the named file
      foreach my $target (@targets) {
         
         my $fail_count = 0;
         print $report_fh "\t$target\t";
         if ( ! -e $target ) {
            _status("$target does not exists");
            print $report_fh "- file does not exist\n";
            next;
         }
         my $finfo = stat $target;
         debug(
            sprintf "File is %s, perms is %04o, owner %d, group %d\n",
            $target, $finfo->mode & 07777,
            $finfo->uid, $finfo->gid
         );
         
         print $report_fh "Compliant\n" if ! _test_matching_rules ($self,$rules, $finfo->mode, $finfo->uid, $finfo->gid, $target);
      }
   }
}
sub findfiles {
   my $self = shift;
   my $target=shift;
   my $rules = shift;
   my @names = map { "-name \"$_\" " } @{ $rules->{'name'} };

   my $find = 'find '.$target.' -type f \( '.join("-o ",@names).' \) -exec ls -nd {} \;';
   open CMD,"$find |";
   my $count=0;
   while ( my $line = <CMD> ) {
      my ($file) = $line =~/.*\/(.*)/;
      _write_failures_log($self,"$target Disallowed file \"$file\" found");
      $count++;
   }
   
   close CMD;
   print $report_fh "\t\t\t\t\t*FAIL* $count disallowed files" if $count;
   
}
#==============================================================================
# format failure messages
#==============================================================================
sub fail {
   my $self = shift;          # always get this one
   my $type = shift;
   my $failmsg;
   if ( $type eq "file" ) {
      my $failmsg;
      my ($test,$modestring,$target,$id) = @_;
      if ( $test eq "other" ) {
         $failmsg="Global write bit $modestring set on $target";
      }
      elsif ( $test eq "group") {
         if ( $id ) {
            $failmsg="Server instance id has write access via group $self->{'server_group'} $modestring to $target";
         }
         else {
            $failmsg="Group write bit $modestring set on $target";
         }
      }
      else {
         if ( $id ) {
            $failmsg="Server instance id $self->{'server_user'} has write access $modestring to $target";
         }
         else {
            $failmsg="User write bit $modestring set on $target";
         }
      }
   
      _write_failures_log($self,"$failmsg\n");
   }
   else {
      _write_failures_log($self,"$_[0]\n");
   }
}

#==========================================================
# convert unix permission mode to symbolic representation
#==========================================================
sub _mode_to_symbolic {
   my ($mode)=@_;
   my $mask = "rwxrwxrwx";
   $mode = sprintf("%09b",$mode);
   my $symbolic;
   my $i=0;
   for ( split//,$mode ) {
      if ( $_ == 0 ) {
         $symbolic .= "-";
      }
      else {
         $symbolic .= substr($mask,$i,1);
      }
      $i++;
   }
   return $symbolic;
}

#=================================================================
# write failings items to the log, and console if attached
#=================================================================
sub _write_failures_log {
   my ($self,$line) = @_;
   my $newlog;
   $newlog = 1 if  ! -e $self->{'faillog'};
   $self->{compliant}=0;
   open LOG, ">>", $self->{'faillog'};
   if ( $newlog ) {
      my ( $min,$hour,$day, $month, $year ) = (localtime)[ 1,2,3, 4, 5 ]; 
      printf LOG "Scan date: %4d/%02d/%02d %02d:%02d\n",$year+1900,$month+1,$day,$hour,$min;
   } 
   print LOG "*FAIL* $line";
   close LOG;
   chomp $line;
   print RED, BOLD, "*FAIL* $line\n",CLEAR if -t;         # show on console if tty available
}

#==============================================================
# create a unix find command with the requested permission tests
#==============================================================
sub createfind {
   debug(@_);
   my ( $starting_directory, $tests ) = @_;
   my @conditions;
   my @permcond;
   push @conditions, '\( -type f -o -type d \) ';
   my $perms = $tests->{'perms'};
#   if ( $tests->{'name'} ) {
#      @{ $tests->{'name'} } = map { "-name \"$_\" " } @{ $tests->{'name'} };
#      push @conditions, '\( ' . join( "-o ", @{ $tests->{'name'} } ) . '\)';
#   }
   if ( $perms->{'user'} ) {
      if ( defined $tests->{'uid'} ) {
         push @permcond, sprintf '\( -user %s -perm -%o \)',
           ${ $tests->{'uid'} },
           ( $perms->{'user'} & 07777 );
      }
      else {
         push @permcond, sprintf '\( -perm -%o', ( $perms->{'user'} & 07777 );
      }
   }
   if ( $perms->{'group'} ) {
      if ( defined $tests->{'gid'} ) {
         push @permcond, sprintf '\( -group %s -perm -%o \)',
           ${ $tests->{'gid'} },
           ( $perms->{'group'} & 07777 );
      }
      else {
         push @permcond, sprintf '\( -perm -%o', ( $perms->{'group'} & 07777 );
      }
   }
   if ( $perms->{'other'} ) {
      push @permcond, sprintf '-perm -%o', ( $perms->{'other'} & 07777 );
   }
   if (@permcond) {
      push @conditions, ' \( ' . join( " -o ", @permcond ) . ' \)';
   }
   
   my $find = 'find '
     . $starting_directory . ' '
     . join( '', @conditions )
     . ' -exec ls -nd {} \;';    # find files or directories where
   debug($find);
   return $find;
}

#====================================================================
# Intiate scan of a directory, determine if it is local or gpfs and
# invoke the appropriate routines for each 
#====================================================================
sub scan_directory {
   my ( $self, $directory, $rules ) = @_;
   print $report_fh "\t$directory\t";
   if ( my $gpfs_dir = _is_dir_on_gpfs($directory) ) {    # it is on gpfs
      debug("$directory is on gpfs");
      my $gpfs_str = $gpfs_dir;
      $gpfs_str =~ s/\//_/g;
      my $lockfile = "/fs/scratch/ihs_itcs104/${gpfs_str}.lck";
      
      # if lock file is older than 1 hour delete it and continue
      #
      if ( -e $lockfile ) {
         my $modtime = sprintf "%d\n" ,(time()-((stat($lockfile))->[9]))/60;
         debug("modtime: $modtime");
         if ( $modtime > 60 ) {
            _status('removing $lockfile older than 60mins'); 
            unlink $lockfile;
         }
      }
      debug("lock file: $lockfile");
    
      my $resultsfile = "/fs/scratch/ihs_itcs104/${gpfs_str}.txt";
      # if results file is older than 1 hour delete it and continue
      #
      debug("check age of results file $resultsfile");
      if ( -e $resultsfile ) {
         debug("system time: ".time());
         debug("file time:" .((stat($resultsfile))->[9]));
         my $modtime = sprintf "%d\n" ,(time()-((stat($resultsfile))->[9]))/60;
         debug("modtime: $modtime");
         if ( $modtime > 60 ) {
            _status('removing $resultsfile older than 60mins');
            unlink $resultsfile;
         }
      }
      
      debug("lock file: $resultsfile");
      while ( -e "$lockfile" ) {    # if its locked wait until lock clears
         _status("waiting for scan of $gpfs_dir\n");
         debug("locked ... waiting");
         sleep 60;
      }
      debug("No lock ... proceeding");
      my $find = createfind( $gpfs_dir, $rules );
      if ( -e "$resultsfile" ) {    # does a scan result file exist ?
         debug("Found stored results");
         if ( _results_match_current_server( "$resultsfile", $find ) ) {
            _status("using stored results for $gpfs_dir\n");
            # use the scan result
            use_stored_scan_results( $self, $resultsfile, $rules );
         }
         else {
            debug("Stored results do not match, scanning");

            # go do a scan
            _status("scanning $gpfs_dir\n");
            scan_gpfs_directory( $self, $lockfile, $gpfs_dir, $resultsfile,
               $find, $rules );
            use_stored_scan_results( $self, $resultsfile, $rules );
         }
      }
      else {    # no scan result file
         debug("No Stored results ... scanning");
         _status("scanning $gpfs_dir\n");
         scan_gpfs_directory( $self, $lockfile, $gpfs_dir, $resultsfile, $find,
            $rules );
         use_stored_scan_results( $self, $resultsfile, $rules );
      }
   }
   else {       # not a gpfs dir so go scan it
      my $find = createfind( $directory, $rules );
      _status("scanning $directory\n");
      scan_local_directory( $self, $find, $rules );
   }
}

#=================================================================
# file/dir is on local disk so use find to identify failing
# files and report the result directly.
#=================================================================
sub scan_local_directory {
   my ( $self, $find, $rules ) = @_;
   
   debug("scanning local filesystem");
   my $fail_count = 0;
   open CMD, "$find |";    # perform the scan
   while ( my $line = <CMD> ) {
      chomp $line;
      my ($modestring,$uid,$gid,$target) = (split /\s+/,$line)[0,2,3,-1]; 
      debug("modestring: $modestring uid:$uid gid:$gid target:$target");
      _test_matching_rules($self,$rules,_symbolic_to_mode($modestring),$uid,$gid,$target);
      $fail_count++;
   }
   close CMD;
   if ($fail_count) {
      print $report_fh "*FAIL* $fail_count non-compliant files\n";
   }
   else {
      print $report_fh "Compliant\n";
   }
}

#==================================================================
# check if the file/directory is actually on a gpfs fs
# need to check each level of the full pathname   
#==================================================================
sub _is_dir_on_gpfs {
   debug(@_);
   my ($dir) = @_;
   my $working_dir=realname($dir);
   debug("$dir is really -> $working_dir");
   my @df = `df $working_dir`;
   if ( grep /\/gpfs\//i, @df ) {
      $working_dir =~ s/\/$//g;
      _status("GPFS scan");
      return $working_dir;
   }
   else {
      return undef;
   }
} 

#===================================================================
# make sure the results file is generated using the same criteria
# that this server would use, otherwise do a rescan of the fs
#===================================================================
sub _results_match_current_server {
   debug(@_);
   my ( $resultsfile, $find ) = @_;
   open RESULTS, "<", $resultsfile or die "Cannot read $resultsfile $!\n";
   my $resultfind = <RESULTS>;
   close RESULTS;
   chomp $resultfind;
   if ( $resultfind eq $find ) {
      debug("$resultsfile matches proposed scan using stored result");
      return 1;
   }
   debug("$resultsfile cannot be used");
   return undef;
}

#====================================================================
# Report on failing files found during gpfs fs scan using the
# results file written during the scan
# all servers using the same fs will use the report file rather
# than rescanning the fs
#====================================================================
sub use_stored_scan_results {
   my ( $self, $resultsfile, $rules ) = @_;
   open RESULTS, "<", $resultsfile or die "Cannot read $resultsfile $!\n";
   $_ = <RESULTS>;    # ignore first line
   my $fail_count = 0;
   while (<RESULTS>) {
      my ($modestring,$uid,$gid,$target) = split /\s/,$_;
      _test_matching_rules($self,$rules,_symbolic_to_mode($modestring),$uid,$gid,$target);
      $fail_count++;
   }
   if ($fail_count) {
      # write the summary count of file to the report
      print $report_fh "*FAIL* $fail_count non-compliant files\n";
   }
   else {
      print $report_fh "Compliant\n";
   }
   close RESULTS;
}

#==================================================================
# directory is on gpfs fs, use find to identify non compliant
# files and save them for later reporting by this and any
# other server using the same gpfs fs
#==================================================================
sub scan_gpfs_directory {
   my ( $self, $lockfile, $dir, $resultsfile, $find,$rules ) = @_;
   debug("Locking scan $lockfile");
   # lock the filesystem so other servers wait while we do the scan
   open LOCK, ">", $lockfile or die "Cannot create lock $!";
   print LOCK '';
   close LOCK;
   open RESULTS, ">", $resultsfile or die "Cannot open $resultsfile $!";
   print RESULTS "$find\n";    # save the find command
   open CMD, "$find |";        # perform the scan
 
   while ( my $line = <CMD> ) {
      my ($modestring,$uid,$gid,$target) = (split /\s+/,$line)[0,2,3,-1]; 
      debug("modestring: $modestring uid:$uid gid:$gid target:$target");
      print RESULTS "$modestring $uid $gid $target\n";
   }
   close CMD;
   close RESULTS;
   debug("Unlocking scan $lockfile");
   unlink $lockfile;
}

#===================================================================
# check logging is enabled
#===================================================================
sub logs {
   my $self = shift;
   debug( Dumper( $self->{'log_config'} ) );
   if ( !defined $self->{'log_config'} ) {
      fail($self,"log","No logging configured");
      print $report_fh "*FAIL* no logging configured\n";
      return;
   }
   foreach my $config ( sort keys %{ $self->{'log_config'} } ) {
      print $report_fh "\t$config \n";
      foreach my $vhost ( sort keys %{ $self->{'log_config'}->{$config} } ) {
         print $report_fh "\t  $vhost\n";
         foreach
           my $log ( sort @{ $self->{'log_config'}->{$config}->{$vhost} } )
         {
            print $report_fh "\t\t$log\n";
         }
      }
   }
}

#=================================================================
# Check the OSR default rule definition exists and matches
# this is an optional item
#=================================================================
sub check_default_rule {
   my $self = shift;

   my @def_rule = ("Order Deny,Allow",
               "Deny from all",
               "Options None",
               "AllowOverride None");   
   
   if ( defined $self->default_rule ) {
      print $report_fh "\n\tActual definition\n";
      print $report_fh "\t     <Directory \/>\n";
      debug("default_rule: $self->default_rule\n");
      foreach my $line ( ( split /\n+/, $self->default_rule ) ) {
         my $matched =0;
         debug($line);
         $line = strip($line);
         
         for ( my $i=0; $i<@def_rule;$i++) {
            my $rule_line = strip($def_rule[$i]);
            debug($rule_line);
            if ( $rule_line =~ /$line/i ) {
               printf $report_fh "\t       %-40s matched\n",$line;
               $matched=1;
               last; 
            }        
         }
         if ( ! $matched ) {   
            printf $report_fh "\t       %-40s <-- not in standard definition\n",$line;
         }
      }
   
      print $report_fh "\t     <\/Directory>\n";
   }
   else {
      print $report_fh "\tNo default rule defined\n";
   }
}

#================================================================
# get sws node name 
#================================================================
sub _sws_node_lookup {
   my ($custtag,$host)=@_;
   _status("dirstore lookup $host \"webserver.$custtag.*\"");
   my %results;
   dsConnect(user=>'dsLookup');
   my $rc=dsSearch( %results, "system",
      expList => ["role==webserver.$custtag.*","eihostname==$host"],
      attrs   => ["custtag"]
   );
   if ( keys %results == 0 ) {
      $custtag =~ s/-.*//;
      $rc=dsSearch( %results, "system",
      expList => ["role==webserver.$custtag.*","eihostname==$host"],
      attrs   => ["custtag"]
      );
   }
   dsDisconnect();
   if ( keys %results > 1 ) {
      print $report_fh "resolved to multiple hosts\n";
   }
   elsif ( keys %results == 1 ) {
      _status("SWS hostname for $custtag,$host = ". join(" ",keys %results));
      return (keys %results)[0];
   }
   else {
       _status("Using real hostname $host for $custtag,$host");
      return undef;
   }
}

#=======================================================================
# Find main IHS config files in standard locations
#=======================================================================
sub find_ihs_configs {
   my ($args_ref) = shift;
   # only look for httpd configs if httpd installed
   debug("Check if IHS is installed");
   my @httpd = glob("/usr/HTTPServer*/bin/httpd /usr/sbin/httpd* /usr/WebSphere*/HTTPServer/bin/httpd");
   return() if ! @httpd;
   debug("it is");
   # use glob to search for configs in standard locations
   my @configs = glob("/projects/*/conf/*.conf /usr/HTTPServer*/conf/*.conf /usr/WebSphere*/HTTPServer/conf/*.conf");
   @configs=grep {!/(?:listen|            # config file names to ignore
      rewrites|
      graphite-vhost|
      kht|
      httpd_mobile|
      mapfile|
      mod_|
      HTDig|
      default|
      errors|
      server-tuning|
      ssl-|
      uid|
      admin|
      old\.|
      \.old
      )/ix} @configs; 

   # If passed any parms use them to filter the configs to scan
   # so we can scan individual instances on stacked nodes.
   if ( @{$args_ref } ) {
      my $confstring_re = "(?:".join("|",@{$args_ref}).")" if @{$args_ref};
      @configs=grep { /$confstring_re/isxm} @configs;
   }

   my %configs;
   # drop duplicates
   # 1nd pass to resolve symlinked configs to actual filename   
   %configs = map { realname($_) => undef } @configs;
   # 2nd pass to resolve symlinked configs that are on gpfs 
   my %configs1 = map { realname($_) => undef } keys %configs;
   return sort keys %configs1;   
}

#=================================================================
# Compare file mode/uid/gid against required itcs rules
#=================================================================
sub _test_matching_rules {
   my ( $self, $rules, $mode, $uid, $gid, $target ) = @_;
   debug("testing rules for $target");
   my $perms = $rules->{'perms'};
   my $fail = 0;
   foreach my $test ( keys %{$perms} ) {
      if ( ( $mode & $perms->{$test} ) == $perms->{$test} ) {    # matched one of the perm rules
         if ( $test eq "user" ) {
            debug( " user test uid:$uid mode:" . sprintf( "%09b", $perms->{$test} ) );
            if ( defined $rules->{'uid'} ) {
               if ( ${ $rules->{'uid'} } == $uid ) {
                  fail( $self, "file", $test,_mode_to_symbolic( $perms->{$test}), $target , $uid );
                  $fail=1;
               }
            }
            else {
               fail( $self, "file", $test,_mode_to_symbolic( $perms->{$test}), $target );
               $fail=1;
            }
         }
         elsif ( $test eq "group" ) {
            debug( "group test " . sprintf( "%09b", $perms->{$test} ) );
            if ( $rules->{'gid'} ) {
               if ( ${ $rules->{'gid'} } == $gid ) {
                  fail( $self, "file", $test,_mode_to_symbolic( $perms->{$test}), $target, $gid );
                  $fail=1;                  
               }
            }
            else {
               fail( $self, "file", $test,_mode_to_symbolic( $perms->{$test}), $target );
               $fail=1;
            }
         }
         elsif ( $test eq "other" ) {
            fail( $self, "file", $test,_mode_to_symbolic( $perms->{$test}), $target);
            $fail=1;
         }
      }
   }
   return $fail;
}

#=======================================================
# convert unix symbolic permissions to numeric 
#=======================================================
sub _symbolic_to_mode {
   my ($symbolic) = @_;
   my $mode;
   for ( split //, $symbolic ) {
      if ( $_ ne "-" && $_ ne "S" ) {
         $mode .= '1';
      }
      else {
         $mode .= '0';
      }
   }
   return unpack( "N", pack( "B32", substr( "0" x 32 . $mode, -32 ) ) );
}
1;
