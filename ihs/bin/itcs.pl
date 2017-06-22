#!/usr/bin/perl -w

#!/usr/local/bin/perl -w
use strict;
use Data::Dumper;
use Getopt::Std;
use Sys::Hostname;
if ( ! -f '/usr/HTTPServer/bin/httpd' ) {				# script sent to all servers, only interested in IHS ones
 	warn "IHS not installed\n";
	exit;
}


# define accepted user/groups here
my $ihsuser					= 'webinst';
my @web_admin_groups		= qw(eiadm);
my @web_authors_groups	= qw(eiadm apps icadmin);
my @web_dev_groups		= qw(eiadm apps staff);
my @banned_list = qw( pfh test-cgi nph-test-cgi post-query uptime upload wais.pl Sh bash csh ksh tsh tclsh wish perl);

my $debug=0;
my $verbose=0;
my $summary=0;

my %opts;
getopts('dvs',\%opts);

$debug=1 if defined $opts{d};
$verbose=1 if defined $opts{v};
$summary=1 if defined $opts{s};



my $depth = 0;
my $master_config = '/usr/HTTPServer/conf/httpd.conf';
my @httpconfig = read_http_config();
my $hostname=hostname();

my $os = `uname -a`;
my @groups;
my @users;
#--------------------------------------------------------------------------------------------------
# Build array of groups
#--------------------------------------------------------------------------------------------------
if ( $os =~ /linux/i ) {
   while( my ($name,$p,$gid,$members) = getgrent() ){
		$members =~ s/ /,/g;
		push @groups, "$name id=$gid users=$members ";
	}
}
else {
	@groups=`lsgroup ALL`;
}

my @ihs_groups = map { word($_,1) } grep(/$ihsuser/,@groups);      # find groups web server userid is member 

# translate user/group names to uid/gid and save for later use
# owner					
my %group;
my %group_id;

foreach my $group ( @groups ) {
	$group =~ /^(\S+?) id=(\d{1,5}).+?users=(.+?)\s/;
	my $gid = $2;
	$group = $1;
	my $users = $3;
	if ( $gid ) {
		$group{$gid}{name}=$group;
		$group{$gid}{members}= $users;
		$group_id{$group}= $gid;
	}
}

my $ihs_user_uid = getpwnam($ihsuser);
my $ihs_group_gids = name_to_gid(@ihs_groups);
my $web_admin_group_gids =name_to_gid(@web_admin_groups);
my $web_authors_group_gids = name_to_gid(@web_authors_groups);
my $web_dev_group_gids = name_to_gid(@web_dev_groups);


#-------------------------------------------------------------------------------------------
#
# Report server ITSC104 compliance status
#
#-------------------------------------------------------------------------------------------
	s1_1();           # OS root user check
	s1_2();           # Document root user check
	s1_3();           # Cgi user check
	s1_4();           # IHS process owner
	s1_5();           # Anonymous users
	s4_1();           # Encryption
	s5_1();           # server root access rights
	s5_2();           # document root access rights
	s5_4();           # autoindex
	s5_5();           # cgi dirs access rights
	s5_6();           # OSR's
	s6_1();           # Logging

#-------------------------------------------------------------------------------------------
# 1.1 - Users with OS root authority
# Check /etc/sudoers setup correctly
#-------------------------------------------------------------------------------------------
sub s1_1 {
   open(FILE_HANDLE,'/etc/sudoers') ||  return; 
   my @sudolist=<FILE_HANDLE>;                     # Read sudo list
   close(FILE_HANDLE);
   @sudolist=grep(/^%/,@sudolist);
   foreach my $sudoer ( @sudolist ) {             #
      $sudoer=~/%(.+?)\b/;                         # only lines starting %
      $sudoer=$1;
      if ( defined $group_id{$sudoer} ) {			# found the group
			my $gid = $group_id{$sudoer};
         if ( ! grep(/$sudoer/,@web_admin_groups) ) { # name not in approved web_admins list
           report("bad, $sudoer=$group{$gid}{members}");
         }
         else {
           report("ok, $sudoer=$group{$gid}{members}");
         }
      }
   }
}
#--------------------------------------------------------------------------------------
# 1.2 Check who has access to document root directories
#-------------------------------------------------------------------------------------------
sub s1_2 {
   my @dirs = get_cfg_lines('documentroot');
   @dirs = map { word($_,2) } @dirs;                  # extract just the directory name
   my %dirs   = map { $_, 1 } @dirs;                  # Drop duplicates
   @dirs =  keys %dirs;                               # rebuild array with unique names
   dir_access_rights(@dirs);
}

