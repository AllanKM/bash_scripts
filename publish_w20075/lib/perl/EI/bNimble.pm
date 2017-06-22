package EI::bNimble;

#
# EI::bNimble.pm:		Perl module for managing various aspects of
#						the bNimble publishing system
#

#
# Author:				Sandy Cash
# Contact:				lhcash@us.ibm.com
# Date:					16. February 2002
#

#
# $Id$
#

use Exporter;
@ISA		= ('Exporter');
@EXPORT		= (
				'distquery',
				'parseconf',
				'pndb_addnode',
				'pndb_delnode',
				'pndb_updnode',
				'pndb_getconf',
				'pndb_listsites',
				'pndb_listentries',
				'pndbDelConfig',
				'pndbGetConfig',
				'pndbSetConfig',
		  );
@EXPORT_OK	= (
				'version',
		  );

use lib "/fs/system/tools/dirstore/lib";
use EI::DirStore;
use IO::Socket;
#use DB_File;
use Fcntl;
use strict;

$EI::bNimble::pndb_path = "/.fs/system/tools/publish/pndb";
$EI::bNimble::configdb	= "pubconfigs";
$EI::bNimble::db_format	= "DB_File";
$EI::bNimble::version	= "bNimble.pm version 2.0.0.0";

1;

#
# version:				Print out the version of this module
#

sub version {
	return($EI::bNimble::version);
}

#
# distquery:			Retrieve the specified URI from the specified distributor,
#						store in a hash
#

sub distquery {
	my (
		$endpoint,
		$host,
		$http_rc,
		$key,
		$port,
		$queuesize,
		$queuetype,
		$rcv_line,
		@rcv_line_array,
		$socket,
		$uri,
		$val,
		%retvals,
	);

	unless($host = shift) {
		die("EI::bNimble::distquery() - Null arglist or invalid host argument found\n");
	}

	unless(($port = shift) && ($port =~ /^\d+$/)) {
		die("EI::bNimble::distquery() - Null or invalid port argument found\n");
	}

	unless($uri = shift) {
		die("EI::bNimble::distquery() - Null URI argument found\n");
	}

	#
	# Make connection
	#
	
	$socket = new IO::Socket::INET( PeerAddr => $host,
									PeerPort => $port,
									Proto	 => "tcp",
									Type	 => SOCK_STREAM)
		or die("ERROR: Unable to connect to distributor at $host:$port\n");
	
	#
	# Perform the requested operation
	#
	
	print($socket "GET $uri\n\n");
	
	$rcv_line = <$socket>;
	($http_rc) = ($rcv_line =~ /HTTP\/\d\.\d\s+(\d{3})/);
	if ($http_rc != 200) {
		warn("ERROR: EI::bNimble::distquery() - Got code $http_rc from distributor\n");
		close($socket);
		return(undef);
	}

	#
	# Get past the rest of the header
	#

	while(($rcv_line = <$socket>) !~ /^\s*$/) {}

	#
	# Read the rest of the lines and put the other values into a hash
	#

	if ($uri =~ /queue/) {
		while($rcv_line = <$socket>) {
			chomp($rcv_line);

		#
		# Now we step through the lines
		#

			if ($rcv_line =~ /^Queue for \w+\s+(\S+)/) {
				$endpoint = $1;
			} elsif ($rcv_line =~ /(Memory|Target|Disk|Target Disk)\s+Queue\s+Size:\s*(\S+)/) {
				
				$queuetype = $1;
				${${$retvals{"$endpoint"}}{"$queuetype"}}{'Size'} = ($queuesize = $2);

				#
				# Regardless of queue size, get past the "Queue Elements" line
				#

				<$socket>;

				if ($queuesize > 0) {

					#
					# Read off $queuesize lines
					#

					my $qcount = 0;
					while ($qcount++ < $queuesize) {
						$rcv_line=<$socket>;
						chomp($rcv_line);
						push(@{${${$retvals{"$endpoint"}}{"$queuetype"}}{'Items'}}, $rcv_line);
					}
				}
			}					# End of details for particular queue
		}						# End of cycling through return lines
	} else {					# End of if this is a queue request condition
		while($rcv_line = <$socket>) {
			chomp($rcv_line);
			if ($rcv_line =~ /^([^:]+):\s+(\S+)/) {
				$key = $1;
				$val = $2;
	
				#
				# If we have an array, already init'd
				#
	
				if (exists($retvals{"$key"})) {
					no strict 'refs';
					if (! defined(${$retvals{"$key"}}[0])) {
						my $temp = $retvals{"$key"};
						delete($retvals{"$key"});
						push(@{$retvals{"$key"}}, $temp, $val);
					} else {
						push(@{$retvals{"$key"}}, $val);
					}
				} else {
					$retvals{"$key"} = $val;
				}
			}
		}
	}

	close($socket);
	return(\%retvals);
}

