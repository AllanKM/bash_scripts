package EI::Impact::session;
#====================================
# $Revision: 1.5 $
#====================================
use strict;
use FindBin;
use lib (
          "$FindBin::Bin/lib",
          "$FindBin::Bin/../lib", "$FindBin::Bin/../../lib",
          "/lfs/system/tools/configtools/lib"
);
use strict;
use URI::Escape;
use Data::Dumper;
use FileHandle;
use MIME::Base64;
use EI::Curl::browser;
use EI::Impact::pages;
use Term::ANSIColor;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use constant TEST => 'https://testimpact.rny.ihost.com/IM/scripts/';
use constant PROD => 'https://impact-enterprise.rny.ihost.com/IM/scripts/';

sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $opts;
   %$opts = @_;
   my $PID = $$;
   my $self = {
      SILENT => $opts->{'SILENT'}
        || $ENV{'SILENT'}
        || 0,
      DEBUG => $opts->{DEBUG}
        || $ENV{DEBUG}
        || 0,
      RESOURCEID    => undef,                       # Impact number of the logged in user
      PROJECTID     => undef,
      PROJECTS      => undef,                       # project and folder details
      REQUESTID     => undef,
      REQUESTPREFIX => undef,
      TICKET        => undef,
      CATEGORYID    => undef,
      ACTIVE        => 0,                           # logged on flag
      BROWSER       => EI::Curl::browser->open(),
   };
   $self->{URL} = $opts->{'URL'} || $ENV{URL} || __config( $self, 'URL' ) || 'PROD';
   $self->{USERID} =
        $opts->{'USERID'}
     || $ENV{USERID}
     || $ENV{I_USERID}
     || __config( $self, 'USERID' )
     || __prompt("Impact Userid:")
     || 'auto-ticket';
   $self->{PASSWORD} =
        $opts->{'PASSWORD'}
     || $ENV{PASSWORD}
     || $ENV{I_PASSWORD}
     || __decode($self)
     || __config( $self, 'PASSWORD' )
     || __prompt("$self->{USERID} password:")
     || undef;

   # convert site name to the url
   if ( uc( $self->{URL} ) eq "TEST" ) {
      $self->{'URL'} = TEST;
   }
   else {
      $self->{'URL'} = PROD;
   }
   bless( $self, $class );
   return $self;
} ## end sub new

#--------------------------------------------------------
# Read config xml if it exists and return matching values.
#--------------------------------------------------------
sub __config {
   my ( $self, $keyword ) = @_;
   if ( !defined $self->{CONFIG} ) {
      my $XML = $ENV{'TICKET_CONFIG'} || glob('.impact_test.xml');
      if ( defined $XML && -r "$XML" ) {
         open "XML", "<", "$XML";
         {
            local $/;
            $self->{CONFIG} = <XML>;
         }
         close XML;
      } ## end if ( -r "$XML" )
   } ## end if ( !defined $self->{...})
   if ( defined $self->{CONFIG} && defined $keyword && $self->{CONFIG} =~ /\<$keyword\>([^\<]+?)\</ismx ) {
		print "$keyword set to $1 from config\n";
      return $1;
   }
   else {
      return;
   }
} ## end sub __config

#==================================================================
# lookup password for auto-ticket id
#==================================================================
sub __decode {
   my $self = shift;
   if ( lc( $self->{USERID} ) eq 'auto-ticket' ) {
      if ( -r '/etc/.impact' ) {
         open PW, '<', '/etc/.impact' or die "$!\n";
         my $pw;
         {
            local $/;
            $pw = <PW>;
            chomp $pw;
         }
         $pw = decode_base64($pw);
         chomp $pw;
         return $pw;
      } ## end if ( -r '/etc/impact' )
      else {
         print "Cannot read pw store\n";
      }
   } ## end if ( lc( $self->{USERID...}))
   return;
} ## end sub __decode