#--------------------------------------------------------------------------------------
# 1.3 Check who has access to cgi root directories
#-------------------------------------------------------------------------------------------
sub s1_3 {
   my %dirs = get_cgi_dirs();
   my @dirs =  keys %dirs;
   dir_access_rights(@dirs);
}

#--------------------------------------------------------------------------------------
# 1.4 Check http runs as webinst
#-------------------------------------------------------------------------------------------
sub s1_4 {
   ($ihsuser)= (get_cfg_lines('user'))[0];
   $ihsuser = word($ihsuser,2);
   report($ihsuser);
   my @procs=`ps -ef | grep httpd | grep -v grep`;
   my %proc_count;
   foreach my $line (@procs) {
      $line=~s/^\s+//;
      my @lines=split(/\s+/,$line);
      $proc_count{$lines[0]}++;
   }
   my $msg = "HTTPD process counts:";
   foreach my $proc (keys %proc_count) {
      $msg .= $proc.":".$proc_count{$proc}."\t";
   }
   report($msg);
}

#--------------------------------------------------------------------------------------
# 1.5 Anonymous users
#-------------------------------------------------------------------------------------------
sub s1_5 {                       # Dont know how to handle this one yet
}

#--------------------------------------------------------------------------------------
# 4.1 Encryption
#-------------------------------------------------------------------------------------------
sub s4_1 {
   my $keyfile='';
   foreach my $line ( get_cfg_lines('keyfile') ) {
      if ( $line=~/keyfile/i ) {
         $keyfile=word($line,2);
         last;
      }
   }
   if ( $keyfile ) {
      report("Keyfile:$keyfile, ".list_certs($keyfile) ) ;
   }
   else {
      report("No keyfile");
   }
   my @vhost=get_cfg_lines('<virtualhost.+?:443','sslenable','SSLservercert');
   for ( my $i=0; $i<@vhost; $i++ ) {
      if ( $vhost[$i] !~ /:443/ ) { next; }
      if ( $vhost[$i] =~ /virtualhost/i ) {
         my $msg = $vhost[$i].' ';
         if ($vhost[$i+1] !~ /sslenable/i ) {
            $msg .= "not ";
         }
         $msg .= "SSLEnabled";
         report($msg);
      }
      if ( $vhost[$i] =~ /SSLservercert/i ) {
         report("SSLcert ".$vhost[$i]);
      }
   }
}

#--------------------------------------------------------------------------------------
# 5.1 Check serverroot owned by web admin group
#-------------------------------------------------------------------------------------------
sub s5_1 {
	warn "s5_1 started\n" if $debug;
	my $directory = (get_cfg_lines('serverroot'))[0];

   if ($directory) {                                # if we have one
		$directory = word($directory,2);
		warn "serverroot = $directory\n" if $debug;
		my @excludes;
		
		if ( ! grep(/documentroot.+?\/htdocs/i,@httpconfig) ) {		# if htdocs not a docroot exclude it
			push @excludes, "/htdocs";
		}
		
		my %parms = ( file => $directory,			# Initialise rules 
			group => $web_admin_group_gids,			# check files owned by admin groups
			other_rights => "r.x",						# disallow global write access
#			group_rights => "rw.",						# #
			exclude => (@excludes)
				);					
		my @results = validate_rights(%parms);
		report($directory . " " . join(",",@results));
   }
   else {
      report("No serverroot!");
   }
}


