#!/usr/local/bin/perl -w
use Data::Dumper;
use FindBin;
use lib (
          "/$FindBin::Bin/lib",       "/$FindBin::Bin/../lib",
          "/$FindBin::Bin/../../lib", "$FindBin::Bin",
          "/lfs/system/tools/configtools/lib"
);
use EI::Impact::session;
my $impact = EI::Impact::session->new;
$impact->debug($ENV{debug}) if defined $ENV{debug};
my $queue  = {};
my $irc    = $ARGV[0] || '';
my $i      = 0;

if ( $impact->login() ) {
	print "logged into Impact\n";
   $impact->debug( $ENV{'debug'} ) if defined $ENV{debug};
   my @queue = $impact->my_queue();
	print scalar @queue ." tickets to process\n";
   # loop thru queue
   foreach my $ticket ( sort @queue ) {
      my $ticketnum = $ticket->{'Request#'};
      next if $ticketnum =~ /RESHC\d+/i;    # Ignore changes
      print "processing $ticketnum\n" if $ENV{'debug'};
      my ( $projectid, $ticketid, $activitylevel, $activityname ) =
        ( split( /\|/, $ticket->{'_control'} ) )[ 0, 2, 4, 5 ];
      next if !defined $ticketid;
      if ( $ticketnum =~ /RESH[IPR]\d+/i && $activityname =~ /EI-Application/i ) {
         my @tasks = $impact->tasks($ticketnum);
         my $assign;
         foreach my $task (@tasks) {
            $assign = $task->{assigned_to};

            #            print "\t$ticketnum: $task->{'task_name'} : $task->{assigned_to}\n";
            if ( $task->{'task_name'} =~ /Assign/i ) {
               last;
            }
         } ## end foreach my $task (@tasks)
         if ( defined $assign && defined $ticketid ) {
            push @{ $queue->{$assign} }, $ticketid;
         }
         else {
            print Dumper($ticket);
            print '-' x 80 . "\n";
            print Dumper( \@tasks );
            exit;
         } ## end else [ if ( defined $assign &&...)]
      } ## end if ( $ticketnum =~ /RESH[IPR]\d+/i...)
      else {
         print "Ignoring $ticketnum : activityname $activityname != EI-Application\n";
      }

      #      last if $i++ > 20;
   } ## end foreach my $ticket ( sort @queue)
   inform("Apps team Impact Queue status");
   inform( sprintf "Unassigned: %s", join( " ", sort @{ $queue->{'RESH QUEUE EI-Application Team'} } ) )
     if defined $queue->{'RESH QUEUE EI-Application Team'};
   delete $queue->{'RESH QUEUE EI-Application Team'};
   inform("Assigned tickets still on queue");
   inform("-------------------------------");
   foreach my $assignee (sort keys %{$queue} ) {
      inform( sprintf "%-30s: %s\n", $assignee, join( " ",sort @{ $queue->{$assignee} } ) );
   }
} ## end if ( $impact->login() )

sub inform {
   my $msg = shift;
	chomp $msg;
   print "$msg\n";
   if ( $irc eq lc('irc') ) {
	  print "sending via IRC\n";
      system("/$FindBin::Bin/sendIRC.pl", "-msg", "$msg","-key", "appsimpact","-channel","#appteam");
   }
} ## end sub inform