#
# parseconf:	subroutine to parse bNimble config
#
# Argument:		string				Path to the bNimble/daedalus config file
#
# Return:		hash reference		reference to a hash - first level keys are names of stanzas,
#									second level keys are other stanza keys ( <key> = <value> )
#

sub parseconf {
	my (
		$configfile,
		$currentstanzaname,
		$key,
		$line,
		$lineno,
		$me,			# Fully qualified function name (of this function)
		$value,
		%config,
	);

	$me = "EI::bNimble::parseconf()";

	# We require a single argument, the path to the config file
	if ( ! ($configfile = shift)) {
		warn("$me: No config file argument found\n");
		return(undef);
	}

	open(CONF, "$configfile") || do {
		warn("$me: Unable to open $configfile for reading\n");
		return(undef);
	};

	#
	# Slurp in the config and parse
	#

	$lineno = 0;
	while($line = <CONF>) {
		$lineno++;

		# Skip comments
		if ($line =~ /^\s*\#/) {
			next;
		}

		# Step into a stanza
		if ($line =~ /{/) {

			# Read until the closing brace
			while (($line = <CONF>) !~ /}/) {
				$lineno++;
				chomp($line);

				# Skip comments
				if ($line =~ /^s*\#/) {
					next;
				}

				# Find key=value lines, parse
				if ($line =~ /^\s*(\w+)\s*=\s*(.+)/) {
					$key = $1;
					$value = $2;

					if ($key eq "name") {
						$currentstanzaname = $value;
					} elsif (! $currentstanzaname ) {
						warn("$me: Error at ${configfile}:${lineno}, name must be first line in stanza\n");
						return(undef);
					} else {
						${$config{$currentstanzaname}}{$key} = $value;
					}
				}
			}

			# Reset for next stanza
			undef($currentstanzaname);
		}
	}		# END OF READING CONFIG FILE

	return(\%config);
}


#
# listdirs			lists the dirs specified in the bNimble/daedalus config, specifically
#					daedalus home and any document-root dirs specified
#
# Argument			hash reference		Should be a reference to a config as returned by EI::bNimble::parseconf()
#
# Return value		Array reference	List of directories
# 					undef			On Error
#

sub listdirs {
	my (
		$configkey,
		$configref,
		$dir,
		$me,
		@dirs,
	);

	$me = "EI::bNimble::listdirs()";

	if ( ! ($configref = shift)) {
		warn("$me: expected hash reference argument, none found\n");
		return(undef);
	}

	push(@dirs, ${${$configref}{'daedalus'}}{'home'});

	foreach $configkey (keys(%{$configref})) {
		if (defined($dir = ${${$configref}{$configkey}}{'document-root'})) {
			push(@dirs, $dir);
		}

		if (defined($dir = ${${$configref}{$configkey}}{'disk-queue-directory'})) {
			push(@dirs, $dir);
		}
	}

	return(\@dirs);
}

