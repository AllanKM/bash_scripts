BEGIN   { RS = "\n"; FS = " "; existence="Found"; }
/^(\t|\ {8})?\/lfs\/system\/bin\/check_ihs\.sh\[[0-9]+\]: \/etc\/apachectl:  not found\.$/ { existence="Not_Found"; }
END	{ print "/etc/apachectl\t"existence; }

# Case 1 example
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

# Case 2 example: This case may be happened when httpd is started by "sudo /usr/HTTPServer/bin/apachectl start" rather than "sudo /lfs/system/bin/rc.ihs start"
#02:06:24 Checking IHS process
#   4 /usr/HTTPServer/bin/httpd -d /usr/HTTPServer -k start
#/lfs/system/bin/check_ihs.sh[69]: /etc/apachectl:  not found.
#02:06:24 Checking IHS config file
#        /lfs/system/bin/check_ihs.sh[69]: /etc/apachectl:  not found.
#### Failed to parse IHS config file. Check permission and syntax of config file.
#02:06:24 Checking ei-stats over a 7 second interval
#        Error percentage OK
#node roles:  WAS.EI.TLCM
#02:06:24 Checking IHS response for:
###### /lfs/system/bin/check_ihs.sh Done
