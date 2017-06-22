#*******************************************************************************************************
# coregroup.py
#
#   Author: James Walton
#   Initial Date: 09/03/2007
#*******************************************************************************************************
import sys
global AdminConfig
global AdminControl
global AdminTask
def usage():
        print 'Usage:'
        print '   wsadmin -lang jython -f coregroup.py -action create -coregroup <cgName>'
        print '   wsadmin -lang jython -f coregroup.py -action move (-cluster <clusterName> | -server <serverName> -node <nodeName>) -src <srcCGName> -dest <destCGName>'
        print '   wsadmin -lang jython -f coregroup.py -action modify -coregroup <cgName> -attr <attributeModifications>'
        print ''
        print 'Attributes: coord | pref'
        print 'Attribute modification examples:'
        print '   - set number of coordinators:  -attr coord:3'
        print '   - set preferred coordinators:  -attr pref:nodeagent,node1_cust_m2m,node2_cust_m2m'
        print '        *Note1 - specifying nodeagent once will include all possible nodeagents'
        print '        *Note1 - the preferred list is cumulative, you cannot use this to append servers'
#*******************************************************************************************************
# Jacl2Jython generated functions and imports (borrowed from other converted scripts)
#*******************************************************************************************************
def checkNode(nodeName):
	nodeID = AdminConfig.getid('/Node:'+nodeName+'/' )
	if (nodeID == ''):
		#Possibly bad node name given (or node has e1/e0), check list of nodes for a possible match
		nodeList = AdminConfig.list('Node').splitlines()
		for n in nodeList:
			nName = AdminConfig.showAttribute(n, 'name' )
			if (nName.find(nodeName) >= 0 ):
				nodeName = nName
				break 
		nodeID = AdminConfig.getid('/Node:'+nodeName+'/' )
		if (nodeID == ''):
			print 'Could not find given node ('+nodeName+'), exiting...'
			sys.exit()
	return nodeName

#*******************************************************************************************************
# Commandline parameter handling
#*******************************************************************************************************
argerr, moveCluster, moveServer = 0,0,0
createM2M = 'false'
coreGroup = 'DefaultCoreGroup'
actionList = ['create','move','list','modify']

i = 0
argc=len(sys.argv)
while ( i < argc):
        arg = sys.argv[i]
        if (arg == '-action'):
                i+=1
                if (i < argc): actionName = sys.argv[i]
                else: argerr = 2
        elif (arg == '-coregroup'):
                i+=1
                if (i < argc): cgName = sys.argv[i]
                else: argerr = 3
        elif (arg == '-server'):
                i+=1
                if (i < argc):
                        serverName = sys.argv[i]
                        moveServer = 1
                else: argerr = 4
        elif (arg == '-node'):
                i+=1
                if (i < argc): nodeName = sys.argv[i]
                else: argerr = 5
        elif (arg == '-cluster'):
                i+=1
                if (i < argc):
                        clusterName = sys.argv[i]
                        moveCluster = 1
                else: argerr = 6
        elif (arg == '-src'):
                i+=1
                if (i < argc): srcName = sys.argv[i]
                else: argerr = 7
        elif (arg == '-dest'):
                i+=1
                if (i < argc): destName = sys.argv[i]
                else: argerr = 8
        elif (arg == '-attr'):
		i += 1
                if (i < argc): attrMod = sys.argv[i]
                else: argerr = 9
        else: argerr = 10
        i+=1
#endWhile

actionExists = ('actionName' in locals().keys() or 'actionName' in globals().keys())
cgExists = ('cgName' in locals().keys() or 'cgName' in globals().keys())
serverExists = ('serverName' in locals().keys() or 'serverName' in globals().keys())
nodeExists = (('nodeName' in locals().keys() or 'nodeName' in globals().keys()) and not nodeName == '')
clusterExists = ('clusterName' in locals().keys() or 'clusterName' in globals().keys())
srcExists = ('srcName' in locals().keys() or 'srcName' in globals().keys())
destExists = ('destName' in locals().keys() or 'destName' in globals().keys())
attrExists = ('attrMod' in locals().keys() or 'attrMod' in globals().keys())
#*******************************************************************************************************
# Verify valid parameters were passed
#*******************************************************************************************************
if (not actionExists): argerr = 11
else:
	try: actionList.index(actionName)
	except: argerr = 12
	if (actionName == 'create' and not cgExists): argerr = 13
	if (actionName == 'move' and (not clusterExists or not serverExists) and not srcExists and not destExists):
        	argerr = 14
    	if (serverExists and not nodeExists): argerr = 15
    	if (actionName == 'modify' and not cgExists and not attrExists): argerr = 16

