package EI::Curl::page;
#====================================
# $Revision: 1.2 $
#====================================
use strict;
use FindBin;
use lib (
          "$FindBin::Bin/lib",
          "$FindBin::Bin/../lib", "$FindBin::Bin/../../lib",
          "/lfs/system/tools/configtools/lib"
);
use URI::Escape;
use Data::Dumper;
use HTML::Parser;
use FileHandle;
use MIME::Base64;
use IPC::Open3;

sub open {
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $url   = shift;
   my $self = {
                __scripts  => '',    # inline script text
                __forms    => {},    # all forms
                __controls => {},    # visible form elements
                __html     => '',    # raw html
                __status   => '',    # http response code
   };
   bless $self, $class;
   return $self;
} ## end sub open

#=====================================================
# do the curl command
#=====================================================
sub navigate {
   my $self = shift;
   printf STDERR "\t%s -> %sat %d\n", ( caller(0) )[ 0, 3, 2 ] if $self->debug;
   $self->scripts('');
   $self->{__header}='';
   $self->{__html}='';
   $self->forms( {} );
   my $url = shift;
   my $loc;    # used if page redirects
   if ($url) {
      if ( $ENV{'save_html'} && !$ENV{'sim'} ) {
         my $page = ( split /\s/, $url )[-1];
         $page = ( split /\//, $page )[-1];
         $page =~ s/["']//g;
         CORE::open HTML, ">", $page;
      } ## end if ( $ENV{'save_html'}...)
      print STDERR "\t" . $url . "\n" if $self->debug;
      #===================================================
      #
      #===================================================
      if ( $ENV{'sim'} ) {
         my $page = ( split /\s/, $url )[-1];
         $page = ( split /\//, $page )[-1];
         $page =~ s/\"//g;
         if ( -e $page ) {
            print STDERR "reading HTML from $page\n" if $self->debug;
            $self->{__html} = `cat $page`;
         }
         else {
            print STDERR "Cant read $page\n" if $self->debug;
            exit;
         }
         $self->{http_rc} = 200;
      } ## end if ( $ENV{'sim'} )
      #===================================================
      #
      #===================================================
      else {
         my $pid = open3( \*WRITER, \*READER, \*ERROR, $url );
         {
            my $header = 1;
            while (  my $line = <READER> ) {
               if ( $line =~/^\s$/ ) {
                  $header=0;
                  next;
               }
               if ( $header ) {
                  $self->{__header} .= $line;
               }
               else {
                  $self->{__html} .= $line;
               }
            }
         }
         {
            local $/;
            $self->{__status} = <ERROR>;
         }
         waitpid( $pid, 0 ) or die "$!\n";
         $self->{curl_rc} = $? >> 8;
         close WRITER;
         close READER;
         close ERROR;
         if ( $ENV{'save_html'} ) {
            print HTML $self->{__html};
            close HTML;
         }

         #  get HTTP response code like ...  HTTP/1.1 200 OK
        $self->{http_rc}='';
         ( $self->{http_rc} ) = $self->header =~ /HTTP\/\d\.\d\s(\d+)/ix;
         if ( !$self->http_rc ) {
            print "HTTP_RC not set\n";
            print $self->status;
            print $self->header;
            exit;
         } ## end if ( !$self->http_rc )
         else {
            print STDERR "<<HTTP Response Code: " . $self->http_rc . ">>\n" if $self->debug;
         }

         #
      } ## end else [ if ( $ENV{'sim'} ) ]
      if ( $self->http_rc != 302 ) {

         # parse the html to pick out forms and controls
         my $p = HTML::Parser->new(
                                    api_version => 3,
                                    start_h     => [ \&html_tag_start, "self, tagname, attr, attrseq, text" ],
                                    text_h      => [ \&html_text, "self, dtext" ],
                                    end_h       => [ \&html_tag_end, "self, tagname" ]
         );
         $self->counters( {} );
         $p->{_self} = $self;    # save pointer to my object in the HTML parse object
         $p->parse( $self->{__html} );
         return $self->{curl_rc};
      } ## end if ( $self->http_rc !=...)
      #===================================================
      # handle 302 redirects here 
      #===================================================
      else {
         ($loc) = $self->header =~ /Location:\s*?([^\s]+)/ix;
         if ( defined $loc ) {
            print STDERR "Handling redirect to $loc\n" if $self->debug;
            $loc =~ s/^\s+|\s+$//g;
            my ( $oldurl ) = (split(/\s/,$url))[-1];
            $url =~ s/-d\s\".*//;
            my ( $newurl, $parms ) = split( /\?/, $loc );
            $newurl =~ s/^\s+//g;
            if ($newurl !~/^http/ ) {
               # relative url so need the original http://.... etc
               my ($oldpath) = $oldurl =~/(.*)\//;
               $newurl = $oldpath.'/'.$newurl;
            }
            $url .= '-G -d "' . $parms . '" "' . $newurl . '"';
            return $self->navigate($url);
         }
         else {
            print "Redirect location not found ! \n";
            print $self->header;
            exit;
         }
      } ## end else [ if ( $self->http_rc !=...)]
   } ## end if ($url)
   else {
      return;
   }
} ## end sub navigate

sub getElementById {
   my ( $self, $opts ) = @_;
   foreach my $element ( keys %{ $self->forms } ) {
   }
} ## end sub getElementById

sub set_elements_from_html {
   my $self = shift;
   foreach my $form ( %{ $self->forms } ) {
      foreach my $element ( keys %{ $self->forms->{$form} } ) {

         #         print "$form : $element ".$self->forms->{$form}->{$element}->{_tag}."\n";
         if ( $self->forms->{$form}->{$element}->{_tag} eq 'select' ) {
            my $options = $self->forms->{$form}->{$element}->{options};
            foreach my $option (@$options) {
               if ( defined $option->{_selected} ) {
                  $self->setElement( $element, $option->{value} );
               }
            }
         } ## end if ( $self->forms->{$form...})
      } ## end foreach my $element ( keys ...)
   } ## end foreach my $form ( %{ $self...})
} ## end sub set_elements_from_html

sub delete_html {
   my $self = shift;
   delete $self->{__html};
}

sub delete_status {
   my $self = shift;
   delete $self->{__status};
}

sub delete_scripts {
   my $self = shift;
   delete $self->{__scripts};
}

sub scripts {
   my $self = shift;
   $self->{__scripts} = shift if @_;
   $self->{__scripts};
} ## end sub scripts

#=============================================================
# return hash of the forms on the page
#=============================================================
sub forms {
   my $self = shift;
   if (@_) {
      $self->{__forms} = shift;
   }
   $self->{__forms};
} ## end sub forms

#=============================================================
# return hash of elements defined to a form
#=============================================================
sub form_elements {
   my ( $self, $form ) = @_;
   if ( defined $self->forms->{$form} ) {
      return $self->forms->{$form};
   }
   return;
} ## end sub form_elements

#=============================================================
# check if parm is a valid option for a select
#=============================================================
sub is_valid_option {
   my $self   = shift;
   my $form   = shift;
   my $select = shift;
   my $opts;
   %$opts = @_;
   if ( $self->valid_element( $form, $select ) ) {
      if ( $self->forms->{$form}->{$select}->{_tag} ne 'select' ) {
         print STDERR "$select is not a select element\n" if $self->debug;
         return;
      }
      my $options = $self->forms->{$form}->{$select}->{'options'};
      foreach my $option ( @{$options} ) {
         if ( ( defined $opts->{value} && $opts->{value} eq $option->{value} )
              || defined $opts->{text} && $opts->{text} eq $option->{text} ) {
            return ( $option->{value}, $option->{text} );
         }
      } ## end foreach my $option ( @{$options...})
   } ## end if ( $self->valid_element...)
   return;
} ## end sub is_valid_option

sub valid_element {
   my ( $self, $form, $element ) = @_;
   if ( !defined $self->forms->{$form} ) {
      print STDERR "$form does not exist\n" if $self->debug;
      return;
   }
   if ( !defined $self->forms->{$form}->{$element} ) {
      print STDERR "$element does not exist in $form\n" if $self->debug;
      return;
   }
   return 1;
} ## end sub valid_element

sub selected_option {
   my $self   = shift;
   my $form   = shift;
   my $select = shift;
   if ( $self->valid_element( $form, $select ) ) {
      return $self->forms->{$form}->{$select}->{value}, $self->forms->{$form}->{$select}->{text};
   }
   return;
} ## end sub selected_option

#=========================================================
# called on every opening tag
#=========================================================
sub html_tag_start {
   my ( $self, $tag, $attrs, $attrseq, $origtext ) = @_;
   $tag = lc($tag);
   if ( $tag =~ /(?:form|input|select|option|script)/ ) {
      my $page     = $self->{_self};
      my $counters = $page->counters;
      my $form;
      if ( !defined $self->{_current_form} ) {
         $form = "form_" . $counters->{form}++;
         $self->{_current_form} = $form;
      }
      else {
         $form = $self->{_current_form};
      }
      my $id = $attrs->{name} || $attrs->{id};
      if ( !defined $id ) {
         $id = "${tag}_" . $counters->{$tag}++;
      }
      if ( $tag eq 'form' ) {
         $self->{_current_form} = $id;
         $page->{__forms}->{$id} = {};
      }
      elsif ( $tag eq "option" ) {
         $self->{_option} = { value => $attrs->{value} };
         if ( $attrs->{selected} ) {
            $self->{_option}->{_selected} = 1;
         }
      } ## end elsif ( $tag eq "option" )
      elsif ( $tag eq 'script' ) {
         if ( !defined $attrs->{src} ) {
            $self->{_script} = $origtext;
         }
      }
      else {
         $page->{__forms}->{$form}->{$id} = $attrs;
         $page->{__forms}->{$form}->{$id}->{_tag} = $tag;
         $self->{_select} = $id if $tag eq 'select';
      }
   } ## end if ( $tag =~ /(?:form|input|select|option|script)/)
} ## end sub html_tag_start

sub debug {
   my $self = shift;
   $self->{__debug} = shift if @_;
   $self->{__debug};
} ## end sub debug

sub html {
   my $self = shift;
   $self->{__html};
}

sub status {
   my $self = shift;
   $self->{__status};
}

sub header {
   my $self = shift;
   $self->{__header};
}
sub http_rc {
   my $self = shift;
   $self->{http_rc};
}

sub counters {
   my $self = shift;
   $self->{__counts} = shift if @_;
   $self->{__counts};
} ## end sub counters

#=========================================================
# called on every closing tag
#=========================================================
sub html_tag_end {
   my ( $self, $tag ) = @_;
   delete $self->{_select} if lc($tag) eq 'select';
   delete $self->{_option} if lc($tag) eq 'option';
   delete $self->{_script} if lc($tag) eq 'script';
   delete $self->{_form}   if lc($tag) eq 'form';
} ## end sub html_tag_end

#=========================================================
# called for text nodes
#=========================================================
sub html_text {
   my ( $self, $text, $tag ) = @_;
   my $page = $self->{_self};

   # store option text
   if ( defined $self->{_option} ) {
      my $form   = $self->{_current_form};
      my $select = $self->{_select};
      my $option = $self->{_option};
      $option->{text} = $text;
      if ( defined $option->{_selected} || !defined $page->forms->{$form}->{$select}->{value} ) {
         $page->forms->{$form}->{$select}->{value} = $option->{value};
         $page->forms->{$form}->{$select}->{text}  = $option->{text};
         delete $option->{_selected};
      }
      push @{ $page->forms->{$form}->{$select}->{options} }, $option;
   } ## end if ( defined $self->{_option...})
   elsif ( defined $self->{_script} ) {
      $page->scripts( $page->scripts . $self->{_script} );
      $page->scripts( $page->scripts . $text );
      $page->scripts( $page->scripts . "</SCRIPT>\n" );
   }
} ## end sub html_text

sub DESTROY {
   my $self = shift;
   print STDERR "Page closed\n" if $self->debug;
}
1;
