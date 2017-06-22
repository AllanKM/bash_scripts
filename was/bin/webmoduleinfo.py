import re
applist = [app for app in AdminApp.list().splitlines()]
wmdict = {}
wmlist = []
wm = ''
cell = AdminConfig.list('Cell').split('(')[0]
vhostdict = {}
dsdict = {}
clusterdict = {}
jvmdict = {}
portdict = {}
versdict = {}
jvminfolist = []

def get_port(jvm,portname):
  port = ''
  se=[se for se in AdminConfig.list('ServerEntry').splitlines() if se.find(jvm) == 0][0]
  for ep in AdminConfig.showAttribute(se, 'specialEndpoints')[1:-1].split(' '):
    name = AdminConfig.showAttribute(ep, 'endPointName')
    if (name == portname):
      port = AdminConfig.showAttribute(AdminConfig.showAttribute(ep, 'endPoint'), 'port')
      portdict.setdefault(jvm, port)
  return port

dmgr_url = "https://%s.event.ibm.com:%s/ibm/console" % (cell,get_port('dmgr', 'WC_adminhost_secure'))

def get_jvminfo_dict():
  jvmproclist = [jvmproc for jvmproc in AdminConfig.list('JavaVirtualMachine').splitlines() if jvmproc.find('dynamicclusters')<0]
  for jvmproc in jvmproclist:
    try:
      cp = AdminConfig.show(jvmproc, ['classpath'])[1:-1].split(' ')[1]
    except:
      cp = ''
    try:
      genJA = AdminConfig.show(jvmproc, ['genericJvmArguments'])[1:-1].split(' ')[1]
    except:
      genJA = ''
    try:
      minH = AdminConfig.show(jvmproc, ['initialHeapSize'])[1:-1].split(' ')[1]
    except:
      minH = ''
    try:
      maxH = AdminConfig.show(jvmproc, ['maximumHeapSize'])[1:-1].split(' ')[1]
    except:
      maxH = ''
    nodestuff = re.search('/nodes/(\w+)/servers/(\w+)',jvmproc)
    node,jvm = nodestuff.group(1),nodestuff.group(2)
    jvminfolist.append("%s^%s^%s::%s::%s::%s" % (jvm,node,cp,genJA,minH,maxH))

get_jvminfo_dict()

def get_vhost_dict():
  vhostidlist = [vhost for vhost in AdminConfig.list('VirtualHost').splitlines()]# if vhost.find('admin_host')!=0 and vhost.find('default_host')!=0]
  for vhostid in vhostidlist: 
    a1 = AdminConfig.show(vhostid, ['aliases']).replace('[','').replace(']','').replace('"','')
    a2 = " ".join(a1.split(' ')[1:])
    hosts = " ".join([AdminConfig.showAttribute(alias, 'hostname') for alias in a2.split(' ')])
    vhostdict.setdefault(vhostid.split('(')[0], hosts)

get_vhost_dict()

def get_cluster_dict():
  clusters = AdminConfig.list('ServerCluster').splitlines()
  for cluster in clusters:
    jvms = [jvm.split('(')[0] for jvm in AdminConfig.showAttribute(cluster, 'members')[1:-1].split(' ')]
    cluster_short = cluster.split('(')[0]
    clusterdict.setdefault(cluster_short, jvms)
    for jvm in jvms:
      jvmdict.setdefault(jvm, cluster_short)
 
get_cluster_dict()

def get_version_dict():
  nodes = [node.split('(')[0] for node in AdminConfig.list('Node').splitlines()]
  for node in nodes:
    versdict.setdefault(node, AdminTask.getNodeBaseProductVersion('[-nodeName %s]' % node))

get_version_dict()


class WebModule:
  app = 0
  uri = ''
  vhost = ''
  croot = ''
  mapping = ''
  servers = ''
  wm = ''
  ear = ''
  dmgr = dmgr_url
  def __str__(self):
    #return "%s,%s,%s,%s,\'%s\',%s" % (self.uri,self.vhost,self.croot,self.dmgr,self.mapping,self.servers)
    return "%s,%s,%s,%s,%s,\'%s\',%s" % (self.ear,self.wm,self.vhost,self.croot,self.dmgr,self.mapping,self.servers)

