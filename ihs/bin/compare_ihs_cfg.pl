#!/usr/local/bin/perl-current -w
use strict;
use Data::Dumper;
use List::Util qw[min max];
use Expect;

my $user;
if ( $ENV{'SUDO_USER'} ) {
	$user=$ENV{'SUDO_USER'}
}
else {
	$user=$ENV{'USER'}
}


my $debug=$ENV{'debug'};
if ( ! $debug ) { $debug=0; }

my %compares = ( 'roles' => [],
			'servers' => [],
			'vhosts' => []
);

my ($file1,$file2);
my %password;
my $line_length=63;

#------------------------------------------------------------------------------
# Get commandline args
#------------------------------------------------------------------------------
while ( $#ARGV >= 0 ) {
	my $arg = shift @ARGV;
	if ( $arg =~ /webserver./i ) {
		push @{$compares{'roles'}},$arg;
	}
	elsif ( $arg =~ /^width=(\d+)/i ) {
		$line_length=min($1,256);
	}
	elsif ( $arg =~ /^[a,d,g,v,w]\w?\d{4,5}/i ) {
		push @{$compares{'servers'}},$arg;
	}
	elsif ( $arg =~ /\w{5,6}/) {
		push @{$compares{'vhosts'}},$arg;
	}
	else {
		print STDERR "Invalid argument $arg\n";
	}
}

#------------------------------------------------------------------------------
# Make sure we have pairs of roles or servers defined
#------------------------------------------------------------------------------
if ( @{$compares{'roles'}} % 2 ) {
	my $err = pop(@{$compares{'roles'}});
	print STDERR "Odd number of roles specified, last role $err will be ignored\n";
}
if ( @{$compares{'servers'}} % 2 ) {
	my $err = pop(@{$compares{'servers'}});
	print STDERR "Odd number of servers specified, last server $err will be ignored\n";
}
#------------------------------------------------------------------------------
# Do compares of roles
#------------------------------------------------------------------------------
warn Dumper(\%compares) if $debug;
while ( @{$compares{'roles'}} ) {
	$file1=shift(@{$compares{'roles'}});
	my @file = split(/\./,$file1);
	my $custtag1=$file[scalar @file -1];
	my $env = substr($custtag1,2,3);
	$file1 = "/fs/projects/$env/$custtag1";
	$file2=shift(@{$compares{'roles'}});
	@file = split(/\./,$file2);
	my $custtag2=$file[scalar @file -1];
	$env = substr($custtag2,2,3);
	$file2 = "/fs/projects/$env/$custtag2";
	
	for my $vhost (@{$compares{'vhosts'}}) {
	 
	   my ($local_vhost,$remote_vhost)=split(/\[/,$vhost);
	
	   if ( ! $remote_vhost ) {
	      $remote_vhost=$local_vhost;
	   }
	   else {
	     $remote_vhost=~s/\]//;   
	   } 
	   
	   my $report = "${local_vhost}_${custtag1}_${custtag2}.txt";
		unlink($report);
		open REPORT,">$report" or die "Unable to open $report $!\n";
		print REPORT "=" x 60 . "\n|\tComparing $local_vhost on $custtag1 vs $remote_vhost $custtag2\n". "=" x 60 . "\n\n";
		if ( $vhost =~/httpd/i ) {
			$local_vhost="HTTPServer/conf/httpd.conf";
			$remote_vhost="HTTPServer/conf/httpd.conf";
		}
		else {
			$local_vhost="$local_vhost/config/$local_vhost.conf";
			$remote_vhost="$remote_vhost/config/$remote_vhost.conf";
		}
		print "Comparing $custtag1/$local_vhost against $custtag2/$remote_vhost\n";
		do_compare("$file1/$local_vhost","$file2/$remote_vhost");
		print "\n$report generated\n\n";	
		close REPORT;	  
	}
}

#------------------------------------------------------------------------------
# Do compares of servers
# get local_copy of file from each server
#------------------------------------------------------------------------------
warn Dumper(\%compares) if $debug;
while ( @{$compares{'servers'}} ) {
	my $server1=shift(@{$compares{'servers'}});
	my $server2=shift(@{$compares{'servers'}});
	for my $vhost (@{$compares{'vhosts'}}) {
	   my ($local_vhost,$remote_vhost)=split(/\[/,$vhost);
	   if ( ! $remote_vhost ) {
         $remote_vhost=$local_vhost;
      }
      else {
        $remote_vhost=~s/\]//;   
      }
      
		warn "vhost=$local_vhost / $remote_vhost\n" if $debug;
		local_copy($server1,$local_vhost);
		local_copy($server2,$remote_vhost);
		my $report = "${vhost}_${server1}_${server2}.txt";
		unlink($report);
		open REPORT,">$report" or die "Unable to open $report $!\n";
		print REPORT "=" x 60 . "\n|\tComparing $local_vhost on $server1 vs $remote_vhost $server2\n". "=" x 60 . "\n\n";
		do_compare("/tmp/${server1}_${local_vhost}.conf", "/tmp/${server2}_${remote_vhost}.conf");
		print "\n$report generated\n\n";
		close REPORT;
		unlink("/tmp/${server1}_${local_vhost}.conf");
		unlink("/tmp/${server2}_${remote_vhost}.conf");  
	}
}