#==========================================================================
# Link tickets
#==========================================================================
sub link_tickets {
   my $self = shift;
   printf STDERR "%s -> %s at %d\n", ( caller(0) )[ 0, 3, 2 ] if $self->debug;
   if ( $self->active ) {
      my ( $ticket1, $ticket2 ) = @_;
      if ( defined $ticket1 && $ticket1 =~ /resh[cipr]\d+/i && defined $ticket2 && $ticket2 =~ /resh[cipr]\d+/i ) {
         my ( $ticket1, $ticket2 ) = @_;
         print STDERR "Linking $ticket2 to $ticket1\n" if $self->debug;
         my ( $parent_projectid, $parent_number ) = $self->RetrieveRequestList( uc($ticket1) );
         return if !defined $parent_projectid;
         my ( $linked_projectid, $linked_number ) = $self->RetrieveRequestList( uc($ticket2) );
         return if !defined $parent_projectid;
         return $self->PersistRequestLinkAdd( $parent_projectid, $parent_number, $linked_projectid, $linked_number );
      } ## end if ( defined $ticket1 ...)
      else {
         print "Must supply 2 ticket numbers in the format RESH[CIPR]nnnn\n";
         return;
      }
   } ## end if ( $self->active )
} ## end sub link_tickets

#==================================================================
# Add a close task to a ticket
#==================================================================
sub add_task {
   my $self = shift;
   printf STDERR "%s -> %s at %d\n", ( caller(0) )[ 0, 3, 2 ] if $self->debug;
   my $opts = {};
   if ( ref $_[0] eq 'HASH' ) {
      $opts = shift;
   }
   else {
      %$opts = @_;
   }
   required_opts( $opts, qw/TICKET TASK DESCRIPTION/ ) || return;
   my ( $projectid, $requestid, $ticket, $requestprefix ) = $self->RetrieveRequestList( uc( $opts->{TICKET} ) );
   return if !defined $projectid;

   # get valid task codes
   my $taskcode = $self->RequestTasksToImplement( $projectid, $requestid, $requestprefix, $opts->{TASK} ) || return;
   my $post = $self->AddEditRequestTask( $requestid, $projectid, $requestprefix, $taskcode, $opts->{DESCRIPTION} );
   if ( defined $post ) {
      if ( $post->{Task} =~ /Rslv/ ) {
         $post->{ResolutionCategoryAssociation} = $post->{Category} . ':' . $post->{SubCategory};
         $post->{ResolutionId}                  = $opts->{RESOLUTION};
      }
      $post->{Description} = uri_escape( $opts->{DESCRIPTION} );
      print STDERR "*" x 40 . "\n" if $self->debug;
      print STDERR __hash($post) if $self-> debug;
      return $self->NewRequestTask($post);
   } ## end if ( defined $post )
   else {
      print "post is null\n";
   }
} ## end sub add_task

sub required_opts {
   my $opts          = shift;
   my @required_opts = @_;
   foreach my $opt (@required_opts) {
      if ( !defined $opts->{$opt} ) {
         print "Missing $opt\n";
         return;
      }
   } ## end foreach my $opt (@required_opts)
   return 1;
} ## end sub required_opts

