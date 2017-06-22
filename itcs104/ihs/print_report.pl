#!/usr/local/bin/perl-current
use Data::Dumper;
use strict;
use warnings;

if ( @ARGV != 1 || $ARGV[0] !~ /\d{8}/ ) { 
	die("This script expects 1 parameters,\nparameter 1 is the date"
		. " for which the data should be processed, in the form YYYYMMDD\n");
}
my $APPDIR="/fs/system/audit/ihs";
my $debug=0;
my $execution_date = $ARGV[0];
my @inputfile;
my $version = "1.4.6";

my @months=qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my $reportmonth=substr($execution_date,4,2);
my $reportyear=substr($execution_date,0,4);
my $DATEDIR = $months[${reportmonth}-1]."${reportyear}";
my $REPORTDATE = substr($execution_date,6,2)."$DATEDIR";

my $data_file 	 = "${APPDIR}/data/$execution_date.dat";
my $fail_file	 = "${APPDIR}/data/${execution_date}_noncompliant.log";
my $server_file = "${APPDIR}/${DATEDIR}/ihs_itcs104_\$server_${REPORTDATE}.log";

my $prev_data_file = `ls $APPDIR/data/*.dat -lrt | tail -2 | head -1 | awk '{print \$\(NF\)}' `;

my $alert;
my $end_of_data = 0;
if ( ! -e "$APPDIR/$DATEDIR" ) {
	mkdir "$APPDIR/$DATEDIR";
}
open(DATA,$data_file) || die "Cannot open $data_file $!";
open(FAILS,">$fail_file") || die "Cannot open $fail_file $!";
while ( !$end_of_data ) {
	my ($server,@server_data) = get_server_data();				# get data for 1 server;
	print "$server rows returned = \t".scalar @server_data."\n" if $debug;
	$alert=0;
	report_server($server,@server_data);
	if ( $alert ) {
		print FAILS "$server\n";
	}
}
close DATA;

sub report_server {
	my ($server,@server_data)=@_;
	my $report = $server_file;
	$report =~ s/\$server/$server/;
	print "$server\n";	
	open(SERVER,">$report") || die "Cannot open $report $!";
	
	print SERVER "ITCS 104 Version $version\n";
	print SERVER "ITCS 104 Compliance report run on data dated $execution_date\n\n";
	
	report_1_1_webserver($server,@server_data);
	report_1_1_webauthors($server,@server_data);
	report_1_1_webdevelopers($server,@server_data);
	report_1_1_webserverid($server,@server_data);
	print SERVER "\n" ."-" x 120 . "\n";
	
	report_3_2_confidential_info();
	report_3_2_document_tree();	
	print SERVER "\n" ."-" x 120 . "\n";
	
	report_4_1_data_transmission($server,@server_data);
	print SERVER "\n" ."-" x 120 . "\n";
	
	report_5_1_server_root($server,@server_data);
	report_5_1_document_root($server,@server_data);
	report_5_1_osrs($server,@server_data);
	report_5_1_default_access($server,@server_data);
	report_5_1_cgi($server,@server_data);
	print SERVER "\n" ."-" x 120 . "\n";
	
	report_6_1_audit($server,@server_data);
	print SERVER "\n" ."-" x 120 . "\n";
	
	close SERVER;
}
	
