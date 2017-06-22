#*******************************************************************************************************
# securityConfig.py -- based on migration from enableSecurity.jacl
#   Author: James Walton
#   Initial Date: 08/27/2008
#
#   Change History: 
#     Lou Amodeo    03-01-2013  Add support for Websphere 8.5 
#
#*******************************************************************************************************
import sys
global AdminConfig
global AdminControl

#*******************************************************************************************************
# Procedures
#*******************************************************************************************************
def usage():
	print 'Usage:'
	print 'Enable Global Security with LDAP User Registry as Web Identity'
	print '   wsadmin -lang jython -f securityConfig.py -WI -ldappassword <ldapPassword> -bindpassword <bindPassword> -standalone'
	print '\nEnable Global Security with LDAP User Registry as Enterprise Directory (BluePages)'
	print '   wsadmin -lang jython -f securityConfig.py -ED -ldappassword <ldapPassword> -standalone'	
	print 'The EI user for WI ED are pre-filled by the script currently.'

def getSecurityAdminMbean():
        try: result = AdminControl.queryNames('WebSphere:type=SecurityAdmin,*').split('\n')
        except:
                print 'AdminControl.queryNames(\'WebSphere:type=SecurityAdmin,*\') caught an exception:',sys.exc_info()
                return 
 	if (result != []):
        	# incase more than one, just get the first one
                secMbean = result[0]
                return secMbean
	else:
        	print 'Security Mbean was not found\n'
                return 

def disableLTPAKeyAutoGen():
	cellKSG=AdminConfig.getid('/KeySetGroup:CellLTPAKeySetGroup/')
	try: AdminConfig.modify(cellKSG,[['autoGenerate', 'false']])
	except:
		print 'AdminConfig.modify('+cellKSG+'[[\'autoGenerate\', \'false\']]) caught an exception:',sys.exc_info()
		sys.exit()

def disableLTPAKeyAutoGenSA():
	cellKSG=AdminConfig.getid('/KeySetGroup:NodeLTPAKeySetGroup/')
	try: AdminConfig.modify(cellKSG,[['autoGenerate', 'false']])
	except:
		print 'AdminConfig.modify('+cellKSG+'[[\'autoGenerate\', \'false\']]) caught an exception:',sys.exc_info()
		sys.exit()

def addToAdminRole(roleType, roleObj):
        adminRoles = 'administrator adminsecuritymanager iscadmins'
        authTable = AdminConfig.getid('/AuthorizationTableExt:admin-authz.xml/')
        authz = AdminConfig.showAttribute(authTable, 'authorizations').split(']')[0].split('[')[1].split(' ')
        #Cycle through all admin roles, add user/group object to the administrator-type roles as defined above
        for a in authz:
                aRole = AdminConfig.showAttribute(a, 'role')
                rName = AdminConfig.showAttribute(aRole, 'roleName')
                if (adminRoles.find(rName) >= 0):
                        args = [['name', roleObj]]
                        try: AdminConfig.create(roleType, a, args)
                        except: print '### Error adding '+roleType+' '+roleObj+' to admin role '+rName+':',sys.exc_info()

def addToOpRole(roleType, roleObj):
        adminRoles = 'operator'
        authTable = AdminConfig.getid('/AuthorizationTableExt:admin-authz.xml/')
        authz = AdminConfig.showAttribute(authTable, 'authorizations').split(']')[0].split('[')[1].split(' ')
        #Cycle through all config and op roles, add user/group object to the roles as defined above
        for a in authz:
                aRole = AdminConfig.showAttribute(a, 'role')
                rName = AdminConfig.showAttribute(aRole, 'roleName')
                if (adminRoles.find(rName) >= 0):
                        args = [['name', roleObj]]
                        try: AdminConfig.create(roleType, a, args)
                        except: print '### Error adding '+roleType+' '+roleObj+' to admin role '+rName+':',sys.exc_info()

def addAdminGroup(group):
        roleType = 'GroupExt'
        addToAdminRole(roleType, group)

def addOpGroup(group):
        roleType = 'GroupExt'
        addToOpRole(roleType, group)

def addAdminUser(user):
        roleType = 'UserExt'
	addToAdminRole(roleType, user)

#*******************************************************************************************************
# Commandline parameter handling
#*******************************************************************************************************
argerr = 0
enableWI = 0
enableUD = 0
enableED = 0
standAlone = 0

i = 0
argc=len(sys.argv)
while (i < argc):
        arg = sys.argv[i]
        if (arg == '-WI'): enableWI = 1
        elif (arg == '-ED' or arg == '-BP'): enableED = 1
        elif (arg == '-ldappassword'):
                i += 1
                if (i < argc): ldapPassword = sys.argv[i]
                else: argerr = 1
        elif (arg == '-bindpassword'):
                i += 1
                if (i < argc): bindPassword = sys.argv[i]
                else: argerr = 2        
        elif (arg == '-standalone'): standAlone = 1
        else: argerr = 3
        i += 1

ldapPwdExists = ('ldapPassword' in locals().keys() or 'ldapPassword' in globals().keys())
bindPwdExists = ('bindPassword' in locals().keys() or 'bindPassword' in globals().keys())
enableCount = enableWI + enableED
if (not ldapPwdExists and enableWI == 0 and enableED == 0): argerr = 4
if (not ldapPwdExists and enableWI == 1 and enableUD == 1): argerr = 5
if (not bindPwdExists and enableWI == 1): argerr = 6
if (enableCount != 1): arrerr = 7

