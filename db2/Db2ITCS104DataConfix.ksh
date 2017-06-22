#!/bin/ksh
#-----------------------------------------------------------------------------------------
# Syntax:       Db2ITCS104DataConfix.ksh 
#
# Description:  This script checks authentication and srv_con_auth parameters for
#               this instance and fixes those according to classification ITCS 104 Confidential data
#
# Assumption:   The script will be run as the instance id.
#
# Input:        None
#
# Output:       ~/audit/DBMConfAuth.timestamp
#-----------------------------------------------------------------------------------------
# History of Changes
# =============================================================================================
# Date          Person          Version Comments
# 2009/01/10    S.rao            1.1    initial version 
#==============================================================================================
 

#-----------------------------------------------------------------------------------------

get_dbminfo()
{
OUT=`db2 get dbm config`
RC=$?

if [ ${RC} -eq 0 ] ; then

  AUTHEN=`echo "${OUT}" | grep '(AUTHENTICATION)' | awk '{print $NF}'`

  if [[ $AUTHEN = "CLIENT" ]];then
   echo "AUTHENTICATION must not client for IBM confidential data. It is being configured as SERVER_ENCRYPT " >> $AUDITFILE
  else
   echo "AUTHENTICATION:\t${AUTHEN}" >> $AUDITFILE
  fi

   SRVCON_AUTH=`echo "${OUT}" | grep '(SRVCON_AUTH)' | awk '{print $NF}'`

  if [[ $SRVCON_AUTH = "CLIENT" ]];then 
    echo "SRVCON_AUTH must not be client for IBM confidential data. It is being configured as Authentication value" >> $AUDITFILE
    db2 -v "update dbm cfg using SRVCON_AUTH SERVER_ENCRYPT" >> $AUDITFILE
  else
    echo "SRVCON_AUTH:\t${SRVCON_AUTH}" >> $AUDITFILE 
  fi

else
  echo "Unable to get DBM config information for $INST" 
  echo "Unable to get DBM config information for $INST" >> ${AUDITFILE}
fi
 
return ${RC}
}
#-----------------------------------------------------------------------------------------------------------------
get_revoke_script()
{
RC=0

#revoke connect for database  authority according to ITCS 104 IBM Confidential Data
echo "-- Revoking connect Authority from Public" >> $REVOKEFILE
db2 "select distinct CONNECTAUTH, 'revoke' \
     from syscat.dbauth where grantee='PUBLIC' or grantee = 'public'" | grep 'revoke'  > /tmp/revoke_dbauth
if [ $? -gt 1 ] ; then
        ((RC = RC + $?))
     fi

#initialize variables
connectauth="N"

while read CONNECTAUTH rev; do
        if [ "$CONNECTAUTH" = "Y" ] ; then
           connectauth="Y"
        fi
done < /tmp/revoke_dbauth
rm -f /tmp/revoke_dbauth  > /dev/null 2>$ERRFILE

#now create the revoke sql
REVSTRING=""
if [ "$connectauth" = "Y" ] ; then
        REVSTRING=`echo $REVSTRING " connect"`
fi

if [ "$REVSTRING" != "" ] ; then
        bad_comma=`echo $REVSTRING | awk '{print $1}'`
        if [ "$bad_comma" = "," ] ; then
           print "revoke ${REVSTRING#,} on database from public; " >> $REVOKEFILE
        else
           print "revoke ${REVSTRING} on database from public; " >> $REVOKEFILE
                fi
fi

return ${RC}

}
#---------------------------------------------------------------------------------------------------------------------
revoke_auth()
{

db2 -tvsf $REVOKEFILE >> $AUDITFILE
RC=$?
return $RC
}



###############################################################################
# MAIN Function. Execution Starts Here
###############################################################################
# Get the path the script is executing from
SCRIPTPATH=`dirname ${0}`

SCRIPTNAME=`basename ${0}`
DATE=`date '+%Y%m%d%H%M'`

# set output file name
mkdir ~/audit > /dev/null 2>&1   

AUDIT_DIR=$HOME/security/audit

if [ ! -d $AUDIT_DIR ]
  then
    mkdir $AUDIT_DIR
fi

AUDITFILE=$HOME/security/audit/DBMConfAuth.${DATE}
INST=`whoami`
echo "Starting script ${SCRIPTNAME}"

echo "Database Manager Authorization information for ${INST}:" >> $AUDITFILE
echo "\nParameter\tCurrent Value" >> $AUDITFILE
echo "-------------------------------------------------------------------" >> $AUDITFILE
get_dbminfo
((TOTRC=$TOTRC+$RC))
echo "-------------------------------------------------------------------" >> $AUDITFILE


DB_ALIAS=`db2 list db directory | grep "Database alias" | awk '{print $NF}'`

# We now have a list of databases defined for the instance
for DB in $DB_ALIAS
do
    DB_DIR=$(db2 list db directory | awk '{RS=""} $4 == DB && $9 ~ /Local/ {print $13}' DB=$DB )

# Check if it is a local database
    if [ -z "$DB_DIR" ] ; then
        continue
   else
        echo
        echo "Processing information for $DB.  Please be patient..."
        REVOKEFILE=$HOME/security/audit/RevokeAuthSQL.${DB}.${DATE}
        db2 +o connect to $DB
        ((TOTRC = TOTRC + $?))
        get_revoke_script
        ((TOTRC = TOTRC + RC))
        echo "revoking the connect authentication from public in database ${DB}" >> $AUDITFILE
        revoke_auth
        ((TOTRC = TOTRC + RC))

   fi
done
echo "" >> $AUDITFILE
TOTRC=0


if [ ${TOTRC} -eq 0 ] ; then
  echo "Successfully run ${SCRIPTNAME}"
else
  echo "ERRORS running ${SCRIPTNAME} "
fi

exit ${TOTRC}
#
###############################################################################