#==================================================================
# Set CLOSE Extended attribute
#==================================================================
sub close_ticket {
   my $self = shift;
   my %opts = @_;
   required_opts( \%opts, qw/TICKET CLOSE_CODE/ ) || return;
   my $ticket = $opts{TICKET};
   if ( my $post = $self->ticket_details($ticket) ) {
		$post->{Subject} = uri_escape($post->{Subject});
      if ( $post->{RequestStatus} !~ /closed/i ) {
         if ( $ticket =~ /reshi/i ) {
            required_opts( \%opts, qw/TICKET CAUSE_CODE CLOSE_CODE RESOLUTION_CODE TEXT/ ) || return;
            my ( $resolutionid, $rtext ) = $self->browser->option( 'SelectResolution', $opts{RESOLUTION_CODE} );
            return if !defined $resolutionid;
            my ( $causecode, $catext ) = $self->browser->option( 'StandardIncidentCauseCodes', $opts{CAUSE_CODE} );
            return if !defined $causecode;
            my ( $closecode, $cltext ) = $self->browser->option( 'StandardCloseCodes', $opts{CLOSE_CODE} );
            return if !defined $closecode;
            $post->{EAAStandardIncidentCauseCodes} = uri_escape($causecode);
            $post->{EAAStandardCloseCodes}         = uri_escape($closecode);
            $post->{ResolutionId}                  = uri_escape($resolutionid);
            $self->ResourceFinalAdd($post) || return;
            $self->add_task(
                             TICKET      => $ticket,
                             TASK        => 'Request Resolved',
                             DESCRIPTION => $opts{TEXT},
                             RESOLUTION  => $resolutionid
            ) || return;
            $self->add_task( TICKET => $ticket, TASK => 'Request Closed', DESCRIPTION => $opts{TEXT} ) || return;
            return 1;
         } ## end if ( $ticket =~ /reshi/i)
         elsif ( $ticket =~ /reshp/i ) {
            required_opts( \%opts, qw/TICKET CAUSE_CODE CLOSE_CODE RESOLUTION_CODE TEXT/ ) || return;
            my ( $resolutionid, $rtext ) = $self->browser->option( 'SelectResolution', $opts{RESOLUTION_CODE} );
            return if !defined $resolutionid;
            my ( $causecode, $catext ) = $self->browser->option( 'StandardIncidentCauseCodes', $opts{CAUSE_CODE} );
            return if !defined $causecode;
            my ( $closecode, $cltext ) = $self->browser->option( 'StandardCloseCodes', $opts{CLOSE_CODE} );
            return if !defined $closecode;
            $post->{EAAStandardIncidentCauseCodes} = uri_escape($causecode);
            $post->{EAAStandardCloseCodes}         = uri_escape($closecode);
            $post->{ResolutionId}                  = uri_escape($resolutionid);
            $self->ResourceFinalAdd($post) || return;
            $self->add_task(
                             TICKET      => $ticket,
                             TASK        => 'Request Resolved',
                             DESCRIPTION => uri_escape($opts{TEXT}),
                             RESOLUTION  => $resolutionid
            ) || return;
            $self->add_task( TICKET => $ticket, TASK => 'Request Closed', DESCRIPTION => $opts{TEXT} ) || return;
            return 1;
         }
         elsif ( $ticket =~ /reshr/i ) {
            required_opts( \%opts, qw/TICKET CLOSE_CODE TEXT/ ) || return;
            my ( $closecode, $text ) = $self->browser->option( 'StandardRFSCloseCodes', $opts{CLOSE_CODE} );
            return if !defined $closecode;
            
            $post->{EAAStandardRFSCloseCodes} = uri_escape($closecode);
            $self->ResourceFinalAdd($post) || return;
            $self->add_task( TICKET => $ticket, TASK => 'Request Closed', DESCRIPTION => $opts{TEXT} );
            return 1;
         } ## end elsif ( $ticket =~ /reshr/i)
         elsif ( $ticket =~ /reshc/i ) {
            required_opts( \%opts, qw/TICKET CLOSE_CODE TEXT/ ) || return;
            my ( $closecode, $text ) = $self->browser->option( 'IRVChangeCompletionCode', $opts{CLOSE_CODE} );
            return if !defined $closecode;
            $post->{EAAIRVChangeCompletionCode} = uri_escape($closecode);
            $self->ResourceFinalAdd($post) || return;
            $self->add_task( TICKET => $ticket, TASK => 'Change Closed', DESCRIPTION => $opts{TEXT} ) || return;
            return 1;
         } ## end elsif ( $ticket =~ /reshc/i)
      } ## end if ( $post->{RequestStatus...})
      else {
         print "$ticket already closed\n";
         return;
      }
   } ## end if ( my $post = $self->ticket_details...)
} ## end sub close_ticket

