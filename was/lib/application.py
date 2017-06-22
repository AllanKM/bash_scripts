#*******************************************************************************************************
# application.py -- based on migration from appAction.jacl
#
#   Author: James Walton
#   Initial Revision Date: 02/25/2008
#
#   Change History: 
#     Lou Amodeo    03-01-2013  Add support for Websphere 8.5 
#
#*******************************************************************************************************
import sys
import re
def usage():
	print 'Usage:'
	print '   wsadmin -lang jython -f application.py -action install -app <appName> -ear </pathTo/name.ear> -cluster <clusterName> [-vhost <virtualHost>]'
        print '   wsadmin -lang jython -f application.py -action update -app <appName> -ear </pathTo/name.ear> [-vhost <virtualHost>]'
        print '   wsadmin -lang jython -f application.py -action export -app <appName> -ear </pathTo/name.ear>'
        print '   wsadmin -lang jython -f application.py -action list [-server <serverName> | -cluster <clusterName> | -node <nodeName>]'
        print '   wsadmin -lang jython -f application.py -action vhost -app <appName> -vhost <virtualHost>'
	print '   wsadmin -lang jython -f application.py -action <stop|start|restart> -app <appName> -server <serverName> [-node <nodeName>]'
        print ''
        print 'Installs application <appName>, using the EAR file </pathTo/name.ear>, to cluster <clusterName>.'
        print 'The option to install to a server is purposefully not allowed.'
        print 'Updates application <appName>, using the EAR files </pathTo/name.ear>, cluster name is not needed.'
        print ''
        print 'The list action requires no additional arguments, by default it lists all applications.'
        print 'Or, the list action can be passed -cluster, -server, or -node to list only applications deployed'
        print 'on those objects.'
        print ''
        print 'The ability to stop/start/restart an individual application on a given appserver is a new feature'
        print 'which allows you to take action on a single instance of an application rather than all instances or'
        print 'all applications on a given appserver (in lieu of a full appserver restart).  Node name is optional.'
        print '  **Note: This feature should NOT be used on a regular basis'
        print '          nor as a replacement for a clean server restart!'

#*******************************************************************************************************
# Functions
#*******************************************************************************************************
def regsuball(pattern, string, replacement, flags=0):
        return re.compile(pattern, flags).sub(replacement, string)

def setVirtualHost(appName, virtualHost):
        global AdminApp
        global AdminConfig
        global AdminControl
        dmgr = AdminControl.completeObjectName('name=dmgr,type=Server,*')
	version = AdminControl.getAttribute(dmgr, 'platformVersion')
        # Check that virtualHost is valid
        print 'Verifying that virtual host is valid...'
        vhosts = AdminConfig.list('VirtualHost').splitlines()
        for host in vhosts:
                vhname = AdminConfig.showAttribute(host, 'name')
                if (vhname == virtualHost): break 
                else: vhname = ''
        # Non-valid virtual host should kick out with an error
        if (vhname == ''): return 1
        # Strip out and populate a list of modules with params
        print 'Searching for web modules...'
        webmodinfo = AdminApp.view(appName, '-MapWebModToVH')
        webmodinfo = regsuball('\n',webmodinfo,' ')
        webmodinfo = regsuball('  ',webmodinfo,' ').split()
        modVar     = 'module:'
        hostVar    = 'host:'       
        # Grab the range of info from the module info output from the first module to the last one's vhost
        modIndex = webmodinfo.index(modVar)
        if (webmodinfo[len(webmodinfo)-1] == ''):
	        webmods = webmodinfo[modIndex:len(webmodinfo)-1]
	else:
		webmods = webmodinfo[modIndex:len(webmodinfo)]
        modList = []
        # Cycle through the full list of info, convert to a list where each item is a module
        while (len(webmods) > 0):
                indexVH = webmods.index(hostVar) + 1
                modList.append(webmods[0:indexVH+1])
                if (indexVH+1 == len(webmods)): break 
                else:
                	# This is essentially a shift-like operation, to strip out the module just processed
                        tmpmods = webmods
                        bump = (indexVH + 1)
                        webmods = tmpmods[bump:len(tmpmods)] 
        # Cycle through modules, grab params, associate modules with vhost
        print 'Associating web modules with new virtual host...'
        for mod in modList:
                iMOD = mod.index(modVar) + 1
                iURI = mod.index('URI:') + 1
                iVH = mod.index(hostVar) + 1
                modName = ''
                # Set the module name, the loop is needed in case the module name has spaces in it
                for st in mod[iMOD:(iURI - 1)]:
                	if (modName != ''): modName += ' '
                	modName += st
                modURI = ''
                # Set the module URI, the loop is needed in case the URI has spaces in it
                for st in mod[iURI:(iVH - 2)]:
                	if (modURI != ''): modURI += ' '
                	modURI += st
                currentModVH = mod[iVH]
                options = [[modName, modURI, virtualHost]]
                mapOptions = ['-MapWebModToVH', options]
                AdminApp.edit(appName, mapOptions)
        # Made it through the function without error, exit cleanly
        return 0
