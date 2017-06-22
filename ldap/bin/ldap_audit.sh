#!/bin/ksh
syntax() {
	print "\nsudo $0 <ldap_instance> enable|disable <rootpw>"
}
if [ -z "$SUDO_USER" ]; then
	print "$0 needs to be run using SUDO"
	syntax
	exit 4
fi
if [ $# -lt 3 ]; then
	print "Missing required info"
	syntax
	exit 4 
fi
instance=$1
action=$2
pw=$3
if [ -z "$pw" ]; then
	pw=vgtk.zL1
fi
if [ -e /db2_database/$instance ]; then
	while read line; do
		if [[ "$line" = "ibm-slapdPort:"* ]]; then
			ldap=${line#*: } 
		elif [[ "$line" = "ibm-slapdSecurePort:"* ]]; then
			ldaps=${line#*: }
		fi
	done </db2_database/$instance/idsslapd-$instance/etc/ibmslapd.conf
else
	print "ldap instance $instance does not exist"
	exit 4
fi
if [ -n "$ldaps" ]; then 
	port=$ldaps
	kdb="-K /etc/security/ldap/ei_yellow_ldap_client.kdb"
else
	port=$ldap
fi

if [ "$action" = 'enable' ]; then
  ldif=/tmp/enable_ldap_audit.ldif
  cat >$ldif <<EOF

# start of audit_enable.ldif
dn: cn=Audit, cn=Log Management, cn=Configuration
changetype: modify
replace: ibm-audit
ibm-audit: TRUE
-
replace: ibm-auditAdd
ibm-auditAdd: TRUE
-
replace: ibm-auditBind
ibm-auditBind: TRUE
-
replace: ibm-auditDelete
ibm-auditDelete: TRUE
-
replace: ibm-auditExtOPEvent
ibm-auditExtOPEvent: TRUE
-
replace: ibm-auditFailedOPonly
ibm-auditFailedOPonly: FALSE
-
replace: ibm-auditModify
ibm-auditModify: TRUE
-
replace: ibm-auditModifyDN
ibm-auditModifyDN: TRUE
-
replace: ibm-auditPerformance
ibm-auditPerformance: TRUE
-
replace: ibm-auditPTABindInfo
ibm-auditPTABindInfo: TRUE
-
replace: ibm-auditSearch
ibm-auditSearch: TRUE
-
replace: ibm-auditUnbind
ibm-auditUnbind: TRUE
-
replace: ibm-auditExtOp
ibm-auditExtOp: TRUE
-
replace: ibm-auditExtOPEvent
ibm-auditExtOpEvent: TRUE
-
replace: ibm-auditCompare
ibm-auditCompare: TRUE
-
replace: ibm-auditGroupsOnGroupControl
ibm-auditGroupsOnGroupControl: TRUE
-
replace: ibm-auditAttributesOnGroupEvalOp
ibm-auditAttributesOnGroupEvalOp: TRUE
-
replace: ibm-auditVersion
ibm-auditVersion: 3

# End of audit_enable.ldif
EOF
elif [ "$action" = 'disable' ]; then 
	ldif=/tmp/disable_ldap_audit.ldif
	cat >$ldif <<EOF 

# start of audit_enable.ldif
dn: cn=Audit, cn=Log Management, cn=Configuration
changetype: modify
replace: ibm-audit
ibm-audit: FALSE
-
replace: ibm-auditAdd
ibm-auditAdd: FALSE
-
replace: ibm-auditBind
ibm-auditBind: TRUE
-
replace: ibm-auditDelete
ibm-auditDelete: FALSE
-
replace: ibm-auditExtOPEvent
ibm-auditExtOPEvent: FALSE
-
replace: ibm-auditFailedOPonly
ibm-auditFailedOPonly: TRUE
-
replace: ibm-auditModify
ibm-auditModify: FALSE
-
replace: ibm-auditModifyDN
ibm-auditModifyDN: FALSE
-
replace: ibm-auditPerformance
ibm-auditPerformance: FALSE
-
replace: ibm-auditPTABindInfo
ibm-auditPTABindInfo: FALSE
-
replace: ibm-auditSearch
ibm-auditSearch: FALSE
-
replace: ibm-auditUnbind
ibm-auditUnbind: TRUE
-
replace: ibm-auditExtOp
ibm-auditExtOp: FALSE
-
replace: ibm-auditExtOPEvent
ibm-auditExtOpEvent: FALSE
-
replace: ibm-auditCompare
ibm-auditCompare: FALSE
-
replace: ibm-auditGroupsOnGroupControl
ibm-auditGroupsOnGroupControl: FALSE
-
replace: ibm-auditAttributesOnGroupEvalOp
ibm-auditAttributesOnGroupEvalOp: FALSE
-
replace: ibm-auditVersion
ibm-auditVersion: 3

# End of audit_enable.ldif
EOF
else
	print "Invalid action $action"
	syntax
	exit 4
fi

if [ -n "$ldif" ] && [ -e $ldif ]; then
	ldapmodify -p $port $kdb -D cn=root -w $pw -i $ldif
else
	print "Missing ldif file"
	exit 4
fi
