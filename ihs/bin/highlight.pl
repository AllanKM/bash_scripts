#!/usr/local/bin/perl
use strict;

use Term::ANSIColor qw(:constants);

if ($ARGV[1] eq "BOLD"){
  print BOLD BLUE "$ARGV[0]";
}

if ($ARGV[1] eq "HEADER"){
  print BOLD GREEN "$ARGV[0]";
}

if ($ARGV[1] eq "SUBHEADER"){
  print BOLD MAGENTA "$ARGV[0]";
}

if ($ARGV[1] eq "GOLDEN_SUM"){
  print BOLD GREEN "$ARGV[0]";
}

if ($ARGV[1] eq "ERROR_SUM"){
  print BOLD RED "$ARGV[0]";
}

if ($ARGV[1] eq "ERROR"){
  print  BOLD ON_RED "$ARGV[0]";
}

if ($ARGV[1] eq "GOLDEN"){
  print  BOLD ON_GREEN "$ARGV[0]";
}

if ($ARGV[1] eq "UNKNOWN"){
  print  BOLD ON_MAGENTA "$ARGV[0]";
}

if ($ARGV[1] eq "REVERSE"){
  print BOLD BLACK ON_YELLOW "$ARGV[0]";
}

if ($ARGV[1] eq "UNDERLINE"){
  print BOLD UNDERLINE ON_BLUE "$ARGV[0]";
}


print RESET;  
