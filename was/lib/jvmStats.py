#*******************************************************************************************************
# jvmStats.py -- retooling of getStats.py, based on migration from getStats.jacl
#
#   Author: James Walton
#   Initial Revision Date: 06/17/2008
#*******************************************************************************************************
def usage():
        print 'Usage:'
        print '   wsadmin -lang jython -f jvmStats.py -server <serverName> [-node <nodeName>] memory|threads [-dataSources] [-j2c ] [-csv]'
        print '   wsadmin -lang jython -f jvmStats.py -node <nodeName> memory|threads [-dataSources] [-j2c ] [-csv]'
        print '   wsadmin -lang jython -f jvmStats.py -cluster <clusterName> memory|threads [-dataSources] [-j2c ] [-csv]'
        print '   wsadmin -lang jython -f jvmStats.py -cell [-filter <searchString>] memory|threads [-dataSources] [-csv]'
        print '   wsadmin -lang jython -f jvmStats.py -infra memory|threads [-dataSources] [-j2c ] [-csv]'
        print 'Given an application server name <serverName>, this script will display the'
        print 'current free memory, current memory heap allocation, and maximum heap allowed'
        print '--OR-- the current statistics for the transport thread pool and configured min/max'
        print '--OR-- both the memory and transport statistics.'
        print ''
        print '** The cluster option can be passed a comma-delimited list of clusters to pull stats from.'
        print '** Adding the -dataSources flag will print JDBC datasource information.'
        print '** Adding the -j2c flag will print J2C connection information.'
        print '** Adding the -csv flag for operations noted will print the output in CSV (comma separated) format.'
        print 'Note: This script only works for WAS 6.1 or later'

#*******************************************************************************************************
# Jacl2Jython generated functions
#*******************************************************************************************************
import sys
import re
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
def parseClusters(clusterNames):
	memberList, cList=[],[]
	# Populate a list with the cfg ID of every member of each cluster passed
	for cluster in clusterNames:
		clId=AdminConfig.getid('/ServerCluster:'+cluster+'/')
		memberList.extend(AdminConfig.showAttribute(clId,'members').split('[')[1].split(']')[0].split())
	# Go through the members, and translate the member to a list of actual server cfg IDs
	for member in memberList:
		name=AdminConfig.showAttribute(member,'memberName')
		node=AdminConfig.showAttribute(member,'nodeName')
		cList.append(AdminConfig.getid('/Node:'+node+'/Server:'+name+'/'))
	return cList

def printMem ( nName, sName, jCfg, jObj, csv ):
        # If we have a valid runtime object (i.e. not blank), get the current heap info, otherwise put in placeholders
        if (len(jObj) > 0):
                jvmheap = AdminControl.getAttribute(jObj, 'heapSize')
                jvmfree = AdminControl.getAttribute(jObj, 'freeMemory')
        else:
                jvmheap = 'NA'
                jvmfree = 'NA'
        # Get the configured heap settings
        jvmmax = AdminConfig.showAttribute(jCfg, 'maximumHeapSize')
        jvmmin = AdminConfig.showAttribute(jCfg, 'initialHeapSize')
        # If this isn't a nodeagent or dmgr, then strip the node name from the appserver string (as is the EI standard naming)
        # we don't need it, as we'll print the node out as well anyway.
        if (sName != 'nodeagent' and sName != 'dmgr'):
                srvComps = sName.split('_')[1:]
                sName = ''
                for comp in srvComps:
                	sName = sName+'_'+comp
                sName=sName[1:]
        # Determine the formatting requested, and spit out the data
        if (csv):
                print nName+','+sName+','+jvmmin+','+jvmmax+','+jvmheap+','+jvmfree
        else:
                print "%-10s %-20s %-5s / %-6s %-10s / %-10s" % (nName, sName, jvmmin, jvmmax, jvmheap, jvmfree)

