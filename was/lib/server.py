#*******************************************************************************************************
# server.py -- based on migration from serverAction.jacl
#
#   Author: James Walton
#   Initial Revision Date: 10 Apr 2008
#*******************************************************************************************************
import sys
def usage():
        print 'Usage:'
        print '   wsadmin -lang jython -f server.py -action <actionName> -server <serverName> [-node <nodeName>]'
        print '   wsadmin -lang jython -f server.py -action list [-cell]'
        print '   wsadmin -lang jython -f server.py -action modify -server <serverName> -attr <attributeModifications> [-node <nodeName>]'
        print ''
        print 'Actions: start | stop | list | status | modify | dump | ports'
        print 'Attributes: heap | cookie | runas | m2m | classpath | port | hamgr | plugin | dnsttl | jvmcustom | threadpool | genarg'
        print ''
        print 'Executes the selected action on server <serverName> of node <nodeName>.'
        print 'If -node <nodeName> is not given, script will assume local node is to be used.'
        print 'The list action requires no additional arguments, by default it lists all servers on the'
        print 'local node, the optional argument -cell will list all servers in the cell.'
        print ''
        print 'Attribute modification examples:'
        print '   - new heap sizes (min 512M, max 1024M):  -attr heap:512/1024'
        print '   - new appserver JSESSIONID cookie name:  -attr cookie:SESSION_cust_app'
        print '   - new runAs user and group            :  -attr runas:webinst/mqm'
        print '   - change m2m settings for an appserver:  -attr m2m:cluster_cust_m2m'
        print '   - turn off m2m session replication    :  -attr m2m:off'
        print '   - append entries to the JVM classpath :  -attr classpath:/projects/app1/lib:/projects/app1/properties'
        print '        *Note - multiple classpath entries can be added using a colon (:) delimited list.'
	print '   - modify one or more appserver port   :  -attr port:SOAP_CONNECTOR_ADDRESS=8890,WC_defaulthost_secure=9044'
        print '        *Note - multiple port modifications are possible by using a comma (,) delimited list.'
        print '   - enable/disable HAManager service    :  -attr hamgr:off || -attr hamgr:on'
    	print '   - modify one or more plugin property  :  -attr plugin:ConnectTimeout=10,MaxConnections=5'
        print '        *Note - multiple plugin property modifications are possible by using a comma (,) delimited list.'
        print '   - modify the JVM DNS TTL value        :  -attr dnsttl:120'
        print '        *Note - TTL value must be in seconds.'
        print '   - add JVM custom properties           :  -attr jvmcustom:Name=value,OtherName=value'
        print '        *Note - multiple value delimited by comma (,)'
        print '   - modify thread pool sizes            :  -attr threadpool:Name=min/max,Name1=min/max'
        print '        *Note - multiple value delimited by comma (,)'
        print '   - add generic JVM arguments           :  -attr genarg:-myarg,-myotherarg,-Xmn320m'
        print '        *Note - multiple value delimited by comma (,)'
        print '   - add Web Container custom properties           :  -attr wccustom:Name=value,OtherName=value'
        print '        *Note - multiple value delimited by comma (,)'

def regFind(aList, theValue):
	theIndex = -1
	for item in aList:
		if (item.find(theValue) >= 0):
			theIndex = aList.index(item)
			break
	return theIndex

#*******************************************************************************************************
# Commandline parameter handling
#*******************************************************************************************************
argerr, useCell = 0,0
actionList = ['start', 'stop', 'list', 'status', 'modify', 'dump', 'ports']
if ( ('nodeName' in locals().keys() or 'nodeName' in globals().keys()) ): nodeName = ''

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
        elif (arg == '-node'):
                i += 1
                if (i < argc): nodeName = sys.argv[i]
                else: argerr = 4
        elif (arg == '-attr'):
		i += 1
                if (i < argc): attrMod = sys.argv[i]
                else: argerr = 10
        elif (arg == '-cell'): useCell = 1
        else: argerr = 5
        i += 1

