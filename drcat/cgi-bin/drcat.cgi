#! /usr/local/bin/perl -w
# drcat.cgi
# Written by Russ Scadden <russcadd@us.ibm.com>
# Front end to xml files descripting out to de-advertise or re-advertise a customer from a certain plex in the EI
#

use strict;
use Date::Manip;
use XML::Simple;
use Data::Dumper;
use EI::DirStore;
use CGI qw/:standard/;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser carpout set_message);
set_message('Please report this error to <a href="mailto:russcadd@us.ibm.com">Russ Scadden</a>, along with the time and date of occurence');

#GLOBAL settings
my $XMLDIR='/lfs/system/tools/drcat/xml';
my @CUSTOMERS=('IBM','XSR','SRM','STG','WWSM','SHARED','CNP','ESC','ICE','JAMS','SSO');
my @ENVIRONMENTS=('CI','CS','stage','p1CS','p2CS','p3CS','p2CI','p3CI');
my %ENVMAP=(
				CI => ['*ci*'],
				CS => ['*cs*','*ei*'],
				stage => ['*.st.p1'],
				p1CS => ['*.cs.p1','*.ei.p1'],
				p2CS => ['*.cs.p2','*.ei.p2'],
				p3CS => ['*.cs.p3','*.ei.p3'],
				p2CI => ['*.ci.p2'],
				p3CI => ['*.ci.p3'],
			);
my @MIDDLEWARE=('WAS','IHS','SPONG', 'ITM', 'PUB','WPS','LCS');
my %MIDDLEWAREMAP=(
					#What strings will we look for in the dirstore roles for each of these middleware selections
					WAS => ['WAS'],
					IHS => ['WEBSERVER'],
					SPONG => ['WEBSERVER'],
					ITM => ['WAS','WEBSERVER','WPS'],
					PUB => ['WAS','WEBSERVER','PUB'],
					LCS => ['WAS','WEBSERVER','WPS'],
					WPS => ['WPS'],
	              );
my %APPMAP=(
				#What strings will we look for when searching the software section of the dirstore
					WAS => 'was',
					IHS => 'ihs',
					WPS => 'was',		
	       );
my %STARTCOMMANDMAP=(
					WAS => '/lfs/system/bin/rc.was start <application>',
					IHS => '/etc/apachectl start',
					SPONG => '/etc/rc.spong start',
					ITM => '/etc/rc.itm start',
					PUB => '/etc/rc.bNimble start <configuration file>',
					WPS => '/lfs/system/bin/rc.was start <application>',
					LCS => '/opt/HPODS/LCS/bin/rc.lcs_client start',
	              );
my %STARTVERIFICATIONCOMMANDMAP=(
					WAS => '/lfs/system/bin/check_was.sh <application>',
					IHS => '/lfs/system/bin/check_ihs.sh',
					SPONG => '/lfs/system/bin/check_spong.sh',
					ITM => 'ps -ef | grep agent | grep ITM',
					PUB => '/lfs/system/bin/check_bNimble.sh',
					WPS => '/lfs/system/bin/check_was.sh <application>',
					LCS => '/lfs/system/bin/check_lcs.sh',
	              );
my %STOPCOMMANDMAP=(
					WAS => '/lfs/system/bin/rc.was stop <application>',
					IHS => '/etc/apachectl stop',  
					SPONG => '/etc/rc.spong stop',
					ITM => '/etc/rc.itm stop all',
					PUB => '/etc/rc.bNimble stop <configuration file>',
					WPS => '/lfs/system/bin/rc.was stop <application>',
					LCS => '/opt/HPODS/LCS/bin/rc.lcs_client stop',
	              );
my %STOPVERIFICATIONCOMMANDMAP=(
					WAS => '/lfs/system/tools/configtools/countprocs.sh 1 WebSphere',
					IHS => '/lfs/system/tools/configtools/countprocs.sh 2 httpd',
					SPONG => '/lfs/system/tools/configtools/countprocs.sh 1 spong',
					ITM => '/lfs/system/tools/configtools/countprocs.sh 1 ITM',
					PUB => '/lfs/system/tools/configtools/countprocs.sh 1 bNimble',
					WPS => '/lfs/system/tools/configtools/countprocs.sh 1 WebSphere',
					LCS => '/opt/HPODS/LCS/bin/rc.lcs_client status',
	              );              
