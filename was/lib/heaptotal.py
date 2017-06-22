#***********************************************************
# Usage: wsadmin.sh -f heaptotal.py [node] [config|runtime]
#***********************************************************
global AdminConfig
data = 'config'
nodelist = []
if (len(sys.argv) == 2):
	global AdminControl
	data=sys.argv[1]
if (len(sys.argv) >= 1): mynode = sys.argv[0]
else: mynode = java.lang.System.getProperty ('local.node')

if (mynode == 'all'):
	if (data == 'config'): nodelist = [n.split('(')[0] for n in AdminConfig.list('Node').splitlines()]
	elif (data == 'runtime'): nodelist = [n.split('node=')[1].split(',')[0] for n in AdminControl.queryNames('WebSphere:name=nodeSync,process=nodeagent,type=NodeSync,*').splitlines()]
else: nodelist.append(mynode)

if (data == 'config'):
	for node in nodelist:
		servers = AdminConfig.list('JavaVirtualMachine', '*'+node+'*').splitlines()
		totalmem = 0
		for jvm in servers:
			mem = float(AdminConfig.showAttribute(jvm, 'maximumHeapSize'))
			name = jvm.split('servers/')[1].split('|')[0]
			print "%35s : %.0fM" % (name, mem)
			totalmem = totalmem + mem
		print '============================================'
		print '%35s : %.2fG' % ('Total ' + node, totalmem/1024)
		if (mynode == 'all'): print ''
elif (data == 'runtime'):
	for node in nodelist:
		servers =  AdminControl.queryNames('WebSphere:name=JVM,type=JVM,node='+node+',*').splitlines()
		totalmem = 0
		for jvm in servers:
			mem = (float(AdminControl.getAttribute(jvm, 'heapSize')) / 1024)/1024
			name = jvm.split('J2EEServer=')[1].split(',')[0]
			print "%35s : %.2fM" % (name, mem)
			totalmem = totalmem + mem
		print '==============================================='
		print '%35s : %.2fG' % ('Total ' + node, totalmem/1024)
		if (mynode == 'all'): print ''
