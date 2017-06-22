BEGIN   { RS = "\n"; FS = " "; existence="Not_Found"; }
/^(\t|\ {8})Found\ instance\ [a-zA-Z0-9_]+\ at\ PID=[0-9]+\ for\ .*$/ || /^#{9} LCS not running$/ { existence="Found"; }
END	{ print "LCS\t"existence; }
