# odrtrust.py
# 	Author: James Walton <jfwalton@us.ibm.com>	2012-03-29
#*******************************************************************************************************
import sys
import commands
def usage():
	print 'Usage: wsadmin -f odrtrust.py action plex/env ip/fqhostname'
	print '   * Actions    : add | remove '
	print '   * Plex/Env   : p1 | p2 | p3 | pre | cdt '
	print ''
	print 'Example: wsadmin -f odrtrust.py add p1 10.111.8.22'
	sys.exit()

def getTrustedSecurityProxies(odrpx):
	return AdminConfig.showAttribute(odrpx, 'trustedIntermediaryAddresses')
#*******************************************************************************************************
# Set defaults, parse passed arguments
argerr = 0
attrList = []
actList = 'add remove'
envList = 'p1 p2 p3 pre cdt dss'

i = 0
argc=len(sys.argv)
while ( i < argc ):
	arg = sys.argv[i]
	if (actList.find(arg) >= 0): action = arg
	elif (envList.find(arg) >= 0): odrDC = arg+'_cluster_odr'
	else: trustedProxy = arg
	i += 1

actionExists = ('action' in locals().keys() or 'action' in globals().keys())
odrExists = ('odrDC' in locals().keys() or 'odrDC' in globals().keys())
tpExists = ('trustedProxy' in locals().keys() or 'trustedProxy' in globals().keys())
#*******************************************************************************************************
#*******************************************************************************************************
# Get current trusted security proxy list
odrPX = AdminConfig.getid('/DynamicCluster:'+odrDC+'/Server:'+odrDC+'/ProxySettings:/')
trustProxies = getTrustedSecurityProxies(odrPX)
tpxList = trustProxies.split(';')
if (action == 'add'):
	# Check current list, verify that the string doesn't already exist
	if trustedProxy in tpxList:
		#Found the requested trusted proxy in the list, do not add
		print 'Requested trusted security proxy ('+trustedProxy+') already configured. No action required.'
		sys.exit(1)
	else:
		#Didn't find the new trusted proxy, add it
		print 'Adding new trusted security proxy ('+trustedProxy+')'
		updatedProxies = trustProxies+';'+trustedProxy
elif (action == 'remove'):
	# Check current list, verify that the string doesn't already exist
	if trustedProxy in tpxList:
		#Found the requested trusted proxy in the list, attempt to remove it
		print 'Removing trusted security proxy ('+trustedProxy+')'
		tpxList.remove(trustedProxy)
		updatedProxies = ';'.join(tpxList)
		#Need to wipe out the current list before re-populating.
		noattr1 = ['trustedIntermediaryAddresses', []]
		noattr = [noattr1]
		try: AdminConfig.modify(odrPX, noattr)
		except:
			print '### Error attempting to clear trusted security proxy for removal:',sys.exc_info()
			sys.exit(1)
	else:
		#Didn't find the new trusted proxy, nothing to do
		print 'Requested trusted security proxy ('+trustedProxy+') not configured. No action required.'
		sys.exit(1)
else:
	print 'You can only add or remove trusted security proxies, what are you doing? You should not even be here.'
	sys.exit(1)

attr1 = ['trustedIntermediaryAddresses', updatedProxies]
attrs = [attr1]
try: AdminConfig.modify(odrPX, attrs)
except:
	print '### Error attempting to '+action+' trusted security proxy:',sys.exc_info()
	sys.exit(1)
else: AdminConfig.save()
print 'Synchronizing VE cell. ',
nodelist = AdminControl.queryNames('WebSphere:name=nodeSync,process=nodeagent,type=NodeSync,*').splitlines()
errcnt=0
for nodesync in nodelist:
	try: AdminControl.invoke(nodesync, 'sync')
	except:
		print '### Could not sync node: '+nodesync
		print '### Error details:',sys.exc_info()
		errcnt += 1
if (errcnt > 0): print 'Warning: '+errcnt+' not all nodes successfully completed sync.'
else: print 'Success!'
