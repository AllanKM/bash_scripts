# sharedlib.py
#   - based on customer-specifc script written by Marvin Gjoni
# 2013-04-13 - James Walton <jfwalton@us.ibm.com>
import sys
import re
global AdminConfig
actionList = ['add', 'replace', 'clear', 'show']
editActions = ['add', 'replace', 'clear']

def usage():
        print 'Usage: wsadmin -f sharedlib.py add|replace|clear|show lib=<libname> [cp=\"/class/path;/values/here.jar\"] [scope=(cell|cluster:<name>|node:<name>)]'

getCP = lambda x: AdminConfig.show(x, ['classPath'])
modCP = lambda x,y: AdminConfig.modify(x, [['classPath', y]])

def display(cp):
	for item in cp.split(';'): print item

def showCP(lib):
	cp = getCP(lib).split(' ')[1][:-1]
	print 'Current classpath for library: %s\n' % lib
	display(cp)
	print ''

def clearCP(lib):
	print 'Clearing library: %s' % lib
	try: modCP(lib,'')
	except:
		print '### Error clearing library classpath - exiting without save.'
		print '### Error details:',sys.exc_info()
		sys.exit()
	print 'Cleared.\n'

def addCP(lib,newcp):
	showCP(lib)
	print 'Appending to library: %s\n' % lib
	try: modCP(lib,newcp)
	except:
		print '### Error appending library classpath - exiting without save.'
		print '### Error details:',sys.exc_info()
		sys.exit()
	cp = getCP(lib).split(' ')[1][:-1]
	print 'New classpath for library: %s\n' % lib
	display(cp)
	print ''

def replaceCP(lib,newcp):
	showCP(lib)
	# Clear classpath, then repopulate it
	clearCP(lib)
	try: modCP(lib,newcp)
	except:
		print '### Error replacing library classpath - exiting without save.'
		print '### Error details:',sys.exc_info()
		sys.exit()
	cp = getCP(lib).split(' ')[1][:-1]
	print 'New classpath for library: %s\n' % lib
	display(cp)
	print ''

#**************************************************************************************
# Begin main
scopeType = ''
i = 0
argc=len(sys.argv)
while ( i < argc ):
	arg = sys.argv[i]
	if (re.match('lib=', arg)): sharedLib=arg.split('=')[1]
	elif (re.match('cp=', arg)): classPath=arg.split('=')[1]
	elif (re.match('scope=', arg)):
		scope=arg.split('=')[1]
		if (scope == 'cell'): scopeType=scope
		else: scopeType,scopeName=scope.split(':')
	elif (arg in actionList): modType=arg
	i += 1

if (modType in ['add', 'replace'] and len(sys.argv) < 3):
	print 'Incorrect number of arguments passed.'
	usage()
        sys.exit()
elif (len(sys.argv) < 2):
	print 'Incorrect number of arguments passed.'
	usage()
        sys.exit()

if (scopeType == 'cell'):
	cellName = java.lang.System.getProperty ('local.cell')
	libraryPath = '/Cell:'+cellName+'/Library:'+sharedLib+'/'
elif (scopeType == 'cluster'): libraryPath = '/ServerCluster:'+scopeName+'/Library:'+sharedLib+'/'
elif (scopeType == 'node'): libraryPath = '/Node:'+scopeName+'/Library:'+sharedLib+'/'
else: libraryPath = '/Library:'+sharedLib+'/'

sharedLibs = AdminConfig.getid(libraryPath).splitlines()

for lib in sharedLibs:
	libName,libScope = lib.split('(')
	libScope = libScope.split('|')[0]
	print '\n=============== %s : %s ===============' % (libName, libScope)
	if (modType == 'replace'): replaceCP(lib, classPath)
	elif (modType == 'add'): addCP(lib, classPath)
	elif (modType == 'clear'): clearCP(lib)
	elif (modType == 'show'): showCP(lib)

if (modType in editActions):
	print 'Saving configuration...'
	AdminConfig.save()
	print 'Done.' 