import sys
jvmname,operation = sys.argv
if operation != 'get' and operation != 'manual' and operation != 'automatic' and operation != 'supervised':
  print "Allowed arguments: <jvmname> <get|manual|automatic|supervised>"
  sys.exit(1)

def setToMode(clusterid, OM):
  omattr = ['operationalMode', OM]
  AdminConfig.modify(clusterid, [omattr])
  AdminConfig.save()
  print "%s,%s" % (jvmname, AdminConfig.show(clusterid, 'operationalMode')[1:-1].split(' ')[1])
    
jvmid = [server for server in AdminConfig.list('Server').splitlines() if server.find('/servers/%s|' % jvmname)>0 and server.find('/dynamicclusters/')<0][0]
clustername = AdminConfig.show(jvmid, 'clusterName')[1:-1].split(' ')[1]
clusterid = AdminConfig.getid('/DynamicCluster:%s/' % clustername)
curOM = ''
if clusterid > 0:
  curOM = AdminConfig.show(clusterid, 'operationalMode')[1:-1].split(' ')[1] 
  if operation == 'get': 
    print "%s,%s" % (jvmname,curOM)
  else: 
    setToMode(clusterid, operation)