actionExists = ('actionName' in locals().keys() or 'actionName' in globals().keys())
serverExists = ('serverName' in locals().keys() or 'serverName' in globals().keys())
nodeExists = (('nodeName' in locals().keys() or 'nodeName' in globals().keys()) and not nodeName == '')
attrExists = ('attrMod' in locals().keys() or 'attrMod' in globals().keys())
#*******************************************************************************************************
# Verify valid parameters were passed
#*******************************************************************************************************
if (not actionExists): argerr = 6
else:
	try: actionList.index(actionName)
	except: argerr = 7
	if (not serverExists and actionName != 'list'): argerr = 8
       	if (actionName == 'list' and serverExists): argerr = 9
	if (actionName == 'modify' and not serverExists and not attrExists): argerr = 10
        if (actionName == 'list' and useCell == 0):
	        nodeName = java.lang.System.getProperty('local.node')
        if (actionName == 'dump' and useCell == 1):
	        print 'WARNING!! You were about to execute a heap dump for every server in the cell!!'
		print 'No Soup For You!! ;)'
	        argerr = 11
        if (not serverExists and actionName == 'ports'): argerr = 12
if (serverExists and not nodeExists):
        nodeName = java.lang.System.getProperty('local.node')

if (argerr):
        print 'Invalid command line invocation (reason code '+str(argerr)+').'
	usage()
        sys.exit()

#*******************************************************************************************************
# Decipher and Perform Requested Action
#*******************************************************************************************************
if (actionName == 'start'):
        # Start AppServer - One node only
        try: AdminControl.startServer(serverName, nodeName)
        except:
        	print 'Could not start server: '+serverName
        	print '### Error details:',sys.exc_info()
        	sys.exit()
elif (actionName == 'stop'):
        # Stop AppServer - One node
        try: AdminControl.stopServer(serverName, nodeName, 'immediate')
        except:
        	print 'Could not stop server: '+serverName
        	print '### Error details:',sys.exc_info()
        	sys.exit()
elif (actionName == 'dump'):
        # Force a Heap Dump on AppServer - One node
        jvmobj = AdminControl.completeObjectName('WebSphere:type=JVM,process='+serverName+',node='+nodeName+',*')
        try: print AdminControl.invoke(jvmobj, 'generateHeapDump')
        except:
        	print 'Could not generate heap dump for server: '+serverName
        	print '### Error details:',sys.exc_info()
        	sys.exit()
elif (actionName == 'list'):
        # Get list of AppServers
        if(useCell): serverlist = AdminConfig.list('Server').splitlines()
	else: serverlist = AdminConfig.getid('/Node:'+nodeName+'/Server:/').splitlines()
        for server in serverlist:
                sname = AdminConfig.showAttribute(server, 'name')
                nname = server.split('/')[3]
		print nname+': '+sname
elif (actionName == 'status'):
        # Get status for AppServer
        print 'Node: '+nodeName
        server = AdminControl.completeObjectName('WebSphere:name='+serverName+',node='+nodeName+',type=Server,*')
        # Check for object, set and show status
        if (len(server) > 0): status = AdminControl.invoke(server, 'getState')
        else: status = 'STOPPED or unavailable'
        print serverName+': '+status
elif (actionName == 'ports'):
	nepList = AdminConfig.getid('/Node:'+nodeName+'/ServerIndex:/ServerEntry:'+serverName+'/NamedEndPoint:/').splitlines()
	# Search the list of named endpoints in the server for a match to update
        for nep in nepList:
                nepName = AdminConfig.showAttribute(nep, 'endPointName')
                endpoint = AdminConfig.showAttribute(nep, 'endPoint')
                nepPort = AdminConfig.showAttribute(endpoint, 'port')
                print nepName+'='+nepPort
