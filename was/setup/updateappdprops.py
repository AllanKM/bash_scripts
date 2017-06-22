import sys

# Adds generic jvm args/environment entries/custom properties to dynamic clusters for AppDynamics
#
# Sample usage:
# 
# sudo /usr/WebSphere85/AppServer/bin/wsadmin.sh -lang jython -f updateappdprops.py clustername=test_itcam controller=appdynamics-pre.ei.eventsgslb.ibm.com accountName=EI accountAccessKey=d0b34484-4443-4bf4-8918-e62326d26d40 applicationName=APPDTEST save=no
#
# If save=no or does not exist, the script will configure, but then not save, i.e. dry run
#
required = {
	'accountAccessKey'	: '', 
  	'applicationName'	: '',
  	'accountName'		: '',
	'controller'		: '',
	'clustername'		: '',
	'save'			: 'no'
}

def set_required(n, v):
  global required
  required[n] = v

def usage(required):
  usage_str = []
  print '''
Usage:
  '''
  for k in required.keys():
    usage_str.append("%s=\"value\"" % k)
  print "wsadmin.sh -lang jython -f <script> %s" % " ".join(usage_str)

def verify_required():
  global required
  for k in required.keys():
    if required[k] == '':
      usage(required)
      sys.exit(1)

def parse_args(args, required):
  for a in args:
    n, v = a.split('=') 
    if not required.has_key(n):
      usage(required)
      sys.exit(1)
    else:
      set_required(n,v)

parse_args(sys.argv, required)
verify_required()

jvmargs = '-javaagent:/opt/appdynamics/AppServerAgent-ibm/javaagent.jar'
# Update as needed with Name:Value pairs
CUSTOM_PROPS = { 
'appagent.install.dir' 			:	'/opt/appdynamics/AppServerAgent-ibm',
'appdynamics.controller.hostName' 	:	required['controller'],
'appdynamics.controller.port' 		:	'8090',
'appdynamics.agent.tierName'		:	'GZ',
'appdynamics.agent.uniqueHostId'	:	'${WAS_SERVER_NAME}',
'appdynamics.agent.nodeName'		:	'${WAS_SERVER_NAME}',
'appdynamics.agent.applicationName'	:	required['applicationName'],
'appdynamics.agent.accountName'		:	required['accountName'],
'appdynamics.agent.accountAccessKey'	:	required['accountAccessKey']
}
ENV_ENTRIES = { 
"org.osgi.framework.bootdelegation"	:	"com.singularity.*"
}

def find_templates(objtype):
  return [s for s in AdminConfig.list(objtype).splitlines() if s.find('dynamicclusters')>=0 and s.find("/" + required['clustername'] + "/" )>=0]

dc = find_templates('Server')

# Find dynamic cluster server template jvm
djvm = find_templates('JavaVirtualMachine')

# Find dynamic cluster server template jpd
djpd = find_templates('JavaProcessDef')

def getCurrentArgs(jvm):
  argstr = AdminTask.showJVMProperties(jvm, '[-propertyName genericJvmArguments]')
  return argstr

def compileGenericJvmArgs(jvm, newstr):
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
    print "Cluster %s" % c.split('(')[0]
    newargs = compileGenericJvmArgs(c, jvmargs)
    print "New args"
    print newargs
    setJVMArgs(c, newargs)  
 
def updateCustomProps(djvm):
  for jvm in djvm:
    setCustomProp(jvm, CUSTOM_PROPS) 

def updateEnvEntries(djpd):
  for jpd in djpd:
    setCustomProp(jpd, ENV_ENTRIES)

class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def print_section(name, color):
  print '''%s
Updating %s
%s''' % (color, name, bcolors.ENDC)

print_section('Generic JVM Args', bcolors.OKBLUE)
updateJVMArgs(dc)
print_section('Custom Properties', bcolors.OKBLUE)
updateCustomProps(djvm)
print_section('Environment Entries', bcolors.OKBLUE)
updateEnvEntries(djpd)
print bcolors.WARNING
if required['save'] == 'yes':
  save()
