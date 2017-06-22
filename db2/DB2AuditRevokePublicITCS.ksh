#!/bin/ksh   
#----------------------------------------------------------------------------------------------
#  Syntax:      DB2RevokePublic.ksh 
#
#  Description: This scripts revokes PUBLIC authority on all objects in all databases
#               defined in this instance.
#
#  NOTE:        *******It is strong recommended that you run DB2CheckPublicAuth.ksh first*********
#
#  Assumption:  This will be run be the instance owner
#
#  Input:       None
#
#  Output:      ~/audit/RevokeAuthSQL.dbname.timestamp
#               ~/audit/PublicAuthAfterRevoke.dbname.timestamp
#               ~/audit/RevokeOutput.dbname.timestamp
#
#----------------------------------------------------------------------------------------------
# History of Changes
# =============================================================================================
# Date          Person          Version Comments
# 2001/12/04    S. Rao       1.1     PUBLIC access will not revoked from NULLID.* packages
# 2008/10/01    S.Rao        1.2     Added a check to revoke specified SYSCAT and SYSIBM tables for ITCS 104 Spec
#==============================================================================================

get_public_auth()
{
    echo "DATABASE authority held by PUBLIC:" >> $AUDITFILE
db2 "select * from syscat.dbauth where grantee='PUBLIC' or grantee='public'"      >> $AUDITFILE
if [ $? -gt 1 ] ; then
	((RC = RC + $?))
fi 
    echo "SCHEMA authority held by PUBLIC:" >> $AUDITFILE
db2 "select * from syscat.schemaauth where grantee='PUBLIC' or grantee='public'"  >> $AUDITFILE
if [ $? -gt 1 ] ; then
	((RC = RC + $?))
  fi 
    echo "TABLE authority held by PUBLIC:" >> $AUDITFILE
db2 "select * from syscat.tabauth where tabname like '%AUTH' and tabschema in ('SYSCAT','SYSIBM') and grantee = 'PUBLIC' or grantee = 'public'"  >> $AUDITFILE
if [ $? -gt 1 ] ; then
	((RC = RC + $?))
fi
return $RC
}

#----------------------------------------------------------------------------------------

