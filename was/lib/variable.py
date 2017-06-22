# variable.py -- manage WebSphere environment variables
#
#   Author: James Walton
#   Initial Revision Date: 08/30/2010
#*******************************************************************************************************
import sys
global AdminConfig
#*******************************************************************************************************
# Functions
def usage():
        print 'Usage:'
        print '   wsadmin -lang jython -f variable.py -action <action> -server|-node|-cluster|-cell <scopeName> [-var name[=value]]'
        print ''
        print 'Actions: list | modify | create | delete'
        print 'Scopes : <cellName> | <nodeName> | <serverName> | <clusterName>'
        print ''
        print 'The -var parameters are used for the modify/create/delete actions.'
        print 'Deletion does not require the value, only the name'

def listVars(varMap):
	varScope = varMap.split('|')[0].split('/')[-1]
	print '-----------------------------------------------------------'
	print 'Environment Variables: '+varScope
	print '-----------------------------------------------------------'
	#Length 2 means the scope has no variables defined
	if (len(AdminConfig.showAttribute(varMap, 'entries')) != 2):
		vseList = AdminConfig.showAttribute(varMap,'entries').split('[')[1].split(']')[0].split()
		for varEntry in vseList:
			vName = AdminConfig.showAttribute(varEntry, 'symbolicName')
			vValue = AdminConfig.showAttribute(varEntry, 'value')
			print vName+' = '+str(vValue)
	else: print 'No variables defined.'

def modVar(varMap,varName,varVal):
	varScope = varMap.split('|')[0].split('/')[-1]
	print '-----------------------------------------------------------'
	print 'Modifying Environment Variable: '+varScope+'|'+varName
	print '-----------------------------------------------------------'
	vseList = AdminConfig.showAttribute(varMap,'entries').split('[')[1].split(']')[0].split()
	curVal = ''
	for varEntry in vseList:
		svName = AdminConfig.showAttribute(varEntry, 'symbolicName')
		if (svName == varName):
			curVal = AdminConfig.showAttribute(varEntry, 'value')
			print 'Found environment Variable ('+varName+') at scope ('+varScope+')'
			print 'Modifying value from ('+str(curVal)+') to ('+varVal+')'
			try: AdminConfig.modify(varEntry, [['symbolicName',varName], ['value',varVal]])
			except:
				print '### Error: Environment variable modification failed!'
				print 'Error details:',sys.exc_info()
				return
			else:
				print 'Environment variable modified.'
				AdminConfig.save()
			return
		else: continue
	print 'Environment Variable ('+varName+') not found at scope ('+varScope+'). No modification occurred.'

def addVar(varMap,varName,varVal):
	varScope = varMap.split('|')[0].split('/')[-1]
	print '-----------------------------------------------------------'
	print 'Creating Environment Variable: '+varScope+'|'+varName
	print '-----------------------------------------------------------'
	vseList = AdminConfig.showAttribute(varMap,'entries').split('[')[1].split(']')[0].split()
	attrs = []
	attrs.append(['symbolicName',varName])
	attrs.append(['value',varVal])
	for varEntry in vseList:
		svName = AdminConfig.showAttribute(varEntry, 'symbolicName')
		if (svName == varName):
			curVal = AdminConfig.showAttribute(varEntry, 'value')
			print '### Error: Environment Variable ('+varName+') already exists at scope ('+varScope+') please specify modify action.'
			print 'Current value of ('+varName+') = '+str(curVal)
			return
		else: continue
	print 'Environment Variable ('+varName+') does not exists at scope ('+varScope+'), creating...'
	try: evObj = AdminConfig.create('VariableSubstitutionEntry', varMap, attrs)
	except:
		print '### Error: Environment variable creation failed!'
                print 'Error details:',sys.exc_info()
                return
        else:
        	print 'Environment variable created: '+evObj
        	AdminConfig.save()

