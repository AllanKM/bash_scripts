#==============================================================================
# Quick script to disable verbose garbage collection
# Usage: wsadmin.sh -lang jython -f disableVerboseGC.py nodeName appserverName
# Note: usage will be changed later to pass a cluster name instead.
#==============================================================================
import sys

node=sys.argv[0]
server=sys.argv[1]
jvmcfg=AdminConfig.getid('/Node:'+node+'/Server:'+server+'/JavaProcessDef:/JavaVirtualMachine:/')
genJVMargs=AdminConfig.showAttribute(jvmcfg,'genericJvmArguments')
try:
  vgc=genJVMargs.index('-verbosegc')
except:
  # Exiting script due to no '-verbosegc' being present
  sys.exit()
vgcEnd=vgc+11
newArgs=genJVMargs[:vgc] + genJVMargs[vgcEnd:]
try: AdminConfig.modify(jvmcfg, [['genericJvmArguments', newArgs]])
except:
	print 'Error occurred while modifying the generic JVM args - exiting without saving.'
	print 'Error details: ',sys.exc_info()
	sys.exit()
try: AdminConfig.modify(jvmcfg, [['verboseModeGarbageCollection', 'false']])
except:
	print 'Error occurred while modifying the verboseModeGarbageCollection flag - exiting without saving.'
	print 'Error details: ',sys.exc_info()
	sys.exit()
AdminConfig.save()