my @ACTIONS=('Start','Stop');
my %SEQUENCEMAP=(
# -1 means last, -2 means second to last
					Start => {
						WAS => 2,
						IHS => 1,
						SPONG => 4,
						ITM => -1,
						PUB => 5,
						WPS => 3,
						LCS => 6,					
					},
					Stop => {
						WAS => 2,
						IHS => 4,
						SPONG => 5,
						ITM => 1,
						PUB => 6,
						WPS => 3,
						LCS => 7,					
					}
				);
my %APPSEQUENCEMAP=(
# -1 means last, -2 means second to last
					Start => {
						nodeagent => 1,
						m2m => 2,				
					},
					Stop => {
						nodeagent => -1,
						m2m => -2,				
					}
				);
my $XML_TO_PERL;


$ENV{TZ}="UT";
my $now = UnixDate("now", "%a, %d %b %Y %H:%M:%S %Z");

my $q = new CGI;

print header(-Cache_Control => 'no-cache',
               -type => 'text/html',
               -expires => $now),
	start_html('DRCAT Web Admin Tool'),
    h1('DRCAT Web Admin Tool');

#print Dump;
		
if (param('goToRoleSelect')) {
	# Time to select a role
   	my $customer = param('customer') || 'ERROR';
   	my $env  = 	param('env') || 'ERROR';
   	my @realms = @{$ENVMAP{$env}};
   	@realms = ('*') unless @realms;
    my $middleware = param('middleware') || 'ERROR';
    my @middleware_list = @{$MIDDLEWAREMAP{$middleware}};
    @middleware_list = ('.*') unless @middleware_list;
    my $action = param('action') || 'ERROR';
    my %results;
    my %seen;
    my @related_roles;
    foreach $middleware (@middleware_list) {
    	   my $searchrole = '*' . $middleware . '*';
    	foreach my $realm (@realms) {
    		dsSearch(%results, "SYSTEM", expList => ["realm==$realm","role==$searchrole","custtag==$customer"]);	
    	 	foreach my $host (keys %results) {
    	 		push @related_roles, ( grep /$middleware/, @{$results{$host}->{role}});	 		
    	 	}
    	}
    }
    #Obtain just the unique role names .. don't need to present he user with a list of duplicate names
    my @roles = grep { ! $seen{ $_ }++ } @related_roles;
    @roles = ('ERROR') unless @roles;
   	
   	print "Related $middleware roles for $customer in $env", p, hr
   	start_form,
    "Roles   ",
    popup_menu(-name=>'role',
       	-values=>\@roles),p,
    submit('goToCustomerSelect','Previous');
    if ( $middleware eq 'WAS' ) {
    	print submit('goToAppSelect','Next');
    } else {
       	print submit('goToCommands','Next'),
       	hidden(-name=>'version',-default=>'all'),
    	hidden(-name=>'app',-default=>'all');    
    } 
    #Set values for reuse on the next screen
    print hidden(-name=>'customer',-default=>$customer),
          hidden(-name=>'env',-default=>$env),
          hidden(-name=>'middleware',-default=>$middleware),
          hidden(-name=>'action',-default=>$action);		
} elsif (param('goToAppSelect')) {
	# Time to select individual applications
	my $customer = param('customer') || 'ERROR';
	my $env  = 	param('env') || 'ERROR';
   	my @realms = @{$ENVMAP{$env}};
   	@realms = ('*') unless @realms;
    my $middleware = param('middleware') || 'ERROR';
    $middleware  = $APPMAP{$middleware} || '*';
	my $action = param('action') || 'ERROR';
	my $role = param('role') || 'ERROR';
	my %hosts;
	my %related_apps;
	my %related_versions;
	
	#query the dirstore for hostnames related to the role selected
	foreach my $realm (@realms) {
		my %results;
    	dsSearch(%results, "SYSTEM", expList => ["realm==$realm","role==$role"]);	
    	foreach my $host (keys %results) {
    	 	$hosts{$host}++; 		
    	 }
    }
    #query the dirstore for software installed on these hosts related to the middleware selected
    foreach my $host (keys %hosts) {
    	my %results;
    	my $name = "$host". '.' . "$middleware";
    	dsSearch(%results, "SOFTWARE", expList => ["name==$name"]);	
    	foreach my $software (keys %results) {
     		my @full_app_names = @{$results{$software}->{instances}};    			 
    		foreach my $app (@full_app_names) {
    			my $name_without_host = $app;
    			$name_without_host =~ s/^(\w+_)//;
     			$related_apps{$name_without_host}++;
    		}
    		my @versions = @{$results{$software}->{version}};
    		foreach my $version (@versions) {
    	 		$related_versions{$version}++; 	 
    		}		
    	 }
    }
    my @apps = keys %related_apps;
    my @versions = keys %related_versions;
    unshift @apps, 'nodeagent';
 	unshift @apps, 'all' unless (($role =~ /WAS\.IBM\.\w+\.GZ/) and ($action =~ /start/i ));
	
	
  	print "Related $middleware applications and versions for $role servers in $env", p, hr,
	  	start_form,
       	"Versions   ";
       	if ( $versions[1] ) {
       		#If there are more than one version have a popup menu
       		if (($role =~ /WAS\.IBM\.\w+\.GZ/)and ($action =~ /start/i )) {
       			# We need to add the 5.1 version for ibm.com as the app tracker doesn't show it
       			unshift @versions, '5.1';
       		} else {
       			# Add the option of selecting "all"
       			unshift @versions, 'all';
       		}	
       		print popup_menu(-name=>'version',
                   			 -values=>\@versions),p;
       	} else {
       		# Only one version ... just list it
       		my $version = $versions[0];
       		print $version,p,
       		hidden(-name=>'version',-default=>$version),p;
       	}
       	
       	unshift @apps, 'all' unless (($role =~ /WAS\.IBM\.\w+\.GZ/)and ($action =~ /start/i ));
       	
       	print "Applications   ";
       		print popup_menu(-name=>'app',
                   			 -values=>\@apps),p,
        submit('goToRoleSelect','Previous'),
        submit('goToCommands','Next'),
        #Set values for reuse on the next screen
        hidden(-name=>'customer',-default=>$customer),  
        hidden(-name=>'env',-default=>$env),
        hidden(-name=>'middleware',-default=>$middleware),
        hidden(-name=>'action',-default=>$action),	
        hidden(-name=>'role',-default=>$role);       	    		
} elsif (param('goToCommands')) {
	# Time to set the commands related to this role and application
   	my $customer = param('customer') || 'ERROR';
	my $env  = 	param('env') || 'ERROR';
	my $middleware = param('middleware') || 'ERROR';
	
	my $action = param('action') || 'ERROR';
	my $role = param('role') || 'ERROR';
	my $version = param('version') || 'ERROR';
	my $app = param('app') || 'ERROR';
	
	my $command_source = "default command";
	my $verification_source = "default command";
	
	#Have we already defined commands to start and stop this application?
	#First look to see if we came back to this screen:
	my $action_command = param('action_command') and $command_source = "command submitted previously";
	my $verification_command = param('verification_command') and $verification_source = "command submitted previously";
	
	#Next look to see if there is existing XML file with these commands defined
	my $xmlfile = lc("$XMLDIR" . '/' . "$env" . '_' . "$customer" . '.xml');
	if ( -r $xmlfile ) {
		#print "Reading in previously generated XML",p;
		my $perl= XMLin( $xmlfile,  forceArray=>1) or print em(escapeHTML("Failed to parse xml in file $xmlfile: $!")),p;
		#print "Perl structure generated form XML in $xmlfile is:",p, Dumper($perl),p;
		unless ($action_command) {
			eval { $action_command = $perl-> {role} -> {$role} -> {action} -> 
				{$action} -> {middleware} -> {$middleware} -> {version} -> {$version} ->
					  			{application} -> {$app} -> {cmd}
					  				and $command_source="command obtained from XML in $xmlfile"; };
			if ($@) {
				print "Error parsing XML in $xmlfile for role $role:",em(escapeHTML($@)),p,
				      "Please, edit the file by hand and correct",p;
			}					  				
		}				  				
		unless ($verification_command) {	
			eval { $verification_command = $perl-> {role} -> {$role} -> {action} -> 
				{$action} -> {middleware} -> {$middleware} -> {version} -> {$version} ->
					  			{application} -> {$app} -> {verify}
					  				and $verification_source="command obtained from XML in $xmlfile"; };				
		}
	}			  
	#Go with the defaults if nothing else has been previously been entered		
	unless ($action_command) {
		if ($action eq 'Start') {
			$action_command = $STARTCOMMANDMAP{$middleware};
			$verification_command = $STARTVERIFICATIONCOMMANDMAP{$middleware};
		} elsif ($action eq 'Stop') {
			$action_command = $STOPCOMMANDMAP{$middleware};
			$verification_command = $STOPVERIFICATIONCOMMANDMAP{$middleware};
		}
		$action_command =~ s/<application>/$app/;
		if ( $app =~ /all/ ) {
			$verification_command =~ s/<application>//;
		} else {
			$verification_command =~ s/<application>/$app/;
		}
	}

	
 	print "$middleware $action configuration for $role servers in $env for $app application(s)", p, hr,
 			"Using $action $command_source",p,
  		  	start_form,
        	"$action command   ", textfield(-name=>'action_command',-value=>$action_command,-size=>150),p,
        	"Using verification $command_source",p,
            "Verification command ", textfield(-name=>'verification_command',-value=>$verification_command,-size=>150),p;
    if ( $middleware eq 'WAS' ) {
            print submit('goToAppSelect','Previous');
    } else {
            print submit('goToRoleSelect','Previous');
    }
    print   submit('goToReviewEntry','Next'),
            hidden(-name=>'customer',-default=>$customer),  
            hidden(-name=>'env',-default=>$env),
            hidden(-name=>'middleware',-default=>$middleware),
    	    hidden(-name=>'action',-default=>$action),	
            hidden(-name=>'role',-default=>$role),
            hidden(-name=>'version',-default=>$version),	
            hidden(-name=>'app',-default=>$app),
            hidden(-name=>'command_source',-default=>$command_source);
} elsif (param('goToReviewEntry')) {
	# Time to save all the selections to the xml file
	my $customer = param('customer') || 'ERROR';
	my $env  = 	param('env') || 'ERROR';
	my $middleware = param('middleware') || 'ERROR';
	my $action = param('action') || 'ERROR';
	my $role = param('role') || 'ERROR';
	my $version = param('version') || 'ERROR';
	my $app = param('app') || 'ERROR';
	my $action_command = param('action_command') || 'ERROR';
	my $verification_command = param('verification_command') || 'ERROR';
	my $command_source = param('command_source') || 'ERROR';
  	print "$middleware $action configuration for $role servers in $env for $app applications",p;
  	print "Version: $version<br>" unless ($version =~ /all/i );
  	print "$action command: $action_command ",p,
   		  	"Verification command: $verification_command ",p, hr;
   		if ( $command_source =~ /XML/i ) {
   			#This entry already existed in the xml file ... show the update and delete buttons
   			print 	"You can Update or Delete this entry",p,hr,
   			start_form,
   			submit('goToCommands','Previous'),
        	submit('goToDeleteEntry','Delete Entry'),
        	submit('goToUpdateEntry','Update Entry');
   		} else {
   			#This is a new entry, show the Create button
   			print "If the above values are correct, press the Create Entry button to save", p,hr,
   			start_form,
   			submit('goToCommands','Previous'),
   			submit('goToCreateEntry','Create Entry');
		}
        #Set values for reuse on the previous screen if the previous button is pressed
        print hidden(-name=>'customer',-default=>$customer),  
       	hidden(-name=>'env',-default=>$env),
        	hidden(-name=>'middleware',-default=>$middleware),
        	hidden(-name=>'action',-default=>$action),	
        	hidden(-name=>'role',-default=>$role),  
        	hidden(-name=>'version',-default=>$version),	
        	hidden(-name=>'app',-default=>$app),
        	hidden(-name=>'action_command',-default=>$action_command),	
        	hidden(-name=>'verification_command',-default=>$verification_command); 
} elsif (param('goToCreateEntry')) {
	# Time to save all the selections to the xml file.  This is a new Entry
	my $customer = param('customer') || 'ERROR';
	my $env  = 	param('env') || 'ERROR';
	my $middleware = param('middleware') || 'ERROR';
	my $action = param('action') || 'ERROR';
	my $role = param('role') || 'ERROR';
	my $version = param('version') || 'ERROR';
	my $app = param('app') || 'ERROR';
	my $action_command = param('action_command') || 'ERROR';
	my $verification_command = param('verification_command') || 'ERROR';
	my $xmlfile = &create_xml;
  	print "Generated XML saved to $xmlfile",p,hr,
   		start_form,
        submit('goToCustSelect','Make another selection'),
        #Set values for reuse on the role selection screen
        hidden(-name=>'customer',-default=>$customer),  
        hidden(-name=>'env',-default=>$env),
        hidden(-name=>'middleware',-default=>$middleware),
        hidden(-name=>'action',-default=>$action),	
        hidden(-name=>'role',-default=>$role);      		    		
} elsif (param('goToUpdateEntry')) {
	# Time to save all the selections to the xml file.  This is a new Entry
	my $customer = param('customer') || 'ERROR';
	my $env  = 	param('env') || 'ERROR';
	my $middleware = param('middleware') || 'ERROR';
	my $action = param('action') || 'ERROR';
	my $role = param('role') || 'ERROR';
	my $version = param('version') || 'ERROR';
	my $app = param('app') || 'ERROR';
	my $action_command = param('action_command') || 'ERROR';
	my $verification_command = param('verification_command') || 'ERROR';
	my $xmlfile = &update_xml;
  	print "Generated XML and updated the entry in $xmlfile",p,hr
   		start_form,
        submit('goToCustSelect','Make another selection'),
        #Set values for reuse on the role selection screen
        hidden(-name=>'customer',-default=>$customer),  
        hidden(-name=>'env',-default=>$env),
        hidden(-name=>'middleware',-default=>$middleware),
        hidden(-name=>'action',-default=>$action),	
        hidden(-name=>'role',-default=>$role);      		    		
} elsif (param('goToDeleteEntry')) {
	# Time to save all the selections to the xml file.  This is a new Entry
	my $customer = param('customer') || 'ERROR';
	my $env  = 	param('env') || 'ERROR';
	my $middleware = param('middleware') || 'ERROR';
	my $action = param('action') || 'ERROR';
	my $role = param('role') || 'ERROR';
	my $version = param('version') || 'ERROR';
	my $app = param('app') || 'ERROR';
	my $action_command = param('action_command') || 'ERROR';
	my $verification_command = param('verification_command') || 'ERROR';
	my $xmlfile = &delete_xml;
  	print hr,start_form,
        submit('goToCustSelect','Make another selection'),
        #Set values for reuse on the role selection screen
        hidden(-name=>'customer',-default=>$customer),  
        hidden(-name=>'env',-default=>$env),
        hidden(-name=>'middleware',-default=>$middleware),
        hidden(-name=>'action',-default=>$action),	
        hidden(-name=>'role',-default=>$role);      		    		
} else {
	#use previous values if we are coming back to this screen
	#push @CUSTOMERS, param('customer') if (param('customer'));
	#push @ENVIRONMENTS, param('env') if (param('env'));
	#push @MIDDLEWARE, param('middleware') if (param('middleware'));
   	#push @ACTIONS, param('action') if (param('action'));    
    #At the first screen .. obtain desired customer, environment middleware, and action
    print start_form,
    	"Customer   ",
        popup_menu(-name=>'customer',
                   -values=>\@CUSTOMERS),p,
        "Environment   ",
        popup_menu(-name=>'env',
                   -values=>\@ENVIRONMENTS),p,
        "Middleware   ",
        popup_menu(-name=>'middleware',
                   -values=>\@MIDDLEWARE),p,
        "Action   ",
        popup_menu(-name=>'action',
                   -values=>\@ACTIONS),p,
        submit('goToRoleSelect','Next');
}

