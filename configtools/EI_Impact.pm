#!/usr/local/bin/perl
package EI_Impact;
use strict;
use Term::ANSIColor;
use Term::ANSIColor qw(:constants);
use URI::Escape;
use Data::Dumper;
use HTML::TokeParser;
use FileHandle;
$Term::ANSIColor::AUTORESET = 1;
##################################################
## the object constructor (simplistic version)  ##
##################################################
sub new {
   my $self = {};
   my $PID=$$;
   $self->{URL}       = undef;
   $self->{USERID}    = undef;
   $self->{PASSWORD}  = undef;
   $self->{FIRSTNAME} = undef;
   $self->{LASTNAME}  = undef;

   $self->{COOKIES}   = "\/tmp\/${PID}_impact_cookies";
   $self->{CURL} = "curl -L -s -b \"$self->{COOKIES}\" -c \"$self->{COOKIES}\"";
   $self->{STATUS} = 2;
   
   my %sites =(
      Test => 'https://impactdev.rny.ihost.com/IM/scripts',
      Prod => 'https://impact-enterprise.rny.ihost.com/IM/scripts'
   );
   
   my $curlver = `curl -V`;
   
   my ($version) = $curlver =~ /(\d+\.\d+)/is;
   debug("curl version $version");
   if ( $version ne "7.9" ) {
      $self->{CURL} .= ' -k ';
   }
   else { 
      debug("$version eq 7.9");
   }
   
   #================================================
   # Get login info from xml
   #================================================

   my $XML = $ENV{'TICKET_CONFIG'} || glob('~/.impact_test.xml');
   debug("login details from $XML");
   
   if ( -r "$XML" ) {
      open "XML", "<", "$XML";
      while ( my $line = <XML> ) {
         chomp $line;
         if ( $line =~ /\<(.+?)\>(.+?)\</i ) {
            $self->{$1} = $2;
            debug("$1 = $2");
         }
      }
      close "XML";
   }
   
   if ( ! $self->{'PASSWORD'} ) {
      if ( ! $ENV{'PASSWORD'} ) {
         $self->{'PASSWORD'} = prompt("Impact Password");
      }
      else {
         $self->{'PASSWORD'} = $ENV{'PASSWORD'};
      }
   }
   if ( ! $self->{'USERID'} ) {
      if ( ! $ENV{'USERID'} ) {
         $self->{'USERID'} = prompt("Impact USERID");
      }
      else {
         $self->{'USERID'} = $ENV{'USERID'};
      }
   }
   if ( ! $self->{'URL'} ) {
      if ( ! $ENV{'URL'} ) {
         $self->{'URL'} = $sites{'Prod'};
      }
      else {
         $self->{'URL'} = $ENV{'URL'};
      }
   }
   
   bless($self);    # but see below
   return $self;
}

#================================================
# Do impact login
#================================================
sub login {
   debug("login");
   my $self       = shift;
   my $USERID_ENC = uri_escape( $self->{USERID} );
   my $PASSWORD   = $self->{PASSWORD};
   my $LOGIN_POST = "GoToURL=&LoginAttempts=1&Password=$PASSWORD&UserID=$USERID_ENC&submit_request=";
   debug("$LOGIN_POST");
   my $curl = "$self->{CURL} \"$self->{URL}/LoginPage.asp?ErrorState=&LoginAttempts=\"";
   debug($curl);
   open( CMD, "$curl |" );
   debug( "curl rc=" . $? );

   while ( defined( my $line = <CMD> ) ) {
      if ( $line =~ /<input type="password"/i ) {
         $self->{STATUS} = 1;
         last;
      }
   }
   close CMD;
   if ( $self->{STATUS} == 1 ) {
      #================================================
      # POST login details
      #================================================
      print STDERR YELLOW "Logging into Impact ... ";
      debug("Send ID/PW");
      $curl = "$self->{CURL} -d \"$LOGIN_POST\" \"$self->{URL}/Login.asp\"";
      debug($curl);
      open( CMD, "$curl |" );
      debug( "curl rc=" . $? );
      while ( defined( my $line = <CMD> ) ) {
         if ( "$line" =~ /frmLeftNavigator/i ) {
            $self->{STATUS} = 2;
            last;
         }
         if ( defined $ENV{'debug'} && $ENV{'debug'} > 5 ) {
            debug("$line");
         }
      }
      close CMD;
      if ( $self->{STATUS} == 2 ) {
         print STDERR YELLOW " Complete\n";
         return 1;
      }
      else {
         print RED BOLD "#### Login failed\n";
         return undef;
      }
   }
   else {
      print RED BOLD
        "#### Failed to access Impact login page, try again later\n";
      return undef;
   }
}

