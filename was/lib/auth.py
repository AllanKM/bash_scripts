#*******************************************************************************************************
# auth.py -- based on migration from authAction.jacl
#   Author: James Walton
#   Initial Revision Date: 07 Mar 2007
#*******************************************************************************************************
import sys
global AdminConfig
def usage():
	print 'Usage:'
        print '   wsadmin -lang jython -f auth.py -action <actionName> -auth <authName> [-attr <attributes>]'
        print '   wsadmin -lang jython -f auth.py -action list -auth <authName> [-filter type:<authType> | -filter role:<authRole>]'
        print 'Executes the selected action on authorization table <authName>.'
        print ''
        print 'Actions: list | add | remove | modify'
        print 'Authorizations: admin | naming'
        print ''
        print 'Attributes for adding, removing, or modifying:'
        print '  Usage:  -attr Type:UserName:Role'
        print '  Auth Types:   user | group | special'
        print '  Special Types: AllAuthenticatedUsers | Everyone | Server'
        print '  Admin Roles:  admin | op | config | monitor'
        print '  Naming Roles: read | write | create | delete | all'
        print ''
        print '  Example:  -action add -auth admin -attr group:\"HPODS Applications\":admin'
        print '  Example:  -action remove -auth naming -attr special:AllAuthenticatedUsers:write'

#*******************************************************************************************************
# Functions
#*******************************************************************************************************
def getAuthorizationTables(authFile):
	cell=AdminConfig.list('Cell').split('(')[0]
        authTable = AdminConfig.getid('/Cell:'+cell+'/AuthorizationTableExt:'+authFile+'/')
        authz = AdminConfig.showAttribute(authTable, 'authorizations').split('[')[1].split(']')[0].split()
        return authz

def printAuthList(aList, aLabel, roleName):
        for i in aList:
        	if (aLabel.find('Special') >= 0):
                        iName = i.split('#')[1].split('_')[0]
                else:
                        iName = AdminConfig.showAttribute(i, 'name')
                print aLabel+' ('+iName+'): '+roleName

def listAuth(authName):
        if (authName == 'admin'):
                authz = getAuthorizationTables('admin-authz.xml')
                uLabel = 'Admin User'
                gLabel = 'Admin Group'
                sLabel = 'Admin Special'
        elif (authName == 'naming'):
                authz = getAuthorizationTables('naming-authz.xml')
                uLabel = 'CORBA Naming User'
                gLabel = 'CORBA Naming Group'
                sLabel = 'CORBA Naming Special'
        for a in authz:
                aRole = AdminConfig.showAttribute(a, 'role')
                rName = AdminConfig.showAttribute(aRole, 'roleName')
                aList = AdminConfig.showAttribute(a, 'users').split('[')[1].split(']')[0].split()
                printAuthList(aList, uLabel, rName)
                aList = AdminConfig.showAttribute(a, 'groups').split('[')[1].split(']')[0].split()
                printAuthList(aList, gLabel, rName)
                aList = AdminConfig.showAttribute(a, 'specialSubjects').split('[')[1].split(']')[0].split()
                printAuthList(aList, sLabel, rName)

