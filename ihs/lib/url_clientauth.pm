#!/usr/local/bin/perl -w
# Author: Russ Scadden
# This Perl module can be used to determine if a specific url is
# responding and a given string is returned.  It uses wget to fetch the
# url.

# Branched from url.pm to use curl to present certificate/password for use in check_was.sh with Client Authentication turned on (as wget cannot be given cert password)

package url;
use FileHandle;
use MIME::Base64;
use strict;

sub new {

   # name => string identifing the url associated with this instance of url.pm
   # url => url to request
   # string => text to look for in the response
   # debug => define if you want debug output printed to STDOUT
   # validate => perl expression to evaluate
    my $class    = shift @_;
    my $settings = shift @_;
    $settings->{err}   = undef;
    $settings->{debug} = 0
        unless ( exists $settings->{debug} );
    $settings->{debug} = $ENV{debug} if defined $ENV{debug};
    $settings->{name} = 'Monitored URL'
        unless ( exists $settings->{name} );
    $settings->{url} = ''
        unless ( exists $settings->{url} );
    $settings->{string} = undef
        unless ( exists $settings->{string} );
    $settings->{validate} = '1 == 1'
        unless ( exists $settings->{validate} );
    my $url = $settings->{url};
    my $app = $settings->{name};
    $settings->{'no-check-certificate'} = 0;
    print "check if no-check-certificate is a valid option\n"  if $settings->{debug};
    open CMD, '/usr/bin/wget --no-check-certificate 2>&1 |';

    while ( my $line = <CMD> ) {

        if ( $line =~ /unrecognized/i ) {
            $settings->{'no-check-certificate'} = 1;
            print "no-check-certificate option not available\n" if $settings->{debug};
        }
    }
    close CMD;
    print "no-check-certificate is valid\n" if !$settings->{'no-check-certificate'} &&  $settings->{debug};

    print "\tURL::new=> Parsed request to pull [$url] for $app\n"
        if $settings->{debug};
    bless( $settings, $class );
    return $settings;
}

sub error {
    my $self = shift @_;
    return $self->{err};
}

sub do_probe {
    my $self = shift @_;
    my $pid  = undef;
    $self->{err} = undef;
    my $url     = $self->{url};
    my $timeout = 15;
    if ( $ENV{'CHK_DELAY'} ) {
        $timeout = $ENV{'CHK_DELAY'};
    }
    my $wget_args
        = "--tries=1 --timeout=$timeout --spider --cache=off --user-agent=eSpong $ENV{'WGET_ARGS'}";
    $wget_args = '--no-check-certificate ' . $wget_args
        if $url =~ /^https:/ && !$self->{'no-check-certificate'};
    my $string = $self->{string};
    my $name   = $self->{name};
    $name =~ s/\W+/_/g;
    my $output_doc = '/tmp/wget_' . "$name";
    $output_doc = '/tmp/wget_debug_' . "$name" if ( $self->{debug} );
    my $index = 1;

    #Make sure we can write to the $output_doc file before proceeding
    while ( ( -f $output_doc ) and ( $index < 10 ) ) {
        if ( !-w $output_doc ) {

   #Found existing output file that cannot be written to .. try another name";
            my $suffix = "_" . "$index";
            $output_doc =~ s/(_\d+)*$/$suffix/;
        }
        else {
            unlink "$output_doc";
        }
        $index++;
    }
    if ( $index == 10 ) {
        $output_doc =~ s/(_\d+)$//;
        $self->{err}
            = "Unable to find a writable output file. Use sudo to remove $output_doc* files and run again\nThis situation can occur when two people are running check_was.sh at the same time";
        return undef;
    }
    $self->{output_doc} = $output_doc;
    if ($string) {
        $wget_args
            = "--tries=1 --timeout=$timeout --output-document=$output_doc --cache=off --user-agent=eSpong $ENV{'WGET_ARGS'}";
        $wget_args = '--no-check-certificate ' . $wget_args
            if $url =~ /^https:/ && !$self->{'no-check-certificate'};
    }

    #$self->debug("\tURL::is_responding For $server");
    my $wget_cmd = "/usr/bin/wget $wget_args \'$url\'";
    if ($url =~ /^https:/) {
    	# find out what realm we're in, so we can specify the correct certificate
    	my $realm = `grep realm /usr/local/etc/nodecache | grep -v authrealm | sed 's/realm.*= \\(.*\\)/\\1/'`;
    	my ($zone) = $realm =~ /(.*?)\./;
    	my $cert_file = "/lfs/system/tools/was/etc/ei." . $zone . "z.was.client.pem";
    	# get the password from was_passwd
    	my $pass_grep = "grep clientauth_" . $zone . "z /lfs/system/tools/was/etc/was_passwd | sed 's/clientauth_" . $zone . "z=//'";
    	my $cert_pass = decode_base64(`$pass_grep`);
    	# build the command - wget has no way of specifying the password to the cert file so we must use curl instead
    	$wget_cmd = "/usr/bin/curl -L";
    	$wget_cmd .=" -k" if !$self->{'no-check-certificate'};
    	$wget_cmd .= " --output $output_doc --user-agent eSpong --max-time $timeout --cert $cert_file --pass $cert_pass $ENV{'WGET_ARGS'}  \'$url\'";
    }
    print "$wget_cmd\n" if $self->{debug};
    $pid = $self->spawn($wget_cmd);
    $self->{pid} = $pid;
    return $pid;
}

