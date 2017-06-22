#!/usr/bin/env bash
LFSTOOLS=/lfs/system/tools
TFIMBIN=${LFSTOOLS}/tfim/bin
TFIMWS=${TFIMBIN}/listpartners.py
#TFIMWS=/fs/home/mgjoni/listpartners.py
ARGS=$*
PREDMGR=g1pre70wi
PRDDMGR=g1prd85edsso
WASROOT=/usr/WebSphere85/AppServer
PARTNEROUTCMD="${WSADMIN} ${TFIMWS} ${ARGS}"
debug=0
PLEX=${plex:-"P1 P3 P5"}

if [ -d ${WASROOT}/profiles/${PREDMGR}Manager ];
then 
	echo
    	if [ $debug -eq 1 ]; then echo "PreProd"; fi
        ${TFIMWS}  ${WASROOT}/profiles/${PREDMGR}Manager/config/itfim/W3_IDP/etc/feds.xml $ARGS
elif [ -d ${WASROOT}/profiles/${PRDDMGR}Manager ];
then
	echo
    	if [ $debug -eq 1 ]; then echo "Prod"; fi
        #su - webinst -c "${PARTNEROUTCMD}" |grep -v WASX |sort
        for D in $PLEX; do
        echo $D
        ${TFIMWS}  ${WASROOT}/profiles/${PRDDMGR}Manager/config/itfim/W3_IDP_${D}/etc/feds.xml $ARGS
        echo 
        done
else
	echo
	echo "You are not on the correct server methinks."
	echo "Pre: ${PREDMGR}"
	echo "Prd: ${PRDDMGR}"
	echo
fi

