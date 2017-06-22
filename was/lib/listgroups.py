#*******************************************************************************************************
# listgroups.py -- stripped down version of auth.py for CBN/PAR usage
#   Author: James Walton
#   Initial Revision Date: 21 Jan 2013
#*******************************************************************************************************
import sys
global AdminConfig
def usage():
	print 'Usage:'
        print '   wsadmin -lang jython -f listgroups.py'

#*******************************************************************************************************
# Functions
#*******************************************************************************************************
def getAuthorizationTables(authFile):
	cell=AdminConfig.list('Cell').split('(')[0]
        authTable = AdminConfig.getid('/Cell:'+cell+'/AuthorizationTableExt:'+authFile+'/')
        authz = AdminConfig.showAttribute(authTable, 'authorizations').split('[')[1].split(']')[0].split()
        return authz

def printAuthList(aList, aLabel):
        for i in aList:
        	if (aLabel.find('Special') >= 0): iName = i.split('#')[1].split('_')[0]
                else: iName = AdminConfig.showAttribute(i, 'name')
		if (iName.find(',') >= 0): iName = iName.split(',')[0].split('=')[1]
                print aLabel+'='+iName

def listAuth(authName):
        authz = getAuthorizationTables('admin-authz.xml')
        label = 'AdminGroup'
        for a in authz:
                aRole = AdminConfig.showAttribute(a, 'role')
                aList = AdminConfig.showAttribute(a, 'groups').split('[')[1].split(']')[0].split()
                printAuthList(aList, label)

#*******************************************************************************************************
# Decipher and Perform Requested Action
#*******************************************************************************************************
try: listAuth('admin')
except: print 'Error during list request:',sys.exc_info()
