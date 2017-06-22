#!/usr/local/bin/perl
package EI::TivTask;
use strict;
use Data::Dumper;
use EI::DirStore;
use debug;

sub new {
   my $proto = shift;
   my $class = ref($proto) || $proto;
   my $self  = {};
   $self->{PLEX}        = {};
   $self->{ROLE}        = {};
   $self->{SERVERS}     = {};
   $self->{TIVTASK}     = '/Tivoli/scripts/tiv.task';
   $self->{ASYNC}       = 0;
   $self->{DELAY}       = undef;
   $self->{WORKDIR}     = '/tmp/';
   $self->{CMD_NAME}    = undef;
   $self->{CMD_CONTENT} = undef;
   bless( $self, $class );
   my (%args) = @_;
   my $args=\%args;
   $self->plex( $args->{'plex'} )       if defined $args->{'plex'};
   $self->workdir( $args->{'workdir'} ) if defined $args->{'workdir'};
   $self->workdir( $args->{'logdir'} ) if defined $args->{'logdir'};
   $self->async( $args->{'async'} )     if defined $args->{'async'};
   $self->delay( $args->{'delay'} )     if defined $args->{'delay'};
   $self->tivtask( $args->{'tivtask'} ) if defined $args->{'tivtask'};
   $self->cmd( @{ $args->{'cmd'} } )    if defined $args->{'cmd'};
   $self->role( $args->{'role'} )       if defined $args->{'role'};
   $self->servers( $args->{'servers'} ) if defined $args->{'servers'};
   
   return $self;
}

sub plex {
   my $self = shift;
   if (@_) {
      my $parms = shift;
      if ( ref $parms eq "ARRAY" ) {
         %{ $self->{PLEX} } = map { $_ => undef } @{$parms};
      }
      else {
         if ( $parms eq "CLEAR" ) {
            $self->{PLEX} = {};
         }
         else {
            $self->{PLEX}->{$parms} = undef;
         }
      }
   }
    return keys %{ $self->{PLEX} };
}

sub role {
   my $self = shift;
   if (@_) {
      my $parms = shift;
      if ( ref $parms eq "ARRAY" ) {
         %{ $self->{ROLE} } = map { $_ => undef } @{$parms};
      }
      else {
         if ( $parms eq "CLEAR" ) {
            $self->{ROLE} = {};
         }
         else {
            $self->{ROLE}->{$parms} = undef;
         }
      }

      # now add servers for each of the roles
      foreach my $role ( $self->role ) {
         foreach my $server (  _dirstore_role_lookup($role) ) {
            $self->servers($server);
         }
      }
   }
   return keys %{ $self->{ROLE} };
}

sub servers {
   my $self = shift;
   if (@_) {
      my $parms = shift;
      if ( ref $parms eq "ARRAY" ) {
         foreach my $server (@$parms) {
            debug("Add server $server");
            _save_server($self,$server);            
         }
      }
      else {
         if ( $parms eq "CLEAR" ) {
            $self->{SERVERS} = {};
         }
         else {
            debug("Add server $parms");
            _save_server($self,$parms);
         }
      }
   }
   return [ keys %{ $self->{SERVERS} } ];
}

sub cmd {
   my $self = shift;
   if (@_) {
      my ( $name, $code ) = @_;
      $code = _strip_whitespace($code);
      $self->cmd_name($name);
      $self->cmd_content($code);
   }
   return ( $self->{CMD_NAME}, $self->{CMD_CONTENT} );
}

sub cmd_name {
   my $self = shift;
   if ( @_ ) {
      $self->{CMD_NAME} = shift;
      $self->{CMD_NAME} =~ s/.*\///;
   }
   return $self->{CMD_NAME};
}

sub workdir {
   my $self = shift;
   if ( @_ ) {
      $self->{WORKDIR} = shift;
      $self->{WORKDIR} =~ s/\/$//;
      $self->{WORKDIR} = $self->{WORKDIR} . '/';
   }
   return $self->{WORKDIR};
}

sub logdir {
   my $self = shift;
   if ( @_ ) {
      $self->{LOGDIR} = shift;
      $self->{LOGDIR} =~ s/\/$//;
      $self->{LOGDIR} = $self->{LOGDIR} . '/';
   }
   return $self->{LOGDIR};
}

sub cmd_content {
   my $self = shift;
   $self->{CMD_CONTENT} = shift if @_;
   return $self->{CMD_CONTENT};
}

sub tivtask {
   my $self = shift;
   $self->{TIVTASK} = shift if @_;
   return $self->{TIVTASK};
}

sub delay {
   my $self = shift;
   $self->{DELAY} = shift if @_;
   return $self->{DELAY};
}

sub async {
   my $self = shift;
   
   if (@_) {
      debug("ASYNC flag set");
      $self->{ASYNC} = 1;
      $self->delay(300) if !$self->delay;
   }
   return $self->{ASYNC};
}