#
# missingdirs		checks existence of directories (daedalus home, document-root(s))
#
# Argument			hash reference	Should be a reference to a config as returned by EI::bNimble::parseconf()
#
# Return value		Array	List of directories which do not exist
#					undef	On error
#

sub missingdirs {
	my (
		$configref,
		$dir,
		$dirlistref,
		$me,
		@missingdirs,
	);

	$me = "EI::bNimble::missingdirs()";

	if ( ! ($configref = shift)) {
		warn("$me: expected hash reference argument, none found\n");
		return(undef);
	}

	if ( ! ($dirlistref = listdirs($configref))) {
		warn("$me: error returned from listdirs()\n");
		return(undef);
	}

	foreach $dir (@{$dirlistref}) {
		if ( ! -d $dir) {
			push(@missingdirs, $dir);
		}
	}

	return(\@missingdirs);
}

#
# unwriteabledirs	checks to see if the list of dirs is writeable
#
# Argument			hash reference	Should be a reference to a config as returned by EI::bNimble::parseconf()
#
# Return value		Array	List of dirs which are not writeable
#					undef	On error
# 

sub unwriteabledirs {
	my (
		$configref,
		$dir,
		$dirlistref,
		$me,
		@unwriteabledirs,
	);

	$me = "EI::bNimble::unwriteabledirs()";

	if ( ! ($configref = shift)) {
		warn("$me: expected hash reference argument, none found\n");
		return(undef);
	}

	if ( ! ($dirlistref = listdirs($configref))) {
		warn("$me: error returned from listdirs()\n");
		return(undef);
	}

	foreach $dir (@{$dirlistref}) {
		if ( ! -w $dir) {
			push(@unwriteabledirs, $dir);
		}
	}

	return(\@unwriteabledirs);
}

###########
# PUBNODES DB MGMT SECTION
###########

#
# NOTE: for each of the functions below, realize that "node" does not simply imply a physical system -
#		it implies a system-site pair, since a given physical system may run multiple instances
#		of bNimble simultaneously.  So each will require as arguments *both* the "nodename" in EI parlance
#		*and* the site - sites are strings like "masters", effectively the event.  This lets us
#		uniquely identify nodes or groups of nodes in a variety of manners.
#
# NOTE:	please keep in mind as well that the above assumes that, for a given event, if multiple bNimble
#		instances are to be run for one event on the same physical system (something we strongly dis-
#		courage), be sure to use different sitenames for each bNimble config, or we cannot guarantee
#		results (and do not anticipate being able to do so in the future, so complaints > /dev/null)
#

#
# pndb_addnode:		function to add a node to the pubnodes db
#					NOTE:  if the pubnodes db does not already exist, this will create it
#
# Arguments:		string	hostname	Name of the host
#					string	sitename	Name of the site (e.g. "masters")
#					string	confpath	Path to the bNimble/daedalus configuration file
#											(e.g. "masters/MainHub.conf")
#
# Return value:		1		if successful
#					undef	on error
#

sub pndb_addnode {
	my (
		$config_path,
		$config_site,
		$confpath,
		$hostname,
		$me,
		$nodeconfig,
		$nodedata,
		$sitename,
		@node_configs,
		%pndb_configs,
	);

	$me = "EI::bNimble::pndb_addnode()";
	
	if ( !($hostname = shift)) {
		warn("$me: no hostname argument found\n");
		return(undef);
	}

	if ( !($sitename = shift)) {
		warn("$me: no site name argument found\n");
		return(undef);
	}

	if ( !($confpath = shift)) {
		warn("$me: no configuration file argument found\n");
		return(undef);
	}

	#
	# Make the entry in the nodes db
	#

	tie(%pndb_configs, $EI::bNimble::db_format, "$EI::bNimble::pndb_path/$EI::bNimble::configdb",
		O_RDWR|O_CREAT, 0777) or
		do {
			warn("$me: unable to open $EI::bNimble::pndb_path/$EI::bNimble::configdb\n");
			return(undef);
		};

	if ($nodedata = $pndb_configs{"$hostname,$sitename"}) {
		# This entry already exists, error
		warn("$me: entry exists for $hostname, $sitename\n");
		return(undef);
	} else {
		# If we're here, no entry found, so create one
		$pndb_configs{"$hostname,$sitename"} = $confpath;
	}

	return(1);
}