def printThreadStats ( nName, sName, wcpool, orbpool, csv ):
        if (len(wcpool) > 0):
                # Pull the web container thread pool settings and stats
                wcMaxSz = AdminControl.getAttribute(wcpool, 'maximumSize')
                wcMinSz = AdminControl.getAttribute(wcpool, 'minimumSize')
                wcStats = AdminControl.getAttribute(wcpool, 'stats')
                if (len(wcStats) > 0):
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
                      # Didn't receive a valid stats attribute, no stats is possible (it was blank), prep placeholder data.
                      wcHwm, wcCur = 'NA', 'NA'
        else:
                # Didn't receive a valid web container thread pool runtime object (it was blank), prep placeholder data.
                wcMaxSz, wcMinSz = 'NA', 'NA'
                wcHwm, wcCur = 'NA', 'NA'
        if (len(orbpool) > 0):
                # Pull the orb thread pool settings and stats
                orbMaxSz = AdminControl.getAttribute(orbpool, 'maximumSize')
                orbMinSz = AdminControl.getAttribute(orbpool, 'minimumSize')
                orbStats = AdminControl.getAttribute(orbpool, 'stats')
                if (len(orbStats) > 0):
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
                     # Didn't receive a orb stats runtime object (it was blank), prep placeholder data.
                     orbHwm, orbCur = 'NA', 'NA'
        else:
                # Didn't receive a valid orb thread pool runtime object (it was blank), prep placeholder data.
                orbMaxSz, orbMinSz = 'NA', 'NA'
                orbHwm, orbCur = 'NA', 'NA'
	# If this isn't a nodeagent or dmgr, then strip the node name from the appserver string (as is the EI standard naming)
        # we don't need it, as we'll print the node out as well anyway.
	if (sName != 'nodeagent' and sName != 'dmgr'):
                srvComps = sName.split('_')[1:]
                sName = ''
                for comp in srvComps:
                	sName = sName+'_'+comp
                sName=sName[1:]
        # Determine the formatting requested, and spit out the data
        if (csv):
                print nName+','+sName+','+wcMinSz+','+wcMaxSz+','+wcHwm+','+wcCur+','+orbMinSz+','+orbMaxSz+','+orbHwm+','+orbCur
        else:
               print "%-10s %-20s {%3s / %3s} (%3s / %3s)  {%3s / %3s} (%3s / %3s)" % (nName, sName, wcMinSz, wcMaxSz, wcHwm, wcCur, orbMinSz, orbMaxSz, orbHwm, orbCur)
#endDef

def printDataSourceStats(nName, sName, ds):
        # Include only DB2 DataSource information
        objectName = AdminControl.getAttribute(ds,'objectName')
        idx = objectName.find('JDBCProvider=DB2')
        if (idx > 0):
            dsName     = AdminControl.getAttribute(ds,"name")
            print ''
            print '-----------------------------------------------------------------------------------------------------------------------------'
            print "JDBC DataSource Information for Node: %s, Server: %s, DataSource: %s "   % (nName, sName, dsName)
            print '-----------------------------------------------------------------------------------------------------------------------------'
            print ''
            print AdminControl.invoke(ds,"showPoolContents")
#endDef

def printJ2CConnectionStats(nName, sName, j2c):
        j2cName = AdminControl.getAttribute(j2c,"name")        
        print ''
        print '--------------------------------------------------------------------------------------------------'
        print "J2C Connection Information for Node: %s, Server: %s, J2C Provider: %s "   % (nName, sName, j2cName)
        print '--------------------------------------------------------------------------------------------------'
        print ''
        print AdminControl.invoke(j2c,"showPoolContents")
#endDef

#*******************************************************************************************************
# Commandline parameter handling
#*******************************************************************************************************
argerr, checkMem, checkThreads, checkDataSources, checkJ2C = 0,0,0,0,0
pollCell, pollInfra, printCSV = 0,0,0
if ( ('nodeName' in locals().keys() or 'nodeName' in globals().keys()) ): nodeName = ''