if (argerr):
	print '### Invalid command line invocation (reason code '+str(argerr)+').'
        usage()
        sys.exit()

#*******************************************************************************************************
# Decipher and Perform Requested Action
#*******************************************************************************************************
if (standAlone): dmgr = AdminControl.completeObjectName('name=server1,type=Server,*')
else: dmgr = AdminControl.completeObjectName('name=dmgr,type=Server,*')

fullVersion = AdminControl.getAttribute(dmgr, 'platformVersion')
print 'fullVersion = ',fullVersion
version = fullVersion[0:3]
print 'version = ',version

# Turn off autoGen of the LTPA keys
print 'Disabling Auto-Generation of LTPA KeySetGroup'
if (standAlone): disableLTPAKeyAutoGenSA()
else: disableLTPAKeyAutoGen()

# Grab LDAP object, set common Registry values
ldap = AdminConfig.getid('/LDAPUserRegistry:/')
try: AdminConfig.modify(ldap, [['reuseConnection', 'false'], ['sslEnabled', 'true'], ['type', 'CUSTOM']])
except:
        print '### Error updating common LDAP Registry values:',sys.exc_info()
        sys.exit()

if (enableWI):
	cellEnv = AdminConfig.showAttribute(AdminConfig.getid('/Cell:/'), 'name')[2:5]
	if (cellEnv == 'prd' or cellEnv == 'spp'):
		wiUser = 'eiwasadmin'
	else:
		wiUser = 'eiapplications'        
        #Setup to allow groups
        result = AdminConfig.modify(ldap, [['baseDN', 'l=world'], ['bindDN', 'uid='+wiUser+',cn=applications'], ['bindPassword', bindPassword], ['primaryAdminId', 'eiauth@events.ihost.com'], ['useRegistryServerId', 'false'], ['realm', 'wildap.ibm.com:636']])
        if (result != ''):
                print '### Error updating WI LDAP values\n'+result
                sys.exit()
        #Just grab the first ldap host in the list, there should not be more than one.
        ldaphosts = AdminConfig.showAttribute(ldap, 'hosts').split('[')[1].split(']')[0].split()[0]
        try: AdminConfig.modify(ldaphosts, [['host', 'wildap.ibm.com'], ['port', '636']])
        except:
                print '### Error updating WI LDAP host and port:',sys.exc_info()
                sys.exit()
        ldapfilter = AdminConfig.showAttribute(ldap, 'searchFilter')
        #New accessrole filters
        try: AdminConfig.modify(ldapfilter, [['groupFilter', '(&(cn=%v1)(objectclass=accessrole))' ], ['groupIdMap', 'accessrole:cn'], ['groupMemberIdMap', 'accessRole:member'], ['userFilter', '(&(uid=%v1)(objectclass=irperson))' ], ['userIdMap', 'irperson:uid']])
        except:
                print '### Error updating WI LDAP filter values:',sys.exc_info()
                sys.exit()
        #Setup Admin Roles for users/groups - ITCS104 required
        addAdminGroup('eiapps')
        addOpGroup('eiwebmasters')
elif (enableED):        
        result = AdminConfig.modify(ldap, [['baseDN', 'o=ibm.com'], ['primaryAdminId', 'C-BCYD897@nomail.relay.ibm.com'], ['useRegistryServerId', 'false'], ['realm', 'bluepages.ibm.com:636']])
        if (result != ''):
                print '### Error updating ED LDAP values\n'+result
                sys.exit()
        #Just grab the first ldap host in the list, there should not be more than one.
        ldaphosts = AdminConfig.showAttribute(ldap, 'hosts').split('[')[1].split(']')[0].split()[0]
        try: AdminConfig.modify(ldaphosts, [['host', 'bluepages.ibm.com'], ['port', '636']])
        except:
                print '### Error updating ED LDAP host and port:',sys.exc_info()
                sys.exit()
        ldapfilter = AdminConfig.showAttribute(ldap, 'searchFilter')
        result = AdminConfig.modify(ldapfilter, [['groupFilter', '(&(cn=%v)(objectclass=groupOfUniqueNames))' ], ['groupIdMap', '*:cn'], ['groupMemberIdMap', 'groupOfUniqueNames:uniqueMember'], ['userFilter', '(&(mail=%v)(objectclass=ePerson))' ], ['userIdMap', '*:uid']])
        if (result != ''):
                print '### Error updating ED LDAP filter values:',sys.exc_info()
                sys.exit()
        #Setup Admin Roles for users/groups - ITCS104 required
        addAdminGroup('ei_ed_wasadmins')
        addOpGroup('ei_webmasters')

#Enabled Global Security with the newly configured registry
security = AdminConfig.list('Security')
sec_attrib = []
sec_attrib.append(['activeUserRegistry', ldap])
sec_attrib.append(['enforceJava2Security', 'false'])
sec_attrib.append(['appEnabled', 'true'])
sec_attrib.append(['enabled', 'true'])
try: AdminConfig.modify(security, sec_attrib)
except:
        print '### Error updating common Security attributes:',sys.exc_info()
        sys.exit()

print 'Saving configuration...'
AdminConfig.save()

print 'You must synchronize your changes across the cell to update any federated nodes.'
print '!! More importantly the dmgr and any federated nodes (nodeagents/appservers) must be restarted. !!'
