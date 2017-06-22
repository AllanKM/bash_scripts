#*******************************************************************************************************
# Jacl2Jython generated functions
#*******************************************************************************************************
import sys
import re
global AdminControl
global AdminConfig
def regsuball(pattern, string, replacement, flags=0):
        return re.compile(pattern, flags).sub(replacement, string)
def listSearch(lst, target):
        if(lst.count(target)<=0): return -1
        return lst.index(target)
def listREMatch(lst, pattern):
	for item in lst:
		if(re.match(pattern, item) != None):
			return lst.index(item)

#*******************************************************************************************************
# getStats.py -- based on migration from getStats.jacl
#
#   Author: James Walton
#   Initial Revision Date: 01/29/2008
#*******************************************************************************************************

#*******************************************************************************************************
# Procedures
#*******************************************************************************************************
def printMem ( nName, sName, jCfg, jObj, csv ):
        if (len(jObj) > 0):
                jvmheap = AdminControl.getAttribute(jObj, 'heapSize')
                jvmfree = AdminControl.getAttribute(jObj, 'freeMemory')
        else:
                jvmheap = 'NA'
                jvmfree = 'NA'
        jvmmax = AdminConfig.showAttribute(jCfg, 'maximumHeapSize')
        jvmmin = AdminConfig.showAttribute(jCfg, 'initialHeapSize')
        if (listSearch('nodeagent dmgr',sName) < 0):
                srvGrp = sName.split('_')[1]
                srvApp = sName.split('_')[2]
                sName = ''
                sName += srvGrp + '_' + srvApp
        if (csv):
                print nName+','+sName+','+jvmmin+','+jvmmax+','+jvmheap+','+jvmfree
        else:
                print nName+' : '+sName+' : '+jvmmin+' / '+jvmmax+' : '+jvmheap+' / '+jvmfree