#------------------------------------------------------------------------------
# The main comparing routine
# does a diff on the files and then updates 1st file to show a side by side
# view of the differences, linux diff -y does this but AIX diff doesnt support
# the -y option :-(
#------------------------------------------------------------------------------
sub do_compare {
	my ($file1,$file2) =@_;
	debug() if $debug;
	# parms 2 file names
	
	my @file1 = readfile("$file1");
	
	for ( my $file_line=0;$file_line<@file1;$file_line++ ) {
		my $line = $file1[$file_line];
		chomp($line);
		$line =~ s/\t/   /g;							# convert tabs to 3 spaces
		$file1[$file_line]=pack("A$line_length",$line). "  ";
	}
	
	my @diff = `diff -iwt $file1 $file2`;
	
	for ( my $diff_line=0;$diff_line<@diff;$diff_line++ ) {
		if ( $diff[$diff_line] =~ /^\d/ ) {				# parse the instruction
			my ( $f1_start,$f1_end,$action,$f2_start,$f2_end);
			my $diff_linenst = $diff[$diff_line];
			print STDERR "Inst = $diff_linenst\n" if $debug >1;
			$diff_linenst =~ /^(\d+),?(\d+)?([a,c,d])(\d+)?,?(\d+)?/;		# get the instaction components
			$f1_start = $1 -1;
			if ( ! defined $2 ) { $f1_end = $f1_start; }
			else { $f1_end = $2 -1 }
			$action	 = $3;
			$f2_start = $4 - 1;
			if ( ! defined $5 ) { $f2_end = $f2_start; }
			else { $f2_end = $5 -1 }
			
			print STDERR "f1_start $f1_start f1_end $f1_end action $action f2_start $f2_start f2_end $f2_end\n" if $debug >1;
			#==========================================================================================
			#  Add action
			#==========================================================================================		
			if ( $action eq "a" ) {
				print STDERR "Adding $diff_linenst\n" if $debug >1;
				$diff_line = $diff_line + 1;		# skip the instruction
				my $file_line=$f1_start;
				$file1[$file_line] = [$file1[$file_line]];
				my $max = $f2_end-$f2_start+1;
				while ( $max > 0 ) {
					chomp $diff[$diff_line];
					push @{$file1[$file_line]}, pack("A$line_length"," ")." ". pack("A$line_length",$diff[$diff_line]);
					$diff_line++;
					$max--;
				}			
				$diff_line--;	
			}
	
			#==========================================================================================
			#  Change action
			#==========================================================================================
			elsif ( $action eq "c" ) {
				print STDERR "changing $diff_linenst \n" if $debug >1;
		
				my $source 	= ($f1_end - $f1_start) + 1;				# 54 - 54 + 1 = 1
				my $target 	= ($f2_end - $f2_start) + 1;				# 53 - 52 + 1 = 2
				my $max = $diff_line + $source + 1 + $target;	# number of lines in this instruction
				my (@old,@new);
				my $ptr = \@old;
				for ( $diff_line=$diff_line+1;$diff_line<=$max;$diff_line++ ) {
					my $line = $diff[$diff_line];
					chomp $line;
					if ( $line =~/^---/ ) {
						$ptr=\@new;
						next;
					}
					push @{$ptr},$line;	
				}
				
				my $file_line = $f1_start;
				
				if ( @new > @old ) {
					while ( @old > 1 ) {
						my $line = shift @new;
						$line =~ s/^\>/\|/;	
						$file1[$file_line] = pack("A$line_length",$file1[$file_line]) . " " . pack("A$line_length",$line);
						pop @old;
						$file_line++;
					}
					my $line = shift @new;
					$line =~ s/^\>/\|/;	
					$line = pack("A$line_length",$line);
					$file1[$file_line]=[pack("A$line_length",$file1[$file_line])." ".$line];	# keep original line as first line in sub array
	
					while ( @new ) {
						my $line = shift @new;
						push @{$file1[$file_line]}," " x $line_length ." ". pack("A$line_length",$line);	
					}	
				}
				elsif ( @old > @new ) {
					while ( @new ) {
						my $line = shift @new;
						$line =~ s/^\>/\|/;	
						$file1[$file_line] = pack("A$line_length",$file1[$file_line]) . " " . pack("A$line_length",$line);
						pop @old;
						$file_line++;
					}
					while ( @old ) {
						$file1[$file_line] = pack("A$line_length",$file1[$file_line]) . " <";
						$file_line++;
						pop @old;
					}
				}
				else {
					while ( @new ) {
						my $line = shift @new;
						chomp $line;
						$line =~ s/^\>/\|/;	
						$file1[$file_line] = pack("A$line_length",$file1[$file_line]) . " " . pack("A$line_length",$line);
						pop @old;
						$file_line++;
					}	
				}
				$diff_line--;
			}
			#==========================================================================================
			#  Delete action
			#==========================================================================================
			elsif ( $action eq "d" ) {
				print STDERR "DELETE\n" if $debug >1;
				my $deleted_lines = ( $f1_end - $f1_start ) + 1;
				$diff_line = $diff_line + $deleted_lines;   	# skip lines to be deleted
				my $file_line=$f1_start;
				until ( $deleted_lines == 0 ){
					$file1[$file_line] = pack("A$line_length",$file1[$file_line])." <";
					$deleted_lines--;
					$file_line++
				}
			}			
			else {
				print "Found action $action that I dont know how to handle\n";
			}
		}
	}

#------------------------------------------------------------------------------
# Print the updated file to the report
#------------------------------------------------------------------------------	 
	for ( my $file_line=0;$file_line<@file1;$file_line++ ) {
		my $line = $file1[$file_line];
		if ( ref($line) eq "ARRAY" ) {
			for my $line ( @{$line}) {
				print REPORT "$line\n";
			}	
		}
		else {
			print REPORT "$line\n";
		}
	}
}

