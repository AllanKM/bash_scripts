#!/bin/ksh

PUBROOT=/projects/publish
PUBDIR=collabjam/htdocs/media
DROPDIR=${PUBROOT}/${PUBDIR}
JAVAPATH=/usr/java14/jre/bin/java
PUBTARGETURL="https://at1006g:6328/DIST-EI"
#USE THE FOLLOWING TARGETS FOR TESTING
#PUBTARGETURL="https://at1008g:6328/LDist-EI"
#TESTPUBURL="http://at1008c:6328/CombinedEventSites"
EVENT=collabjam
STOREPATH=/lfs/system/tools/publish/bNimble2/keys/allisone
LOGDIR=/logs/jampub
LOGFILE=jampub.log
PWDFILE=/lfs/system/tools/bNimble/conf/storepass
TOOLSBIN=/lfs/system/tools/was/bin

if [[ ! -d ${DROPDIR} ]]; then
   echo "Drop directory ${DROPDIR} does not exist!!!"
   echo "Exiting..."
   exit 1
fi

pub_file ()
{
cd ${PUBROOT}
if [ $? -ne 0 ]; then
        echo "Failed to chdir to ${PUBROOT}"
        exit 1;
fi

if [[ -f $PWDFILE ]]; then
	encrypted_passwd=$(grep ei_yz_pub_events.jks ${PWDFILE} |awk '{split($0,pwd,"ei_yz_pub_events.jks="); print pwd[2]}' |sed -e 's/\\//g')
	passwd_string=`${TOOLSBIN}/PasswordDecoder.sh $encrypted_passwd`
    keyPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")
    echo "Found and decoded keystore password"
else
    echo "Could not decode keystore password!"
fi

$JAVAPATH \
-Djavax.net.ssl.trustStore=${STOREPATH}/ei_yz_pub_events.jks \
-Djavax.net.ssl.trustStorePassword=${keypass} \
-Djavax.net.ssl.keyStore=${STOREPATH}/ei_yz_pub_events.jks \
-Djavax.net.ssl.keyStorePassword=${keypass} \
-jar /lfs/system/tools/publish/bNimble2/lib/Transmit.jar --Site $EVENT --Target-URL $PUBTARGETURL ${PUBDIR}/${FILE}
}

del_file ()
{
DATE=`date +%m/%d/%Y`
grep $FILE ${LOGDIR}/${LOGFILE} | grep $DATE | grep -q sent
  if [ $? -eq 0 ] ; then
    rm ${DROPDIR}/${FILE}
    rm ${DROPDIR}/${FILE}.done
  else
     echo "File was not successfully published!!! Please check ${LOGDIR}/${LOGFILE} for details."
  fi
}

i=9
while [ $i -ge 1 ]; do
mv ${LOGDIR}/${LOGFILE}.${i} ${LOGDIR}/${LOGFILE}.$(($i+1))
i=$(($i-1))
done

mv ${LOGDIR}/${LOGFILE} ${LOGDIR}/${LOGFILE}.1

umask 022
exec >>${LOGDIR}/${LOGFILE} 2>&1

for FILE in `ls ${DROPDIR} | grep -v .done`; do
  if [[ -f ${DROPDIR}/${FILE} && -f ${DROPDIR}/${FILE}.done ]]; then
    pub_file
    del_file
  fi
done
