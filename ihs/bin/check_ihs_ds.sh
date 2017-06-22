#!/usr/bin/ksh
#Check the health of IHS
#Usage:
#         check_ihs.sh  [list of sites]
#Example: check_ihs.sh rolandgarros-odd masters-odd tonys-odd

#All errors messages begin the line with "###"
#To look for just errors, run:  check_ihs.sh | grep \#
validate_vhosts() {

	CFGS=`awk 'BEGIN{IGNORECASE=1}/^[:blank:]*include.*\/projects\// {print $2}' /usr/HTTPServer/conf/httpd.conf | grep -i $2`
	for cfg in $CFGS; do
		VIPS=`awk -v site="$1" 'BEGIN{
			IGNORECASE=1;
			ORS=""
			want=0
			x=0}
			/servername/ { 
				if ( index( $0,site)) { 
					want=1 
				} 
			}; 
			/<virtualhost/ { 
				gsub(/<|>/,""); 
			for (i=2;i<=NF;i++) {
				vhost[x] = $i;x++ 
			} 
		}; 
		END{
			if ( want==1 ) {
				for(i=0;i<x;i++){
					gsub(/:.*/,"",vhost[i])
					print vhost[i] " "
				}
			}
		}' $cfg`
		
		checkVIPs $VIPS
		SERVERNAMES=`grep -i servername $cfg | awk '{print $2}'`
		for server in $SERVERNAMES; do 
			$checkURL $SITE http://$server/site.txt $3 
		done
		for vip in $VIPS; do
			plex=`echo $vip | awk -F'.' '{print $3}'`
			case $plex  in
				26) plex=p1;;
				34) plex=p2;;
				42) plex=p3;;
				*) plex=Unknown;;
			esac
			server=`echo $server | awk -F':' '{print $1}'`
			$checkURL ${server}_${plex}_vhost:$vip http://$vip/site.txt $3
		done
	done

}

