#*******************************************************************************************************
# splicerprop.py
#   Author: James Walton
#   Initial Date: 04 Sep 2010
#*******************************************************************************************************
import sys
global AdminConfig

def usage():
        print 'Usage: wsadmin -lang jython -f splicerprop.py <clustername> </path/to/splicer.prop.file>'

if (len(sys.argv) < 2):
	print 'Incorrect number of arguments passed.'
	usage()
        sys.exit()

clusterName = sys.argv[0]
splicerFile = sys.argv[1]

cluster = AdminConfig.getid('/ServerCluster:'+clusterName+'/')
memberList = AdminConfig.showAttribute(cluster, 'members').split('[')[1].split(']')[0].split()
propName = 'com.ibm.websphere.xs.sessionFilterProps'
attrs = []
attrs.append(['name',propName])
attrs.append(['value',splicerFile])
attrs.append(['description','WebSphere eXtreme Scale Splicer File'])

for member in memberList:
	mServ = AdminConfig.showAttribute(member,'memberName')
	mNode = AdminConfig.showAttribute(member,'nodeName')
	mASObj = AdminConfig.getid('/Node:'+mNode+'/Server:'+mServ+'/ApplicationServer:/')
	#Verify the property doesn't exist yet, if it does, modify instead of create
	asProps = AdminConfig.getid('/Node:'+mNode+'/Server:'+mServ+'/ApplicationServer:/Property:/').split()
	modProp = 0
	asProp = ''
	if (len(asProps) > 0):
		for prop in asProps:
			pName = AdminConfig.showAttribute(prop,'name')
			if (pName == propName):
				modProp = 1
				asProp = prop
				break
	if (modProp):
		print 'Modifying existing '+propName+' on '+mNode+'\\'+mServ+' to: '+splicerFile
		try: AdminConfig.modify(asProp, attrs)
		except:
			print '### Error: '+mNode+'\\'+mServ+' custom property modifcation failed!'
			print 'Error details:',sys.exc_info()
			sys.exit()
		else:
			print mNode+'\\'+mServ+' custom property ('+propName+') modified.'
			AdminConfig.save()
	else:
		print 'Creating '+propName+' on '+mNode+'\\'+mServ+' with value: '+splicerFile
		try: cpObj = AdminConfig.create('Property', mASObj, attrs)
		except:
			print '### Error: '+mNode+'\\'+mServ+' custom property creation failed!'
			print 'Error details:',sys.exc_info()
			sys.exit()
		else:
			print 'Custom property created: '+cpObj
			AdminConfig.save()
