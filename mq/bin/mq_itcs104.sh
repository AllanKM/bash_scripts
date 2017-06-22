#!/bin/ksh


###################################################################################################
# #mqm should be defined so that it does not have a password, and access can only be through sudo su
#
###################################################################################################
checkPasswd() {
    echo "Checking to see if mqm has a password set."
    os=`uname`
    case $os in
		  AIX) chk=`grep mqm /etc/security/passwd`
				 if [[ "$chk" != "" ]] ; then
					  echo "==> Failed, Violation ! Section 2.1 Resuable pwd chk....mqm on $hostname has a password set <=="
					  return 1
				else
	    	   		echo "Passed"
		   			return 0
            fi
            ;;
			Linux) chk=`grep mqm /etc/shadow |awk -F: '{print $2}'`
				if [[ "$chk" != "!!" ]] ; then
					  echo "==> Failed, Violation ! Section 2.1 Resuable pwd chk....mqm on $hostname has a password set <=="
					  return 1
				  else
						echo "Passed"
						return 0
 				fi
				;;
    esac
    if [[ "$chk" != "" ]] ; then
        echo "==> Failed, Violation ! Section 2.1 Resuable pwd chk....mqm on $hostname has a password set <=="
        return 1
    else
        echo "Passed"
        return 0
    fi
    
}
###################################################################################################
#
#check if queue manager is available to perform checking
#
###################################################################################################
checkQMGR() {
    QMGR=$1
    OUT=/tmp/dis_channel.OUT

    status=1 #1-available 0-not available
    su - mqm -c "dmpmqaut -m $QMGR -t qmgr 2>&1" > $OUT
    chown mqm $OUT
    chmod a+r $OUT
        
    if cat $OUT |grep -i queue\ manager |grep -i not\ available > /dev/null ; then
        status=0
        echo "###Queue Manager $QMGR is not available###"
    fi
    
    return $status
}