i = 0
argc=len(sys.argv)
while ( i < argc ):
        arg = sys.argv[i]
        if (arg == '-server'):
                i += 1
                if (i < argc): serverName = sys.argv[i]
                else: argerr = 1
        elif (arg == '-cluster'):
                i += 1
                # Clusters can be comma-delimited, so split up a list
                if (i < argc): clusterNames = sys.argv[i].split(',')
                else: argerr = 2
                # Prep the member appserver id list, we'll need it no matter what for this option
                memberIDList=parseClusters(clusterNames)
        elif (arg == '-node'):
                i += 1
                if (i < argc): nodeName = sys.argv[i]
                else: argerr = 3
        elif (arg == '-filter'):
                i += 1
                pollCell = 1
                if (i < argc): filterArg = sys.argv[i]
                else: argerr = 4
        elif (arg == '-infra'):
                pollInfra = 1
                infraList = 'nodeagent dmgr'
        elif (arg == '-cell'): pollCell = 1
        elif (arg == '-csv'): printCSV = 1
        elif (arg == 'memory'): checkMem = 1
        elif (arg == 'threads'): checkThreads = 1
        elif (arg == '-dataSources'): checkDataSources = 1
        elif (arg == '-j2c'): checkJ2C = 1
        else: argerr = 5
        i += 1

serverExists = ('serverName' in locals().keys() or 'serverName' in globals().keys())
nodeExists = (('nodeName' in locals().keys() or 'nodeName' in globals().keys()) and not nodeName == '')
filterExists = ('filterArg' in locals().keys() or 'filterArg' in globals().keys())
clusterExists = ('clusterNames' in locals().keys() or 'clusterNames' in globals().keys())
#*******************************************************************************************************
# Verify valid parameters were passed
#*******************************************************************************************************
if (nodeExists and (pollCell or pollInfra or clusterExists)): argerr = 6
if ((checkMem == 0 and checkThreads == 0) and (serverExists or clusterExists)): argerr = 7
if (serverExists and (pollCell or pollInfra)): argerr = 8
if (pollCell and pollInfra): argerr = 9

if (argerr):
        print 'Invalid command line invocation (reason code '+str(argerr)+').'
        usage()
        sys.exit()