#------------------------------------------------------------------------------
# Read file into an array
#------------------------------------------------------------------------------
sub readfile {
	my ($file) = @_;
	debug() if $debug;
	my @data;
	print STDERR "reading $file\n" if $debug;
	open DATA, "<$file" or die "Cannot open $file $!\n";
	@data=<DATA>;
	close DATA;
	return @data;
}

#------------------------------------------------------------------------------
# Read file into an array
#------------------------------------------------------------------------------
sub debug {
	my ($package, $filename, $line,$subroutine) = caller(1);
	printf STDERR "## %s called from line %s\n",$subroutine,$line;
}

sub local_copy {
	my ( $server, $vhost ) = @_;
	warn "getting $server $vhost" if $debug;
	my $dir;
	if ( $vhost =~ /^httpd/i ) {
		$dir = "HTTPServer/conf\/";
	} 
	else {
		$dir = "$vhost/config\/";
	}
	unlink("/tmp/${server}_$vhost.conf");
	
	warn "server=${server} dir=${dir} vhost=${vhost}\n" if $debug;
	my $command = "scp -o pubkeyauthentication=no ${user}\@${server}:/projects/${dir}${vhost}.conf /tmp/${server}_$vhost.conf";
	my @params;
	my $zone     = get_zone($server);
	my $password = getpw($zone);
	
	$Expect::Log_Stdout   = 0;
	$Expect::Debug        = 0;
	$Expect::Exp_Internal = $debug;
	my $timeout1 = 30;
	my $spawn_ok;
	my $errflag;
	my $exp = new Expect;

	if ( !$exp->spawn( $command, @params ) ) {
		die "Cannot spawn $command: $!\n";
	}
	$exp->expect(
		$timeout1,
		[
			qr/^\w+?@\w+?\'s password: */i => sub {
				my $fh = shift;
				$fh->send("$password\r");
				$spawn_ok = 1;
				exp_continue;
			  }
		],
		[
			qr/permission denied/i => sub {
				warn "Error: got 'Permission denied' message\n";
				$errflag = 1;
			  }
		],
		[
			'incorrect password' => sub {
				warn "Error: got 'incorrect password' message\n";
				$errflag = 1;
			  }
		],
		[
			'Authentication is denied' => sub {
				warn "Error: got 'Authentication is denied' message\n";
				$errflag = 1;
			  }
		],
		[
			timeout => sub {
				warn "Error: expect timed out ($timeout1 seconds)\n";
				$errflag = 1;
			  }
		],
		[
			eof => sub {
				if ( ! $spawn_ok) {
					$errflag = 1;
				}
			  }
		],
	);

	if ( ! -r "/tmp/${server}_${vhost}.conf" ) {
		warn "Failed to copy $vhost config from $server\n";
		exit;
	}
	else {
		print "file copied\n";
	}
}

sub get_zone {
	my ($server) = @_;
	my ($realm)  = `lssys -1 -l realm $server`;
	($realm) = split( /\./, $realm );
	if ( $realm eq "y" ) {
		$realm = "Yellow";
	}
	elsif ( $realm eq "b" ) {
		$realm = "Blue";
	}
	else {
		$realm = "Green";
	}
	return $realm;
}

sub getpw {
	my ($zone) = @_;
	my $password;
	if ( ! exists $password{$zone}) {
		local $SIG{INT} = \&ctrlc;
		print "$zone zone password:";
		system( 'stty', '-echo' );
		chop( $password = <STDIN> );
		system( 'stty', 'echo' );
		print "\n";
		$password{$zone}=$password;
	}
	else {
		$password=$password{$zone};
	}
	
	return $password;
}

sub ctrlc {
	system( 'stty', 'echo' );
	print "Exiting\n";
	exit;
}