sub report_1_1_webserver {
	my ($server,@server_data)=@_;
	my @rows = grep(/,ADM,/,@server_data);
	@rows = map { strip_hdr($_)} @rows;
	print SERVER "1.1 Userids\n";
	
	print SERVER "Webserver Administrator/Webmaster\n",
					 "---------------------------------\n",
	"\tAn ID having full system or security admnistration authority\n\tCan access the server either locally or remotely\n";
	print SERVER "\t\tAdmin rights granted thru SUDO\n";		
	
	foreach my $row ( @rows ) {
		my ($group,$users ) = split(/,/,$row,2);
		my $new;
		my @data=`grep -i "$server,ADM,$group" $prev_data_file`;
		if ( @data ) {
			print "$data[0]\n" if $debug;
			@data = map{ strip_hdr($_)} @data;
			my ($oldgroup,$oldusers) = split(/,/,$data[0],2);
			$new = user_diff( $users, $oldusers );
		}
		else {
			$new='';
		}
				
		print SERVER "\t\tGroup: $group\n";		
		print SERVER "\t\tMembers: ";
		userlist($users);
		if ( $new ) {
			print SERVER "\t\tNew members since last run: ";
			userlist($new);
		}	
	}

}
# 
sub report_1_1_webauthors {
	my ($server,@server_data)=@_;	
	my @rows = grep(/,AUT,/,@server_data);
	@rows = map { strip_hdr($_)} @rows;
	print SERVER "\nWeb Authors\n",
					   "-----------\n",
	"\tAn ID having read and write access to the document tree\n";
	
	if ( @rows ) {
		foreach my $row ( @rows ) {
			my $new;
			my ($docroot,$group,$users ) = split(/,/,$row,3);
			my @data=`grep -i "$server,AUT,$docroot,$group" $prev_data_file`;
			if ( @data ) {
				@data = map{ strip_hdr($_)} @data;
				my ($olddocroot,$oldgroup,$oldusers) = split(/,/,$data[0],3);
				$new = user_diff( $users, $oldusers );
			}
			else {
				$new='';
			}
			print SERVER "\t\tDocument tree: $docroot\n";		
			print SERVER "\t\t\tGroup: $group\n";				
			print SERVER "\t\t\tMembers:";
			userlist($users);			
			if ( $new ) {
				print SERVER "\t\t\tNew members since last run: ";
				userlist($new);		
			}	
		}
	}
}

sub report_1_1_webdevelopers {
	my ($server,@server_data)=@_;	
	my @rows = grep(/,DEV,/,@server_data);
	@rows = map { strip_hdr($_)} @rows;
	
	print SERVER "\nWeb Developers\n",
					   "--------------\n",
		"\tAn author ID having additional authority to install and modify CGI scripts\n\t";
		
	if ( @rows ) {
		foreach my $row ( @rows ) {
			my $new;
			my ($docroot,$group,$users ) = split(/,/,$row,3);
			my @data=`grep -i "$server,DEV,$docroot,$group" $prev_data_file`;
			if ( @data ) {
				print "$data[0]\n" if $debug;
				@data = map{ strip_hdr($_)} @data;
				my ($olddocroot,$oldgroup,$oldusers) = split(/,/,$data[0],3);
				$new = user_diff( $users, $oldusers );
			}
			else {
				$new='';
			}
			print SERVER "\t\tDocument tree: $docroot\n";				
			print SERVER "\t\tGroup: $group\n";		
			print SERVER "\t\tMembers: ";
			userlist($users);		
			
			if ( $new ) {
				print SERVER "New members since last run: ";
				userlist($new);		
			}	
		}	
	}
}

sub report_1_1_webserverid {
	my ($server,@server_data)=@_;
	my @rows = grep(/,WID,/,@server_data);
	@rows = map { strip_hdr($_)} @rows;
	print SERVER "\nWeb Server ID\n",
						"-------------\n",
					"\tID which runs the web server\n";
	print SERVER "\t\t".$rows[0]."\n";		
}

sub report_3_2_confidential_info {
	print SERVER "\n3.2 User Resources\n",
						"------------------\n",
			"\tIBM COnfidential Information\n",
			"\t----------------------------\n",
			"\tNot stored on EI systems\n";
}

sub report_3_2_document_tree {
	print SERVER "\tDocument Tree\n",
						"\t-------------\n",
			"\tConfidential data not stored on EI systems\n";	
}

sub report_4_1_data_transmission {
	my ($server,@server_data)=@_;
	my @rows = grep(/,SSL,/,@server_data);
	@rows = map { strip_hdr($_)} @rows;
	
	print SERVER "\n4.1 Encryption\n",
						"--------------\n";
	print SERVER "\tData Transmission\n",
						"\t-----------------\n",
			"\t\tSSL\n";
		
	if ( @rows ) {
		foreach my $ssl ( @rows ) {
			print SERVER "\t\t\t$ssl\n";
		}
	}
	else { 
				print SERVER "\t\t\tNo HTTPS connections defined";
	}
	
	@rows = grep(/,CRT,/,@server_data);
	@rows = map { strip_hdr($_)} @rows;
	if ( @rows ) {
		foreach my $cert ( @rows ) {
			my ($vhost,$auth,$url,$start,$start_time,$end,$end_time) = split(/,/,$cert);
			if ( ! defined $start 
				|| ! defined $end 
				|| ! defined $vhost
				|| ! defined $auth ) {
					print SERVER "\t\t *FAIL* Invalid certificate information, check collector is working\n";
					$alert=1;
				}
			else {
				print SERVER "\t\t\tvhost: $vhost\n";
				print SERVER "\t\t\tIssued by: $auth\n";
				print SERVER "\t\t\tPeriod: $start to $end\n";
			}
		}
	}	
}