#*******************************************************************************************************
# Decipher and Perform Requested Action
#*******************************************************************************************************
if (checkMem):
	if (printCSV):
		print 'Nodename,AppServer,MinHeap,MaxHeap,AllocHeap,FreeHeap'
	else:
         print '-----------------------------------------------------------------------'
         print 'Nodename  | AppServer          | Min/Max Heap | Allocated/Free Heap    '
         print '-----------------------------------------------------------------------'
	if (pollCell or pollInfra):
		# Going to churn through the full server list
		for server in AdminConfig.list('Server').splitlines():
			serverName = server.split('(')[0]
			if (pollInfra):
				# If server is not one of the infrastructure bits (nodeagent, etc), skip it.
				try: infraList.index(serverName)
				except:	continue
			elif (filterExists):
				# If server doesn't match the given filter, skip it.
				if (serverName.find(filterArg) < 0): continue
			elif (re.match('^DC_', server) != None): continue
			# Get the official node name, JVM config ID, and the JVM runtime object (if it's running), call the print function
			nodeName = server.split('/')[3]
			jvmcfg = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/JavaProcessDef:/JavaVirtualMachine:/')
			jvmobj = AdminControl.queryNames('WebSphere:type=JVM,node='+nodeName+',process='+serverName+',*')
			printMem(nodeName, serverName, jvmcfg, jvmobj, printCSV)
	elif (clusterExists):
		# Process the list of cluster members
		for member in memberIDList:
			# Traverse down the attributes to get the JVM cfg ID, use the server name to get the runtime obj
			procDef=AdminConfig.showAttribute(member,'processDefinitions').split('[')[1].split(']')[0]
			serverName=AdminConfig.showAttribute(member,'name')
			nodeName=member.split('/')[3]
			jvmcfg=AdminConfig.showAttribute(procDef,'jvmEntries').split('[')[1].split(']')[0]
			jvmobj = AdminControl.queryNames('WebSphere:name=JVM,type=JVM,node='+nodeName+',process='+serverName+',*')
			printMem(nodeName, serverName, jvmcfg, jvmobj, printCSV)
	elif (serverExists):
		# Process a single server, get the cfg and runtime
		if (nodeExists):
			# A node name was specified - used mostly for nodeagents as you need the node to differentiate.
			jvmcfg = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/JavaProcessDef:/JavaVirtualMachine:/')
		else:
			jvmcfg = AdminConfig.getid('/Server:'+serverName+'/JavaProcessDef:/JavaVirtualMachine:/')
			nodeName=jvmcfg.split('/')[3]
		jvmobj = AdminControl.queryNames('WebSphere:name=JVM,type=JVM,node='+nodeName+',process='+serverName+',*')
		printMem(nodeName, serverName, jvmcfg, jvmobj, printCSV)
	elif (nodeExists):
		# Process entire node, get the cfg list and runtime list
		sidList=AdminConfig.getid('/Node:'+nodeName+'/Server:/').splitlines()
		#serverList=[]
		for sid in sidList:
			#serverList.append(AdminConfig.showAttribute(sid,'name'))
			serverName=AdminConfig.showAttribute(sid,'name')
			jvmcfg = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/JavaProcessDef:/JavaVirtualMachine:/')
			jvmobj = AdminControl.queryNames('WebSphere:name=JVM,type=JVM,node='+nodeName+',process='+serverName+',*')
			printMem(nodeName, serverName, jvmcfg, jvmobj, printCSV)
        else:
		print 'Error: Unhandled parameter was passed.'
        print ''
#endIf 

if (checkThreads):
        if (printCSV):
                print 'Node,AppServer,WCCfgMin,WCCfgMax,WCThPoolPeak,WCThPoolNow,ORBCfgMin,ORBCfgMax,ORBThPoolPeak,ORBThPoolNow'
        else:
                print '--------------------------------------------------------------------------------'
                print '          |                    |  WC Cfg    WC ThPool   |  ORB Cfg  ORB ThPool  '
                print 'Nodename  | AppServer          | {Min/Max} (Peak/Now)   | {Min/Max} (Peak/Now)  '
                print '--------------------------------------------------------------------------------'
        if (pollCell or pollInfra):
            # Going to churn through the full server list
            for server in AdminConfig.list('Server').splitlines():
                serverName = server.split('(')[0]
                if (pollInfra):
                    # If server is not one of the infrastructure bits (nodeagent, etc), skip it.
                    try: infraList.index(serverName)
                    except: continue 
                elif (filterExists):
                      # If server doesn't match the given filter, skip it.
                      if (serverName.find(filterArg) < 0): continue 
                # Get the official node name, thread pool config IDs, and the thread pool runtime objects (if it's running), call the print function
                nodeName = server.split('/')[3]
                wcPool = AdminControl.queryNames('WebSphere:name=WebContainer,type=ThreadPool,node='+nodeName+',process='+serverName+',*')
                orbPool = AdminControl.queryNames('WebSphere:name=ORB.thread.pool,node='+nodeName+',process='+serverName+',*')
                printThreadStats(nodeName, serverName, wcPool, orbPool, printCSV)
        elif (clusterExists):
              # Process the list of cluster members
              for member in memberIDList:
                  # Grab the server and node name to get the thread pool runtime objs
                  serverName=AdminConfig.showAttribute(member,'name')
                  nodeName=member.split('/')[3]
                  wcPool = AdminControl.queryNames('WebSphere:name=WebContainer,type=ThreadPool,node='+nodeName+',process='+serverName+',*')
                  orbPool = AdminControl.queryNames('WebSphere:name=ORB.thread.pool,node='+nodeName+',process='+serverName+',*')
                  printThreadStats(nodeName, serverName, wcPool, orbPool, printCSV)
        elif (serverExists):
              # Process a single server, get the cfg and runtime
              if (nodeExists):
                   # A node name was specified - used mostly for nodeagents as you need the node to differentiate.
                   wcPool = AdminControl.queryNames('WebSphere:name=WebContainer,type=ThreadPool,node='+nodeName+',process='+serverName+',*')
                   orbPool = AdminControl.queryNames('WebSphere:name=ORB.thread.pool,node='+nodeName+',process='+serverName+',*')
              else:
                   wcPool = AdminControl.queryNames('WebSphere:name=WebContainer,type=ThreadPool,process='+serverName+',*')
                   orbPool = AdminControl.queryNames('WebSphere:name=ORB.thread.pool,process='+serverName+',*')
              nodeName=orbPool.split(',')[listREMatch(orbPool.split(','),'node=')]
              printThreadStats(nodeName, serverName, wcPool, orbPool, printCSV)
        elif (nodeExists):
              # Process entire node, get the cfg list and runtime list
              sidList=AdminConfig.getid('/Node:'+nodeName+'/Server:/').splitlines()
              #serverList=[]
              for sid in sidList:
                  #serverList.append(AdminConfig.showAttribute(sid,'name'))
                  serverName=AdminConfig.showAttribute(sid,'name')
                  wcPool = AdminControl.queryNames('WebSphere:name=WebContainer,type=ThreadPool,node='+nodeName+',process='+serverName+',*')
                  orbPool = AdminControl.queryNames('WebSphere:name=ORB.thread.pool,node='+nodeName+',process='+serverName+',*')
                  printThreadStats(nodeName, serverName, wcPool, orbPool, printCSV)
        else:
              print 'Error: Unhandled parameter was passed.'
              print ''
