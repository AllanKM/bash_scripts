#*******************************************************************************************************
# jvmmon.py -- retooling of jvmStats.py
#   Author: James Walton
#   Initial Revision Date: 04/05/2012
#*******************************************************************************************************
def usage():
        print 'Usage: wsadmin -f jvmmon.py -server <serverName> memory|threads [-ds <datasourceName>] [-sleep <seconds>] [-csv] [-noheader]'

import sys
import re
import time

def regsuball(pattern, string, replacement, flags=0):
        return re.compile(pattern, flags).sub(replacement, string)
def listREMatch(lst, pattern):
	for item in lst:
		if(re.match(pattern, item) != None): return lst.index(item)

#*******************************************************************************************************
# Functions
#*******************************************************************************************************
global AdminControl
global AdminConfig
def printMemThreads ( sName, jCfg, jObj, wcpool, orbpool, dsObj, csv ):
        # If we have a valid runtime object (i.e. not blank), get the current heap info, otherwise put in placeholders
        if (len(jObj) > 0):
                jvmheap = str(round((float(AdminControl.getAttribute(jObj, 'heapSize')) / 1024)/1024, 3))
                jvmfree = str(round((float(AdminControl.getAttribute(jObj, 'freeMemory')) / 1024)/1024, 3))
                #jvmheap = str(round((float(jvmheap) / 1024)/1024, 3))
                #jvmfree = str(round((float(jvmfree) / 1024)/1024, 3))
        else:
                jvmheap = 'NA'
                jvmfree = 'NA'
        # Get the configured heap settings
        jvmmax = AdminConfig.showAttribute(jCfg, 'maximumHeapSize')
        jvmmin = AdminConfig.showAttribute(jCfg, 'initialHeapSize')
        
        # Get WC Pool
        if (len(wcpool) > 0):
                # Pull the web container thread pool settings and stats
                wcMaxSz = AdminControl.getAttribute(wcpool, 'maximumSize')
                wcMinSz = AdminControl.getAttribute(wcpool, 'minimumSize')
                wcStats = AdminControl.getAttribute(wcpool, 'stats').split('{')[1].split('}')[0]
		wcStats = regsuball('\n', wcStats, '')
		wcStats = regsuball(' ', wcStats, '')
		wcStats = wcStats.split(',')
		# Get Thread Pool
                iHwm = listREMatch(wcStats, 'highWaterMark=')
                iCur = listREMatch(wcStats, 'current=')
                wcHwm = wcStats[iHwm].split('=')[1]
                wcCur = wcStats[iCur].split('=')[1]
        else:
                # Didn't receive a valid web container thread pool runtime object (it was blank), prep placeholder data.
                wcMaxSz, wcMinSz = 'NA', 'NA'
                wcHwm, wcCur = 'NA', 'NA'
	
	# Get ORB Pool
        if (len(orbpool) > 0):
		# Pull the orb thread pool settings and stats
		orbMaxSz = AdminControl.getAttribute(orbpool, 'maximumSize')
		orbMinSz = AdminControl.getAttribute(orbpool, 'minimumSize')
		orbStats = AdminControl.getAttribute(orbpool, 'stats').split('{')[1].split('}')[0]
		orbStats = regsuball('\n', orbStats, '')
		orbStats = regsuball(' ', orbStats, '')
		orbStats = orbStats.split(',')
		# Get Thread Pool
		iHwm = listREMatch(orbStats, 'highWaterMark=')
                iCur = listREMatch(orbStats, 'current=')
		orbHwm = orbStats[iHwm].split('=')[1]
		orbCur = orbStats[iCur].split('=')[1]
        else:
        	# Didn't receive a valid orb thread pool runtime object (it was blank), prep placeholder data.
                orbMaxSz, orbMinSz = 'NA', 'NA'
                orbHwm, orbCur = 'NA', 'NA'
        
        # Get DataSource info
        if (len(dsObj) > 0):
        	poolData = AdminControl.invoke(dsObj, 'showPoolContents')
        	poolData = regsuball('\n', poolData, ' ')
        	poolData = poolData.split()
        	iCur = listREMatch(poolData, 'connections:') + 1
        	iFree = listREMatch(poolData, 'pool:') + 1
        	iMxMn = listREMatch(poolData, '\(max/min') + 1
        	dsCur = poolData[iCur]
        	dsFree = poolData[iFree]
        	dsMax = poolData[iMxMn].split('/')[0]
        	dsMin = poolData[iMxMn].split('/')[1].split(',')[0]
    	else:
    		dsCur, dsFree = 'NA', 'NA'
    		dsMax, dsMin = 'NA', 'NA'
        # Determine the formatting requested, and spit out the data
        if (csv):
        	if (len(dsObj) > 0):
			print time.strftime("%Y-%m-%d,%H:%M:%S")+','+sName+','+jvmmin+','+jvmmax+','+jvmheap+','+jvmfree+','+wcMinSz+','+wcMaxSz+','+wcHwm+','+wcCur+','+orbMinSz+','+orbMaxSz+','+orbHwm+','+orbCur+','+dsMin+','+dsMax+','+dsCur+','+dsFree
		else: print time.strftime("%Y-%m-%d,%H:%M:%S")+','+sName+','+jvmmin+','+jvmmax+','+jvmheap+','+jvmfree+','+wcMinSz+','+wcMaxSz+','+wcHwm+','+wcCur+','+orbMinSz+','+orbMaxSz+','+orbHwm+','+orbCur
	else:
        	if (len(dsObj) > 0):
			#print time.strftime("%Y-%m-%d %H:%M:%S")+'\t'+sName+'\t'+jvmmin+'\t'+jvmmax+'\t'+jvmheap+'\t'+jvmfree+'\t'+wcMinSz+'\t'+wcMaxSz+'\t'+wcHwm+'\t'+wcCur+'\t'+orbMinSz+'\t'+orbMaxSz+'\t'+orbHwm+'\t'+orbCur+'\t'+dsMin+'\t'+dsMax+'\t'+dsCur+'\t'+dsFree
			print '%19s  %-30s %6s %6s %10s %10s %5s %5s %5s %5s %5s %5s %5s %5s %5s %5s %5s %5s' % (time.strftime("%Y-%m-%d %H:%M:%S"),sName,jvmmin,jvmmax,jvmheap,jvmfree,wcMinSz,wcMaxSz,wcHwm,wcCur,orbMinSz,orbMaxSz,orbHwm,orbCur,dsMin,dsMax,dsCur,dsFree)
		else: print time.strftime("%Y-%m-%d %H:%M:%S")+'\t'+sName+'\t'+jvmmin+'\t'+jvmmax+'\t'+jvmheap+'\t'+jvmfree+'\t'+wcMinSz+'\t'+wcMaxSz+'\t'+wcHwm+'\t'+wcCur+'\t'+orbMinSz+'\t'+orbMaxSz+'\t'+orbHwm+'\t'+orbCur