#
# pndb_delnode:		function to delete a node from the pubnodes db
#					NOTE:  there is no way to "wildcard delete" all the entries for a given
#					physical system (assuming multiple site-system entries for the same
#					physical system).  If you need to do this, process allnodes.(conf|xml)
#					to get the list of nodes for a given site, then cycle through them.
#					Same if you want to delete all entries for a given site or event.
#
# Arguments:		string	hostname	Name of the host
#					string	sitename	Name of the site (e.g. "masters")
#
# Return value:		1		if successful
#					undef	on error
#

sub pndb_delnode {
	my (
		$config_site,
		$count,
		$eventname,
		$hostname,
		$me,
		$nodeconfig,
		$nodedata,
		$sitename,
		@node_configs,
		%pndb_configs,
	);

	$me = "EI::bNimble::pndb_delnode()";
	
	if ( !($hostname = shift)) {
		warn("$me: no hostname argument found\n");
		return(undef);
	}

	if ( !($sitename = shift)) {
		warn("$me: no site name argument found\n");
		return(undef);
	}

	#
	# Find and delete the entry in the hosts db
	#

	tie(%pndb_configs, $EI::bNimble::db_format, "$EI::bNimble::pndb_path/$EI::bNimble::configdb",
		O_RDWR, 0777) or
		do {
			warn("$me: unable to open $EI::bNimble::pndb_path/$EI::bNimble::configdb\n");
			return(undef);
		};

	if($pndb_configs{"$hostname,$sitename"}) {
		delete($pndb_configs{"$hostname,$sitename"});
		return(1);
	} else {
		# If we're here, we didn't find an entry, return error
		warn("$me: no entry found for $hostname, $sitename\n");
		return(undef);
	}
}

#
# pndb_updnode:		function to update the entry for a node in the pubnodes db
#					NOTE:  if the specified node does not already have an entry in the
#					pubnodes db, this will *not* add it - you must use pndb_addnode or
#					call this function with the CR_ENTRY flag
#

sub pndb_updnode {
	my (
		$confpath,
		$hostname,
		$me,
		$nodeconfig,
		$nodedata,
		$sitename,
		@node_configs,
		%pndb_configs,
	);

	$me = "EI::bNimble::pndb_updnode()";
	
	if ( !($hostname = shift)) {
		warn("$me: no hostname argument found\n");
		return(undef);
	}

	if ( !($sitename = shift)) {
		warn("$me: no site name argument found\n");
		return(undef);
	}

	if ( !($confpath = shift)) {
		warn("$me: no configuration file argument found\n");
		return(undef);
	}

	#
	# Find and update the entry in the hosts db
	#

	tie(%pndb_configs, $EI::bNimble::db_format, "$EI::bNimble::pndb_path/$EI::bNimble::configdb",
		O_RDWR, 0777) or
		do {
			warn("$me: unable to open $EI::bNimble::pndb_path/$EI::bNimble::configdb\n");
			return(undef);
		};

	if($pndb_configs{"$hostname,$sitename"}) {
		$pndb_configs{"$hostname,$sitename"} = $confpath;
		return(1);
	} else {
		# If we're here, we didn't find an entry, return error
		warn("$me: no entry found for $hostname, $sitename\n");
		return(undef);
	}
}

#
# pndb_getconf:		function to return the path to the config file for the specified "node"
#					NOTE:  We intend for programs calling this to supply the hostname AND
#					either the event or the sitename - for instance, a program to start publishing
#					should be run locally on the system (and thereby be aware of the hostname) and
#					be called with the sitename or event as an argument - it should then call this
#					function with both of those parameters.
#
#					NOTE:  We are coding this function to accept three args - system hostname,
#					event, and site - only one of event and site is required, but if BOTH are supplied...
#					caveat emptor.  If both are supplied, but they do not match, we will
#					return undef/NULL.
#