#==========================================================================
# Create ticket
#==========================================================================
sub create_ticket {
   my $self = shift;
   printf STDERR "%s -> %s at %d\n", ( caller(0) )[ 0, 3, 2 ] if $self->debug;
   if ( $self->active ) {
      my $opts = {};
      if ( ref $_[0] eq 'HASH' ) {
         $opts = shift;
      }
      else {
         %$opts = @_;
      }
      my @required_opts = qw/SUBJECT DESCRIPTION ACTIVITY CATEGORY SUBCATEGORY CUSTOMER OWNER  PROJECT/;
      foreach my $opt (@required_opts) {
         if ( !defined $opts->{$opt} ) {
            print "Missing $opt\n";
            return;
         }
      } ## end foreach my $opt (@required_opts)
      my ( $cb_day, $cb_month, $cb_year, $cb_hour, $cb_sec, $cb_min, $scheduledcompletionflag );

      # Get current time
      my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
      my $o_ampm = 'AM';
      if ( $hour > 12 ) {
         $o_ampm = 'PM';
         $hour -= 12;
      }
      my $cb_ampm = 'AM';
      $cb_sec = '00';
      if ( defined $opts->{COMPLETEBY} ) {
         if ( $opts->{COMPLETEBY} =~ /(\d+)\/(\d+)\/(\d+)\s(\d+):(\d+)/ix ) {
            ( $cb_year, $cb_month, $cb_day, $cb_hour, $cb_min ) = $opts->{COMPLETEBY} =~ /
         (\d+)\/(\d+)\/(\d+)\s(\d+):(\d+)
      /ix;
            $scheduledcompletionflag = 'Y';
         } ## end if ( $opts->{COMPLETEBY...})
         else {
            print "Invalid format for COMPLETEBY ( yyyy/mm/dd hh:mm )\n";
            return;
         }
      } ## end if ( defined $opts->{COMPLETEBY...})
      else {
         $cb_day   = sprintf "%02d", $mday;
         $cb_hour  = sprintf "%02d", $hour;
         $cb_min   = sprintf "%02d", $min;
         $cb_month = sprintf "%02d", $mon + 1;
         $cb_sec   = '00';
         $cb_year  = sprintf "%04d", $year + 1900;
         $scheduledcompletionflag = 'N';
      } ## end else [ if ( defined $opts->{COMPLETEBY...})]
      if ( $cb_hour > 12 ) {
         $cb_ampm = 'PM';
         $cb_hour -= 12;
      }
      $self->firstname(    $self->firstname
                        || $ENV{FIRSTNAME}
                        || $ENV{I_FIRSTNAME}
                        || __config( $self, 'FIRSTNAME' )
                        || undef );
      $self->lastname(    $self->lastname
                       || $ENV{LASTNAME}
                       || $ENV{I_LASTNAME}
                       || __config( $self, 'LASTNAME' )
                       || undef );

      # 1. get new ticket page
      if ( my $post = $self->ResourceAddRequest() ) {
         my $contactid = $self->RetrievePotentialContacts( $self->firstname, $self->lastname ) || return;
         my ( $projectid, $folderid ) = $self->RetrieveContactProjects( $contactid, $opts->{PROJECT}, $opts->{FOLDER} );
         return if ( !defined $projectid || !defined $folderid );
         my $activityid = $self->RetrieveActivityLevels( $projectid, $opts->{ACTIVITY} ) || return;
         my $categoryid = $self->RetrieveCategories( $projectid, $opts->{CATEGORY} ) || return;
         my $subcategoryid = $self->RetrieveSubCategories( $projectid, $categoryid, $opts->{SUBCATEGORY} )
           || return;
         my $requestid = '-2147483648';    # Impact code for not assigned
         $self->RequestEAEmbedded( $projectid, $requestid, $categoryid, $subcategoryid, $contactid );
         my ($customerid) = $self->browser->option( 'RESHCUSTOMER', $opts->{CUSTOMER} );
         return if !defined $customerid;
         my $ownerid =
           $self->RetrieveResourcesToAssign( $activityid, $projectid, $folderid, $self->resourceid, $categoryid,
                                             $subcategoryid, $opts->{OWNER} )
           || return;
         $post->{ActivityLevelId}            = $activityid;
         $post->{CategoryCode}               = $categoryid;
         $post->{ContactId}                  = $contactid;
         $post->{Description}                = uri_escape( $opts->{DESCRIPTION} );
         $post->{EAARESHCUSTOMER}            = $customerid;
         $post->{FolderID}                   = $folderid;
         $post->{OpenedAMPM}                 = $o_ampm;
         $post->{OpenedDay}                  = sprintf "%02d", $mday;
         $post->{OpenedHour}                 = sprintf "%02d", $hour;
         $post->{OpenedMinute}               = sprintf "%02d", $min;
         $post->{OpenedMonth}                = sprintf "%02d", $mon + 1;
         $post->{OpenedSeconds}              = sprintf "%02d", $sec;
         $post->{OpenedYear}                 = sprintf "%04d", $year + 1900;
         $post->{OwningResource}             = $ownerid;
         $post->{Priority}                   = '4';
         $post->{ProjectId}                  = $projectid;
         $post->{ReceivedAMPM}               = $post->{OpenedAMPM};
         $post->{ReceivedDay}                = $post->{OpenedDay};
         $post->{ReceivedHour}               = $post->{OpenedHour};
         $post->{ReceivedMinute}             = $post->{OpenedMinute};
         $post->{ReceivedMonth}              = $post->{OpenedMonth};
         $post->{ReceivedSeconds}            = $post->{OpenedSeconds};
         $post->{ReceivedYear}               = $post->{OpenedYear};
         $post->{ScheduledCompleteByAMPM}    = $cb_ampm;
         $post->{ScheduledCompleteByDay}     = $cb_day;
         $post->{ScheduledCompleteByHour}    = $cb_hour;
         $post->{ScheduledCompleteByMinute}  = $cb_min;
         $post->{ScheduledCompleteByMonth}   = $cb_month;
         $post->{ScheduledCompleteBySeconds} = $cb_sec;
         $post->{ScheduledCompleteByYear}    = $cb_year;
         $post->{ScheduledCompletionFlag}    = $scheduledcompletionflag;
         $post->{SubcategoryCode}            = $subcategoryid;
         $post->{Subject}                    = uri_escape( $opts->{SUBJECT} );
         $post->{ResolvedImmediate}          = 'false';
         $post->{SaveInProgress}             = 'true';
         $post->{Severity}                   = '3';
         $post->{Source}                     = 'Phone';
         my $ticket = $self->ResourceFinalAdd($post) || return;
         return $ticket->[1] . $ticket->[0];
      } ## end if ( my $post = $self->ResourceAddRequest...)
      else {
         print "Failed to get new request page\n";
         return;
      }
   } ## end if ( $self->active )
   else {
      print "Not logged in\n";
      exit;
   }
} ## end sub create_ticket

