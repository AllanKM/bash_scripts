/^\ +[0-9]+\ \/([^\/]+\/)*httpd\ -d\ \/([^\/]+\/)*[a-zA-Z0-9_\-]+\ -k\ start\ *$/ { print $2,$1; }
/^\ +[0-9]+\ \/([^\/]+\/)*httpd\ -d\ \/([^\/]+\/)*[a-zA-Z0-9_\-]+\ -f\ \/([^\/]+\/)*[a-zA-Z0-9_\-]+\.conf\ -k\ start\ *$/ { print $2"("$6")",$1; }
/^########## httpd not running$/ { print "httpd\tNot_Running"; }

#Case 1:
#07:53:51 Checking IHS process
#     11 /usr/HTTPServer/bin/httpd -d /usr/HTTPServer -k start 
#
#        Apache Server Status for HTTPServer
#
#        Server Version: IBM_HTTP_Server
#        Server Built: Mar 10 2010 15:59:22
#        __________________________________________________________________
#
#        Current Time: Friday, 11-Mar-2011 07:53:51 UTC
#        Restart Time: Friday, 11-Mar-2011 06:52:28 UTC
#        Parent Server Generation: 0
#        Server uptime: 1 hour 1 minute 22 seconds
#        Total accesses: 1588 - Total Traffic: 315 kB

#Case 2:
#13:04:16 Checking IHS process
#      9 /usr/HTTPServer/bin/httpd -d /usr/HTTPServer -f /projects/cmrolg-odd/conf/cmrolg-odd.conf -k start
#     10 /usr/HTTPServer/bin/httpd -d /usr/HTTPServer -f /projects/cmtony-odd/conf/cmtony-odd.conf -k start
#      9 /usr/HTTPServer/bin/httpd -d /usr/HTTPServer -f /projects/cmusga-odd/conf/cmusga-odd.conf -k start
#      9 /usr/HTTPServer/bin/httpd -d /usr/HTTPServer -f /projects/cmusta-odd/conf/cmusta-odd.conf -k start
#      9 /usr/HTTPServer/bin/httpd -d /usr/HTTPServer -f /projects/cmwimb-odd/conf/cmwimb-odd.conf -k start
#
#Looking up localhost
#Making HTTP connection to localhost
#Alert!: Unable to connect to remote host.
#
#lynx: Can't access startfile http://localhost/server-status
#13:04:16 Checking IHS config file
#        Syntax OK
#13:04:16 Checking ei-stats over a 7 second interval
#        Error percentage OK
#node roles:  WEBSERVER.SWS.X WEBSERVER.EI.61029 GPFS.CLIENT
#13:04:16 Checking IHS response for:  webserver.sws.x webserver.ei.61029
#### Check of site.txt using http://localhost/site.txt failed:  Connection refused
#### Waiting 10 seconds and trying again
#### Recheck of site.txt failed:  Connection refused
#### Check of site.txt using http://localhost/site.txt failed:  Connection refused
#### Waiting 10 seconds and trying again
#### Recheck of site.txt failed:  Connection refused
###### /lfs/system/bin/check_ihs.sh Done

#Case 3:
#11:51:10 Checking IHS process
########## httpd not running
#11:51:10 Checking IHS config file
#        /lfs/system/bin/check_ihs.sh[69]: /etc/apachectl:  not found.
#### Failed to parse IHS config file. Check permission and syntax of config file.
#11:51:10 Checking ei-stats over a 7 second interval
#        Error percentage OK
#node roles:  TMF.TMR.SERVER TMF.LCF.GATEWAY MONITORING.SMA.ITCAMISM.SERVER PUB.BZPRTL.CLIENT
#11:51:11 Checking IHS response for:
###### /lfs/system/bin/check_ihs.sh Done
