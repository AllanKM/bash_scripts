/^(\t|\ {8})Found\ instance\ [a-zA-Z0-9_]+\ at\ PID=[0-9]+\ for\ [^\ ]+$/ { print $3"\tRunning"; }
/^#{9} LCS not running/ {print "LCS\tNot_Running"; }

#Case 1 Example:
#02:26:28 Checking LCS client
#        Found instance lcs_clientibm948p at PID=4915444 for www-948stage.ibm.com
#        Found instance lcs_clientibm952p at PID=5701810 for www-952stage.ibm.com
#        Found instance lcs_clientibmpxyp at PID=5570734 for ibmproxy.staging.events.ihost.com
#        Found instance lcs_clientihsrv at PID=5505196 for IBMHTTPServer
#02:26:29 ###### /lfs/system/bin/check_lcs.sh Done


#Case 2 Example:
#09:11:38 Checking LCS client
######### LCS not running
#09:11:38 ###### /lfs/system/bin/check_lcs.sh Done
