#!/usr/bin/perl
#======================================================================
# Generate formatted output from data files created by:
#    /lfs/system/tools/was/bin/get_cmp_data.sh

#======================================================================
# Functions
sub usage {
	print "Usage: report_cmp_data.pl [<datatype>=<all|filter>] datafile1 [... datafileN]\n";
	print "    Data types: jvm, jdbcprv, jdbcds, mqcf, mqq, mail, env, lib, port\n";
	print "        (If no data types are specified, all data will be reported)\n";
	print "    The data files to report on must be provided, and more than 1 may be specified for comparison.\n"
}

sub readConfigData {
	my $file = shift @_;
	my ($dataItem, @dataArray, %dataGroups, $dKey, $i);
	open(FILE, "<$file");
	while ($dataItem = <FILE>) {
		chomp $dataItem;
		@dataArray = split(/\|/, $dataItem);
		#First item will be data type indicator, the key
		$dKey = shift @dataArray;
		#Push array of data (as a whole unit) into data type array of the file's data hash
		push @{$dataGroups{$dKey}}, [@dataArray];
		#undef $dataItem;
		#undef @dataArray;
	}
	close FILE;
	#Return the resulting hash of two-dimensional arrays
	return %dataGroups;
}

sub printJVM {
	my ($refJvmArr, $filter) = @_;
	if ($filter eq 'all' || $refJvmArr->[0] =~ /$filter/ || $refJvmArr->[1] =~ /$filter/ || $refJvmArr->[2] =~ /$filter/) {
		printf "Server: %s\tNode: %s\tCluster: %s\n", $refJvmArr->[0], $refJvmArr->[1], $refJvmArr->[2];
		printf "\tHeap  : %s/%-8s\tThreads: %s/%-8s\tPersistence: %s\tM2M Mode: %s\tM2M Domain: %s\n", $refJvmArr->[3], $refJvmArr->[4], $refJvmArr->[5], $refJvmArr->[6], $refJvmArr->[16], $refJvmArr->[17], $refJvmArr->[18];
		printf "\tCookie: %s\tTracking: %s  %s  %s  %s  %s\n", $refJvmArr->[10], $refJvmArr->[11], $refJvmArr->[12], $refJvmArr->[13], $refJvmArr->[14], $refJvmArr->[15], $refJvmArr->[16], $refJvmArr->[17];
		printf "\tTuning: %s  %s\t\tInterval: %s\tOverwrite: %s\t\tMaximum: %s\n", $refJvmArr->[19], $refJvmArr->[20], $refJvmArr->[21], $refJvmArr->[22], $refJvmArr->[23];
		printf "\tPlugin Connect Timeout: %s\tMax Connections: %s\tServerIO Timeout: %s\tServer Role: %s\n", $refJvmArr->[24], $refJvmArr->[25], $refJvmArr->[26], $refJvmArr->[27];
		printf "\tClasspath: %s\tJVM Args: %s\tCustom properties: %s\n", $refJvmArr->[7], $refJvmArr->[8], $refJvmArr->[9];
		print "\n";
	}
}

sub printJdbcPrv {
	my ($refJdbcArr, $filter) = @_;
	if ($filter eq 'all' || $refJdbcArr->[0] =~ /$filter/) {
		printf "JDBC Provider: %s\tScope: %s\n", $refJdbcArr->[0], $refJdbcArr->[1];
		printf "\tTransactions: %s\tImplementation Class: %s\n", $refJdbcArr->[2], $refJdbcArr->[4];
		printf "\tDrivers: %s\n", $refJdbcArr->[3];
		print "\n";
	}
}

sub printJdbcDS {
	my ($refJdbcArr, $filter) = @_;
	if ($filter eq 'all' || $refJdbcArr->[0] =~ /$filter/ || $refJdbcArr->[2] =~ /$filter/ || $refJdbcArr->[11] =~ /$filter/ || $refJdbcArr->[13] =~ /$filter/) {
		printf "Data source: %s\tScope: %s\tJNDI Name: %s\n", $refJdbcArr->[0], $refJdbcArr->[1], $refJdbcArr->[2];
		printf "\tStatement Cache: %-10s\tConnection Pool: %s/%-5s\tPurge Policy  : %s\n", $refJdbcArr->[3], $refJdbcArr->[4], $refJdbcArr->[5], $refJdbcArr->[10];
		printf "\tAged Timeout   : %-10s\tConnect Timeout: %-7s\tUnused Timeout: %-12s\tReap Time: %s\n", $refJdbcArr->[6], $refJdbcArr->[7], $refJdbcArr->[8], $refJdbcArr->[9];
		printf "\tDB Name        : %-10s\tDB Host        : %-7s\tDB Port       : %-12s\tDB Type  : %-4s\tDB Schema: %s\n", $refJdbcArr->[11], $refJdbcArr->[13], $refJdbcArr->[14], $refJdbcArr->[12], $refJdbcArr->[15];
		print "\n";
	}
}

