# getCmpData.py -- library file for use in get_wascmp_data.sh to gather comparison data.
#   Author: James Walton
#   Initial Revision Date: 02 Mar 2010
import sys
global AdminConfig
#*******************************************************************************************************
# Functions
def usage():
        print 'Usage:'
        print '   wsadmin -lang jython -f getCmpData.py <dataType>'
        print '   Data types: jvm | jdbc | jms | mail | libs | env'

def envData():
	skipVars = ['WAS_INSTALL_ROOT', 'USER_INSTALL_ROOT', 'WAS_LIBS_DIR', 'WAS_PROPS_DIR', \
		'APP_INSTALL_ROOT', 'WAS_TEMP_DIR', 'LOG_ROOT', 'DRIVER_PATH', 'JAVA_HOME', \
		'MQ_INSTALL_ROOT', 'JVM_CACHE', 'DEPLOY_TOOL_ROOT', 'CONNECTOR_INSTALL_ROOT', \
		'WAS_ETC_DIR', 'WAS_CELL_NAME', 'WAS_SERVER_NAME', 'DB2390_JDBC_DRIVER_PATH', \
		'OS400_NATIVE_JDBC_DRIVER_PATH', 'OS400_TOOLBOX_JDBC_DRIVER_PATH', 'SERVER_LOG_ROOT', \
		'INFORMIX_JDBC_DRIVER_PATH', 'SYBASE_JDBC_DRIVER_PATH', 'ORACLE_JDBC_DRIVER_PATH', \
		'CONNECTJDBC_JDBC_DRIVER_PATH', 'MSSQLSERVER_JDBC_DRIVER_PATH', 'UNIVERSAL_JDBC_DRIVER_PATH', \
		'DB2UNIVERSAL_JDBC_DRIVER_NATIVEPATH', 'WAS_INSTALL_LIBRARY', 'DERBY_JDBC_DRIVER_PATH', \
		'MICROSOFT_JDBC_DRIVER_NATIVEPATH', 'MICROSOFT_JDBC_DRIVER_PATH', 'User-defined_JDBC_DRIVER_PATH' \
		]
	for varMap in AdminConfig.list('VariableMap').splitlines():
		varScope = varMap.split('|')[0].split('/')[-1]
		#Length 2 means the scope has no variables defined
		if (len(AdminConfig.showAttribute(varMap, 'entries')) != 2):
			for varEntry in AdminConfig.showAttribute(varMap, 'entries').split('[')[1].split(']')[0].split():
				varName = AdminConfig.showAttribute(varEntry, 'symbolicName')
				varValue = AdminConfig.showAttribute(varEntry, 'value')
				if (varValue == ''): varValue = '<undef>'
				if varName in skipVars: continue
				else: print 'ENV|'+varName+'|'+varScope+'|'+varValue

def jdbcProviderData():
	for jdbcPrv in AdminConfig.list('JDBCProvider').splitlines():
		jdbcScope = jdbcPrv.split('|')[0].split('/')[-1]
		#Skip default Derby providers
		if (jdbcPrv[1:6] != 'Derby'):
			jdbcName = AdminConfig.showAttribute(jdbcPrv, 'name')
			jdbcCP = AdminConfig.showAttribute(jdbcPrv, 'classpath')
			jdbcImpl = AdminConfig.showAttribute(jdbcPrv, 'implementationClassName')
			jdbcXA = AdminConfig.showAttribute(jdbcPrv, 'xa')
			if (jdbcXA == 'true'): jdbcXA = 'XA'
			else: jdbcXA = 'Non-XA'
			print 'JDBCPRV|'+jdbcName+'|'+jdbcScope+'|'+jdbcXA+'|'+jdbcCP+'|'+jdbcImpl