#=======================================================================================================
#
#	Section 5
#
#=======================================================================================================
sub report_5_1_server_root{
	my ($server,@server_data)=@_;	

	print SERVER "\n5.1 Operating system resources\n",
						"------------------------------\n";
	
	my @rows = grep(/,SVR,/,@server_data);
	@rows = map { strip_hdr($_)} @rows;
	my $fail=0;
	print SERVER "\tServer Root\n",
						"\t-----------\n";
	if ( @rows ) {
		my ( $root,$valid_group,$other_write ) = split(/,/,$rows[0] );
		print SERVER "\t\tServer root: $root";
		if ( $valid_group == "1" ) {
			print SERVER "\t*FAIL* owned by non webserver admin group\n";
			$fail="1";
			$alert=1;
		}
		if ( $other_write ) {
			print SERVER "\t*FAIL* $other_write directories with global write access\n";
			$fail="1";
			$alert=1;
		}
		if ( $fail == "0" ) {
			print SERVER "\tcompliant\n";
		}
	}
	
}

sub report_5_1_document_root {
	my ($server,@server_data)=@_;
		
	my @rows = grep(/,DOC,/,@server_data);
	@rows = map { strip_hdr($_)} @rows;
	my $fail = "0";
	print SERVER "\n\tDocument Root\n",
						"\t-------------\n",
		"\tThis directive sets the directory from which httpd will serve files.\n\tUnless matched by a directive like Alias, the server appends the path from the requested URL to the document root to make the path to the document.\n";
	
	if ( @rows ) {
		foreach my $row ( @rows ) {
			my ( $docroot,$badfiles ) = split(/,/,$row );
			if ( $badfiles > 0 ) {
				print SERVER "/t/t$docroot: *FAIL* Non-compliant $badfiles files fail\n";
				$alert=1;
				$fail="1";
			}
			else {
				print SERVER "\t\t$docroot: compliant\n";
			}
		}
	}
}