#--------------------------------------------------------------------------------------
# 5.2 Check access to document root directories
#-------------------------------------------------------------------------------------------
sub s5_2 {
	warn "s5_2 started\n" if $debug;
   my @doc_roots=get_cfg_lines('documentroot');    # get list of document root directories
	
   @doc_roots= map {cleanup(word($_,2))} @doc_roots;        # drop duplicates
   my %doc_roots = map {$_,1} @doc_roots;
   @doc_roots= keys(%doc_roots);
	
	my %parms = (          									# Initialise rules 
			group => $web_authors_group_gids,	 		# check files owned by web_authors groups
			other_rights => "r.x",							# 
			deny_group => [$ihs_group_gids,"r.x"],		# ihs groups cannot have +w
			deny_user => [$ihs_user_uid,"r.x"],			# webuser cannot have +w
			);
		
	
   foreach my $directory ( @doc_roots) {          # check each document root
		$parms{file} = $directory;
		warn "s5_2\t" . Dumper(\%parms) if $debug;	
		my @results = validate_rights(%parms);
		report($directory . " " . join(",",@results));
   }
}

#--------------------------------------------------------------------------------------
# 5.5 Check cgi directory right
#----------------------------------------------------------------------------------------------------------
sub s5_5 {
   my %dirs = get_cgi_dirs();
	
		my %parms = ( group => $web_dev_group_gids, 
							banned => [@banned_list],
						);	
			
   foreach my $directory ( keys %dirs ) {
		$parms{file} = $directory;
		warn "s5_2\t" . Dumper(\%parms) if $debug;	
		my @results = validate_rights(%parms);
		report($directory . " " . join(",",@results));
   }
}

#--------------------------------------------------------------------------------------
# 5.4 Directories with autoindex
#----------------------------------------------------------------------------------------------------------
sub s5_4 {
   my @cfg = get_cfg_lines('<directory','.*\sautoindex\s');
   my $lastline;
   foreach my $line (@cfg) {
      if ( $line =~ /\sautoindex\s/i ) {
         if ( $lastline =~ /directory/i ) {
            report("$lastline is autoindexed");
         }
         else {
            report("Error: autoindex outside directory");
         }
      }
      $lastline = $line;
   }
}

#--------------------------------------------------------------------------------------
# 5.6 OSR's
#----------------------------------------------------------------------------------------------------------
sub s5_6 {
	my $serverroot = (get_cfg_lines('serverroot'))[0];
	$serverroot = word($serverroot,2);
	my @dirs =qw  (bin modules conf logs);
	
	foreach my $directory ( @dirs ) {
		$directory = $serverroot . "/" . $directory;
		my %parms = ( file => $directory,
					other_rights => "r.x" );
		my @results	= validate_rights(%parms);
		report($directory . " " . join(",",@results));
	}
	
}

#--------------------------------------------------------------------------------------
# 6.1 Check logging
#----------------------------------------------------------------------------------------------------------
sub s6_1 {
   my @cfg=get_cfg_lines('customlog','transferlog');
   @cfg= map{ report($_) } @cfg;
}

