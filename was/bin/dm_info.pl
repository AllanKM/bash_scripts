#!/usr/local/bin/perl
# ---------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------
use strict;
my $msg;
while (<STDIN>) {
	my $in = $_;
	if ( $in=~/endpoint:\s(.+?)\s/i ) {
		my $info=`lssys -x csv -l nodestatus,role $1 | grep -v "#"`;
		$info =~ /(.+?),(.+?),(.*)/;
		my @roles = split(/;/,$3);
		my $node = $1;
		my $status = $2;
		$in = "$status - $node - ";
		foreach my $role ( @roles ) {
			if ( $role =~/was.dm./i ) {
				$in .= "$role ";
			}
		}
		$in .= "\n";
	}
	else {
		$in = "\t$in"; 
	}
	$msg .= "$in";
}
print "\t$msg";