#*******************************************************************************************************
# Commandline parameter handling
#*******************************************************************************************************
argerr, checkMem, checkThreads = 0,0,0
pollCell, pollInfra, printCSV = 0,0,0
printHeader, checkMem, checkThreads = 1,1,1

i = 0
argc=len(sys.argv)
while ( i < argc ):
        arg = sys.argv[i]
        if (arg == '-server'):
                i += 1
                if (i < argc): serverNameList = sys.argv[i].split(',')
                else: argerr = 1
	elif (arg == '-ds'):
                i += 1
                if (i < argc): datasourceName = sys.argv[i]
                else: argerr = 2
	elif (arg == '-sleep'):
                i += 1
                if (i < argc): sleeptime = int(sys.argv[i])
                else: argerr = 3
	elif (arg == '-csv'): printCSV = 1
        elif (arg == '-noheader'): printHeader = 0
        elif (arg == 'memory'): checkMem = 1
        elif (arg == 'threads'): checkThreads = 1
        else: argerr = 5
        i += 1
serverExists = ('serverNameList' in locals().keys() or 'serverNameList' in globals().keys())
dsExists = ('datasourceName' in locals().keys() or 'datasourceName' in globals().keys())
sleepExists = ('sleeptime' in locals().keys() or 'sleeptime' in globals().keys())
#*******************************************************************************************************
# Verify valid parameters were passed
#*******************************************************************************************************
if ((checkMem == 0 and checkThreads == 0) and serverExists): argerr = 7
if (not sleepExists): sleeptime=30
if (argerr):
        print 'Invalid command line invocation (reason code '+str(argerr)+').'
        usage()
        sys.exit()

#*******************************************************************************************************
# Decipher and Perform Requested Action
#*******************************************************************************************************
if (checkMem and checkThreads):
	if (printCSV and printHeader):
		if (dsExists): print 'Date,Time,AppServer,mnHeap,mxHeap,allocHeap,freeHeap,WCthMin,WCthMax,WCthPeak,WCthNow,ORBthMin,ORBthMax,ORBthPeak,ORBthNow,DSmin,DSmax,DSnow,DSfree'
		else: print 'Date,Time,AppServer,mnHeap,mxHeap,allocHeap,freeHeap,WCthMin,WCthMax,WCthPeak,WCthNow,ORBthMin,ORBthMax,ORBthPeak,ORBthNow'
	elif (printHeader):
		if (dsExists):
			print '%-19s  %-30s %13s %21s %23s %23s %23s' % ("","","Heap Config","Heap Runtime","Web Container Threads","ORB Container Threads","Database Connections")
			print '%-19s  %-30s %6s %6s %10s %10s %5s %5s %5s %5s %5s %5s %5s %5s %5s %5s %5s %5s' % ("Date and Time mark","Application Server","Min","Max","Alloc","Free","Min","Max","Peak","Now","Min","Max","Peak","Now","Min","Max","Pool","Free")
		else:
			print '%-19s  %-30s %13s %21s %23s %23s' % ("","","Heap Config","Heap Runtime","Web Container Threads","ORB Container Threads")
			print '%-19s  %-30s %6s %6s %10s %10s %5s %5s %5s %5s %5s %5s %5s %5s' % ("Date and Time mark","Application Server","Min","Max","Alloc","Free","Min","Max","Peak","Now","Min","Max","Peak","Now")
	if (serverExists):
		while 1:
			# Process server(s), get the cfg and runtime
			for serverName in serverNameList:
				jvmcfg = AdminConfig.getid('/Server:'+serverName+'/JavaProcessDef:/JavaVirtualMachine:/')
				wcPool = AdminControl.queryNames('WebSphere:name=WebContainer,type=ThreadPool,process='+serverName+',*')
	               		orbPool = AdminControl.queryNames('WebSphere:name=ORB.thread.pool,process='+serverName+',*')
	               		nodeName=jvmcfg.split('/')[3]
				jvmobj = AdminControl.queryNames('WebSphere:name=JVM,type=JVM,node='+nodeName+',process='+serverName+',*')
				if (dsExists):
					dsObj = AdminControl.queryNames('WebSphere:type=DataSource,name='+datasourceName+',process='+serverName+',*')
					printMemThreads(serverName, jvmcfg, jvmobj, wcPool, orbPool, dsObj, printCSV)
				else: printMemThreads(serverName, jvmcfg, jvmobj, wcPool, orbPool, '', printCSV)
			time.sleep(sleeptime)
	else:
		print 'Error: Unhandled parameter was passed.'
		print ''

