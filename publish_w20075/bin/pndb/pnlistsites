#!/usr/bin/perl

#
# pnlistsites.pl:	Script to list all the sites (should be sorted and unique)
#					in the pubnodes db
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
	$me,
	$sitename,
	@sites,
);

$me = basename($0);

if(@sites = pndb_listsites) {
	foreach $sitename (@sites) {
		print("$sitename\n");
	}
} else {
	print("Unable to get site list\n");
	exit(1);
}

exit(0);
