BEGIN   { RS = "\n"; FS = " "; existence="Not_Found" }
/^([0-9]{2}:){2}[0-9]{2}\ Checking Publishing Status$/ || /^##### bNimble not running$/ { existence="Found" }
END	{ print "bNimble\t"existence; }