def listAuthFiltered(authName, authFilter):
	filterStyle = authFilter.split(':')[0]
	filterValue = authFilter.split(':')[1]
	adminRoles='admin op config monitor'
        corbaRoles='read write create delete all'
        styleList = 'user group special'
        if (authName == 'admin'):
                authz = getAuthorizationTables('admin-authz.xml')
                uLabel = 'Admin User'
                gLabel = 'Admin Group'
                sLabel = 'Admin Special'
        elif (authName == 'naming'):
                authz = getAuthorizationTables('naming-authz.xml')
                uLabel = 'CORBA Naming User'
                gLabel = 'CORBA Naming Group'
                sLabel = 'CORBA Naming Special'
        
        if (filterStyle == 'type'):
        	if (styleList.find(filterValue) < 0):
        		print 'ERROR: Invalid filter value specified, type requires user | group | special.'
                	usage()
                	sys.exit()
            	for a in authz:
	                aRole = AdminConfig.showAttribute(a, 'role')
	                rName = AdminConfig.showAttribute(aRole, 'roleName')
	                if (filterValue == 'user'):
	                	aList = AdminConfig.showAttribute(a, 'users').split('[')[1].split(']')[0].split()
	                	printAuthList(aList, uLabel, rName)
	            	elif (filterValue == 'group'):
	                	aList = AdminConfig.showAttribute(a, 'groups').split('[')[1].split(']')[0].split()
	                	printAuthList(aList, gLabel, rName)
	                elif (filterValue == 'special'):
	                	aList = AdminConfig.showAttribute(a, 'specialSubjects').split('[')[1].split(']')[0].split()
	                	printAuthList(aList, sLabel, rName)
	            	else: continue
    	elif (filterStyle == 'role'):
    		# Get role to apply, if admin role
	        if (adminRoles.find(filterValue) >= 0):
	                if (filterValue == 'admin'): filterValue = 'administrator'
	                elif (filterValue == 'op'): filterValue = 'operator'
	                elif (filterValue == 'config'): filterValue = 'configurator'
	                elif (filterValue == 'monitor'): filterValue = 'monitor'
	        # Get role to apply, if corba role
	        elif (corbaRoles.find(filterValue) >= 0):
	                if (filterValue == 'read'): filterValue = 'CosNamingRead'
	                elif (filterValue == 'write'): filterValue = 'CosNamingWrite'
	                elif (filterValue == 'create'): filterValue = 'CosNamingCreate'
	                elif (filterValue == 'delete'): filterValue = 'CosNamingDelete'
	                elif (filterValue == 'all'): filterValue = 'ALL'
	        elif (styleList.find(filterValue) <= 0):
	                print 'ERROR: Invalid filter value specified.'
	                usage()
	                sys.exit()
	        for a in authz:
	                aRole = AdminConfig.showAttribute(a, 'role')
	                rName = AdminConfig.showAttribute(aRole, 'roleName')
	                if (filterValue == rName):
	                       	aList = AdminConfig.showAttribute(a, 'users').split('[')[1].split(']')[0].split()
	                	printAuthList(aList, uLabel, rName)
	                	aList = AdminConfig.showAttribute(a, 'groups').split('[')[1].split(']')[0].split()
	                	printAuthList(aList, gLabel, rName)
	                	aList = AdminConfig.showAttribute(a, 'specialSubjects').split('[')[1].split(']')[0].split()
	                	printAuthList(aList, sLabel, rName)
	            	else: continue
	else:
		print 'ERROR: Invalid filter type specified.'
                usage()
                sys.exit()

def convertAttrs(authAttrs):
        adminRoles='admin op config monitor'
        corbaRoles='read write create delete all'
        atType = authAttrs.split(':')[0]
        atName = authAttrs.split(':')[1]
        atRole = authAttrs.split(':')[2]
        # Set type, attribute, and a print label
        if (atType == 'user'):
                atLabel = 'User'
                atType = 'UserExt'
                atAttr = 'users'
        elif (atType == 'group'):
                atLabel = 'Group'
                atType = 'GroupExt'
                atAttr = 'groups'
        elif (atType == 'special'):
                atLabel = 'SpecialSubject'
                atType = atName+'Ext'
                atAttr = 'specialSubjects'
        # Get role to apply, if admin role
        if (adminRoles.find(atRole) >= 0):
                if (atRole == 'admin'): atRole = 'administrator'
                elif (atRole == 'op'): atRole = 'operator'
                elif (atRole == 'config'): atRole = 'configurator'
                elif (atRole == 'monitor'): atRole = 'monitor'
        # Get role to apply, if corba role
        elif (corbaRoles.find(atRole) >= 0):
                if (atRole == 'read'): atRole = 'CosNamingRead'
                elif (atRole == 'write'): atRole = 'CosNamingWrite'
                elif (atRole == 'create'): atRole = 'CosNamingCreate'
                elif (atRole == 'delete'): atRole = 'CosNamingDelete'
                elif (atRole == 'all'): atRole = 'ALL'
        else:
                print 'ERROR: Invalid Role specified.'
                usage()
                sys.exit()
        return [atLabel,atAttr,atType,atName,atRole]

def addAuth(authName, authAttrs):
        if (authName == 'admin'): authz = getAuthorizationTables('admin-authz.xml')
        elif (authName == 'naming'): authz = getAuthorizationTables('naming-authz.xml')
        authAttrs = convertAttrs(authAttrs)
        atLabel = authAttrs[0]
        atType = authAttrs[2]
        atName = authAttrs[3]
        atRole = authAttrs[4]
        for a in authz:
                aRole = AdminConfig.showAttribute(a, 'role')
                rName = AdminConfig.showAttribute(aRole, 'roleName')
                if (rName.find(atRole) or atRole == 'ALL'):
                        if (atType.find('SpecialSubject')):
                                print 'Adding '+atLabel+' '+atName+' to '+authName+' role '+rName+'...'
                                result = AdminConfig.create(atType, a, [])
                        else:
                                print 'Adding '+atLabel+' '+atName+' to '+authName+' role '+rName+'...'
                                args = ['name \"'+atName+'\"']
                                result = AdminConfig.create(atType, a, args)
        if (result.find('cells/')):
                AdminConfig.save()
                print 'The configuration changes have been saved.'
                print 'Changes might need to be synchronized, and the appservers will need to be restarted.'

