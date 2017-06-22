#!/usr/local/bin/perl
package ParseXML::ParseXML;
use strict;
use warnings;
use FindBin;
use lib ( "$FindBin::Bin/lib", "$FindBin::Bin/../lib" );
use Data::Dumper;
use debug;
use XML::Parser;
use ParseXML::Element;
use Term::ANSIColor;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use strict;
use warnings;

#    XML => x.y.z,
#    PARENT => undef,
#    CHILD => [ {
#                 TAG => name,
#                 PARENT => \$parent
#                 IDX => 0,
#                 CHILD => [ {
#                           TAG => name
#                           PARENT => \$parent,
#                           IDX => 0,
#                           CHILD => [ {
#                               TAG => name
#                               PARENT => \$parent,
#                               CHILD => etc etc
#                              }
#                            ]
#                        }
#                   ]
#                }
#
#
#
sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my ($xml) = @_;

   my $self = {
                XML         => undef,    # name of the input file
                PARENT      => undef,
                CHILD       => [],
   };
   bless( $self, $class );
   if ( $xml =~/\s*</ || ( $xml && -e $xml )  ) {
      $self->{XML}    = $xml;
      $self->{PARENT} = \$self;    # first elements go to the initial object
      __parse($self);
   }
   else {
      print "$xml not found\n";
      return;
   }
   bless( $self, $class );
   return $self;
}

sub getElementByTagName {
   my $self = shift;
   my ( $want_tag, $want_attr, $value ) = @_;
   my @tags;
   foreach my $element ( @{ $self->{CHILD} } ) {
      my $tag = $element->tag;
      if ( $tag eq $want_tag ) {
         if ( $want_attr && $value ) {
            if ( $element->attr( $want_attr, $value ) ) {
               push @tags, $element;
            }
         }
         else {
            push @tags, $element;
         }
      }
      @tags = ( @tags, ( $element->getElementByTagName( $want_tag, $want_attr, $value ) ) );
   }
   wantarray ? @tags : $tags[0];
}

sub getElementByAttrName {
   my $self = shift;
   my ( $want_attr, $value ) = @_;
   my @tags;
   foreach my $element ( @{ $self->{CHILD} } ) {
      push @tags, $element if $element->attr( $want_attr, $value );
      @tags = ( @tags, ( $element->getElementByAttrName( $want_attr, $value ) ) );
   }
   wantarray ? @tags : $tags[0];
}

sub getFirstElement {
   my $self = shift;
   return $self->{CHILD}->[0];
}

#---------------------------------------------
# update child array indexes
#---------------------------------------------
sub reindex {
   my $self = shift;
   foreach my $i ( 0..(@{$self->{CHILD}} -1 )) {
      $self->{CHILD}->[$i]->index($i);
   }
}

# insert a child element
sub insertChild {
   my $self = shift;
   my ($tag,$attrs) = @_;
   my $element=ParseXML::Element->new(\$self,$tag,$attrs);
   push @{$self->{CHILD}},$element;
   $self->reindex;   
}

# insert a sibling element
sub insertSibling {
   my $self = shift;
   my ($tag,$attrs) = @_;
   my $index = $self->index;
   my $parent = $self->parent;
   my $element=ParseXML::Element->new(\$parent,$tag,$attrs);
   splice(@{$self->parent->{CHILD}},$index+1,0,$element);
   $self->parent->reindex;
}

sub getNextChild {
   my $self = shift;
   if ( defined $self->{CHILD} && @{$self->{CHILD}}>0 ) {
      return $self->{CHILD}->[0];
   }
   else {
      return;
   }
}

sub getNextSibling {
   my $self = shift;
   my $next = $self->index + 1;
   if ( $next < @{$self->parent->{CHILD}} ) {
      return $self->parent->{CHILD}->[$next];
   }
   else {
      return;
   }
}

sub delete {
   my $self = shift;
   my $next = $self->getNextSibling;
   my $parent = $self->parent;
   splice(@{$self->parent->{CHILD}},$self->index,1);
   $parent->reindex;
   return $next;
}
# get next line
# if child nodes return 1st child
#

sub getNextElement {
   my $self        = shift;
   # do we have child nodes ?

   my $element = $self->getNextChild;
   
   # do we have sibling nodes
   if ( ! $element ) {
      $element = $self-> getNextSibling;
   }
   
   # need to move back up the tree 
   while ( ! $element ) {
      $self = $self->parent;
     if ( ! defined $self->{XML} ) {
          $element = $self->getNextSibling;
     }
     else {
        return;
     }
   }
   return $element;
 }

sub parentNode {
   my $self   = shift;
   my $parent = $self->parent;
   $$parent;
}

sub index {
   my $self = shift;
   $self->{IDX} = shift if @_;
   $self->{IDX};
}


sub as_text {
   my $self = shift;
   my $xml;
   foreach my $elementptr ( @{ $self->{CHILD} } ) {
      $xml .= $elementptr->as_text(0);
   }
   return $xml;
}

sub as_tree {
   my $self = shift;
   foreach my $elementptr ( @{ $self->{CHILD} } ) {
      $elementptr->as_tree(0);
   }
}

sub __me {
   my $calledby = "main";
   if ( ( defined( scalar caller(1) ) ) ) {
      $calledby = ( caller(1) )[3];
      $calledby =~ s/^.+?:://;
   }
   return "$calledby";
}