#endIf 

if (checkDataSources):
        if (printCSV):
                print '----------------------------------------------------------------------------------------------------'
                print 'Comma separated format is not supported for Datasource information, bypassing DataSource collection '
                print '----------------------------------------------------------------------------------------------------'                
        else:
                print ''
                print ''
                print '-----------------------------------------------------------------------------'
                print '                    Gathering DataSource Information '
                print '-----------------------------------------------------------------------------'
                if (pollCell or pollInfra):
                    # Going to churn through the full server list
                    for server in AdminConfig.list('Server').splitlines():
                        serverName = server.split('(')[0]
                        if (pollInfra):
                            # If server is not one of the infrastructure bits (nodeagent, etc), skip it.
                            try: infraList.index(serverName)
                            except: continue 
                        elif (filterExists):
                              # If server doesn't match the given filter, skip it.
                              if (serverName.find(filterArg) < 0): continue 
                              # Get the official node name,the data source runtime objects (if it's running), call the print function
                              nodeName = server.split('/')[3]
                              dsList = AdminControl.queryNames("*:type=DataSource,node="+nodeName+",process="+serverName+",*").splitlines()
                              for ds in dsList:
                                  printDataSourceStats(nodeName, serverName, ds)
                elif (clusterExists):
                      # Process the list of cluster members
                      for member in memberIDList:
                          # Grab the server and node name to get the data source runtime objects
                          serverName=AdminConfig.showAttribute(member,'name')
                          nodeName=member.split('/')[3]
                          # Get the data source runtime objects (if it's running), call the print function
                          dsList = AdminControl.queryNames("*:type=DataSource,node="+nodeName+",process="+serverName+",*").splitlines()
                          for ds in dsList:
                              printDataSourceStats(nodeName, serverName, ds)
                elif (serverExists):
                      # Process a single server, get the cfg and runtime
                      if (nodeExists):
                         # A node name was specified - used mostly for nodeagents as you need the node to differentiate.
                           dsList = AdminControl.queryNames("*:type=DataSource,node="+nodeName+",process="+serverName+",*").splitlines()
                      else:                        
                           dsList = AdminControl.queryNames("*:type=DataSource,process="+serverName+",*")                        
                      for ds in dsList:
                          printDataSourceStats(nodeName, serverName, ds)
                elif (nodeExists):
                      # Process entire node, get the cfg list and runtime list
                      sidList=AdminConfig.getid('/Node:'+nodeName+'/Server:/').splitlines()
                      for sid in sidList:
                          serverName=AdminConfig.showAttribute(sid,'name')
                          dsList = AdminControl.queryNames("*:type=DataSource,node="+nodeName+",process="+serverName+",*").splitlines()
                          for ds in dsList:
                              printDataSourceStats(nodeName, serverName, ds)
                else:
                     print 'Error: Unhandled parameter was passed.'
                     print ''
