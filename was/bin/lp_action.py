import sys
lp_list = [lp for lp in AdminConfig.list('ListenerPort').splitlines()]

try:
  operation = sys.argv[0]
except:
  print '''Usage:

  wsadmin.sh -lang jython -f lp_action.py <status|start> <lp name> <jvm>
'''

def lp_status():
  for lp in lp_list:
    if AdminConfig.show(lp, 'connectionFactoryJNDIName').find('DISABLED') < 0:
      lp_name = AdminConfig.show(lp, 'name').split(' ')[1][:-1] 
      jvm = AdminConfig.show(lp, 'stateManagement').split(' ')[1][:-1].split('servers/')[1].split('|')[0]
      lp_state = AdminControl.getAttribute(AdminControl.queryNames("*:type=ListenerPort,name=%s,process=%s,*" % (lp_name, jvm)), 'started')
      print jvm,lp_name,lp_state

def lp_action(operation):
  try:
    lp_name = sys.argv[1]
    lp_jvm = sys.argv[2]
  except:
    print '''Usage:
	wsadmin.sh -lang jython -f start_listener.py <listener port name> <jvm>'''
    sys.exit(1)
  print "Attempting to %s LP: %s on JVM: %s" % (operation, lp_name, lp_jvm)
  AdminControl.invoke(AdminControl.queryNames("*:type=ListenerPort,name=%s,process=%s,*" % (lp_name, lp_jvm)), operation)
  print "Status is now: %s" % ( AdminControl.getAttribute(AdminControl.queryNames("*:type=ListenerPort,name=%s,process=%s,*" % (lp_name, lp_jvm)), 'started') )

if operation == 'status':
  lp_status()
else:
  lp_action(operation)