#endDef

def getAppMgr(appNode, appServer):
	global AdminControl
	# Simple function to grab the ApplicationManager runtime control object
	if (appNode == ''): mgr=AdminControl.completeObjectName('process='+appServer+',type=ApplicationManager,*')
	else: mgr=AdminControl.completeObjectName('node='+appNode+',process='+appServer+',type=ApplicationManager,*')
	return mgr

def stopApp(appNode, appServer, app):
	global AdminControl
	# Simple function stop an app, requires getting application manager control object
	appMgr=getAppMgr(appNode,appServer)
	if (appMgr == ''): return 1
	AdminControl.invoke(appMgr,'stopApplication',app)
	return 0

def startApp(appNode, appServer, app):
	global AdminControl
	# Simple function start an app, requires getting application manager control object
	appMgr=getAppMgr(appNode,appServer)
	if (appMgr == ''): return 1
	AdminControl.invoke(appMgr,'startApplication',app)
	return 0

def outputStateResults(result, app, server, action):
	# Simple text output, didn't want to keep copy/pasting this for each app action
	if (result): print 'Error!! '+app+' was not '+action+'ed, server '+server+' might not be running or app does not exist on it'
	else: print app+' '+action+'ed successfully.'

#*******************************************************************************************************
# Commandline parameter handling
#*******************************************************************************************************
argerr = 0
if ( ('nodeName' in locals().keys() or 'nodeName' in globals().keys()) ):
        nodeName = ''

i = 0
argc=len(sys.argv)
while ( i < argc ):
        arg = sys.argv[i]
        if (arg == '-action'):
                i += 1
                if (i < argc): actionName = sys.argv[i]
                else: argerr = 2
        elif (arg == '-server'):
                i += 1
                if (i < argc): serverName = sys.argv[i]
                else: argerr = 3
        elif (arg == '-cluster'):
                i += 1
                if (i < argc): clusterName = sys.argv[i]
                else: argerr = 4
        elif (arg == '-app'):
                i += 1
                if (i < argc): appName = sys.argv[i]
                else: argerr = 5
        elif (arg == '-ear'):
                i += 1
                if (i < argc): earName = sys.argv[i]
                else: argerr = 6
        elif (arg == '-node'):
                i += 1
                if (i < argc): nodeName = sys.argv[i]
                else: argerr = 7
        elif (arg == '-vhost'):
                i += 1
                if (i < argc): virtualHost = sys.argv[i]
                else: argerr = 8
        else: argerr = 9
        i += 1
#endWhile

actionExists = ('actionName' in locals().keys() or 'actionName' in globals().keys())
appExists = ('appName' in locals().keys() or 'appName' in globals().keys())
earExists = ('earName' in locals().keys() or 'earName' in globals().keys())
clusterExists = ('clusterName' in locals().keys() or 'clusterName' in globals().keys())
serverExists = ('serverName' in locals().keys() or 'serverName' in globals().keys())
nodeExists = (('nodeName' in locals().keys() or 'nodeName' in globals().keys()) and not nodeName == '')
vhExists = ('virtualHost' in locals().keys() or 'virtualHost' in globals().keys())
#*******************************************************************************************************
# Verify valid parameters were passed
#*******************************************************************************************************
allActions='install update list export vhost stop start restart'
runtimeActions='stop start restart'
if (not actionExists):
	argerr = 10
else:
	if (actionName != 'list' and not appExists and not earExists and not clusterExists): argerr = 11
	if (allActions.find(actionName) < 0): argerr = 12
	if ((serverExists and clusterExists) or (serverExists and nodeExists) or (clusterExists and nodeExists)): argerr = 13
	if (( actionName == 'install' or actionName == 'update') and serverExists): argerr = 14
	if (vhExists and not ( actionName == 'install' or actionName == 'update' or actionName == 'vhost') ): argerr = 15
	if ((runtimeActions.find(actionName) >= 0) and not serverExists and not appExists): argerr = 16
	if ((actionName == 'export') and not appExists and not earExists): argerr = 17

