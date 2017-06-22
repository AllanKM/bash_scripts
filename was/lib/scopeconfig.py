import sys
configdict = {}
def getAll():
  for t in types:
    yo = AdminConfig.list(t, id).strip()
    if len(yo) > 0:
      items = yo.splitlines()
      configdict.setdefault(t,items)
      for i in items:
        print "\t%s" % i
      print "*****"

def showSpecific(query):
  configdict.setdefault(query,AdminConfig.list(query,id).strip().splitlines())
  for i in configdict[query]:
    print "\033[95m%s\033[0m" % AdminConfig.show(i, 'name')[1:-1].split()[1].upper()
    print AdminConfig.show(i) 
    print "########"

def usage():
  print '''Do this you:
wsadmin.sh -lang jython -f /lfs/system/tools/was/lib/scopeconfig.py 'Cell:gzprd70wispe' MailSession

or

wsadmin.sh -lang jython -f /lfs/system/tools/was/lib/scopeconfig.py 'ServerCluster:p1_cluster_cust_app' Library
'''
  sys.exit()


if len(sys.argv) < 1:
  usage()
id=AdminConfig.getid('/%s/' % (sys.argv[0]))
types = [t for t in AdminConfig.types().splitlines()]
if len(sys.argv) == 2: 
  showSpecific(sys.argv[1])
else:
  getAll()