sub execute {
   my $self = shift;
   if ( ! $self->plex ) { 
      print "Cannot execute no target plex defined";
      exit;
   }
   
   _write_script($self)      if $self->cmd_content;
   
   
   #$self->servers("CLEAR");
   $self->logdir ($self->workdir) if ! $self->logdir;
   foreach my $plex ( $self->plex ) {
      my $serverlist = _write_server_list($self,$plex) if @{$self->servers};   
      my $cmd = $self->tivtask . " -l $plex ";
      $cmd .= " -f $serverlist " if $serverlist;
      $cmd .= $self->workdir.$self->cmd_name;
      $cmd .= " 2>&1 ";
      
      my $log = $self->logdir.$self->cmd_name."_$plex.log";
      open LOG, ">", "$log";
      
      debug("Executing $cmd");
      open CMD, "$cmd |" || die "$cmd failed to execute $!\n";
      my ( $endpoint,$capture_stderr,$capture_stdout );
      while ( my $line = <CMD> ) {
         debug($line);
         print LOG $line;
         if ( $line =~ /Task Endpoint:.*((?:[adg]\w\d+\w|\w\d{5}))/ ) {
            $endpoint = $1;
            $self->servers($endpoint);
            next;
         }
         elsif ( $line =~ /((?:[adg]\w\d+\w|\w\d{5}))\s+\(Endpoint\):/i ) {
            #z10041 (Endpoint): The task failed to execute.
            $endpoint = $1;
            debug("endpoint: $endpoint line:$line");
            $capture_stderr = 1;
         }
         elsif ( $line =~ /######/ ) {
            undef $capture_stdout;
            undef $capture_stderr;
            undef $endpoint;
            next;
         }
         elsif ( $line =~ /------Standard Output------/ ) {
            $capture_stdout = 1;
            next;
         }
         elsif ( $line =~ /------Standard Error Output------/ ) {
            undef $capture_stdout;
            $capture_stderr = 1;
            next;
         }
         if ($capture_stdout) {
            push @{ $self->{SERVERS}->{$endpoint}->{'STDOUT'} }, $line;
         }
         elsif ($capture_stderr) {
            push @{ $self->{SERVERS}->{$endpoint}->{'STDERR'} }, $line;
         }
      }
   }
   close CMD;
   close LOG;
   
   $self->_wait_for_complete if $self->async;
   return %{ $self->{SERVERS} };
}

sub _write_server_list {
   my ($self,$plex) = @_;
   
   debug("Write server list for $plex");
   my $keep=0;
   my $serverlist = $self->workdir . $self->cmd_name . "_${plex}_server_list";
   open FILE, '>', $serverlist;
   foreach my $server (sort @{ $self->servers } ) {
      if ( 
         ( $server =~/^(?:v1|a[c,t])/i && $plex =~/px1/i ) ||
         ( $server =~/^z1/i && $plex =~/ecc/i ) ||
         ( $server =~/^(?:v2|d[c,t])/i && $plex =~/px2/i ) ||
         ( $server =~/^w1/i && $plex =~/ci1/i ) ||
         ( $server =~/^w2/i && $plex =~/ci2/i ) ||
         ( $server =~/^(?:v3|g[c,t])/i && $plex =~/px3/i ) ||
         ( $server =~/^(?:v5)/i && $plex =~/px5/i ) ||
         ( $server =~/^s/i && $plex =~/sl/i ) ||
         ( $server =~/^w3/i && $plex =~/ci3/i ) ) {
            print FILE "$server\n";
            ++$keep;
         }
   }
   close FILE;
   if ( ! $keep ) {
      unlink $serverlist if ! $keep;
      return undef;
   }
   else {
      return $serverlist;
   }
}

sub _wait_for_complete {
   my $self = shift;
 
   debug("waiting for scripts to complete");
   my $waittask = EI::TivTask->new(
         plex    => [ $self->plex ],
         servers => ( $self->servers ),
         workdir => $self->workdir,
         cmd     => [ &_wait_cmd($self->cmd_name) ],
         tivtask => $self->tivtask
   );
   my $running = 1;
   while ($running) {
      debug("Sleeping " . $self->delay );
      sleep $self->delay;
      my (%results)=$waittask->execute;
      $running=0;
      foreach my $server ( sort keys %results ) {
         if ( grep /not Running/i, @{$results{$server}{STDOUT}} ) {
            undef $self->{SERVERS}->{$server};
         }
         elsif ( grep /Still Running/i, @{$results{$server}{STDOUT}} ) {
            printf "[%02d:%02d] still running on %s\n",(localtime())[2],(localtime())[1],$server;
            $running++;
         }
         else {
            print "No response from $server\n";
            undef $self->{SERVERS}->{$server};
         }
      }
   }
   debug( "END OF WAIT" );
}

