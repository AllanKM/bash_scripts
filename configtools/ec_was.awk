BEGIN { RS = "\n"; FS = " "; }
/^   HOST: .*$/ { hostname = $2; }
/^     APP SERVERS UNDER: .*$/ { appdir = $4; }
/^     version: [0-9]+(\.[0-9]+)+  build date: [0-9]{1,2}(\/[0-9]{1,2}){2}  level: [a-z0-9.]+$/ { ver = $2; bdate = $5; lvl = $7; }
/^    # Directory not found: \/.*$/ { missdir = $5; }
/^#### Update \/lfs\/system\/bin\/check_was\.sh to recognize.*$/ { role = $6; }
END {
if (hostname != "" && appdir !="") { print hostname":"appdir"\tFound"; }
if (ver != "") { print "Version\t"ver; }
if (bdate != "") { print "Build_Date\t"bdate; }
if (lvl != "") { print "Level\t"lvl; }
if (missdir != "") { print missdir"\tNot_Found"; }
if (role !="") { print role"\tRole_Unrecognized"; }
}


#08:22:51 Checking WebSphere Processes
#
#---------------------------
#   HOST: v30010
#---------------------------
#
#    --------------------------------------------------------------------
#     APP SERVERS UNDER: /usr/WebSphere61/AppServer/profiles/v30010
#    --------------------------------------------------------------------
#
#     SERVER NAME          STATE        PID      UP SINCE
#     --------------       -------      -------  ------------
#     nodeagent            RUNNING      618576   Mar 11 05:21
#     v30010_stg_iepd      RUNNING      827420   Mar 11 05:26
#     v30010_stg_m2m       RUNNING      712858   Mar 11 05:23
#     v30010_stg_sss-csn   RUNNING      192644   Mar 11 05:29
#
#    SERVER COUNT  = 4
#    RUNNING COUNT = 4
#
#node roles:  MQ.STG.CLIENT WAS.STG.PROD PUB.STG.LDIST.PRD DATABASE.STG.CLIENT.DB2V8


#12:12:31 Checking WebSphere Processes
#
#---------------------------
#   HOST: dt1201b
#---------------------------
#
#    # Directory not found: /usr/WebSphere70/AppServer/profiles/?z*anager
#
#node roles:  TMF.TMR.SERVER TMF.LCF.GATEWAY MONITORING.SMA.ITCAMISM.SERVER PUB.BZPRTL.CLIENT
###### /lfs/system/bin/check_was.sh Done


#10:16:45 Checking WebSphere Processes
#
#---------------------------
#   HOST: w20094
#---------------------------
#
#    --------------------------------------------------------------------
#     APP SERVERS UNDER: /usr/WebSphere70/AppServer/profiles/gzspp70edibmManager
#     version: 7.0.0.15  build date: 2/15/11  level: cf151107.06
#    --------------------------------------------------------------------
#
#     SERVER NAME      STATE        PID      UP SINCE
#     --------------   -------      -------  ------------
#     dmgr             RUNNING      6321     Sep 26 09:03
#
#    SERVER COUNT  = 1
#    RUNNING COUNT = 1
#
#node roles:  WAS.DM.IBM.SPP.ED.ES
#dmgr OK
###### /lfs/system/bin/check_was.sh Done


# Case: check_was.sh can't recognize new node roles.  WAS may be started by "sudo /usr/WebSphere??/AppServer/profiles/*/bin/startServer.sh <AppServer>"
#05:55:42 Checking WebSphere Processes
#
#---------------------------
#   HOST: v10102
#---------------------------
#
#    # Directory not found: /usr/WebSphere70/AppServer/profiles/?z*anager
#
#node roles:  WAS.EI.TLCM
#### Update /lfs/system/bin/check_was.sh to recognize was.ei.tlcm
###### /lfs/system/bin/check_was.sh Done
