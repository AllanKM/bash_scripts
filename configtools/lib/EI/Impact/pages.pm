package EI::Impact::pages;

#===========================================
# $Revision: 1.3 $
#===========================================
use strict;
use FindBin;
use lib ("$FindBin::Bin/lib", "$FindBin::Bin/../lib", "$FindBin::Bin/../../lib", "/lfs/system/tools/configtools/lib");
use strict;
use URI::Escape;
use Data::Dumper;
use FileHandle;
use MIME::Base64;
use EI::Curl::browser;
$Term::ANSIColor::AUTORESET = 1;
use base 'Exporter';
our @EXPORT = qw(Login LoginPage RetrieveRequestList ResourceRequestDetails RequestEAEmbedded
  AddEditRequestTask RequestTasksToImplement NewRequestTask __set_post_values_from_form
  __set_post_values_from_javascript __form_to_post_data PersistRequestLinkAdd RequestQueueReport
  __get_javascript_settings __griddata RequestTasks ResourceAddRequest RetrievePotentialContacts
  RetrieveActivityLevels RetrieveCategories RetrieveSubCategories RetrieveResourcesToAssign
  __set_html_values_from_javascript __set_element_value
  ResourceFinalAdd ResourceAddRequestClassic RetrieveContactProjects RetrieveSearchedRequests __get_page_array);
our @EXPORT_OK;

#==========================================================================
# Impact Login
#==========================================================================
sub Login {
   my $self = shift;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   $self->browser->fetch_page(
                              'POST',
                              $self->url . 'Login.asp',
                              {
                                 GoToURL        => '',
                                 LoginAttempts  => '1',
                                 Password       => $self->{PASSWORD},
                                 UserID         => uri_escape($self->{USERID}),
                                 submit_request => ''
                              }
   );

   #   Location: https://testimpact.rny.ihost.com/IM/scripts/frame.asp?CallerMode=T
   if (   $self->browser->http_rc eq "302 Object Moved"
       && $self->browser->status =~ /location:.*?frame.asp\?CallerMode=T/i) {
      print "#### Login failed\n";
      print STDERR $self->browser->status                                        if $ENV{'debug'};
      print STDERR $self->browser->html                                          if $ENV{'debug'};
      print STDERR 'USER:' . $self->{USERID} . ' PW:' . $self->{PASSWORD} . "\n" if $ENV{'debug'};
      return;
   } ## end if ( $self->browser->http_rc...)
   else {
      $self->active(1);
      return 1;
   }
} ## end sub Login

#==================================================================
# Get post data for a new task
#==================================================================
sub AddEditRequestTask {
   my $self = shift;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   my ($requestid, $projectid, $requestprefix, $taskcode, $description) = @_;
   if (defined $requestid && defined $projectid && defined $requestprefix && defined $description) {
      $self->browser->fetch_page(
                                 'GET',
                                 $self->url . 'AddEditRequestTask.asp',
                                 {
                                    RequestID     => $requestid,
                                    ProjectID     => $projectid,
                                    RequestTaskId => '-2147483648',
                                    RequestPrefix => $requestprefix,
                                    TaskCode      => $taskcode,
                                 }
      );
      $self->__set_html_values_from_javascript(qr/Function\s+?InitPage\(\)(.*?)}\s*?\n*?\s*?function/isx);
      my $form = $self->browser->forms('frmAddEditTask');
      if ($form) {
         my $post = $self->__form_to_post_data($form);
         $post = $self->__set_post_values_from_form(
                                                    $post, 'form_0',
                                                    transforms => {
                                                                    SelectCategory       => 'Category',
                                                                    EndAMPM              => 'EndDateAMPM',
                                                                    EndDay               => 'EndDateDay',
                                                                    EndHour              => 'EndDateHour',
                                                                    EndMinute            => 'EndDateMinute',
                                                                    EndMonth             => 'EndDateMonth',
                                                                    EndSeconds           => 'EndDateSeconds',
                                                                    EndYear              => 'EndDateYear',
                                                                    StartAMPM            => 'StartDateAMPM',
                                                                    StartDay             => 'StartDateDay',
                                                                    StartHour            => 'StartDateHour',
                                                                    StartMinute          => 'StartDateMinute',
                                                                    StartMonth           => 'StartDateMonth',
                                                                    StartSeconds         => 'StartDateSeconds',
                                                                    StartYear            => 'StartDateYear',
                                                                    PlannedDurationTime  => 'PlannedTaskDurationTime',
                                                                    PlannedDurationUnits => 'PlannedTaskDurationUnits',
                                                                    TaskStatusCode       => 'TaskStatus',
                                                    }
         );
         foreach my $key (
            qw/AdditionalTime chkForceCategorization Resolution Billing AdditionalUnits TaskName BatchSize SearchType optResolutionCode optAssignedBilling optAdditionalTime chkRecording KBFolders Folder PlannedTaskDuration/
           ) {
            delete $post->{$key};
         }
         $post->{ActivityLevelId} = $post->{ActivityLevel};
         delete $post->{ActivityLevel};
         $post->{AssignedToResourceId} = $post->{RecordingResource};
         $post->{AssignedResource}     = 'False';
         $post->{ChangeResolutionCode} = 'False';
         $post->{RecordingResource}    = 'True';
         $post->{Apply}                = 'True';
         $post->{BillingOn}            = 'False';
         $post->{Initialized}          = 'Y';
         $post->{SaveInProgress}       = '1';
         $post->{Task}                 = $post->{TaskCode};
         $post->{TaskTime}             = '0.00';
         $post->{TaskTimeUnits}        = 'Min';

         if ($self->debug) {
            print STDERR "\n" . "=" x 20 . " AddEditRequestTask " . "=" x 20 . "\n";
            print STDERR $self->__hash($post);
            print STDERR "=" x 20 . " END " . "=" x 20 . "\n";
         } ## end if ( $self->debug )
         return $post;
      } ## end if ($form)
      print STDERR "Failed to obtain AddEditRequestTask\n" if $self->debug;
      return;
   } ## end if ( defined $requestid...)
   else {
      print "Missing required information\n";
      return;
   }
} ## end sub AddEditRequestTask

