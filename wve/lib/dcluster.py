# dcluster.py
# 	Author: James Walton <jfwalton@us.ibm.com>	2012-03-22
#*******************************************************************************************************
import sys
def usage():
	print 'Usage: wsadmin -f dcluster.py action appClusterName -attr namevaluepair [-attr another ...]'
	print '   * Actions    : create | modify '
	print '   * Create Attributes : template | nodegroup | coregroup'
	print '   * Modify Attributes : heap | cookie | runas | classpath | port | plugin | dnsttl | jvmcustom | threadpool | genarg'
	print ''
	print 'Create Attribute examples:'
	print '   - specify template   :  -attr template:ei_template_https'
	print '   - specify node group :  -attr nodegroup:p1DynamicClusterNodeGroup'
	print '   - specify core group :  -attr coregroup:DefaultNodeGroup'
	print ''
	print 'Modify Attribute examples:'
	print '   - set heap sizes (min 512M, max 1024M) :  -attr heap:512/1024'
	print '   - set appserver JSESSIONID cookie name :  -attr cookie:SESSION_cust_app'
	print '   - set runAs user and group             :  -attr runas:webinst/mqm'
	print '   - append entries to the JVM classpath  :  -attr classpath:/projects/app1/lib:/projects/app1/properties'
	print '   - modify one or more appserver port    :  -attr port:SOAP_CONNECTOR_ADDRESS=8890,WC_defaulthost_secure=9044'
	print '   - modify one or more plugin property   :  -attr plugin:ConnectTimeout=10,MaxConnections=5'
	print '   - modify the JVM DNS TTL value         :  -attr dnsttl:120'
	print '        *Note - TTL value in seconds.'
	print '   - add JVM custom properties            :  -attr jvmcustom:Name=value,OtherName=value'
	print '   - modify thread pool sizes             :  -attr threadpool:Name=min/max,Name1=min/max'
	print '   - add generic JVM arguments            :  -attr genarg:-myarg,-myotherarg,-Xmn320m'
	sys.exit()

#*******************************************************************************************************
# Set defaults, parse passed arguments
argerr = 0
attrList = []
dcNodeGroup = 'DefaulNodeGroup'
dcTemplate = 'ei_template_all'
dcCoreGroup = 'DefaultCoreGroup'
actionList = ['create', 'modify']
createAttrList = ['template', 'nodegroup', 'coregroup']
modifyAttrList = ['heap', 'cookie', 'runas', 'classpath', 'port', 'plugin', 'dnsttl', 'jvmcustom', 'threadpool', 'genarg']

i = 0
argc=len(sys.argv)
while ( i < argc ):
	arg = sys.argv[i]
	if ((arg == 'create') or (arg == 'modify')): action = arg
	elif ((arg.find('_dc_') >= 0) or (arg.find('_cluster_') >= 0)): dclusterName = arg
	elif (arg == '-attr'):
		i += 1
		if (i < argc): attrList.append(sys.argv[i])
		else: argerr = 1
	else: argerr = 2
	i += 1

actionExists = ('actionName' in locals().keys() or 'actionName' in globals().keys())
dclusterExists = ('dclusterName' in locals().keys() or 'dclusterName' in globals().keys())
#*******************************************************************************************************
# Verify valid parameters were passed
#*******************************************************************************************************
if (not actionExists): argerr = 3
else:
	try: actionList.index(actionName)
	except: argerr = 4
	if (not dclusterExists): argerr = 5
	if (actionName == 'create'):
		for attr in attrList:
			try: createAttrList.index(attr.split(':')[0])
			except: argerr = 6
	elif (actionName == 'modify'):
		for attr in attrList:
			try: modifyAttrList.index(attr.split(':')[0])
			except: argerr = 7

if (argerr):
        print 'Invalid command line argument (reason code: '+str(argerr)+').'
	usage()
        sys.exit()
