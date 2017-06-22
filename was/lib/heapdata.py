#*******************************************************************************************************
# heapdata.py
#   Author: James Walton <jfwalton@us.ibm.com>
#   Initial Revision Date: 01/27/2012
#*******************************************************************************************************
import sys
def usage():
        print 'Usage: wsadmin.sh -f heapdata.py <action> <nodeName> <serverName> [heapMin/heapMax]'
        print ''
        print 'Given an action, a node name and an application server name <serverName>, will display or'
        print 'modify current configured JVM heap settings, or display current in-use data.'
        print ''
        print 'Actions: show-config | show-runtime | set-config'
        print 'Note: This script only works for WAS 6.1 or higher.'

# Commandline parameter handling
#*******************************************************************************************************
if ( ('nodeName' in locals().keys() or 'nodeName' in globals().keys()) ): nodeName = ''

argc=len(sys.argv)
if (not argc >= 3):
	usage()
	sys.exit()
action = sys.argv[0]
nodeName = sys.argv[1]
serverName = sys.argv[2]

# Get the configured heap settings
jvmcfg = AdminConfig.getid('/Node:'+nodeName+'/Server:'+serverName+'/JavaProcessDef:/JavaVirtualMachine:/')
jvmmax = AdminConfig.showAttribute(jvmcfg, 'maximumHeapSize')
jvmmin = AdminConfig.showAttribute(jvmcfg, 'initialHeapSize')
if (action == 'show-runtime'):
	# Print out runtime heap stats, if available
	jObj = AdminControl.completeObjectName('WebSphere:name=JVM,type=JVM,node='+nodeName+',process='+serverName+',*')
	if (len(jObj) > 0):
		# Valid runtime object found
		jvmheap = AdminControl.getAttribute(jObj, 'heapSize')
		jvmheap = float(jvmheap)/1024/1024
		jvmfree = AdminControl.getAttribute(jObj, 'freeMemory')
		jvmfree = float(jvmfree)/1024/1024
		percentUtil = (float(jvmheap)/float(jvmmax))*100
		print nodeName+' '+serverName+' %.1f MB of %d MB max heap allocated (%.1f%% utilized) (%.1f MB free)' % (jvmheap,jvmmax,percentUtil,jvmfree)
	else:
		# No runtime object found
		print '### Error: '+serverName+' is not running. No runtime heap statistics available.'
		print 'Current config settings: '+nodeName+' '+serverName+' '+jvmmin+'/'+jvmmax
		sys.exit()
elif (action == 'set-config'):
	# Split out jvm heap args and change JVM heap
	attrVal = sys.argv[3]
        heapMin = attrVal.split('/')[0]
        heapMax = attrVal.split('/')[1]
        print 'Current config settings: '+nodeName+' '+serverName+' '+jvmmin+'/'+jvmmax
        print 'New config settings    : '+nodeName+' '+serverName+' '+heapMin+'/'+heapMax
        try: AdminConfig.modify(jvmcfg, [['initialHeapSize', heapMin], ['maximumHeapSize', heapMax]])
        except:
                print '### Error occurred while modifying jvm heap - exiting without save.'
                print '### Error details:',sys.exc_info()
                sys.exit()
        AdminConfig.save()
        print 'New config settings set and saved successfully.'
        print 'Changes must be synchronized, and the appserver ('+serverName+') restarted to take effect.'
elif (action == 'show-config'):
	# Print out current config settings
        print nodeName+' '+serverName+' '+jvmmin+'/'+jvmmax
else:
	print 'Invalid action specified and somehow slipped under the radar - please try again.'