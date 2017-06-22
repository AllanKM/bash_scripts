#!/usr/bin/perl

#
# pngetconf.pl:		Script to return the path to the correct bNimble/daedalus config
#					file for the specified event
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

if($confpath = pndb_getconf($hostname, $sitename)) {
	print("$confpath\n");
} else {
	print("No configuration data found\n");
	exit(1);
}

exit(0);