#*******************************************************************************************************
# Decipher and Perform Requested Action
#*******************************************************************************************************
if (actionName == 'create'):
	# Parse creation attributes
	for attr in attrList:
		attrName = attr.split(':')[0]
		attrVal = attr.split(':')[1]
		if (attrName == 'template'): dcTemplate = attrVal
		elif (attrName == 'nodegroup'): dcNodeGroup = attrVal
		elif (attrName == 'coregroup'): dcCoreGroup = attrVal
        # Create dynamic cluster
        memPolicy='node_nodegroup = '+dcNodeGroup
        dcProps='[[operationalMode manual][minInstances 2][maxInstances -1][numVerticalInstances 1][serverInactivityTime 1440]]'
        clProps='[[preferLocal false][createDomain false][templateName '+dcTemplate+'][coreGroup '+dcCoreGroup+']]'
        args='[-membershipPolicy '+memPolicy+' -dynamicClusterProperties '+dcProps+' -clusterProperties '+clProps+']'
        try: AdminTask.createDynamicCluster(dclusterName, args)
        except:
        	print '### Error creating dynamic cluster:',sys.exc_info()
        	sys.exit()
elif (actionName == 'modify'):
        for attr in attrList:
		attrName = attr.split(':')[0]
		attrValues = attr.split(':')[1]
		if (attrName == 'heap'):
			# Split out jvm heap values and change JVM heap
			heapMin = attrValues.split('/')[0]
			heapMax = attrValues.split('/')[1]
			jvmcfg = AdminConfig.getid('/DynamicCluster:'+dclusterName+'/Server:'+dclusterName+'/JavaProcessDef:/JavaVirtualMachine:/')
			print 'Modifying ('+dclusterName+') heap size: '+heapMin+'/'+heapMax+' ...'
			try: AdminConfig.modify(jvmcfg, [['initialHeapSize', heapMin], ['maximumHeapSize', heapMax]])
			except:
				print '### Error occurred while modifying ('+dclusterName+') jvm heap - not saving.'
				print '### Error details:',sys.exc_info()
			else:
				AdminConfig.save()
				print '   Heap size saved.'
		elif (attrName == 'cookie'):
			# Change appserver session cookie name
			cookieName = attrValues
			asCookie = AdminConfig.getid('/DynamicCluster:'+dclusterName+'/Server:'+dclusterName+'/ApplicationServer:/WebContainer:/SessionManager:/Cookie:/')
			print 'Modifying ('+dclusterName+') cookie name: '+cookieName+' ...'
			try: AdminConfig.modify(asCookie, [['name', cookieName]])
			except:
				print '### Error occurred while modifying ('+dclusterName+') cookie - not saving.'
				print '### Error details:',sys.exc_info()
			else:
				AdminConfig.save()
				print '   Session cookie saved.'
		elif (attrName == 'runas'):
			# Split out user and group, set java process runAs values
			runUser = attrValues.split('/')[0]
			runGroup = attrValues.split('/')[1]
			procexec = AdminConfig.showAttribute(AdminConfig.getid('/DynamicCluster:'+dclusterName+'/Server:'+dclusterName+'/JavaProcessDef:/' ), 'execution')
			print 'Modifying ('+dclusterName+') runAs user and group: '+runUser+'/'+runGroup+'...'
			try: AdminConfig.modify(procexec, [['runAsUser', runUser], ['runAsGroup', runGroup]])
			except:
				print '### Error occurred while modifying process runas user/group - not saving.'
				print '### Error details:',sys.exc_info()
			else:
				AdminConfig.save()
				print '   RunAs user/group saved.'
		elif (attrName == 'dnsttl'):
			jvmcfg = AdminConfig.getid('/DynamicCluster:'+dclusterName+'/Server:'+dclusterName+'/JavaProcessDef:/JavaVirtualMachine:/')
			genArgs = AdminConfig.showAttribute(jvmcfg, 'genericJvmArguments')
			newTTLarg='-Dsun.net.inetaddr.ttl='+attrValues
			print 'Modifying ('+dclusterName+') DNS TTL: '+newTTLarg+' ...'
			if (genArgs):
				argList = genArgs.split(' ')
				if (regFind(argList, 'Dsun.net.inetaddr.ttl=') >= 0):
					#check value and change if necessary
					ttlIndex = regFind(argList, 'Dsun.net.inetaddr.ttl=')
					ttlArgs = argList[ttlIndex].split('=')
					if (ttlArgs[1] != attrValues):
						print '   Using new TTL value: '+newTTLarg
					else:	print '   No change required, existing TTL = '+attrValues
					argList[ttlIndex] = newTTLarg
					newGenArgs = ' '.join(argList)
				else:
					print 'No pre-existing TTL value, adding it.'
					newGenArgs = genArgs+' '+newTTLarg
			else: 
				print '   No existing genericJvmArguments, adding TTL.'
				genArgs='None'
				newGenArgs = newTTLarg
			print '   Old jvm args: '+genArgs
			try: AdminConfig.modify(jvmcfg, [['genericJvmArguments', newGenArgs]])
			except:
				print '### Error occurred while updating Generic JVM Arguments - not saving.'
				print '### Error details:',sys.exc_info()
			else:
				print '   New jvm args: '+AdminConfig.showAttribute(jvmcfg, 'genericJvmArguments')
				AdminConfig.save()
				print '   DNS TTL saved.'
		elif (attrName == 'plugin'):
			asPlugin = AdminConfig.getid('/DynamicCluster:'+dclusterName+'/Server:'+dclusterName+'/ApplicationServer:/WebserverPluginSettings:/')
			validOpts = ['ConnectTimeout', 'MaxConnections', 'Role', 'ServerIOTimeout', 'WaitForContinue', 'ExtendedHandshake']
			# Split up the parameter, in case more than one port was passed
			plgList=attrValues.split(',')
			plgName, plgVals=[],[]
			# Loop through the list, break each entry into the port's name and number
			for plgAttr in plgList:
				plgName=plgAttr.split('=')[0]
				plgVal=plgAttr.split('=')[1]
				print 'Modifying ('+dclusterName+') webserver plugin property: '+plgAttr+' ...'
				if plgName in validOpts:
			        	try: AdminConfig.modify(asPlugin, [[plgName, plgVal]])
					except:
						print '   ### Error occurred while modifying server plugin configuration - not saving.'
						print '   ### Error details:',sys.exc_info()
					else:
						AdminConfig.save()
						print '   Web server plugin property ('+plgName+') saved.'
				else: print '   ### Not a valid plugin property ('+plgName+') - skipping.'
			print 'All requested plugin properties modified.'
			print 'The webserver plugin will need to be regenerated and deployed for changes to take effect.'
		elif (attrName == 'classpath'):
			# Split up the parameter to get a list of paths (throw away the first entry, as that's the attribute name.)
			# Passing [] as the parameter acts as a 'deletes all' request
			attrValues = attrMod.split(':')[1:]
			jvmcfg = AdminConfig.getid('/DynamicCluster:'+dclusterName+'/Server:'+dclusterName+'/JavaProcessDef:/JavaVirtualMachine:/')
			# Loop through all entries, and append to the JVM classpath
			for path in attrValues:
				if (path == 'removeall'):
					print 'Removing all classpath entries from ('+dclusterName+')'
					AdminConfig.modify(jvmcfg, [['classpath', [] ]])
				else:
					print 'Appending ('+dclusterName+') classpath: '+path+' ...'
				    	try: AdminConfig.modify(jvmcfg, [['classpath', path]])
					except:
						print '### Error occurred while modifying server configuration - not saving.'
						print '### Error details:',sys.exc_info()
					else:
						AdminConfig.save()
						print '   Classpath saved.'
			print 'All requested classpaths appended/removed.'
		elif (attrName == 'jvmcustom'):
			# Split up the parameter, in case more than one port was passed
			custPropList=attrValues.split(',')
			jvmcfg = AdminConfig.getid('/DynamicCluster:'+dclusterName+'/Server:'+dclusterName+'/JavaProcessDef:/JavaVirtualMachine:/')
			# Loop through the list, and break each entry into the port's name and number
			for custPropAttr in custPropList:
				custPropName = ['name', custPropAttr.split('=')[0]]
				custPropVal = ['value', custPropAttr.split('=')[1]]
				sysPropList = [custPropName, custPropVal]
				print 'Creating ('+dclusterName+') JVM custom property: '+custPropAttr+' ...'
				try: AdminConfig.create('Property', jvmcfg, sysPropList)
				except:
					print '### Error occurred while updating Custom JVM Properties - not saving.'
					print '### Error details:',sys.exc_info()
				else:
					AdminConfig.save()
					print '   JVM custom property saved.'
			print 'All JVM custom properties created.'
			print 'New JVM custom properties list:'+AdminConfig.showAttribute(jvmcfg, 'systemProperties')
		elif (attrName == 'threadpool'):
			# Split up the parameter, in case more than one port was passed
			thpList=attrValues.split(',')
			for thp in thpList:
				thpName = thp.split('=')[0]
				thpVals = thp.split('=')[1]
				thpMin = thpVals.split('/')[0]
				thpMax = thpVals.split('/')[1]
				thpcfg = AdminConfig.getid('/DynamicCluster:'+dclusterName+'/Server:'+dclusterName+'/ThreadPoolManager:/ThreadPool:'+thpName+'/')
				print 'Modifying ('+dclusterName+') thread pool sizes: '+thp+' ...'
				try: AdminConfig.modify(thpcfg, [['minimumSize', thpMin], ['maximumSize', thpMax]])
				except:
					print '### Error occurred while updating thread pool'+thpName+' - not saving.'
					print '### Error details:',sys.exc_info()
				else:
					AdminConfig.save()
					print '   Thread pool sizes saved.'
			print 'All thread pool sizes modified.'
		elif (attrName == 'genarg'):
			# Split up the parameter to get a list of paths (throw away the first entry, as that's the attribute name.)
			# Have to re-join with : in case the argument requested uses : (i.e. -verbose:gc or -XX:something)
			attrValues = ':'.join(attrMod.split(':')[1:])
			reqGenArgs=' '.join(attrValues.split(','))
			jvmcfg = AdminConfig.getid('/DynamicCluster:'+dclusterName+'/Server:'+dclusterName+'/JavaProcessDef:/JavaVirtualMachine:/')
			currentGenArgs = AdminConfig.showAttribute(jvmcfg, 'genericJvmArguments')
			if (currentGenArgs):
				print 'Appending generic JVM arguments to ('+dclusterName+'), existing ...'
				newGenArgs = currentGenArgs+' '+reqGenArgs
			else: 
				print 'Appending generic JVM arguments to ('+dclusterName+'), none existing ...'
				currentGenArgs='None'
				newGenArgs = reqGenArgs
			print '   Old jvm args: '+currentGenArgs
			try: AdminConfig.modify(jvmcfg, [['genericJvmArguments', newGenArgs]])
			except:
				print '### Error occurred while updating Generic JVM Arguments - not saving.'
				print '### Error details:',sys.exc_info()
			else:
				print '   New jvm args: '+AdminConfig.showAttribute(jvmcfg, 'genericJvmArguments')
				AdminConfig.save()
				print '   JVM generic arguments saved.'
		elif (attrName == 'port'):
			# Modify the template ports. !! May not affect endpoint servers !!
			# Split up the parameter, in case more than one port was passed
			portList=attrValues.split(',')
			portNames, portVals=[],[]
			# Loop through the list, and break each entry into the port's name and number
			for portAttr in portList:
				portNames.append(portAttr.split('=')[0])
				portVals.append(portAttr.split('=')[1])
			portCount=len(portNames)
			iPort=0
			nepList = AdminConfig.getid('/DynamicCluster:'+dclusterName+'/ServerIndex:/ServerEntry:'+dclusterName+'/NamedEndPoint:/').splitlines()
			# Search the list of named endpoints in the server for a match to update
			for nep in nepList:
				nepName = AdminConfig.showAttribute(nep, 'endPointName')
				try: i = portNames.index(nepName)
				except:
					#print 'Skipping port '+nepName+'...'
					continue
				else:
					iPort += 1
					print 'Modifying '+dclusterName+' '+portNames[i]+': '+portVals[i]+' ...'
					endpoint = AdminConfig.showAttribute(nep, 'endPoint')
					try: AdminConfig.modify(endpoint, [['port', portVals[i]]])
					except:
						print '### Error occurred while modifying server configuration - not saving.'
						print '### Error details:',sys.exc_info()
					else:
						AdminConfig.save()
						print '   Port saved.'
					# Break out of the loop if we found all the requested ports.
					if(iPort == portCount): break
			print 'All requested ports modified.'
        # All modifications complete
        print 'Done! All changes must be synchronized and the '+dclusterName+' application servers restarted to take effect.'