#*************************************************************************************
# Check directory right
#*************************************************************************************
sub validate_rights {
	my (%parms) = @_;
	warn "validate rights:\n" if $debug;
	if ( $depth > 2 ) { 
		warn "limiting depth\n" if $debug;
		return;
	}							# dont check too deep ! 
		
	# cleanup the directory format
	my $directory = cleanup($parms{file});				# Get nice clean directory name
		
	my @bad_counts=(0,0,0,0,0,0,0);
   my @list;
   if ( -f $directory ) {        		            # were we passed a file rather than a directory
      warn "$directory is a file\n" if $debug;
      push @list,$directory;
   }
   else {
      warn "doing directory list of $directory/*\n" if $debug;
      @list=glob($directory."/*");                 # get list of files in directory
      warn scalar(@list)." entries returned\n" if $debug;
   }

	foreach my $file ( @list ) {
		$parms{file} = $file;								# save it for subsequent subs
		#---------------------------------------------------
		# Directory checking
		#---------------------------------------------------
		if ( -d $file ) {										# its a directory
			my $excluded;
			# should we exclude this directory from the checks ?
			if ( exists $parms{exclude} ) {
				foreach my $exclude ( $parms{exclude} ) {
					if ( $file =~ /$exclude/i ) { 
						$excluded=1;
						warn "Excluding $file\n" if $debug;
						last;
					}
				}
			}	
	
			if ( ! $excluded ) {
				$depth++;										# increase offset from the root directory
				warn "found directory $file depth = $depth\n" if $debug;
					my @results = check_settings(%parms);
				for ( my $i=0; $i<@results; $i++ ) {
					$bad_counts[$i] += $results[$i];		# add returned values to counts
				}
				@results = validate_rights(%parms);		# descend into the directory
				for ( my $i=0; $i<@results; $i++ ) {
					$bad_counts[$i] += $results[$i];		# add returned values to counts
				}
				$depth--;
			}
		}
		
		#---------------------------------------------------
		# File checking
		#---------------------------------------------------
		if ( -f $file ) {
			warn "found file $file\n" if $debug;
			my @results = check_settings( %parms );
			for ( my $i=0; $i<@results; $i++ ) {
				$bad_counts[$i] += $results[$i];			# add returned values to counts
			}
		}
	}
	warn "exit value from validate_rights\t$directory has " . join(',',@bad_counts). " errors\n" if $debug;
	report ("$directory," . join(',',@bad_counts) ) if $summary;
	return @bad_counts;
}

