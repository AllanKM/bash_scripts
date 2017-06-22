#==============================================================================================
# Revision : $Revision: 1.1 $
# Source   : $Source: /cvsroot/hpodstools/lfs_tools/ihs/lib/resolv_symlink.pm,v $
# Date     : $Date: 2012/05/16 14:00:36 $
#
# $Log: resolv_symlink.pm,v $
# Revision 1.1  2012/05/16 14:00:36  steve_farrell
# Install new IHS ITCS104 scanning scripts
#
# Revision 1.3  2012/05/10 13:12:04  stevef
# Fix looping symlink
#
# Revision 1.2  2012/03/08 13:01:41  stevef
# add script dir to lib env dir
#
# Revision 1.1  2012/03/07 09:48:33  stevef
# Initial revision
#
# Revision 1.1  2012/03/07 09:21:25  steve
# Initial revision
#
#==============================================================================================
#!/usr/local/bin/perl

use strict;
use FindBin;
use lib ("$FindBin::Bin/lib", "$FindBin::Bin");
use debug;
use Data::Dumper;
use Exporter;
our ($VERSION) = '$Revision: 1.1 $' =~ m{ \$Revision: \s+ (\S+) }x;

our @ISA    = qw(Exporter);
our @EXPORT = qw( realname );

my $debug = $ENV{debug} || 0;

sub realname {
   my $object = shift;
   return _realname($object);
   
}
#============================================================
# resolve symlinks to real file
#============================================================
sub _realname {
   my ( $object ) = @_;
   debug("resolving symlink $object");
   my @dirs = split /\//xms, $object;
   my $workingpath=q{};
   foreach my $dir ( @dirs ) {
      next if ! $dir;
      debug("Appending \/$dir to $workingpath");
      # append dir to working path
      $workingpath .= q{/}.$dir;
      
      if ( -e $workingpath ) {
         $workingpath = _resolve_realname($workingpath);     # follow symlinks to find real name
      }
      else {
         debug("$workingpath does not exist");
         return q{};
      }
   }
   return $workingpath;
}

sub _resolve_realname {
   my ($object)= @_;
   if ( -l $object ) {
      debug("$object is a symlink");
      return _symlink_target($object);
   }
   else {
     return $object;
   }
}

sub _symlink_target {
   my ($link) = @_;

   while ( -l $link ) {
      debug("----> resolving $link");
      my $target = readlink $link;
      debug("Symlink returned $target");
      while ( $target =~ /^\./xms ) {
         if ( $target =~ /^\.\.\//xms ) {          # starts ../
                                                # remove ../
                                                # remove last 2 level from link
            debug("\t$link starts with ../");
            $target =~ s/\.\.\///smx;
            $link =~ s/\/[^\/]*$//smx;
            $link =~ s/\/[^\/]*$/\//xms;
            debug("\tlink modified to $link");
            debug("\ttarget modified to $target");
         }
         elsif ( $target =~ /^\.\//smx ) {
            debug("$link starts with ./");
            return $link if $target eq './';
            $link =~ s/\/[^\/]*$/\//xms;
             debug("\tlink modified to $link");
         }
         else {
            return $link;
         }
      }
      if ( $target =~ /^\//xms ) {
         debug("$target starts with / replacing link ");
         $link = $target;
         debug("\tlink modified to $link");
      }
      else {
         debug("\trelative to current dir ");
         $link =~ s/\/[^\/]*$/\//xms;
         debug("\tlink amended to $link");
         $link .= $target;
         debug("\tappending $target -> $link");
      }
      debug("resolved to $link <-------");
   }
   return $link;
}
1;