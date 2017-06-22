#!/bin/ksh
#Check the health of WebSphere Application Server
# Usage:   check_was.sh  [list of applications]
#
# Example: check_was.sh guestbook netpoll
#
# - If no arguements are passed then roles associated with the node are used to determine apps
# - All errors messages begin the line with "###"
#    * To look for just errors, run:  check_was.sh | grep \#
#
# - To look for 3 occurrences of "SUCCESS" in output of a health check use the following perl regular expression:
# (?s)(SUCCESS.*){3,}?
# - (?s) tells perl to match newlines as well as any character and space for '.*'
# - {3,}? tells perl to look for 3 or more occurrences of SUCCESS in the output

HOST=`hostname -s`
was_funcs=/lfs/system/tools/was/lib/was_functions.sh
[ -r $was_funcs ] && . $was_funcs || print -u2 -- "#### Can't read functions file at $was_funcs"

checkURL=/lfs/system/tools/ihs/bin/chk_url_clientauth.pm
ARGS=$*

#Call various functions defined in was/lib/was_functions.sh
checkWASapps

if [ $# -eq 0 ]; then
    #no args passed, lets look for WAS related roles
    funcs=/lfs/system/tools/configtools/lib/check_functions.sh
    [ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"
    getRoles
    for ROLE in $ROLES; do
        typeset -l ROLE
        if [[ "$ROLE" = "was"* || "$ROLE" = "wps"* || "$ROLE" = "wlp"* ]]; then 
            ARGS="$ARGS $ROLE"
        fi
    done
fi
if [[ -n $ARGS ]]; then
    #Check health of applications specified on the command line
    #This file should be updated as port numbers and health checks change
    #Currently, WAS health check polling is done with /usr/local/Tivoli/scripts/chk_url
    #That file can be used as a reference for what values should be placed here
    
    #May need to do some expansion first
    #Expand/map node roles to list of apps if necessary
    case $ARGS in
        *wlp.wwsm.prd.ucd*|*wlp.wwsm.pre.ucd*)
                ARGS="guestbook-wlp relatedcontent-wlp predictivecloud-wlp solr-wlp" ;;
        *wlp.wwsm.prd.sl*)
                ARGS="guestbook-wlp relatedcontent-wlp solr-wlp" ;;
        *wlp.wwsm.prd*|*wlp.wwsm.pre*)
                ARGS="guestbook-wlp solr-wlp relatedcontent-wlp" ;;
        *was.ve.prd.85*)
            ARGS="minijam4-85 minijam3-85 tickets-85 badges-85 masters-dcp edr_prd" ;;
        *was.ve.prd*)
            ARGS="minijam4 minijam3 tickets badges guestbook solr blazeds masters-dcp" ;;
        *was.ve.pre.85*)
            ARGS="tickets-pre-85 badges-pre-85 masters-dcp-pre edr_pre" ;;  
        *was.ve.pre*)
            ARGS="tickets-pre badges-pre guestbook-pre solr-pre blazeds-pre masters-dcp-pre" ;;
        *was.ve.cdt.85*)
            ARGS="edr_cdt" ;;
        *was.ibm.pre.wi.es*|*was.ibm.prd.es*) 
            ARGS="search_esa search_esps mqloader search_esqs";;
        *was.ibm.pre.ed.es*|*was.ibm.spp.es*)
            ARGS="admin_ui mqsubmitter";;
        *was.ibm.pre3.gz*)
            ARGS="profile links wireless investor instant_profile swif " ;;
        *was.ibm.pre2.gz*)
            ARGS="ied dynamicnav evs noticenchoice ibm_greet_etp ibm_ezaccess_merch ibm_instantreg" ;;
        *was.ibm.prd3.gz*)
            ARGS="investor instant_profile links profile wireless swif myibm rwservice webidm_prd" ;;
        *was.ibm.prd2.gz*)
            ARGS="dynamicnav evs noticenchoice ied ibm_greet_etp ibm_ezaccess_merch ibm_instantreg basicreg emailservice ibmid" ;;
        *was.ibm.cdt7.gz*)
            ARGS="ied investor instant_profile links profile wireless dynamicnav noticenchoice_cdt evs swif ibm_greet_etp ibm_ezaccess_merch ibm_instantreg rwservice webidm" ;;
        *was.ibm.spp.gz*)       
            ARGS="investor_preview " ;;
        *wps.ibm.*.portal.farm*)
            ARGS="ibm_base ibm_software" ;;
        *wps.ibm.*.portal.support)
            ARGS="ibm_base" ;;
        *was.ice.cdt*)
            ARGS="AxisEAR_preview_cdt AxisEAR_staging_cdt";;
        *was.ice.pre*)
            ARGS="AxisEAR_preview_pre AxisEAR_staging_pre AxisEAR_pre";;
        *was.ice.spp*)
            ARGS="AxisEAR_preview_spp AxisEAR_staging_spp";;
        *xsrspp.pre*|*xsr.sppp.cdt*)
            ARGS="xsrspp_ejb" ;;    
        *xsr.prd*|*xsr.pre*|*xsr.cdt*)
            ARGS="nexus xsr xsrAuth xat cat phoenix mcfeely_prd" ;;
        *xsr.spp*)
            ARGS="nexus phoenix mcfeely_spp xat dietplan" ;;
        *stg.prd)
            ARGS="csn csn_feeder sss css iepd_psp iepd_bdsr iepd_eci iepd_db iepd_retain" ;;
        *stg.spp)
            ARGS="csn_eventmonitor csn_spp crs_spp csn_broker_spp iepd_mq iepdeb_db iepdpr_db" ;;
        *stg.pre|*stg.cdt)
            ARGS="csn csn_feeder sss csn_eventmonitor csn_spp crs_spp csn_broker css iepd_psp iepd_bdsr iepd_eci iepd_db iepd_retain iepd_mq iepdeb_db iepdpr_db" ;;
        *was.dm*)
            ARGS="dmgr" ;;
        *was.cnp.prd*|*was.cnp.pre*|*was.cnp.cdt*)
            ARGS="itsdapi mlcr scm serviceprofile entitlement notification" ;;
        *was.cnp.spp*)
            ARGS="itsdapi" ;;
        *wps.cnp.prd*|*wps.cnp.pre*|*wps.cnp.cdt*)
            ARGS="edesktop" ;;
        *wps.spe.prd*)
            ARGS="spefacade spe_scsi spewps" ;;
        *wps.spe.cdt*|*wps.spe.pre*)
            ARGS="spefacade_cdt_pre spe_scsi spewps" ;;
        *was.zpap.prod*|*was.zpap.cdt*|*was.zpap.pre*)
            ARGS="zpap-admin zpap-zrsf zpap-tasks" ;;
        *was.sso.pre*|*was.sso.prd*)
            ARGS="sso-nextgen" ;;
    esac

    for APP in $ARGS ; do
        typeset -l APP
        case $APP in 
            zpap-admin) $checkURL ${APP} 'https://C-F2KY897%40nomail.relay.ibm.com:0$u&OM857Z9rTIh@localhost:9044/hwmgmt/remote/admin/admin.wss?HMRSRequId=Health' '<td width="75"  id="respcode">200</td>' ;;
            zpap-zrsf)      $checkURL ${APP} https://localhost:9044/hwmgmt/remote/support/zrsf.wss?HMRSRequId=Health '<td width="75"  id="respcode">200</td>' ;;
            zpap-tasks) $checkURL ${APP} https://localhost:9044/hwmgmt/remote/support/tasks.wss?HMRSRequId=Health '<td width="75"  id="respcode">200</td>' ;;
            masters-dcp)
                port=`/lfs/system/tools/was/bin/portreport.sh |grep WC |grep masters_dcp |grep $HOST |awk '{split($0,p,","); print p[5]}'`
                $checkURL ${APP} https://localhost:${port}/dcp/app/healthcheck?creCheck=true '^WAS=true\n\s*.*\n\s*.*\n.*\n\s*DB=true.*\n\s*Successfully' ;;
            masters-dcp-pre)
                port=`/lfs/system/tools/was/bin/portreport.sh |grep WC |grep masters_dcp |grep $HOST |awk '{split($0,p,","); print p[5]}'`
                $checkURL ${APP} https://localhost:${port}/dcp/app/healthcheck?creCheck=true '^WAS=true\n\s*.*\n\s*.*\n.*\n\s*DB=true.*\n\s*Successfully' ;;
            guestbook)      $checkURL ${APP} https://localhost:9055/gb2db2/Gb2db2?status true ;;
            guestbook-pre)  $checkURL ${APP} https://localhost:9051/gb2db2/Gb2db2?status true ;;
            guestbook-wlp)  $checkURL ${APP} https://localhost:9044/gb2db2/Gb2db2?status true ;;
            minijam3)       $checkURL ${APP} https://localhost:9051/minijam3/jam/healthMonitor.do 'WAS=success,\s*?\sDB2=success' ;;
            minijam3-85)    $checkURL ${APP} https://localhost:9443/minijam3/jam/healthMonitor.do 'WAS=success,\s*?\sDB2=success' ;;
            minijam4)       $checkURL ${APP} https://localhost:9052/jam4/jam/healthMonitor.action 'WAS=success,\s*?\sDB2=success' ;;
            minijam4-85)    $checkURL ${APP} https://localhost:9446/jam4/jam/healthMonitor.action 'WAS=success,\s*?\sDB2=success' ;;
            tickets)        $checkURL ${APP} https://localhost:9050/app/healthcheck 'WAS=true' ;;
            tickets-85)     $checkURL ${APP} https://localhost:9451/app/healthcheck 'WAS=true' ;;
            tickets-pre)    $checkURL ${APP} https://localhost:9044/app/healthcheck 'WAS=true' ;;
            tickets-pre-85) $checkURL ${APP} https://localhost:9450/app/healthcheck 'WAS=true' ;;
            badges)         $checkURL ${APP} https://localhost:9049/seriesbadges/app/healthcheck 'WAS=true' ;;
            badges-85)      $checkURL ${APP} https://localhost:9450/seriesbadges/app/healthcheck 'WAS=true' ;;
            badges-pre)     $checkURL ${APP} https://localhost:9046/seriesbadges/app/healthcheck 'WAS=true' ;;
            badges-pre-85)  $checkURL ${APP} https://localhost:9448/seriesbadges/app/healthcheck 'WAS=true' ;;
            solr)
                tagList="cmauso cmmast cmrolg cmtony cmusga cmwimb cmusta"
                for tag in $tagList; do $checkURL ${APP}_${tag}-even https://localhost:9047/slsearch/${tag}-even/admin/ping '<str name="status">OK</str>'; done
                tagList="cmauso cmmast cmrolg cmtony cmusga cmwimb cmusta"
                for tag in $tagList; do $checkURL ${APP}_${tag}-odd https://localhost:9047/slsearch/${tag}-odd/admin/ping '<str name="status">OK</str>'; done 
                $checkURL ${APP}_cmusga-even-women https://localhost:9047/slsearch/cmusga-even-women/admin/ping '<str name="status">OK</str>'
                $checkURL ${APP}_cmauso https://localhost:9047/slsearch/cmauso/admin/ping '<str name="status">OK</str>' ;;
            solr-pre)
                tagList="cmauso cmmast cmrolg cmtony cmusga cmwimb cmusta"
                for tag in $tagList; do $checkURL ${APP}_${tag} https://localhost:9048/slsearch/${tag}/admin/ping '<str name="status">OK</str>'; done ;;
            solr-wlp)
                tagList="cmauso cmmast cmrolg cmtony cmusga cmwimb cmusta"
                for tag in $tagList; do $checkURL ${APP}_${tag} https://localhost:9045/slsearch/${tag}/admin/ping '<str name="status">OK</str>'; done ;;
            blazeds)        $checkURL ${APP} https://localhost:9045/blazeds/BigData/BigData.html 'Get Adobe Flash' ;;
            blazeds-pre)    $checkURL ${APP} https://localhost:9052/blazeds/BigData/BigData.html 'Get Adobe Flash' ;;
            predictivecloud-wlp)    $checkURL ${APP} https://localhost:9043/blazeds/BigData/BigData.html 'Get Adobe Flash' ;;
            relatedcontent-wlp) $checkURL ${APP} https://localhost:9046/relatedcontent/rest/test '\[DB\] Pass' ;;
            axisear_preview_cdt)
                $checkURL ice_preview https://loopback:9044/services/healthcheck20.wss/status 'Database connection is available:\r\n <b>true' ;;
            axisear_preview_pre)
                $checkURL ice_preview https://loopback:9045/services/healthcheck20.wss/status 'Database connection is available:\r\n <b>true' ;;
            axisear_preview_spp)
                $checkURL ice_preview https://loopback:9040/services/healthcheck20.wss/status 'Database connection is available:\r\n <b>true' ;;
            axisear_staging_cdt)
                $checkURL ice_staging https://loopback:9045/services/healthcheck20.wss/status 'Database connection is available:\r\n <b>true' ;;
            axisear_staging_pre)
                $checkURL ice_staging https://loopback:9046/services/healthcheck20.wss/status 'Database connection is available:\r\n <b>true' ;;
            axisear_staging_spp)
                $checkURL ice_staging https://loopback:9041/services/healthcheck20.wss/status 'Database connection is available:\r\n <b>true' ;;
            axisear_pre)
                $checkURL ice_services https://loopback:9044/services/healthcheck20.wss/status 'Database connection is available:\r\n <b>true' ;;
            ied|employee)
                $checkURL $APP https://localhost:9052/contact/employees/servlets/utils/health '^\s*?PASS\s' ;;
            investor_preview)
                $checkURL $APP https://localhost:9090/investor/healthcheck '(?s)(PASS.*){3,}?' ;;
            investor)
                $checkURL $APP https://localhost:9055/investor/healthcheck '(?s)(PASS.*){3,}?' ;;
            wireless)
                $checkURL $APP https://localhost:9050/healthcheck/ '(?s)(PASS.*){7,}?' ;;
            instant_profile)
                export WGET_ARGS='-u testidtest@gmail.com:12345678'
                $checkURL $APP  https://localhost:9040/ibmweb/idm/instantprofile/public/healthcheck '^\s*?PASS\s' ;;
            profile|common_profile)
                $checkURL $APP https://localhost:9047/account/profile/app/healthcheck '^\s*?PASS\s'  ;;
            noticenchoice_cdt)
                $checkURL NoticeNChoice https://localhost:9080/NoticeNChoice/healthCheck.jsp '^\s*?PASS\s' ;;
            noticenchoice)
                $checkURL NoticeNChoice https://localhost:9045/NoticeNChoice/healthCheck.jsp '^\s*?PASS\s' ;;
            dynamicnav)
                $checkURL $APP https://localhost:9051/dynamicnav/healthcheck '(?s)(PASS.*){12,}?' ;;
            evs)
                $checkURL $APP https://localhost:9046/ibmweb/idm/evs/HealthCheckApp '(?s)(PASSED.*){6,}?' ;;
            links)
                $checkURL $APP https://localhost:9056/links/healthcheck '(?s)(PASS.*){2,}?'  ;;
            csn_eventmonitor)
                $checkURL CSN_eventmonitor  'https://localhost:9046/systems/support/csn/event/EventMonitorServlet.wss?reqid=InsertEventMessageRequest&application=HealthCheckerServlet&severity=INFO&message=Checking+Health+Test&context=HealthCheckServlet.processRequest%28%29' 'SUCCEEDED' ;; 
            csn_spp)
                $checkURL CSN_spp 'https://localhost:9046/systems/support/csn/sp/healthcheck/health.wss?health.requid=health.localtest' '(?s)(SUCCEEDED.*){2,}?' ;;
            crs_spp)
                $checkURL CRS_spp https://localhost:9046/systems/support/begz/registration/begz.wss?action=health_check '(?s)(SUCCESS.*){5,}?' ;;
            csn_broker_spp)
                $checkURL CSN_broker https://localhost:9046/systems/support/csn/broker/BrokerControllerStarter.wss?starter.requid=health_check 'SUCCEEDED' ;;
            csn_broker)
                $checkURL CSN_broker https://localhost:9046/systems/support/csn/broker/BrokerControllerStarter.wss?starter.requid=health_check 'SUCCEEDED' ;;
            csn_feeder)
                $checkURL CSN_feeder 'https://localhost:9045/systems/support/myfeed/xmlfeeder.wss?feeder.requid=feeder.test_feed&feeder.feedtype=RSS&feeder.uid=2700000442&feeder.subscrid=SFFFa0863b6f&feeder.subdefkey=s034&feeder.maxfeed=25'  'SUCCEEDED' ;;    
            csn)
                $checkURL CSN  https://localhost:9045/csn/hc/hc.wss?health.requid=health.localtest '(?s)(SUCCEEDED.*){1,}?' ;;
            sss)    
                $checkURL SSS https://localhost:9045/systems/support/healthcheck/ha_sss/healthcheck.wss/ei.hc 'SUCCESS' ;;
            css)
                $checkURL CSS https://localhost:9045/csn/hc/hc.wss?health.requid=health.test '(?s)(SUCCEEDED.*){3,}?' ;;        
            iepd_psp)
                $checkURL iepd_psp https://eiHealthCheck:pw4EIhc@localhost:9044/iepd-rest/services/healthCheckStatus/PSP_CONNECTION '"status": "PASS"' ;;
            iepd_bdsr)
                $checkURL iepd_bdsr https://eiHealthCheck:pw4EIhc@localhost:9044/iepd-rest/services/healthCheckStatus/BDSR_CONNECTION '"status": "PASS"' ;;
            iepd_eci)
                $checkURL iepd_eci https://eiHealthCheck:pw4EIhc@localhost:9044/iepd-rest/services/healthCheckStatus/ECI_PING '"status": "PASS"' ;;
            iepd_db)
                $checkURL iepd_db https://eiHealthCheck:pw4EIhc@localhost:9044/iepd-rest/services/healthCheckStatus?testTypes=DB_SELECT '"status": "PASS"' ;;
            iepd_retain)
                $checkURL iepd_retain https://eiHealthCheck:pw4EIhc@localhost:9044/iepd-rest/services/healthCheckStatus/RETAIN_BROWSE_HW '"status": "PASS"' ;;
            iepd_mq)
                $checkURL iepd_mq https://eiHealthCheck:pw4EIhc@localhost:9044/iepdeb-rest/services/healthCheckStatus/MQ_CONNECT '"status": "PASS"' ;;
            iepdeb_db)
                $checkURL iepdeb_db https://eiHealthCheck:pw4EIhc@localhost:9044/iepdeb-rest/services/healthCheckStatus/DB_SELECT '"status": "PASS"' ;;
            iepdpr_db)
                $checkURL iepdpr_db https://eiHealthCheck:pw4EIhc@localhost:9044/iepdeb-rest/services/healthCheckStatus/IEPDPR_DB_SELECT '"status": "PASS"' ;;
            nexus)
                #xSR application 
                $checkURL $APP https://localhost:9040/tools/support/xsr/ws/appMonitor?cmd=checkNexusConn 'Success: connection to nexus successful'
                $checkURL ${APP}_CamConn https://localhost:9040/tools/support/xsr/ws/appMonitor?cmd=checkCamConn 'Success: connection to phoenix successful'
                $checkURL ${APP}_McFeelyConn https://localhost:9040/tools/support/xsr/ws/appMonitor?cmd=checkMcFeelyConn 'Success: connection to McFeely successful'
                $checkURL ${APP}_RetainConn https://localhost:9040/tools/support/xsr/ws/appMonitor?cmd=checkRetainConn 'Success: connection to RETAIN \(RS4\) successful'
                $checkURL ${APP}_PMRRetry https://localhost:9040/tools/support/xsr/ws/appMonitor?cmd=checkPmrRetry 'Success: PMR retry is OK.'
                $checkURL ${APP}_UploadAttachment https://localhost:9040/tools/support/xsr/ws/appMonitor?cmd=checkUploadAttachment 'Success: UploadAttachment.*successful'
                $checkURL ${APP}_EcuRep https://localhost:9040/tools/support/xsr/ws/appMonitor?cmd=checkEcuRep 'Success:'
                $checkURL ${APP}_Testcase https://localhost:9040/tools/support/xsr/ws/appMonitor?cmd=checkTestcase 'Success:'
                $checkURL ${APP}_RetainPassword https://localhost:9040/tools/support/xsr/ws/appMonitor?cmd=checkRetainPassword 'Success: RETAIN ID:.*'
                ;;
            xsr)
                #xSR application 
                $checkURL ${APP}_NexusConn https://localhost:9041/support/servicerequest/appMonitor?cmd=checkNexusConn 'Success:' ;;
            xsrauth)
                #xSR application
                $checkURL ${APP}_NexusConn https://localhost:9041/xsrAuth/appMonitor?cmd=checkNexusConn 'Success: connection to nexus successful'
                #$checkURL ${APP}_PhoenixConn https://localhost:9041/xsrAuth/appMonitor?cmd=checkPhoenixConn 'Success: connection to phoenix successful'
                #$checkURL ${APP}_WIAuth https://localhost:9041/xsrAuth/appMonitor?cmd=checkWiAuth 'Success: WI Auth successful'
                $checkURL ${APP}_WIProfile https://localhost:9041/xsrAuth/appMonitor?cmd=checkWiProfile 'Success: WI Profile successful'
                #$checkURL ${APP}_WIFailOver https://localhost:9041/xsrAuth/appMonitor?cmd=checkWiFailOver 'Success: WI Failover successful'
                #$checkURL ${APP}_WIBypass https://localhost:9041/xsrAuth/appMonitor?cmd=checkWiBypass 'Success: WI Bypass successful'
                ;;
            xat)
                #xSR application 
                $checkURL ${APP}_NexusConn https://localhost:9042/tools/support/xsr/appMonitor?cmd=checkNexusConn 'Success: connection to nexus successful' ;;
            cat)
                #xSR application 
                $checkURL ${APP}_PhoenixConn https://localhost:9042/tools/support/cam/appMonitor?cmd=checkPhoenixConn 'Success: connection to phoenix successful' ;;
            phoenix)
                #xSR application
                $checkURL ${APP}_CamConn https://localhost:9040/tools/support/cam/ws/appMonitor?cmd=checkCamConn 'Success: connection to CAM successful'
                $checkURL ${APP}_DBConnection https://localhost:9040/tools/support/cam/ws/appMonitor?cmd=checkDBConn 'Success: connection to db successful'
                $checkURL ${APP}_SRCallerReport https://localhost:9040/tools/support/cam/ws/appMonitor?cmd=checkSRCallerReport 'Success: SRCallerReport'
                $checkURL ${APP}_PWISVWeb https://localhost:9040/tools/support/cam/ws/appMonitor?cmd=checkPWISVWeb 'Success: PWISV Web Service is OK'
                $checkURL ${APP}_WebIdentity https://localhost:9040/tools/support/cam/ws/appMonitor?cmd=checkWebIdentity 'Success: .* \[UP\].*\[UP\]'
                $checkURL ${APP}_IEEConn https://localhost:9040/tools/support/cam/ws/appMonitor?cmd=checkIEEConn 'Success: connection to IEE successful'
                ;;
            mcfeely_prd)
                #xSR application
                $checkURL McFeelyConn https://localhost:9040/mcfeelyWeb/appMonitor?cmd=checkMcFeelyConn 'successful'
                $checkURL ${APP}_DbConn https://localhost:9040/mcfeelyWeb/appMonitor?cmd=checkDbConn 'successful'
                #$checkURL ${APP}_QueueDepthBUSEVENTS 'https://localhost:9040/mcfeelyWeb/appMonitor?cmd=checkQueueDepth&queue=BUSEVENTS' 'OK'
                $checkURL ${APP}_UpdatePMREmail 'https://localhost:9040/mcfeelyWeb/appMonitor?cmd=checkUpdatePMREmail' 'Success: SERVICE_REQUEST_UPDATED'
                ;;
            mcfeely_spp)
                #xSR application
                $checkURL McFeelyConn https://localhost:9040/mcfeelyWeb/appMonitor?cmd=checkMcFeelyConn 'successful'
                $checkURL ${APP}_DbConn https://localhost:9040/mcfeelyWeb/appMonitor?cmd=checkDbConn 'successful'
                $checkURL ${APP}_QueueDepthLOG_DEBUG 'https://localhost:9040/mcfeelyWeb/appMonitor?cmd=checkQueueDepth&queue=LOG_DEBUG' 'OK' 
                $checkURL ${APP}_QueueDepthLOG_INFO 'https://localhost:9040/mcfeelyWeb/appMonitor?cmd=checkQueueDepth&queue=LOG_INFO' 'OK' 
                $checkURL ${APP}_QueueDepthLOG_WARN 'https://localhost:9040/mcfeelyWeb/appMonitor?cmd=checkQueueDepth&queue=LOG_WARN' 'OK' 
                $checkURL ${APP}_QueueDepthLOG_ERROR 'https://localhost:9040/mcfeelyWeb/appMonitor?cmd=checkQueueDepth&queue=LOG_ERROR' 'OK' 
                $checkURL ${APP}_QueueDepthLOG_FATAL 'https://localhost:9040/mcfeelyWeb/appMonitor?cmd=checkQueueDepth&queue=LOG_FATAL' 'OK' 
                $checkURL ${APP}_QueueDepthLOG_SQL 'https://localhost:9040/mcfeelyWeb/appMonitor?cmd=checkQueueDepth&queue=LOG_SQL' 'OK'  
                ;;  
            xsrspp_ejb)
                #Preprod runs two ejb servers - one that mimics 3-site production and another that mimics sppp  
                #Next check ejb container listening on port 9043
                $checkURL SPPP_Nexus https://localhost:9043/tools/support/xsr/ws/appMonitor?cmd=checkAll 'success:.*\n.*success:.*\n.*success:'
                $checkURL SPPP_Phoenix https://localhost:9043/tools/support/cam/ws/appMonitor?cmd=checkAll 'Success:.*\n.*Success:'
                $checkURL SPPP_McFeelyConn https://localhost:9043/mcfeelyWeb/appMonitor?cmd=checkMcFeelyConn 'successful'
                $checkURL SPPP_McFeely_DbConn https://localhost:9043/mcfeelyWeb/appMonitor?cmd=checkDbConn 'successful'
                $checkURL SPPP_McFeely_QueueDepthLOG_DEBUG 'https://localhost:9043/mcfeelyWeb/appMonitor?cmd=checkQueueDepth&queue=LOG_DEBUG' 'OK' 
                $checkURL SPPP_McFeely_QueueDepthLOG_INFO 'https://localhost:9043/mcfeelyWeb/appMonitor?cmd=checkQueueDepth&queue=LOG_INFO' 'OK' 
                $checkURL SPPP_McFeely_QueueDepthLOG_WARN 'https://localhost:9043/mcfeelyWeb/appMonitor?cmd=checkQueueDepth&queue=LOG_WARN' 'OK' 
                $checkURL SPPP_McFeely_QueueDepthLOG_ERROR 'https://localhost:9043/mcfeelyWeb/appMonitor?cmd=checkQueueDepth&queue=LOG_ERROR' 'OK' 
                $checkURL SPPP_McFeely_QueueDepthLOG_FATAL 'https://localhost:9043/mcfeelyWeb/appMonitor?cmd=checkQueueDepth&queue=LOG_FATAL' 'OK' 
                $checkURL SPPP_McFeely_QueueDepthLOG_SQL 'https://localhost:9043/mcfeelyWeb/appMonitor?cmd=checkQueueDepth&queue=LOG_SQL' 'OK'  
                ;;
            search_esa)
                $checkURL $APP https://localhost:9044/search/esas/healthcheck '^\s*?PASS\s';;
            mqloader)
                $checkURL $APP https://localhost:9045/search/esas/deltaController/healthcheck '^\s*?PASS\s';;
            mqsubmitter)
                $checkURL $APP https://localhost:9046/search/esas/deltaController/submitter/www/healthcheck '^\s*?PASS\s';;
            search_esps)
                $checkURL $APP https://localhost:9047/search/esas/esps/healthcheck '^\s*?PASS\s';;
            search_esqs)
                $checkURL $APP https://localhost:9046/search/esas/esqs/healthcheck '^\s*?PASS\s';;
            admin_ui)
                $checkURL $APP https://localhost:9044/search/adminui/console/healthcheck '^\s*?PASS\s';;
            itsdapi)
                $checkURL $APP https://localhost:9051/support/electronic/itsdapi/healthcheck/DapiStatus 'Success'
                $checkURL itsdapi_v2 https://localhost:9052/support/electronic/itsdapi_v2/rest/saisearch/isAvailable '(?s)(true.*){2,}?' ;;
            mlcr)
                $checkURL $APP https://localhost:9058/support/electronic/mlcr_v2/healthcheck/status 'Success' ;;
            scm)
                $checkURL $APP https://localhost:9054/support/electronic/scm/healthcheck/status 'Success' ;;
            serviceprofile)
                $checkURL $APP https://localhost:9055/support/electronic/serviceprofile/healthcheck/status 'Success' ;;
            entitlement)
                $checkURL $APP https://localhost:9057/support/electronic/entitlement/healthcheck/status 'Success' ;;
            notification)
                $checkURL $APP https://localhost:9056/support/electronic/spe/notificationhealthcheck/Status 'Success' ;;
            edesktop)
                $checkURL $APP https://localhost:9053/support/electronic/edesktop/hcstatus '.*:(Success.*){4,}?' ;;
            spefacade)
                $checkURL ${APP}_hc https://localhost:9051/support/entry/healthcheck/runcheck '(?s)(SUCCESS.*){7,}?'
                $checkURL ${APP}_boarders https://localhost:9051/support/entry/healthcheckboarders/runcheck '(?s)(SUCCESS.*){1,}?' ;;
            spefacade_cdt_pre)
                $checkURL ${APP}_hc https://localhost:9051/support/entry/healthcheck/runcheck '(?s)(SUCCESS.*){7,}?'
                $checkURL ${APP}_boarders https://localhost:9051/support/entry/healthcheckboarders/runcheck '(?s)(SUCCESS.*){1,}?' ;;
            spe_scsi)
                $checkURL ${APP}_hc https://localhost:9052/support/scsix/healthcheck/runcheck '(?s)(SUCCESS.*){1,}?'
                $checkURL ${APP}_Entitlement https://localhost:9052/support/entry/service/EntitlementWebService/services/EntitlementWebService 'Hi there, this is a Web service!' ;;
            spewps)
                $checkURL ${APP}_portal https://localhost:9050/support/entry/portal 'IBM Support Portal'
                echo "           ** ${APP}_portal check only verifies app is running, not full functionality." ;;
            ibm_base)
                $checkURL ${APP}_portal https://localhost:9029/web/portal/ei-monitor-page '<title>ei-monitor-page</title>' ;;
            ibm_software)
                $checkURL ${APP}_portal https://localhost:9029/web/portal/software '<meta content="index,follow" name="Robots".*>' ;;
            swif)
                $checkURL $APP 'https://localhost:9064/gateway/?cb=999:none&cc=us&lc=en' '^\s*?PASS\s';;
            dietplan)
                $checkURL $APP https://localhost:9040/kobayashiWeb/appMonitor?cmd=checkDietPlan 'Success:' ;;
            ibm_greet_etp)
                $checkURL ${APP}_hc https://localhost:9067/ibmweb/greet_etp/greeting/healthcheck '^\s*?PASS\s'
                $checkURL ${APP}_signindisplay https://localhost:9067/ibmweb/greet_etp/signindisplay/healthcheck '^\s*?PASS\s'
                $checkURL ${APP}_emailthispage https://localhost:9067/ibmweb/greet_etp/emailthispage/healthcheck '^\s*?PASS\s' ;;
            ibm_ezaccess_merch)
                $checkURL ${APP}_easyaccess https://localhost:9068/ibmweb/ezaccess_merch/easyaccess/healthcheck '^\s*?PASS\s'
                $checkURL ${APP}_merchandising https://localhost:9068/ibmweb/ezaccess_merch/merchandising/healthcheck '^\s*?PASS\s' ;;
            ibm_instantreg)
                $checkURL $APP https://localhost:9070/gss/instantprofile/healthcheck '^\s*?PASS\s' ;;
            rwservice)
                $checkURL ${APP} https://localhost:9059/ibmweb/idm/common_profile_extended/healthcheck '^\s*?PASS\s' ;;
            webidm)
                $checkURL ${APP} https://localhost:9045/ibmweb/idm/dxds/healthcheck '^\s*?PASS\s' ;;
            webidm_prd)
                $checkURL ${APP} https://localhost:9045/ibmweb/idm/webidm/healthcheck '(?s)(PASS.*){3,}?' ;;
            myibm)
                $checkURL ${APP} https://localhost:9053/ibmweb/myibm/account/healthcheck '(?s)(PASS.*){4,}?' ;;
            basicreg)
                $checkURL ${APP} https://localhost:9044/ibmweb/basic/profile/healthcheck '(?s)(PASS.*){5,}?' ;;
            emailservice)
                $checkURL ${APP} https://localhost:9068/ibmweb/emailservice/healthcheck  '(?s)(PASS.*){7,}?' ;;
            ibmid)
                $checkURL ${APP} https://localhost:9048/ibmweb/account/ibmid/healthcheck '(?s)(PASS.*){6,}?' ;;
            sso-nextgen)
                $checkURL ${APP} https://localhost:9042/ibmid/UserServicesHealthCheck.wss '(?s)(PASS.*){4,}?' ;;
            edr_cdt)
                $checkURL edr_admin https://localhost:9445/AdministrationPortal/ei/healthcheck '(?s)(PASS.*){6,}?'
                $checkURL edr_reg https://localhost:9444/RegistrationPortal/ei/healthcheck '(?s)(PASS.*){6,}?' ;;
            edr_pre)
                $checkURL edr_admin https://localhost:9444/AdministrationPortal/ei/healthcheck '(?s)(PASS.*){6,}?'
                $checkURL edr_reg https://localhost:9443/RegistrationPortal/ei/healthcheck '(?s)(PASS.*){6,}?' ;;
            edr_prd)
                $checkURL edr_admin https://localhost:9462/AdministrationPortal/ei/healthcheck '(?s)(PASS.*){6,}?'
                $checkURL edr_reg https://localhost:9458/RegistrationPortal/ei/healthcheck '(?s)(PASS.*){6,}?' ;;

            nodeagent|dmgr|*m2m*)
                /lfs/system/tools/configtools/countprocs.sh 1 $MYPID > /dev/null && echo "$APP OK" 
                /lfs/system/tools/configtools/countprocs.sh 1 $MYPID > /dev/null || print -u2 --  "####Failed to find $APP running" ;;
            *)
                print -u2 -- "#### Update $0 to recognize $APP" ;;  
        esac
    done
fi

echo "###### $0 Done"