class DataSource:
  scope = ''
  jndi = ''
  auth = ''
  name = ''
  jdbc = ''
  def __str__(self):
    return "%s,%s,%s,%s,%s" % (self.name,self.jndi,self.jdbc,self.auth,self.scope)

def find_members(mapping):
  jvmlist = mapping.replace("WebSphere:","")
  jvmstring = ''
  members = 1
  for jvm in jvmlist.split('+'):
    jvms = re.search('cluster=(\w+)',jvm)
    try:
      cluster = jvms.group(1)
      memberstring = " ".join(clusterdict[cluster])
      if jvmstring == '':
         jvmstring = "%s" % (memberstring)
      else:
         jvmstring = "%s %s" % (jvmstring, memberstring)
    except:
      members = 0  
  if members == 1:
    #servers = [":".join((server,get_port(server,'WC_defaulthost_secure'))) for server in jvmstring.split(' ')]
    #return " ".join(servers)
    # Ports will be populated to portdict - return value not needed, hence the garbage 
    garbage = [get_port(jvm,'WC_defaulthost_secure') for jvm in jvmstring.split(' ')]
    return jvmstring
  else:
    return ""

def get_datasources():
  DSlist = [ds for ds in AdminConfig.list('DataSource').splitlines() if ds.find('DefaultEJBTimer') != 0]
  for ds in DSlist:
    scope = ds.split('|')[0].split('(')[1]
    jndi = AdminConfig.show(ds, 'jndiName').split(' ')[1][:-1]
    auth = AdminConfig.show(ds, 'authDataAlias').split(' ')[1][:-1]
    name = AdminConfig.show(ds, 'name').split(' ')[1][:-1]
    jdbc = "%s)" % AdminConfig.show(ds, 'provider').split(' ')[1][:-1].split('|')[0]
    dsdict.setdefault(ds, DataSource())
    dsdict[ds].scope = scope
    dsdict[ds].jndi = jndi
    dsdict[ds].name = name
    dsdict[ds].jdbc = jdbc
    dsdict[ds].auth = auth

def selective_print(ear):
  mywmlist = [wm for wm in AdminApp.listModules(ear).splitlines() if wm.find('web.xml')>=0]
  for wm in mywmlist:
    mywm = WebModule()
    mywm.ear = ear
    for line in AdminApp.view(wm).splitlines():
      if line.find('ContextRoot: ')==0 or line.find('Context Root: ')==0:
        mywm.croot = line.split(':  ')[1]
      if line.find('Server: ')==0:
        mywm.mapping = line.split(':  ')[1]
        mywm.mapping = mywm.mapping.replace(',',' ')
        mywm.servers = find_members(mywm.mapping)
      if line.find('Virtual host: ')==0:
        mywm.vhost = line.split(':  ')[1]
      if line.find('Web module: ')==0:
        mywm.wm = line.split(':  ')[1]
    if mywm.vhost == '':
      vhostaliases = ''
    else:
      vhostaliases = vhostdict[mywm.vhost]
    print "WM^%s^%s,%s" % (cell,mywm,vhostaliases)

def start():
  count = 0
  [selective_print(app) for app in applist]
#  get_datasources()
  # Print datasource information with each line beginning with DS^cell^
#  for key in dsdict.keys():
#    print "DS^%s^%s" % (cell,dsdict[key])
  # Print out cluster and members with each line beginning with CLUSTER^cell^
  for key in clusterdict.keys():
    print "CLUSTER^%s^%s::%s" % (cell,key," ".join(clusterdict[key]))
  # Print out jvms and their WC_default_secure port
  for key in portdict.keys():
    print "PORT^%s^%s::%s" % (cell,key,portdict[key])
  for key in versdict.keys():
    print "VERSION^%s^%s::%s" % (cell,key,versdict[key])
  for jvminfo in jvminfolist:
    print "JVMINFO^%s^%s" % (cell,jvminfo)

start()