#***********************************************************************************************************
# This is what does all the hard work
#***********************************************************************************************************
sub check_settings {
	
	my ( %parms ) = @_;
	warn "check_settings \n" if $debug;
	warn Dumper(\%parms) if $debug;
	my $file = $parms{file};
	my @bad_counts;
	
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
	
	my $invalid=0;
	my $file_rights = sprintf("%03o", $mode & 07777);
	$file_rights = substr($file_rights,length($file_rights)-3);
	my $owner_rights = substr($file_rights,0,1);
	my $group_rights = substr($file_rights,1,1);
	my $other_rights = substr($file_rights,2,1);
	warn "\tDetected rights are $file_rights\t$owner_rights\t$group_rights\t$other_rights\n" if $debug;
	
	if ( exists $parms{owner} ) {
	#---------------------------------------------
	# Check owner values
	#---------------------------------------------
		warn "\tchecking owner is ", $parms{owner},"\n" if $debug;
		my $user=getpwuid $uid;
		if ( $parms{owner} !~ /\s?${user}\s/i ) {						# owner is not in the valid list
			warn "\t\t$file invalid owner $user uid $uid\n" if $debug;
			report ("invalid owner $user $file, accepted users:" . $parms{owner}) if $verbose;
			push @bad_counts, 1;
		}
		else {
			push @bad_counts, 0;
		}
	}
	else {
		warn "\tBypassing owner check\n" if $debug;
		push @bad_counts, 0;
	}
	#check owner rights
	if ( exists $parms{owner_rights} ) {
		push @bad_counts, rights_check($parms{owner_rights}, $owner_rights, "Owner_rights",\$invalid)
	}
	else {
		warn "\tskipping owner rights check\n" if $debug;
		push @bad_counts, 0;
	}
	
	
	#---------------------------------------------
	# Check group values
	#---------------------------------------------
	if ( exists $parms{group} ) {
		warn "\tchecking group is ", $parms{group},"\n" if $debug;
		if ( $parms{group} !~ /\s?${gid}\b/i ) {						# is owner in 
			warn "\t\t$file invalid group ".gid_to_name($gid)." gid $gid\n" if $debug;
			report ("invalid group $group{$gid}{name} $file, accepted groups: ".gid_to_name($parms{group}) ) if $verbose;
			push @bad_counts, 1;
		}
		else {
			push @bad_counts, 0;
		}
	}
	else {
		warn "\tBypassing group check\n" if $debug;
		push @bad_counts, 0;
	}
	#---------------------------------------------
	# Check group_rights values
	#---------------------------------------------
	if ( exists $parms{group_rights} ) {
		push @bad_counts, rights_check($parms{group_rights}, $group_rights, "Group_rights",\$invalid)
	}
	else {
		warn "\tBypassing group_rights check\n" if $debug;
		push @bad_counts, 0;
	}
	
	#---------------------------------------------
	# Check other values
	#---------------------------------------------
	if ( exists $parms{other_rights} ) {
		push @bad_counts, rights_check($parms{other_rights}, $other_rights, "Other_rights",\$invalid)
	}
	else {
		warn "Bypassing other check\n" if $debug;
		push @bad_counts,0;
	}
	
	#----------------------------------------------
	# Check for alternate user/group rights
	#----------------------------------------------
	if ( exists $parms{deny_user} || exists $parms{deny_group}  ) {
	# check user or group does not have specific rights
	# if deny_user = owner & owner has denied right 
		my $error = 0;
		my $invalid;
		if ( $parms{deny_user}[0] == $uid ) {
			warn "deny user $parms{deny_user}[0] matched $uid\n" if $debug;
			$error += rights_check($parms{deny_user}[1], $owner_rights,"Deny_user",\$invalid) ;
		}
		if ( $parms{deny_group}[0] =~ /\b$gid\s/ ) {
			warn "deny group $parms{deny_group}[0] matched $gid\n" if $debug;
			$error += rights_check($parms{deny_user}[1], $group_rights,"Deny_group",\$invalid);
		}
		if ( $error ) 	{ 
			report("User has excessive rights $file") if $verbose;
			push @bad_counts,1;
		}
		else {
			push @bad_counts,0;
		}
	}
	else {
		warn "Bypassing deny checks\n" if $debug;
		push @bad_counts,0;
	}
	
	if ( defined $parms{banned} ) {					
		my $banned=0;
		foreach my $type ( $parms{banned} ) {
			if ( $file =~/$type/i ) {				# is file on the banned list 
				warn "$file contains banned string $type\n" if $verbose;
				$banned =1 ;
				last;
			}
		}
		if ( $banned ) {
			push @bad_counts,1;
		}
		else {
			push @bad_counts,0;
		}
	}
	else {
		warn "Bypassing banned files checks\n" if $debug;
		push @bad_counts,0;
	}
		
	if ( $invalid && $verbose  ) {
		report("Invalid rights $file_rights, $file");
	}
	return @bad_counts;
}

#*********************************************************************************************
# 
#*********************************************************************************************
sub rights_check {
	my ($check_rights, $file_rights, $type, $invalid_ref ) = @_;
		warn "\tchecking $type are $check_rights\n" if $debug;
		# convert other rights to octal
		my $octal = octal($check_rights);
		
		if ( $file_rights & $octal ) {
			warn "\t\t$type found ". dec2bin($file_rights) ."\tdisallowed " . dec2bin($octal). "\n" if $debug;
			$$invalid_ref=1;
			return 1;
		}
		else {
			return 0;
		}
}

sub octal {
	my ($mode) = @_;
	my $octal = 0;
	$octal  = mode(substr($mode,0,1)) * 4;
	$octal += mode(substr($mode,1,1)) * 2;
	$octal += mode(substr($mode,2,1));
	return $octal;
}

