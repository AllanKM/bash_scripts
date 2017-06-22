#
# Delete ldap endpoint from security configuration on websphere
#
# Syntax:
# 
# ./wsadmin.sh -lang jython -f ldapdel.py <search string> [-noprompt] [-save]
#

import sys
try:
  search = sys.argv[0]
except:
  print "Please specify a search filter for the LDAPUserRegistry"
  sys.exit()

save = any(arg == '-save' for arg in sys.argv)
noprompt = any(arg == '-noprompt' for arg in sys.argv)

def delete(host):
  print "\nDeleting %s : %s\n" % (getHost(host), host)
  AdminConfig.remove(host)

def getHostList(search):
  return [hostid for hostid in AdminConfig.showAttribute(ldap, 'hosts')[1:-1].split(' ') if getHost(hostid).find(search) >= 0]

getHost = lambda x: AdminConfig.showAttribute(x, 'host')
getPort = lambda x: AdminConfig.showAttribute(x, 'port')

ldap=AdminConfig.list("LDAPUserRegistry")
hostList=getHostList(search)

for host in hostList:
  name = "%s:%s" % (getHost(host), getPort(host))
  print "LDAPUserRegistry: %s \nLDAPServer: %s" % (host, name)
  if not noprompt:
    answer = raw_input("Delete this host? (y/n) ")
  else:
    answer = 'y'
  if answer == 'y':
    delete(host)

if not save:
  saveYN = raw_input("Save configuration? (y/n) ")
else:
  saveYN = 'y'
if saveYN == 'y':
  AdminConfig.save()
