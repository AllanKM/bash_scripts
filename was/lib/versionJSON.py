#!/usr/bin/python
import os,sys,subprocess,re,json
HOSTNAME = os.uname()[1]
dirdict = {}
# version scripts and options needed to spit out efix lists
verscripts = {'versionInfo.sh' : " -maintenancepackages", 'WPVersionInfo.sh': ' -fixes'}
verfilter = lambda x: " ".join(verscripts.keys()).find(x)>=0

versions = ['','60','61','70','80','85']
base = '/usr'
products = ['WebSphere', 'HTTPServer']
subdir = ['AppServer/bin','PortalServer/bin','UpdateInstaller/bin','bin', 'Plugins/bin', 'Plugins70/bin', 'Plugins60/bin', 'Plugins61/bin', 'HTTPServer/bin', 'Plugin/bin']

dirdict = {}
# Build list of possible names to look for
# { 'WebSphere' : [list of different versions + product name to check], ...}
[dirdict.setdefault(p, map(lambda x: p+x, versions)) for p in products]
direxist = []
binexist = []
scripts = []
fullversionDict = {}
LOGS = [] # for logging yo

# Final Dict, nah, I didnt make too many
FULL = {}

def writelogs():
  print type(LOGS)
  msgs = "\n".join(LOGS)
  f = open('/tmp/%s.log' % HOSTNAME, 'w')
  f.write(msgs)
  f.close()

def LOG(msg):
  LOGS.append(msg)

def findprodbase(dirname):
  dir = "%s/%s" % (base, dirname)
  if os.path.exists(dir) and not os.path.islink(dir):
    direxist.append(dir)

def findfirstbin(dirname):
  for s in subdir:
    dir = "%s/%s" % (dirname, s)
    if os.path.exists(dir):
      binexist.append(dir)

def pushtolist(dir, flist):
  for f in flist:
    scripts.append("%s/%s%s" % (dir, f, verscripts[f]))

def process_output(script):
  fullversionDict.setdefault(script.split()[0], [])
  process = subprocess.Popen(script.split(), stdout=subprocess.PIPE)
  out = process.communicate()[0]
  splitter = re.compile(r'\nInstalled\s(\w+\s?)+\n[-]+\n')
  for item in splitter.split(out)[1:]:
    attrs = {}
    #p = re.compile(r'(\w+\s+){2,}\n')
    for i in item.split('\n'):
      p = re.compile(r'\s{2,}')
      l = p.split(i)
      if len(l) == 2:
        attrs.setdefault(l[0], l[1])
    fullversionDict[script.split()[0]].append(attrs)
    #print attrs
  
def testOutput(d):
  for k in d.keys():
    print k
    print "     "
    for i in d[k]:
      for j in i.keys():
        print "                %s\t%s" % (j, i[j])


# Find base dirs that exist, /usr/HTTPServerXX, /usr/WebSphereXX
for k in dirdict.keys():
  map(findprodbase, dirdict[k])

# No products exist
if len(direxist) == 0:
  LOG( "No products")
  sys.exit(1)

# Find bin within subdirs - push to binexist list
for f in direxist:
  LOG( "finding bin dirs")
  findfirstbin(f)

# List of executable version scripts
LOG( "finding versioninfo scripts")
[ pushtolist(f, filter(verfilter, os.listdir(f))) for f in binexist] 
LOG( "\n".join(binexist))
if len(binexist)==0:
  sys.exit(1)

LOG( "parsing version script output")
for s in scripts:
  process_output(s)

#testOutput(fullversionDict)
FULL.setdefault(HOSTNAME, fullversionDict)
LOG( "dumping contents to json")
if len(scripts)>0: 
  outDir = '/fs/scratch/json'
  try:
    os.makedirs(outDir)
  except:
    pass
  fn = "%s/%s.json" % (outDir,HOSTNAME)
  f = open(fn, 'w')
  f.write(json.dumps(FULL))
  f.close()
writelogs()