sub report_5_1_osrs {
	my ($server,@server_data)=@_;
	my $fail;
	print SERVER "\n\tApache OSRs\n",
					 "\t-----------\n",
		"\t\tOSRs for webservers are directories and files which contain executables, libraries, modules, configuration files and other configuration objects. By default they are located within the ServerRoot but may have other locations if specified by configuration statements and compiled-in defaults.\n",
		"\t\tGeneral users at an operating system level may be allowed read (or read & execute) access to the following OSR directories and files:\n";

	print SERVER "\t\tConfiguration File Directory\n",
					 "\t\t----------------------------\n";
	my @rows = grep(/,CFD,/,@server_data);
	@rows = map { strip_hdr($_)} @rows;
	if ( @rows ) {
		foreach my $row ( @rows ) {
			my ( $dir,$count ) = split(/,/,$row);
			if ( $count > 0 ) {
				print SERVER "\t\t\t$dir: *FAIL* has $count non compliant files\n";
				$alert=1;
				$fail="1";
			}
			else {
				if ( $row eq $rows[scalar @rows -1] ) {
					print SERVER "\t\t\t$dir: complies\n";
				}
				else {
					print SERVER "\t\t\t$dir: complies\n";
				}
			}
		}
	}

	print SERVER "\n\t\tLogs Directory\n",
					 "\t\t--------------\n";
	
	@rows = grep(/,LOG,/,@server_data);
	@rows = map { strip_hdr($_)} @rows;
	if ( @rows ) {
		foreach my $row ( @rows ) {
			my ( $dir,$count ) = split(/,/,$row);
			if ( $count > 0 ) {
				print SERVER "\t\t\t$dir: *FAIL* has $count non compliant files\n";
				$alert=1;
				$fail="1";
			}
			else {
				if ( $row eq $rows[scalar @rows -1] ) {
					print SERVER "\t\t\t$dir: complies\n";
				}
				else {
					print SERVER "\t\t\t$dir: complies\n";
				}
			}
		}
	}
	
	print SERVER "\n\t\tBin Directory\n",
						"\t\t-------------\n";
	@rows = grep(/,BIN,/,@server_data);
	@rows = map { strip_hdr($_)} @rows;
	if ( @rows ) {
		foreach my $row ( @rows ) {
			my ( $dir,$count ) = split(/,/,$row);
			if ( $count > 0 ) {
				print SERVER "\t\t\t$dir: *FAIL* has $count non compliant files\n";
				$alert=1;
				$fail="1";
			}
			else {
				if ( $row eq $rows[scalar @rows -1] ) {
					print SERVER "\t\t\t$dir: complies\n";
				}
				else {
					print SERVER "\t\t\t$dir: complies\n";
				}
			}
		}
	}
	
	
	print SERVER "\n\t\tLoad Module/LibExec Modules\n",
						"\t\t---------------------------\n";
	@rows = grep(/,MOD,/,@server_data);
	@rows = map { strip_hdr($_)} @rows;
	if ( @rows ) {
		foreach my $row ( @rows ) {
			my ( $dir,$count ) = split(/,/,$row);
			if ( $count > 0 ) {
				print SERVER "\t\t\t$dir: *FAIL* has $count non compliant files\n";
				$alert=1;
				$fail="1";
			}
			else {
				if ( $row eq $rows[scalar @rows -1] ) {
					print SERVER "\t\t\t$dir: complies\n";
				}
				else {
					print SERVER "\t\t\t$dir: complies\n";
				}
			}
		}
	}
		
	print SERVER "\t\tHttpd.conf\n",
					 "\t\t----------\n";
	@rows = grep(/,CFG,/,@server_data);
	@rows = map { strip_hdr($_)} @rows;
	if ( @rows ) {
		foreach my $row ( @rows ) {
			my ( $dir,$count ) = split(/,/,$row);
			if ( $count > 0 ) {
				print SERVER "\t\t\t$dir: *FAIL* has $count non compliant files\n";
				$alert=1;
				$fail="1";		
			}
			else {
				if ( $row eq $rows[scalar @rows -1] ) {
					print SERVER "\t\t\t$dir: complies\n";
				}
				else {
					print SERVER "\t\t\t$dir: complies\n";
				}
			}
		}
	}
}

sub report_5_1_default_access {
	my ($server,@server_data)=@_;
	print SERVER "\n\tDefault Access Rule\n",
						"\t-------------------\n",
		"Apache allows the restriction of network access to the documents of the webserver. A 'default deny' clause and subsequent allow clauses for specific web-resources limits the risk of configuration errors.\n",
		"The following directives have to be put into the main apache configuration file near the beginning before any other Directory statements:\n",
		"	<Directory />\n",
		"	Order Deny,Allow\n",
		"	Deny from all\n",
		"	Options None\n",
		"	AllowOverride None\n",
		"	</Directory>\n";

	my @rows = grep(/,DAR,/,@server_data);
	@rows = map { strip_hdr($_)} @rows;
	if ( @rows ) {
		foreach my $row ( @rows ) {
			my ( $dir,$order,$deny,$options,$allowoveride ) = split(/,/,$row);
		
			my $comment="Rule defined:";
			if ( $order == 0 ) { 
				$comment=$comment . " order";
			}
			if ( $deny == 0 ) { 
				$comment=$comment . " deny," ; 	
			}
			if ( $options == 0 ) { 
				$comment=$comment . " options,";  	
			}
			if ( $allowoveride == 0 ) { 
				$comment=$comment . " allowoverride,";  	
			}
			
			if ( $comment=~/,$/ ) {
				$comment=~s/,$//;
				$comment.=" statement not as per rule"; 
			}
			else {
				$comment=~s/://;
			}
			print SERVER "\t\t\t$dir $comment\n" ;
		}
	}
	else {
		print SERVER "\t\t\tNo optional default access rule defined\n";
	}
}