def jdbcDatasourceData():
	for jdbcDS in AdminConfig.list('DataSource').splitlines():
		dsScope = jdbcDS.split('|')[0].split('/')[-1]
		#Skip default Derby providers
		if (AdminConfig.showAttribute(jdbcDS, 'name') != 'DefaultEJBTimerDataSource'):
			dsName = AdminConfig.showAttribute(jdbcDS, 'name')
			dsJNDI = AdminConfig.showAttribute(jdbcDS, 'jndiName')
			dsStCache = AdminConfig.showAttribute(jdbcDS, 'statementCacheSize')
			dsConnPool = AdminConfig.showAttribute(jdbcDS, 'connectionPool')
			dsCPAgeTO = AdminConfig.showAttribute(dsConnPool, 'agedTimeout')
			dsCPConTO = AdminConfig.showAttribute(dsConnPool, 'connectionTimeout')
			dsCPUnuTO = AdminConfig.showAttribute(dsConnPool, 'unusedTimeout')
			dsCPReap = AdminConfig.showAttribute(dsConnPool, 'reapTime')
			dsCPPurge = AdminConfig.showAttribute(dsConnPool, 'purgePolicy')
			dsCPMin = AdminConfig.showAttribute(dsConnPool, 'minConnections')
			dsCPMax = AdminConfig.showAttribute(dsConnPool, 'maxConnections')
			dsProps = AdminConfig.showAttribute(jdbcDS, 'propertySet')
			dsProps = AdminConfig.showAttribute(dsProps, 'resourceProperties').split('[')[1].split(']')[0].split()
			dsDBSchem = ''
			for prop in dsProps:
				propName = AdminConfig.showAttribute(prop, 'name')
				if (propName == 'databaseName'): dsDBName = AdminConfig.showAttribute(prop, 'value')
				elif (propName == 'driverType'): dsDBDriver = AdminConfig.showAttribute(prop, 'value')
				elif (propName == 'serverName'): dsDBHost = AdminConfig.showAttribute(prop, 'value')
				elif (propName == 'portNumber'): dsDBPort = AdminConfig.showAttribute(prop, 'value')
				elif (propName == 'currentSchema'): dsDBSchema = AdminConfig.showAttribute(prop, 'value')
				else: continue
			if (dsDBSchema == ''): dsDBSchema = '<undef>'
			print 'JDBCDS|'+dsName+'|'+dsScope+'|'+dsJNDI+'|'+dsStCache \
			 +'|'+dsCPMin+'|'+dsCPMax+'|'+dsCPAgeTO+'|'+dsCPConTO+'|'+dsCPUnuTO+'|'+dsCPReap+'|'+dsCPPurge \
			 +'|'+dsDBName+'|'+dsDBDriver+'|'+dsDBHost+'|'+dsDBPort+'|'+dsDBSchema

def mqConnFactoryData():
	for mqCF in AdminConfig.list('MQConnectionFactory').splitlines():
		cfScope = mqCF.split('|')[0].split('/')[-1]
		cfName = AdminConfig.showAttribute(mqCF, 'name')
		cfJNDI = AdminConfig.showAttribute(mqCF, 'jndiName')
		cfHost = AdminConfig.showAttribute(mqCF, 'host')
		cfPort = AdminConfig.showAttribute(mqCF, 'port')
		cfChan = AdminConfig.showAttribute(mqCF, 'channel')
		cfQmgr = AdminConfig.showAttribute(mqCF, 'queueManager')
		cfTrans = AdminConfig.showAttribute(mqCF, 'transportType')
		cfCipher = AdminConfig.showAttribute(mqCF, 'sslCipherSuite')
		cfBrCtrl = str(AdminConfig.showAttribute(mqCF, 'brokerControlQueue'))
		cfXA = AdminConfig.showAttribute(mqCF, 'XAEnabled')
		cfConnPool = AdminConfig.showAttribute(mqCF, 'connectionPool')
		cfCPAgeTO = AdminConfig.showAttribute(cfConnPool, 'agedTimeout')
		cfCPConTO = AdminConfig.showAttribute(cfConnPool, 'connectionTimeout')
		cfCPUnuTO = AdminConfig.showAttribute(cfConnPool, 'unusedTimeout')
		cfCPReap = AdminConfig.showAttribute(cfConnPool, 'reapTime')
		cfCPPurge = AdminConfig.showAttribute(cfConnPool, 'purgePolicy')
		cfCPMin = AdminConfig.showAttribute(cfConnPool, 'minConnections')
		cfCPMax = AdminConfig.showAttribute(cfConnPool, 'maxConnections')
		cfSessPool = AdminConfig.showAttribute(mqCF, 'connectionPool')
		cfSPAgeTO = AdminConfig.showAttribute(cfSessPool, 'agedTimeout')
		cfSPConTO = AdminConfig.showAttribute(cfSessPool, 'connectionTimeout')
		cfSPUnuTO = AdminConfig.showAttribute(cfSessPool, 'unusedTimeout')
		cfSPReap = AdminConfig.showAttribute(cfSessPool, 'reapTime')
		cfSPPurge = AdminConfig.showAttribute(cfSessPool, 'purgePolicy')
		cfSPMin = AdminConfig.showAttribute(cfSessPool, 'minConnections')
		cfSPMax = AdminConfig.showAttribute(cfSessPool, 'maxConnections')
		if (cfXA == 'true'): cfXA = 'XA'
		else: cfXA = 'Non-XA'
		print 'MQCF|'+cfName+'|'+cfScope+'|'+cfJNDI+'|'+cfHost+'|'+cfPort+'|'+cfChan+'|'+cfQmgr \
		 +'|'+cfTrans+'|'+cfCipher+'|'+cfBrCtrl+'|'+cfXA \
		 +'|'+cfCPMin+'|'+cfCPMax+'|'+cfCPAgeTO+'|'+cfCPConTO+'|'+cfCPUnuTO+'|'+cfCPReap+'|'+cfCPPurge \
		 +'|'+cfSPMin+'|'+cfSPMax+'|'+cfSPAgeTO+'|'+cfSPConTO+'|'+cfSPUnuTO+'|'+cfSPReap+'|'+cfSPPurge

