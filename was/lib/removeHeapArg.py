#==============================================================================
# Quick script to remove any -Xmx or -Xms parameters
# Usage: wsadmin.sh -lang jython -f removeHeapArg.py nodeName appserverName arg
#==============================================================================
import sys
import re
def listFind(lst, pattern):
	for item in lst:
		if(re.match(pattern, item) != None): return lst.index(item)

if (len(sys.argv) != 3):
	print 'Unsupported number of arguments.'
	sys.exit()
node=sys.argv[0]
server=sys.argv[1]
jvmarg=sys.argv[2]
if (jvmarg != 'Xmx' and jvmarg != 'Xms'):
	print 'Only supports removal of Xmx or Xms parameters.'
	sys.exit()
jvmcfg=AdminConfig.getid('/Node:'+node+'/Server:'+server+'/JavaProcessDef:/JavaVirtualMachine:/')
genJvmArgs=AdminConfig.showAttribute(jvmcfg,'genericJvmArguments').split()
item=genJvmArgs[listFind(genJvmArgs,'^-'+jvmarg+'[0-9]{2,4}m$')]
genJvmArgs.remove(item)
genJvmArgs=' '.join(genJvmArgs)
try: AdminConfig.modify(jvmcfg, [['genericJvmArguments', genJvmArgs]])
except:
	print 'Error occurred while removing the generic JVM arg ($arg) - exiting without saving.'
	print 'Error details: ',sys.exc_info()
	sys.exit()
AdminConfig.save()