#==========================================================================
# perform Impact login
#==========================================================================
sub login {
   my $self = shift;
   printf STDERR "%s -> %s at %d\n", ( caller(0) )[ 0, 3, 2 ] if $self->debug;
   if ( $self->LoginPage ) {    # found field for password entry
      if ( $self->Login ) {
         # get resourcename/id for logged in user
         if ( $self->ResourceAddRequestClassic ) {
            print STDERR "Login successful\n" if $self->debug;
            return 1;
         }
         else {
            print "Login failed\n";
            return;
         }
      } ## end if ( $self->Login )
   } ## end if ( $self->LoginPage )
   return;
} ## end sub login

#==========================================================================
# List tickets on my queue
#==========================================================================
sub my_queue {
   my $self = shift;
   printf STDERR "%s -> %s at %d\n", ( caller(0) )[ 0, 3, 2 ] if $self->debug;
   if ( $self->active ) {
      return $self->RequestQueueReport;
   }
   else {
      print "Not logged on\n";
      return;
   }
} ## end sub my_queue

#==========================================================================
# Get Ticket details
#==========================================================================
sub ticket_details {
   my $self = shift;
   printf STDERR "%s -> %s at %d\n", ( caller(0) )[ 0, 3, 2 ] if $self->debug;
   if ( $self->active ) {
      my $ticket = shift;
      if ( !$ticket ) {
         print STDERR RED BOLD "Missing ticket number\n";
         return;
      }

      # check ticket exists
      if ( my ( $projectid, $requestid, $ticket, $requestprefix ) = $self->RetrieveRequestList($ticket) ) {
         if ( my $post = $self->ResourceRequestDetails( $projectid, $requestid, $requestprefix ) ) {
            if (
                 my $eapost = $self->RequestEAEmbedded(
                                                        $projectid,            $requestid,
                                                        $post->{CategoryCode}, $post->{SubcategoryCode},
                                                        $post->{ContactId}
                 )
              ) {
               %$post = ( %$post, %$eapost );
               return $post;
            } ## end if ( my $eapost = $self...)
            else {
               print "failed to get Extended Attributes\n";
               return;
            }
         } ## end if ( my $post = $self->ResourceRequestDetails...)
         else {    # no form to post !
            return;
         }
      } ## end if ( my ( $projectid, ...))
      else {
         return;
      }
   } ## end if ( $self->active )
   else {
      print "Not logged on\n";
      return;
   }
} ## end sub ticket_details