def printThreadStats ( ver, nName, sName, wcpool, orbpool, csv ):
        if (len(wcpool) > 0):
                wcMaxSz = AdminControl.getAttribute(wcpool, 'maximumSize')
                wcMinSz = AdminControl.getAttribute(wcpool, 'minimumSize')
                if (ver == '5.1'):
			wcStats = AdminControl.getAttribute(wcpool, 'stats').split()[5:]
                else:
			wcStats = AdminControl.getAttribute(wcpool, 'stats').split('{')[1].split('}')[0]
			wcStats = regsuball('\n', wcStats, ' ')
			wcStats = wcStats.split()
                if (ver == '6.1'):
                        # Get Thread Pool
                        index = listSearch(wcStats,'name=PoolSize,')
                        iHwm = index + 13
                        iCur = iHwm + 1
                        wcHwmP = wcStats[iHwm].split(',')[0].split('=')[1]
                        wcCurP = wcStats[iCur].split(',')[0].split('=')[1]
                        # Get Active Threads
                        index = listSearch(wcStats,'name=ActiveCount,')
                        iHwm = index + 11
                        iCur = iHwm + 1
                        wcHwm = wcStats[iHwm].split(',')[0].split('=')[1]
                        wcCur = wcStats[iCur].split(',')[0].split('=')[1]
                else:
                        # Get Thread Pool
                        iLwm = listSearch(wcStats,'lowWaterMark=1')
                        iHwm = iLwm + 1
                        iCur = iHwm + 1
                        wcHwmP = wcStats[iHwm].split('=')[1]
                        wcCurP = wcStats[iCur].split('=')[1]
                        # Get Active Threads
                        iLwm = listSearch(wcStats,'lowWaterMark=0')
                        iHwm = iLwm + 1
                        iCur = iHwm + 1
                        wcHwm = wcStats[iHwm].split('=')[1]
                        wcCur = wcStats[iCur].split('=')[1]
        else:
                wcMaxSz, wcMinSz = 'NA', 'NA'
                wcHwmP, wcCurP = 'NA', 'NA'
                wcHwm, wcCur = 'NA', 'NA'
        if (len(orbpool) > 0):
		orbMaxSz = AdminControl.getAttribute(orbpool, 'maximumSize')
		orbMinSz = AdminControl.getAttribute(orbpool, 'minimumSize')
		if (ver == '5.1'):
			orbStats = AdminControl.getAttribute(orbpool, 'stats').split()[5:]
		else:
			orbStats = AdminControl.getAttribute(orbpool, 'stats').split('{')[1].split('}')[0]
			orbStats = regsuball('\n', orbStats, ' ')
			orbStats = orbStats.split()
                if (ver == '6.1'):
			# Get Thread Pool
			index = listSearch(orbStats,'name=PoolSize,')
			iHwm = index + 13
			iCur = iHwm + 1
			orbHwmP = orbStats[iHwm].split(',')[0].split('=')[1]
			orbCurP = orbStats[iCur].split(',')[0].split('=')[1]
			# Get Active Threads
			index = listSearch(orbStats,'name=ActiveCount,')
			iHwm = index + 11
			iCur = iHwm + 1
			orbHwm = orbStats[iHwm].split(',')[0].split('=')[1]
			orbCur = orbStats[iCur].split(',')[0].split('=')[1]
                else:
                        # Get Thread Pool
                        iLwm = listSearch(orbStats,'lowWaterMark=1')
                        iHwm = iLwm + 1
                        iCur = iHwm + 1
                        orbHwmP = orbStats[iHwm].split('=')[1]
                        orbCurP = orbStats[iCur].split('=')[1]
                        # Get Active Threads
                        iLwm = listSearch(orbStats,'lowWaterMark=0')
                        iHwm = iLwm + 1
                        iCur = iHwm + 1
                        orbHwm = orbStats[iHwm].split('=')[1]
                        orbCur = orbStats[iCur].split('=')[1]
        else:
                orbMaxSz, orbMinSz = 'NA', 'NA'
                orbHwmP, orbCurP = 'NA', 'NA'
                orbHwm, orbCur = 'NA', 'NA'

        if (csv):
                print nName+','+sName+','+wcMinSz+','+wcMaxSz+','+wcHwmP+','+wcCurP+','+wcHwm+','+wcCur+','+orbMinSz+','+orbMaxSz+','+orbHwmP+','+orbCurP+','+orbHwm+','+orbCur
        else:
                print nName+' : '+sName+' : {'+wcMinSz+'/'+wcMaxSz+'} ('+wcHwmP+'/'+wcCurP+') ('+wcHwm+'/'+wcCur+') : {'+orbMinSz+'/'+orbMaxSz+'} ('+orbHwmP+'/'+orbCurP+') ('+orbHwm+'/'+orbCur+')'

#*******************************************************************************************************
# Commandline parameter handling
#*******************************************************************************************************
argerr, checkMem, checkTransport = 0,0,0
pollCell, pollInfra, printCSV = 0,0,0
if ( ('nodeName' in locals().keys() or 'nodeName' in globals().keys()) ): nodeName = ''

i = 0
argc=len(sys.argv)
while ( i < argc ):
        arg = sys.argv[i]
        if (arg == '-server'):
                i += 1
                if (i < argc): appServer = sys.argv[i]
                else: argerr = 1
        elif (arg == '-datasource'):
                i += 1
                if (i < argc): dataSource = sys.argv[i]
                else: argerr = 2
        elif (arg == '-node'):
                i += 1
                if (i < argc): nodeName = sys.argv[i]
                else: argerr = 3
        elif (arg == '-cell'): pollCell = 1
        elif (arg == '-filter'):
                i += 1
                if (i < argc): filterArg = sys.argv[i]
                else: argerr = 4
        elif (arg == '-infra'):
        	pollInfra = 1
        	infraList = 'nodeagent dmgr'
        elif (arg == '-csv'): printCSV = 1
        elif (arg == 'memory'): checkMem = 1
        elif (arg == 'transport' or arg == 'threads'): checkTransport = 1
        else: argerr = 5
        i += 1

serverExists = ('appServer' in locals().keys() or 'appServer' in globals().keys())
nodeExists = (('nodeName' in locals().keys() or 'nodeName' in globals().keys()) and not nodeName == '')
filterExists = ('filterArg' in locals().keys() or 'filterArg' in globals().keys())
dsExists = ('dataSource' in locals().keys() or 'dataSource' in globals().keys())

