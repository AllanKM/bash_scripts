#!/usr/local/bin/perl

use strict;

# if run with parameter 1 as "check", it will verify the entry already exists
# else it will add the entry

my $check = $ARGV[0];


if( $check eq "check" ){
	print "Checking Crontab\n";
	my $CRONTAB_ENTRY=`su pubinst -c "crontab -l | grep -c /lfs/system/tools/publish/bin/scripts/CleanLogs"`;
	chomp $CRONTAB_ENTRY;
	if( $CRONTAB_ENTRY eq "1" ){
		print "Entry Exists";
		exit 0;	
	}
	else{
		exit 1;	
	}
	
}
else{
	print "Installing Crontab Entry\n";
	system("su pubinst -c \"crontab /fs/system/tools/publish/bin/scripts/CleanLogsCrontabEntry\"");
}