print end_form, hr, end_html;
   
sub create_xml {
	my $customer = param('customer') || 'ERROR';
	my $env  = 	param('env') || 'ERROR';
	my $middleware = param('middleware') || 'ERROR';
	my $action = param('action') || 'ERROR';
	my $role = param('role') || 'ERROR';
	my $version = param('version') || 'ERROR';
	my $app = param('app') || 'ERROR';
	my $action_command = param('action_command') || 'ERROR';
	my $verification_command = param('verification_command') || 'ERROR';
	my $perl;
	
	my $sequence = $SEQUENCEMAP{$action}->{$middleware};
	my $appsequence;
	my $defined;
	foreach my $pattern ( keys %{$APPSEQUENCEMAP{$action}} ) {
		if ( $app =~ /$pattern/ ) {
			$appsequence = $APPSEQUENCEMAP{$action}->{$pattern};
		}
	}
	$appsequence = 3 unless ($appsequence);
	my $xmlfile = lc("$XMLDIR" . '/' . "$env" . '_' . "$customer" . '.xml');
	if ( -r $xmlfile ) {
		print "Reading in previously generated entries in XML file: $xmlfile",p;
		$perl= XMLin( $xmlfile,  forceArray=>1) or print "Failed to parse xml in file $xmlfile: $!",p;
		
		eval { $defined = $perl -> {role} };
		unless ($defined) {
			#No roles defined in this xML file .. that seems strange! .. the eval returned an error
			print "Warning: No roles defined in $xmlfile, yet this file existed",p,
			      "Updating XML file with this new role: $role",p;
			
			$perl = { 'role' => { "$role" => { 'action' => {
					"$action" => {'middleware' => { "$middleware" => { 'version' => { "$version"=> {
						'sequence' => $sequence,
						'application' => {  "$app" => {
														'sequence' => "$appsequence",
														'cmd' => "$action_command",
														'verify' => "$verification_command"
													   }
								          }
						}}}}}
				}}}};
				
		}

		eval { $defined = $perl-> {role} -> {$role} };
					  				
		unless ($defined) {
			print "Update the listing in this XML file with this new role, $role",p;
					
					my %hash = %{ $perl -> {role}};
					$hash{$role} = { 'action' => {
				"$action" => {'middleware' => { "$middleware" => { 'version' => { "$version"=> {
					'sequence' => $sequence,
					'application' => {  "$app" => {
													'sequence' => "$appsequence",
													'cmd' => "$action_command",
													'verify' => "$verification_command"
												   }
							          }
					}}}}}
				}};
				$perl -> {role} = \%hash;
		}	
		
		eval {  $defined = $perl-> {role} -> {$role} -> {action} -> {$action}  };
					  				
		unless ($defined) {
			print "Updating the existing $role entry in this XML file with this new $action action entry",p;
				
				my %hash = %{ $perl -> {role} -> {$role} -> {action}};
				$hash{$action} = {'middleware' => 
					{ "$middleware" => { 'version' => { "$version"=> {
													'sequence' => $sequence,
					  'application' => {  "$app" => {
													'sequence' => "$appsequence",
													'cmd' => "$action_command",
													'verify' => "$verification_command"
												   }
							          }
					}}}}};
				$perl -> {role} -> {$role} -> {action} = \%hash;
		}
		
		eval {  $defined = $perl-> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware} };
					  				
		unless ($defined) {
			print "Updating the existing $role entry in this XML file with this new $middleware entry",p;
				
				my %hash = %{$perl -> {role} -> {$role} -> {action} -> {$action} -> {middleware}};
				$hash{$middleware} = 
					{ 'version' => { "$version"=> {
													'sequence' => $sequence,
					  'application' => {  "$app" => {
													'sequence' => "$appsequence",
													'cmd' => "$action_command",
													'verify' => "$verification_command"
												   }
							          }
					}}};
					
				$perl -> {role} -> {$role} -> {action} -> {$action} -> {middleware} = \%hash;
		}
		
		eval {  $defined = $perl-> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
			    -> {version} -> {$version} };
					  				
		unless ($defined) {
			print "Updating the existing $role entry in this XML file with this new version $version entry",p;
				
				my %hash = %{$perl -> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
				      -> {version} };
				$hash{$version} = { 
					  'sequence' => $sequence,
					  'application' => {  "$app" => {
													'sequence' => "$appsequence",
													'cmd' => "$action_command",
													'verify' => "$verification_command"
												   }
							          }
					};
				$perl -> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
				      -> {version} = \%hash;		
		}
		
		eval {  $defined = $perl-> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
			    -> {version} -> {$version}-> {application} -> {$app} };
					  				
		unless ($defined) {
			print "Updating the existing $role entry in this XML file with an a new entry for this application",p;
				
				my %hash = %{ $perl -> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
				      -> {version} -> {$version} -> {application} };
				$hash{$app} = {
								'sequence' => "$appsequence",
								'cmd' => "$action_command",
								'verify' => "$verification_command"
							  };
				$perl -> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
				      -> {version} -> {$version} -> {application} = \%hash;
		}
			  			
		
	} else {
		#New XML file needed		
		$perl = { 'role' => { "$role" => { 'action' => {
					"$action" => {'middleware' => { "$middleware" => { 'version' => { "$version"=> {
						'sequence' => $sequence,
						'application' => {  "$app" => {
														'sequence' => "$appsequence",
														'cmd' => "$action_command",
														'verify' => "$verification_command"
													   }
								          }
						}}}}}
				}}}};
	}
	my $xml= XMLout( $perl ) or print "Failed to generate XML: $!",p;
	#print "Here is the raw perl structure:",p;
	#print Dumper($perl),p;
	#print "Updating $xmlfile with:",p;
	#print ": $xml  : $testxml :",p;

	open(XMLFILE,">$xmlfile") or print "Failed to open $xmlfile: $!",p; 
	print XMLFILE $xml;	
	return $xmlfile;	
}

