#!/bin/ksh
#Check the health of DB2
#Usage:
#         check_db2.sh [list of databases]
#Example: check_db2.sh netpoll guestbook
#All errors messages begin the line with "###"
#To look for just errors, run:  check_db2.sh | grep \#

ARGS=$*
funcs=/lfs/system/tools/db2/lib/db2_functions.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

funcs=/lfs/system/tools/configtools/lib/check_functions.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

ENV=`getEnv`

if [ $# -eq 0 ]; then
	#no args passed, lets look for DB2 related roles
	getRoles
	for ROLE in $ROLES; do
		typeset -l ROLE
		if [[ "$ROLE" = "database"* ]]; then 
			ARGS="$ARGS $ROLE"
		fi
	done
fi

#may need to do some expansion first
case $ARGS in
	*ibm.prodgz*)
		ARGS="ied homepage rtp osi onex sandbox lpost" ;;
	allisone|*events.yz*)
		 ARGS="eipatron epatron guestbook netpoll" ;;
	*events*|*jams*)
		 ;;
	*ice*)
		;;
	*cnp*)
		ARGS="wps" ;;
	*stg*)
		ARGS="wps stgiepdb stgsssdb" ;;
	*spe*)
		ARGS="spe gcs wps scsi";;
esac

for DB in $ARGS ; do
	typeset -l DB
	case $DB in 			
		guestbook)
			checkReplicationDB2 $DB cap[t]ure_server=gbook ap[p]ly_qual=GBOOKAQ ;;
		netpoll)
			checkReplicationDB2 $DB cap[t]ure_server=netpoll ap[p]ly_qual=NETPOLLAQ ;;
		epatron)
			checkReplicationDB2 $DB cap[t]ure_server=epatron ap[p]ly_qual=EPATRONAQ ;;
		eipatron)
			checkReplicationDB2 $DB cap[t]ure_server=eipatron ap[p]ly_qual=EIPATRONAQ ;; 
		*jam*)
			checkReplicationDB2 $DB cap[t]ure_server=lillyjam ap[p]ly_qual=LILLYJAMAQ
			checkReplicationDB2 $DB cap[t]ure_server=innovjam ap[p]ly_qual=INNOVJAMAQ 
			checkReplicationDB2 $DB cap[t]ure_server=nokiaway ap[p]ly_qual=NOKIAWAYAQ
			checkReplicationDB2 $DB cap[t]ure_server=connact ap[p]ly_qual=CONNACTAQ
			checkReplicationDB2 $DB cap[t]ure_server=nsnjam ap[p]ly_qual=NSNJAMAQ
			checkReplicationDB2 $DB cap[t]ure_server=innovph2 ap[p]ly_qual=INNOVPH2AQ			
			;;
		sandbox)
			checkReplicationDB2 $DB cap[t]ure_server=sandbox ap[p]ly_qual=SANDBOXAQ ;;
		wps|portal)
			checkReplicationDB2 $DB cap[t]ure_server=wpsdb none 
			checkReplicationDB2 $DB none ap[p]ly_qual=CUSTAQ
			checkReplicationDB2 $DB none ap[p]ly_qual=COMMAQ
			;;
		ied|employee|iedibmdb)
			case $ENV in
				ei)	checkReplicationDB2 $DB cap[t]ure_server=ied ap[p]ly_qual=IEDAQ ;;
				st) echo "no replication in staging for $DB" ;;
			esac ;;	
		homepage|hpp|hppibmdb|intarea)
			case $ENV in 
				ei)	checkReplicationDB2 $DB cap[t]ure_server=intarea ap[p]ly_qual=INTAREAAQ ;;
				st) echo "no replication in staging for $DB" ;;
			esac ;;
		rtp|ratethispage)
			checkReplicationDB2 $DB cap[t]ure_server=rtp ap[p]ly_qual=RTPAQ ;;
		osi|osam|am|osientdb)
			case $ENV in
				ei) checkReplicationDB2 $DB cap[t]ure_server=am ap[p]ly_qual=AMAQ ;;
				st) echo "no replication in staging for $DB" ;;
			esac 
			;;
		lpost|lstnpost)
			checkReplicationDB2 $DB cap[t]ure_server=lstnpost ap[p]ly_qual=GBOOKAQ ;;
		rtpibmdb|rtpibmrp|rtp)
			checkReplicationDB2 RTP cap[t]ure_server=rtp ap[p]ly_qual=RTPAQ
			checkReplicationDB2 LSTNPOST cap[t]ure_server=lstnpost ap[p]ly_qual=LSTNPOSTAQ ;;
		onex|onxqmgdb|onxqmgrp)
				case $ENV in 
					ei) checkReplicationDB2 $DB none ap[p]ly_qual=AMAQ ;;
					st) checkReplicationDB2 $DB cap[t]ure_server=onex none ;;
					*) print -u2 -- "#### Update $0 to recognize the $ENV environment" ;;
				esac
				;;
		smartspot|smrtspot|scribmdb)
			checkReplicationDB2 RTP cap[t]ure_server=smrtspot none ;;
		spe)
		  case $ENV in
			 ci) checkReplicationDB2 $DB cap[t]ure_server=spe ap[p]ly_qual=SPEAQ ;;
			 cs) checkReplicationDB2 $DB cap[t]ure_server=spe ap[p]ly_qual=SPEAQ
				  checkReplicationDB2 $DB none ap[p]ly_qual=PULLSPE ;;
			 esac
			 ;;
		gcs)
			case $ENV in
				ci) checkReplicationDB2 $DB cap[t]ure_server=gcs none ;;
				cs) checkReplicationDB2 $DB none ap[p]ly_qual=PULLGCS ;;
         esac
			;;
		scsi)
			checkReplicationDB2 $DB cap[t]ure_server=scsi ap[p]ly_qual=SCSIAQ ;;
		stgiepdb|iepdr4|iepd) 
			checkReplicationDB2 IEPDR4 cap[t]ure_server=iepdr4  ap[p]ly_qual=IEPDAQ ;;
		stgsssdb|syssupt)
			checkReplicationDB2 SYSSUPT cap[t]ure_server=syssupt  ap[p]ly_qual=PULLSPPP ;;
		*xsr*)
			checkReplicationDB2 SYSSUPT cap[t]ure_server=xsr  ap[p]ly_qual=XSRAQ ;;
		*)
			print -u2 -- "#### Update $0 to recognize $DB" ;;
		
	esac
done	

date "+%T ###### $0 Done"