sub printMQCF {
	my ($refMqcfArr, $filter) = @_;
	if ($filter eq 'all' || $refMqcfArr->[0] =~ /$filter/ || $refMqcfArr->[2] =~ /$filter/ || $refMqcfArr->[3] =~ /$filter/ || $refMqcfArr->[5] =~ /$filter/ || $refMqcfArr->[6] =~ /$filter/) {
		printf "MQ Conn Factory: %s\tScope: %s\tJNDI Name: %s\n", $refMqcfArr->[0], $refMqcfArr->[1], $refMqcfArr->[2];
		printf "\tMQ Host: %-7s\tMQ Port: %-8s\tChannel: %s\tQManager: %s\n", $refMqcfArr->[3], $refMqcfArr->[4], $refMqcfArr->[5], $refMqcfArr->[6];
		printf "\tTransport: %s\tCipher: %s\t\tBroker Control: %s\tTransactions: %s\n", $refMqcfArr->[7], $refMqcfArr->[8], $refMqcfArr->[9], $refMqcfArr->[10];
		printf "\tConnection Pool: %s/%-4s\tAged Timeout: %-4s\tConnect Timeout: %-4s\tUnused Timeout: %-4s\tReap Time: %-4s\tPurge Policy: %s\n", $refMqcfArr->[11], $refMqcfArr->[12], $refMqcfArr->[13], $refMqcfArr->[14], $refMqcfArr->[15], $refMqcfArr->[16], $refMqcfArr->[17];
		printf "\tSession Pool   : %s/%-4s\tAged Timeout: %-4s\tConnect Timeout: %-4s\tUnused Timeout: %-4s\tReap Time: %-4s\tPurge Policy: %s\n", $refMqcfArr->[18], $refMqcfArr->[19], $refMqcfArr->[20], $refMqcfArr->[21], $refMqcfArr->[22], $refMqcfArr->[23], $refMqcfArr->[24];
		print "\n";
	}
}

sub printMQQ {
	my ($refMqqArr, $filter) = @_;
	if ($filter eq 'all' || $refMqqArr->[0] =~ /$filter/ || $refMqqArr->[2] =~ /$filter/ || $refMqqArr->[3] =~ /$filter/ || $refMqqArr->[5] =~ /$filter/ || $refMqqArr->[7] =~ /$filter/ || $refMqqArr->[8] =~ /$filter/) {
		printf "MQ Queue: %s\tScope: %s\tJNDI Name: %s\n", $refMqqArr->[0], $refMqqArr->[1], $refMqqArr->[2];
		printf "\tMQ Host: %-7s\tMQ Port : %-8s\tChannelName: %s\tClient: %s\n", $refMqqArr->[3], $refMqqArr->[4], $refMqqArr->[5], $refMqqArr->[6];
		printf "\tQueue  : %s\tQManager: %s\tPersistence: %s\n", $refMqqArr->[7], $refMqqArr->[8], $refMqqArr->[9];
		printf "\tPriority: %s\tSpecified Priority: %s\n", $refMqqArr->[10], $refMqqArr->[11];
		printf "\tExpiry  : %s\tSpecified Expiry  : %s\n", $refMqqArr->[12], $refMqqArr->[13];
		printf "\tEncoding: %s\tInteger Enc: %s\tDecimal Enc: %s\tFloating Point Enc: %s\n", $refMqqArr->[14], $refMqqArr->[15], $refMqqArr->[16], $refMqqArr->[17];
		print "\n";
	}
}

sub printEnvVars {
	my ($refEnvArr, $filter) = @_;
	if ($filter eq 'all' || $refEnvArr->[0] =~ /$filter/ || $refEnvArr->[1] =~ /$filter/ || $refEnvArr->[2] =~ /$filter/) {
		printf "Variable: %s\tScope: %s\tValue: %s\n", $refEnvArr->[0], $refEnvArr->[1], $refEnvArr->[2];
		print "\n";
	}
}

sub printMail {
	my ($refMailArr, $filter) = @_;
	if ($filter eq 'all' || $refMailArr->[0] =~ /$filter/ || $refMailArr->[1] =~ /$filter/ || $refMailArr->[2] =~ /$filter/) {
		printf "Mail Session: %s\tScope: %s\tJNDI Name: %s\tHost: %s\tProtocol: %s\n", $refMailArr->[0], $refMailArr->[1], $refMailArr->[2], $refMailArr->[3], $refMailArr->[4];
		print "\n";
	}
}

sub printLibs {
	my ($refLibArr, $filter) = @_;
	if ($filter eq 'all' || $refLibArr->[0] =~ /$filter/ || $refLibArr->[1] =~ /$filter/ || $refLibArr->[2] =~ /$filter/) {
		printf "Shared Library: %s\tScope: %s\n\tClasspath : %s\n\tNativePath: %s\n", $refLibArr->[0], $refLibArr->[1], $refLibArr->[2], $refLibArr->[3];
		print "\n";
	}
}

