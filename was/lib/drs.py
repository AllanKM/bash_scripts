session_mode = [drs for drs in AdminConfig.list('DRSSettings').splitlines() if drs.find('/servers/')>=0]
jvm = lambda x: x.split('|')[0].split('servers/')[1]
drm = lambda x: AdminConfig.show(x, 'dataReplicationMode')[1:-1].split(' ')
cell = AdminConfig.list('Cell').split('(')[0]
drsdata = {}
def outputSessionMode(session_mode):
  drsdata.setdefault(cell, {})
  for sess in session_mode:
    drmval = drm(sess)
    drsdata[cell].setdefault(jvm(sess), {drmval[0]:drmval[1]})

outputSessionMode(session_mode)
print str(drsdata).replace('\'', '"')