sub is_responding {
    my $self   = shift @_;
    my $string = $self->{string};
    my $index  = 1;
    $self->{err} = undef;
    my $url  = $self->{url};
    my $name = $self->{name};
    $name =~ s/\W+/_/g;
    my $output_doc = $self->{output_doc} || '/tmp/wget_' . "$name";

    #Make sure do_probe was called ealier and a "wget" process was spawned
    unless ( ( exists $self->{pid} ) and ( $self->{pid} > 1 ) ) {
        $self->{err} = "Call do_probe before is_responding";
        return undef;
    }
    my $output = $self->reap( $self->{pid} );
    $self->{cmd_pid} = undef;
    $self->{pid}     = undef;
    if ( $output =~ /(302\s+Found)/i ) {

#$self->debug("\tURL::is_responding 302 Redirect found .. so desired URL responded even if the redirected URL timed out");
        return "302 Found";
    }
    elsif ( $output =~ /(403\s+Forbidden)/i ) {

#$self->debug("\tURL::is_responding 403 Forbidden found .. so desired URL responded but permission denied");
        return "403 Forbidden";
    }
    elsif ( $output =~ /failed:/ ) {
        unless ( $output =~ /301 Moved Permanently/ ) {
            my ($error_num) = $output =~ /failed:([^\.]+)\./;
            $self->{err} = "$error_num";
            $self->debug("!!! - WGET OUTPUT:\n$output\n");
            return undef;
        }
    }
    elsif ( $output =~ /(200\s+OK|Broken\s+pipe)/i ) {

        #$self->debug("\tURL::is_responding ....successful");
    }
    elsif ( $output =~ /ERROR/i ) {
        my ($error_num) = $output =~ /ERROR([^\.]+)\./i;
        $self->{err} = "$error_num";
        $self->debug("!!! - WGET OUTPUT:\n$output\n");
        return undef;
    }
    elsif ( $output =~ /\[errno/ ) {
        my ($error_num) = $output =~ /\[errno\s+(\S+)/;
        if ( $error_num eq 9 ) {
            $self->{err} = "request hung";
        }
        else {
            $self->{err} = "wget exited with code: $error_num";
        }
        $self->debug("!!! - WGET OUTPUT:\n$output\n");
        return undef;
    }
    if ($string) {
        open FILE, "$output_doc"
            or $self->debug(
                       "\tURL::is_responding Unable to open $output_doc: $!");
        my @lines = <FILE>;
        close FILE;
        unlink "$output_doc";
        my $lines = "@lines";
        if ( $lines =~ /$string/i ) {

          #$self->debug("\tURL::is_responding Found \"$string\" in response");
        }
        else {
            $self->debug(
                "\tURL::is_responding The pattern \"$string\" was not found in the response"
            );
            if ( length $lines > 30 ) {
                $self->{err}
                    = "The pattern:\n $string \nwas not found in the response\n";
            }
            else {
                $self->{err}
                    = "The pattern:\n $string \nwas not found in the response:\n$lines\n";
            }
            return undef;
        }
    }
    else {    #No need for the output file
        unlink "$output_doc";
    }
    return $output;
}

sub validate {
    my $self = shift @_;
    my $eval_this = $self->{validate} || '1 == 1';
    if ( eval($eval_this) ) {
        $self->debug("\tURL::validate [$eval_this] is true");
        return $eval_this;
    }
    else {
        $self->{err} = "check for [$eval_this] did not pass";
        $self->debug("\tURL::validate [$eval_this] is false");
        return undef;
    }
}

sub debug {
    my $self = shift @_;
    my $message = "@_" || " ";
    print "$message\n" if $self->{debug};
}

sub spawn {
    my $self     = shift @_;
    my $run_this = shift @_;
    my $output   = '';
    $self->{err} = undef;
    if ($run_this) {
        $self->{run_this} = $run_this;

        #open FILE, ">>/tmp/daemons.out";
        #print "Executing $run_this \n" if $self->{debug};
        #print FILE "Executing $run_this \n" if $self->{debug};
        # First lets fork the command using a pipe to obtain its output
        my $pipe = new FileHandle;
        my ($cmd_pid) = $pipe->open("$run_this 2>&1 |") or do {
            $self->{err} = "Failed to start $run_this: $!";
            return undef;
        };
        if ($cmd_pid) {
            $self->{cmd_pid} = $cmd_pid;
            $self->{$cmd_pid}{pipe}
                = $pipe;    #Keep track of this to get the output
            $self->{$cmd_pid}{spawn_time}
                = time;     #Used to determine if wget hangs
            return $cmd_pid;
        }
        else {
            $self->{err} = "Failed to establish pipe for $run_this: $!";
            return undef;
        }
    }
    else {

        # Nothing to run
        return undef;
    }
}

sub reap {
    my $self     = shift @_;
    my $cmd_pid  = shift @_ || $self->{cmd_pid};
    my $pipe     = $self->{$cmd_pid}{pipe};
    my $waits    = 0;
    my $maxwaits = 19;
    if ( $ENV{'CHK_DELAY'} ) {
        $maxwaits = $ENV{'CHK_DELAY'} + 4;
    }
    while ( ( waitpid( $cmd_pid, &POSIX::WNOHANG ) ) == 0 ) {

        #Kill the command if it takes too long
        my $time_past = time - $self->{$cmd_pid}{spawn_time};
        $waits++;
        if ( ( $waits > $maxwaits ) or ( $time_past > $maxwaits ) ) {
            $self->debug(
                "[$time_past] [$waits]  Sending kill signal to $self->{run_this}"
            );
            kill 'KILL' => $cmd_pid;
        }
        else {
            $self->debug("[$time_past] [$waits] seconds");
        }
        sleep 1;
    }
    my $command_status = ( $? >= 256 ) ? ( $? / 256 ) : ($?); 
    my $output = join "\n", $pipe->getlines();
    $pipe->close();
    delete $self->{$cmd_pid};

 #print "\t$run_this returned errno $command_status\n" if $self->{debug};
 #print FILE "\t$run_this returned errno $command_status\n" if $self->{debug};
    if ($command_status) {
        return "[errno $command_status ]\n $output\n";
    }
    if ($output) {

        #print FILE "$output\n" if $self->{debug};
        #close FILE;
        return $output;
    }
    else {

        #close FILE;
        return "OK";
    }
}

sub get_ei_stats {
    my $self       = shift @_;
    my $max_errors = $self->{max_errors};
    my $min_access = $self->{min_access};
    my $interval   = $self->{interval};
    my $errors     = 0;
    my ( $err1, $err2, $ta1, $ta2 );
    my $total_access   = 0;
    my $percent_errors = 0;

    sub get_data_ges {
        my $output_doc_ges = shift @_;
        my ( $stat, $data, $ta );
        my $err = 0;
        open( OUTDOC, "< $output_doc_ges" );
        while (<OUTDOC>) {
            ( $stat, $data ) = split(/:\s+/);
            chomp $data;

            #$self->debug("STAT is: $stat\n");
            #$self->debug("DATA is: $data\n");
            if ( $stat =~ /[tT]otal\s+[aA]ccess/ ) {

                #$self->debug("Found Total Access Count: $data");
                $ta = $data;
            }
            if ( $stat =~ /[54]XX\s+[eE]rr/ ) {

                #$self->debug("Found 4XX or 5XX: $data");
                $err += $data;
            }
        }
        close(OUTDOC);
        unlink("$output_doc_ges");
        return ( $err, $ta );
    }
    my $url  = $self->{url};
    my $name = $self->{name};
    $name =~ s/\W+/_/g;
    my $server;
    my $output_doc = '/tmp/wget_' . "$name" . '_' . "$server";
    my $wget_args
        = "--tries=1 --timeout=15 --output-document=$output_doc --cache=off --user-agent=eSpong";
    my $wget_cmd = "/usr/bin/wget $wget_args \'$url\' > /dev/null 2>&1";
    `$wget_cmd`;

    if ($?) {
        unlink("$output_doc");
        return 1;
    }
    ( $err1, $ta1 ) = get_data_ges($output_doc);

    #print "\tSleeping for $interval seconds before check ei-stats again\n"
    sleep $interval;
    $wget_cmd = "/usr/bin/wget $wget_args \'$url\' > /dev/null 2>&1";
    `$wget_cmd`;
    if ($?) {
        unlink("$output_doc");
        return 1;
    }
    ( $err2, $ta2 ) = get_data_ges($output_doc);
    $errors       = $err2 - $err1;
    $total_access = $ta2 - $ta1;
    if ( $total_access < $min_access ) {
        return 1;
    }
    $percent_errors = ( $errors / $total_access ) * 100;
    print
        "\tErrors: $errors\n\tAccess: $total_access\n\tPercentage of Errors: $percent_errors\n";
    if ( $percent_errors > $max_errors ) {
        $percent_errors = sprintf( "%3.2f", $percent_errors );
        $self->{err}
            = "Percent errors exceeds ${max_errors}%: ${percent_errors}%($errors errs in $interval seconds)";
        return 0;
    }
    return 1;
}
1;
