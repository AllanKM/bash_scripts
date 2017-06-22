#!/usr/local/bin/perl
# Description: Validates URL is responding by using url.pm
#
# Usage
#   chk_url.pm [name] [url] [string]
use lib "/lfs/system/tools/ihs/lib";
use url;
use POSIX "strftime";
my $DEBUG = 0;        # Set to 1 if you want to see debug on STDOUT
my @urls;             # array of urls to check
my @urls_ei_stats;    # array of urls to check
my ( %failed_urls_old, %failed_urls_current );    # Hash of failed urls
my $checkName   = shift @ARGV || 'Check URL';
my $checkURL    = shift @ARGV || 'http://localhost/site.txt';
my $checkString = "@ARGV"     || undef;
my $caller = $ENV{'chk_url_caller'};
$check = new url(
                  {
                    name   => $checkName,
                    url    => $checkURL,
                    string => $checkString,
                    debug  => $DEBUG,
                  }
);

if ( !$check ) {
   print "#### Failed to initialize instance url\n";
   exit 1;
}
elsif ( my $error = $check->error() ) {
   print "#### Failed to initialize $url->{name} instance: [$error]\n";
   exit 1;
}
if ( $check->do_probe() ) {
   $check->debug("$check->{url}");
}
else {
   print "#### Failed while probing $checkName:", $check->error(), "\n";
}
if ( $check->is_responding() ) {

	if ( $caller eq "check_ihs" ) {
		print "\t$checkName $checkURL OK", $check->error(), "\n";
	}
	else {
		print "\t$checkName OK", $check->error(), "\n";
	}

}
else {
   print "#### $checkName $checkURL failed: ", $check->error() ."\n";
   if ( $check->error() !~ /(?:4\d\d:|5\d\d\:)/ && $check->error() !~ /The pattern:/i ) {
      print "#### Waiting 10 seconds and trying again\n";
      sleep 10;
		if ( $caller eq "check_ihs" ) {
			if ( $check->do_probe() and $check->is_responding() ) {
				print "#### $checkName $checkURL is now OK", $check->error(), "\n";
			}
			else {
				print "#### Recheck of $checkName $checkURL failed: ", $check->error(), "\n";
			}
		}
		else {
			if ( $check->do_probe() and $check->is_responding() ) {
				print "#### $checkName is now OK", $check->error(), "\n";
			}
			else {
				print "#### Recheck of $checkName failed: ", $check->error(), "\n";
			}
		}
	}
}