get_revoke_script()
{
RC=0

#revoke DATABASE authority 
echo "-- Revoking DATABASE Authority from Public" >> $REVOKEFILE
db2 "select distinct DBADMAUTH, CREATETABAUTH, IMPLSCHEMAAUTH,SECURITYADMAUTH, 'revoke' \
     from syscat.dbauth where grantee='PUBLIC' or grantee = 'public'" | grep 'revoke'  > /tmp/revoke_dbauth
if [ $? -gt 1 ] ; then
	((RC = RC + $?))
     fi

#initialize variables
dbadm="N"
create="N"
impschema="N"
secadm="N"
 
while read DBADMAUTH CREATETABAUTH IMPLSCHEMAAUTH SECURITYADMAUTH rev; do
	if [ "$DBADMAUTH" = "Y" ] ; then
	   dbadm="Y"	
	fi
	if [ "$CREATETABAUTH" = "Y" ] ; then
	   create="Y"	
	fi
	if [ "$IMPLSCHEMAAUTH" = "Y" ] ;then
	   impschema="Y"
	fi
        if [ "$SECURITYADMAUTH" = "Y" ] ;then
           secadm="Y"
        fi
done < /tmp/revoke_dbauth
rm -f /tmp/revoke_dbauth  > /dev/null 2>$ERRFILE

#now create the revoke sql
REVSTRING=""
if [ "$dbam" = "Y" ] ; then
	REVSTRING=`echo $REVSTRING " dbadm"`
	fi
if [ "$create" = "Y" ] ; then
	REVSTRING=`echo $REVSTRING ", createtab"`
	fi
if [ "$impschema" = "Y" ] ;then
	REVSTRING=`echo $REVSTRING ", implicit_schema"`
fi
if [ "$secadm" = "Y" ] ;then
        REVSTRING=`echo $REVSTRING ", secadm"`
fi

if [ "$REVSTRING" != "" ] ; then
	bad_comma=`echo $REVSTRING | awk '{print $1}'`
	if [ "$bad_comma" = "," ] ; then
	   print "revoke ${REVSTRING#,} on database from public; " >> $REVOKEFILE
	else
	   print "revoke ${REVSTRING} on database from public; " >> $REVOKEFILE
		fi
fi


#revoke SCHEMA authority
echo "-- Revoking SCHEMA Authority from Public" >> $REVOKEFILE
db2 "select distinct SCHEMANAME, ALTERINAUTH, CREATEINAUTH, DROPINAUTH, 'revoke' from syscat.schemaauth where grantee='PUBLIC' or grantee = 'public'" | grep 'revoke'  >> /tmp/revoke_schema

if [ $? -gt 1 ] ; then
	((RC = RC + $?))
    fi

set -A schemaa
set -A altera
set -A createa
set -a dropa
CNT=0
 
#initialize array
 
while read SCHEMA ALTERIN CREATEIN DROPIN rev; do
   FOUND=0
   i=1
   while [ $i -le $CNT ] ; do
        if [ "$SCHEMA" = "${schemaa[$i]}" ] ; then
           FOUND=1
           if [ "$ALTERIN" = "Y" ] ; then
                altera[$i]="Y"
           fi
           if [ "$CREATEIN" = "Y" ] ; then
                createa[$i]="Y"
           fi
           if [ "$DROPIN" = "Y" ] ; then
                dropa[$i]="Y"
           fi
        fi
        ((i = i + 1))
          done
   if [ $FOUND -eq 0 ] ; then
        ((CNT = CNT + 1))
	schemaa[$CNT]=$SCHEMA
	altera[$CNT]=$ALTERIN
	createa[$CNT]=$CREATEIN
	dropa[$CNT]=$DROPIN
   fi
done < /tmp/revoke_schema
 
rm -f /tmp/revoke_schema

#now write the revoke statements
i=1
while [ $i -le $CNT ] ; do
   REVSTRING=""
   if [ "${altera[$i]}" = "Y" ] ; then
	REVSTRING=`echo $REVSTRING " alterin"`
   fi
   if [ "${createa[$i]}" = "Y" ] ; then
	REVSTRING=`echo $REVSTRING ", createin"`
   fi
   if [ "${dropa[$i]}" = "Y" ] ; then
	REVSTRING=`echo $REVSTRING ", dropin"`
   fi
 
   if [ "$REVSTRING" != "" ] ; then
	bad_comma=`echo $REVSTRING | awk '{print $1}'`
	   if [ "$bad_comma" = "," ] ; then
		print "revoke ${REVSTRING#,} on schema \"${schemaa[$i]}\" from public; " >> $REVOKEFILE
	   else
		print "revoke ${REVSTRING} on schema \"${schemaa[$i]}\" from public; " >> $REVOKEFILE
	   fi
   fi
   ((i = i + 1))
done


#revoke TABLE  authority
echo "-- Revoking TABLE  from Public" >> $REVOKEFILE

db2ver=`db2licm -l | grep Version | tail -1 | awk '{print $NF}'`

db2 "select distinct  tabschema, tabname, 'revoke' \
     from syscat.tabauth where tabname like '%AUTH' and tabschema in ('SYSCAT','SYSIBM') and grantee = 'PUBLIC' or grantee = 'public'" |grep 'revoke'  >> /tmp/revoke_table

if [ $? -gt 1 ] ; then
	((RC = RC + $?))
fi

set -A schemaa
set -A namea
CNT=0
 
while read SCHEMA NAME rev ; do
   FOUND=0
   i=1
   while [ $i -le $CNT ] ; do
        if [ "$SCHEMA" = "${schemaa[$i]}" ] && [ "$NAME" = "${namea[$i]}" ] ; then
           FOUND=1
        fi
        ((i = i + 1))
           done
   if [ $FOUND -eq 0 ] ; then
        ((CNT = CNT + 1))
	schemaa[$CNT]=$SCHEMA
	namea[$CNT]=$NAME
   fi
done < /tmp/revoke_table
 
rm -f /tmp/revoke_table  > /dev/null 2>$ERRFILE

#now write the revoke statements
i=1

while [ $i -le $CNT ] ; do
   if [ $db2ver != "8.2" ] ; then
   print "revoke all on table \"${schemaa[$i]}\".\"${namea[$i]}\" from public; " >> $REVOKEFILE
   ((i = i + 1))
   else
   print "revoke statements for db2 version 8.2 is not required for ITCS0104" >> $REVOKEFILE
   fi
done
 

return $RC
}

#----------------------------------------------------------------------------------------

revoke_auth()
{

db2 -tvsf $REVOKEFILE >> $REVOKEOUT
RC=$?
echo "Database $DB - Grantees with Public Authority After to revoke:" >> $AUDITFILE
get_public_auth
((RC = RC + $?))
return $RC
}
	
#-----------MAIN LINE-------------------------------------------------------

SCRIPTPATH=`dirname ${0}`
SCRIPTNAME=`basename ${0}`
DATE=`date '+%Y%m%d%H%M'`
TOTRC=0
ERRFILE=/tmp/auditscript.errors
mkdir ~/audit      > /dev/null 2>$ERRFILE
 
echo "Starting script ${SCRIPTNAME}"

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
	AUDITFILE=$HOME/security/audit/PublicAuthAfterRevoke.${DB}.${DATE}
	REVOKEFILE=$HOME/security/audit/RevokeAuthSQL.${DB}.${DATE}
	REVOKEOUT=$HOME/security/audit/RevokeOutput.${DB}.${DATE}
	db2 +o connect to $DB
	((TOTRC = TOTRC + $?))  
	get_revoke_script
	((TOTRC = TOTRC + RC))  
	revoke_auth
	((TOTRC = TOTRC + RC))  
  
   fi
done
 
if [ ${TOTRC} -eq 0 ] ; then
	echo "Successfully run ${SCRIPTNAME}"
else
	echo "ERRORS running ${SCRIPTNAME}"
fi
rm -f $ERRFILE 
exit ${TOTRC}

#-----------End Main Line-----------------------------------------------------
 