sub update_xml {
	my $customer = param('customer') || 'ERROR';
	my $env  = 	param('env') || 'ERROR';
	my $middleware = param('middleware') || 'ERROR';
	my $action = param('action') || 'ERROR';
	my $role = param('role') || 'ERROR';
	my $version = param('version') || 'ERROR';
	my $app = param('app') || 'ERROR';
	my $action_command = param('action_command') || 'ERROR';
	my $verification_command = param('verification_command') || 'ERROR';
	my $perl;
	
	my $sequence = $SEQUENCEMAP{$action}->{$middleware};
	my $appsequence;
	my $defined;
	foreach my $pattern ( keys %{$APPSEQUENCEMAP{$action}} ) {
		if ( $app =~ /$pattern/ ) {
			$appsequence = $APPSEQUENCEMAP{$action}->{$pattern};
		}
	}
	$appsequence = 3 unless ($appsequence);
	my $xmlfile = lc("$XMLDIR" . '/' . "$env" . '_' . "$customer" . '.xml');
	if ( -r $xmlfile ) {
		print "Reading in previously generated entries in XML file: $xmlfile",p;
		$perl= XMLin( $xmlfile,  forceArray=>1) or print "Failed to parse xml in file $xmlfile: $!",p;
		
		eval {  $defined = $perl-> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
			    -> {version} -> {$version}-> {application} -> {$app} };
					  				
		if ($defined) {
				my %hash = %{ $perl -> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
				      -> {version} -> {$version} -> {application} };
				$hash{$app} = {
								'sequence' => "$appsequence",
								'cmd' => "$action_command",
								'verify' => "$verification_command"
							  };
				$perl -> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
				      -> {version} -> {$version} -> {application} = \%hash;	
		} else {   
			print "WARNING:  Updated called, however $app entries for this role, $role, have not previously been added to $xmlfile",p,
			      "Investigate this issue.",p;	

		}
		my $xml= XMLout( $perl ) or print "Failed to generate XML: $!",p;
		#print "Here is the raw perl structure:",p;
		#print Dumper($perl),p;
		#print "Updating $xmlfile with:",p;
		#print ": $xml  : $testxml :",p;

		open(XMLFILE,">$xmlfile") or print "Failed to open $xmlfile: $!",p; 
		print XMLFILE $xml;	
		return $xmlfile;													   	   
	} else {
		print "something is wrong.   Didn't find XML file, $xmlfile, to update the entry",p,hr;
		return undef;
	}
	return undef;
}

