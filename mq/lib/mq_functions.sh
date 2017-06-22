#!/bin/ksh


checkQmgrs() {
        date "+%T Checking Qmgrs"
        QMGR=$1
        OUT=/tmp/dspmq.out
        dspmq -m $QMGR > $OUT
		set -- $(cat $OUT)
			RC=0
			while [[ "$1" != "" ]]; do
				if [[ "$1" = QMNAME\(*\) ]]; then
					QMGR=`echo $1 | cut -d\( -f2 | cut -d\) -f1`
				elif [[ "$1" = STATUS\(*\) ]]; then
					STATUS=`echo $1 | cut -d\( -f2 | cut -d\) -f1`
					if echo $1 | grep  -i RUNNING > /dev/null ; then
						echo "dspmq command shows the status of QMGR $QMGR as: $STATUS"
					else
						print -u2 -- "########## Qmgr $QMGR is not running - status is: $STATUS"
						RC=1
					fi
				fi
				shift
			done
 			return $RC
}


checkMQlistener() {
        date "+%T Checking MQ Listener"
        QMGR=$1
        ps -f -u mqm | grep runmqlsr | grep $QMGR
        if [ $? -ne 0 ]; then
                print -u2 -- "########## MQ Listener (runmqlsr) is not running"
                return 1
        fi
}

checkMQchannel() {
        date "+%T Checking MQ channels"
        QMGR=$1
        CMD=/tmp/dis_chstatus.cmd
        OUT=/tmp/dis_chstatus.out
        echo "dis chstatus(*)" > $CMD
        echo "end"	>> $CMD

		chown mqm $CMD $OUT
        chmod a+rw $CMD $OUT
		
       	su - mqm -c "runmqsc $QMGR < $CMD" > $OUT 
        grep 'Channel Status not found' $OUT > /dev/null
        if [ $? -eq 0 ]; then
        	echo "No channels active for QMGR $QMGR which is normal during periods of low activity"
        	return 0
        fi
        
		set -- $(cat $OUT)
		RC=0
		while [[ "$1" != "" ]]; do
			if [[ "$1" = CHANNEL\(*\) ]]; then
				CHANNEL=`echo $1 | cut -d\( -f2 | cut -d\) -f1`
			elif [[ "$1" = 	CONNAME\(*\) ]]; then
				CONNAME=`echo $1 | cut -d\( -f2 | cut -d\) -f1`
			elif [[ "$1" = STATUS\(*\) ]]; then
				STATUS=`echo $1 | cut -d\( -f2 | cut -d\) -f1`
				if echo $1 | grep RUNNING > /dev/null ; then
					echo "dis chstatus(*) shows the status of channel $CHANNEL connected with $CONNAME as: $STATUS"
				else
					print -u2 -- "########## Channel $CHANNEL connected with $CONNAME is not running: $STATUS"
					RC=1
				fi
			fi
			shift
		done
 		return $RC
}

checkQdepth() {
        date "+%T Checking Q Depth"
        QMGR=$1
        CMD=/tmp/dis_curdepth.cmd
        OUT=/tmp/dis_curdepth.out
        echo "dis ql(*) USAGE WHERE(curdepth gt 0)" > $CMD
        echo "end"	>> $CMD

		chown mqm $CMD $OUT
        chmod a+rw $CMD $OUT
       	su - mqm -c "runmqsc $QMGR < $CMD" > $OUT 
        
		set -- $(cat $OUT)
		RC=0
		while [[ "$1" != "" ]]; do
			if [[ "$1" = QUEUE\(*\) ]]; then
				QUEUE=`echo $1 | cut -d\( -f2 | cut -d\) -f1`
			elif [[ "$1" = 	CURDEPTH\(*\) ]]; then
				DEPTH=`echo $1 | cut -d\( -f2 | cut -d\) -f1`
				#Ignore Q depth on SYSTEM queues except for SYSTEM.DEAD.LETTER.QUEUE
				echo $QUEUE | grep -vi SYSTEM > /dev/null
				if [ $? -eq 0 ]; then
					echo "$QUEUE CURDEPTH($DEPTH)"
					print -u2 -- "########## Queue $QUEUE shows a CURDEPTH value of: $DEPTH"
					RC=1
				fi
				echo $QUEUE | grep -i SYSTEM.DEAD.LETTER.QUEUE > /dev/null
				if [ $? -eq 0 ]; then
					echo "$QUEUE CURDEPTH($DEPTH)"
					print -u2 -- "########## Queue $QUEUE shows a CURDEPTH value of: $DEPTH"
					RC=1
				fi
			fi
			shift
		done
		if [ $RC -ne 1 ]; then
			echo "Depth values are OK"
		fi
 		return $RC
}