#================================================================================
# Return liust of tasks for a ticket
#================================================================================
sub tasks {
   my $self = shift;
   printf STDERR "%s -> %s at %d\n", ( caller(0) )[ 0, 3, 2 ] if $self->debug;
   if ( $self->active ) {
      my ($ticket) = @_;
      if ( $ticket =~ /resh[cipr]\d+/i ) {
         if ( my ( $projectid, $requestid, $ticket, $requestprefix ) = $self->RetrieveRequestList($ticket) ) {
            return $self->RequestTasks( $requestid, $projectid );
         }
         else {
            print "Missing or invalid projectid or requestid\n";
            return;
         }
      } ## end if ( $ticket =~ /resh[cipr]\d+/i)
      else {
         print "Missing or invalid ticket number\n";
         return;
      }
   } ## end if ( $self->active )
   else {
      print "Not logged on\n";
      return;
   }
} ## end sub tasks

#=========================================================
# print a pretty hash
#=========================================================
BEGIN {
   my $depth = 0;

   sub __hash {
      my ( $self, $hash ) = @_;
      my $str = '';
      foreach my $key ( sort keys %$hash ) {
         if ( ref $hash->{$key} eq "HASH" ) {
            $str .= "\t" x $depth . " $key => {\n";
            $depth++;
            $str .= $self->__hash( $hash->{$key} );
            $str .= "\t" x $depth . "}\n";
            $depth--;
         } ## end if ( ref $hash->{$key}...)
         elsif ( ref $hash->{$key} eq "ARRAY" ) {
            $str .= "\t" x $depth . " $key => [\n";
            $depth++;

            #            $str .= $self->Array( $hash->{$key} );
            $str .= "\t" x $depth . "]\n";
            $depth--;
         } ## end elsif ( ref $hash->{$key}...)
         else {
            if ( defined $hash->{$key} ) {
               $str .= "\t" x $depth . $key . " => " . $hash->{$key} . "\n";
            }
            else {
               $str .= "\t" x $depth . $key . " => ''\n";
            }
         } ## end else [ if ( ref $hash->{$key}...)]
      } ## end foreach my $key ( sort keys...)
      return $str;
   } ## end sub __hash
} ## end BEGIN