sub pndb_getconf {
	my (
		$confpath,
		$hostname,
		$me,
		$nodeconfig,
		$nodedata,
		$sitename,
		@node_configs,
		%pndb_configs,
	);

	$me = "EI::bNimble::pndb_getconf()";
	
	if ( !($hostname = shift)) {
		warn("$me: no hostname argument found\n");
		return(undef);
	}

	if ( !($sitename = shift)) {
		warn("$me: no site name argument found\n");
		return(undef);
	}

	#
	# Find and return the entry in the hosts db
	#

	tie(%pndb_configs, $EI::bNimble::db_format, "$EI::bNimble::pndb_path/$EI::bNimble::configdb",
		O_RDONLY, 0777) or
		do {
			warn("$me: unable to open $EI::bNimble::pndb_path/$EI::bNimble::configdb\n");
			return(undef);
		};

	if($confpath = $pndb_configs{"$hostname,$sitename"}) {
		return($confpath);
	} else {
		# If we're here, we didn't find an entry, return error
		warn("$me: no entry found for $hostname, $sitename\n");
		return(undef);
	}
}

#
# pndb_listsites:	function to list all sites registered in the pubnodes db
#					This can be useful if you are unsure of what may be the
#					currently used sites and are trying to troubleshoot problems.
#
# Arguments:		None
#
# Return value:		Array	(list of sitenames)
#					undef	On error
#

sub pndb_listsites {
	my (
		$index,
		$me,
		$key,
		$sitename,
		@sitelist,
		@sitelist_sorted,
		%pndb_configs,
	);

	$me = "EI::bNimble::pndb_listsites()";

	tie(%pndb_configs, $EI::bNimble::db_format, "$EI::bNimble::pndb_path/$EI::bNimble::configdb", O_RDONLY, 0777)
		or do {
			warn("$me: Unable to open $EI::bNimble::pndb_path/$EI::bNimble::configdb\n");
			return(undef);
		};

	@sitelist = keys(%pndb_configs);

	#
	# At this point, the values in @sitelist are actually strings of this form:
	# 
	#		"host,site"
	#
	# We need to trim out the "host," portion, then do a sort/unique on the entire array.
	#

	$index = 0;
	while($index <= $#sitelist) {
		$sitelist[$index] =~ s/[^,]*,//;
		$index++;
	}

	@sitelist_sorted = sort(@sitelist);

	#
	# Now unique @sitelist_sorted, which at this point contains *only* sitenames
	#

	$index = 0;
	while($index <= $#sitelist_sorted) {
		while($sitelist_sorted[$index] eq $sitelist_sorted[($index + 1)]) {

			# Trim out the second of the equal elements
			splice(@sitelist_sorted, $index, 1);
		}
		
		$index++;
	}

	return(@sitelist_sorted);
}

#
# pndb_listentries:	function to list the entire contents of the pubnodes db
#
# Arguments:		None (formatting left to the calling program)
#
# Return value:		Array, keys and values alternate.  Keys are split into separate
#					hostname and sitename elements.  So the array elements occur thusly:
#
#					host0, site0, conf0, host1, site1, conf1...hostn, siten, confn
#
#					undef	On error
#

sub pndb_listentries {
	my (
		$confpath,
		$hostname,
		$key,
		$me,
		$sitename,
		$value,
		@entries,
		%pndb_configs,
	);

	$me = "EI::bNimble::pndb_listentries()";

	tie(%pndb_configs, $EI::bNimble::db_format, "$EI::bNimble::pndb_path/$EI::bNimble::configdb", O_RDONLY, 0777)
		or do {
			warn("$me: unable to open $EI::bNimble::pndb_path/$EI::bNimble::configdb\n");
			return(undef);
		};

	while(($key, $value) = each(%pndb_configs)) {
		push(@entries, split(/,/, $key), $value);
	}

	return(@entries);
}

