#---------------------------------------------------------------
# As detailed on: http://publib.boulder.ibm.com/infocenter/wasinfo/v6r1/index.jsp?topic=/com.ibm.websphere.nd.doc/info/ae/ae/csec_secfailover_ldap.html
#
# Add ldap hostname and port
#     wsadmin -f ldapadd.py arg1 arg2
#
#  The script expects some parameters:
#      arg1 - LDAP Server hostname
#      arg2 - LDAP Server portnumber
#
#---------------------------------------------------------------
import java

#-------------------------------------------------------
# get the line separator and use to do the parsing 
# since the line separator on different platform are different
lineSeparator = java.lang.System.getProperty('line.separator')

#-------------------------------------------------------------------------------
# add LDAP host
#-------------------------------------------------------------------------------
def LDAPAdd (ldapServer, ldapPort):
    global AdminConfig, lineSeparator, ldapUserRegistryId
    try:
        ldapObject = AdminConfig.list("LDAPUserRegistry")
        if len(ldapObject) == 0:
            print "LDAPUserRegistry ConfigId was not found\n"
            return

        ldapUserRegistryId = ldapObject.split(lineSeparator)[0]
        print "Got LDAPUserRegistry ConfigId is " + ldapUserRegistryId + "\n"
    except:
        print "AdminConfig.list('LDAPUserRegistry') caught an exception\n"

    try:
        secMbeans = AdminControl.queryNames('WebSphere:type=SecurityAdmin,*') 
        if len(secMbeans) == 0:
            print "Security Mbean was not found\n"
            return

        secMbean = secMbeans.split(lineSeparator)[0]
        print "Got Security Mbean is " + secMbean + "\n"
    except:
        print "AdminControl.queryNames('WebSphere:type=SecurityAdmin,*') caught an exception\n"


    attrs2 = [["hosts", [[["host", ldapServer], ["port", ldapPort]]]]]
    try:
        AdminConfig.modify(ldapUserRegistryId, attrs2)
        try:
            AdminConfig.save()
            print "Done setting up attributes values for LDAP User Registry"
            print "Updated was saved successfully\n"
        except:
            print "AdminConfig.save() caught an exception\n"
    except:
        print "AdminConfig.modify(" + ldapUserRegistryId + ", " + attrs2 + ") caught an exception\n"
    return

#-------------------------------------------------------------------------------
# Main entry point
#-------------------------------------------------------------------------------
if len(sys.argv) < 2 or len(sys.argv) > 3:
        print("LDAPAdd: this script requires 2 parameters: LDAP server hostname and LDAP server port number\n")
        print("e.g.: LDAPAdd ldaphost 389\n")
        sys.exit(1)
else:
        ldapServer = sys.argv[0]
        ldapPort = sys.argv[1]
        LDAPAdd(ldapServer, ldapPort)
        sys.exit(0)
