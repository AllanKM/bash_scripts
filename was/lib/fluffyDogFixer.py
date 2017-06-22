#*******************************************************************************************************
# fluffyDogFixer.py
#
#   Author: James Walton
#   Initial Revision Date: 10/21/2014
#
#*******************************************************************************************************
import sys
def usage():
	print 'Usage:'
        print '   wsadmin -lang jython -f fluffyDogFixer.py on|off|show\n'
        print 'on  == enable POODLE SSLv3 mitigation by setting all SSL configurations to TLS (TLSv1)'
        print 'off == revert POODLE SSLv3 mitigation by setting all SSL configurations to SSL_TLS (SSLv3 + TLSv1)'

# Commandline parameter handling
#*******************************************************************************************************
actionList = ['on', 'off', 'show']
poodleFix = sys.argv[0]

try: actionList.index(poodleFix)
except:
        print '### You MUST specify on, off, or status as arguments to fluffyDogFixer.py'
	usage()
        sys.exit()

# Go for fluffy dog fixing/unfixing
#*******************************************************************************************************
sslConfigList = AdminConfig.list('SSLConfig').splitlines()

if (poodleFix == 'show'):
	for sslCfg in sslConfigList:
		sslAlias = AdminConfig.showAttribute(sslCfg, 'alias')
		sslSetting = AdminConfig.showAttribute(sslCfg, 'setting')
		sslProtocol = AdminConfig.showAttribute(sslSetting, 'sslProtocol')
		print 'SSL Config ( %-25s ) using protocol:  %s' % (sslAlias,sslProtocol)
else:
	if (poodleFix == 'on'): sslProtocol = 'TLS'
	else: sslProtocol = 'SSL_TLS'
	
	for sslCfg in sslConfigList:
		sslAlias = AdminConfig.showAttribute(sslCfg, 'alias')
		sslSetting = AdminConfig.showAttribute(sslCfg, 'setting')
		attrs = [['sslProtocol', sslProtocol]]
		if (AdminConfig.showAttribute(sslSetting, 'sslProtocol') != sslProtocol):
			print 'SSL Config ( %-25s ) MODIFY to protocol:  %s     ' % (sslAlias,sslProtocol),
			try: AdminConfig.modify(sslSetting, attrs)
			except:
				print '[FAILED]'
				print '### Error occurred while modifying SSL configuration ('+ sslAlias +') - exiting without save.'
	          		print sys.exc_info()
	          		sys.exit()
	          	print '[SUCCESS]'
			AdminConfig.save()
		else:
			print 'SSL Config ( %-25s ) already @ protocol:  %s' % (sslAlias,sslProtocol)
	#end for loop
	secConf = AdminConfig.list('Security')
	dynSSLCfg = AdminConfig.showAttribute(secConf, 'dynamicallyUpdateSSLConfig')
	if (dynSSLCfg == 'true'): print '\nYou MUST SYNC all nodes for changes to take effect. JVM restarts are NOT necessary.'
	else: print '\nYou MUST SYNC all nodes for changes to take effect, and JVMs MUST be restarted.'
#end if/else