def mqQueueData():
	for mqQue in AdminConfig.list('MQQueue').splitlines():
		qScope = mqQue.split('|')[0].split('/')[-1]
		qName = AdminConfig.showAttribute(mqQue, 'name')
		qJNDI = AdminConfig.showAttribute(mqQue, 'jndiName')
		qHost = AdminConfig.showAttribute(mqQue, 'queueManagerHost')
		qPort = AdminConfig.showAttribute(mqQue, 'queueManagerPort')
		qChan = AdminConfig.showAttribute(mqQue, 'serverConnectionChannelName')
		qClient = AdminConfig.showAttribute(mqQue, 'targetClient')
		qQueue = AdminConfig.showAttribute(mqQue, 'baseQueueName')
		qQmgr = AdminConfig.showAttribute(mqQue, 'baseQueueManagerName')
		qPersist = AdminConfig.showAttribute(mqQue, 'persistence')
		qPriority = AdminConfig.showAttribute(mqQue, 'priority')
		qSpecPry = AdminConfig.showAttribute(mqQue, 'specifiedPriority')
		qExpiry = AdminConfig.showAttribute(mqQue, 'expiry')
		qSpecExp = AdminConfig.showAttribute(mqQue, 'specifiedExpiry')
		qNatEnc = AdminConfig.showAttribute(mqQue, 'useNativeEncoding')
		qIntEnc = AdminConfig.showAttribute(mqQue, 'integerEncoding')
		qDecEnc = AdminConfig.showAttribute(mqQue, 'decimalEncoding')
		qFlpEnc = AdminConfig.showAttribute(mqQue, 'floatingPointEncoding')
		if (qNatEnc == 'true'): qNatEnc = 'Native'
		else: qNatEnc = 'Non-Native'
		print 'MQQ|'+qName+'|'+qScope+'|'+qJNDI+'|'+qHost+'|'+qPort+'|'+qChan+'|'+qClient \
		 +'|'+qQueue+'|'+qQmgr+'|'+qPersist+'|'+qPriority+'|'+qSpecPry+'|'+qExpiry+'|'+qSpecExp \
		 +'|'+qNatEnc+'|'+qIntEnc+'|'+qDecEnc+'|'+qFlpEnc

