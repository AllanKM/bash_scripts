##############################################################################
# 
# dsStats.py
#
# Description: Dumps pool contents for datasources 
# 
# Usage: 
# ./wsadmin.sh -lang jython -f dsStats.py <jvm> <datasource> [exclude string]
#
# Commandline options:
# <jvm> - search string for jvm
# <datasource> - search string for datasource
# [exclude string] - (optional) will filter out any <jvm> searches that also
# contain this string
#
# Author: Marvin Gjoni (mgjoni@us.ibm.com)
#
# Date: 2008/02/07
#
#############################################################################
import sys
if len(sys.argv)<2:
    print "Usage: ./wsadmin.sh -lang jython -f dsStats.py <jvm_searchstring> <datasource_searchstring> [exclude string]"
    sys.exit()
jvmsearch = sys.argv[0]
dssearch = sys.argv[1]
try:
    filter = sys.argv[2]
except IndexError:
    filter = ''
serverlist = []
dslist = []

def listObjects(name,search=''):
    return [AdminConfig.showAttribute(id,'name') for id in AdminConfig.list(name).split('\n') if (id.split('(')[0].find(search)!=-1 or search=='')]

def objToDict(objName):
    objDict={}
    objNameList = objName.split('WebSphere:')[1].split(',')
    for obj in objNameList:
        objDict[obj.split('=')[0]] = obj.split('=')[1]
    return objDict

def printPoolContents(objName):
    objDict={}
    objDict=objToDict(objName)
    printSeparator(objDict)
    print AdminControl.invoke(objName,'showPoolContents')

def printSeparator(objDict):
    print "============================================"
    print objDict['name'] + " " + objDict['process']
    print "============================================"

def getCObjList(dslist,serverlist):
    return [AdminControl.completeObjectName('type=DataSource,name='+ds+',process='+server+',*') for ds in dslist for server in serverlist]

serverlist = listObjects('Server',jvmsearch)
dslist = listObjects('DataSource',dssearch)
dsObjList = getCObjList(dslist,serverlist)
map(printPoolContents,dsObjList)

