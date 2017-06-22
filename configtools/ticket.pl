#!/usr/local/bin/perl -w
use strict;
use Data::Dumper;
use FindBin;
use lib (
          "/$FindBin::Bin/lib",       "/$FindBin::Bin/../lib",
          "/$FindBin::Bin/../../lib", "$FindBin::Bin",
          "/lfs/system/tools/configtools/lib"
);

use warnings;
use strict;
use EI::Impact::session;
my $debug = $ENV{'debug'} || 0;
if ( @ARGV < 6 ) {
   print "Missing parms !\n";
   syntax();
}
my %team_names = (
                   APPS   => 'Application Team',
                   IO     => 'Infrastructure Ops Team',
                   EST    => 'Events mgmt Monitoring',
                   WM     => 'Webmasters',
                   NET    => 'Networking',
                   PE     => 'Project Execs',
                   MON    => 'Events mgmt Monitoring',
                   SD     => 'Service Desk',
                   IMPACT => 'IMPACT support'
);


my ( $project, $customer, $activity, $category, $subcategory, $subject, $details ) = @ARGV;
my $config = config();
my $sr = $ENV{'SR'} || '';
my $severity;

#======================================================
# Handle the ticket type parm
#======================================================
if ( defined $project ) {
   ( $project, $severity ) = split( /:/, $project );
   if ( uc($project) eq 'SR' ) {
      $project = 'RESH.*4.*Service Request';
   }
   elsif ( uc($project) eq 'I' ) {
      $project = 'Incident';
   }
   else {
      print "$project is an invalid type,  <SR|I>\n";
      exit;
   }
   $severity = 4 if !defined $severity;
   if ( $severity < 1 || $severity > 4 ) {
      print "Severity must be 1,2,3 or 4\n";
      exit;
   }
   print "Type: $project  Severity: $severity\n" if $debug;
}
else {
   print "Missing type parm\n";
   syntax();
}
my $firstname = $ENV{FIRSTNAME} || $ENV{I_FIRSTNAME} || config('FIRSTNAME');
my $lastname  = $ENV{LASTNAME}  || $ENV{I_LASTNAME}  || config('LASTNAME');

#======================================================
# Handle the ticket team parm
#======================================================
my $owner;
( $activity, $owner ) = split( /:/, $activity );
$activity = resolve_activity($activity);
$owner = 'RESH QUEUE EI-' . $activity if !defined $owner;
print "Activity: $activity  Owner: $owner\n" if $debug;

#======================================================
# Handle the details parm
# value can come from a number of sources
# 1. the parm can be a filename
# 2. if stdin is piped then read from stdin
# 3. the value of parm 7
# 4. if non of the above use the subject
#================================================
#TODO handle aleternative sources
if ( defined $details ) {
   if ( -r $details ) {
      $details = `cat $details`;
   }
}
else {
   # try to read from stdin
   if ( ! -t STDIN ) {
      print "Read from STDIN\n";
   while (<STDIN>) {
                       chomp;
                       next unless -f $_;      # ignore specials
                       $details .= $_;
                   }
   }     
   $details = $subject if !defined $details;
}

my $completeby= $ENV{'COMPLETE_BY'} || undef;

my $site = $ENV{I_SITE} || config('SITE') || 'Test';
my $session = EI::Impact::session->new( SITE=>$site,SILENT=>0 );
if ( $session->login ) {
   $session->debug(3);
   if (
        my $ticket = $session->create_ticket(
                                              ACTIVITY          => $activity,
                                              PROJECT           => $project,
                                              CONTACT_FIRSTNAME => $firstname,
                                              CONTACT_LASTNAME  => $lastname,
                                              CUSTOMER          => $customer,
                                              SEVERITY          => $severity,
                                              OWNER             => $owner,
                                              CATEGORY          => $category,
                                              SUBCATEGORY       => $subcategory,
                                              SUBJECT           => $subject,
                                              DESCRIPTION       => $details,
                                              COMPLETEBY       => $completeby,
        )
     )
   {
      print "$ticket created\n";
      if ( defined $sr ) {
         $session->link_tickets($ticket,$sr);
      }
   }
   else {
      exit 4;
   }
}

sub syntax {
   print <<EOF;
 Function: Create impact Incident and Service Request tickets from the command line
 Syntax:
   ticket.sh <type:severity> <customer> <team>[:name] <category> <subcategory> "<subject>" ("<details>")
or
   SR=<request#> ticket.sh <type> <customer> <team>[:name] <category> <subcategory> "<subject>" ("<details>")
EOF
   exit 4;
}

sub resolve_activity {
   my $activity = shift;
   $activity = uc($activity);
   return $team_names{$activity} if defined $team_names{$activity};
   foreach my $key ( keys %team_names ) {
      if ( $team_names{$key} =~ /$activity/ix ) {
         print "$activity matched $key\n";
         return $team_names{$key};
      }
   }
   print "Activity not found\n";
   return;
}

#=========================================================================
# Read configuration file if it exists
#=========================================================================
sub config {
   my $keyword = shift;
   
   if ( !defined $config ) {
      my $XML = $ENV{'TICKET_CONFIG'} || glob('.impact_test.xml');
      if ( defined $XML &&  -r "$XML" ) {
         open "XML", "<", "$XML";
         {
            local $/;
            $config = <XML>;
         }
         close XML;
      }
   }
   
   if ( defined $keyword && defined $config &&  $config =~ /\<$keyword\>([^\<]+?)\</ismx ) {
      return $1;
   }
   else {
      return;
   }
}
