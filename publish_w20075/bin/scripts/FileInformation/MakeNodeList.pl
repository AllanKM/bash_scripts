#!/usr/local/bin/perl

use Getopt::Long;

$nodesconf="/.fs/system/config/nd-gen/allnodes.conf";


# Parse through command line arguements
my ( $port,$uri,$include_these,$exclude_these );
unless ( GetOptions ( "port=i" => \$port, 
		      "uri=s" => \$uri,
		      "include=s" => \$include_these,
		      "exclude=s" => \$exclude_these,
		    ) ) {
  usage();
}

my $fileinformation_root = "/fs/system/tools/publish/bin/scripts/FileInformation";
my $hostfile = "HostFile";

# Set defaults if nothing passed in on the command line
$port = '6328' unless ( $port );  
$uri = 'fileinformation' unless ( $uri );

if ( ($without_first_char) = $uri =~ /^\/(.*)$/ ) {
  $uri=$without_first_char
}

unless ( length $include_these > 2 ) {
  usage();
}

my @includes = split /\s+/, $include_these;
my @excludes = split /\s+/, $exclude_these;

print "Scanning allnodes.conf for these matches: [$include_these] \n";
print "Excluding these matches: [$exclude_these] \n";

if ( -r $nodesconf ) {
  # Get the %NODES hash from allnodes.conf file
  require $nodesconf;
} else {
  print "Could not locate $nodesconf file\n";
}


my %hostnames;
my $total_included = 0;

NODE: foreach my $node (sort keys(%NODES)) {

  my @roles = @{ $NODES{$node} };

 

  

 foreach my $exclude ( @excludes ) {
   
   if ( $node =~ /$exclude/i ) {
     print "[$total_included] --- [$node] exclude $exclude\n";
     next NODE; 
   }

   if ( grep /$exclude/i, @roles ) {
     print "[$total_included] --- [$node] exclude $exclude\n";
     next NODE; 
   }
 }
  
  foreach my $include ( @includes ) {

    if ( $node =~ /$include/i ) {
      $total_included++;
      print "[$total_included] +++ [$node] include $include\n";
      $hostnames{$node}=$include;
      next NODE;
    }
    
    if (grep /$include/i, @roles ) {
      $total_included++;
      print "[$total_included] +++ [$node] include $include\n";
      $hostnames{$node}=$include;
      next NODE;
    }
  }

}

open(HOSTFILE, ">$fileinformation_root/$hostfile") or die("$!: unable to open $fileinformation_root/$hostfile\n");

foreach $host (keys(%hostnames)){

  if( $host !~ /e1$/ ){
#	$host .= "e1";
  }

print HOSTFILE "http://$host:$port/$uri", "\n";

}

close (HOSTFILE);


sub usage {
  print "$0 --port [port number] --uri [uri] \\ \n";
  print "   --include [space seperated list of patterns to find in allnodes.conf] \\ \n";
  print "   --exclude [space seperated list of patterns from allnodes to exclude] \n";
  print "use double quotes around the lists\n\n";
  die "Exiting...\n";
}
