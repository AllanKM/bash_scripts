/^([0-9]{2}:){2}[0-9]{2}\ Checking Publishing Status$/ { print "bNimble\tRunning"; }
/^##### bNimble not running$/ { print "bNimble\tNot_Running"; }