def removeAuth(authName, authAttrs):
        if (authName == 'admin'): authz = getAuthorizationTables('admin-authz.xml')
        elif (authName == 'naming'): authz = getAuthorizationTables('naming-authz.xml')
        authAttrs = convertAttrs(authAttrs)
        atLabel = authAttrs[0]
        atAttr = authAttrs[1]
        atType = authAttrs[2]
        atName = authAttrs[3]
        atRole = authAttrs[4]
        for a in authz:
                aRole = AdminConfig.showAttribute(a, 'role')
                rName = AdminConfig.showAttribute(aRole, 'roleName')
                if (rName == atRole):
                        iList = AdminConfig.showAttribute(a, atAttr).split('[')[1].split(']')[0].split()
                        for i in iList:
                                if (atAttr.find('special')): iName = i.split('#')[1].split('_')[0]
                                else: iName = AdminConfig.showAttribute(i, 'name')
                                if (iName.find(atName)):
                                        print 'Removing '+atLabel+' '+iName+' from role: '+rName
                                        result = AdminConfig.remove(i)
        if (result == ''):
                AdminConfig.save()
                print 'The configuration changes have been saved.'
                print 'Changes might need to be synchronized, and the appservers will need to be restarted.'

#*******************************************************************************************************
# Commandline parameter handling
#*******************************************************************************************************
argerr = 0
actionList=['list', 'add', 'remove']
modify='add remove'
if ( ('nodeName' in locals().keys() or 'nodeName' in globals().keys()) ): nodeName = ''

i = 0
argc=len(sys.argv)
while (i < argc):
        arg = sys.argv[i]
        if (arg == '-action'):
                i += 1
                if (i < argc): actionName = sys.argv[i]
                else: argerr = 2
        elif (arg == '-auth'):
                i += 1
                if (i < argc): authName = sys.argv[i]
                else: argerr = 3
        elif (arg == '-attr'):
                i += 1
                if (i < argc): authAttrs = sys.argv[i]
                else: argerr = 4
	elif (arg == '-filter'):
                i += 1
                if (i < argc): filterAttrs = sys.argv[i]
                else: argerr = 5
        else: argerr = 6
        i += 1

actionExists = ('actionName' in locals().keys() or 'actionName' in globals().keys()) 
authExists = ('authName' in locals().keys() or 'authName' in globals().keys())
attrExists = ('authAttrs' in locals().keys() or 'authAttrs' in globals().keys())
filterExists = ('filterAttrs' in locals().keys() or 'filterAttrs' in globals().keys())
#*******************************************************************************************************
# Verify valid parameters were passed
#*******************************************************************************************************
if (not actionExists): argerr = 7
else:
	try: actionList.index(actionName)
	except: argerr = 8
	if (authExists and not attrExists and actionName != 'list'): argerr = 9
	if (actionName == 'list' and not authExists): argerr = 10
	if (modify.find(actionName) < 0 and not attrExists and not authExists): argerr = 11
	if (actionName != 'list' and filterExists): argerr = 12

if (argerr):
        print 'Invalid command line invocation (reason code '+str(argerr)+').'
        usage()
        sys.exit()

#*******************************************************************************************************
# Decipher and Perform Requested Action
#*******************************************************************************************************
if (actionName == 'list'):
	if (filterExists):
		try: listAuthFiltered(authName, filterAttrs)
	        except: print 'Error during list request:',sys.exc_info()
	else:
	        try: listAuth(authName)
	        except: print 'Error during list request:',sys.exc_info()
elif (actionName == 'add'):
        try: addAuth(authName, authAttrs)
        except: print 'Error during add request:',sys.exc_info()
elif (actionName == 'remove'):
        try: removeAuth(authName, authAttrs)
        except: print 'Error during remove request:',sys.exc_info()
elif (actionName == 'modify'):
        try: usage()
        except: print 'Error during modify request:',sys.exc_info()
else: usage()
