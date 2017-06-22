#!/bin/bash
ldap_inst=$1
password=$2
user="cn=root"
if [ -z $ldap_inst ]; then
	echo "you must supply the ldap instance name"
	exit 
fi
if [ ! -d /db2_database/${ldap_inst}/idsslapd-${ldap_inst} ]; then
	echo ldap instance ${ldap_inst} not found
	exit
fi
if [ -z $password ]; then
	echo Password for instance ${ldap_inst} user $user required as 2nd parameter
	exit
fi
if ! sudo grep ldapauth.kdb /db2_database/${ldap_inst}/idsslapd-${ldap_inst}/etc/ibmslapd.conf >/dev/null; then
	echo "LDAP must be configured for SSL before running this script"
	exit
fi

port=i`sudo grep -Ep cn=SSL /db2_database/${ldap_inst}/idsslapd-${ldap_inst}/etc/ibmslapd.conf | grep ibm-slapdSecurePort | awk '{print $2}'`

if ! sudo grep -i "ibm-slapdMasterDN:" /db2_database/${ldap_inst}/idsslapd-${ldap_inst}/etc/ibmslapd.conf 1>/dev/null 2>&1 ; then
	sudo cat >>/db2_database/${ldap_inst}/idsslapd-${ldap_inst}/etc/ibmslapd.conf <<ADDMASTER

dn: cn=Master server, cn=configuration
cn: master server
ibm-slapdMasterDN: cn=replica
ibm-slapdMasterPW: Xd9.2fzP
objectclass: ibm-slapdReplication

ADDMASTER
	
fi
/usr/bin/ldapadd -k -p ${port} -K/db2_database/${ldap_inst}/idsslapd-${ldap_inst}/etc/ldapauth.kdb -D "${user}" -w ${password} -c <<ENDBASE
dn: o=ibm,c=us 
objectclass: top
objectclass: organization
o: ibm

ENDBASE

/usr/bin/ldapmodify -k -p ${port} -K/db2_database/${ldap_inst}/idsslapd-${ldap_inst}/etc/ldapauth.kdb -D "${user}" -w ${password} -c <<ENDMOD
dn: o=ibm,c=us
changetype: modify
add: objectclass
objectclass: ibm-replicationContext

ENDMOD

/usr/bin/ldapadd -k -p ${port} -K/db2_database/${ldap_inst}/idsslapd-${ldap_inst}/etc/ldapauth.kdb -D "${user}" -w ${password} -c <<ENDCRED
dn: cn=simple,cn=replication,cn=IBMpolicies
objectclass:ibm-replicationCredentialsSimple
cn:simple
replicaBindDN:cn=replica
replicaCredentials: Xd9.2fzP
description:Bind method of the peer master (server1)to the peer (server2)

ENDCRED

/usr/bin/ldapadd -k -p ${port} -K/db2_database/${ldap_inst}/idsslapd-${ldap_inst}/etc/ldapauth.kdb -D "${user}" -w ${password} -c <<ENDADD
#
dn: ibm-replicaGroup=default, o=ibm,c=us 
ibm-replicagroup: default
objectclass: ibm-replicaGroup
objectclass: top

dn: ibm-replicaServerId=peer1, ibm-replicaGroup=default, o=ibm,c=us 
objectclass: top
objectclass: ibm-replicaSubentry
ibm-replicaServerId: peer1
ibm-replicationServerIsMaster: TRUE
cn: peer1
description: peer1 master 

dn: ibm-replicaServerId=peer2, ibm-replicaGroup=default, o=ibm,c=us
objectclass: ibm-replicaSubentry
objectclass: top
ibm-replicaServerId: peer2
ibm-replicationServerIsMaster: TRUE
cn: peer2

dn: ibm-replicaServerId=peer3, ibm-replicaGroup=default, o=ibm,c=us
objectclass: ibm-replicaSubentry
objectclass: top
ibm-replicaServerId: peer3
ibm-replicationServerIsMaster: TRUE
cn: peer3

# peer1 ->  peer2 replication
dn: cn=peer2,ibm-replicaServerId=peer1, ibm-replicaGroup=default, o=ibm,c=us
ibm-replicaConsumerId: peer2
ibm-replicationonhold: TRUE
ibm-replicacredentialsdn: cn=simple,cn=replication,cn=IBMpolicies
ibm-replicaurl: ldaps://peer2.event.ibm.com:${port}
objectclass: ibm-replicationAgreement
objectclass: top
description: peer1 -> peer2

# peer1 ->  peer3 replication
dn: cn=peer3,ibm-replicaServerId=peer1, ibm-replicaGroup=default, o=ibm,c=us
ibm-replicaConsumerId: peer3
ibm-replicationonhold: TRUE
ibm-replicacredentialsdn: cn=simple,cn=replication,cn=IBMpolicies
ibm-replicaurl: ldaps://peer3.event.ibm.com:${port}
objectclass: ibm-replicationAgreement
objectclass: top
description: peer1 -> peer3

# peer2 -> peer1 replication
dn: cn=peer1,ibm-replicaServerId=peer2, ibm-replicaGroup=default, o=ibm,c=us
ibm-replicaConsumerId: peer1
ibm-replicationonhold: TRUE
ibm-replicacredentialsdn: cn=simple,cn=replication,cn=IBMpolicies
ibm-replicaurl: ldaps://peer1.event.ibm.com:${port}
objectclass: ibm-replicationAgreement
objectclass: top
description: peer2 -> peer1

# peer2 -> peer3 replication
dn: cn=peer3,ibm-replicaServerId=peer2, ibm-replicaGroup=default, o=ibm,c=us
ibm-replicaConsumerId: peer3
ibm-replicationonhold: TRUE
ibm-replicacredentialsdn: cn=simple,cn=replication,cn=IBMpolicies
ibm-replicaurl: ldaps://peer3.event.ibm.com:${port}
objectclass: ibm-replicationAgreement
objectclass: top
description: peer2 -> peer3

# peer3 -> peer1 replication
dn: cn=peer1,ibm-replicaServerId=peer3, ibm-replicaGroup=default, o=ibm,c=us
ibm-replicaConsumerId: peer1
ibm-replicationonhold: TRUE
ibm-replicacredentialsdn: cn=simple,cn=replication,cn=IBMpolicies
ibm-replicaurl: ldaps://peer1.event.ibm.com:${port}
objectclass: ibm-replicationAgreement
objectclass: top
description: peer3 -> peer1

# peer3 -> peer2 replication
dn: cn=peer2,ibm-replicaServerId=peer3, ibm-replicaGroup=default, o=ibm,c=us
ibm-replicaConsumerId: peer2
ibm-replicationonhold: TRUE
ibm-replicacredentialsdn: cn=simple,cn=replication,cn=IBMpolicies
ibm-replicaurl: ldaps://peer2.event.ibm.com:${port}
objectclass: ibm-replicationAgreement
objectclass: top
description: peer3 -> peer2
ENDADD