def jvmData():
	cookies = 'Cookies-OFF'
    	sslTrack = 'SSLTrack-OFF'
    	urlRewrt = 'UrlRW-OFF'
    	prsRewrt = 'PrtSwRW-OFF'
    	secInt = 'SecInt-OFF'
	for server in AdminConfig.list('Server').splitlines():
		sName = AdminConfig.showAttribute(server, 'name')
		nName = server.split('(')[1].split('/')[3]
		clName = str(AdminConfig.showAttribute(server, 'clusterName'))
		#Get necessary cfg object handles
		nsID = '/Node:'+nName+'/Server:'+sName
		procdef = AdminConfig.getid(nsID+'/JavaProcessDef:/')
		jvmcfg = AdminConfig.getid(nsID+'/JavaProcessDef:/JavaVirtualMachine:/')
		wcCfg = AdminConfig.getid(nsID+'/ApplicationServer:/WebContainer:/')
		wctcfg = AdminConfig.getid(nsID+'/ThreadPoolManager:/ThreadPool:WebContainer/')
		sessMgr = AdminConfig.getid(nsID+'/ApplicationServer:/WebContainer:/SessionManager:/')
		drsCfg = AdminConfig.getid(nsID+'/ApplicationServer:/WebContainer:/SessionManager:/DRSSettings:/')
		tuneCfg = AdminConfig.getid(nsID+'/ApplicationServer:/WebContainer:/SessionManager:/TuningParams:/')
		webPlg = AdminConfig.getid(nsID+'/ApplicationServer:/WebserverPluginSettings:/')
		
		#Pull JVM cfg data items
		maxHeap = AdminConfig.showAttribute(jvmcfg, 'maximumHeapSize')
        	minHeap = AdminConfig.showAttribute(jvmcfg, 'initialHeapSize')
        	classPath = AdminConfig.showAttribute(jvmcfg, 'classpath')
        	if (classPath == '' or classPath == '[]'): classPath = '<undef>'
        	genJvmArgs = AdminConfig.showAttribute(jvmcfg, 'genericJvmArguments')
        	#Filter out any ITCAM args
        	if (genJvmArgs.find('ITCAM') != -1):
        		genArgList = genJvmArgs.split()
        		genJvmArgs = ''
        		for arg in genArgList:
        			if (arg.find('ITCAM') == -1 and arg.find('ITM/WASDC') == -1):
        				if (genJvmArgs != ''): genJvmArgs += ' '
        				genJvmArgs += arg
        	sysPropList = AdminConfig.showAttribute(jvmcfg, 'systemProperties').split('[')[1].split(']')[0].split()
        	sysProps = ''
        	if (len(sysPropList) > 0):
	        	for prop in sysPropList:
	        		if (sysProps != ''): sysProps += ','
	        		pName = AdminConfig.showAttribute(prop, 'name')
	        		pValue = AdminConfig.showAttribute(prop, 'value')
	        		#Only gather non-ITCAM properties
	        		if (pValue.find('datacollector') == -1 and pValue.find('itcamdc') == -1):
	        			sysProps += pName+'='+pValue
		else: sysProps = '<undef>'
		#No web container == no session/cookie stuff or thread pools
        	if (wcCfg != ''):
        		#Reset session variables
        		cookies = 'Cookies-OFF'
		    	sslTrack = 'SSLTrack-OFF'
		    	urlRewrt = 'UrlRW-OFF'
		    	prsRewrt = 'PrtSwRW-OFF'
		    	secInt = 'SecInt-OFF'
		    	#Pull threads, session manager and m2m data
	        	wcMaxTh = AdminConfig.showAttribute(wctcfg, 'maximumSize')
	        	wcMinTh = AdminConfig.showAttribute(wctcfg, 'minimumSize')
	        	cookieName = AdminConfig.showAttribute(sessMgr, 'defaultCookieSettings').split('(')[0]
	        	if (AdminConfig.showAttribute(sessMgr, 'enableCookies') == 'true'): cookies = 'Cookies-ON'
	        	if (AdminConfig.showAttribute(sessMgr, 'enableSSLTracking') == 'true'): sslTrack = 'SSLTrack-ON'
	        	if (AdminConfig.showAttribute(sessMgr, 'enableUrlRewriting') == 'true'): urlRewrt = 'UrlRW-ON'
	        	if (AdminConfig.showAttribute(sessMgr, 'enableProtocolSwitchRewriting') == 'true'): prsRewrt = 'PrtSwRW-ON'
	        	if (AdminConfig.showAttribute(sessMgr, 'enableSecurityIntegration') == 'true'): secInt = 'SecInt-ON'
	        	sessMode = AdminConfig.showAttribute(sessMgr, 'sessionPersistenceMode')
	        	sessWrite = AdminConfig.showAttribute(tuneCfg, 'writeContents')
	        	sessFreq = AdminConfig.showAttribute(tuneCfg, 'writeFrequency')
	        	sessInt = AdminConfig.showAttribute(tuneCfg, 'writeInterval')
	        	sessOver = AdminConfig.showAttribute(tuneCfg, 'allowOverflow')
	        	sessMax = AdminConfig.showAttribute(tuneCfg, 'maxInMemorySessionCount')
	        	if (drsCfg != ''):
	        		drsMode = AdminConfig.showAttribute(drsCfg, 'dataReplicationMode')
	        		drsDomain = str(AdminConfig.showAttribute(drsCfg, 'messageBrokerDomainName'))
	    		else:
	    			drsMode = '<n/a>'
	    			drsDomain = '<n/a>'
        	else:
    			wcMaxTh = '<n/a>'
	        	wcMinTh = '<n/a>'
        		cookieName = '<n/a>'
	        	cookies = '<n/a>'
	        	sslTrack = '<n/a>'
	        	urlRewrt = '<n/a>'
	        	prsRewrt = '<n/a>'
	        	secInt = '<n/a>'
	        	sessMode = '<n/a>'
        		sessWrite = '<n/a>'
	        	sessFreq = '<n/a>'
	        	sessInt = '<n/a>'
	        	sessOver = '<n/a>'
	        	sessMax = '<n/a>'
        	
        	#Pull webserver plugin settings
        	if (webPlg != ''):
	        	plgConTO = AdminConfig.showAttribute(webPlg, 'ConnectTimeout')
	        	plgMxCon = AdminConfig.showAttribute(webPlg, 'MaxConnections')
	        	plgSioTO = AdminConfig.showAttribute(webPlg, 'ServerIOTimeout')
	        	plgRole = AdminConfig.showAttribute(webPlg, 'Role')
        	else:
        		plgConTO = '<n/a>'
	        	plgMxCon = '<n/a>'
	        	plgSioTO = '<n/a>'
	        	plgRole = '<n/a>'
        	
        	#Print data
        	print 'JVM|'+sName+'|'+nName+'|'+clName+'|'+minHeap+'|'+maxHeap+'|'+wcMinTh+'|'+wcMaxTh \
        	 +'|'+classPath+'|'+genJvmArgs+'|'+sysProps+'|'+cookieName+'|'+cookies+'|'+sslTrack \
        	 +'|'+urlRewrt+'|'+prsRewrt+'|'+secInt+'|'+sessMode+'|'+drsMode+'|'+drsDomain \
        	 +'|'+sessWrite+'|'+sessFreq+'|'+sessInt+'|'+sessOver+'|'+sessMax \
        	 +'|'+plgConTO+'|'+plgMxCon+'|'+plgSioTO+'|'+plgRole
