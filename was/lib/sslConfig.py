#*******************************************************************************************************
# sslConfig.py -- based on migration from editSSLConfig.jacl
#
#   Author: James Walton
#   Initial Revision Date: 02/28/2006
#
#*******************************************************************************************************
#
#   Change History: 
#     Lou Amodeo    03-01-2013  Add support for Websphere 8.5 
#
#*******************************************************************************************************
#*******************************************************************************************************
import sys
def usage():
	print 'Usage:'
        print '   wsadmin -lang jython -f sslConfig.py -node <nodeName> -keystore <keystoreName> -keypassword <keystorePass> [-version <61|70|85>]\n'
        print 'This script will update the DefaultSSLSettings for the given node to use the given'
        print 'keystore and password.  Note: currently does not support using a different file for truststore.'
        print 'There is no need to provide a full path to the keystore, provided it is in $WAS_ROOT/etc/'
        print 'Providing a version is optional.'

#*******************************************************************************************************
# Commandline parameter handling
#*******************************************************************************************************
argerr = 0
i = 0
argc=len(sys.argv)
while ( i < argc ):
        arg = sys.argv[i]
        if (arg == '-node'):
                i += 1
                if (i < argc): nodeName = sys.argv[i]
                else: argerr = 2
        elif (arg == '-keystore'):
                i += 1
                if (i < argc): keystoreName = sys.argv[i]
                else: argerr = 3
        elif (arg == '-keypassword'):
                i += 1
                if (i < argc): keystorePass = sys.argv[i]
                else: argerr = 4
        elif (arg == '-version'):
                i += 1
                if (i < argc): version = sys.argv[i]
                else: argerr = 5
        else: argerr = 6
        i += 1

nodeExists = (('nodeName' in locals().keys() or 'nodeName' in globals().keys()) and not nodeName == '')
keystoreExists = ('keystoreName' in locals().keys() or 'keystoreName' in globals().keys()) 
passwordExists = ('keystorePass' in locals().keys() or 'keystorePass' in globals().keys()) 
versionExists = ('version' in locals().keys() or 'version' in globals().keys())
#*******************************************************************************************************
# Verify valid parameters were passed
#*******************************************************************************************************
if (not nodeExists and not keystoreExists and not passwordExists): argerr = 7
if (not versionExists): version = '70'

if (argerr):
        print '### Invalid command line invocation (reason code '+str(argerr)+'). Usage:'
	usage()
        sys.exit()

#*******************************************************************************************************
# Decipher and Perform Requested Action
#*******************************************************************************************************
if (nodeName.find('Manager') >= 0):
   # Changing the cell keystore/truststore since we're on the dmgr node
   cellDefaultKS = AdminConfig.getid('/KeyStore:CellDefaultKeyStore/')
   cellDefaultTS = AdminConfig.getid('/KeyStore:CellDefaultTrustStore/')
   attrs = [['location', '${USER_INSTALL_ROOT}/etc/'+keystoreName], ['type', 'JKS'], ['readOnly', 'true'], ['password', keystorePass]]
   try: AdminConfig.modify(cellDefaultKS, attrs)
   except:
          print '### Error occurred while modifying Cell Default Keystore configuration - exiting without save.'
          print sys.exc_info()
          sys.exit()
   try: AdminConfig.modify(cellDefaultTS, attrs )
   except:
          print '### Error occurred while modifying Cell Default Truststore configuration - exiting without save.'
          print sys.exc_info()
          sys.exit()
else:
     # Changing a node's keystore/truststore
     nodeDefaultKS = AdminConfig.getid('/KeyStore:NodeDefaultKeyStore/').splitlines()
     if (len(nodeDefaultKS) > 1):
     	# More than one node found, search through keystores for scope that matches given node
        for ks in nodeDefaultKS:
            ksScope = AdminConfig.showAttribute(AdminConfig.showAttribute(ks, 'managementScope'), 'scopeName')
            ksNode = ksScope.split(':')[3]
            if (ksNode == nodeName):
                 nodeDefaultKS = ks
                 break 
     else: nodeDefaultKS = nodeDefaultKS[0]
     nodeDefaultTS = AdminConfig.getid('/KeyStore:NodeDefaultTrustStore/').splitlines()
     if (len(nodeDefaultTS) > 1):
       	#More than one node found, search through truststores for scope that matches given node
        for ts in nodeDefaultTS:
            tsScope = AdminConfig.showAttribute(AdminConfig.showAttribute(ts, 'managementScope'), 'scopeName')
            tsNode = tsScope.split(':')[3]
            if (tsNode == nodeName):
                nodeDefaultTS = ts
                break
     else: nodeDefaultTS = nodeDefaultTS[0]
     # Setup the attributes for the modify commands
     attrs = [['location', '${USER_INSTALL_ROOT}/etc/'+keystoreName], ['type', 'JKS'], ['readOnly', 'true'], ['password', keystorePass]]
     try: AdminConfig.modify(nodeDefaultKS, attrs)
     except:
            print '### Error occurred while modifying Node Default Keystore configuration - exiting without save.'
            print sys.exc_info()
            sys.exit()
     try: AdminConfig.modify(nodeDefaultTS, attrs)
     except:
            print '### Error occurred while modifying Node Default Truststore configuration - exiting without save.'
            print sys.exc_info()
            sys.exit()

print 'Success! Saving configuration...'
AdminConfig.save()
