#*******************************************************************************************************
# cluster.py -- based on migration from clusterAction.jacl
#
#   Author: James Walton
#   Initial Revision Date: 08/27/2007
#*******************************************************************************************************
import sys
global AdminConfig
global AdminTask
def usage():
	print 'Usage:'
	print '   wsadmin -lang jython -f cluster.py -action <actionName> -cluster <clusterName> [-m2m]'
        print '   wsadmin -lang jython -f cluster.py -action list'
        print '   wsadmin -lang jython -f cluster.py -action add -cluster <clusterName> -member <memberName> -node <nodeName> [-template <templateName>] [-vhost <vhostName>] [-cookie <cookieName>] [-coregroup <coregroupName>] [-m2m]'
        print '   wsadmin -lang jython -f cluster.py -action modify -cluster <clusterName> -attr <attributeModifications>'
        print ''
        print '  Actions: start | stop | list | status | members | create | add'
        print '  Attributes: nodegroup'
        print ''
        print '  Executes the selected action on cluster <clusterName>.'
        print '   -The list action requires no additional arguments as it lists all clusters in the cell.'
        print '   -The add action will create a new member <memberName> on node <nodeName> in cluster <clusterName>'
        print '    using template <templateName>, but if no template is given ei_template_all will be used by default.'
        print '  If a cluster has existing members, the template is not needed as the new member will use the cluster\'s default.'
        print '  Specifying a virtual host will override the default_host that the EI templates provide.'
        print '  Specifying the cookie will override the default session cookie name (JSESSIONID) that WebSphere provides.'
        print '  The -m2m flag will setup a replication domain for the cluster and replicator entries for members.'
        print ''
	print 'Attribute modification examples:'
        print '   - new node group:	  -attr nodegroup:ReplicationZone_CUSTOMER_P1'

#*******************************************************************************************************
# Functions
#*******************************************************************************************************
def postCreationMemberEdit ( memberName, vhostName, cookieName ):
        # Modify the virtual host if one was specified as an argument.
        if(vhostName != ''):
	        vhosts = AdminConfig.list('VirtualHost').splitlines()
	        # Check list of vhosts, make sure the one given is valid
	        for host in vhosts:
	                vhname = AdminConfig.showAttribute(host, 'name')
	                if (vhname == vhostName): break 
	                else: vhname = ''
	        if (vhname == ''):
	                print 'Error: Virtual Host specified does not exist and was therefore not modified.'
	                print 'Defaulted to virtual host as configured in the application server template '
	        else:
	                webcontainer = AdminConfig.getid('/Server:'+memberName+'/ApplicationServer:/WebContainer:/' )
	                print AdminConfig.modify(webcontainer, [['defaultVirtualHostName', vhostName]] )
	else: print 'No virtual host provided, cluster member will not be modified.'
        # Modify the session cookie if one was specified as an argument.
        if (cookieName != ''):
                asCookie = AdminConfig.getid('/Server:'+memberName+'/ApplicationServer:/WebContainer:/SessionManager:/Cookie:/' )
                try: AdminConfig.modify(asCookie, [['name', cookieName]] )
                except:
                        print 'Error: modifying session cookie name failed - all other changes will be saved'
                        print 'Error details:',sys.exc_info()
        else: print 'No cookie name provided, cluster member will not be modified.'

def getTemplate(templateName):
	# Check configs for template provided
	sTemplate = AdminConfig.listTemplates('Server', templateName)
	# If no matches, use default; if more than one match, search for the exact match
	if (len(sTemplate) == 0): return 'ei_template_all'
	elif (len(sTemplate.splitlines()) > 1):
		sTemplate=sTemplate.splitlines()
		for template in sTemplate:
			tName = AdminConfig.showAttribute(template, 'name')
			if (tName == templateName): return tName
	else: return templateName

def checkCoreGroup(coreGroup):
	cgList = AdminConfig.list('CoreGroup').splitlines()
	# Pull the full list of core groups, search for the one provided, use default if none found.
	for cg in cgList:
		cgName=AdminConfig.showAttribute(cg, 'name')
		if(cgName == coreGroup): return coreGroup
	print 'No matching core group found, creating core group: '+coreGroup
       	args = '[-coreGroupName '+coreGroup+']'
       	AdminTask.createCoreGroup(args)
	return coreGroup

#*******************************************************************************************************
# Commandline parameter handling
#*******************************************************************************************************
argerr = 0
createM2M = 'false'
coreGroup = 'DefaultCoreGroup'
actionList= ['start','stop','list','status','members','create','add','modify']

