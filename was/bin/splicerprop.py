import sys
cell=AdminConfig.list('Cell').split('(')[0]
operation = sys.argv[0]
if operation == 'list':
  filter = ''
else:
  filter = sys.argv[1]
if len(sys.argv) == 3:
  if sys.argv[2] == 'save':
    save = 1
  else:
    save = 0
else:
  save = 0

splicerprops = [sf for sf in AdminConfig.list('Property', AdminConfig.list('Cell')).splitlines() if sf.find('sessionFilterProps') >= 0]
SPDICT = {}

def populateDict():
  global splicerprops
  for sp in splicerprops:
    id = "(%s" % sp.split('(')[1]
    spname = sp.split(',com.ibm.websphere.xs.sessionFilterProps')[0][1:] # Remove leading "
    SPDICT.setdefault(spname, id)

populateDict()

def listSplicer():
  global splicerprops, SPDICT
  for i in SPDICT.keys():
    try:
      print "%s : %s" % ( i, AdminConfig.show(SPDICT[i], ['value']) ) 
    except:
      pass

def removeSplicer(filter):
  global splicerprops, SPDICT, save, cell
  if SPDICT.has_key(filter):
    name = '%s,com.ibm.websphere.xs.sessionFilterProps' % filter
    value = AdminConfig.show(SPDICT[filter], ['value']).split(' ')[1][0:-1]
    print "\nBefore\n"
    listSplicer()
    print "\nAfter\n"
    AdminConfig.remove(SPDICT[filter])
    listSplicer()
    print "\n"
    if save == 1:
      print "Saving\n"
      AdminConfig.save()
    else:
      print "Not Saving\n"
  else:
    print "%s not found" % filter
  
  
if operation == 'list':
  listSplicer()
elif operation == 'remove':
  removeSplicer(filter) 
