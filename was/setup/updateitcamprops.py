import sys
SEARCH = sys.argv[0]
try:
  SAVE = sys.argv[1]
except:
  SAVE = ''
itcamjvmargs = '-Dsun.net.inetaddr.ttl=120 -agentlib:am_ibm_16=${WAS_SERVER_NAME} -Xbootclasspath/p:/opt/IBM/ITM/wasdc/current/toolkit/lib/bcm-bootstrap.jar -Djava.security.policy=/opt/IBM/ITM/wasdc/current/itcamdc/etc/datacollector.policy -Dcom.ibm.tivoli.itcam.ai.runtimebuilder.inputs=/opt/IBM/ITM/wasdc/current/runtime/aix536_Template_DCManualInput.txt -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000 -Dsun.rmi.transport.connectionTimeout=300000 -Dws.bundle.metadata=/opt/IBM/ITM/wasdc/current/runtime/wsBundleMetaData -Ditcamdc.dyncluster=true'
# Update as needed with Name:Value pairs
CUSTOM_PROPS = { 
"TEMAGCCollector.gclog.path" : "None", 
"am.home" : "/opt/IBM/ITM/wasdc/current/itcamdc",
"com.ibm.tivoli.itcam.toolkit.ai.runtimebuilder.enable.rebuild" : "true"
}
ENV_ENTRIES = { 
"LIBPATH" : "/lib:/opt/IBM/ITM/wasdc/current/toolkit/lib/aix536:/opt/IBM/ITM/wasdc/current/toolkit/lib/aix536/ttapi",
"NLSPATH" : "/opt/IBM/ITM/wasdc/current/toolkit/msg/%L/%N.cat"
}

dc = [s for s in AdminConfig.list('Server').splitlines() if s.find('dynamicclusters')>=0 and s.find(SEARCH)>=0]

# Find dynamic cluster server template jvm
djvm = [s for s in AdminConfig.list('JavaVirtualMachine').splitlines() if s.find('dynamicclusters')>=0 and s.find(SEARCH)>=0]

# Find dynamic cluster server template jpd
djpd = [s for s in AdminConfig.list('JavaProcessDef').splitlines() if s.find('dynamicclusters')>=0 and s.find(SEARCH)>=0]

def getCurrentArgs(jvm):
  argstr = AdminTask.showJVMProperties(jvm, '[-propertyName genericJvmArguments]')
  return argstr

def compileGenericJvmArgs(jvm, newstr):
  print jvm
  curargstr = getCurrentArgs(jvm)
  #print "Current\n%s" % curargstr
  curdict = {}
  # Split args into dict so it is searchable via key name
  [curdict.setdefault(arg, '') for arg in curargstr.split(' ')]
  # Set or replace existing entries
  for newarg in newstr.split(' '):
    curdict.setdefault(newarg, '')
  # Merge keys into string to be set as new generic jvm args
  return " ".join(curdict.keys())

def setJVMArgs(jvm, newstr):
  AdminTask.setJVMProperties(jvm, '[-genericJvmArguments "%s"]' % newstr) 

def deleteCurrentCustomProp(jvm, n):
  for cp in AdminConfig.list('Property', jvm).splitlines():
    name = AdminConfig.show(cp, '[name]')[1:-1].split(' ')[1]
    if name == n:
      AdminConfig.remove(cp)

def setCustomProp(jvm, valuedict):
  for k in valuedict.keys():
    print "Creating: %s : %s for %s" % (k, valuedict[k], jvm)
    deleteCurrentCustomProp(jvm, k)
    AdminConfig.create('Property', jvm, '[[validationExpression ""] [name "%s"] [description ""] [value "%s"] [required "false"]]' % (k, valuedict[k]) ) 

def save():
  AdminConfig.save()

def updateJVMArgs(dc):
  for c in dc:
    newargs = compileGenericJvmArgs(c, itcamjvmargs)
    print "New args"
    print newargs
    setJVMArgs(c, newargs)  
 
def updateCustomProps(djvm):
  for jvm in djvm:
    setCustomProp(jvm, CUSTOM_PROPS) 

def updateEnvEntries(djpd):
  for jpd in djpd:
    setCustomProp(jpd, ENV_ENTRIES)

updateJVMArgs(dc)
updateCustomProps(djvm)
updateEnvEntries(djpd)
if SAVE != '':
  save()
