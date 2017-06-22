# -*- coding: utf-8 -*-
# 
# veAction.py
# 	- Sets and records operational mode of a dynamic cluster
#	- Change a server to maintenance mode
#	- Unset maintenance mode
import sys, time, cPickle, os
cell = AdminConfig.list('Cell').split('(')[0]
cellvarsdir = "/fs/scratch/dmgrinfo/"
cellvarsfile = "%s%s%s" % (cellvarsdir, cell, 'vars.txt')
# Attempt to load file into vars var
if os.path.exists(cellvarsfile):
  file = open(cellvarsfile, 'r')
  vars = cPickle.load(file)
  file.close()
else:
  vars = {}

if (not os.path.exists(cellvarsdir)):
  os.mkdir(cellvarsdir)

def usage():
  print '''Usage:

                 veAction.py <full jvm name> <stop | start | restart>
'''
  sys.exit(24)

try:
  jvmName, operation = sys.argv
except:
  usage()

if (not vars.has_key(jvmName)):
  try:
    #objNameString = AdminControl.completeObjectName('WebSphere:type=Server,name=%s,*' % jvmName)
    #nodeName = AdminControl.getAttribute(objNameString, 'nodeName')
    stuff = AdminConfig.showall(AdminConfig.getid('/Server:%s/' % jvmName)).splitlines()
    strstuff = "^^".join(stuff)
    nodeName = strstuff.split('host ')[1].split(']^^')[0]
    vars.setdefault(jvmName,nodeName)
  except:
    print 'Problem retrieving nodeName from jvmName supplied'
    sys.exit(26)
else:
  
  nodeName = vars[jvmName]

def stopServer():
  return AdminControl.stopServer(jvmName, nodeName)

def startServer():
  return AdminControl.startServer(jvmName, nodeName)

#if operation != 'get' and operation != 'manual' and operation != 'automatic' and operation != 'supervised':
#  print "Allowed arguments: <jvmName> <get|manual|automatic|supervised>"
#  sys.exit(1)

def getMode():
  jvmid = [server for server in AdminConfig.list('Server').splitlines() if server.find('/servers/%s|' % jvmName)>0 and server.find('/dynamicvars/')<0][0]
  clusterName = AdminConfig.show(jvmid, 'clusterName')[1:-1].split(' ')[1]
  clusterID = AdminConfig.getid('/DynamicCluster:%s/' % clusterName)
  curOM = ''
  # Check vars var first
  if clusterID > 0:
    if (not vars.has_key(clusterName)) and (operation.upper() == 'STOP' or operation.upper() == 'RESTART'):
      curOM = AdminConfig.show(clusterID, 'operationalMode')[1:-1].split(' ')[1]
      vars.setdefault(clusterName,curOM)
      #print "%s %s %s" % (vars, clusterName, curOM)
    #print "%s %s %s" % (vars, clusterName, curOM)
    print "Retrieved mode: %s for cluster: %s" % (vars[clusterName], clusterName)
    return clusterName, vars[clusterName]
  else:
    print "%s is not a dynamic cluster or something is wrong" % clusterName
    sys.exit(25)
  #recordVars(clusterID, curOM)

def recordVars():
  file = open(cellvarsfile, 'w')
  cPickle.dump(vars, file)
  file.close()
  #file = open('/fs/scratch/bztst70wiManagervars.txt', 'r')
  #me = cPickle.load(file)
  #file.close()
  #print me

def setMaintenanceMode():
  print "Setting maintenance mode for %s, please wait." % jvmName
  AdminTask.setMaintenanceMode(nodeName,'[-name %s -mode stop]' % jvmName)
  #AdminControl.stopServer('%%SERVERNAME%%', '%%NODE%%')
  i=1
  while i==1:
    try:
      sys.stdout.write(".")
      AdminControl.getAttribute(AdminControl.completeObjectName('name=%s,type=Server,*' % jvmName), 'state')
      time.sleep(5)
    except:
      print "Stopped"
      i=0

def unsetMaintenanceMode():
  print "Unsetting maintenance mode for %s" % jvmName
  AdminTask.unsetMaintenanceMode(nodeName,'[-name %s]' % jvmName)

def setMode(clusterName, OM):
  print "Setting DC mode for cluster: %s to %s" % (clusterName, OM)
  clusterID = AdminConfig.getid('/DynamicCluster:%s/' % clusterName)
  omattr = ['operationalMode', OM]
  AdminConfig.modify(clusterID, [omattr])
  AdminConfig.save()
  print "DC mode is now %s" % AdminConfig.show(clusterID, 'operationalMode')[1:-1].split(' ')[1]

def stop():
  clusterName, mode = getMode()
  recordVars()
  setMode(clusterName, 'manual')
  setMaintenanceMode()
  #status = stopServer()
  #if status.find('WASX7264I')>=0:
  #  print "Server %s stopped successfully" % jvmName
  #else:
  #  print "Server %s not successfully stopped.  Exiting." % jvmName 
  #  sys.exit(4)

def start():
  clusterName, mode = getMode() 
  print "Starting server %s" % jvmName
  status = startServer()
  if status.find('WASX7262I')>=0:
    print "Server %s started successfully" % jvmName
  else:
    print "Server %s not successfully started.  Exiting" % jvmName 
    sys.exit(4)
  unsetMaintenanceMode()
  setMode(clusterName, mode)  

if operation.upper() == 'STOP':
  stop()
elif operation.upper() == 'START': 
  start()
elif operation.upper() == 'RESTART':
  stop()
  print ''
  print '**** Proceeding to start phase ****'
  print ''
  start()

#WASX7264I: Stop completed for server "{0}" on node "{1}"
#    Explanation	In response to an AdminControl stopServer command, the specified server has been stopped on the specificed node.
#    Action	None
#WASX7265W: Stop not completed for server "{0}" on node "{1}". The stop process may have timed out.
#WASX7262I: Start completed for server "{0}" on node "{1}"
#    Explanation	In response to an AdminControl startServer command, the specified server has been started on the specificed node.
#    Action	None
#WASX7263W: Start not completed for server "{0}" on node "{1}". The server launching process may have timed out.