#end jvmData()

def libData():
	skipLibs = ['SKIPLib']
	for lib in AdminConfig.list('Library').splitlines():
		libScope = lib.split('|')[0].split('/')[-1]
		libName = AdminConfig.showAttribute(lib, 'name')
		libClass = AdminConfig.showAttribute(lib, 'classPath')
		libNative = AdminConfig.showAttribute(lib, 'nativePath')
		if (libNative == '' or libNative == '[]'): libNative = '<undef>'
		if (libClass == '' or libClass == '[]'): libClass = '<undef>'
		if libName in skipLibs: continue
		else: print 'LIB|'+libName+'|'+libScope+'|'+libClass+'|'+libNative

def mailData():
	skipMail = ['SKIPMail']
	for mail in AdminConfig.list('MailSession').splitlines():
		msScope = mail.split('|')[0].split('/')[-1]
		msName = AdminConfig.showAttribute(mail, 'name')
		msJNDI = AdminConfig.showAttribute(mail, 'jndiName')
		msTHost = AdminConfig.showAttribute(mail, 'mailTransportHost')
		msTProtId = AdminConfig.showAttribute(mail, 'mailTransportProtocol')
		msTProt = AdminConfig.showAttribute(msTProtId, 'protocol')
		if msName in skipMail: continue
		else: print 'MAIL|'+msName+'|'+msScope+'|'+msJNDI+'|'+msTHost+'|'+msTProt

#*******************************************************************************************************
# Commandline parameter handling
if (len(sys.argv) != 1):
	usage()
	sys.exit()
dataType = sys.argv[0]
#Setup options, and execute function based on argument passed (like a switch/case)
options = { 'jvm' : jvmData, \
	'jdbcprv' : jdbcProviderData, \
	'jdbcds' : jdbcDatasourceData, \
	'mqcf' : mqConnFactoryData, \
	'mqq' : mqQueueData, \
	'mail' : mailData, \
	'libs' : libData, \
	'env' : envData \
}
options[dataType]()
