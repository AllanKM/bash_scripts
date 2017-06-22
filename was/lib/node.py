#*******************************************************************************************************
# node.py -- based on migration from nodeAction.jacl
#
#   Author: James Walton
#   Revision Date: 04/12/2006
#*******************************************************************************************************
import sys
def usage():
	print 'Usage:'
        print '   wsadmin -lang jython -f node.py -action <actionName> [-node <nodeName> | -cell ]'
        print '   wsadmin -lang jython -f node.py -action setup -node <nodeName> -type <nodeType>'
        print '  Actions:'
        print '      sync    -   Synchronize the configuration'
        print '      refresh -   Refresh the configuration repository (full synchronize)'
        print '      setup   -   Configure nodeagent with standard File synchronization and logging (-cell is invalid for this)'
        print '      status  -   Print synchronization status for a given node (synchronized or not)'
        print '  Node Types:'
        print '      nodeagent  -   Setup EI common configurations for nodeagents'
        print '      dmgr       -   Setup EI common configurations for deployment managers'
        print '      server1    -   Setup EI common configurations for standalone node'
        print ''
        print 'Executes the selected action on node <nodeName> or for each node in the cell.'
        print 'If -node <nodeName> is not given, script will assume local node is to be used,'
        print 'except for the setup action. For setup, node name and node type are required.'

#*******************************************************************************************************
# Functions
#*******************************************************************************************************
global AdminControl
global AdminConfig
def checkSync(nodeName):
        if (AdminControl.queryNames('WebSphere:name=nodeSync,process=nodeagent,type=NodeSync,node='+nodeName+',*') != ''):
                nodeSync = AdminControl.queryNames('WebSphere:name=nodeSync,process=nodeagent,type=NodeSync,node='+nodeName+',*')
                result = AdminControl.invoke(nodeSync, 'isNodeSynchronized')
                if (result == 'true'):
                        print nodeName+': IN-SYNC'
                else:
                        print nodeName+': OUT-OF-SYNC'
        else:
                print nodeName+': n/a'

def checkNode(nodeName):
        if (AdminControl.queryNames('WebSphere:name=nodeSync,process=nodeagent,type=NodeSync,node='+nodeName+',*') != ''): nodeUp = 1
        else: nodeUp = 0
        return nodeUp

#*******************************************************************************************************
# Commandline parameter handling
#*******************************************************************************************************
argerr = 0
actionList = ['sync', 'refresh', 'setup', 'status']
typeList = ['nodeagent', 'dmgr', 'server1']
if ( ('nodeName' in locals().keys() or 'nodeName' in globals().keys()) ): nodeName = ''

i = 0
argc=len(sys.argv)
while ( i < argc ):
        arg = sys.argv[i]
        if (arg == '-action'):
                i += 1
                if (i < argc): actionName = sys.argv[i]
                else: argerr = 1
        elif (arg == '-node'):
		i += 1
                if (i < argc):
                        nodeName = sys.argv[i]
                        scope = 'node'
                else: argerr = 2
        elif (arg == '-cell'):
                nodeList = AdminConfig.list('Node' )
                if (len(nodeList) > 0):
                        cellname = AdminControl.getCell()
                        scope = 'cell'
        elif (arg == '-type'):
		i += 1
                if (i < argc): nodeType = sys.argv[i]
                else: argerr = 3
        else: argerr = 4
        i += 1

actionExists = ('actionName' in locals().keys() or 'actionName' in globals().keys())
typeExists = ('nodeType' in locals().keys() or 'nodeType' in globals().keys())
nodeExists = (('nodeName' in locals().keys() or 'nodeName' in globals().keys()) and not nodeName == '')
cellExists = ('cellname' in locals().keys() or 'cellname' in globals().keys())
#*******************************************************************************************************
# Verify valid parameters were passed
#*******************************************************************************************************
if (not actionExists): argerr = 5
else:
	try: actionList.index(actionName)
	except: argerr = 6
	if (actionName == 'setup' and not nodeExists and not typeExists): argerr = 7
if (typeExists):
	try: typeList.index(nodeType)
	except: argerr = 8
else: nodeType = 'nodeagent'
if (nodeExists and cellExists): argerr = 9
if (not nodeExists and not cellExists):
        nodeName = java.lang.System.getProperty ('local.node')
        scope = 'node'

if (argerr):
        print 'Invalid command line invocation (reason code '+str(argerr)+').'
	usage()
        sys.exit()