#--------------------------------------------------------
# return list of tickets on team queue
#--------------------------------------------------------
sub queue {
   my $self = shift;
   if ( $self->{STATUS} == 2 ) {    # logged in
      my $url = "/RequestQueueReport.asp?CallerMode=T";
      print STDERR YELLOW "Querying queue ...";
      my @tickets=get_tickets($self,$url);
      
      # my @tickets = get_tickets( $self, "/home/steve/lfs_tools/configtools/RequestQueueReport.asp" );
      print STDERR YELLOW "done\n";
      return @tickets;
   }
   else {
      print RED BOLD "#### Not logged in\n";
      return undef;
   }
}

#--------------------------------------------------------
# perform Impact search
#--------------------------------------------------------
sub search {
   my $self   = shift;
   my $search = shift;
   if ( $self->{STATUS} == 2 ) {    # logged in
      my $url = "/RetrieveSearchedRequests.asp?ProjectId=All&FolderId=All&ActivityLevelId=All&Category=All&SubCategory=All&ExternalReference=&Severity=All&Priority=All&Status=AOpen&Source=All&Attribute1Id=&Attribute1Value=&Attribute2Id=&Attribute2Value=&Attribute3Id=&Attribute3Value=&OpenDateFlag=false&ClosedDateFlag=false&OpenedStartDate=&ClosedStartDate=&OpenedEndDate=&ClosedEndDate=&Details=$search&CallerMode=T";
      debug("$url");
      print STDERR YELLOW "Performing search ...";
      my @tickets = get_tickets( $self, $url );
      print STDERR YELLOW "done\n";
#my @tickets=get_tickets($self,$url"/home/steve/lfs_tools/configtools/RetrieveSearchedResults.asp");
      return @tickets;
   }
   else {
      print RED BOLD "#### Not logged in\n";
      return undef;
   }
}

#--------------------------------------------------------
# Get tasks for a given ticket
#--------------------------------------------------------
sub tasks {
   my $self = shift;
   my ( $RequestId, $ProjectId ) = @_;
   if ( defined $RequestId && defined $ProjectId ) {
      ($RequestId) = get_prefix_number($RequestId);
      debug("Get tasks for $ProjectId $RequestId");
      if ( $self->{STATUS} == 2 ) {    # logged in
         my $url = "/RequestTasks.asp?ProjectId=$ProjectId&RequestId=$RequestId&Portal=N";
         debug($url);
         $ENV{'debug'} = 0;
         print STDERR YELLOW "Querying tasks ...";
         my @tasks = get_tickets( $self, $url );
         print STDERR YELLOW "done\n";
# my @tasks=get_tickets($self,"/home/steve/lfs_tools/configtools/RequestTasks.asp");
         return @tasks;
      }
      else {
         print RED BOLD "#### Not logged in\n";
         return undef;
      }
   }
   else {
      print RED BOLD "#### Need RequestId and ProjectId for task list\n";
      return undef;
   }
}

sub owner {

# -d "ActivityLevelID=$ACTIVITYID&CallerMode=T&CategoryCode=$CATEGORYID&FolderID=$FOLDERID&OverrideOwningResource=false&ProjectID=$PROJECTID&RecordingResource=$CONTACTID&SubcategoryCode=$SUBCATEGORYID" "$URL/RetrieveResourcesToAssign.asp" |&
}

sub category {

   #-d "CallerMode=T&ProjectId=$PROJECTID" "$URL/RetrieveCategories.asp" |&
}

sub subcategory {

#-d " " "$URL/RetrieveSubCategories.asp?ProjectId=$PROJECTID&Category=$CATEGORYID&CallerMode=T" |&
}

sub activity_levels {

   # "$URL/RetrieveActivityLevels.asp?ProjectId=$PROJECTID&CallerMode=T" |&
}

sub customers {

#  "$URL/RequestEAEmbedded.asp?ProjectId=$PROJECTID&RequestId=&CategoryCode=&SubCategoryCode=&ServiceCatalogId=&ContactId=$CONTACTID&SearchForMainAttributes=Y&ClassType=R&ClassTypeCode=&SetUpForCopy=N&CallerMode=T" |&
}

sub contact {

#"$URL/RetrievePotentialContacts.asp?AddContactAllowed=1&FirstName=$FIRSTNAME&LastName=$LASTNAME&AreaCode=&PhoneNumber=&EmailAddress=&Address=&City=&CompanyName=&DepartmentName=&Title=&PostalCode=" |&
}

sub get_prefix_number {
   my ($ticket) = @_;
   debug("$ticket");
   if ( $ticket ) {
      my ($Prefix,$num) = $ticket =~ /(RESH[CIPRst])(\d+)/i;
      return ($num,uc($Prefix));
   }
   else {
      die "No ticket number\n";
   }
}