#==========================================================================
# Perform search for tickets
#==========================================================================
sub search {
   my $self = shift;
   printf STDERR "%s -> %s at %d\n", ( caller(0) )[ 0, 3, 2 ] if $self->debug;
   my %opts = @_;
   if ( $self->active ) {
      if ( $opts{'TEXT'} ) {
         return $self->RetrieveSearchedRequests( $opts{TEXT} );
      }
      else {
         print "Missing TEXT=> 'text to search for'\n";
         return;
      }
   } ## end if ( $self->active )
   else {
      print "Not logged in\n";
      return;
   }
} ## end sub search

#********************************************************************************************************
#********************************************************************************************************
#********************************************************************************************************
#********************************************************************************************************
#********************************************************************************************************
#==========================================================================
# Browser object get/set - pointer to curl object
#==========================================================================
sub browser {
   my $self = shift;
   $self->{BROWSER} = shift if @_;
   $self->{BROWSER};
}

#==========================================================================
# Logged on flag get/set
#==========================================================================
sub active {
   my $self = shift;
   $self->{ACTIVE} = shift if @_;
   $self->{ACTIVE};
}

#==========================================================================
# Silent flag get/set
#==========================================================================
sub silent {
   my $self = shift;
   $self->{SILENT} = shift if @_;
   $self->{SILENT};
}

#==========================================================================
# Debug flag get/set
#==========================================================================
sub debug {
   my $self = shift;
   if (@_) {
      $self->{_debug} = shift;
      $self->browser->debug($self->{_debug}) if $self->{_debug} > 1;
   }
   $self->{_debug};
} ## end sub debug

#==========================================================================
# URL get/set
#==========================================================================
sub url {
   my $self = shift;
   $self->{URL} = shift if @_;
   $self->{URL};
}

#==========================================================================
# Resourcename get/set
#==========================================================================
sub resourcename {
   my $self = shift;
   $self->{RESOURCENAME} = shift if @_;
   $self->{RESOURCENAME};
}

#==========================================================================
# Resourceid get/set
#==========================================================================
sub resourceid {
   my $self = shift;
   $self->{RESOURCEID} = shift if @_;
   $self->{RESOURCEID};
}

#==========================================================================
# ticket get/set
#==========================================================================
sub ticket {
   my $self = shift;
   $self->{TICKET} = shift if @_;
   $self->{TICKET};
}

#==========================================================================
# firstname get/set
#==========================================================================
sub firstname {
   my $self = shift;
   $self->{FIRSTNAME} = shift if @_;
   $self->{FIRSTNAME};
}

#==========================================================================
# lastname get/set
#==========================================================================
sub lastname {
   my $self = shift;
   $self->{LASTNAME} = shift if @_;
   $self->{LASTNAME};
}

#--------------------------------------------------------
# Print debugging information
#--------------------------------------------------------
sub __prompt {
   my ( $__promptstring, @validoptions ) = @_;
   $__promptstring = "Input ?" if !$__promptstring;
   $| = 1;    # force a flush after our print
   my $ans;
   print CYAN BOLD "$__promptstring: " if !@validoptions;
   if ( @validoptions > 1 ) {
      print CYAN BOLD "Select number for the $__promptstring to use:\n";
      for ( my $i = 0 ; $i < @validoptions ; $i++ ) {
         print CYAN BOLD $i+ 1 . ") $validoptions[$i]\n";
      }
   }
   else {
   }
   while ( $ans = <STDIN> ) {    # get the input from STDIN (presumably the keyboard)
      chomp $ans;
      return $validoptions[ $ans - 1 ] if @validoptions && $ans =~ /^\d+$/ && $ans <= @validoptions && $ans > 0;
      return $ans if !@validoptions;
      print "Invalid response\n";
   }
}
1;