#*******************************************************************************************************
# Decipher and Perform Requested Action
#*******************************************************************************************************
errcnt = 0
if (scope == 'node'):
        if (nodeType == 'nodeagent'):
                active = checkNode(nodeName)
                if ( not active):
                        print 'ERROR: Node '+nodeName+' is not currently running or does not exist'
                        sys.exit()
        if (actionName == 'sync'):
                # Synchronize one Node
                nodeSync = AdminControl.completeObjectName('type=NodeSync,node='+nodeName+',*')
                try: AdminControl.invoke(nodeSync, 'sync')
                except:
                	print 'Could not sync node: '+nodeName
			print 'Error details:',sys.exc_info()
                	errcnt += 1
        elif (actionName == 'refresh'):
                # Run Full Synchronization on one Node
                nodeRepo = AdminControl.completeObjectName('type=ConfigRepository,node='+nodeName+',process=nodeagent,*')
                try: AdminControl.invoke(nodeRepo, 'refreshRepositoryEpoch')
                except:
                	print 'Could not refersh node: '+nodeName
			print 'Error details:',sys.exc_info()
			errcnt += 1
        elif (actionName == 'setup'):
                # Setup initial configuration for nodeagent/dmgr
                # Set file synch settings for a nodeagent, get server cfg id regardless
                if (nodeType == 'nodeagent'):
                        nodeagent = AdminConfig.getid('/Node:'+nodeName+'/Server:'+nodeType+'/NodeAgent:/')
                        fss = AdminConfig.showAttribute(nodeagent, 'fileSynchronizationService')
                        AdminConfig.modify(fss, [['autoSynchEnabled', 'false']])
                        serverName = AdminConfig.showAttribute(nodeagent, 'server')
                else: serverName = AdminConfig.getid('/Node:'+nodeName+'/Server:'+nodeType+'/')
                ## Set log file rotation/retention
                outlog = AdminConfig.showAttribute(serverName, 'outputStreamRedirect')
                errlog = AdminConfig.showAttribute(serverName, 'errorStreamRedirect')
                AdminConfig.modify(outlog, [['rolloverType', 'TIME'], ['maxNumberOfBackupFiles', 14], ['rolloverPeriod', 24], ['baseHour', 24]])
                AdminConfig.modify(errlog, [['rolloverType', 'TIME'], ['maxNumberOfBackupFiles', 14], ['rolloverPeriod', 24], ['baseHour', 24]])
                ## Set process execution
                procexec = AdminConfig.showAttribute(AdminConfig.getid('/Node:'+nodeName+'/Server:'+nodeType+'/JavaProcessDef:/'), 'execution')
                AdminConfig.modify(procexec, [['runAsUser', 'webinst'], ['runAsGroup', 'mqm']])
                print 'Saving configuration...'
                AdminConfig.save()
                if (nodeType == 'nodeagent'):
                        print 'Ensure that the updated configuration has been synchronized to node: '+nodeName
                print 'Server '+nodeType+' on '+nodeName+' will need to be restarted for the changes to take effect.'
        elif (actionName == 'status'): checkSync(nodeName)
        else: print 'Invalid action specified and somehow slipped under the radar - please try again.'
elif (scope == 'cell'):
        if (actionName == 'sync'):
        	nodes = AdminControl.queryNames('WebSphere:name=nodeSync,process=nodeagent,type=NodeSync,*').splitlines()
        	# Execute sync for all nodes in the cell
        	for nodesync in nodes:
			try: AdminControl.invoke(nodesync, 'sync')
			except:
				print '### Could not sync node: '+nodename
				print '### Error details:',sys.exc_info()
				errcnt += 1
        elif (actionName == 'refresh'):
        	nodes = AdminControl.queryNames('WebSphere:name=nodeSync,process=nodeagent,type=ConfigRepository,*').splitlines()
        	# Execute repository epoch refresh, aka "full resynchronize"
        	for noderepo in nodes:
			try: AdminControl.invoke(noderepo, 'refreshRepositoryEpoch')
			except:
				print '### Could not refresh node: '+noderepo
				print '### Error details:',sys.exc_info()
				errcnt += 1
	elif (actionName == 'status'):
		nodes = AdminConfig.list('Node').splitlines()
        	# Poll synchronization status for all nodes (except dmgr node) in the cell
        	for node in nodes:
        		nodename = AdminConfig.showAttribute(node, 'name')
        		if (nodename.find('Manager') == -1): checkSync(nodename)
	else: print 'Invalid action specified and somehow slipped under the radar - please try again.'
else: print 'Invalid scope specified and somehow slipped under the radar - please try again.'

if (errcnt > 0): print 'Warning: '+errcnt+' node(s) did not successfully complete '+actionName
else: print 'Success!'