check_url() {

  if [[ $# -eq 0 ]]; then
  	  getRoles
  	  getPlex
  else 
  	  ROLES=$1 
  	  SITE=$2
  fi
  for R in $ROLES; do
    typeset -l ROLE=$R
    if [[ "$ROLE" = "webserver"* ]]; then
        /lfs/system/tools/was/bin/hcls -r $ROLE |grep -i instances  > /tmp/.chk_ihs_${USER}.tmp
        if [[ -s /tmp/.chk_ihs_${USER}.tmp ]]; then
          while read -r INSTANCES
          do
            FIRST=`echo ${INSTANCES}|cut -d "=" -f2|awk -F "@@" '{print $1}'`
            SECOND=`echo ${INSTANCES}|awk -F "@@" '{print $2}'`
            THIRD=`echo ${INSTANCES}|awk -F "@@" '{print $3}'`
                if [[ `echo $FIRST | cut -c1-6` = 'hc_was' ]]; then
                        WAS_R_APP=$FIRST
                        WAS_R=`echo ${WAS_R_APP}|awk -F "_" '{print $2}'`
                        APP=`echo ${WAS_R_APP}| cut -d '_' -f3-`
                        HCNAME=$SECOND
                        VURL=$THIRD
                    if [[ `echo $THIRD | cut -c1-5` = '$plex' ]]; then
                        typeset -l RLM=$PLEX
                        VURL=`echo "${THIRD}"|sed -e s/'$plex'/${RLM}/`
                        VURL0=`echo "${THIRD}"|sed -e s/'$plex.'//`
                    fi
                   rm -rf /tmp/.chk_was_${USER}.tmp
                   /lfs/system/tools/was/bin/hcls -r "${WAS_R}" -a "${APP}" | grep -i instances | cut -d "=" -f2 > /tmp/.chk_was_${USER}.tmp
                  if [[ -s /tmp/.chk_was_${USER}.tmp ]]; then
                     while read -r WAS_STRING
                     do
                  WAS_HCURL=`echo "${WAS_STRING}"|awk -F "@@" '{print $2}'`
                  WAS_PASS=`echo "${WAS_STRING}"|awk -F "@@" '{print $3}'`
                  WAS_CHKDELAY=`echo "${WAS_STRING}"|awk -F "@@" '{print $4}'`
                  HTTP=`echo "$WAS_STRING" | awk -F "//" '{print $1}'`
                  WAS_S=`echo "${WAS_HCURL}" | awk -F "//" '{print $2}'`
                                    REPLACE=`echo "$WAS_S" | awk -F "/" '{print $1}'`
                  IHS_URL=`echo "$WAS_HCURL" | sed -e "s/$REPLACE/$VURL/"`
                  export WAS_CHKDELAY
                    if [[ -n $VURL0 ]]; then
                        IHS_URL0=`echo $WAS_HCURL | sed -e "s/$REPLACE/$VURL0/"`
                        $checkURL "${HCNAME}" "${IHS_URL0}" "$WAS_PASS"
                        $checkURL "${HCNAME}_${RLM}" "${IHS_URL}" "$WAS_PASS"
                    else
                        $checkURL "${HCNAME}" "${IHS_URL}" "$WAS_PASS"
                    fi
                    done < /tmp/.chk_was_${USER}.tmp
                   fi
                  unset WAS_CHKDELAY
                else
                        SITE=$FIRST
                        SURL=$SECOND
                        PASS=$THIRD
                $checkURL "${SITE}" ${SURL} "${PASS}"
              fi
          done < /tmp/.chk_ihs_${USER}.tmp
        fi
        rm -rf /tmp/.chk_ihs_${USER}.tmp
        rm -rf /tmp/.chk_was_${USER}.tmp
    fi
  done
}

funcs=/lfs/system/tools/ihs/lib/ihs_functions.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

checkURL=/lfs/system/tools/ihs/bin/chk_url.pm
ARGS=$*
#Call various functions defined in lib/ihs_functions.sh
checkIHS
checkConf
date "+%T Checking ei-stats over a 7 second interval"
/lfs/system/tools/ihs/bin/check_eistats.pm
funcs=/lfs/system/tools/configtools/lib/check_functions.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

if [ $# -eq 0 ]; then
	check_url
else
	echo $ARGS | grep -i allisone > /dev/null
	if [ $? -eq 0 ]; then
	ARGS="ausopen masters tonys wimbledon usopen jam"
	fi

SITES=""
for SITE in $ARGS ; do
        typeset -l SITE
	case $SITE in
		allisone)
			SITES="$SITES ausopen masters tonys wimbledon usopen cmusga" ;;
		*events.origin*)
			SITES="$SITES ausopen masters rolandgarros tonys wimbledon usopen cmusga" ;;
		*webserver.ice.qa20)
			SITES="$SITES ic20st" ;;
                *webserver.ice.qa)
			SITES="$SITES ic15st ic15pv" ;;
                *cluster*)
                        ;;
                *)
                        SITES="$SITES $SITE"

	esac

