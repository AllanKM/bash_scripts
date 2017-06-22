package ParseXML::Element;
use strict;
use Data::Dumper;
our @ISA    = qw(ParseXML::ParseXML);


sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;
   
   my $parent = shift;
   my ($tag,$attrref) = @_;
   my $self;

   if ( $tag eq "comment" ) {
      $self = { 
         PARENT => $parent,
         IDX => 0,
         DEPTH => 0,
         COMMENT => $attrref };
   }
   elsif ( $tag eq "xmldecl" ) {
      $self = { 
         PARENT => $parent,
         IDX => 0,
         DEPTH => 0,
         XMLDECL => $attrref };
   }
   else {   
      $self = {
           PARENT => $parent,
           CHILD => [],
           IDX => 0,
           DEPTH => 0,
           TEXT => undef,
           ATTR => $attrref,
           TAG => $tag,
      };
   }
   bless ($self,$class);
   return $self;
}


sub remove_attr {
   my $self = shift;
   my $attr = shift;
   delete $self->{ATTR}->{$attr};
}

sub attr {
   my $self = shift;
   my ($attr,$value,$set) = @_;
   if ( $set ) {
      $self->{ATTR}->{$attr} = $value;
   }
   else {
      if ( defined $value ) {
         return $self->{ATTR}->{$attr} if $value eq $self->{ATTR}->{$attr};
      }
      else {
         return $self->{ATTR}->{$attr} if exists $self->{ATTR}->{$attr};
      }
   }
}

sub attr_names {
   my $self = shift;
   if ( defined $self->{ATTR} ) {
      return keys %{$self->{ATTR}} ;
   }
   else {
      return {};
   }
}

sub tag {
   my $self = shift;
   if ( @_ ) {
      $self->{TAG} = $_[0];
   }
   if ( defined $self->{COMMENT} ) {
      return "<!--";
   }
   elsif ( defined $self->{XMLDECL} ) {
      return "<?xml>";
   }
   
   return $self->{TAG} || '';
}

sub text {
   my $self = shift;
   if ( @_ ) {
      $self->{TEXT} = shift;
   }
   $self->{TEXT};
}

sub comment {
   my $self = shift;
   if ( @_ ) {
      $self->{COMMENT} = $_[0];
   }
   $self->{COMMENT};
}

sub xmldecl {
   my $self = shift;
   if ( @_ ) {
      $self->{XMLDECL} = $_[0];
   }
   $self->{XMLDECL};
}

sub parent {
   my $self = shift;
   ${$self->{PARENT}};
   
}

#=================================================================
# return formatted string representation of xml object
#=================================================================
sub as_text {

   my $self = shift;
   my $indent=shift || 0;
   my $exclude_attrs ={};
   my $excludes;
   while ( @_ > 0 ) {
      if ( $_[0] =~ /^\d+$/ ) {
         $indent=shift;
      }
      if ( $_[0] =~ /^exclude_attr/xi ) {
         shift;
         $excludes = shift;
         %{$exclude_attrs} =  map { lc($_) => defined } @{$excludes} ;
      }
      shift;
   }

   my $xml;

   
   if ( $self->comment ) {
      # element is a comment
       $xml .= "   " x $indent . "<!-- ".$self->comment. "-->\n";
   }
   elsif ( $self->xmldecl ) {
       $xml .=  "   " x $indent . "<?xml";
       if ( defined @{$self->{XMLDECL}}[0] ) {
          $xml .=  ' version="'.@{$self->{XMLDECL}}[0].'"';
       }
       if ( defined @{$self->{XMLDECL}}[1] ) {
          $xml .= ' encoding="'.@{$self->{XMLDECL}}[1].'"';
       }
       if ( defined @{$self->{XMLDECL}}[2] ) {
          $xml .= ' standalone="'.@{$self->{XMLDECL}}[2].'"';
       }
       $xml .= "?>\n";
   }
  
   else {
      if ( $self->tag ) {
        $xml .= "   " x $indent . "<".$self->tag;
        
        if ( $self ->{ATTR} ) {
           # Element has attributes
           foreach my $attr ( keys %{$self->{ATTR}} ) {
              if ( ! defined $exclude_attrs->{lc($attr)} ) {
                 $xml .= " $attr=\"".$self->{ATTR}->{$attr}."\"";
              }
           }
        }
        if ( $self->text ) {
           # Element has embedded text node eg <tag>some text</tag>
           $xml .= ">".$self->text;
           if ( ! defined @{$self->{CHILD}} ) {
              $xml .= "</". $self->tag.">\n";
           }
        }
        if ( defined @{$self->{CHILD}} ) {
           if ( ! $self->text ) {
              $xml .= ">\n";
           }
           foreach my $child ( @{$self->{CHILD}} ) {
              if ( $child->comment ) {
                  $xml .= "   " x $indent . "<!-- ".$child->comment. "-->\n";
              }
              else {           
                $xml .=  $child->as_text($indent+1, exclude_attrs=>$excludes);
              }
           }
           $xml .=  "   " x $indent . "</".$self->tag.">\n";
        }
        else {
           $xml .= "/>\n" if ! $self->text;
        }
      }
   }
   return $xml;
}

sub as_tree {
   my $self = shift;
   my $indent=shift || 0;

   if ( $self->comment ) {
       print "   " x $indent;
       print "IDX:".$self->{IDX}." " if exists $self->{IDX};
       print "<!-- ".$self->comment. "-->\n";
   }
   elsif ( $self->xmldecl ) {
       print "   " x $indent;
       print "IDX:".$self->{IDX}." " if exists $self->{IDX};
       print "<?xml";
       if ( defined @{$self->{XMLDECL}}[0] ) {
          print ' version="'.@{$self->{XMLDECL}}[0].'"';
       }
       if ( defined @{$self->{XMLDECL}}[1] ) {
          print ' encoding="'.@{$self->{XMLDECL}}[1].'"';
       }
       if ( defined @{$self->{XMLDECL}}[2] ) {
          print ' standalone="'.@{$self->{XMLDECL}}[2].'"';
       }
       print "?>\n";
   }
  
   else {
      if ( $self->tag ) {
        print "   " x $indent;
        print "IDX:".$self->{IDX}." " if exists $self->{IDX};
        print "<".$self->tag;
        
        if ( $self ->{ATTR} ) {

           foreach my $attr ( keys %{$self->{ATTR}} ) {
              print " $attr=\"".$self->{ATTR}->{$attr}."\"";
           }
        
        }
        if ( $self->text ) {
           print ">".$self->text;
           if ( ! defined @{$self->{CHILD}} ) {
              print "</". $self->tag.">\n";
           }
        }
        if ( defined @{$self->{CHILD}} ) {
           if ( ! $self->text ) {
              print ">\n";
           }
           else {
              print "\n";
           }
           foreach my $child ( @{$self->{CHILD}} ) {
              if ( $child->comment ) {
                  print "   " x $indent . "<!-- ".$child->comment. "-->\n";
              }
              else {           
                 $child->as_tree($indent+1);
              }
           }
           print  "   " x $indent . "</".$self->tag.">\n";
        }
        else {
           print "/>\n" if ! $self->text;
        }
      }
   }
}
1;