if (serverExists and dsExists and (checkMem == 1 or checkTransport == 1)): argerr = 6
if (checkMem == 0 and checkTransport == 0 and serverExists and not dsExists): argerr = 7
if ((checkMem == 1 or checkTransport == 1) and dsExists): argerr = 8
if (serverExists and (pollCell or pollInfra)): argerr = 9
if (filterExists and not pollCell): argerr = 10
if (pollCell and pollInfra): argerr = 11

if (argerr):
        print 'Invalid command line invocation (reason code '+str(argerr)+'). Usage:'
        print '   wsadmin -lang jython -f getStats.py -server <appServerName> [-node <nodeName>] memory|transport [-csv]'
        print '   wsadmin -lang jython -f getStats.py -cell [-filter <searchString>] memory|transport [-csv]'
        print '   wsadmin -lang jython -f getStats.py -infra memory|(transport|threads) [-csv]'
        print '   wsadmin -lang jython -f getStats.py -datasource <datasourceName> [-server <serverName>] [-node <nodeName>]\n'
        print 'Given an application server name <appServerName>, this script will display the'
        print 'current free memory, current memory heap allocation, and maximum heap allowed'
        print '--OR-- the current statistics for the transport thread pool and configured min/max'
        print '--OR-- both the memory and transport statistics.'
        print 'Given a datasource name <datasourceName>, this script will display the common'
        print 'statistics (i.e. connection pool min/max/current, etc) for each active instance'
        print 'of the datasource (this will change depending on the scope).\n'
        print '** Adding the -csv flag for operations noted will print the output in CSV (comma separated) format.'
        sys.exit()

#*******************************************************************************************************
# Decipher and Perform Requested Action
#*******************************************************************************************************
dmgr = AdminControl.completeObjectName('WebSphere:name=dmgr,type=Server,*')
version = AdminControl.getAttribute(dmgr, 'platformVersion')

if (checkMem):
	if (printCSV):
		print 'Nodename,AppServer,MinHeap,MaxHeap,CurrentHeap,FreeHeap'
	else:
		print '======================================================='
		print 'Nodename : AppServer : Min/Max Heap : Current/Free Heap'
		print '======================================================='
	if (pollCell or pollInfra):
		serverList = AdminConfig.list('Server').splitlines()
		for server in serverList:
			serverName = server.split('(')[0]
			if (pollInfra):
				if (infraList.index(serverName) < 0): continue
			elif (filterExists):
				if (serverName.find(filterArg) < 0): continue 
			nodeName = server.split('/')[3]
			jvmcfg = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/JavaProcessDef:/JavaVirtualMachine:/')
			jvmobj = AdminControl.completeObjectName('type=JVM,node='+nodeName+',process='+serverName+',*')
			printMem(nodeName, serverName, jvmcfg, jvmobj, printCSV)
		#endFor 
	else:
		if (nodeExists):
			jvmobj = AdminControl.completeObjectName('type=JVM,node='+nodeName+',process='+appServer+',*')
			jvmcfg = AdminConfig.getid('/Node:'+nodeName+'/Server:'+appServer+'/JavaProcessDef:/JavaVirtualMachine:/')
		else:
			jvmobj = AdminControl.completeObjectName('name=JVM,type=JVM,process='+appServer+',*')
			jvmcfg = AdminConfig.getid('/Server:'+appServer+'/JavaProcessDef:/JavaVirtualMachine:/')
		printMem(nodeName, appServer, jvmcfg, jvmobj, printCSV)
        print ''