sub _wait_cmd {
   my $cmd_name = shift;
   my $wait_cmd_name = "wait_$cmd_name";
   debug("waiting for $cmd_name to complete");
   return ($wait_cmd_name,<<END_WAIT_CMD
   #!/bin/ksh
   running=\$(ps -eo "%a" | grep "$cmd_name" | grep -vcE "$wait_cmd_name|grep" )
   if [ "\$running" -gt 0 ]; then
      ps -eo "%a" | grep "$cmd_name" | grep -v grep
      print "$cmd_name Still running"
   else 
      print "$cmd_name not running"
   fi
END_WAIT_CMD
   );
}

sub _strip_whitespace {
   no warnings;
   my ($string) = @_;
   $string =~ s/^\s+|\s+$//g;
   return $string;
}

sub _write_script {
   my $self = shift;
   debug("Write script ".$self->cmd_name);
   $self->nohup if ( $self->async && $self->cmd_content !~ /nohup/isxm );
   my $cmd_name = $self->workdir . $self->cmd_name;
   open SCRIPT, ">", $cmd_name
     or die "Cannot open " . $cmd_name . " for write $!\n";
   print SCRIPT $self->cmd_content;
   close SCRIPT;
   chmod 0775, $cmd_name;
}

sub nohup {
   my $self = shift;
   debug("Making command nohup itself");
   my $cmd  = $self->cmd_content;
   my $cmd_name = $self -> cmd_name;
   $cmd_name =~ s/.*\///;
   $cmd =~ s/^\#\!/\#/;    # remove interpreter id line
   $cmd = <<ENDNOHUP . $cmd;
#!/usr/bin/ksh
if [ -z "\$1" ]; then
   cmd=/tmp/$cmd_name
   print "tivtask cmd: \$0 copied to \$cmd"
   cp \$0 \$cmd 
   nohup \$cmd 1 2>&1 >\${cmd}.log
   exit
fi
ENDNOHUP
}

sub _dirstore_role_lookup {
   my ($role) = shift;
   my %results;
   debug("dirstore role lookup $role");
   dsConnect();
   dsSearch( %results, 'system', expList => [ "role==$role" ],
      attrs => [qw(custtag role nodestatus realm eihostname systemtype )] );
   dsDisconnect();
   return keys %results if %results;
   return undef;
}

sub _dirstore_server_loopkup {
   my ($server) = shift;
   my %results;
   debug("dirstore lookup $server");
   dsConnect();
   dsGet( %results, 'system', $server,
      attrs => [qw(custtag role nodestatus realm eihostname systemtype )] );
   dsDisconnect();
   if (%results && $results{'role'}) {
      my $prefered_role = _best_role( $results{'role'} );
      my $plex = _plex( $results{'realm'}->[0]);
      $server = $results{'eihostname'}->[0] if $results{'systemtype'}->[0] eq "SERVICE";
      return (
         $server,
         $results{'custtag'}[0],
         $plex,
         $prefered_role,
         $results{'nodestatus'}[0]
      );
   }
   return undef;
}

sub _plex {
   my ($realm) = shift;
   debug($realm);
   
   return "ECC" if $realm =~ /\.z1$/;
   return "CI1" if $realm =~ /\.ci\.p1$/;
   return "CI2" if $realm =~ /\.ci\.p2$/;
   return "CI3" if $realm =~ /\.ci\.p3$/;
   return "PX1" if $realm =~ /\.p1$/;
   return "PX2" if $realm =~ /\.p2$/;
   return "PX3" if $realm =~ /\.p3$/;
   return "PX5" if $realm =~ /\.p5$/;
   return "SL"  if $realm =~ /\.sl\.s[1,3,5]$/;
   
   return undef;
}

sub _best_role {
   my ($roles) = shift;
   my $prefered = '';
   foreach my $role ( sort @$roles ) {
      if ( $role =~ /WEBSERVER\.CLUSTER/ismx ) {    # use cluster role if found
         $prefered = $role;
         last;
      }
      elsif ( $role =~ /WEBSERVER\./i ) {
         if ( $role !~ /WEBSERVER.EI.\d+/i ) {
            $prefered =
              $role;    # use webserver role but keep looking for better one
         }
      }
      elsif ( $role =~ /WAS\./i && $prefered !~ /WEBSERVER/ ) {
         $prefered = $role;
      }
      elsif ( $role =~ /MQ\./i && $prefered !~ /(?:WAS|WEBSERVER)/i ) {
         $prefered = $role;
      }
      elsif ( $prefered !~ /(?:WAS|WEBSERVER|MQ)/i ) {
         $prefered = $role;
      }
   }
   return $prefered;
}


sub _save_server {
   my ($self,$server) = @_;
   my ( $real_server, $cust, $plex, $role, $nodestatus ) = _dirstore_server_loopkup($server);
   if ( $real_server ) {
      $self->{SERVERS}->{$real_server} = {
         cust       => $cust,
         role       => $role,
         nodestatus => $nodestatus,
         plex       => $plex
      };
      $self->plex($plex);
   }
}
1;