sub delete_xml {
	my $customer = param('customer') || 'ERROR';
	my $env  = 	param('env') || 'ERROR';
	my $middleware = param('middleware') || 'ERROR';
	my $action = param('action') || 'ERROR';
	my $role = param('role') || 'ERROR';
	my $version = param('version') || 'ERROR';
	my $app = param('app') || 'ERROR';
	my $action_command = param('action_command') || 'ERROR';
	my $verification_command = param('verification_command') || 'ERROR';
	my $perl;
	my $defined;
	my $stop_deleting = undef;
	
	my $xmlfile = lc("$XMLDIR" . '/' . "$env" . '_' . "$customer" . '.xml');
	if ( -r $xmlfile ) {
		print "Reading in previously generated entries in XML file: $xmlfile",p;
		$perl= XMLin( $xmlfile,  forceArray=>1) or print "Failed to parse xml in file $xmlfile: $!",p;
		
		eval {  $defined = $perl-> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
			    -> {version} -> {$version}-> {application} -> {$app} };
					  				
		if ($defined) {
			print "Deleting application details",p;
				my %hash = %{ $perl -> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
				      -> {version} -> {$version} -> {application} };
				delete $hash{$app} or print "Failed to find $app application entry for $role in XML",p;
				#Were there other applications associated with this role?
				my @otherapps = keys %hash;
				if (@otherapps) {
					my $otherapps = "@otherapps";
					print "Leaving XML entries for other applications: $otherapps",p;
					$stop_deleting = "true";
				} else {
					$stop_deleting = undef;
				}
				$perl -> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
				      -> {version} -> {$version} -> {application} = \%hash;
		} else {	
			print "Warning:  Failed to find application entry in $xmlfile related to the role, $role.",p
			      "Nothing to delete ... please, investigate and update the file by hand",p;
		}
		unless ( $stop_deleting ) {	 
				eval {  $defined = $perl-> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
			    -> {version} -> {$version} };
		 				
			if ($defined) {
				print "Deleting $version version details",p;
					my %hash = %{ $perl -> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
				      -> {version} };
					delete $hash{$version} or print "Failed to find version $version for $role in XML",p;
					#Were there other versions associated with this role?
					my @otherversions = keys %hash;
					if (@otherversions) {
						my $otherversions = "@otherversions";
						print "Leaving XML entries for other versions: $otherversions",p;
						$stop_deleting = "true";
					} else {
						$stop_deleting = undef;
					}
					$perl -> {role} -> {$role} -> {action} -> {$action} -> {middleware} -> {$middleware}
				      -> {version} = \%hash;
			} else {
				print "Warning:  Failed to find version details in $xmlfile for the role, $role.",p
			      	  "Nothing to delete ... please, investigate and update the file by hand",p;
			}
		}
		unless ( $stop_deleting ) {	 
				eval {  $defined = $perl-> {role} -> {$role} -> {action} -> {$action} -> {middleware}  };
		 				
			if ($defined) {
				print "Deleting $middleware middleware details",p;
					my %hash = %{ $perl -> {role} -> {$role} -> {action} -> {$action} -> {middleware} };
					delete $hash{$middleware} or print "Failed to find middleware $middleware for  $role in XML",p;
					#Were there other middleware associated with this role?
					my @othermiddleware = keys %hash;
					if (@othermiddleware) {
						my $othermiddleware = "@othermiddleware";
						print "Leaving XML entries for other middleware: $othermiddleware",p;
						$stop_deleting = "true";
					} else {
						$stop_deleting = undef;
					}
					$perl -> {role} -> {$role} -> {action} -> {$action} -> {middleware} = \%hash;
			} else {
				print "Warning:  Failed to find middleware details in $xmlfile for the role, $role.",p
			      	  "Nothing to delete ... please, investigate and update the file by hand",p;
			}
		}
		unless ( $stop_deleting ) {	 
				eval {  $defined = $perl-> {role} -> {$role} -> {action} };
		 				
			if ($defined) {
				print "Deleting $action action details",p;
					my %hash = %{ $perl -> {role} -> {$role} -> {action} };
					delete $hash{$action} or print "Failed to find action $action for  $role in XML",p;
					#Were there other actions associated with this role?
					my @otheractions = keys %hash;
					if (@otheractions) {
						my $otheractions = "@otheractions";
						print "Leaving XML entries for other actions: $otheractions",p;
						$stop_deleting = "true";
					} else {
						$stop_deleting = undef;
					}
					$perl -> {role} -> {$role} -> {action} -> {$action} -> {middleware} = \%hash;
			} else {
				print "Warning:  Failed to find action details in $xmlfile for the role, $role.",p
			      	  "Nothing to delete ... please, investigate and update the file by hand",p;
			}
		}
		unless ( $stop_deleting ) {	 
				eval {  $defined = $perl-> {role} };
		 				
			if ($defined) {
				print "Deleting $role entry",p;
					my %hash = %{ $perl -> {role} };
					delete $hash{$role} or print "Failed to find role $role in XML",p;
					#Were there other roles associated with this customer and environment?
					my @otherroles = keys %hash;
					if (@otherroles) {
						my $otherroles = "@otherroles";
						print "Leaving XML entries for other roles: $otherroles",p;
						$stop_deleting = "true";
					} else {
						$stop_deleting = undef;
					}
					$perl -> {role} = \%hash;
			} else {
				print "Warning:  Failed to find $role details in $xmlfile.",p
			      	  "Nothing to delete ... please, investigate and update the file by hand",p;
			}
		}
		
	
		if ( $stop_deleting ) {
			#Other entries besides this one were found .. write them out
			my $xml= XMLout( $perl ) or print "Failed to generate XML: $!",p;
			#print "Here is the raw perl structure:",p;
			#print Dumper($perl),p;
			#print "Updating $xmlfile with:",p;
			#print ": $xml  : $testxml :",p;

			open(XMLFILE,">$xmlfile") or print "Failed to open $xmlfile: $!",p; 
			print XMLFILE $xml;	
			return $xmlfile;
		} else {
			#nothing else was in this file ... lets remove it
			print "Deleting file, $xmlfile, as there were no other entries listed in it",p;
			unlink $xmlfile or print "Failed to remove $xmlfile when there were no more entries in it: $!",p;
			return $xmlfile;
		}
	} else {
		print "Something is wrong.   Didn't find XML file, $xmlfile, to delete the entry",p,hr;
		return undef;
	}
	return undef;
}

  