i = 0
argc=len(sys.argv)
while ( i < argc):
        arg = sys.argv[i]
        if (arg == '-action'):
                i+=1 
                if (i < argc): actionName = sys.argv[i]
                else: argerr = 2
        elif (arg == '-cluster'):
                i+=1 
                if (i < argc): clusterName = sys.argv[i]
                else: argerr = 3
        elif (arg == '-member'):
                i+=1 
                if (i < argc): memberName = sys.argv[i]
                else: argerr = 4
        elif (arg == '-node'):
                i+=1 
                if (i < argc): nodeName = sys.argv[i]
                else: argerr = 5
        elif (arg == '-template'):
                i+=1 
                if (i < argc): templateName = sys.argv[i]
                else: argerr = 6
        elif (arg == '-vhost'):
                i+=1 
                if (i < argc): vhostName = sys.argv[i]
                else: argerr = 7
        elif (arg == '-cookie'):
                i+=1 
                if (i < argc): cookieName = sys.argv[i]
                else: argerr = 8
        elif (arg == '-coregroup'):
                i+=1 
                if (i < argc): coreGroup = sys.argv[i]
                else: argerr = 9
	elif (arg == '-attr'):
		i += 1
                if (i < argc): attrMod = sys.argv[i]
                else: argerr = 10
        elif (arg == '-m2m'): createM2M = 'true'
        else: argerr = 11
        i+=1
#endWhile

actionExists = ('actionName' in locals().keys() or 'actionName' in globals().keys())
clusterExists = ('clusterName' in locals().keys() or 'clusterName' in globals().keys())
memberExists = ('memberName' in locals().keys() or 'memberName' in globals().keys())
nodeExists = (('nodeName' in locals().keys() or 'nodeName' in globals().keys()) and not nodeName == '')
templateExists = ('templateName' in locals().keys() or 'templateName' in globals().keys())
attrExists = ('attrMod' in locals().keys() or 'attrMod' in globals().keys())
#*******************************************************************************************************
# Verify valid parameters were passed
#*******************************************************************************************************
if (not actionExists):
	argerr = 12
else:
	if (not clusterExists and actionName != 'list'): argerr = 13
	if (actionName == 'add' and not clusterExists and not memberExists and not nodeExists): argerr = 14
	if (actionName == 'modify' and not clusterExists and not attrExists): argerr = 15
	try: actionList.index(actionName)
	except: argerr = 16

if (argerr):
        print 'Invalid command line invocation (reason code '+str(argerr)+').'
        usage()
        sys.exit()

#*******************************************************************************************************
# Decipher and Perform Requested Action
#*******************************************************************************************************
vhostExists = ('vhostName' in locals().keys() or 'vhostName' in globals().keys())
cookieExists = ('cookieName' in locals().keys() or 'cookieName' in globals().keys())
if(not vhostExists): vhostName=''
if(not cookieExists): cookieName=''

if (actionName == 'start'):
        # Start entire Cluster
        clusterMgr = AdminControl.completeObjectName('type=ClusterMgr,*' )
        AdminControl.invoke(clusterMgr, 'retrieveClusters' )
        cluster = AdminControl.completeObjectName('type=Cluster,name='+clusterName+',*' )
        AdminControl.invoke(cluster, 'start' )
elif (actionName == 'stop'):
        # Stop entire Cluster
        cluster = AdminControl.completeObjectName('type=Cluster,name='+clusterName+',*' )
        AdminControl.invoke(cluster, 'stopImmediate' )
elif (actionName == 'list'):
        # Print list of clusters
        clusterList = AdminConfig.list('ServerCluster').splitlines()
        for cluster in clusterList:
                cname = cluster.split('(')[0]
                print cname
elif (actionName == 'status'):
        # Determine cluster status
        cluster = AdminControl.completeObjectName('type=Cluster,name='+clusterName+',*' )
        status = AdminControl.getAttribute(cluster, 'state' )
        cname = AdminControl.invoke(cluster, 'getClusterName' )
        print cname+': '+status
elif (actionName == 'members'):
        # Print out the list of cluster members
        cluster = AdminConfig.getid('/ServerCluster:'+clusterName+'/')
        memberList = AdminConfig.show(cluster, 'members').split('[')[2].split(']')[0].split()
        for member in memberList:
                mname = member.split('(')[0]
                print mname
elif (actionName == 'create'):
        # Create New Cluster (empty, members must be added)
       	args = '[-clusterConfig [-clusterName '+clusterName+'] -replicationDomain [-createDomain '+createM2M+']]'
       	AdminTask.createCluster(args)
       	cluster = AdminConfig.getid('/ServerCluster:'+clusterName+'/')
       	try: AdminConfig.modify(cluster, [['nodeGroupName', 'DefaultNodeGroup']])
       	except:
		print 'Error occurred while modifying cluster nodegroup - exiting without save.'
		print 'Error details:',sys.exc_info()
		sys.exit()
        print 'Saving configuration...'
        AdminConfig.save()
        print 'You must synchronize your changes across the cell for them to fully take effect.'
