#/www.*_p[123]_vhost:([0-9]{1,3}\.){3}[0-9]{1,3} OK/ {
#/.*_p[123].* OK/ {
/^[\ {8}|\t].* OK$/ {
        print $1"\tOK";
}
/^#### Recheck of .* failed:$/ {
        print $4"\tfailed";
}
/^##### Missing VIP ([0-9]{1,3}\.){3}[0-9]{1,3} for .* on loopback adapter.$/ {
        print $6"\tVIP_Missed";
}
/^#### Recheck of .* failed: The pattern:$/ {
        print $4"\tfailed(pattern)";
}
/^#### Recheck of .* failed:  \(A remote host did not respond within the timeout period$/ {
        print $4"\tfailed(timeout)";
}
/^#### Recheck of .* failed:  A remote host refused an attempted connect operation$/ {
        print $4"\tfailed(refused)";
}
/^####Check of web server errors indicates problem: Percent errors exceeds 10%: [0-9]+.?[0-9]*%\([0-9]+ errs in [0-9]+ seconds\)$/ {
        printf("Error\t>10%%(%.2f%%)\n",$12);
#       printf("Error\tExceeds_10%%(%.2f%%)\n",$12);
}

# Case 1 example:
#03:05:28 Checking IHS config file
#        Syntax OK
#03:05:28 Checking ei-stats over a 7 second interval
#        Error percentage OK
#node roles:  WEBSERVER.ESC.PRD WEBSERVER.CLUSTER.YZPRDCL002 PUB.ESC.ENDPOINT
#03:05:35 Checking IHS response for:  webserver.esc.prd
#        webserver.esc.prd OK
#### Check of webserver.esc.prd_rtp using http://rtp.www-930.events.ibm.com/support/esc/heartbeat.wss failed:
#03:05:36 ERROR 500: Internal Server Error
#### Waiting 10 seconds and trying again
#### Recheck of webserver.esc.prd_rtp failed:
#03:05:47 ERROR 500: Internal Server Error
#        webserver.esc.prd_stl OK
#        webserver.esc.prd_bld OK
###### /lfs/system/bin/check_ihs.sh Done

# Case 2 example:
#07:53:58 Checking aliases for VIP: 129.42.42.240
##### Missing VIP 129.42.42.240 for www.australianopen.com on loopback adapter.
#        www.australianopen.com points to external address
#                www.australianopen.com is an alias for www.australianopen.com.edgesuite.net.
#                www.australianopen.com.edgesuite.net is an alias for a1494.g.akamai.net.
#                a1494.g.akamai.net has address 64.215.172.235
#                a1494.g.akamai.net has address 64.215.172.243
#        www.australianopen.com_p1_vhost:129.42.26.240 OK
#        www.australianopen.com_p2_vhost:129.42.34.240 OK
#        www.australianopen.com_p3_vhost:129.42.42.240 OK
#

# Case 3 example:
#### Check of webserver.ibm.origin using http://www.ibm.com/Admin/whichnode failed: The pattern:
# s
#was not found in the response:
#v10106
#
#
#### Waiting 10 seconds and trying again
#### Recheck of webserver.ibm.origin failed: The pattern:
# s
#was not found in the response:
#v10106
#

# Case 4 example:
#### Check of webserver.stg.prd_p1 using https://p1.www-945.events.ibm.com/systems/support/csn/healthcheck/health.wss?health.requid=health.localtest failed:
#07:33:40 ERROR 500: Internal Server Error
#### Waiting 10 seconds and trying again
#### Recheck of webserver.stg.prd_p1 failed:  (A remote host did not respond within the timeout period

# Case 5 example:
#18:21:34 Checking IHS process
########## httpd not running
#18:21:34 Checking IHS config file
#        /lfs/system/bin/check_ihs.sh[69]: /etc/apachectl:  not found.
#### Failed to parse IHS config file. Check permission and syntax of config file.
#18:21:34 Checking ei-stats over a 7 second interval
#        Error percentage OK
#node roles:  WEBSERVER.CLUSTER.BZCDTCL004 WEBSERVER.IBM.CDT.BZ
#18:21:34 Checking IHS response for:  webserver.ibm.cdt.bz
#### Check of site.txt using http://localhost/site.txt failed:  A remote host refused an attempted connect operation
#### Waiting 10 seconds and trying again
#### Recheck of site.txt failed:  A remote host refused an attempted connect operation
###### /lfs/system/bin/check_ihs.sh Done

# Case 6 example:
#07:32:33 Checking ei-stats over a 7 second interval
#        Errors: 7
#        Access: 17
#        Percentage of Errors: 41.1764705882353
####Check of web server errors indicates problem: Percent errors exceeds 10%: 41.18%(7 errs in 7 seconds)
#node roles:  WEBSERVER.IBM.CDT WEBSERVER.CLUSTER.YZCDTCL003 PROJ_ISOLATED.IBM.RW GPFS.CLIENT
#07:32:40 Checking IHS response for:  webserver.ibm.cdt
#        site.txt OK
###### /lfs/system/bin/check_ihs.sh Done
