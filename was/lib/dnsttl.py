#*******************************************************************************************************
# dnsttl.py -- Script to make a "shotgun" change to all JVM DNS TTL values. USE WITH CAUTION!!!
#
#   Author: James Walton
#   Initial Revision Date: 10 Apr 2008
#*******************************************************************************************************
import sys
def regFind(aList, theValue):
	theIndex = -1
	for item in aList:
		if (item.find(theValue) >= 0):
			theIndex = aList.index(item)
			break
	return theIndex
#*******************************************************************************************************
argc=len(sys.argv)
if (argc == 0):
	print 'Usage: wsadmin -lang jython -f dnsttl.py <ttlvalue>'
	print '       * ttlvalue = DNS TTL value in seconds'
	sys.exit()
ttlValue=sys.argv[0]
newTTLarg='-Dsun.net.inetaddr.ttl='+ttlValue
jvmList = AdminConfig.list('JavaVirtualMachine').split()
for jvmcfg in jvmList:
	nodeName = jvmcfg.split('(')[1].split('|')[0].split('/')[3]
	serverName = jvmcfg.split('(')[1].split('|')[0].split('/')[5]
	jvmName = nodeName+'/'+serverName
	print '*** MODIFYING: '+jvmName+' ***'
	genArgs = AdminConfig.showAttribute(jvmcfg, 'genericJvmArguments')
	if (genArgs):
		argList = genArgs.split(' ')
		if (regFind(argList, 'Dsun.net.inetaddr.ttl=') >= 0):
		    	#check value and change if necessary
		    	ttlIndex = regFind(argList, 'Dsun.net.inetaddr.ttl=')
		    	ttlArgs = argList[ttlIndex].split('=')
		    	if (ttlArgs[1] != ttlValue):
	    			print '     '+jvmName+' - Using new TTL value: '+newTTLarg
			else:
				print '     '+jvmName+' - No change required, existing TTL = '+ttlValue
				continue
			argList[ttlIndex] = newTTLarg
			newGenArgs = ' '.join(argList)
		else:
			print '     '+jvmName+' - No pre-existing TTL value, adding it.'
			newGenArgs = genArgs+' '+newTTLarg
	else: 
		print '     '+jvmName+' -  No existing genericJvmArguments, adding TTL.'
		genArgs='None'
		newGenArgs = newTTLarg
	print '     '+jvmName+' - Old jvm args: '+genArgs
	try: AdminConfig.modify(jvmcfg, [['genericJvmArguments', newGenArgs]])
	except:
	       	print 'Error occurred while updating Generic JVM Arguments - exiting without save.'
	       	print 'Error details:',sys.exc_info()
	       	sys.exit()
	print '     '+jvmName+' - New jvm args: '+AdminConfig.showAttribute(jvmcfg, 'genericJvmArguments')
	print '*** SAVING: '+jvmName+' ***'
	AdminConfig.save()
print 'All configuration changes have been made and saved.'
print 'Synchronize all nodes, and all appservers will need to be restarted for the changes to take effect.'