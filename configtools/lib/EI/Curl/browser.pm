package EI::Curl::browser;
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

use strict;
use URI::Escape;
use Data::Dumper;
use FileHandle;
use MIME::Base64;
use EI::Curl::page;

#====================================================================
# start browser session
#====================================================================
sub open {
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self = {
                COOKIES => '/tmp/' . $$ . '_curl_cookies',
                CURL    => '',
                debug   => $ENV{'debug'} || undef,
   };

   # store standard curl command
   $self->{CURL} = 'curl -D - -v -b "' . $self->{COOKIES} . '" -c "' . $self->{COOKIES} . '"';

   # Add -k for older versions of curl
   my $curlver = `curl -V`;
   my ($version) = $curlver =~ /(\d+\.\d+)/is;
   if ( $version ne "7.9" ) {
      $self->{CURL} .= ' -k ';
   }
   bless $self, $class;
   $self->page( EI::Curl::page->open() );
   printf STDERR "%s->%s at %d\n", ( caller(0) )[ 0, 3, 2 ] if $self->debug;
   return $self;
}

#====================================================================
# Retrieve page from remote server
#====================================================================
sub fetch_page {
   my ( $self, $method, $url, $data ) = @_;
   printf STDERR "\t%s -> %sat %d\n", ( caller(0) )[ 0, 3, 2 ] if $self->debug;
   $url =~ s/["']//g;
   if ( $method !~ /GET|POST/i ) {
      print STDERR "Invalid method $method\n" if $self->debug;
      return;
   }
   my $curl = $self->{CURL};
   if ( uc($method) eq "GET" ) {
      $curl .= ' -G ';
   }

   # add data to be sent
   $curl .= ' -d "' if $data;
   foreach my $key ( sort keys %{$data} ) {
      if ( !defined $data->{$key} ) {
         print "*** Warning $key is not defined\n";
         print "URL: $url\n";
         print $self->Hash($data);
      }
      $curl .= $key . "=" . $data->{$key} . '&';
   }
   $curl =~ s/\&$/\"/;    # remove ending &
   $curl .= ' "' . $url . '"';
   $self->page->navigate($curl);

   # save any select options as we might need them to do lookups later
   foreach my $form ( keys %{ $self->forms } ) {
      my $form = $self->forms->{$form};
      foreach my $element ( keys %$form ) {
         if ( $form->{$element}->{_tag} eq 'select' ) {
            $self->Select( $element, $form->{$element} );
         }
      }
   }
}

sub Select {
   my $self   = shift;
   my $select = shift;
   if ( defined $select ) {
      if (@_) {
         print STDERR "\tStoring $select\n" if $self->debug;
         $self->{_select}->{$select} = shift;
      }
      elsif ( defined $self->{_select}->{$select} ) {
#         print STDERR "\treturning select $select\n" if $self->debug;
         return $self->{_select}->{$select};
      }
      else {
         print STDERR "\t$select doesnt exist\n" if $self->debug;
         return;
      }
   }
   else {
#      print STDERR "\treturning all selects\n" if $self->debug;
      return $self->{_select};
   }
}

sub debug {
   my $self = shift;
   if (@_) {
      $self->{_debug} = 1;
      $self->page->debug(1) if $_[0] > 2;    # debug lower level module
   }
   $self->{_debug};
}

#==========================================================
#
#==========================================================
sub option {
   my $self   = shift;
   printf STDERR "\t\t%s -> %sat %d\n", ( caller(0) )[ 0, 3, 2 ] if $self->debug;
   my $select = shift;
   my $value  = shift;
   if ( !defined $select ) {
      print STDERR "\tMissing name of select element\n" if $self->debug;
      return;
   }
   if ( !defined $value ) {
      print STDERR "\tMissing value to return\n" if $self->debug;
      return;
   }

   my $options = $self->Select->{$select}->{options};
   
   if ( !defined $options ) {
      print STDERR "\t$select doesnt exist\n" if $self->debug;
      print STDERR "\t" . Dumper( keys %{ $self->Select } ) if $self->debug;
      return;
   }
   foreach my $option ( @$options ) {
      if ( $option->{value} =~ /$value/i || $option->{text} =~ /$value/i ) {
         print STDERR "\treturning $select option ".$option->{value} .',' . $option->{text} ."\n" if $self->debug;
         return ( $option->{value}, $option->{text} );
      }
   }
   # if we get here it didnt find the option requested
   print "\tInvalid $select option \"$value\", valid options are:-\n";
   foreach my $option ( sort {$a->{text} cmp $b->{text} } @$options ) {
      print "\t".$option->{text}."\n" if $option->{text} !~ /please select/i;
   }
   return;
}

sub forms {
   my $self = shift;
   my $form = shift;
   if ( defined $form ) {
      if ( defined $self->page->forms->{$form} ) {
         return $self->page->forms->{$form};
      }
      else {
         print STDERR "\t$form doesnt exist\n" if $self->debug;
         return;
      }
   }
   else {
      return $self->page->forms;
   }
}

sub scripts {
   my $self = shift;
   return $self->page->scripts;
}

sub dump {
   my $self = shift;
   printf STDERR "\t\t%s -> %sat %d\n", ( caller(0) )[ 0, 3, 2 ] if $self->debug;
   $self->page->delete_scripts;
   $self->page->delete_html;
   $self->page->delete_status;
   print Dumper($self);
}

#===============================================================
# print list of defined forms
#===============================================================
sub list_forms {
   my $self = shift;
   foreach my $name ( sort keys %{ $self->page->forms } ) {
      print "$name\n";
   }
}

#===============================================================
# print list of elements defined to a form
#===============================================================
sub list_elements {
   my ( $self, $form ) = @_;
   print "Elements under form $form\n";
   print $self ->Hash( $self->page->forms->{$form} );

   #   print Dumper($self  ->  page  ->  forms->{$form});
}

#===============================================================
# pretty print hash
#===============================================================
BEGIN {
   my $depth = 0;

   sub Hash {
      my ( $self, $hash ) = @_;
      my $str = '';
      foreach my $key ( sort keys %$hash ) {
         if ( ref $hash->{$key} eq "HASH" ) {
            $str .= "\t" x $depth . " $key => {\n";
            $depth++;
            $str .= $self->Hash( $hash->{$key} );
            $str .= "\t" x $depth . "}\n";
            $depth--;
         }
         elsif ( ref $hash->{$key} eq "ARRAY" ) {
            $str .= "\t" x $depth . " $key => [\n";
            $depth++;

            #            $str .= $self  ->  Array( $hash->{$key} );
            $str .= "\t" x $depth . "]\n";
            $depth--;
         }
         else {
            if ( defined $hash->{$key} ) {
               $str .= "\t" x $depth . $key . " => " . $hash->{$key} . "\n";
            }
            else {
               $str .= "\t" x $depth . $key . " => ''\n";
            }
         }
      }
      return $str;
   }
}

#===============================================================
# return pointer to HTML
#===============================================================
sub is_valid_option {
   my $self = shift;
   return $self->page->is_valid_option(@_);
}

#===============================================================
# return pointer to HTML
#===============================================================
sub selected_option {
   my $self = shift;
   return $self->page->selected_option(@_);
}

#===============================================================
# return pointer to HTML
#===============================================================
sub html {
   my $self = shift;
   $self->page->html;
}

#===============================================================
# return pointer to HTML
#===============================================================
sub status {
   my $self = shift;
   $self->page->status;
}

sub http_rc {
   my $self = shift;
   $self->page->http_rc;
}

sub form_data {
   my ( $self, $form ) = @_;
   my $data = {};
   if ( defined $self->page->forms->{$form} ) {
      foreach my $element ( sort keys %{ $self->current_page->forms->{$form} } ) {
         $data->{$element} = $self->page->forms->{$form}->{$element}->{value};
      }
   }
   return $data;
}

#===============================================
# get/set page object pointer
#===============================================
sub page {
   my $self = shift;
   $self->{__page} = shift if @_;
   $self->{__page};
}

sub DESTROY {
   my $self = shift;
   print STDERR "\tBrowser closed\n" if $self->debug;
   unlink $self->{COOKIES} if -e $self->{COOKIES};
}
1;