sub mode {
	my ($mode) = @_;
	if ( $mode eq "." ) {return 1;}
	return 0;
}
#--------------------------------------------------------------------------------------
# Convert uid to username
#----------------------------------------------------------------------------------------------------------
sub lookup_uid {
	my ($uid) = @_;
	return getpwuid $uid;
}
#--------------------------------------------------------------------------------------
# Subroutine to read http config into an array
#----------------------------------------------------------------------------------------------------------
sub read_http_config {
   open(FILE_HANDLE, $master_config) ||  return ;
   @httpconfig =  <FILE_HANDLE> ;
   close(FILE_HANDLE);
   my @includes = grep(/^\s*?include/i,@httpconfig);
	foreach my $inc ( @includes ) {
		$inc = word($inc,2);
		if ( -f $inc ) {
	   	open(FILE_HANDLE, $inc) ;
			my @inc_data = <FILE_HANDLE>;
			close(FILE_HANDLE);
			@httpconfig = (@httpconfig, @inc_data );
		}
	}	
	return @httpconfig;
}

#----------------------------------------------------------------------------------------------------------
# Subroutine to extract requested config line
#----------------------------------------------------------------------------------------------------------
sub get_cfg_lines {
   my (@regexp)=@_;
   my $regexp='';
   foreach my $exp (@regexp) {
      $regexp = $regexp . "^\\s*?$exp|";
   }
   chop($regexp);
   my @cfglines = grep(/$regexp/i,@httpconfig);
   chomp(@cfglines);
   return @cfglines;
}