#endIf

if (checkJ2C):
        if (printCSV):
                print '----------------------------------------------------------------------------------------------------'
                print 'Comma separated format is not supported for J2C Connection information, bypassing J2C collection    '
                print '----------------------------------------------------------------------------------------------------'
        else:
                print ''
                print ''
                print '-----------------------------------------------------------------------------'
                print '                    Gathering J2C Connection Information '
                print '-----------------------------------------------------------------------------'
                if (pollCell or pollInfra):
                    # Going to churn through the full server list
                    for server in AdminConfig.list('Server').splitlines():
                        serverName = server.split('(')[0]
                        if (pollInfra):
                            # If server is not one of the infrastructure bits (nodeagent, etc), skip it.
                            try: infraList.index(serverName)
                            except: continue 
                        elif (filterExists):
                              # If server doesn't match the given filter, skip it.
                              if (serverName.find(filterArg) < 0): continue 
                              # Get the official node name,the data source runtime objects (if it's running), call the print function
                              nodeName = server.split('/')[3]
                              j2cList = AdminControl.queryNames("*:type=J2CConnectionFactory,node="+nodeName+",process="+serverName+",*").splitlines()
                              for j2c in j2cList:
                                  printJ2CConnectionStats(nodeName, serverName, j2c)
                elif (clusterExists):
                      # Process the list of cluster members
                      for member in memberIDList:
                          # Grab the server and node name to get the data source runtime objects
                          serverName=AdminConfig.showAttribute(member,'name')
                          nodeName=member.split('/')[3]
                          # Get the official node name,the data source runtime objects (if it's running), call the print function
                          nodeName = server.split('/')[3]
                          j2cList = AdminControl.queryNames("*:type=J2CConnectionFactory,node="+nodeName+",process="+serverName+",*").splitlines()
                          for j2c in j2cList:
                              printJ2CConnectionStats(nodeName, serverName, j2c)
                elif (serverExists):
                      # Process a single server, get the cfg and runtime
                      if (nodeExists):
                         # A node name was specified - used mostly for nodeagents as you need the node to differentiate.
                           j2cList = AdminControl.queryNames("*:type=J2CConnectionFactory,node="+nodeName+",process="+serverName+",*").splitlines()
                      else:                        
                           j2cList = AdminControl.queryNames("*:type=J2CConnectionFactory,process="+serverName+",*")                        
                      for j2c in j2cList:
                          printJ2CConnectionStats(nodeName, serverName, j2c)
                elif (nodeExists):
                      # Process entire node, get the cfg list and runtime list
                      sidList=AdminConfig.getid('/Node:'+nodeName+'/Server:/').splitlines()
                      for sid in sidList:
                          serverName=AdminConfig.showAttribute(sid,'name')
                          j2cList = AdminControl.queryNames("*:type=J2CConnectionFactory,node="+nodeName+",process="+serverName+",*").splitlines()
                          for j2c in j2cList:
                              printJ2CConnectionStats(nodeName, serverName, j2c)
                else:
                     print 'Error: Unhandled parameter was passed.'
                     print ''
#endIf  