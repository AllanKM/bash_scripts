#*******************************************************************************************************
# nodegroup.py
#
#   Author: James Walton
#   Initial Date: 06/11/2010
#*******************************************************************************************************
import sys
global AdminConfig
global AdminTask
def usage():
        print 'Usage:'
        print '   wsadmin -lang jython -f nodegroup.py -action list'
        print '   wsadmin -lang jython -f nodegroup.py -action create -group <ngName>'
        print '   wsadmin -lang jython -f nodegroup.py -action add -node <nodeName> -group <ngName>'

def checkNode(nodeName):
	nodeID = AdminConfig.getid('/Node:'+nodeName+'/' )
	if (nodeID == ''):
		#Possibly bad node name given, check list of nodes for a possible match
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
argerr = 0
actionList = ['create','add','list']

i = 0
argc=len(sys.argv)
while ( i < argc):
        arg = sys.argv[i]
        if (arg == '-action'):
                i+=1
                if (i < argc): actionName = sys.argv[i]
                else: argerr = 2
        elif (arg == '-group'):
                i+=1
                if (i < argc): ngName = sys.argv[i]
                else: argerr = 3
        elif (arg == '-node'):
                i+=1
                if (i < argc):
                        nodeName = sys.argv[i]
                else: argerr = 4
        else: argerr = 5
        i+=1
#endWhile

actionExists = ('actionName' in locals().keys() or 'actionName' in globals().keys())
ngExists = ('ngName' in locals().keys() or 'ngName' in globals().keys())
nodeExists = (('nodeName' in locals().keys() or 'nodeName' in globals().keys()) and not nodeName == '')
#*******************************************************************************************************
# Verify valid parameters were passed
#*******************************************************************************************************
if (not actionExists): argerr = 6
else:
	try: actionList.index(actionName)
	except: argerr = 7
	if (actionName == 'create' and not ngExists): argerr = 8
	if (actionName == 'add' and not nodeExists and not ngExists): argerr = 9

if (argerr):
	print 'Invalid command line invocation (reason code '+str(argerr)+').'
	usage()
        sys.exit()

#*******************************************************************************************************
# Decipher and Perform Requested Action
#*******************************************************************************************************

if (actionName == 'create'):
        # Create New NodeGroup
        print 'Creating nodegroup: '+ngName
       	try: AdminTask.createNodeGroup(ngName)
       	except:
       		print 'Error: creation of node group ('+ngName+') failed - exiting.'
                print 'Error details:',sys.exc_info()
                sys.exit()
        print 'Saving configuration...'
        AdminConfig.save()
        print 'You must synchronize your changes across the cell for them to fully take effect.'
elif (actionName == 'add'):
        # Add node to a new NodeGroup
    	nodeName=checkNode(nodeName)
    	args = '[-nodeName '+nodeName+']'
    	print 'Adding node '+nodeName+' to nodegroup '+ngName
    	try: AdminTask.addNodeGroupMember(ngName, args)
        except:
        	print 'Error: adding node ('+nodeName+') to node group ('+ngName+') failed - exiting.'
                print 'Error details:',sys.exc_info()
                sys.exit()
	print 'Saving configuration...'
        AdminConfig.save()
        print 'You must synchronize your changes across the cell for them to fully take effect.'
elif (actionName == 'list'):
	#List all node groups in the cell
	ngList=AdminConfig.list('NodeGroup')
	for ng in ngList:
		print AdminConfig.showAttribute(ng,'name')
else: print 'Invalid action specified and somehow slipped under the radar - please try again.'
