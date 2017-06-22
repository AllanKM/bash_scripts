BEGIN   {       RS = "\n"; FS = " "; hostname = ""; dm = ""; app = ""; rstatus = "";    }

$0 ~ /^\ {3}HOST: .*$/ { hostname = $2; }
#$0 ~ /^\ {5}APP SERVERS UNDER: .*$/ { FS="/"; dm=$NF; FS=" "; }
$0 ~ /^\ {5}APP SERVERS UNDER: .*$/ { n = split($NF,a,"/"); dm = a[n]; }
$2 ~ /RUNNING|##STOPPED##/ { app = $1; rstatus = $2; }
$0 ~ /## DO NOT START ##/ { app = $1; rstatus = "##DO_NOT_START##"; }

{ if (hostname != "" && dm !="" && app !="") { print app"(@"hostname":"dm")\t"rstatus; app = ""; rstatus = ""; } }

#Case 1:
#08:21:49 Checking WebSphere Processes
#
#---------------------------
#   HOST: w20004
#---------------------------
#
#    --------------------------------------------------------------------
#     APP SERVERS UNDER: /usr/WebSphere61/AppServer/profiles/gzcdt61wiibm2Manager
#    --------------------------------------------------------------------
#
#     SERVER NAME      STATE        PID      UP SINCE
#     --------------   -------      -------  ------------
#     dmgr             ##STOPPED##
#
#    SERVER COUNT  = 1
#    RUNNING COUNT = 0
#
### Not all defined WAS servers are running
#
#    --------------------------------------------------------------------
#     APP SERVERS UNDER: /usr/WebSphere61/AppServer/profiles/gzpre61wiManager
#    --------------------------------------------------------------------
#
#     SERVER NAME      STATE        PID      UP SINCE
#     --------------   -------      -------  ------------
#     dmgr             ##STOPPED##
#
#    SERVER COUNT  = 1
#    RUNNING COUNT = 0
#
### Not all defined WAS servers are running
#
#    --------------------------------------------------------------------
#     APP SERVERS UNDER: /usr/WebSphere61/AppServer/profiles/gzspp61wiManager
#    --------------------------------------------------------------------
#
#     SERVER NAME      STATE        PID      UP SINCE
#     --------------   -------      -------  ------------
#     dmgr             RUNNING      6094998  Mar 07 16:04
#
#    SERVER COUNT  = 1
#    RUNNING COUNT = 1
#
#node roles:  WAS.DM.BACKUP
#dmgr OK
###### /lfs/system/bin/check_was.sh Done

#Case 2:
#02:20:21 Checking WebSphere Processes
#
#---------------------------
#   HOST: v10062
#---------------------------
#
#    --------------------------------------------------------------------
#     APP SERVERS UNDER: /usr/WebSphere70/AppServer/profiles/v10062
#     version: 7.0.0.13  build date: 10/2/10  level: cf131039.07
#    --------------------------------------------------------------------
#
#     SERVER NAME              STATE        PID      UP SINCE
#     --------------           -------      -------  ------------
#     DC_wwsm_search2_v10062   ##STOPPED##
#     DC_wwsm_search_v10062    ##STOPPED##
#     nodeagent                ##STOPPED##
#     v10062_jams_minijam      ## DO NOT START ##
#     v10062_wwsm_events       ## DO NOT START ##
#     v10062_wwsm_search       ##STOPPED##
#     v10062_wwsm_search2      ##STOPPED##
#
#    SERVER COUNT  = 7
#    RUNNING COUNT = 0
#
### Not all defined WAS servers are running
#node roles:  WAS.EVENTS.PRD.P6 WAS.EVENTS.PRD PUB.EVENTS.ENDPOINT.SEARCH PUB.EVENTS.ENDPOINT.WAS
#### Check of eipatron70 using https://localhost:9052/eipatron2/healthMonitor.do failed:  A remote host refused an attempted connect operation
#### Waiting 10 seconds and trying again
#### Recheck of eipatron70 failed:  A remote host refused an attempted connect operation
#### Check of guestbook70 using https://localhost:9052/gb2db2/Gb2db2?status failed:  A remote host refused an attempted connect operation
#### Waiting 10 seconds and trying again
#### Recheck of guestbook70 failed:  A remote host refused an attempted connect operation
#### Check of minijam70 using https://localhost:9046/minijam3/jam/healthMonitor.do failed:  A remote host refused an attempted connect operation
#### Waiting 10 seconds and trying again
#### Recheck of minijam70 failed:  A remote host refused an attempted connect operation
#### wwsm_search does not have a healthcheck URL currently
#### wwsm_search2 does not have a healthcheck URL currently
###### /lfs/system/bin/check_was.sh Done
