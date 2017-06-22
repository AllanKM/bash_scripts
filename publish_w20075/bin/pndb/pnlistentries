#!/usr/bin/perl

#
# pnlistentries.pl:	Script to list all the entries in the pubnodes db
#

#
# Author:			Sandy Cash
# Contact:			lhcash@us.ibm.com
# Date:				19. February 2002
#

use lib '/fs/system/tools/publish/lib/perl';
use EI::bNimble;
use File::Basename;
use strict;

my(
	$confpath,
	$hostname,
	$index,
	$me,
	$sitename,
	@entries,
);

$me = basename($0);

if(@entries = pndb_listentries) {
	$index = 0;
	while($index < $#entries) {
		$hostname = $entries[$index];
		$sitename = $entries[++$index];
		$confpath = $entries[++$index];
		$index++;

		print("HOST: $hostname\tSITE: $sitename\tCONF: $confpath\n");
	}
} else {
	print("Unable to get entry list\n");
	exit(1);
}

exit(0);
