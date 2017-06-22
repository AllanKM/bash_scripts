BEGIN   { RS = "\n"; FS = " "; existence="Not_Found" }
/^#{7} Spong not running$/ || /(Polling|Checking)\ every\ [0-9]+\ seconds/ { existence="Found" }
END	{ print "Spong\t"existence; }
