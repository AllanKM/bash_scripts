dsL = [d for d in AdminConfig.list('DataSource').splitlines() if d.find('EJBTimerDataSource') < 0]
authDict = {}

def getAuth():
  authL = AdminConfig.list('JAASAuthData').splitlines()
  for auth in authL:
    alias = AdminConfig.show(auth, 'alias')[1:-1].split()[1]
    userId = AdminConfig.show(auth, 'userId')[1:-1].split()[1]
    authDict.setdefault(alias, userId)

def processPropSet(ps):
  psattr = " ".join(AdminConfig.show(ps).split()[1:]).replace('[','').replace(']','').split()
  attrDict = {}
  for ps in psattr:
    name = AdminConfig.show(ps, ['name'])[1:-1].split()[1]
    value = AdminConfig.show(ps, ['value'])[1:-1].split()[1]
    attrDict.setdefault(name, value)
  return attrDict

def checkVar(myvar,showDict):
  if showDict.has_key(myvar):
    return showDict[myvar]
  else:
    return ''

def main():
  print "Datasource,DB,Server,Port,JNDI,Scope,JAASUser,Schema"
  for ds in dsL:
    dsname = AdminConfig.show(ds,['name'])[1:-1].split()[1]
    jndiname = AdminConfig.show(ds, 'jndiName')[1:-1].split()[1]
    ps = AdminConfig.show(ds, ['propertySet'])[1:-1].split()[1]
    #(cells/gzprd70wi2/clusters/p1_cluster_cnp_support_electronic_entitlementAS|resources.xml#DataSource_1390305684795)
    scope = ds.split('/')[-1].split('|')[0]
    # authDataAlias
    showDict = processPropSet(ps)
    try:
      authalias = AdminConfig.show(ds, 'authDataAlias')[1:-1].split()[1]
      auth = authDict[authalias]
    except:
      auth = checkVar('user',showDict)
    db = checkVar('databaseName',showDict)
    sn = checkVar('serverName',showDict)
    pn = checkVar('portNumber',showDict)
    cs = checkVar('currentSchema',showDict)
    print "%s,%s,%s,%s,%s,%s,%s,%s" % (dsname,db,sn,pn,jndiname,scope,auth,cs)
    #print "%s,%s,%s,%s,%s,%s,%s,%s" % (dsname,showDict['databaseName'],showDict['serverName'],showDict['portNumber'],jndiname,scope,auth,showDict['currentSchema'])

def test():
  dsname = AdminConfig.show(dsL[-1],['name'])[1:-1].split()[1]
  ps = AdminConfig.show(dsL[-1], ['propertySet'])[1:-1].split()[1]
  showDict = processPropSet(ps)
  try:
    print "%s,%s,%s,%s" % (dsname,showDict['databaseName'],showDict['serverName'],showDict['portNumber'])
  except:
    print showDict

getAuth()
main()