#----------------------------------------------------------------------------------------------------------
# Subroutine to return a specified word from a string
#----------------------------------------------------------------------------------------------------------
sub word {
   my ($string,$word)=@_;
   $string=~s/^\s+|\s+$//;
   my @words=split(/\s+/,$string);
	$words[$word-1] =~s/^[\<\s\"\']+//;
	$words[$word-1]=~s/[\>\s\"\']+$//;
   return $words[$word-1];
}


sub report {
   my ($msg) = @_;
   my $section=itcs_section_name();
   print "ITCS, $hostname, $section, $msg\n"
}

sub itcs_section_name {
	my $section;
	my $i=0;
   while (   my $me = ( caller($i) )[3]  ) {
      $section= $me;
      $i++;
   }
   $section=~/::(.*)/;
   return $1;
} 

#Remove extraneoius chars from around directory name <>"
sub cleanup {
	my ($directory) = @_;
	$directory =~ s/^[\<\s\"\']+//;                     # strip any enclosing quotes etc
	$directory =~ s/[\>\s\"\'\\]+$//;
	$directory =~ s/ /\\ /g;                                     # escape spaces
	return $directory;
}

sub dec2bin {
    my $str = unpack("B32", pack("N", shift));
    $str =~ s/^0+(?=\d)//;   # otherwise you'll get leading zeros
    return sprintf("%03d",$str);
}


#******************************************************************
# Translate array of group names to string of matching gids
#******************************************************************
sub name_to_gid {
	my (@groups) = @_;
	my $ids="";
	foreach my $group ( @groups ) {			# create string of valid gids
		warn "\tlooking up $group\n" if $debug;
		if ( defined $group_id{$group} ) {
			warn "\t\tfound it as $group_id{$group}\n" if $debug;
			$ids .= $group_id{$group} . " ";
		}
	}
	return $ids;
}

#******************************************************************
# Translate string of gids to string of matching group names
#******************************************************************
sub gid_to_name {
	my ($groups) = @_;
	my $names="";
	foreach my $gid ( split(/ /,$groups) ) {
		if ( defined $group{$gid} ) {
			$names .= $group{$gid}{name} . " ";
		}
		else {
			$names .= "gid=$gid ";
		}
	}
	return $names;
}

#----------------------------------------------------------------------------------------------------------
#  lookup users with write access to directory
#----------------------------------------------------------------------------------------------------------
sub dir_access_rights {
   my (@dirs) = @_;
   foreach my $dir ( @dirs) {
      if ( -d $dir ) {                    # check directory exists
         my $msg="$dir, ";
         my $mode = (stat($dir))[2];
         if ( $mode & 0200 ) {               # owner has write access
            my $uid = (stat($dir))[4];
            my $user = getpwuid $uid;
            $msg .= "$user:";
         }

         my $gid = (stat($dir))[5];
         if ( $mode & 020 ) {                # group has write access
            $msg .= "$group{$gid}{name}=$group{$gid}{members}";
         }
         report($msg);
      }
      else {
         warn "$dir does not exist\n";
      }
   }
}

#--------------------------------------------------------------------------------------
# Subroutine to get cgi dir information
#-------------------------------------------------------------------------------------------
sub get_cgi_dirs {
   my @dirs = get_cfg_lines('<directory','option.+?execcgi','scriptalias','addhandler');   # get dir and options lineS
   my $lastline;
   my $saved_dir;
   my %cgi_dirs;
   my $filetypes ='';
   my $keyword;
   foreach my $line (@dirs) {       # keep directories followed by options
      $keyword=word($line,1);
      if ($keyword =~/directory/i) {
         $saved_dir = word($line,2);              # save the directory
      }
      if ( $keyword =~ /option/i ) {
         if ( $lastline!~/option/i ) {             # ignore duplicate option lines
            $cgi_dirs{$saved_dir}=$filetypes;
         }
      }
      if ( $keyword =~/scriptalias/i ) {
         # do check on directory ... word 3 i all files
         my $dir=word($line,3);
         $cgi_dirs{$dir}=['*'];
      }
      if ( $keyword =~ /addhandler/i ) {
        $filetypes .=word($line,3)." ";       # save the filetype
      }
      $lastline = $line;
   }
   return %cgi_dirs;
}

#----------------------------------------------------------------------------------------------------------
#i Get CMS cert db information
#----------------------------------------------------------------------------------------------------------
sub list_certs {
   my ($keydb) = @_;
   my $certinfo;
   my $stash = $keydb;
   $stash =~ s/.kdb$/.sth/;
   my $stash_pw = dstash($stash);
	if ( ! $stash_pw ) {
		warn "no stashed password\n" if $debug;
		return "unable to open";
	}
   my $java_version = `java -version 2>&1 | grep version | cut -d" " -f3`;
   if ( $java_version !~ /1.4/ ) {
      $java_version = "JAVA_HOME=/usr/java14 "
   }
   else {
      $java_version = '';
   }

  my @certs = `$java_version gsk7cmd -cert -list personal -db $keydb -pw $stash_pw`;
   if ( grep(/No key was found/i,@certs) ) {
      return "No key was found in the key database.";
   }
  my @cert_list = grep(/^\s+?\w/,@certs);
   if ( @cert_list ) {
      foreach my $cert (@cert_list) {
         $cert =~ s/^\s+|\s+$//;
         $cert=~s/ /\\ /g;
         my @certinfo = `$java_version gsk7cmd -cert -details -db $keydb -pw $stash_pw -label $cert`;
         @certinfo = grep(/issued by|label/i,@certinfo);
         chomp(@certinfo);
         $certinfo .= join(", ",@certinfo) .",";
      }
      $certinfo=~s/,$//;
      return $certinfo;
   }
   else {
      return 'Unable to open';
   }
}

#----------------------------------------------------------------------------------------------------------
# Decrypt stashed password
#----------------------------------------------------------------------------------------------------------
sub dstash {
   my ($file) = @_;
   my $pw ='';
   open(F,$file) || return "";
   my $stash;
   read F,$stash,1024;
   my @unstash=map { $_^0xf5 } unpack("C*",$stash);
   foreach my $c (@unstash) {
      last if $c eq 0;
      $pw=$pw.sprintf "%c",$c;
   }
   return $pw;
}

