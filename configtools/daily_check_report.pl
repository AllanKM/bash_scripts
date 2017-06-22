#!/usr/bin/perl 
use strict;
use Data::Dumper;
my $check_value;
my $plex;
my %report;
my $input_count=$ENV{'DAILY_CHECK_COUNT'};
#==================================================
# page css
#==================================================
print qq(
   <style type="text/css">
   .top {
      position: relative;
      margin-right: 50%;
      float: right;
      font-size: 10px;
   }
   .host { 
      color:green;
      width:45px; 
   }
   .space {
       width:20px;
   }
   .second { 
      height: 20px;
   }
   .even {
      background-color: white;
   }
   .odd {
      background-color: #FFFFCC;
   }
   h1 {
      color:blue;
      text-decoration:underline;
      font-size:14px;
   }    
   .alert {
      color: red;
      font-weight: bold;
   }
   .warn {
      background-color: #ffff99;
   }
   table { 
      width:90%;
      font-size:13px;
		font-family: "liberation mono","lucida console","courier new",courier,monospace;
   }
   
   </style>
   );

#===============================================
# create hash of data
#===============================================
my %raw_data;
my $raw_data = \%raw_data;
while (my $line = <STDIN>) {
   my ($check, $title);
   if ($line =~ /^\$CHECK\$/) {
      my ($TAG, $host, $prisort, $secsort, $data) = split(',', $line, 5);

      $data =~ s/^[\s\"]+|[\s\"]+$//g;
      if ($data =~ '^CHECK') {
         $data =~ s/^CHECK,//;
         $raw_data->{$prisort}->{$secsort}->{check} = $data;
      }
      elsif ($data =~ '^TITLE') {
         $data =~ s/^TITLE,//;
         $raw_data->{$prisort}->{$secsort}->{title} = $data;
      }
      else {
         push @{ $raw_data->{$prisort}->{$secsort}->{hosts}->{$host}->{rows} }, $data;
      }
   }
}
my $last;

#=================================================
# print the report to in memory array
#================================================
my $output_count;
foreach my $prisort (sort { $a <=> $b } keys %raw_data) {
   foreach my $secsort (sort { $a <=> $b } keys %{ $raw_data{$prisort} }) {
      $output_count++;
      my $secinfo = {
                      title        => $raw_data{$prisort}{$secsort}{title},
                      prisort      => $prisort,
                      secsort      => $secsort,
                      check        => $raw_data{$prisort}{$secsort}{check},
                      limit_min    => undef,
                      limit_max    => undef,
                      limit_string => undef,
                      limit_count  => 0,
      };

      #=============================================================
      # split limit check into component parts
      #=============================================================
      if ($secinfo->{check} =~ /^limit/i) {
         my $check = $secinfo->{check};
         $secinfo->{check} = 'limit';
         $check =~ s/^.*=\(//;
         my ($min, $max,, $string, $prefered) = split(/\s*,\s*/, $check);
         $string =~ s/\s*\)\s*$//;
         $secinfo->{limit_min} = $min || 0;
         $secinfo->{limit_max} = $max || 1;
         $secinfo->{limit_string} = $string;
      }

      #=============================================================
      # Create report
      #=============================================================
      report_title($secinfo);
      foreach my $host (sort keys %{ $raw_data{$prisort}{$secsort}{hosts} }) {
         my $count = 0;
         $secinfo->{xin} = 0;
         foreach my $row (@{ $raw_data{$prisort}{$secsort}{hosts}{$host}{rows} }) {
            $row = highlight_issues($host, $row, $secinfo);
            $row =~ s/\t/\&nbsp\;\&nbsp\;\&nbsp\;\&nbsp\;\&nbsp\;\&nbsp\;/g;
            push @{ $report{results} }, "<tr><td class=\"space\"></td><td class=\"host\">$host</td><td>:  $row</td></tr>\n";
            $count++;
         }
         if ($count > 1) {
            push @{ $report{results} }, "<tr class=\"second\"><td></td><td></td></tr>\n";
         }
      }
      #print STDERR Dumper($secinfo);
      if ($secinfo->{check} eq 'limit') {
         if ($secinfo->{limit_count} > $secinfo->{limit_max}) {
            print STDERR $secinfo->{limit_count}. "is greater than ".$secinfo->{limit_max}. "\n";
            push @{ $report{results} },
              "<span class=alert><font color=red>*** Too many instances of '" . $secinfo->{limit_string} . "' found, expected:".$secinfo->{limit_max}." found:".$secinfo->{limit_count}."***</font></span>";
            my $count = $secinfo->{limit_count} || 1;
            $report{warn}{"$prisort\.$secsort"}{count} = $count;
         }
         if ($secinfo->{limit_count} < $secinfo->{limit_min}) {
            push @{ $report{results} },
              "<span class=alert><font color=red>*** Too few instances of '" . $secinfo->{limit_string} . "' found, expected:".$secinfo->{limit_min}." found:".$secinfo->{limit_count}. "***</font></span>";
            my $count = $secinfo->{limit_count} || 1;
            $report{warn}{"$prisort\.$secsort"}{count} = $count;
         }
      }
      push @{ $report{results} }, "</table>\n";
   }
}
print "<a id='top'></a>";

#=============================================================
# print summary table if any lines are highlighted
#=============================================================
print "<h1>Section Summary</h1>";
if ( $input_count != $output_count ) {
      print "<h3>Input sections:$input_count    Output sections: $output_count</h2>\n";
}
print "<table>\n\<tr class=even>";
my $i     = 0;
my $r     = 1;
my $class = "odd";
foreach my $prisec (sort { $report{warn}{$a}->{title} cmp $report{warn}{$b}->{title} } keys %{ $report{warn} }) {

   if ($report{warn}{$prisec}{count} > 0) {
      print "<td><a class='alert' href=\"#$prisec\" target=\"_self\"><font color=\"red\">$report{warn}{$prisec}{title}</font></a></td>";
      print "<td class='alert'><font color=\"red\">$report{warn}{$prisec}{count}</font></td>\n";
   }
   else {
      print STDERR Dumper($report{warn}{$prisec});
      print "<td><a href=\"#$prisec\" target=\"_self\">$report{warn}{$prisec}{title}</a></td>";
      if ( $report{warn}{$prisec}{check} == 1 ) {
         print "<td>$report{warn}{$prisec}{count}</td>\n";         
      }
      else {
         print "<td>n/c</td>\n";
      }


   }
   $i++;
   if ($i % 2 == 0) {
      print "</tr>\n<tr class=$class>\n";
      $r++;
      if ($r % 2 == 0) {
         $class = "even";
      }
      else {
         $class = "odd";
      }
   }
}
print "</tr></table>\n";

#=============================================================
# print the results
#=============================================================
foreach my $line (@{ $report{results} }) {
   print $line;
}

#=============================================================
# Highlight potential problems
#=============================================================
sub highlight_issues {
   my ($host, $row, $secinfo) = @_;

   # XML defines MD5 check
   if ($secinfo->{check} eq "md5") {
      set_check_used_flag($secinfo);
      $row = md5_check($host, $row, $secinfo);
   }
   elsif ($secinfo->{check} eq 'limit') {
      set_check_used_flag($secinfo);
      $row = limit_check($host, $row, $secinfo);
   }

   # XML defines MD5 check by plex
   elsif ($secinfo->{check} eq "md5_by_plex") {
      set_check_used_flag($secinfo);
      if ($plex ne substr($host, 1, 1)) {
         $plex = substr($host, 1, 1);
         $secinfo->{check_value} = undef;
      }
      $row = md5_check($host, $row, $secinfo);
   }

   # XML defines check of %used
   elsif ($secinfo->{check} =~ /\%used/) {
      set_check_used_flag($secinfo);
      $row = percent_used($host, $row, $secinfo);
   }

   # XML defines count of rows
   elsif ($secinfo->{check} =~ /count/) {
      set_check_used_flag($secinfo);
      if ($row !~ /(?:^\s+$|WWSM Omnibus Alerts occuring|================|\/logs\/Omnibus_logs|-------)/i) {

         #       print STDERR $row;
         sum_error($secinfo);
      }
   }

   # Highlight if server uptime less than 1 day
   elsif ($row =~ /Server\suptime:\s+(\d+)\s+days/) {
      set_check_used_flag($secinfo);
      if ($1 == 0) {

         #        print STDERR "Matched server uptime $1\n";
         sum_error($secinfo);
         $row = "<span class=warn>$row</span>";
      }
   }

   # Pubstatus lines
   elsif (
      $row =~ /https:\/\/v\d{5}:\d{4}\/LDist-EI\s+(\w+)
               \s+(\d+)\s+(\d+)\s+(\d+)
               /x
     ) {
        set_check_used_flag($secinfo);
      if ($1 ne "UP" || $2 > 0 || $3 > 0 || $4 > 0) {

         #        print STDERR "Matched $1 $2 $3 $4\n";
         sum_error($secinfo);
         $row = "<span class=alert><font color=\"red\">$row</font></span>";
      }
   }

   # DNS changes
   elsif ($row =~ /IN\s+(?:CNAME|A)\s+/i) {
      set_check_used_flag($secinfo);
      if ($row =~ /[\|\<\>]/) {
         sum_error($secinfo);
         $row = "<span class=alert><font color=\"red\">$row</font></span>";
      }
   }

   # XIN issues
   elsif ($row =~ /Cannot find XIN application-level ping/) {
      set_check_used_flag($secinfo);

      #                  print STDERR "$host $row\n";
      $secinfo->{xin} = 1;
      $row = "<span class=warn>$row</span>";
   }

   # XIN error count
   elsif ($row =~ /###### Done with (\d+) detected errors/) {
      set_check_used_flag($secinfo);
      if ($1 > 0 && $secinfo->{xin} == 0) {
         sum_error($secinfo);
         $row = "<span class=alert><font color=\"red\">$row</font></span>";
      }
   }
   elsif ($row =~ /\[INFO\]\s+Publisher\[\w+\]\s+Subscriber\[\w+\]\s+Result\[([\s\w]+)\]/i) {
      set_check_used_flag($secinfo);
      if ($1 !~ /^Received$/i) {

         #      print STDERR "Publish error $1\n";
         sum_error($secinfo);
         $row = "<span class=alert><font color=\"red\">$row</font></span>";
      }
   }
   return $row;
}

#=============================================================
# Check limits placed on lines in section
#=============================================================
sub limit_check {
   my ($host, $row, $secinfo) = @_;
   my $string = $secinfo->{limit_string};
   if ($row =~ /$string/i) {
      $secinfo->{limit_count}++;
      print STDERR "$string matched by $row\n";
      print STDERR $secinfo->{limit_count} . " " . $secinfo->{limit_max} . "\n";
      if ($secinfo->{limit_count} > $secinfo->{limit_max}) {
         $row = "<span class=alert><font color=\"red\">$row</font></span>";
      }
   }
   return $row;
}

#=============================================================
# Output the section title and store any checks
#=============================================================
sub report_title {
   my $secinfo = shift;
   my $title   = $secinfo->{title};
   my $prisort = $secinfo->{prisort};
   my $secsort = $secinfo->{secsort};
   $secinfo->{title} =~ s/{[\w_\>\<\=\%]+}//;
   push @{ $report{results} }, "<h1 id=\"$prisort.$secsort\">$secinfo->{title}<div class=top><a href='#top' target=\"_self\">top</a></div></h1>\n";
   push @{ $report{results} }, "<table>\n";
   $report{warn}{"$prisort\.$secsort"}{count} = 0;
   $report{warn}{"$prisort\.$secsort"}{check} = 0;
   $report{warn}{"$prisort\.$secsort"}{title} = $secinfo->{title};
}

#==================================================================
# Compare MD5 sum and flag any that are different
#==================================================================
sub md5_check {
   my ($host, $row, $secinfo) = @_;
   my ($test_value) = $row =~ /([0-9a-f]{32})/;
   if (!$secinfo->{check_value}) {
      $secinfo->{check_value} = $test_value;
   }
   else {
      if ($secinfo->{check_value} ne $test_value) {
         sum_error($secinfo);
         $row = "<span class='alert'><font color=\"red\">" . $row . "</font></span>";
      }
   }
   return $row;
}

#===================================================================
# increment section highlited counter
#===================================================================
sub sum_error {
   my ($secinfo) = @_;
   my $prisort   = $secinfo->{prisort};
   my $secsort   = $secinfo->{secsort};
   $report{warn}{"$prisort\.$secsort"}{check}=1;;
   $report{warn}{"$prisort\.$secsort"}{count}++;;
}

sub set_check_used_flag {
   my ($secinfo) = @_;
   my $prisort   = $secinfo->{prisort};
   my $secsort   = $secinfo->{secsort};
   $report{warn}{"$prisort\.$secsort"}{check}=1;;
}
#==================================================================
# Find %value and compare against check value
#==================================================================
sub percent_used {
   my ($host, $row, $secinfo) = @_;
   my ($check_value) = $row =~/(\d+\.?\d?)\s?%/;
   my $error = 0;
   if ($check_value) {
      my ($test, $value) = $secinfo->{check} =~ /([\>\<\=])(\d+)/;
      if ($test eq '<' && $check_value < $value) {
         $error = 1;
      }
      elsif ($test eq '>' && $check_value > $value) {
         $error = 1;
      }
      elsif ($test eq '=' && $check_value != $value) {
         $error = 1;
      }
      elsif ($test !~ /[\>\<\=]/) {
         print STDERR "Invalid operator $test\n";
      }
   }
   if ($error) {
      sum_error($secinfo);
      $row = "<span class='alert'><font color=\"red\">" . $row . "</font></span>";
   }
   return $row;
}