elif (actionName == 'modify'):
	# Break up attr parameter to get the name
        attrName = attrMod.split(':')[0]
        attrValues = attrMod.split(':')[1]
        attrTmp = attrMod.split(':')[1:]
        print 'Modifying '+attrName+' for '+serverName+' to '+str(attrTmp)
        if (attrName == 'heap'):
        	# Split out jvm heap values and change JVM heap
                heapMin = attrValues.split('/')[0]
                heapMax = attrValues.split('/')[1]
                jvmcfg = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/JavaProcessDef:/JavaVirtualMachine:/')
                try: AdminConfig.modify(jvmcfg, [['initialHeapSize', heapMin], ['maximumHeapSize', heapMax]])
                except:
                        print '### Error occurred while modifying jvm heap - exiting without save.'
                        print '### Error details:',sys.exc_info()
                        sys.exit()
                AdminConfig.save()
                print 'The configuration changes have been saved.'
                print 'Changes might need to be synchronized, and the appserver ('+serverName+') will need to be restarted.'
        elif (attrName == 'cookie'):
        	# Change appserver session cookie name
                cookieName = attrValues
                asCookie = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/ApplicationServer:/WebContainer:/SessionManager:/Cookie:/')
                try: AdminConfig.modify(asCookie, [['name', cookieName]])
                except:
                        print '### Error occurred while modifying application server cookie - exiting without save.'
                        print '### Error details:',sys.exc_info()
                        sys.exit()
                AdminConfig.save()
                print 'The configuration changes have been saved.'
                print 'Changes might need to be synchronized, and the appserver ('+serverName+') will need to be restarted.'
        elif (attrName == 'runas'):
        	# Split out user and group, set java process runAs values
                runUser = attrValues.split('/')[0]
                runGroup = attrValues.split('/')[1]
                procexec = AdminConfig.showAttribute(AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/JavaProcessDef:/' ), 'execution')
                try: AdminConfig.modify(procexec, [['runAsUser', runUser], ['runAsGroup', runGroup]])
                except:
                        print '### Error occurred while modifying process runas user/group - exiting without save.'
                        print '### Error details:',sys.exc_info()
                        sys.exit()
                AdminConfig.save()
                print 'The configuration changes have been saved.'
                print 'Changes might need to be synchronized, and the appserver ('+serverName+') will need to be restarted.'
        elif (attrName == 'm2m'):
                if (attrValues == 'off'):
                	# Turn off session persistence
                        sessmgr = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/ApplicationServer:/WebContainer:/SessionManager:/')
                        try: AdminConfig.modify(sessmgr, [['sessionPersistenceMode', 'NONE']])
                        except:
                        	print '### Error occurred while disabling DRS session management - exiting without save.'
                        	print '### Error details:',sys.exc_info()
                        	sys.exit()
                else:
                	# Configure a new DRS object to configure m2m session replication
                	asName = serverName.split('_')[len(serverName.split('_'))-1]
                	m2mName = attrValues.split('_')[len(attrValues.split('_'))-1]
                	# If the server given is the m2m server, set mode to server-only
                	if (asName == m2mName):
                		drMode='SERVER'
                		print '   Server '+serverName+' is an m2m server, setting DRS to Server-Only mode.'
            		else:
            			drMode='CLIENT'
            			print '   Setting '+serverName+' DRS to Client-Only mode.'
                        drsTemplate = AdminConfig.listTemplates('DRSSettings', attrValues)
                        sessmgr = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/ApplicationServer:/WebContainer:/SessionManager:/')
                        try: AdminConfig.createUsingTemplate('DRSSettings', sessmgr, [['dataReplicationMode', drMode], ['messageBrokerDomainName', attrValues]], drsTemplate)
                        except:
                        	print '### Error occurred while creating DRS settings object - exiting without save.'
                        	print '### Error details:',sys.exc_info()
        	                sys.exit()
                        print '   DRS settings modified...'
                        # Update session management to enable session persistence with DRS replication
                        try: AdminConfig.modify(sessmgr, [['sessionPersistenceMode', 'DATA_REPLICATION']])
                        except:
	                        print '### Error occurred while modifying session manager - exiting without save.'
	                        print '### Error details:',sys.exc_info()
	                        sys.exit()
                        print '   Persistence mode set to DRS...'
                        # Update tuning parameters for higher replication rate
                        tuneParams = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/ApplicationServer:/WebContainer:/SessionManager:/TuningParams:/')
                        try: AdminConfig.modify(tuneParams, [['writeContents', 'ONLY_UPDATED_ATTRIBUTES'], ['writeFrequency', 'END_OF_SERVLET_SERVICE']])
                        except:
	                        print '### Error occurred while modifying session manager - exiting without save.'
	                        print '### Error details:',sys.exc_info()
	                        sys.exit()
                        print '   Custom tuning parameters set to MEDIUM...'
                AdminConfig.save()
                print 'The configuration changes have been saved.'
                print 'Changes might need to be synchronized, and the appserver ('+serverName+') will need to be restarted.'
        elif (attrName == 'classpath'):
        	# Split up the parameter to get a list of paths (throw away the first entry, as that's the attribute name.)
        	# Passing [] as the parameter acts as a 'deletes all' request
                attrValues = attrMod.split(':')[1:]
                jvmcfg = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/JavaProcessDef:/JavaVirtualMachine:/')
                # Loop through all entries, and append to the JVM classpath
                for path in attrValues:
                	if (path == 'removeall'):
                		AdminConfig.modify(jvmcfg, [['classpath', [] ]])
            		else:
                        	try: AdminConfig.modify(jvmcfg, [['classpath', path]])
				except:
					print '### Error occurred while modifying server configuration - exiting without save.'
					print '### Error details:',sys.exc_info()
					sys.exit()
                AdminConfig.save()
                print 'The configuration changes have been saved.'
                print 'Changes might need to be synchronized, and the appserver ('+serverName+') will need to be restarted.'
        elif (attrName == 'port'):
        	# Split up the parameter, in case more than one port was passed
        	portList=attrValues.split(',')
        	portNames, portVals=[],[]
        	# Loop through the list, and break each entry into the port's name and number
        	for portAttr in portList:
	                portNames.append(portAttr.split('=')[0])
        	        portVals.append(portAttr.split('=')[1])
    	        portCount=len(portNames)
       		iPort=0
		nepList = AdminConfig.getid('/Node:'+nodeName+'/ServerIndex:/ServerEntry:'+serverName+'/NamedEndPoint:/').splitlines()
		# Search the list of named endpoints in the server for a match to update
                for nep in nepList:
                        nepName = AdminConfig.showAttribute(nep, 'endPointName')
                        try: i = portNames.index(nepName)
                        except:
                        	#print 'Skipping port '+nepName+'...'
                        	continue
                    	else:
                        	iPort += 1
                                print 'Found '+portNames[i]+', modifying port to '+portVals[i]+' for '+serverName+' ...'
                                endpoint = AdminConfig.showAttribute(nep, 'endPoint')
                                try: AdminConfig.modify(endpoint, [['port', portVals[i]]])
		                except:
					print '### Error occurred while modifying server configuration - exiting without save.'
					print '### Error details:',sys.exc_info()
					sys.exit()
				# Break out of the loop if we found all the requested ports.
				if(iPort == portCount): break
                AdminConfig.save()
                print 'The configuration changes have been saved.'
                print 'Changes might need to be synchronized, and the appserver ('+serverName+') will need to be restarted.'
        elif (attrName == 'hamgr'):
		hamgr = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/HAManagerService:/')
                if (attrValues == 'off'):
                	# Turn off HAManagerService
                        haStatus='false'                	
                elif (attrValues == 'on'):
                	# Turn on HAManagerService
                        haStatus='true'
                else:
                	print '### Error occurred while modifying HAmanager - exiting without save.'
	                print '### Error details: you must specify only \"on\" or \"off\".'
	                sys.exit()
		try: AdminConfig.modify(hamgr, [['enable', haStatus]])
                except:
                       	print '### Error occurred while disabling DRS session management - exiting without save.'
                       	print '### Error details:',sys.exc_info()
                       	sys.exit()
                AdminConfig.save()
                print 'The configuration changes have been saved.'
                print 'Changes might need to be synchronized, and the appserver ('+serverName+') will need to be restarted.'
        elif (attrName == 'plugin'):
        	asPlugin = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/ApplicationServer:/WebserverPluginSettings:/')
        	validOpts = ['ConnectTimeout', 'MaxConnections', 'Role', 'ServerIOTimeout', 'WaitForContinue', 'ExtendedHandshake']
        	# Split up the parameter, in case more than one port was passed
        	plgList=attrValues.split(',')
        	plgName, plgVals=[],[]
        	# Loop through the list, break each entry into the port's name and number
        	for plgAttr in plgList:
			plgName=plgAttr.split('=')[0]
			plgVal=plgAttr.split('=')[1]
			try: validOpts.index(plgName)
	                except:
	                	print 'Not a valid plugin property: '+plgName
	    	                sys.exit()
	            	else:
	                        print 'Found '+plgName+', modifying value to '+plgVal+' for '+serverName+' ...'
	                        try: AdminConfig.modify(asPlugin, [[plgName, plgVal]])
		                except:
					print '### Error occurred while modifying server plugin configuration - exiting without save.'
					print '### Error details:',sys.exc_info()
					sys.exit()
                AdminConfig.save()
                print 'The configuration changes have been saved.'
                print 'Change should be synchronized, and the plugin should be regenerated.'
        elif (attrName == 'dnsttl'):
		jvmcfg = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/JavaProcessDef:/JavaVirtualMachine:/')
                genArgs = AdminConfig.showAttribute(jvmcfg, 'genericJvmArguments')
                newTTLarg='-Dsun.net.inetaddr.ttl='+attrValues
                if (genArgs):
	                argList = genArgs.split(' ')
	                if (regFind(argList, 'Dsun.net.inetaddr.ttl=') >= 0):
	                	#check value and change if necessary
	                	ttlIndex = regFind(argList, 'Dsun.net.inetaddr.ttl=')
	                	ttlArgs = argList[ttlIndex].split('=')
	                	if (ttlArgs[1] != attrValues):
	                		print 'Using new TTL value: '+newTTLarg
                		else:
                			print 'No change required, existing TTL = '+attrValues
                			sys.exit()
            			argList[ttlIndex] = newTTLarg
            			newGenArgs = ' '.join(argList)
	            	else:
	            		print 'No pre-existing TTL value, adding it.'
	            		newGenArgs = genArgs+' '+newTTLarg
    		else: 
    			print serverName+' has no existing genericJvmArguments, adding TTL.'
    			genArgs='None'
    			newGenArgs = newTTLarg
    		print 'Old jvm args: '+genArgs
		try: AdminConfig.modify(jvmcfg, [['genericJvmArguments', newGenArgs]])
                except:
                       	print '### Error occurred while updating Generic JVM Arguments - exiting without save.'
                       	print '### Error details:',sys.exc_info()
                       	sys.exit()
                print 'New jvm args: '+AdminConfig.showAttribute(jvmcfg, 'genericJvmArguments')
                AdminConfig.save()
                print 'The configuration changes have been saved.'
                print 'Changes might need to be synchronized, and the appserver ('+serverName+') will need to be restarted.'
	elif (attrName == 'jvmcustom'):
        	# Split up the parameter, in case more than one custom property was passed
        	custPropList=attrValues.split(',')
		jvmcfg = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/JavaProcessDef:/JavaVirtualMachine:/')
        	# Loop through the list, and break each entry into the propery's name and value
        	for custPropAttr in custPropList:
	                custPropName = ['name', custPropAttr.split('=')[0]]
        	        custPropVal = ['value', custPropAttr.split('=')[1]]
        	        sysPropList = [custPropName, custPropVal]
        	        try: AdminConfig.create('Property', jvmcfg, sysPropList)
        	        except:
        	        	print '### Error occurred while updating Custom JVM Properties - exiting without save.'
                       		print '### Error details:',sys.exc_info()
                       		sys.exit()
                print 'New JVM custom properties list:'+AdminConfig.showAttribute(jvmcfg, 'systemProperties')
		AdminConfig.save()
                print 'The configuration changes have been saved.'
                print 'Changes might need to be synchronized, and the appserver ('+serverName+') will need to be restarted.'
	elif (attrName == 'threadpool'):
        	# Split up the parameter, in case more than one port was passed
        	thpList=attrValues.split(',')
        	for thp in thpList:
        		thpName = thp.split('=')[0]
        		thpVals = thp.split('=')[1]
        		thpMin = thpVals.split('/')[0]
        		thpMax = thpVals.split('/')[1]
			thpcfg = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/ThreadPoolManager:/ThreadPool:'+thpName+'/')
			try: AdminConfig.modify(thpcfg, [['minimumSize', thpMin], ['maximumSize', thpMax]])
        	        except:
        	        	print '### Error occurred while updating thread pool'+thpName+' - exiting without save.'
                       		print '### Error details:',sys.exc_info()
                       		sys.exit()
                       	print 'Thread pool ('+thpName+') size set to '+thpMin+'/'+thpMax
                       	print 'Saving changes to thread pool ('+thpName+')'
			AdminConfig.save()
                print 'All configuration changes have been saved.'
                print 'Changes might need to be synchronized, and the appserver ('+serverName+') will need to be restarted.'
        elif (attrName == 'genarg'):
        	# Split up the parameter to get a list of paths (throw away the first entry, as that's the attribute name.)
        	# Have to re-join with : in case the argument requested uses : (i.e. -verbose:gc or -XX:something)
        	attrValues = ':'.join(attrMod.split(':')[1:])
		reqGenArgs=' '.join(attrValues.split(','))
		jvmcfg = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/JavaProcessDef:/JavaVirtualMachine:/')
                currentGenArgs = AdminConfig.showAttribute(jvmcfg, 'genericJvmArguments')
                if (currentGenArgs):
	                print 'Appending new arguments to '+serverName+' generic JVM argument list.'
	            	newGenArgs = currentGenArgs+' '+reqGenArgs
    		else: 
    			print serverName+' has no existing genericJvmArguments, adding new arguments.'
    			currentGenArgs='None'
    			newGenArgs = reqGenArgs
    		print 'Old jvm args: '+currentGenArgs
		try: AdminConfig.modify(jvmcfg, [['genericJvmArguments', newGenArgs]])
                except:
                       	print '### Error occurred while updating Generic JVM Arguments - exiting without save.'
                       	print '### Error details:',sys.exc_info()
                       	sys.exit()
                print 'New jvm args: '+AdminConfig.showAttribute(jvmcfg, 'genericJvmArguments')
                AdminConfig.save()
                print 'The configuration changes have been saved.'
                print 'Changes might need to be synchronized, and the appserver ('+serverName+') will need to be restarted.'
	elif (attrName == 'wccustom'):
        	# Split up the parameter, in case more than one custom property was passed
        	custPropList=attrValues.split(',')
		wccfg = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/ApplicationServer:/WebContainer:/')
        	# Loop through the list, and break each entry into the custom property's name and value
        	for custPropAttr in custPropList:
	                custPropName = ['name', custPropAttr.split('=')[0]]
        	        custPropVal = ['value', custPropAttr.split('=')[1]]
        	        wcPropList = [custPropName, custPropVal]
        	        #Verify the property doesn't exist yet, if it does, modify instead of create
			wcProps = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/ApplicationServer:/WebContainer:/Property:/').split()
			modProp = 0
			wcProp = ''
			if (len(wcProps) > 0):
				for prop in wcProps:
					pName = AdminConfig.showAttribute(prop,'name')
					if (pName == custPropName[1]):
						modProp = 1
						wcProp = prop
						break
			if (modProp):
				print 'Modifying existing property: '+custPropName[1]+' ...'
				try: AdminConfig.modify(wcProp, wcPropList)
				except:
					print '### Error: '+nodeName+'/'+serverName+' WebContainer custom property modifcation failed!'
					print 'Error details:',sys.exc_info()
					sys.exit()
			else:
				print 'Creating new property: '+custPropName[1]+' ...'
	        	        try: AdminConfig.create('Property', wccfg, wcPropList)
	        	        except:
	        	        	print '### Error occurred while updating Custom JVM Properties - exiting without save.'
	                       		print '### Error details:',sys.exc_info()
	                       		sys.exit()
                print 'New WebContainer custom property list:'+AdminConfig.showAttribute(wccfg, 'properties')
		AdminConfig.save()
                print 'The configuration changes have been saved.'
                print 'Changes might need to be synchronized, and the appserver ('+serverName+') will need to be restarted.'
        else:
                print 'Invalid attribute specified and somehow slipped under the radar - please try again.'
                sys.exit()
else:
        print 'Invalid action specified and somehow slipped under the radar - please try again.'
