#!/bin/bash

db_owner=$1
db_owner_group=$2
auth=$3

if [ -z $db_owner ]; then
	echo "you must supply the ldap instance name"
	exit 
fi
if [ -z $db_group} ]; then
	echo you must supply the LDAP owner group
	exit
fi
if [ -z $auth ]; then
	$auth="serverclientauth"
fi

# Copy the key file to LDAP config

cp /fs/system/security/certauth/KEYRINGS/LDAPSERVER/ldapauth* /db2_database/${db_owner}/idsslapd-${db_owner}/etc
chown ${db_owner}:${db_owner_group} /db2_database/${db_owner}/idsslapd-${db_owner}/etc/*

sed "
		s/^ibm-slapdSslCertificate:.*$/ibm-slapdSslCertificate: EI CA signed cert for ldapauth/
		s/^ibm-slapdSslKeyDatabase:.*$/ibm-slapdSslKeyDatabase: \/db2_database\/${db_owner}\/idsslapd-${db_owner}\/etc\/ldapauth.kdb/
		s/^ibm-slapdPwEncryption:.*$/ibm-slapdPwEncryption: sha/
		s/^ibm-slapdSecurity:.*$/ibm-slapdSecurity: SSLOnly/
		s/^ibm-slapdSslAuth:.*$/ibm-slapdSslAuth: $auth/
      "  /db2_database/${db_owner}/idsslapd-${db_owner}/etc/ibmslapd.conf >/tmp/$db_owner.conf

cp /db2_database/${db_owner}/idsslapd-${db_owner}/etc/ibmslapd.conf /db2_database/${db_owner}/idsslapd-${db_owner}/etc/ibmslapd.conf.bak

mv /tmp/${db_owner}.conf /db2_database/${db_owner}/idsslapd-${db_owner}/etc/ibmslapd.conf
chown ${db_owner}:${db_owner_group} /db2_database/${db_owner}/idsslapd-${db_owner}/etc/ibmslapd.conf
chmod 755 /db2_database/${db_owner}/idsslapd-${db_owner}/etc/ibmslapd.conf