###########
# PUBNODES DB IMPORT/EXPORT SECTION
###########

#
# NOTE: For pure/basic text export, see pndb_listentries() in the previous section.
#

#
# pndb_exptxml:		function to export the contents of the pubnodes db to xml
#

#
# pndb_imptxml:		function to import the contents of the pubnodes db from xml
#					NOTE: not yet implemented, we need to figure out how to do this safely
#					and make it at least difficult to destroy the pubnodes db (although there
#					may in fact be cases where users will want to do this, for instance if
#					they need to (re)create it from scratch and have only the xml export with
#					which to work
#

#######################
# PNDB v2 Functions
#######################

#
# pndbDelConfig:	function to delete the bNimble configuration setting for a given systemRole
#
# Arguments:		string	rolename - the name of the systemRole
#
# Return value:		1 if successful, 0 otherwise
#

sub pndbDelConfig {
	my (
		$rolename,
		%results,
		@attrs,
		$key,
		$val,
	);

	if( !($rolename = shift)) {
		return(0);
	}

	dsSearchRoles(%results, $rolename, @attrs);

}

#
# pndbGetConfig:	function to retrieve the config path for a given systemRole
#
# Arguments:		string rolename
#
# Return value:		string - the config path if successful, undef otherwise
#

sub pndbGetConfig {
	my (
		$rolename,
		%results,
		@attrs,
		$roleVarVal,
		$rvValue,
		$key,
		$val,
	);

	if( !($rolename = shift)) {
		return(undef);
	}

	@attrs = ("rolevar");

	dsSearchRoles(%results, $rolename, @attrs);

	$roleVarVal = ${$results{$rolename}}{"rolevar"};

	foreach $rvValue (@{$roleVarVal}) {
		($key, $val) = split(/=/, $rvValue);
		if($key eq "bNimbleConf") {
			return($val);
		}
	}

	return(undef);
}

#
# pndbSetConfig:	function to set the config for a given systemRole
#
# Arguments:		string	rolename - the name of the systemRole
#					string	confpath - the path to the bNimble config (relative to the config root)
#
# Return value:		1 if successful, 0 otherwise
#

sub pndbSetConfig {
	my (
		$rolename,
		$confpath,
		%results,
		@attrs,
		$roleVarVal,
		@roleVarValList,
		$key,
		$key2,
		$val,
		$val2,
		$rvIndex,
		%newAttrs,
	);

	if( !($rolename = shift)) {
		return(0);
	}

	if( !($confpath = shift)) {
		return(0);
	}

	#
	# Connect with update privs
	#

	dsConnect("cn=root","l00kM3") or die "Error: dsConnect failed: $dsErrMsg\n";

	#
	# Get the value of roleVar
	#

	@attrs = ("rolevar");
	dsSearchRoles(%results, $rolename, @attrs);

	$roleVarVal = ${$results{$rolename}}{"rolevar"};

	#
	# Check that we're dealing with an arrayref, then update if so
	#


	if(ref($roleVarVal) eq "ARRAY") {
	
		#
		# Find the current bNimbleConf value, delete it, add the new one
		#
	
		for($rvIndex = 0; $rvIndex <= $#{$roleVarVal}; $rvIndex++) {
			($key, $val) = split(/=/, ${$roleVarVal}[$rvIndex]);
			if($key eq "bNimbleConf") {
				splice(@{$roleVarVal}, $rvIndex, 1);
				push(@{$roleVarVal}, "bNimbleConf=$confpath");
				last;
			}
		}
	
		$newAttrs{"rolevar"} = [@{$roleVarVal}];
		dsUpdateRole($rolename, INHERIT_NONE, %newAttrs);
	
		return(1);
	} else {
		return(0);
	}
}
