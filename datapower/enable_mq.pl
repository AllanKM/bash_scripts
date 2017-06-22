#!/usr/local/bin/perl -w
#============================================
# $Revision: 1.2 $
# Author: Steve Farrell
#============================================
use strict;
use FindBin;
use Term::ANSIColor;
use lib ( "/$FindBin::Bin", "/$FindBin::Bin/lib", "/$FindBin::Bin/../lib", "/lfs/system/tools/configtools/lib" );
use dp_functions;
my ( $serverlist, $attrs, $others ) = parseParms( \@ARGV );
# sanity check whether we got back expected servers
unless ( @{$serverlist}[0] ) {
	print colored( "ERROR: No servers returned. Exiting...\n", "bold red" );
	exit 1;
}
if ($others) {
	print colored( "ERROR: One or more of the supplied arguments did not result in a recognised DataPower device:\n", "bold red" );
	print "$_\n" foreach $others;
	print colored( "Exiting...\n", "bold red" );
	exit 1;
}

my $dp_user = get_dp_user($serverlist);

foreach my $server ( sort @$serverlist ) {
	print colored( "$server", "bold blue" );
	print "\n";
	my $domain = ei_domain($server);

	my $objects = readObjectStatus( $dp_user, $server, $domain );
	enable( $dp_user, $server, $domain, $objects, 'MQQM' );
	enable( $dp_user, $server, $domain, $objects, 'HTTP.*Source.*' );
	save( $dp_user, $server, $domain );
}
print "\nAll done.\n";

sub enable {
	my ( $dp_user, $server, $domain, $objects, $class, $name ) = @_;
	$class = qr/$class$/;
	foreach my $object ( sort { lc($a) cmp lc($b) } keys %$objects ) {
		if ( $objects->{$object}->{class} =~ $class ) {
			if ( ( $name && $object =~ /$name/i ) || !$name ) {
				my $state = "unknown";
				$state = "disabled" if $objects->{$object}->{opstate} eq "down";
				$state = "enabled"  if $objects->{$object}->{opstate} eq "up";
				print colored( "   Before:\t", "bold green" );
				print "$objects->{$object}->{class} $object $state\n";
				print colored( "   After :\t", "bold green" );
				setObjectState( $dp_user, $server, $domain, $objects->{$object}->{class}, $object, 'enabled' );
				print "\n";
			}
		}
	}
}