done
ARGS=$SITES
even_odd="even"
date "+%T Checking IHS response for: $ARGS"
for SITE in $ARGS ; do
	typeset -l SITE
	case $SITE in 
		espong|*spong*)
	           ROLE='webserver.spong.ei'
			;;	
		ibmstg|*wwwstage*)
		   ROLE='webserver.ibm.wwwstage'
                        ;;
		ibmtst|*wwwtest*)
                   #$checkURL $SITE http://wwwtest.ibm.com/Admin/whichnode [a-z]
			;;
		*yzprdcl001|webserver.ibm.origin|www.ibm.com|ibmprd|ibm)
		        checkVIPs 129.42.26.212 129.42.34.212 129.42.42.212 
		   ROLE='webserver.ibm.origin'
			;;
		ibmsearch)
			#$checkURL $SITE http://localhost:3333/site.txt www.ibm.com 
			;;
		*ausopen*|cmauso*)
			validate_vhosts australianopen cmauso-${even_odd} $even_odd
			;;	
		*masters*|cmmast*)
			validate_vhosts masters cmmast-${even_odd} $even_odd
			;;
		*rolandgarros*|cmrolg*)
			validate_vhosts rolandgarros cmrolg-${even_odd} $even_odd
			;;	
		*tonys*|cmrtony*)
			validate_vhosts tony cmtony-${even_odd} $even_odd
			;;	
		*usopen*|cmrusop*)
			validate_vhosts usopen cmusga-${even_odd} $even_odd
			;;
		*usga*)
			validate_vhosts usopen cmusta-${even_odd} $even_odd
			;;																	
		*wimbledon*|cmwimb*)
			validate_vhosts wimbledon cmwimb-${even_odd} $even_odd
			;;				
		*jam*|www.collaborationjam.com)
			validate_vhosts $SITE cmjams-${even_odd} $even_odd
			;;
		*esc*|www-930.ibm.com)
		   ROLE='webserver.esc'
			;;
		w3ei|w3.event.ibm.com|*portal.bz*)
		   ROLE='webserver.ei.portal'
			;;	
		*enetmap*)
		   ROLE='webserver.ei.enetmap'
			;;	
		iceprd|ic15pd)
		   ROLE='webserver.ice.qa20'
			;;
                webserver.ice)
		   ROLE='webserver.ice'
                        ;;
                webserver.ice.cdt)
		   ROLE='webserver.ice.cdt'
#echo "it jump here"
                        ;;
                webserver.ice.spp)
		   ROLE='webserver.ice.spp'
                        ;;
                webserver.ice.pre)
                        ;;
		ic15pv|icepreview|wwwpreview-935.events.ibm.com)
			#$checkURL ${SITE} http://wwwpreview20-935.events.ibm.com/services/healthcheck20.wss/status 'Database connection is available:\r\n <b>true'
			;;
		ic15st|icestage|wwwstage-935.events.ibm.com)
			#$checkURL ${SITE} http://wwwstage20-935.events.ibm.com/services/healthcheck20.wss/status 'Database connection is available:\r\n <b>true'
			;;
		ic20st|wwwstage-935.events.ibm.com)
			#$checkURL ${SITE} http://wwwstage20-935.events.ibm.com/services/healthcheck20.wss/status 'Database connection is available:\r\n <b>true'
			;;	
		portal|ei.events.ihost.com|*ei.portal)
			#$checkURL ${SITE} http://localhost/site.txt 'ei.events.ihost.com'
			;;	
		bzportal|w3.events.ibm.com|*portal.bz)
			#$checkURL ${SITE} http://localhost/site.txt 'Global'
			#$checkURL ${SITE}_w3ei http://w3.ei.event.ibm.com/site.txt 'w3ei'
			;;
		ibmpxy|*ibm.proxy)
			checkVIPs 129.42.26.215 129.42.34.215 129.42.42.215
		   ROLE='webserver.ibm.proxy'
			;;
		srprex|webserver.srm.yz)
		### removed srm
			;;
		webserver.stg.prd|isprod)
			checkVIPs 129.42.26.224 129.42.34.224 129.42.42.224
		   ROLE='webserver.stg.prd'
			;;
		webserver.xsr.prd|xsprod)
			checkVIPs 129.42.26.227 129.42.34.227 129.42.42.227
		   ROLE='webserver.xsr.prd'
			;;
		webserver.xsr.spp|xsspp)
			checkVIPs NO_SPP_IN_PLEX1 10.111.114.216 10.111.178.216
		   ROLE='webserver.xsr.spp'
			;;
		webserver.xsr.pre|xspprd)
			checkVIPs NO_PRE_IN_PLEX1 NO_PRE_IN_PLEX2 9.17.254.135
		   ROLE='webserver.xsr.pre'
			;;
		*webserver*|localhost)
			$checkURL site.txt http://localhost/site.txt [a-z] ;;	
		*)
			print -u2 -- "#### Update $0 to recognize $SITE" ;;
	esac
#echo "this is outside of case"
		check_url $ROLE $SITE
done

echo "###### $0 Done"

fi