if (argerr):
	print 'Invalid command line invocation (reason code '+str(argerr)+').'
	usage()
        sys.exit()

#*******************************************************************************************************
# Decipher and Perform Requested Action
#*******************************************************************************************************

if (actionName == 'create'):
        # Create New CoreGroup
       	args = '[-coreGroupName '+cgName+']'
       	AdminTask.createCoreGroup(args)
        print 'Saving configuration...'
        AdminConfig.save( )
        print 'You must synchronize your changes across the cell for them to fully take effect.'
elif (actionName == 'move'):
        # Move Server or Cluster to a different CoreGroup
        if (moveServer):
        	nodeName=checkNode(nodeName)
        	#Need to check if server is stopped...
        	srvObj=AdminControl.completeObjectName('WebSphere:name='+serverName+',node='+nodeName+',*')
		if (srvObj != ''):
        		print 'WARNING: Server ('+serverName+') should be stopped before moving core groups.'
        		sys.exit()
        	args = '[-source '+srcName+' -target '+destName+' -nodeName '+nodeName+' -serverName '+serverName+']'
        	AdminTask.moveServerToCoreGroup(args)
        elif (moveCluster):
        	#Need to check if cluster is stopped...
		clrObj=AdminControl.completeObjectName('WebSphere:type=Cluster,name='+clusterName+',*')
		clrState=AdminControl.invoke(clrObj, 'getState')
        	if (clrState != 'websphere.cluster.stopped'):
        		print 'WARNING: Cluster ('+clusterName+') should be stopped before moving core groups.'
        		sys.exit()
        	args = '[-source '+srcName+' -target '+destName+' -clusterName '+clusterName+']'
        	AdminTask.moveClusterToCoreGroup(args)
        else:
		print 'Error - some how you managed a move request of an unsupported object...'
		sys.exit()
        
	print 'Saving configuration...'
        AdminConfig.save()
        print 'You must synchronize your changes across the cell for them to fully take effect.'
elif (actionName == 'list'):
	#List all core groups in the cell
	cgList=AdminConfig.list('CoreGroup')
	for cg in cgList:
		print AdminConfig.showAttribute(cg,'name')
elif (actionName == 'modify'):
	# Break up attr parameter to get the name
        attrName = attrMod.split(':')[0]
        attrValues = attrMod.split(':')[1]
        attrTmp = attrMod.split(':')[1:]
        print 'Modifying '+attrName+' for '+cgName+' with '+str(attrTmp)
        if (attrName == 'coord'):
        	cgcfg = AdminConfig.getid('/CoreGroup:'+cgName+'/')
        	try: AdminConfig.modify(cgcfg, [['numCoordinators', attrValues]])
                except:
                        print 'Error occurred while modifying core group coordinator count - exiting without save.'
                        print 'Error details:',sys.exc_info()
                        sys.exit()
                AdminConfig.save()
                print 'The configuration changes have been saved.'
                print 'Changes should be synchronized, and all core group coordinators will need to be restarted.'
        if (attrName == 'pref'):
        	cgcfg = AdminConfig.getid('/CoreGroup:'+cgName+'/')
        	prefList = attrValues.split(',')
        	prefServers = ''
        	for psrv in prefList:
        		cgsID = AdminConfig.getid('/CoreGroup:'+cgName+'/CoreGroupServer:'+psrv+'/')
        		if (prefServers == ''): prefServers = cgsID
        		else: prefServers = prefServers+' '+cgsID
        	try: AdminConfig.modify(cgcfg, [['preferredCoordinatorServers', prefServers]])
                except:
                        print 'Error occurred while modifying core group preferred coordinators - exiting without save.'
                        print 'Error details:',sys.exc_info()
                        sys.exit()
                AdminConfig.save()
                print 'The configuration changes have been saved.'
                print 'Changes should be synchronized, and all core group coordinators will need to be restarted.'
else: print 'Invalid action specified and somehow slipped under the radar - please try again.'
