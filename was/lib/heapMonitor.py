#*******************************************************************************************************
# heapMonitor.py -- cutdown version of jvmStats.py for monitoring
#   Author: James Walton
#   Initial Revision Date: 07/17/2009
#*******************************************************************************************************
def usage():
        print 'Usage:'
        print '   wsadmin.sh -f heapMonitor.py <nodeName> <serverName>'
        print 'Given a node name and an application server name <serverName>, this script will display the'
        print 'current in-use memory heap allocation, maximum heap allowed, the utilization percentage,'
        print 'and free allocated memory.'
        print 'Note: This script only works for WAS 6.1 or higher and is designed for monitoring only.'

import sys
# Commandline parameter handling
#*******************************************************************************************************
if ( ('nodeName' in locals().keys() or 'nodeName' in globals().keys()) ): nodeName = ''

argc=len(sys.argv)
if (argc != 2):
	usage()
	sys.exit()
nodeName = sys.argv[0]
serverName = sys.argv[1]

# Perform heap check
#*******************************************************************************************************
jObj = AdminControl.completeObjectName('WebSphere:name=JVM,type=JVM,node='+nodeName+',process='+serverName+',*')
# If we have a valid runtime object (i.e. not blank) then continue, otherwise exit
if (len(jObj) > 0):
	jvmheap = AdminControl.getAttribute(jObj, 'heapSize')
	jvmheap = float(jvmheap)/1024/1024
	jvmmax = AdminControl.getAttribute(jObj, 'maxMemory')
	jvmmax = float(jvmmax)/1024/1024
	jvmfree = AdminControl.getAttribute(jObj, 'freeMemory')
	jvmfree = float(jvmfree)/1024/1024
	percentUtil = (float(jvmheap)/float(jvmmax))*100
	print nodeName+' '+serverName+' %.1f MB of %d MB max heap allocated (%.1f%% utilized) (%.1f MB free)' % (jvmheap,jvmmax,percentUtil,jvmfree)
else:
	print serverName+' is not running. No heap statistics are available.'
	sys.exit()