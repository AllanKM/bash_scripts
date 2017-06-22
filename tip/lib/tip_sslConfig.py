#*******************************************************************************************************
# tip_sslConfig.py  
#
#
#*******************************************************************************************************
#
#   Change History: 
#     Lou Amodeo    03-01-2013  Add support for Websphere 8.5 
#     E Coley       04-18-2013  Create TIP version to be used when more control is needed.
#                               Such as for updating the LMT stores to use EI-supplied stores
#                                                              
#*******************************************************************************************************
#*******************************************************************************************************
import sys
import traceback
def usage():
	print 'Usage:'
        print '   wsadmin -lang jython -f sslConfig.py -node <nodeName>  '
        print '           -ks <ks_name> -ts <ts_name> -keystore <keystoreFilename> -keypassword <keystorePass> '
        print '          [-version <61|70|85>] -debug\n'
        print 'This script will update the specified key and trust store for the given node to use the given'
        print 'keystore and password.  Note: currently does not support using a different file for truststore.'
        print 'There is no need to provide a full path to the keystore, provided it is in $WAS_ROOT/etc/'
        print 'Providing a version is optional and is not used.'

debug = 0
#*******************************************************************************************************
# Commandline parameter handling
# The keystoreName is the name of the file,and is used for both keystore and truststore. 
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
        elif (arg == '-ks'):
                i += 1
                if (i < argc): ksName = sys.argv[i]         # WAS keystore name
                else: argerr = 3
        elif (arg == '-ts'):
                i += 1
                # keystoreName is the filename
                if (i < argc): tsName = sys.argv[i]         # WAS truststore name
                else: argerr = 4
        elif (arg == '-keystore'):
                i += 1
                # keystoreName is the filename
                if (i < argc): keystoreName = sys.argv[i]   #  store file name
                else: argerr = 5
        elif (arg == '-keypassword'):                       #  keystore password
                i += 1
                if (i < argc): keystorePass = sys.argv[i]
                else: argerr = 6
        elif (arg == '-version'):                           # version
                i += 1
                if (i < argc): version = sys.argv[i]
                else: argerr = 7
        elif (arg == '-debug'):                             # debug flag
                debug = 1
        else: argerr = 8
        i += 1

nodeExists     = (('nodeName'    in locals().keys() or 'nodeName'     in globals().keys()) and not nodeName == '')
keystoreExists = ('keystoreName' in locals().keys() or 'keystoreName' in globals().keys()) 
passwordExists = ('keystorePass' in locals().keys() or 'keystorePass' in globals().keys()) 
versionExists  = ('version'      in locals().keys() or 'version'      in globals().keys())
ksExists       = ('ksName'       in locals().keys() or 'ksName'       in globals().keys())   
tsExists       = ('tsName'       in locals().keys() or 'tsName'       in globals().keys())   

#*******************************************************************************************************
# Verify valid parameters were passed
#*******************************************************************************************************
if (not nodeExists and not keystoreExists and not passwordExists): argerr = 9
if (not ksExists):argerr = 10  
if (not tsExists):argerr = 11   
if (not versionExists): version = '70'

if (argerr):
        print '### Invalid command line invocation (reason code '+str(argerr)+'). Usage:'
        usage()
        sys.exit()

if ( debug ): print 'tsName: %s   ksName: %s' % (tsName, ksName)  
#*******************************************************************************************************
# Decipher and Perform Requested Action
#*******************************************************************************************************
if (nodeName.find('Manager') >= 0):   
   print 'Deployment manager detected - no TIP config work to do.'
else:
     # Changing a node's keystore/truststore
     # keystore
     KS = AdminConfig.getid('/KeyStore:%s/' %ksName).splitlines()
     if ( debug ): print 'AdminConfig.getid(KeyStore) %s ' % str(KS) 
     if (len(KS) > 1):
     	# More than one node found, search through keystores for scope that matches given node
        for ks in KS:
            ksScope = AdminConfig.showAttribute(AdminConfig.showAttribute(ks, 'managementScope'), 'scopeName')
            ksNode = ksScope.split(':')[3]
            if (ksNode == nodeName):
                 KS = ks
                 break 
     else: KS = KS[0]
     if ( debug ): print 'KS: %s ' % str(KS)  
      
     TS = AdminConfig.getid('/KeyStore:%s/' %tsName).splitlines()
     if ( debug ): print 'AdminConfig.getid(KeyStore ts) %s ' % str(TS) 
     # Trust store 
     if (len(TS) > 1):
       	#More than one node found, search through truststores for scope that matches given node
        for ts in TS:
            tsScope = AdminConfig.showAttribute(AdminConfig.showAttribute(ts, 'managementScope'), 'scopeName')
            tsNode = tsScope.split(':')[3]
            if (tsNode == nodeName):
                TS = ts
                break
     else: TS = TS[0]
     if ( debug ): print 'TS: %s ' % str(TS)  
     
     # Setup the attributes for the modify commands
     attrs = [['location', '${USER_INSTALL_ROOT}/etc/'+keystoreName], ['type', 'JKS'], ['readOnly', 'true'], ['password', keystorePass]]
     if ( debug ): print 'KS modify attrs: %s ' % attrs   
     try: AdminConfig.modify(KS, attrs)
     except:
            print '### Error occurred while modifying Node Default Keystore configuration - exiting without save.'
            #print sys.exc_info()
            _type, _val, _tb = sys.exc_info()
            traceback.print_exception(_type,_val,_tb)
            sys.exit()
     if ( debug ): print 'TS modify attrs: %s ' % attrs          
     try: AdminConfig.modify(TS, attrs)
     except:
            print '### Error occurred while modifying Node Default Truststore configuration - exiting without save.'
            #print sys.exc_info()
            _type, _val, _tb = sys.exc_info()
            traceback.print_exception(_type,_val,_tb)
            sys.exit()

print 'Success! Now Saving configuration...'
AdminConfig.save()
print 'Configuration...saved'

