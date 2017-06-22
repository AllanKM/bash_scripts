#!/usr/local/bin/perl 


###############################################
# Start user configurable section
###############################################

$title="US Open 2005 VE Search FileInformation results";

# Array of emails
@emailAddress = qw(mauro1@us.ibm.com rbcubril@us.ibm.com vaughank@us.ibm.com);
#@emailAddress = qw(mauro1@us.ibm.com );

# Strings from allnodes to include ( picture grep -i )
#$include = "ac0203a";
$include = "WEBSERVER.EVENTS.ORIGIN.VE.SLES WEBSERVER.EVENTS.ORIGIN.VE.AIX";

# Strings from allnodes to include ( picture grep -vi )
#VE#$exclude = "gt0803[bc] gt0804[bcjk]";
$exclude = "";

# Server port
$bNimblePort = "6328";

# Server URI
$fileInformationURI = "/fileinformation";


###############################################
# End user configurable section
###############################################


$debug = $ARGV[0];
$debug_var = "";
$stdout = 0;
$sendmail = 1;

if( $debug eq "-debug" ){
	$sendmail = 0;
	$debug = 1;
	$debug_var = "-debug";
}

if( $debug eq "-stdout" ){
	$stdout = 1;
	$sendmail = 0;
}


system("/fs/system/tools/publish/bin/scripts/FileInformation/MakeNodeList.pl --port $bNimblePort --uri $fileInformationURI --include \"$include\" --exclude \"$exclude\" ");


$BNIMBLE_HOME = "/fs/system/tools/publish/bin";
$FILE_INFO_HOME = "/fs/system/tools/publish/bin/scripts/FileInformation";
$FILE_LIST = "FileList_VEsearch";
$HOST_LIST = "HostFile_VEsearch";

# get output of program
if( $debug || $stdout ){
system("java -Xmx512M -jar \"$BNIMBLE_HOME/FileInformation.jar\" --hostfile $FILE_INFO_HOME/$HOST_LIST --filelist $FILE_INFO_HOME/$FILE_LIST --missing --size --crc $debug_var 2> /tmp/FileInformation.stderr");
}

else{
$output = `java -Xmx512M -jar "$BNIMBLE_HOME/FileInformation.jar" --hostfile $FILE_INFO_HOME/$HOST_LIST --filelist $FILE_INFO_HOME/$FILE_LIST --missing --size --crc $debug_var 2> /tmp/FileInformation.stderr`;
}


if(! $output){
	open(ERROR, "/tmp/FileInformation.stderr");
	$errorOutput = join('',<ERROR>);
	close(ERROR);	

	$output = "Program error, unable to run FileInformation query.\nError output follows:\n\n" . $errorOutput;
}

# send mail to users
if( $sendmail ){
	foreach $email(@emailAddress){
		open (MAIL, "|mail -s \"$title\" $email");
		print MAIL $output;
		close MAIL;
	}
}