sub printPorts {
	my ($refPortArr, $filter) = @_;
	if ($filter eq 'all' || $refPortArr->[0] =~ /$filter/ || $refPortArr->[1] =~ /$filter/ || $refPortArr->[2] =~ /$filter/) {
		printf "Node: %-16s\tServer: %-20s\tName: %-40s\tPort: %s\n", $refPortArr->[0], $refPortArr->[1], $refPortArr->[2], $refPortArr->[3];
		print "\n";
	}
}
#======================================================================
# Start main script execution
my (@DATAFILES, @PARAMS, @WASDATA, $file, $key, $filter) = undef;
my ($i, $j) = 0;
my $noDataTypes = 1;
my %DATATYPES = (
	JVM     => undef,
	JDBCPRV => undef,
	JDBCDS  => undef,
	MQCF    => undef,
	MQQ     => undef,
	MAIL    => undef,
	LIB     => undef,
	ENV     => undef,
	PORT    => undef,
);

foreach my $arg (@ARGV) {
	@PARAMS = split(/\=/, $arg);
	if    ($arg =~ /^jvm=/i)    { $noDataTypes = 0; $DATATYPES{JVM} = $PARAMS[1]; }
	elsif ($arg =~ /^jdbcprv=/i){ $noDataTypes = 0; $DATATYPES{JDBCPRV} = $PARAMS[1]; }
	elsif ($arg =~ /^jdbcds=/i) { $noDataTypes = 0; $DATATYPES{JDBCDS} = $PARAMS[1]; }
	elsif ($arg =~ /^mqcf=/i)   { $noDataTypes = 0; $DATATYPES{MQCF} = $PARAMS[1]; }
	elsif ($arg =~ /^mqq=/i)    { $noDataTypes = 0; $DATATYPES{MQQ} = $PARAMS[1]; }
	elsif ($arg =~ /^mail=/i)   { $noDataTypes = 0; $DATATYPES{MAIL} = $PARAMS[1]; }
	elsif ($arg =~ /^lib=/i)    { $noDataTypes = 0; $DATATYPES{LIB} = $PARAMS[1]; }
	elsif ($arg =~ /^env=/i)    { $noDataTypes = 0; $DATATYPES{ENV} = $PARAMS[1]; }
	elsif ($arg =~ /^port=/i)   { $noDataTypes = 0; $DATATYPES{PORT} = $PARAMS[1]; }
	else { $DATAFILES[$i] = $PARAMS[0]; $i++; }
	@PARAMS = undef;
}

if ($noDataTypes) {
	%DATATYPES = (
		JVM     => 'all',
		JDBCPRV => 'all',
		JDBCDS  => 'all',
		MQCF    => 'all',
		MQQ     => 'all',
		MAIL    => 'all',
		LIB     => 'all',
		ENV     => 'all',
		PORT    => 'all',
	);
}

#Confirm files provided exist and pull in the data
$i = 0;
foreach $file (@DATAFILES) {
	if ( -e $file) {
		print "Found data file: $file\n";
		%{$WASDATA[$i]} = readConfigData($file);
		print "Data imported.\n";
		$i++;
	} else { print "Could not find data file: $file\n"; exit 1; }
}

my %data, @di, $e;
#Cycle through and report the data
foreach $key (sort keys %DATATYPES) {
	#Skip data not requested for report
	if (not defined $DATATYPES{$key}) { next; }
	$filter = $DATATYPES{$key};
	$i = 0;
	print "\n-----------------------------------\n";
	print "Configuration Data: $key\n-----------------------------------\n";
	while ($i <= $#WASDATA) {
		%data = %{$WASDATA[$i]};
		$j = 0;
		while ($j <= $#{$data{$key}}){
			@di = @{${$data{$key}}[$j]};
			if    ($key eq "JVM")    { printJVM(\@di, $filter); }
			elsif ($key eq "JDBCPRV"){ printJdbcPrv(\@di, $filter); }
			elsif ($key eq "JDBCDS") { printJdbcDS(\@di, $filter); }
			elsif ($key eq "MQCF")   { printMQCF(\@di, $filter); }
			elsif ($key eq "MQQ")    { printMQQ(\@di, $filter); }
			elsif ($key eq "MAIL")   { printMail(\@di, $filter); }
			elsif ($key eq "LIB")    { printLibs(\@di, $filter); }
			elsif ($key eq "ENV")    { printEnvVars(\@di, $filter); }
			elsif ($key eq "PORT")   { printPorts(\@di, $filter); }
			else { print "You should not be here. Get out.\n"; exit 1; }
			$j++;
		}
		$i++;
	}
}