if (argerr):
        print 'Invalid command line invocation (reason code '+str(argerr)+').'
        usage()
        sys.exit()

#*******************************************************************************************************
# Decipher and Perform Requested Action
#*******************************************************************************************************
if (actionName == 'install'):
        # Install new App to Cluster
        args = '-cluster '+clusterName+' -appname '+appName
        print AdminApp.install(earName, args)
        print appName+' installed - updating virtual host...'
        if (vhExists):
                result = setVirtualHost(appName, virtualHost)
                if (result != 0):
                        print 'Error: Virtual Host not set properly, please check virtual host name and edit in the console.'
        print 'Saving configuration...'
        AdminConfig.save()
        print 'You must synchronize your changes across the cell for them to fully take effect.'
elif (actionName == 'update'):
        # Update existing App
        args = '-update -appname '+appName
        print AdminApp.install(earName, args)
        if (vhExists):
                result = setVirtualHost(appName, virtualHost)
                if (result != 0):
                        print 'Error: Virtual Host not set properly, please check virtual host name and edit in the console.'
        print 'Saving configuration...'
        AdminConfig.save()
        print 'You must synchronize your changes across the cell for them to fully take effect.'
elif (actionName == 'list'):
        if (serverExists):
                # List apps on specified AppServer
                server = AdminConfig.getid('/ServerEntry:'+serverName+'/')
                dAppList = AdminConfig.show(server, 'deployedApplications').split(']')[0].split('[')[1].split(';')
                print serverName
                for dApp in dAppList:
                        appname = dApp.split('/')[2]
                        print '  '+appname
        elif (clusterExists):
                # List apps on specified Cluster
                cluster = AdminConfig.getid('/ServerCluster:'+clusterName+'/')
                memberList = AdminConfig.show(cluster, 'members').split(']')[0].split('[')[2].split()
                print clusterName
                # Print out for every member, even though they should be the same, in case you need to check consistency.
                for member in memberList:
                        mname = member.split('(')[0]
                        print '  '+mname
                        server = AdminConfig.getid('/ServerEntry:'+mname+'/')
                        dAppList = AdminConfig.show(server, 'deployedApplications').split(']')[0].split('[')[1].split(';')
                        for dApp in dAppList:
                                appname = dApp.split('/')[2]
                                print '    '+appname
                        print ''
        elif (nodeExists):
                # List apps for all AppServers on specified Node
                node = AdminConfig.getid('/Node:'+nodeName+'/')
                serverList = AdminConfig.list('ServerEntry', node).splitlines()
                print nodeName
                for server in serverList:
                        dAppList = AdminConfig.show(server, 'deployedApplications').split(']')[0].split('[')[1].split(';')
                        sName = server.split('(')[0]
                        print '  '+sName
                        for dApp in dAppList:
                                appname = dApp.split('/')[2]
                                print '    '+appname
        else:
                # List all applications in the cell.
                print AdminApp.list()
elif (actionName == 'export'):
	print 'Exporting '+appName+' to '+earName+' ...'
	try: AdminApp.export(appName, earName)
	except:
		print 'Application export failed: '+str(argerr)
        	sys.exit()
	else: print 'Done!'
elif (actionName == 'vhost'):
	print 'Setting virtual host for '+appName+' to '+virtualHost+' ...'
	try: setVirtualHost(appName, virtualHost)
	except:
		print 'Setting vhost failed: '+str(argerr)
        	sys.exit()
	else: print 'Done!'
        print 'Saving configuration...'
        AdminConfig.save()
        print 'You must synchronize your changes across the cell for them to fully take effect.'
elif (actionName == 'stop'):
	result = stopApp(nodeName, serverName, appName)
	outputStateResults(result, appName, serverName, 'stopp')
elif (actionName == 'start'):
	result = startApp(nodeName, serverName, appName)
	outputStateResults(result, appName, serverName, 'start')
elif (actionName == 'restart'):
	result = stopApp(nodeName, serverName, appName)
	outputStateResults(result, appName, serverName, 'stopp')
	result = startApp(nodeName, serverName, appName)
	outputStateResults(result, appName, serverName, 'start')
else:
        print 'Invalid action requested, and somehow slipped through - please try again.'
