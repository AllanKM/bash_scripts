#!/usr/local/bin/perl
use strict;
	my ($file) = $ARGV[0];
	my $pw ='';
	open(F,$file) || die "Can't open $file: $!";
	my $stash;
	read F,$stash,1024;

	my @unstash=map { $_^0xf5 } unpack("C*",$stash);

	foreach my $c (@unstash) {
		 last if $c eq 0;
		 $pw=$pw.sprintf "%c",$c;
	}
	print $pw;