def delVar(varMap,varName):
	varScope = varMap.split('|')[0].split('/')[-1]
	print '-----------------------------------------------------------'
	print 'Deleting Environment Variable: '+varScope+'|'+varName
	print '-----------------------------------------------------------'
	vseList = AdminConfig.showAttribute(varMap,'entries').split('[')[1].split(']')[0].split()
	curVal = ''
	for varEntry in vseList:
		svName = AdminConfig.showAttribute(varEntry, 'symbolicName')
		if (svName == varName):
			curVal = AdminConfig.showAttribute(varEntry, 'value')
			print 'Found environment Variable ('+varName+') at scope ('+varScope+')'
			print 'Deleting variable, which currently has a value of ('+str(curVal)+')'
			try: AdminConfig.remove(varEntry)
			except:
				print '### Error: Environment variable deletion failed!'
		                print 'Error details:',sys.exc_info()
		                return
		        else:
		        	print 'Environment variable deleted.'
		        	AdminConfig.save()
			return
		else: continue
	print 'Environment Variable ('+varName+') not found at scope ('+varScope+'). No deletion occurred.'

#*******************************************************************************************************
# Commandline parameter handling
varName,varValue = '',''
i,argerr = 0,0
while ( i < len(sys.argv) ):
        arg = sys.argv[i]
        if (arg == '-action'):
                i += 1
                if (i < len(sys.argv)): actionName = sys.argv[i]
                else: argerr = 1
        elif (arg == '-server'):
                i += 1
                if (i < len(sys.argv)): scopeName = sys.argv[i]
                else: argerr = 2
                variableMap = AdminConfig.getid('/Server:'+scopeName+'/VariableMap:/')
        elif (arg == '-node'):
                i += 1
                if (i < len(sys.argv)): scopeName = sys.argv[i]
                else: argerr = 3
                variableMap = AdminConfig.getid('/Node:'+scopeName+'/VariableMap:/')
        elif (arg == '-cluster'):
                i += 1
                if (i < len(sys.argv)): scopeName = sys.argv[i]
                else: argerr = 4
                variableMap = AdminConfig.getid('/ServerCluster:'+scopeName+'/VariableMap:/')
        elif (arg == '-cell'):
        	i += 1
                if (i < len(sys.argv)): scopeName = sys.argv[i]
                else: argerr = 5
                variableMap = AdminConfig.getid('/Cell:'+scopeName+'/VariableMap:/')
        elif (arg == '-var'):
                i += 1
                if (i < len(sys.argv)): actVars = sys.argv[i]
                else: argerr = 6
                varList = actVars.split('=')
                varName = varList[0]
                if (len(varList) > 1): varValue = varList[1]
        else: argerr = 7
        i += 1

actionExists = ('actionName' in locals().keys() or 'actionName' in globals().keys())
scopeExists = ('scopeName' in locals().keys() or 'scopeName' in globals().keys())
varsExists = ('actVars' in locals().keys() or 'actVars' in globals().keys())
filterExists = ('filterArg' in locals().keys() or 'filterArg' in globals().keys())
clusterExists = ('clusterNames' in locals().keys() or 'clusterNames' in globals().keys())
#*******************************************************************************************************
# Verify valid parameters were passed
#*******************************************************************************************************
actionList='list modify create delete'
needVarList='modify create delete'
if (not actionExists):
	argerr = 8
else:
	if (not scopeExists): argerr = 9
	if (actionList.find(actionName) < 0): argerr = 10
	if ((needVarList.find(actionName) >= 0) and not varsExists): argerr = 11

if (argerr):
        print 'Invalid command line invocation (reason code '+str(argerr)+').'
        usage()
        sys.exit()

#*******************************************************************************************************
# Decipher and Perform Requested Action
#*******************************************************************************************************
if (actionName == 'list'): listVars(variableMap)
elif (actionName == 'modify'): modVar(variableMap,varName,varValue)
elif (actionName == 'create'): addVar(variableMap,varName,varValue)
elif (actionName == 'delete'): delVar(variableMap,varName)
else: print 'No valid action specified somehow.'