sub report_5_1_cgi {
	my ($server,@server_data)=@_;

	my @rows = grep(/,CGI,/,@server_data);
	@rows = map { strip_hdr($_)} @rows;
	
	print SERVER "\n\tCGI Scripts \n",
						"\t-----------\n";
	
	if ( @rows ) {
		foreach my $row ( @rows ) {
			my ( $dir,$owner,$globalw,$ex,$sh ) = split(/,/,$row);
			if ( $owner > 0 || $globalw > 0 ) {
				print SERVER "\t\t$dir: *FAIL* Non compliant - $owner with invalid owner and $globalw with global write\n";
				$alert=1;
			}
			else {
				print SERVER "\t\t$dir: complies\n";
			}
		}
	}
	else {
		print SERVER "\t\tNo CGI dirs found\n";
	}
	

	print SERVER "\n\texploitable CGI programs\n",
						"\t------------------------\n";
	if ( @rows ) {
		foreach my $row ( @rows ) {
			my ( $dir,$owner,$globalw,$ex,$sh ) = split(/,/,$row);
			if ( $ex > 0 ) {
				print SERVER "\t\t$dir: *FAIL* Non compliant - $ex exploitable files found\n";
				$alert=1;
			}
			else {
				if ( $row eq $rows[scalar @rows -1] ) {
					print SERVER "\t\t$dir: complies\n";
				}
				else {
					print SERVER "\t\t$dir: complies\n";
				}
			}
		}
	}
	
	print SERVER "\n\tShell or script interpreters\n",
						"\t----------------------------\n";
	if ( @rows ) {
		foreach my $row ( @rows ) {
			my ( $dir,$owner,$globalw,$ex,$sh ) = split(/,/,$row);
			if ( $sh > 0 ) {
				print SERVER "\t\t$dir: *FAIL* Non compliant - $ex exploitable files found\n";
				$alert=1;
			}
			else {
				if ( $row eq $rows[scalar @rows -1] ) {
					print SERVER "\t\t$dir: complies\n";
				}
				else {
					print SERVER "\t\t$dir: complies\n";
				}
			}
		}
	}
}

sub report_6_1_audit {
	my ($server,@server_data)=@_;

	my @rows = grep(/,AUD,/,@server_data);
	@rows = map { strip_hdr($_)} @rows;
	
	print SERVER "\n6.1 Activity auditing\n",
						"---------------------\n";
	print SERVER "\tTransferLog\n",
					 "\t-----------\n",
		"\tWeb Server Log where activity is stored\n",
		"\tDefined by TransferLog directive in Server Configuration file\n";
	if ( @rows ) {
		foreach my $row ( @rows ) {
			print SERVER "\t\t$row\n";
		}
	}
	else {
		print SERVER "\t\tNo customlog definitions\n";
		$alert=1;
	}
}


sub report_5_1_skel {
	my ($server,@server_data)=@_;	
	
	print SERVER "-" x 60 . "\n";
}

BEGIN {
my $lastline;
my $last_server='';
	sub get_server_data {
		my @server_data;
		my ($server,$x);
		if ( $lastline ) {
			push(@server_data,$lastline);
		}
		while ( my $line = <DATA> ) {
			($x,$server) = split(/,/,$line)	;				# get 2nd comma delimited field
			if ( ! $last_server ) {
				print "first server\n" if $debug;
				$last_server=$server;
			}
			if ( "$server" ne "$last_server" ) {
				$lastline=$line;										# preserve line over sub calls
				$x=$last_server;
				$last_server=$server;
				return ($x,@server_data);
			}
			else {
				$last_server=$server;
				push (@server_data,$line);
			}
		}
		print "End of file\n" if $debug;
		$end_of_data=1;
		return ($last_server,@server_data);
	}
}

sub strip_hdr {
	my ($row) = @_;
	$row =~ /.+?,.+?,.+?,(.*)/;
	return $1;
	}

sub user_diff {
	my ($users,$oldusers) = @_;
	$users=substr($users,1,length($users)-2);
	$oldusers=substr($oldusers,1,length($oldusers)-2);
	my $u;
	map {$u->{$_}++} split(/,/,$users);
	foreach my $user ( split(/,/,$oldusers) ) {
		delete $u->{$user};
	}
	$users='';
	foreach my $user ( keys %{$u} ) {
		$users=$users.$user.',';
	}
		
	return substr($users,0,length($users)-1);
}

sub userlist {
		my ($users)=@_;
		my @users=split(",",$users);
		my $i=0;
		my $userlist;
		foreach my $user (@users) {
			$i++;
			$userlist .= $user .",";
			if ( $i % 8 == 0 ) {
				print SERVER "$userlist\n\t\t";
				$userlist="\t\t";
			}
			
		}
		if ( $userlist ) {
			$userlist =~ s/,\),$/\)/;
			print SERVER $userlist."\n";
		}				
}