if (checkTransport):
        if (printCSV):
                print 'Node,AppServer,HTTPCfgMin,HTTPCfgMax,HTTPPoolPeak,HTTPPoolNow,HTTPThreadsPeak,HTTPThreadsNow,ORBCfgMin,ORBCfgMax,ORBPoolPeak,ORBPoolNow,ORBThreadsPeak,ORBThreadsNow'
        else:
                print '============================================================================================'
                print '        :               :              HTTP               :              ORB'
                print '        :               :    Cfg       Pool     Threads   :    Cfg       Pool     Threads'
                print ' Node   : AppServer     : {Min/Max} (Peak/Now) (Peak/Now) : {Min/Max} (Peak/Now) (Peak/Now)'
                print '============================================================================================'
        if (pollCell or pollInfra):
                serverList = AdminConfig.list('Server').split('\n')
                for server in serverList:
                        serverName = server.split('(')[0]
                        if (pollInfra):
                                if (infraList.index(serverName) < 0): continue 
                        elif (filterExists):
                                if (serverName.find(filterArg) < 0): continue 
                        nodeName = server.split('/')[3]
                        if (version == '5.1'):
                                wcPool = AdminControl.queryNames('name=Servlet.Engine.Transports,node='+nodeName+',process='+serverName+',*')
                        elif (version == '6.0' or version == '6.1'):
                                wcPool = AdminControl.queryNames('name=WebContainer,type=ThreadPool,node='+nodeName+',process='+serverName+',*')
                        else:
                                print 'No valid WebSphere version was found while attempting to obtain Web Container thread pool ID.'
                                sys.exit()
                        orbPool = AdminControl.queryNames('name=ORB.thread.pool,node='+nodeName+',process='+serverName+',*')
                        printThreadStats(version, nodeName, serverName, wcPool, orbPool, printCSV)
        else:
                if (version == '5.1'):
                        ## Get transport thread pools and stats for v5.1
                        if (nodeExists):
				wcPool = AdminControl.queryNames('name=Servlet.Engine.Transports,node='+nodeName+',process='+appServer+',*')
                        else:
				wcPool = AdminControl.queryNames('name=Servlet.Engine.Transports,process='+appServer+',*')
                elif (version == '6.0' or version == '6.1'):
                        ## Get transport thread pools and stats for v6.0/6.1
                        if (nodeExists):
                                wcPool = AdminControl.queryNames('name=WebContainer,type=ThreadPool,node='+nodeName+',process='+appServer+',*')
                        else:
                                wcPool = AdminControl.queryNames('name=WebContainer,type=ThreadPool,process='+appServer+',*')
                else:
                        print 'No valid WebSphere version was found while attempting to obtain thread pool ID.'
                        sys.exit()
                if (nodeExists):
                        orbPool = AdminControl.queryNames('name=ORB.thread.pool,node='+nodeName+',process='+appServer+',*')
                else:
                        orbPool = AdminControl.queryNames('name=ORB.thread.pool,process='+appServer+',*')
                printThreadStats(version, nodeName, appServer, wcPool, orbPool, printCSV)
        print ''

if (dsExists):
        if (version == '5.1'): poolContentOp = 'getPoolContents'
        elif (version == '6.0' or version == '6.1'): poolContentOp = 'showPoolContents'
        else:
                print 'No valid WebSphere version was found while attempting to set datasource connection pool operation.'
                sys.exit()
        if (serverExists):
                # Get DS instance for specifc appserver
                ds = AdminControl.queryNames('type=DataSource,process='+appServer+',name='+dataSource+',*')
                dsInfo = AdminControl.invoke(ds, poolContentOp)
                print 'AppServer: '+appServer
                print dsInfo
        elif (nodeExists and not serverExists):
                # Get all DS instances on node
                dsList = AdminControl.queryNames('type=DataSource,node='+nodeName+',name='+dataSource+',*').splitlines()
                print 'Node: '+nodeName
                print '====================================================='
                for ds in dsList:
                        # get appserver that DS is tied to and print it
                        dsargs = ds.split(',')
                        sName = dsargs[listREMatch(dsargs,'Server=')].split('=')[1]
                        print 'AppServer: '+sName
                        dsInfo = AdminControl.invoke(ds, poolContentOp)
                        print dsInfo
                        print '---------------------------------------------------'
        else:
                # Churn through all instances of the datasource
                dsList = AdminControl.queryNames('type=DataSource,name='+dataSource+',*').splitlines()
                for ds in dsList:
                        # get node and appserver that DS is tied to and print it
                        dsargs = ds.split(',')
                        sName = dsargs[listREMatch(dsargs, 'Server=')].split('=')[1]
                        nName = dsargs[listSearch(dsargs, 'node=')].split('=')[1]
                        print 'Node: '+nName+'  --  ApplicationServer: '+sName
                        dsInfo = AdminControl.invoke(ds, poolContentOp )
                        print dsInfo
                        print '-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-'
        print ''
