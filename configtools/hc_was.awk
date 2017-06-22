# Health Check Information
BEGIN	{	RS = "\n"; FS = " "; hostname = ""; dm = ""; app = ""; hstatus = "";	}

	$0 ~ /^\ {3}HOST: .*$/ { hostname = $2; }
#	$0 ~ /^\ {5}APP SERVERS UNDER: .*$/ { FS="/"; dm = $NF; FS=" "; }
	$0 ~ /^\ {5}APP SERVERS UNDER: .*$/ { n = split($NF,a,"/"); dm = a[n]; }
        $2 ~ /OK|failed/ { app = $1; hstatus = $2; }
        $0 ~ /^#### Check of [^\ ]+ is now OK$/ { app = $4; hstatus = "OK"; }
        $0 ~ /^#### Recheck of [^\ ]+ failed:  \(A remote host did not respond within the timeout period$/ { app = $4; hstatus = "failed(timeout)"; }
	$0 ~ /^#### Recheck of [^\ ]+ failed: The pattern:$/ { app = $4; hstatus = "failed(pattern)"; }
	$0 ~ /^#### Recheck of [^\ ]+ failed:  A remote host refused an attempted connect operation$/ { app = $4; hstatus = "failed(refused)"; }
	$0 ~ /^#### Recheck of [^\ ]+ failed:  404: Not Found$/ { app = $4; hstatus = "failed(404)"; }
	$0 ~ /^#### [^\ ]+ does not have a healthcheck URL currently$/ { app = $2; hstatus = "NO_HC_URL"; }

#{ if (hostname != "" && dm != "" && app != "") { print app"(@"hostname":"dm")\t"hstatus; app = ""; hstatus = ""; } }
{ if (app != "" && hstatus != "") {print app"\t"hstatus; app = ""; hstatus = "";} }




# Case 1 example:
#        dynamicnav OK

# Case 2 example:
#### Check of NoticeNChoice using https://localhost:9045/NoticeNChoice/healthCheck.jsp failed:  (A remote host did not respond within the timeout period
#### Waiting 10 seconds and trying again
#### Check of NoticeNChoice is now OK

# Case 3 example:
#### Check of osi using https://localhost:9053/account/orderstatus/myorders/healthcheck failed:  (A remote host did not respond within the timeout period
#### Waiting 10 seconds and trying again
#### Recheck of osi failed:  (A remote host did not respond within the timeout period

# Case 4 example:
#### Check of notificationAS using https://localhost:9057/support/electronic/healthcheck/Status?test=Notification failed: The pattern:
# Success
#was not found in the response
#
#### Waiting 10 seconds and trying again
#### Recheck of notificationAS failed: The pattern:
# Success
#was not found in the response

# Case 5 example:
#### Check of osi using https://localhost:9053/account/orderstatus/myorders/healthcheck failed:  A remote host refused an attempted connect operation
#### Waiting 10 seconds and trying again
#### Recheck of osi failed:  A remote host refused an attempted connect operation

# Case 6 example:
#### Check of evs using https://localhost:9046/myprofile/EVS/HealthCheckApp failed:  404: Not Found
#### Waiting 10 seconds and trying again
#### Recheck of evs failed:  404: Not Found

# Case 7 example:
#### wwsm_search does not have a healthcheck URL currently
#### wwsm_search2 does not have a healthcheck URL currently