###################################################################################################
#
# SYSTEM.DEF.SVRCONN,SYSTEM.DEF.RECEIVER, and SYSTEM.DEF.REQUESTER
# To ensure that these sample channels cannot be used, set MCAUSER to 
# an invalid userid or one that has no authority. On Unix, set MCAUSER to nobody.
#
###################################################################################################
checkSYSTEMDEF() {
    QMGR=$1
    CMD=/tmp/dis_channel.cmd
    OUT=/tmp/dis_channel.out
    echo "dis channel(SYSTEM.DEF.SVRCONN) mcauser" > $CMD
    echo "dis channel(SYSTEM.DEF.RECEIVER) mcauser" >> $CMD
    echo "dis channel(SYSTEM.DEF.REQUESTER) mcauser" >> $CMD
    echo "end"      >> $CMD

    su - mqm -c "runmqsc $QMGR < $CMD" > $OUT   
    chown mqm $CMD $OUT
    chmod a+r $CMD $OUT
    
    start=0
    while read -r result
    do
        if echo $result |grep -i WebSphere\ MQ\ object |grep -i not\ found > /dev/null ; then
            echo $result
            continue
        fi
        if echo $result |grep -i Display\ Channel\ details > /dev/null ; then
            start=1
            channel=""                        
        fi
        if [[ $start == 0 ]] ; then
            continue
        fi
        if echo $result |grep -i channel\( > /dev/null ; then
            channel=`echo $result |cut -f2 -d\(|cut -f1 -d\)`
            continue
        fi
        if echo $result |grep -i mcauser\( > /dev/null ; then
            mcauser=`echo $result |cut -f2 -d\(|cut -f1 -d\)`
            if [[ $mcauser != "NOBODY" ]] ; then
                echo "==> Failed, Violation ! Channel $channel is not configured with MCAUSER: NOBODY <=="
                status=1
                return 1
            else
                echo "Passed"
                return 0
            fi
        fi    
    done < $OUT    
}

####################################################################################################
#
#If SSL is set then it should be:  RC4_SHA_US, or TRIPLE_DES_SHA_US  or TLS_RSA_WITH_AES_128_CBC_SHA  
#
#If SSL is not set -> ITCS104 conform
#IF SSL is set with none of the above -> violation
#If SSL is set with the above -> ITCS104 conform
#
#If violation then display: "violation: Channel $Channel has SSLCIPH $SSLCIPH configured. Check if this is ITCS104 standard"
#If ITCS104 conform, then dispaly "Type of SSLCIPH of channels are ITCS104 conform"
#
####################################################################################################
checkTrans() {
    QMGR=$1
    CMD=/tmp/dis_chl.cmd    
    OUT=/tmp/dis_chl.out
    echo "dis chl(*) sslciph" > $CMD
    echo "end" >> $CMD
    
    su - mqm -c "runmqsc $QMGR < $CMD 2>&1" > $OUT
    chown mqm $CMD $OUT
    chmod a+r $CMD $OUT

    
    start=0
    status=0
    while read -r result
    do
        if echo $result |grep -i Display\ Channel\ details > /dev/null ; then
            start=1
            channel=""
            sslciph=""                        
        fi
        if [[ $start == 0 ]] ; then
            continue
        fi
        if echo $result |grep -i channel\( > /dev/null ; then
            channel=`echo $result |cut -f2 -d\(|cut -f1 -d\)`
            continue
        fi
        if echo $result |grep -i sslciph\( > /dev/null ; then
            sslciph=`echo $result |cut -f2 -d\(|cut -f1 -d\)`
            if [[ $sslciph != " " && $sslciph != "RC4_SHA_US" && $sslciph != "TRIPLE_DES_SHA_US" && $sslciph != "TLS_RSA_WITH_AES_128_CBC_SHA" && $sslciph != "TLS_RSA_WITH_DES_CBC_SHA" ]] ; then
                 echo "==>Failed, Violation ! Check if SSLCIPH $sslciph of channel $channel is ITCS104 standard <=="
                 status=1
                 return 1
            fi
        fi
    done < $OUT

    if [[ $status == 0 ]] ; then
        echo "Passed"
        return 0
    fi
}

###################################################################################################
#
#qm.ini Must not be edited to disable the OAM.
#
###################################################################################################
checkOAM() {
    QMGR=$1
    OUT=/var/mqm/qmgrs/$1/qm.ini
 
    #if grep OAM $OUT > /dev/null ; then
    #    echo "==> Violation: OAM of Qmgr is not conform to ITCS104 security standars <=="
    #else
    #    echo "OAM is enabled conform to ITCS104 standards "
    #fi
    if grep Name=AuthorizationService $OUT > /dev/null ; then
        echo "Passed "
        return 0
    else
        print -u2 -- "==>Failed, Violation ! Check OAM configuration of Qmgr in qm.ini <=="
        return 1
    fi
}

###################################################################################################
#
#if others has no permission -> ITCS104 conform. 
#if no files is there -> display "no keyrings..." soemthing like that
#if others has permission -> violation
#
#
#If violation, then display:"Violation: permission of others of keyring needs to be remvoed "
#If ITCS104 conform then display: "Keyrings of Qmgr are conform ITCS104"
#
###################################################################################################
checkSSLcert() {
    QMGR=$1
    SSLDir=/var/mqm/qmgrs/$1/ssl
    SSLFileNo=`find $SSLDir \( -type b -o -type c -o -type f -o -type l \) |wc -l |tr -s ' '|cut -c 2-2`
    if [[ $SSLFileNo == "0" ]] ; then
        echo "### Keyring for Qmgr $1 not found"
        return 0
    fi
    ls -ld $SSLDir
    for SSLFile in `find $SSLDir \( -type b -o -type c -o -type f -o -type l \)` ; do
        #if echo $SSLFile |cut -c ${#SSLDir}- |cut -c 3- |grep / > /dev/null ; then 
        ##ignore the sub-folder files
        #    continue
        #fi  
        if [[ $(find $SSLFile \( -perm -001 -o -perm -002 -o -perm -004 \)) != "" ]] ; then
            echo "==>Failed, Violation ! Permission of *others* of keyring $SSLFile needs to be removed <=="
            return 1
        else
            echo "Passed" 
            return 0
        fi
    done

#    SSLFileNo=`find $SSLDir \( -type b -o -type c -o -type f -o -type l \) \( -perm -001 -o -perm -002 -o -perm -004 \) | wc -l|tr -s ' ' |cut -c 2-2`
#    if echo $SSLFileNo |grep 0 > /dev/null; then
#        echo "Keyrings of Qmgr $1 are conform to ITCS104 standards"
#    else
#        for SSLFile in `find $SSLDir \( -type b -o -type c -o -type f -o -type l \) \( -perm  -001 -o -perm -002 -o -perm -004 \)`; do    
#            echo "==> Violation: permission of *others* of keyring $SSLFile needs to be removed <=="
#        done
#    fi 
}

checkCLIENTSSLcert() {
    SSLDir=/var/mqm/ssl/keys
    if ! [[ -d ${SSLDir} ]] ; then
        echo "### ${SSLDir} does not exist"
        return 0
    fi    
    
    SSLFileNo=`find $SSLDir \( -type b -o -type c -o -type f -o -type l \) |wc -l |tr -s ' '|cut -c 2-2`
    if [[ $SSLFileNo == "0" ]] ; then
        echo "### Keyring not found"
        return 0
    fi
    for SSLFile in `find $SSLDir \( -type b -o -type c -o -type f -o -type l \)` ; do
        if [[ $(find $SSLFile \( -perm -001 -o -perm -002 -o -perm -004 \)) != "" ]] ; then
            echo "==>Failed, Violation ! Permission of *others* of keyring $SSLFile needs to be removed <=="
            return 1
        else
            echo "Passed"
            return 0
        fi
    done
}

###################################################################################################
#
#search output for any other entity then mqm.
#
#If there is no stanza with any other entity then mqm -> conform ITCS104 standard
#If there is a stanza with any other entity then mqm -> viloation: 
#
#If violation, then display stanza and Violation: Revoke above permissions of SYSTEM.MQEXPLORER.REPLY.MODEL queue?
#If ITCS104 conform display: "SYSTEM.MQEXPLORER.REPLY.MODEL queue is conform ITCS104"
#
###################################################################################################

checkMQEXPLORER() {
    QMGR=$1
    OUT=/tmp/dmpmqaut.out
    su - mqm -c "dmpmqaut -m $QMGR -n SYSTEM.MQEXPLORER.REPLY.MODEL 2>&1" > $OUT
    chown mqm $OUT
    chmod a+r $OUT
    
    status=0
    stanza=""
    start=0
    while read -r result
    do
        if echo $result |grep -i No\ matching\ authority\ records > /dev/null ; then
            echo "###Queue SYSTEM.MQEXPLORER.REPLY.MODEL not found"
            return 0
        fi
   
        if  echo $result |grep -i profile: > /dev/null ; then
            start=1
            violation=0
            stanza=""
        fi 

        if [[ $start == 0 ]] ; then
            continue
        fi
        
        stanza="$stanza""\n"$result 

        if echo $result |grep -i entity: | grep -i -v mqm > /dev/null ; then
            userid=`echo $result |cut -c 9-|tr -s ' '`
            checkApprList 'checkMQEXPLORER' $userid
            if [[ $userchk == 1 ]]; then
                violation=1
                status=1
            fi
        fi
 
        if [[ $violation == 1 ]] && echo $result |grep -i authority: > /dev/null ; then
            echo $stanza
            echo "==>Failed, Violation ! Check valid business need of above permission of SYSTEM.MQEXPLORER.REPLY.MODEL queue <=="
           return 1    
       fi

    done < $OUT

    if [[ $status == 0 ]]; then
        echo "Passed"
        return 0 
    fi
}

###################################################################################################
#
#check output for any stanza with enitity other then mqm that has authority: altusr  
#If other enitiy then mqm has permission (authorization) altusr -> violation. 
#
#If violation, then display the stanza and "violation: Revoke altusr authorization of userID $USERID from QMGR?
#If ITCS104 conform display: "QMGR authorization is conform ITCS104"
#
###################################################################################################

checkaltusr() {
    QMGR=$1
    OUT=/tmp/dmpmqaut.out

    su - mqm -c "dmpmqaut -m $QMGR -t qmgr 2>&1" > $OUT    
    chown mqm $OUT
    chmod a+r $OUT
        
    isWBIMBnode=0 
    if lssys -n |grep WBIMB.EVENTS.MANAGER > /dev/null ; then
        isWBIMBnode=1
    fi
    
    status=0
    userid=""
    userchk=0
    while read -r result
    do
        if  echo $result |grep -i profile: > /dev/null ; then
            start=1
            userchk=0
        fi

        if [[ $start == 0 ]] ; then
            continue
        fi
        
#        if [[ $isWBIMBnode == 1 ]] ; then        
#        #for WBIMB.EVENTS.MANAGER node, pass eiadm check -- Tiger Wu 20090522
#            if echo $result |grep -i entity: | grep -i -Ev "mqm|mqbrkrs|eiadm" > /dev/null ; then
#                userid=`echo $result |cut -c 9-`
#                userchk=1
#                continue
#            fi
#        else
            if echo $result |grep -i entity: | grep -i -Ev "mqm|mqbrkrs" > /dev/null ; then
                userid=`echo $result |cut -c 9-`
                checkApprList 'checkaltusr' $userid
                continue
            fi        
#        fi

        if [[ $userchk == 1 ]] && echo $result |grep -i authority:|grep -i altusr > /dev/null ; then
            echo "==>Failed, Violation ! Check valid business need of authorization altusr of group $userid <=="
            status=1
            return 1
        fi
    done < $OUT

    if [[ $status == 0 ]]; then
        echo "Passed"
        return 0
    fi    
}

###################################################################################################
#
#if the MCAUSER is set to mqm or any other userID and SSLCIPH is set -> ITCS104 conform 
#IF MCAUSER is not set and SSLCIPH is set -> ITCS104 conform 
#IF MCAUSER is not set and SSLCIPH is not set -> ITCS104 conform 
#If MCAUSER is set to mqm or any other userID and SSLCIPH is not set -> violation
#
#If violation then display soemthing like: MCAUSER of SVRCONN Channel $CHANNEL is set to $MCAUSER
#If ITCS104 conform display: "SVRCONN channel $CHANNEL are conform ITCS104"
#ignore SYSTEM.DEF.SVRCONN SYSTEM.AUTO.SVRCONN SYSTEM.ADMIN.SVRCONN as they will be checked by other functions
#
###################################################################################################

checkSVRCONN() {
    QMGR=$1
    CMD=/tmp/dis_channel.cmd
    OUT=/tmp/dis_channel.out
    echo "dis channel(*) chltype(SVRCONN) sslciph mcauser" > $CMD
    echo "end"      >> $CMD

    su - mqm -c "runmqsc $QMGR < $CMD 2>&1" > $OUT
    chown mqm $CMD $OUT
    chmod a+r $CMD $OUT

    mcauserset=0
    sslciphset=0
    start=0
    chlcnt=0
    extchls=""
    while read -r result
    do
        if echo $result |grep -i display\ channel\ details > /dev/null ; then
            if [[ $mcauserset == 1 && $sslciphset == 0 ]] ; then
                echo "==> Failed, Violation ! Check: MCAUSER of SVRCONN Channel $channel is set to $mcauser <=="
                return 1
            else
                if [[ $start != 0 ]] ; then
                    echo "Passed"
                    return 0
                fi
            fi
            mcauserset=0
            sslciphset=0
            mcauser=""
            channel=""
            start=1
            continue
        fi
        if echo $result |grep CHANNEL\( > /dev/null ; then
            channel=`echo $result |cut -f2 -d \( |cut -f1 -d \)`
            if [[ $channel == "SYSTEM.DEF.SVRCONN" || $channel == "SYSTEM.AUTO.SVRCONN" || $channel == "SYSTEM.ADMIN.SVRCONN" ]] ; then
                start=0  #ignore SYSTEM.DEF.SVRCONN SYSTEM.AUTO.SVRCONN SYSTEM.ADMIN.SVRCONN as they will be checked by other functions
                extchls="$extchls"","$channel
            else
                chlcnt=1  
            fi
            continue
        fi
        if [[ $start == 0 ]] ; then
            continue
        fi

        if echo $result |grep MCAUSER\( |grep SSLCIPH\( > /dev/null ; then
            if echo $result |grep -i MCAUSER\(\ \) > /dev/null ; then
                mcauserset=0
            else
                mcauserset=1
            fi
            if echo $result |grep SSLCIPH\(\ \) > /dev/null ; then
                sslciphset=0
            else
                sslciphset=1
            fi
            mcauser=`echo $result |cut -f2 -d \( |cut -f1 -d \)`
            sslciph=`echo $result |cut -f3 -d \( |cut -f1 -d \)`
        fi
    done < $OUT
    if [[ $chlcnt == 0 ]] ; then
        if [[ $extchls == "" ]] ; then
            echo "###SVRCONN channels not found"
        else
            extchls=`echo $extchls |cut -c 2-`
            echo "###SVRCONN channels not found except $extchls"
        fi
        return 0
    fi
    if [[ $mcauserset == 1 && $sslciphset == 0 ]] ; then
        echo "==>Failed, Violation ! Check: MCAUSER of SVRCONN Channel $channel is set to $mcauser <=="
        return 1
    else
        if [[ $start != 0 ]] ; then
            echo "Passed"
            return 0
        fi
    fi
}

###################################################################################################
#
#If CHADEXIT is empty and MCAUSER field displays "nobody" -> conform ITCS104
#If CHADEXIT is set and MCAUSER field is empty -> conform ITCS104
#If CHADEXIT is set and MCAUSER set -> conform ITCS104
#If CHADEXIT is empty and MCAUSER field empty -> violation
#If CHADEXIT is empty and MCAUSER is set to other userID then nobody -> violation
#
#If violation then display: "violation: Either CHADEXIT in QMGR must be set or MCAUSER of channel $CHANNEL must be set to NOBODY"
#If ITCS104 conform display: "channel $CHANNEL are conform ITCS104"
#
###################################################################################################

checkSYSTEMAUTO() {
    QMGR=$1
    OUT=/tmp/runmqsc.out
    subckrsut=0
    su - mqm -c "echo ""dis qmgr CHADEXIT"" | runmqsc $QMGR 2>&1" > $OUT
    chown mqm $OUT
    chmod a+r $OUT

    while read -r result
    do
        if echo $result |grep -i CHADEXIT\( > /dev/null ; then
            if echo $result |grep -i CHADEXIT\(\ \) > /dev/null ; then
                chadexitset=0
            else
                chadexitset=1
            fi
        fi
    done < $OUT

    if [[ $chadexitset == 1 ]]; then
#       echo "Pass: channel SYSTEM.AUTO.RECEIVER are conform to ITCS104 standards"
#       echo "Pass: channel SYSTEM.AUTO.SVRCONN are conform to ITCS104 standards"
        echo "Passed"
        return 0
    fi

    checkSYSTEMAUTOCHL $QMGR SYSTEM.AUTO.RECEIVER
    let "subckrsut = $subckrsut + $?"
    checkSYSTEMAUTOCHL $QMGR SYSTEM.AUTO.SVRCONN
    let "subckrsut = $subckrsut + $?"
    return $subckrsut

}

checkSYSTEMAUTOCHL() {
    QMGR=$1
    channel=$2
    OUT=/tmp/runmqsc.out
    su - mqm -c "echo ""dis channel\($channel\) MCAUSER"" | runmqsc $QMGR 2>&1" > $OUT
    chown mqm $OUT
    chmod a+r $OUT

    while read -r result
    do
        if echo $result |grep -i WebSphere\ MQ\ object |grep -i not\ found > /dev/null ; then
            echo $result
            continue
        fi

        if echo $result |grep -i MCAUSER\( > /dev/null ; then
            if echo $result |grep -i MCAUSER\(\ \) > /dev/null ; then
                echo "==> Failed, Violation ! Check configuration of $QMGR and $channel <=="
                return 1
            else
                if echo $result |grep -i nobody > /dev/null ; then
                    echo "Passed"
                    return 0
                else
                    echo "==>Failed, Violation ! Check configuration of $QMGR and $channel <=="
                    return 1
                fi
            fi
#           return 
        fi
    done < $OUT
}

###################################################################################################
#
#If SSLCIPH is set & MCAUSER set to NoBODY -> conform ITCS104
#IF SSLCIPH is set & MCAUSER is set to any other userID then NOBODY -> conform ITCS104
#IF SSLCIPH is set & MCAUSER is not set -> conform ITCS104
#If SSLCIPH is not set & MCAUSER is set to NOBODY -> conform ITCS104
#IF SSLCIPH is not set & MCAUSER is not set -> violation
#IF SSLCIPH is not set & MCAUSER is set to any other userID then NOBODY -> violation
#
#If violation then display: "violation: Either MCAUSER or SSLCIPH must be set on Channel SYSTEM.ADMIN.SVRCONN"
#If ItCS104 conform, then display: "Channel SYSTEM.ADMIN.SVRCONN is conform ITCS104"
#
###################################################################################################

checkSYSTEMADMINSVR() {
    QMGR=$1
    OUT=/tmp/runmqsc.out
    su - mqm -c "echo ""dis chl\(SYSTEM.ADMIN.SVRCONN\) MCAUSER SSLCIPH"" | runmqsc $QMGR 2>&1" > $OUT
    chown mqm $OUT
    chmod a+r $OUT

    if cat $OUT |grep -i WebSphere\ MQ\ object\ SYSTEM.ADMIN.SVRCONN\ not\ found > /dev/null ; then
        echo "### WebSphere MQ object SYSTEM.ADMIN.SVRCONN not found"
        return 0
    fi
    
    mcauserset=0 # 0- not set 1- set nobody 2- set others
    sslciphset=0 # 0- not set 1- set
    while read -r result
    do
        if echo $result |grep -i MCAUSER\( > /dev/null ; then
            if echo $result |grep -i MCAUSER\(\ \) > /dev/null ; then
                mcauserset=0
            else
                if echo $result |grep -i nobody > /dev/null ; then
                    mcauserset=1
                else
                    mcauserset=2
                fi
            fi
        else
            if echo $result |grep -i SSLCIPH\( > /dev/null ; then
                if echo $result |grep -i SSLCIPH\(\ \) > /dev/null ; then
                    sslciphset=0
                else
                    sslciphset=1
                fi
            fi
        fi        
    done < $OUT
    
    if [[ $sslciphset == 0 && $mcauserset != 1 ]] ; then
        echo "==>Failed, Violation ! Check configuration of Channel SYSTEM.ADMIN.SVRCONN <=="
        return 1
    else
        echo "Passed"
        return 0
    fi
}

###################################################################################################
#
#If anything else like mqm, wbimb, webinst, db2adm is displayed -> violation. 
#
#If violation, then display "violation. User account $USERID is a member of group mqm"
#If ITCS104 conform, then display "mqm group is ITCS104 conform"
#
###################################################################################################

checkGROUPid() {
    users=`more /etc/group |grep mqm: |cut -f4 -d:`
    OLDIFS=$IFS
    IFS=","
#    typeset -l $users
    isconform=1 # 1:conform 0:not conform
    for user in $users
    do        
#        if [[ $user != "mqm" && $user != "wbimb" && $user != "webinst" && $user != "db2adm" && $user != "eijamsdb" && $user != "eijamsrp" ]] ; then
        if [[ $user != "mqm" ]]; then
            checkApprList 'checkGROUPid' $user
            if [[ $userchk == 1 ]]; then # 0 -- approved 1 -- not approved
                isconform=0
                echo "==>Failed, Violation ! Check valid business need of user account $user being a member of group mqm <=="
                return 1
            fi
        fi
    done
    
    if [[ $isconform == 1 ]] ; then
        echo "Passed"
        return 0
    fi    
    IFS=$OLDIFS
}

###################################################################################################
#
#check if entity other the mqm has permissions like: passid, passall, setid and setall
#
#if only mq has above permission -> conform ITCS104 standards
#if any other entity then mqm has above mentioned permission -> violation
#
#If violation, then display: "Violation: User ID $UserID has permission $PERM on SYSTEM.ADMIN.COMMAND.QUEUE"
#If ITCS104 conform, then display: "SYSTEM.ADMIN.COMMAND.QUEUE is ITCS104 conform"
#
###################################################################################################

checkSYSTEMADMINQ() {
    QMGR=$1
    OUT=/tmp/dmpmqaut.out

    su - mqm -c "dmpmqaut -m $QMGR -n SYSTEM.ADMIN.COMMAND.QUEUE 2>&1" > $OUT    
    chown mqm $OUT
    chmod a+r $OUT

    status=0
    userid=""
    userchk=0
    violation=0
    while read -r result
    do
        if echo $result |grep -i WebSphere\ MQ\ object |grep -i not\ found > /dev/null ; then
            echo $result
            continue
        fi

        if echo $result |grep profile: > /dev/null ; then
            userid=""
            violation=0
            userchk=0
        fi            
        if echo $result |grep entity: |grep -v mqm > /dev/null ; then
            userid=`echo $result |cut -c 9-`
            userchk=1
        fi
        if [[ $userchk == 0 ]] ; then
            continue
        fi
        if echo $result |grep authority:  > /dev/null ; then
            authoritys=`echo $result |cut -f2 -d: |tr -s ' '`
            perms=""
            for perm in $authoritys
            do
                if [[ $perm == "passall" || $perm == "passid" || $perm == "setid" || $perm == "setall" ]] ; then 
                    violation=1
                    perms="$perms"","$perm
                fi
            done
            if [[ $violation == 1 ]] ; then
                perms=`echo $perms|cut -c 2-`
                echo "==>Failed, Violation ! Check valid business need of authorization $perms of entity $userid on SYSTEM.ADMIN.COMMAND.QUEUE <=="
                status=1
                return 1
            fi                         
        fi        
        
    done < $OUT
    if [[ $status == 0 ]]; then
#       echo "Pass: SYSTEM.ADMIN.COMMAND.QUEUE is conform to ITCS104 standards"
        echo "Passed"
        return 0
    fi    
}

###################################################################################################
#
#check output for any stanza that is not entity mqm and has folloing authorizations: chg, clr, crt, del, ping, ctrl or ctrlx.
#
#If this is the case -> violation
#
#If ITCS104 conform, then display: "OAM profiles are ITCS104 conform"
#If violation, then display the stanza that violates and "violation: Revoke authorization $PERM of userID $USERID"
#
###################################################################################################

checkOAMset() {
    QMGR=$1
    OUT=/tmp/dmpmqaut.out

    su - mqm -c "dmpmqaut -m $QMGR 2>&1" > $OUT    
    chown mqm $OUT
    chmod a+r $OUT

    isWBIMBnode=0 
    if lssys -n |grep WBIMB.EVENTS.MANAGER > /dev/null ; then
        isWBIMBnode=1
    fi
    
    status=0
    userid=""
    userchk=0
    start=0
    stanza=""
    violation=0
    while read -r result
    do
        if echo $result |grep profile: > /dev/null ; then
            userid=""
            violation=0
            userchk=0
            stanza=""
            start=1
        fi            
        if [[ $start == 0 ]] ; then
            continue
        fi
        
#        if [[ $isWBIMBnode == 1 ]] ; then        
#        #for WBIMB.EVENTS.MANAGER node, pass eiadm check -- Tiger Wu 20090522                                
#            if echo $result |grep -i entity: |grep -i -Ev "mqm|mqbrkrs|eiadm" > /dev/null ; then
#                userid=`echo $result |cut -c 9-|tr -s ' '`
#                userchk=1
#            fi
#        else
            if echo $result |grep -i entity:|grep -i -Ev "mqm|mqbrkrs" > /dev/null ; then
                userid=`echo $result |cut -c 9-|tr -s ' '`
                checkApprList 'checkOAMset' $userid
            fi        
#        fi  
        
        stanza="$stanza""\n"$result
        if [[ $userchk == 0 ]] ; then
            continue
        fi
       
        if echo $result |grep authority:  > /dev/null ; then
            authoritys=`echo $result |cut -f2 -d: |tr -s ' '`
            perms=""
            for perm in $authoritys
            do
                if [[ $perm == "chg" || $perm == "clr" || $perm == "crt" || $perm == "del" || $perm == "ping" || $perm == "ctrl" || $perm == "ctrlx" ]] ; then
                    violation=1
                    perms="$perms"","$perm     
                fi
            done
            if [[ $violation == 1 ]] ; then
                perms=`echo $perms|cut -c 2-`
                echo $stanza
                echo "==>Failed, Violation ! Check valid business need of authorization $perms of entity $userid <=="
                status=1
                return 1
            fi                
        fi                
    done < $OUT
    if [[ $status == 0 ]]; then
#       echo "Pass: OAM profiles are conform to ITCS104 standards"
        echo "Passed"
        return 0
    fi   
}


##################################################################################################
#
# check user approved list
#
##################################################################################################
checkApprList() {
    funcname=$1
    userid=$2
    roles=`grep -i "^[[:space:]]*func=$funcname" $ApprovedListFile|grep -Fi "username=$userid"|awk -F= '{print $4}'| awk '{print $1}'`
    #echo "test1: role name: $roles  userid: $userid"
    if [[ $roles == "" ]]; then
        userchk=1
    else
        if [[ $roles == "all" ]]; then
            userchk=0
        else
            userchk=1
            for role in `echo $roles|awk -F\; '{for(x=1;x<=NF;x++) {print $x}}'`; do
                if lssys -n |grep -i "$role" >  /dev/null ; then
                    userchk=0
                fi
            done
        fi
    fi
}

#########################################################################
#######check mq server node
#########################################################################
checkSERVER(){

    echo "Start check MQ Server ..."
    echo
    checkrslt=0
cd /var/mqm/qmgrs
if [ $? -ne 0 ]; then
    print -u2 -- "### Queue Manager not found"
    echo
    echo "** 2.1 Resusable passwords checking **"
    checkPasswd
    let "checkrslt = $checkrslt + $?"
    echo
    echo "**  5.2 Security & Administration              **"
    echo "User group mqm checking..."
    checkGROUPid
    let "checkrslt = $checkrslt + $?"
    echo
    echo ITCS104 Report end
    exit 
fi

for QMGR in `ls | grep -v @SYSTEM`; do
    if echo $QMGR | grep -i dummy > /dev/null ; then
        echo "$QMGR is a dummy, will be ignored"
        continue
    fi
    echo
    echo "------------------- $QMGR -------------------------"
    echo
    checkQMGR $QMGR
    qmgrsts=$?
    if [[ $qmgrsts == 0 ]] ; then
        echo "******Can not perform checkTrans() checkMQEXPLORER() checkaltusr() checkSVRCONN() checkSYSTEMDEF() checkSYSTEMAUTO() checkSYSTEMADMINSVR() checkSYSTEMADMINQ() checkOAMset()"
    fi
    echo "** 2.1 Resusable passwords checking **"
    checkPasswd
    let "checkrslt = $checkrslt + $?"
    echo
    echo "** 4   Information protection $ confidentiality **"
    echo "** 4.1 Encryption Type: Transmission **"
    echo "Check SSLCIPH:"
    if [[ $qmgrsts == 1 ]] ; then
        checkTrans $QMGR
        let "checkrslt = $checkrslt + $?"
    fi
    echo
    echo "** 5   Service integrity & availability         **"
    echo "Check OAM of Qmgr:"
    checkOAM $QMGR
    let "checkrslt = $checkrslt + $?"
    echo
    echo "** 5.1 Operating system resources                **"
    echo "Check Symbolic link is coverd by OS Healthcheck via SCM"
    echo
    echo "Check SSL keyrings:"
    checkSSLcert $QMGR
    let "checkrslt = $checkrslt + $?"
    if [[ $qmgrsts == 1 ]] ; then
    echo
    echo "Check Permissions of Queue SYSTEM.MQEXPLORER.REPLY.MODEL:"
        checkMQEXPLORER $QMGR
        let "checkrslt = $checkrslt + $?"
    echo
    echo "Check altusr permission of Qmgr:"
    checkaltusr $QMGR
    let "checkrslt = $checkrslt + $?"
    echo
    echo "Check SYSTEM.ADMIN.COMMAND.QUEUE permission:"
    if [[ $qmgrsts == 1 ]] ; then
        checkSYSTEMADMINQ $QMGR
        let "checkrslt = $checkrslt + $?"
    echo
    echo "Check OAM profiles (admin authorization):"
        checkOAMset $QMGR
        let "checkrslt = $checkrslt + $?"
    fi
    echo
    echo "Check SVRCONN channel:"
    checkSVRCONN $QMGR
    let "checkrslt = $checkrslt + $?"
    echo
    echo "Check sample channels:"
    checkSYSTEMDEF $QMGR
    let "checkrslt = $checkrslt + $?"
    echo
    echo "Check auto-def channels:"
    checkSYSTEMAUTO $QMGR
    let "checkrslt = $checkrslt + $?"
    
    echo
    echo "Check channel SYSTEM.ADMIN.SVRCONN:"
    checkSYSTEMADMINSVR $QMGR
    let "checkrslt = $checkrslt + $?"
    fi
    echo
    echo "**  5.2 Security & Administration              **"
    echo "User group mqm checking..."
    checkGROUPid
    let "checkrslt = $checkrslt + $?"
    echo
    echo "---------------------------------------------------"
    echo
done
    if [[ $checkrslt == 0 ]] ; then
       echo "All q managers on `hostname` conform to ITCS104 standards"
        echo "Overall Status: Passed"
      else
        echo "Total Violation(s):$checkrslt"
        echo "Overall Status: Failed"   
    fi
    echo "End check MQ Server."
    echo 

}


#########################################################################
#######check mq client node
#########################################################################
checkCLIENT(){
    
    echo "Start check MQ Client ..."

    echo "** 2.1 Resusable passwords checking **"
    checkPasswd
    let "checkrslt = $checkrslt + $?"
    
    echo
    echo "** 5.1 Operating system resources              **"
    echo
    echo "Check SSL keyrings:"
    checkCLIENTSSLcert 
    let "checkrslt = $checkrslt + $?"
    
    echo
    echo "**  5.2 Security & Administration              **"
    echo "User group mqm checking..."
#   checkGROUPid
    let "checkrslt = $checkrslt + $?"
    
    echo
    echo "---------------------------------------------------"
    echo
    echo "End check MQ Client."
    echo

}

###################################################################################################
#
# main function
#
###################################################################################################

echo ITCS104 Report Version 10.1 
echo MQ ITCS104 owner Marco Zeng
date
hostname

if echo `dspmqver 2>&1` | grep -i not\ found > /dev/null ; then
    echo "Websphere MQ not installed in this node"
    echo
    echo ITCS104 Report end
    date
    exit 
fi

ApprovedListFile=/lfs/system/tools/mq/conf/mq_itcs104_approved_list.conf
if ! [[ -f $ApprovedListFile ]]; then
    echo "The Approved User List $ApprovedListFile does not exists, please check"
    echo ITCS104 Report end
    date
    exit 
fi

echo

SERVER_IS_CHECKED="0"
CLIENT_IS_CHECKED="0"

for ROLE in `lssys -n1l role|awk '{for(i=1;i<=NF;i++) {print $i}}'|grep MQ` ; do 
    if echo $ROLE|grep CLIENT > /dev/null ; then
        if [[ ${CLIENT_IS_CHECKED} == "0" ]] ; then
            checkCLIENT
            CLIENT_IS_CHECKED="1"
        fi
    else
        if [[ ${SERVER_IS_CHECKED} == "0" ]] ; then
            checkSERVER
            SERVER_IS_CHECKED="1"
        fi
    fi
done

if echo `lssys -n1l role` |grep WBIMB > /dev/null ; then
    if [[ ${SERVER_IS_CHECKED} == "0" ]] ; then
        checkSERVER
        SERVER_IS_CHECKED="1"
    fi
fi

echo 
echo ITCS104 Report end
date
