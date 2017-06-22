#!/usr/bin/perl

#
# pnupdnode.pl:		Script to update a node/event pair and the corresponding configuration file
#					entry in the pubnodes db
#

#
# Author:			Sandy Cash
# Contact:			lhcash@us.ibm.com
# Date:				18. February 2002
#

use lib '/fs/system/tools/publish/lib/perl';
use EI::bNimble;
use File::Basename;
use Getopt::Long;
use Sys::Hostname;
use strict;

my(
	$confpath,
	$hostname,
	$me,
	$sitename,
);

&GetOptions(
	"conf=s"		=> \$confpath,
	"host=s"		=> \$hostname,
	"site=s"		=> \$sitename,
);

$me = basename($0);

# Hostname defaults to hostname of local system (the one you're running this on)
unless($hostname) {
	$hostname = hostname();
}

if ( ! $sitename ) {
	warn("$me: must specify sitename argument with --site flag\n");
	die;
}

if ( ! $confpath ) {
	warn("$me: must specify configuration file path with --conf flag\n");
	die;
}

if (pndb_updnode($hostname, $sitename, $confpath)) {
	print("Entry for $hostname, $sitename updated => $confpath\n");
} else {
	warn("Error encountered, entry either not found or not updated\n");
	exit(1);
}

exit(0);