#----------------------------------------------------------------------------------------------------
# delete the current tag
#----------------------------------------------------------------------------------------------------
sub __parse {
   my $self = shift;
   my $xmlparser = XML::Parser->new( Style => 'Tree' );
   $xmlparser->setHandlers(
                            Default      => sub { __xml_default_handler( $self, @_ ) },
                            Init         => sub { __xml_init( $self,            @_ ) },
                            Final        => sub { __xml_final( $self,           @_ ) },
                            Start        => sub { __xml_start( $self,           @_ ) },
                            End          => sub { __xml_end( $self,             @_ ) },
                            Char         => sub { __xml_char( $self,            @_ ) },
                            Proc         => sub { __xml_proc( $self,            @_ ) },
                            Comment      => sub { __xml_comment( $self,         @_ ) },
                            CdataStart   => sub { __xml_cdatastart( $self,      @_ ) },
                            CdataEnd     => sub { __xml_cdataend( $self,        @_ ) },
                            Unparsed     => sub { __xml_unparsed( $self,        @_ ) },
                            Notation     => sub { __xml_notation( $self,        @_ ) },
                            ExternEnt    => sub { __xml_externent( $self,       @_ ) },
                            ExternEntFin => sub { __xml_externentfin( $self,    @_ ) },
                            Entity       => sub { __xml_entity( $self,          @_ ) },
                            Element      => sub { __xml_element( $self,         @_ ) },
                            Attlist      => sub { __xml_attlist( $self,         @_ ) },
                            Doctype      => sub { __xml_doctype( $self,         @_ ) },
                            DoctypeFin   => sub { __xml_doctypefin( $self,      @_ ) },
                            XMLDecl      => sub { __xml_xmldecl( $self,         @_ ) }
   );
   my @tree;
   if (  $self->{XML} =~/\s*</ ) {
      @tree = $xmlparser->parse( $self->{XML} );
   }
   else {
      @tree = $xmlparser->parsefile( $self->{XML} );
   }
}

sub __xml_init {
   my $self = shift;
   debug( Dumper( \@_ ) );
}

sub __xml_final {
   my $self = shift;
   debug( Dumper( \@_ ) );
}

sub __xml_start {
   my $self = shift;
   my ( $expat, $tag, %attrs ) = @_;
   # where do I put the elements
   my $parent = ${ $self->{PARENT} } || $self;

   # create element
   my $element = ParseXML::Element->new( \$parent, $tag, \%attrs );
   $element->index(scalar @{ $parent->{CHILD} });
   push @{ $parent->{CHILD} }, $element;

   # assume next element will be a child
   my $child = $parent->{CHILD}->[-1];
   $self->{PARENT} = \$child;
}

sub __xml_end {
   my $self = shift;
   # self parent -> child -> parent
   my $child = $self->{PARENT};
   $self->{PARENT} = $$child->{PARENT};
}

sub __xml_char {
   my $self = shift;
   my ( $expat, $string ) = @_;

#   $string =~ s/^\s+|\s+$//g;
   if ($string) {
      my $parent = ${ $self->{PARENT} } || $self;
      if ( $parent->text ) {
         $string .= $parent->text;
      }
      $parent->text($string);
   }
}

sub __xml_proc {
   my $self = shift;
   my ( $expat, $target, $data ) = @_;
   debug( Dumper( \@_ ) );
   print __me();
   print BOLD RED "Proc $target $data\n";
}

sub __xml_comment {
   my $self = shift;
   my ( $expat, $comment ) = @_;
   my $parent = ${ $self->{PARENT} } || $self;
   my $element = ParseXML::Element->new( \$parent, "comment", $comment );
   $element->index(scalar @{ $parent->{CHILD} });
   push @{ $parent->{CHILD} }, $element;
}

sub __xml_cdatastart {
   my $self = shift;
   debug( Dumper( \@_ ) );
   print BOLD RED "CdataStart\n";
}

sub __xml_cdataend {
   my $self = shift;
   debug( Dumper( \@_ ) );
   print BOLD RED "CdataEnd\n";
}

sub __xml_unparsed {
   my $self = shift;
   debug( Dumper( \@_ ) );
   print BOLD RED "Unparsed\n";
}

sub __xml_notation {
   my $self = shift;
   debug( Dumper( \@_ ) );
   print BOLD RED "Notation\n";
}

sub __xml_externent {
   my $self = shift;
   debug( Dumper( \@_ ) );
   print BOLD RED "ExternEnt\n";
}

sub __xml_externentfin {
   my $self = shift;
   debug( Dumper( \@_ ) );
   print BOLD RED " ExternEntFin\n";
}

sub __xml_entity {
   my $self = shift;
   debug( Dumper( \@_ ) );
   print BOLD RED "Entity\n";
}

sub __xml_element {
   my $self = shift;
   debug( Dumper( \@_ ) );
   print BOLD RED "Element\n";
}

sub __xml_attlist {
   debug( Dumper( \@_ ) );
   my $self = shift;
   print BOLD RED "Attlist\n";
}

sub __xml_doctype {
   my $self = shift;
   print "doctype\n";
   debug( Dumper( \@_ ) );
}

sub __xml_doctypeFin {
   my $self = shift;
   debug( Dumper( \@_ ) );
   print BOLD RED "Doctypefin\n";
}

sub __xml_xmldecl {
   my $self = shift;
   my ( $expat, $version, $encoding, $standalone ) = @_;
   my $parent = ${ $self->{PARENT} } || $self;
   my $element = ParseXML::Element->new( \$parent, "xmldecl", [ $version, $encoding, $standalone ] );
   $element->index(@{ $parent->{CHILD} });
   push @{ $parent->{CHILD} }, $element;
}

sub __xml_default_handler {
   my $self = shift;
}
1;