elif (actionName == 'add'):
        # Deploy a new cluster member to a node
        cluster = AdminConfig.getid('/ServerCluster:'+clusterName+'/')
        memberList = AdminConfig.show(cluster, 'members').split('[')[2].split(']')[0].split()
        nodeID = AdminConfig.getid('/Node:'+nodeName+'/')
        if (nodeID == ''):
                # Possibly bad node name given (or node has e1), check list of nodes for a possible match
                nodeList = AdminConfig.list('Node').splitlines()
                for n in nodeList:
                        nName = AdminConfig.showAttribute(n, 'name')
                        if (nodeName.find(nName) >= 0):
                                #Found a matching node, check if the member name has name from configs
                                if (memberName.find(nName+'_') < 0 and memberName.find(nodeName+'_') >= 0):
	                            	# Change member name, it is not using node name from configs
					i=1
					newName=nName
					args=memberName.split('_')
					# loop to rebuild the memberName, instead of regex sub (for 6.0 compat)
					while (i < len(args)):
						newName+='_'+args[i]
						i+=1
					memberName = newName
				else:
                                	print 'Node name given did not match actual node name, and neither match the cluster member name.'
					sys.exit()        
                                # Lastly, set the node name to the one from the configs
                                nodeName = nName
                                break
                # Get the node's cfg ID now that we have a valid one
                nodeID = AdminConfig.getid('/Node:'+nodeName+'/')
        if (len(memberList) < 1):
        	# This is the first member of the cluster
        	# Check for template/coregroup, or set to defaults
                if (templateExists): serverTemplate = getTemplate(templateName)
                else: serverTemplate = 'ei_template_all'
                if (coreGroup != 'DefaultCoreGroup'): coreGroup=checkCoreGroup(coreGroup)
                # Build the option list, create member, then set the vhost and cookie
                args = '[-clusterName '+clusterName+' -memberConfig [-memberNode '+nodeName+' -memberName '+memberName+' -memberWeight 2 -replicatorEntry '+createM2M+'] -firstMember [-templateName '+serverTemplate+' -nodeGroup DefaultNodeGroup -coreGroup '+coreGroup+']]'
                print AdminTask.createClusterMember(args)
                postCreationMemberEdit(memberName, vhostName, cookieName)
        else:
        	#One or more members already exist, get the template of the first member
                mName = memberList[0].split('(')[0]
                serverTemplate = AdminConfig.getid('/Server:'+mName+'/' )
                # Build the option list, create member, then set the vhost and cookie
                args = '[-clusterName '+clusterName+' -memberConfig [-memberNode '+nodeName+' -memberName '+memberName+' -memberWeight 2 -replicatorEntry '+createM2M+']]'
                print AdminTask.createClusterMember(args)
                postCreationMemberEdit(memberName, vhostName, cookieName)
        cluster = AdminConfig.getid('/ServerCluster:'+clusterName+'/')
       	try: AdminConfig.modify(cluster, [['nodeGroupName', 'DefaultNodeGroup']])
       	except:
		print 'Error occurred while modifying cluster nodegroup - exiting without save.'
		print 'Error details:',sys.exc_info()
		sys.exit()
        print 'Saving configuration...'
        AdminConfig.save( )
        print 'You must synchronize your changes across the cell for them to fully take effect.'
elif (actionName == 'modify'):
        # Modify Cluster
        # Break up attr parameter to get the name
        attrName = attrMod.split(':')[0]
        attrValues = attrMod.split(':')[1]
        attrTmp = attrMod.split(':')[1:]
        print 'Modifying '+attrName+' for '+clusterName+' to '+str(attrTmp)
        if (attrName == 'nodegroup'):
        	# Change nodegroup bounding the cluster
                cluster = AdminConfig.getid('/ServerCluster:'+clusterName+'/')
	       	try: AdminConfig.modify(cluster, [['nodeGroupName', 'DefaultNodeGroup']])
	       	except:
			print 'Error occurred while modifying cluster nodegroup - exiting without save.'
			print 'Error details:',sys.exc_info()
			sys.exit()
	        print 'Saving configuration...'
	        AdminConfig.save()
	        print 'You must synchronize your changes across the cell for them to fully take effect.'
	else:
                print 'Invalid attribute specified and somehow slipped under the radar - please try again.'
                sys.exit()
else: print 'Invalid action specified and somehow slipped under the radar - please try again.'