#==================================================================
# Impact Create new task
#==================================================================
sub NewRequestTask {
   my $self = shift;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   my $post = shift;
   if (defined $post) {
      if ($self->debug) {
         print STDERR "\n" . "=" x 20 . " NewRequestTask " . "=" x 20 . "\n";
         print STDERR $self->__hash($post);
         print STDERR "=" x 20 . " END " . "=" x 20 . "\n";
      }
      $self->browser->fetch_page('POST', $self->url . 'NewRequestTask.asp', $post);
      if ($self->browser->html =~ /var\s+?arrStatus\s+?=\s+?new\s+?Array\(\"Success\"/) {
         return 1;
      }
      else {
         print "Failed to create tasks\n";
         return;
      }
   } ## end if ( defined $post )
} ## end sub NewRequestTask

#==============================================================
# Impact link Tickets
#==============================================================
sub PersistRequestLinkAdd {
   my $self = shift;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   my ($parent_projectid, $parent_number, $linked_projectid, $linked_number) = @_;
   if (defined $parent_projectid && defined $parent_number && defined $linked_projectid && defined $linked_number) {
      $parent_number =~ s/reshr//i;
      $linked_number =~ s/reshr//i;
      $self->browser->fetch_page(
         'POST',
         $self->url . 'PersistRequestLinkAdd.asp',
         {
           CallerMode    => 'T',
           Project       => $parent_projectid,    # Parent projectid
           ProjectId     => $linked_projectid,    # Linked ticket projectid
           Relationship  => 'P',
           RequestId     => $linked_number,       # Incident number
           RequestNumber => $parent_number,       # SR number
         }
      );

      #   var arrStatus = new Array("true","")     if it works
      if ($self->browser->html =~ /var\s+arrStatus\s+?=\s+?new\s+?Array\(\"true\",\"\"\)/i) {
         print "Tickets linked\n";
         return 1;
      }
      else {
         print "Failed to link tickets\n";
         return;
      }
   } ## end if ( defined $parent_projectid...)
   else {
      print "Missing required values\n";
      return;
   }
} ## end sub PersistRequestLinkAdd

#===================================================================================
# Get EA imbedded attributes
#===================================================================================
sub RequestEAEmbedded {
   my ($self, $projectid, $requestid, $categoryid, $subcategoryid, $contactid) = @_;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   if (   defined $projectid
       && defined $requestid
       && defined $categoryid
       && defined $subcategoryid
       && defined $contactid) {
      $self->browser->fetch_page(
                                 'GET',
                                 $self->url . 'RequestEAEmbedded.asp',
                                 {
                                    ProjectId               => $projectid,
                                    RequestId               => $requestid,
                                    CategoryCode            => $categoryid,
                                    SubCategoryCode         => $subcategoryid,
                                    ServiceCatalogId        => '',
                                    ContactId               => $contactid,
                                    SearchForMainAttributes => 'Y',
                                    ClassType               => 'R',
                                    ClassTypeCode           => '',
                                    SetUpForCopy            => 'Y',
                                    CallerMode              => 'T',
                                 }
      );
      my $regex = qr/<SCRIPT\s+?FOR\=window\s+?EVENT\=onload[^>]+>(.*?)\<\/SCRIPT\>/ixs;
      $self->__set_html_values_from_javascript($regex);
      my $post;
      $post->{EAA} = '';
      $post = $self->__set_post_values_from_form($post, 'frmAttributes', prefix => 'EAA',);
      foreach my $key (qw/EAAinput_0/) {
         delete $post->{$key};
      }
      if ($self->debug) {
         print STDERR "\n" . "=" x 20 . " RequestEAEmbedded " . "=" x 20 . "\n";
         print STDERR $self->__hash($post);
         print STDERR "=" x 20 . " END " . "=" x 20 . "\n";
      }
      return $post;
   } ## end if ( defined $projectid...)
   else {
      print "Cannot retrieve EA missing parms\n";
      printf STDERR "%s %s %s %s %s\n", $projectid, $requestid, $categoryid, $subcategoryid, $contactid;
      return;
   }
} ## end sub RequestEAEmbedded

#==========================================================================
# Impact My Queues Page
#==========================================================================
sub RequestQueueReport {
   my $self = shift;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   $self->browser->fetch_page('get', $self->url . 'RequestQueueReport.asp', { CallerMode => 'T', });
   return $self->__griddata($self->browser->html);
} ## end sub RequestQueueReport

#==========================================================================
# Impact LoginPage
#==========================================================================
sub LoginPage {
   my $self = shift;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   $self->browser->fetch_page(
                              'get',
                              $self->url . 'LoginPage.asp',
                              {
                                 ErrorState    => '',
                                 LoginAttempts => ''
                              }
   );
   if ($self->browser->html =~ /<input type="password"/i) {
      return 1;
   }
   else {
      return;
   }
} ## end sub LoginPage

#--------------------------------------------------------
# Get tasks for a given ticket
#--------------------------------------------------------
sub RequestTasks {
   my ($self, $requestid, $projectid) = @_;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   if (!defined $requestid || $requestid !~ /\d+/i) {
      print STDERR "Missing or invalid Requestid (ticket number) $requestid\n";
      return;
   }
   else {
      $requestid =~ s/RESH[CIPR]//i;
   }
   if (!defined $projectid || $projectid !~ /-\d{5,}/) {
      print STDERR "Missing or invalid Projectid $projectid\n";
      return;
   }
   $self->browser->fetch_page(
                              'GET',
                              $self->url . 'RequestTasks.asp',
                              {
                                 ProjectId => $projectid,
                                 RequestId => $requestid,
                                 Portal    => 'N',
                              }
   );
   return ($self->__griddata($self->browser->html));
} ## end sub RequestTasks

#==============================================================
# Impact List tasks that can be used with current ticket
#==============================================================
sub RequestTasksToImplement {
   my $self = shift;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   my ($projectid, $requestid, $requestprefix, $opt) = @_;
   if (defined $projectid && defined $requestid && defined $requestprefix) {
      $self->browser->fetch_page(
                                 'GET',
                                 $self->url . 'RequestTasksToImplement.asp',
                                 {
                                    ProjectID     => $projectid,
                                    RequestID     => $requestid,
                                    RequestPrefix => $requestprefix,
                                 }
      );
      my %hash;

      # parse the HTML and turn list item into select
      my $html = $self->browser->html;
      while (
         $html =~ /oItem.Id\s*?=\s*?[\'|\"]([^\"\']+)[\'\"]
            \s*?oItem.Text\s*?=\s*?[\'\"]([^\"\']+)[\'\"]
            .*?Item.FireSelected\s+?=\s+?[\'\"](\w)[\'\"]
            /ixgm
        ) {
         $hash{$2} = $1 if $3 eq 'Y';
      } ## end while ( $html =~ /oItem.Id\s*?=\s*?[\'|\"]([^\"\']+)[\'\"] )
      if (%hash) {
         if (defined $opt) {
            if (defined $hash{$opt}) {
               print STDERR "returning single requested value $opt-> " . $hash{$opt} . "\n" if $self->debug;
               return $hash{$opt};
            }
            elsif (my @keys = grep(/$opt/i, keys %hash)) {
               if (@keys == 1) {
                  print STDERR "returning single value $keys[0] -> " . $hash{ $keys[0] } . "\n" if $self->debug;
                  return $hash{ $keys[0] };
               }
               else {
                  print STDERR "Multiple matching values for \"$opt\"\n" if $self->debug;
                  foreach my $value (sort @keys) {
                     print "\t$value\n";
                  }
                  return;
               } ## end else [ if ( @keys == 1 ) ]
            } ## end elsif ( my @keys = grep( ...))
            else {
               print "Invalid Taskname \"$opt\", valid options are:-\n";
               foreach my $key (sort keys %hash) {
                  print "\t$key\n";
               }
               return;
            } ## end else [ if ( defined $hash{$opt...})]
         } ## end if ( defined $opt )
         else {    # no opt requested so return all names
            return \%hash;
         }
      } ## end if (%hash)
      else {
         print "Failed to retrieve task names\n";
         return;
      }
   } ## end if ( defined $projectid...)
   else {
      print "Missing required parms\n";
      return;
   }
} ## end sub RequestTasksToImplement

#==========================================================================
# Impact new request page
#==========================================================================
sub ResourceAddRequest {
   my $self = shift;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   $self->browser->fetch_page('get', $self->url . 'ResourceAddRequest.asp', { CallerMode => 'T' });
   my $form = $self->browser->forms('frmResourceAddRequest');
   if ($form) {
      return $self->__form_to_post_data($form);
   }
   return;
} ## end sub ResourceAddRequest

#==========================================================================
# Impact page ResourceAddRequestClassic contains Resourcename and id
# of logged in user
#==========================================================================
sub ResourceAddRequestClassic {
   my $self = shift;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   $self->browser->fetch_page(
                              'GET',
                              $self->url . 'ResourceAddRequestClassic.asp',
                              {
                                 ProjectId            => '',
                                 WhiteBoardIssueID    => '',
                                 CalledFromWhiteBoard => '',
                                 ServiceCatalogID     => '',
                                 ContactID            => '',
                              }
   );

   # var strResourceName = "RESH RES1 EI-Application Team"
   if ($self->browser->html =~ /var\s+strResourceName\s+\=\s+\"([^\"]+)\"/isx) {
      $self->resourcename($1);
   }
   if ($self->browser->html =~ /var\s+lResourceId\s+?\=\s+?\"(\-\d+)/isx) {
      $self->resourceid($1);
   }
   if ($self->resourcename && $self->resourceid) {
      return 1;
   }
   else {
      print "Failed to obtain resourcename/id\n";
      return;
   }
} ## end sub ResourceAddRequestClassic

#=====================================================================
# Add/Update ticket
#=====================================================================
sub ResourceFinalAdd {
   my ($self, $postdata) = @_;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   if ($self->debug) {
      print STDERR "\n" . "=" x 20 . " ResourceFinalAdd " . "=" x 20 . "\n";
      print STDERR $self->__hash($postdata);
      print STDERR "=" x 20 . " END " . "=" x 20 . "\n";
   }
   $self->browser->fetch_page('POST', $self->url . 'ResourceFinalAdd.asp', $postdata);
   my $html = $self->browser->html;

# var arrRequest = new Array("212","RESHR", "-2147173789", "-2147483323", "1360390970", " 6 secs","-2147473779", "-2147483648", "1", "-2147482435", "3", "4")
   $html =~ /var\s+arrRequest\s+=\s+new\s+array\((\"
         .*?\")\)
         /igx;
   if ($1) {
      my $values;
      my $ev = '$values = [ ' . $1 . ' ]';
      print STDERR "Evaluating $ev\n" if $self->debug;
      eval $ev;
      return $values;
   } ## end if ($1)
   else {
      print "failed to create ticket\n";
      return;
   }
} ## end sub ResourceFinalAdd

#=================================================================
# Get ticket details
#=================================================================
sub ResourceRequestDetails {
   my ($self, $projectid, $requestid, $requestprefix) = @_;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   if (defined $requestid && defined $projectid && defined $requestprefix) {
      $self->browser->fetch_page(
                                 'GET',
                                 $self->url . 'ResourceRequestDetails.asp',
                                 {
                                    RequestID     => $requestid,
                                    ProjectID     => $projectid,
                                    RequestPrefix => $requestprefix,
                                    CallerMode    => 'T',
                                 }
      );
      $self->__set_html_values_from_javascript(qr/Function\s+?InitPage\(\)(.*?)}\s*?\n*?\s*?function/isx);
      my $post = $self->__form_to_post_data($self->browser->forms('frmSaveRequest'));

      #Update post data with values set in the HTML
      $post = $self->__set_post_values_from_form(
                                                 $post, 'form_0',
                                                 transforms => {
                                                                 CompleteByAMPM      => 'ScheduledCompleteByAMPM',
                                                                 CompleteByDay       => 'ScheduledCompleteByDay',
                                                                 CompleteByHour      => 'ScheduledCompleteByHour',
                                                                 CompleteByMinute    => 'ScheduledCompleteByMinute',
                                                                 CompleteByMonth     => 'ScheduledCompleteByMonth',
                                                                 CompleteBySeconds   => 'ScheduledCompleteBySeconds',
                                                                 CompleteByYear      => 'ScheduledCompleteByYear',
                                                                 OpenedDateAMPM      => 'OpenedAMPM',
                                                                 OpenedDateDay       => 'OpenedDay',
                                                                 OpenedDateHour      => 'OpenedHour',
                                                                 OpenedDateMinute    => 'OpenedMinute',
                                                                 OpenedDateMonth     => 'OpenedMonth',
                                                                 OpenedDateSeconds   => 'OpenedSeconds',
                                                                 OpenedDateYear      => 'OpenedYear',
                                                                 ReceivedDateAMPM    => 'ReceivedAMPM',
                                                                 ReceivedDateDay     => 'ReceivedDay',
                                                                 ReceivedDateHour    => 'ReceivedHour',
                                                                 ReceivedDateMinute  => 'ReceivedMinute',
                                                                 ReceivedDateMonth   => 'ReceivedMonth',
                                                                 ReceivedDateSeconds => 'ReceivedSeconds',
                                                                 ReceivedDateYear    => 'ReceivedYear',
                                                                 SubjectText         => 'Subject',
                                                                 SelectModule        => 'Moduleid',
                                                                 SelectResolution    => 'ResolutionId'
                                                 }
      );

      #Update post data with values set in Javascript
      # remove the ones we dont need
      foreach my $key (
         qw/SelectCategory SelectFolder SelectSource SelectSubCategory CloseImmediately ExternalAttributesURL ExternalReferenceText PriorityLevel SelectResource SeverityLevel/
        ) {
         delete $post->{$key};
      }
      if ($self->debug) {
         print STDERR "\n" . "=" x 20 . " ResourceRequestDetails " . "=" x 20 . "\n";
         print STDERR $self->__hash($post);
         print STDERR "=" x 20 . " END " . "=" x 20 . "\n";
      }
      return $post;
   } ## end if ( defined $requestid...)
   else {
      print "ResourceRequestDetails Missing required values\n";
      return;
   }
} ## end sub ResourceRequestDetails

#===============================================================================
# Impact retrieve ActvityLevel page
#===============================================================================
sub RetrieveActivityLevels {
   my $self = shift;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   my ($projectid, $opt) = @_;
   if (defined $projectid) {
      $self->browser->fetch_page(
                                 'GET',
                                 $self->url . 'RetrieveActivityLevels.asp',
                                 {
                                    ProjectId  => $projectid,
                                    CallerMode => 'T'
                                 }
      );
      return $self->__get_page_array($opt, qr/^\d+/);
   } ## end if ( defined $projectid)
   else {
      print STDERR "Projectid value not set\n";
      return;
   }
} ## end sub RetrieveActivityLevels

#===============================================================================
# Get valid categories for project
#===============================================================================
sub RetrieveCategories {
   my $self = shift;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   my ($projectid, $opt) = @_;
   if (defined $projectid) {
      $self->browser->fetch_page(
                                 'POST',
                                 $self->url . 'RetrieveCategories.asp',
                                 {
                                    ProjectId  => $projectid,
                                    CallerMode => 'T',
                                 }
      );
      return $self->__get_page_array($opt, qr/^C\d+/);
   } ## end if ( defined $projectid)
   else {
      print STDERR "Projectid value not set\n";
      return;
   }
} ## end sub RetrieveCategories

#======================================================================
# get folder and project ids associated with the contactid
#======================================================================
sub RetrieveContactProjects {
   my $self = shift;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   my ($contactid, $opt_project, $opt_folder) = @_;
   my %hash;
   if (defined $contactid) {
      $opt_folder = 'Ticket' if !defined $opt_folder;
      $self->browser->fetch_page(
                                 'POST',
                                 $self->url . 'RetrieveContactProjects.asp',
                                 {
                                    CallerMode => 'T',
                                    ContactId  => $contactid,
                                    ProjectId  => '',
                                 }
      );
      my $html = $self->browser->html;
      while (
         $html =~ /var\s+arr\d+\s+=\s+new\s+array\((\"
         .*?\")\)
         /igx
        ) {
         my $values;
         my $ev = '$values = [ ' . $1 . ' ]';
         print STDERR "Evaluating $ev\n" if $self->debug;
         eval $ev;
         if (@$values == 5) {
            $hash{ $values->[0] }{ID} = $values->[1];
            $hash{ $values->[0] }{FOLDERS}{ $values->[2] } = $values->[3];
         }
      } ## end while ( $html =~ /var\s+arr\d+\s+=\s+new\s+array\((\" )))
      if (%hash) {
         if (defined $opt_project) {
            if (   defined $hash{$opt_project}
                && defined defined $hash{$opt_project}{ID}
                && defined $hash{$opt_project}{FOLDERS}{$opt_folder}) {
               print STDERR "Returning matched values\n" if $self->debug;
               return $hash{$opt_project}{ID}, $hash{$opt_project}{FOLDERS}{$opt_folder};
            } ## end if ( defined $hash{$opt_project...})

            # Try a partial match
            if (my @keys = grep { /$opt_project/i } (keys %hash)) {
               if (@keys == 1) {
                  print STDERR "Partial match returning single value $keys[0] $opt_folder\n" if $self->debug;
                  return $hash{ $keys[0] }{ID}, $hash{ $keys[0] }{FOLDERS}{$opt_folder};
               }
               else {
                  print STDERR "Multiple matching values for \"$opt_project\"\n" if $self->debug;
                  foreach my $value (sort @keys) {
                     print "\t-->$value\n";
                  }
                  return;
               } ## end else [ if ( @keys == 1 ) ]
            } ## end if ( my @keys = grep {...})
            else {
               print "Invalid Project/Folder  \"$opt_project/$opt_folder\", valid options are :-\n";
               foreach my $project (sort keys %hash) {
                  print "\t$project\n";
                  foreach my $folder (sort keys %{ $hash{$project}{FOLDERS} }) {
                     print "\t\t$folder\n";
                  }
               } ## end foreach my $project ( sort ...)
            } ## end else [ if ( my @keys = grep {...})]
         } ## end if ( defined $opt_project)
      } ## end if (%hash)
      else {
         print "Failed to obtain Projects for $contactid\n";
         return;
      }
   } ## end if ( defined $contactid)
   else {
      print "Missing Contactid\n";
      return;
   }
} ## end sub RetrieveContactProjects

#==============================================================================
# Get the Impact contact id for the person raising the ticket
#==============================================================================
sub RetrievePotentialContacts {
   my $self = shift;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   my ($firstname, $lastname) = @_;
   if (defined $firstname && defined $lastname) {
      $self->browser->fetch_page(
                                 'GET',
                                 $self->url . 'RetrievePotentialContacts.asp',
                                 {
                                    AddContactAllowed => '1',
                                    FirstName         => uri_escape($firstname),
                                    LastName          => uri_escape($lastname),
                                    AreaCode          => '',
                                    PhoneNumber       => '',
                                    EmailAddress      => '',
                                    Address           => '',
                                    City              => '',
                                    CompanyName       => '',
                                    DepartmentName    => '',
                                    Title             => '',
                                    PostalCode        => '',
                                 }
      );
      my @contacts = $self->__griddata($self->browser->html);
      if (!@contacts) {
         print "Cannot find contact $self->{FIRSTNAME} $self->{LASTNAME}\n";
         return;
      }
      elsif (scalar(@contacts) != 1) {
         print "Multiple contacts match $self->{FIRSTNAME} $self->{LASTNAME}\n";
         return;
      }
      else {
         my ($contactid) = $contacts[0]->{'_control'} =~ /^(-\d+)|/;
         if (!defined $contactid) {
            print "Cannot find contact $self->{FIRSTNAME} $self->{LASTNAME}\n";
            return;
         }
         print STDERR "Contactid: $contactid \n" if $self->debug;
         return $contactid if defined $contactid;
      } ## end else [ if ( !@contacts ) ]
   } ## end if ( defined $firstname...)
   else {
      print "Missing Firstname/Lastname for contact\n";
      return;
   }
} ## end sub RetrievePotentialContacts

#=====================================================================
# search for a ticket number and return control info
#=====================================================================
sub RetrieveRequestList {
   my ($self, $ticket) = @_;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   if ($ticket =~ /resh[ciprt]\d+/i) {
      $self->browser->fetch_page(
                                 'get',
                                 $self->url . 'RetrieveRequestList.asp',
                                 {
                                    RequestNumber => $ticket,
                                    CallerMode    => 'T'
                                 }
      );
      my @tickets;
      # print STDERR Dumper($self->__griddata($self->browser->html));
      foreach my $row ($self->__griddata($self->browser->html)) {
         my ($PROJECTID, $REQUESTID, $TICKET, $REQUESTPREFIX) = (split(/\|/, $row->{_control}))[ 0, 1, 2, 3 ];
         if (defined $TICKET && $TICKET eq uc($ticket)) {
            print STDERR "Returning $PROJECTID, $REQUESTID, $TICKET, $REQUESTPREFIX\n" if $self->debug;
            return $PROJECTID, $REQUESTID, $TICKET, $REQUESTPREFIX;
         }
      } ## end foreach my $row ( $self->__griddata...)
      print "Unable to find ticket $ticket\n";
      return;
   } ## end if ( $ticket =~ /resh[ciprt]\d+/i)
   else {
      print "Missing or invalid ticket number\n";
      return;
   }
} ## end sub RetrieveRequestList

#===============================================================================
# Get Assignee values
#===============================================================================
sub RetrieveResourcesToAssign {
   my $self = shift;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   my ($activityid, $projectid, $folderid, $resourceid, $categoryid, $subcategoryid, $opt) = @_;
   if (   defined $activityid
       && defined $projectid
       && defined $folderid
       && defined $resourceid
       && defined $categoryid
       && defined $subcategoryid) {
      $self->browser->fetch_page(
                                 'POST',
                                 $self->url . 'RetrieveResourcesToAssign.asp',
                                 {
                                    ActivityLevelID        => $activityid,
                                    CallerMode             => 'T',
                                    CategoryCode           => $categoryid,
                                    FolderID               => $folderid,
                                    OverrideOwningResource => 'false',
                                    ProjectID              => $projectid,
                                    RecordingResource      => $resourceid,
                                    SubcategoryCode        => $subcategoryid,
                                 }
      );
      return $self->__get_page_array($opt, qr/-\d+/);
   } ## end if ( defined $activityid...)
   else {
      print "Missing required parms\n";
      return;
   }
} ## end sub RetrieveResourcesToAssign

#--------------------------------------------------------
# perform Impact search
#--------------------------------------------------------
sub RetrieveSearchedRequests {
   my ($self, $text) = @_;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   if (!defined $text) {
      print "Missing search string\n";
      return;
   }
   $self->browser->fetch_page(
                              'GET',
                              $self->url . 'RetrieveSearchedRequests.asp',
                              {
                                 ProjectId         => 'All',
                                 FolderId          => 'All',
                                 ActivityLevelId   => 'All',
                                 Category          => 'All',
                                 SubCategory       => 'All',
                                 ExternalReference => '',
                                 Severity          => 'All',
                                 Priority          => 'All',
                                 Status            => 'AOpen',
                                 Source            => 'All',
                                 Attribute1Id      => '',
                                 Attribute1Value   => '',
                                 Attribute2Id      => '',
                                 Attribute2Value   => '',
                                 Attribute3Id      => '',
                                 Attribute3Value   => '',
                                 OpenDateFlag      => 'false',
                                 ClosedDateFlag    => 'false',
                                 OpenedStartDate   => '',
                                 ClosedStartDate   => '',
                                 OpenedEndDate     => '',
                                 ClosedEndDate     => '',
                                 Details           => uri_escape($text),
                                 CallerMode        => 'T',
                              }
   );
   return $self->__griddata($self->browser->html);
} ## end sub RetrieveSearchedRequests

#===============================================================================
# Get valid subcategories for project/category
#===============================================================================
sub RetrieveSubCategories {
   my $self = shift;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   my ($projectid, $categoryid, $opt) = @_;
   if (defined $categoryid && defined $projectid) {
      $self->browser->fetch_page(
                                 'GET',
                                 $self->url . 'RetrieveSubCategories.asp',
                                 {
                                    ProjectId  => $projectid,
                                    Category   => $categoryid,
                                    CallerMode => 'T',
                                 }
      );
      return $self->__get_page_array($opt, qr/^S\d+/);
   } ## end if ( defined $categoryid...)
   else {
      print "Projectid value not set\n";
      return;
   }
} ## end sub RetrieveSubCategories

#=============================================================================
# Update a post hash with values in supplied form
# translating key names if necessary
#=============================================================================
sub __set_post_values_from_form {
   my $self = shift;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   my ($post, $formname, %opts) = @_;
   my $form = $self->browser->forms($formname);
   foreach my $element (sort keys %{$form}) {
      my $target = $element;
      if ($opts{transforms}->{$element}) {
         $target =~ s/$element/$opts{transforms}->{$element}/g;
      }
      if ($opts{prefix}) {
         $target = $opts{prefix} . $target;
      }
      print STDERR "\t$formname \-\> $element \-\> $target = " . $form->{$element}->{value} . "\n"
        if $self->debug && exists $form->{$element}->{value};
      $post->{$target} = $form->{$element}->{value} if exists $form->{$element}->{value};
   } ## end foreach my $element ( sort ...)
   return $post;
} ## end sub __set_post_values_from_form

#===========================================================
# find element and set value
#===========================================================
sub __set_element_value {
   my $self = shift;
   my ($element, $value) = @_;
   foreach my $form ($self->browser->forms) {
      foreach my $frm (keys %{$form}) {
         foreach my $key (keys %{ $form->{$frm} }) {
            if ($key eq $element) {
               if (ref $form->{$frm}->{$key} eq 'HASH') {
                  print STDERR "\t\tSetting $frm HASH $element value to $value\n" if $self->debug;
                  $form->{$frm}->{$key}->{value} = $value;
               }
               else {
                  print STDERR "\t\tSetting $frm $element value to $value\n" if $self->debug;
                  $form->{$frm}->{$key} = $value;
               }
            } ## end if ( $key eq $element )
         } ## end foreach my $key ( keys %{ $form...})
      } ## end foreach my $frm ( keys %{$form...})
   } ## end foreach my $form ( $self->browser...)
} ## end sub __set_element_value

#==========================================================================
# Parse scripts for statements that set controls.
#==========================================================================
sub __set_html_values_from_javascript {
   my ($self, $regex) = @_;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;

   # Update post data with values set in the Javascript
   foreach my $row ($self->__get_javascript_settings($regex)) {
      print STDERR "\tjavascript setting: $row\n" if $self->debug;

      #               document.getElementById(\'ScheduledCompletionFlag\').checked = true;
      if ($row =~ /getElementById.*checked/i) {
         my ($element, $state) = $row =~ /[\"\\']
                  (\w+).*(true|false)/ix;
         $state = $state eq 'true' ? 'Y' : 'N';
         $self->__set_element_value($element, $state);
      } ## end if ( $row =~ /getElementById.*checked/i)

      #              SetDateTime("ReceivedDate","10/10/2012 11:39:55:000");
      elsif ($row =~ /setdate/i) {
         my ($data) = $row =~ /\((.*)\)/ix;
         my ($element, $datetime) = (split(/,/, $data));
         $element  =~ s/["\']//g;
         $datetime =~ s/["\']//g;
         if ($datetime) {
            my ($date, $time) = split(/\s/, $datetime);
            my ($month, $day, $year) = split(/\//, $date);
            $self->__set_element_value($element . 'Month', $month);
            $self->__set_element_value($element . 'Day',   $day);
            $self->__set_element_value($element . 'Year',  $year);
            my ($hour, $min, $sec) = split(/:/, $time);
            my $ampm = 'AM';
            if ($hour > 12) {
               $hour = $hour - 12;
               $ampm = 'PM';
            }
            $self->__set_element_value($element . 'Hour', sprintf('%02d', $hour));
            $self->__set_element_value($element . 'Minute',  $min);
            $self->__set_element_value($element . 'Seconds', $sec);
            $self->__set_element_value($element . 'AMPM',    $ampm);
         } ## end if ($datetime)
      } ## end elsif ( $row =~ /setdate/i)

      #      SetDDL(document.getElementById("RESHCUSTOMER"),"zPAPNew", "true");
      elsif ($row =~ /(?:SetDDL|Settext)\((.*)\)/i) {
         my ($element, $value) = (split(/,\s*?[\"\']/, $1))[ 0, 1 ];
         $element =~ s/^.*?[\"\']//;
         $element =~ s/[\"\'].*$//;
         $value   =~ s/[\"\'].*$//;
         $self->__set_element_value($element, $value);
      } ## end elsif ( $row =~ /(?:SetDDL|Settext)\((.*)\)/i)
      else {
         print "Cant handle $row\n";
      }
   } ## end foreach my $row ( $self->__get_javascript_settings...)
} ## end sub __set_html_values_from_javascript

#======================================================
# map a form to a hash of the keys/value memebr
#======================================================
sub __form_to_post_data {
   my $self = shift;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   my $data      = shift;
   my %translate = @_;
   my $postdata  = {};
   foreach my $key (keys %$data) {
      my $targetkey;
      if (defined $translate{$key}) {
         $targetkey = $translate{$key};
      }
      else {
         $targetkey = $key;
      }
      $postdata->{$targetkey} = $data->{$key}->{value};
   } ## end foreach my $key ( keys %$data)
   return $postdata;
} ## end sub __form_to_post_data

#======================================================
# Parse page init javascript for statements that set values in the forms
#======================================================
sub __get_javascript_settings {
   my ($self, $regex) = @_;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   my @statements;

   #   <SCRIPT FOR=window EVENT=onload LANGUAGE=JavaScript>
   #   ...
   # </SCRIPT>
   if (

      #      $self->browser->scripts =~ /Function\s+?InitPage\(\)
      #         (.*?)
      #      }\s*?\n*?\s*?function/isx
      #      || $self->browser->scripts =~ /<SCRIPT\s+?FOR\=window\s+?EVENT\=onload[^>]+>(.*?)\<\/SCRIPT\>/ixs
      #     ) {
      $self->browser->scripts =~ /$regex/
     ) {
      my $text = $1;
      while ($text =~ /(getElementById\([^\)]+\)\.checked\s*?=\s*?[\"\']?(?:true|false))/gismx) {
         push @statements, $1;
      }

      #      SetDDL(document.getElementById("IRVChangeType"),"Emergency", "true");
      while ($text =~ /((?:setddl|settext)\(.*\))/gix) {
         push @statements, $1;
      }

      #   SetDateTime("ReceivedDate","10/10/2012 11:39:55:000");
      while ($text =~ /(SetDateTime\([^\)]+\))/gismx) {
         push @statements, $1;
      }
   } ## end if ( $self->browser->scripts...)
   else {
      print STDERR "\tNo init function\n" if $self->debug;
   }
   print STDERR "\tNo settings in javascript \n" if !@statements && $self->debug;
   return @statements;
} ## end sub __get_javascript_settings

#--------------------------------------------------------
# Grab the GridData json definiton and return as an array
#--------------------------------------------------------
sub __griddata {
   my ($self, $html, $opts) = @_;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   my $labels;
   if ($opts) {
      @$labels = @{ $opts->{labels} } if defined $opts->{labels};
   }
   if ($html =~ /\n\s*var\s+griddata\s*?=/ism) {

      # get column headings
      if (!$labels) {
         my $t_flag;
         my $pa = HTML::Parser->new(
            api_version => 3,
            text_h      => [
               sub {
                  my $text = shift;
                  $text =~ s/&nbsp;//gism;
                  push @$labels, $text;
                  $t_flag = 1;
               },
               "text"
            ],
         );

         #      var HeaderData = [^M
         my ($headerdata) = $html =~ /\n\s*?var\s+headerdata\s*?=(.*?)\n\s*?var/is;
         if ($headerdata) {
            my @labels;
            eval '@labels=' . $headerdata;
            foreach my $label (@{ $labels[0] }) {
               if ($label =~ /<.*?>/) {
                  $t_flag = 0;
                  $pa->parse($label);
                  $pa->eof();
                  push @$labels, "Col" . scalar @$labels if !$t_flag;
               } ## end if ( $label =~ /<.*?>/)
               else {
                  push @$labels, $label;
               }
            } ## end foreach my $label ( @{ $labels...})
            push @$labels, "_control";
         } ## end if ($headerdata)
      } ## end if ( !$labels )

      # get column values
      if ($labels) {
         my @rows;
         my ($griddata) = $html =~ /\n\s*var\s+griddata\s*?=(.*?])(?:\s*\n\s*var\b)/ism;
         $griddata =~ s/\@/\\@/g;
         eval '@rows=' . $griddata;
         my $data = {};
         my @list;
         my $i = 0;
         my $t_flag;
         my $p = HTML::Parser->new(
            api_version => 3,
            text_h      => [
               sub {
                  my $text = shift;
                  if (defined $labels->[$i]) {
                     $text =~ s/&nbsp;//gism;
                     $text =~ s/^\s+|\s+$//gism;
                     if ($text) {
                        $data->{ $labels->[$i] } .= "$text\n";
                        $t_flag = 1;
                     }
                  } ## end if ( defined $labels->...)
               },
               "text"
            ],
         );
         foreach my $row (@{ $rows[0] }) {
            foreach my $col (@$row) {
               if ($col =~ /<.*?>/) {
                  $t_flag = 0;
                  $p->parse($col);
                  $p->eof();
                  $data->{ $labels->[$i] } = '' if !$t_flag;
               } ## end if ( $col =~ /<.*?>/ )
               else {
                  $data->{ $labels->[$i] } = "$col";
               }
               $i++;
               if (!defined $labels->[$i]) {
                  last;
               }
            } ## end foreach my $col (@$row)
            foreach my $key (keys %$data) {
               $data->{$key} =~ s/^\s+|\s+$//g;
            }
            push @list, $data;
            $data = {};
            $i    = 0;
         } ## end foreach my $row ( @{ $rows[...]})
         return @list;
      } ## end if ($labels)
      else {
         return;
      }
   } ## end if ( $html =~ /\n\s*var\s+griddata\s*?=/ism)
   else {
      return;
   }
} ## end sub __griddata

#============================================================================
# get array data from page and return entry that matches $opt
#============================================================================
sub __get_page_array {
   my ($self, $opt, $regex) = @_;
   printf STDERR "\t%s -> %sat %d\n", (caller(0))[ 0, 3, 2 ] if $self->debug;
   my %hash;
   my $page = (caller(1))[3];
   my $type = (split(/::/, $page))[-1];
   $type =~ s/Retrieve//i;
   $type =~ s/ies$/y/i;
   $type =~ s/Levels$//i;
   my $html = $self->browser->html;

   while (
      $html =~ /var\s+arr\d+\s+=\s+new\s+array\((\"
         .*?\")\)
         /igx
     ) {
      my $values;
      my $ev = '$values = [ ' . $1 . ' ]';
      print STDERR "Found $ev\n" if $self->debug;
      eval $ev;
      if (@$values < 4 && $values->[1] =~ /$regex/i) {
         print STDERR "Saving $ev\n" if $self->debug;

         # for retrieveresourcestoassign
         if ($values->[0] =~ /hrs,.*hrs/) {
            $values->[0] =~ s/(?:\(off-hook\).*?)?\d+\.\d+\s+hrs,.*$//;
         }

         # end of for retrieveresourcestoassign
         $hash{ $values->[0] } = $values->[1];
      }
   } ## end while ( $html =~ /var\s+arr\d+\s+=\s+new\s+array\((\" )))

   # should now have a hash containing the array data from the page
   if (%hash) {
      if (defined $opt) {
         if (defined $hash{$opt}) {
            print STDERR "returning single requested value $opt\n" if $self->debug;
            return $hash{$opt};
         }
         elsif (my @keys = grep(/$opt/i, keys %hash)) {
            if (@keys == 1) {
               print STDERR "returning single value $keys[0]\n" if $self->debug;
               return $hash{ $keys[0] };
            }
            else {
               print STDERR "Multiple matching values for \"$opt\"\n" if $self->debug;
               foreach my $value (sort @keys) {
                  print "\t$value\n";
               }
               return;
            } ## end else [ if ( @keys == 1 ) ]
         } ## end elsif ( my @keys = grep( ...))
         else {
            print "Invalid $type \"$opt\", valid options are:-\n";
            foreach my $key (sort keys %hash) {
               print "\t$key\n";
            }
            return;
         } ## end else [ if ( defined $hash{$opt...})]
      } ## end if ( defined $opt )
      else {
         print STDERR "No specific value requested returning complete hash\n" if $self->debug;
         return \%hash;
      }
   } ## end if (%hash)
   else {
      print "$page returned no $type\n";
      return;
   }
} ## end sub __get_page_array
1;