sub ticket_details {
    # /ResourceRequestDetails.asp?RequestID=166&ProjectID=-2147483324&RequestPrefix=RESHC&CallerMode=T
   my $self      = shift;
   my $ticket     = shift;
   my ($RequestId,$RequestPrefix) = get_prefix_number($ticket);
   my $ProjectId = shift;
   my $curl = "$self->{CURL} \"$self->{URL}/ResourceRequestDetails.asp?RequestID=$RequestId&ProjectID=$ProjectId&RequestPrefix=$RequestPrefix&CallerMode=T\"";
   debug("$curl");
   #$curl = "cat /home/steve/lfs_tools/configtools/ResourceRequestDetails.asp";
   # debug("$curl");
     
   my $html=`$curl`;
   
   my $phtml = HTML::TokeParser->new(\$html);
   
   my %fields;
   my $sid;
   my $selectedindex;
   
   #==============================================================
   # some details we get from form objects, inputs/selects etc
   # some we need to get from javascript 
   #==============================================================
   while ( my $token = $phtml->get_token ) {
      my $ttype = shift @{$token};
      my ( $tag, $attr, $attrseq, $rawtxt ) = @{$token};
      
      if ( $ttype eq "S" ) {                       # start tag?   
         
         if ( $tag eq "input" ) {                 # input tag
            my $name = $attr->{'id'} || $attr->{'name'} ;
            if ( defined $attr->{'type'} && $attr->{'type'} eq 'checkbox' ) {
               $fields{$name}{'type'}='checkbox';
            }
            else {
               $fields{$name}=$attr->{'value'};
            }
         }
         
         elsif ( $tag eq "script" ) {           # javascript 
            if ( ! $attr->{'src'} ) {           # inline javascript has no src=
               my $js = $phtml->get_text;
               my @jslines=split(/[\n|\;]/,$js);
               foreach my $line ( @jslines ) {
                  if ($line =~ /.checked\s+=\s+[\"\']?(true|false)/i ) {
                     my $state=$1;
                     my ($id)=$line=~/getElementById\([\"|\'](\w+)[\"|\']/;
                     $fields{$id}{'checked'}=$state;
                  }
                  elsif ($line =~ /^\s+SetDateTime\(\"(\w+)\",\"(.+?)\"/ ) {
                     $fields{$1} = $2;
                  }
               }
            }          
         }
         
         elsif ( $tag eq "select" ) {           # select tag
            $sid = $attr->{'id'} || $attr->{'name'};
            $selectedindex=0;
         }
         elsif ( $tag eq "option" ) {           # select tag options
            push @{$fields{$sid}{'values'}}, $attr->{'value'};
            my $text = $phtml->get_trimmed_text;
                    
            push @{$fields{$sid}{'titles'}}, $text;
            if ( $attr ->{'selected'} ) {
               $fields{$sid}{'selected'}=$selectedindex;
            }
            $selectedindex++;
         }
         
      }    # since we know what we're looking for, no need for the rest of these
      
      elsif ( $ttype eq "T" ) {
      }
      elsif ( $ttype eq "C" ) {    # comment?
      }
      elsif ( $ttype eq "E" ) {    # end tag?
         my ( $tag, $attr, $attrseq, $rawtxt ) = @{$token};
         if ( $tag eq "select" ) {
            undef $sid;
         }
      }
      elsif ( $ttype eq "D" ) {    # declaration?
      }
      
   }               # endof while (my $token = $p->get_token)
   
   undef $html;    # destroy the HTML::TokeParser object (don't need it no more)
   return %fields;
}

sub project_folderid {
}

sub get_tickets {
   my $self = shift;
   my $url  = shift;
   debug("url is defined and set to $url");
   my $curl = "$self->{CURL} \"$self->{URL}$url\"";
   debug("$curl");

   #  my $curl="cat $url";
   open( CMD, "$curl |" );
   debug( "curl rc=" . $? );
   my ( $hData, $HeaderData, $gData, $GridData, @entrys );
   while ( defined( my $line = <CMD> ) ) {
      chomp $line;
      undef $gData if $line =~ /^\s*var/i && $gData;
      undef $hData if $line =~ /^\s*var/i && $hData;
      $GridData   .= $line if $gData;
      $HeaderData .= $line if $hData;
      if ( $line =~ /^\s*var GridData\s*=/i ) {
         $GridData = $line;
         $gData    = 1;
      }
      elsif ( $line =~ /^\s*var HeaderData\s*=/i ) {
         $HeaderData = $line;
         $hData      = 1;
      }
   }
   close CMD;
   if ( $GridData && $HeaderData ) {
      ($HeaderData) = $HeaderData =~ /\[(.*)\]/;
      my @headings = split( /,/, $HeaderData );

      #======================================================
      # clean up the headings
      #======================================================
      map { s/(\"|\')//g } @headings;
      map { s/\<img src.+?attach.+?&nbsp;// } @headings;
      map { s/^\s+|\s+$// } @headings;

      #==============================================================
      # Parse the GridData
      #==============================================================
      print Dumper($GridData) if $ENV{'debug'};
   
      #==============================================================
      # regular expressions for parsing GridData
      #==============================================================
      my %re = ( 
       ticket => qr/
            -\d{5,10}            # - followed by upto 10 numbers
            \|                   # |
            \d{1,8}              # upto 8 numbers
            \|                   # |
            \w{5}                # 5 chars eg RESHR
            \d{1,8}              # upto 8 numbers
            \|                   # |
            \w{5}                # 5 chars   eg RESHR
            \|                   # |
            -\d{1,10}            # - followed by upto 10 numbers
            /xism ,
            

         task => qr/
            -\d{5,10}            # - followed by upto 10 numbers
            \|                   # |
            \d{1,8}              # upto 8 numbers
            \|                   # |
            -\d{5,10}            # - followed by upto 10 numbers
            \|                   # |
            \w{5}
           /xism
         );
         
      while ( $GridData =~ m/(\[
                  .*?
                  (?:$re{'ticket'}|$re{'task'})
                  \"
                  \]   
               ) /gisx ) {   # split into individual entries
         my %entry;
         debug("$1");
         my @values = split( /\",\"/, $1 );   # Split entry into component parts
         for ( my $i = 0 ; $i < @values ; $i++ ) {
            my $value = $values[$i];
            $value =~ s/^\s+|\s+$//;

            #======================================
            # handle task input checkbox
            #======================================
            if ( $value =~ /\<input type=checkbox/i ) {
               $headings[$i] = "checkbox_$i";
               if ( $value =~ / checked /i ) {
                  $value = "checked";
               }
               else {
                  $value = "unchecked";
               }
            }

            #=========================================
            # handle task img with multiple value
            #=========================================
            if ( $value =~ /^\<img src=/i ) {
               my $t = 0;
               while ( $value =~ m/\<B\>(.+?)\<\/B\>/gis ) {
                  my $string = $1;
                  $string =~ s/(?:\"|\&nbsp\;|\<.+?\>|\]|\[)//gi;
                  $entry{'task_name'}      = $string if $t == 0;
                  $entry{'task_date'}      = $string if $t == 1;
                  $entry{'activity_level'} = $string if $t == 2;
                  $entry{'assignee'}       = $string if $t == 3;
                  $t++;
               }
            }

            #=================================================
            # Search and Queue queries
            #=================================================
            else {
               $value =~ s/(?:\"|\&nbsp\;|\<.+?\>|\]|\[)//gix;          # remove html junk
               if ( $headings[$i] ) {
                  debug("$headings[$i] = $value");
                  $entry{ $headings[$i] } = $value;
               }
               else {
                  $entry{'controlinfo'} = $value;
               }
            }
         }
         push @entrys, {%entry};
      }
      return @entrys;
   }
   else {
      print RED BOLD "#### failed to read queue\n";
      return undef;
   }
}

#--------------------------------------------------------
# Print debugging information
#--------------------------------------------------------
sub prompt {
   my ($promptstring,@validoptions) = @_;
   $promptstring = "Input ?" if  ! $promptstring; 
   $| = 1;    # force a flush after our print
   my $ans;
   
   print CYAN BOLD "$promptstring: " if ! @validoptions;
   if ( @validoptions > 1 ) {
      print CYAN BOLD "Select number for the $promptstring to use:\n";
      for ( my $i =0; $i<@validoptions; $i++ ) {
         print CYAN BOLD $i+1 . ") $validoptions[$i]\n";
      }
   }
   else {
   }   
   while ( $ans = <STDIN> ) {          # get the input from STDIN (presumably the keyboard)
      chomp $ans;
      return $validoptions[$ans-1] if  @validoptions && $ans =~ /^\d+$/ && $ans <= @validoptions && $ans > 0 ;
      return $ans if ! @validoptions;       
      print "Invalid response\n";
   }
}
#--------------------------------------------------------
# Print debugging information
#--------------------------------------------------------
sub debug {
   my ($msg) = @_;
   if ( $ENV{'debug'} ) {
      $msg = '' if !$msg;
      my $line     = ( caller(0) )[2];
      my $calledby = "Main";
      if ( ( defined( scalar caller(1) ) ) ) {
         $calledby = ( caller(1) )[3];
         $calledby =~ s/^.+?:://;
      }
      print STDERR YELLOW "$line:$calledby: ";
      print STDERR CYAN "$msg\n";
   }
}
1;
