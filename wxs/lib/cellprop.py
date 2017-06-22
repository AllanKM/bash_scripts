#*******************************************************************************************************
# cellprop.py
#   Author: James Walton <jfwalton@us.ibm.com>
#   Date: 04 Sep 2010
#*******************************************************************************************************
import sys

def usage():
        print 'Usage: wsadmin -lang jython -f cellprop.py <propname> <propvalue> [-remove] [-save]'

if (len(sys.argv) < 2):
	print 'Incorrect number of arguments passed.'
	usage()
        sys.exit()

def remove(splicename):
	cell = AdminConfig.list('Cell')
	props = AdminConfig.show(cell, ['properties'])
	propsliststr = props[1:-1].split('properties ')[1][1:-1].split(' ')
	xslist = [ xs for xs in propsliststr if xs.find('sessionFilterProps')>0]
	for x in xslist:
		xsname = AdminConfig.show(x, ['name'])
		if xsname.find("%s,com.ibm.websphere.xs.sessionFilterProps" % splicename) >= 0:
			print "Found: %s" % x
			AdminConfig.remove(x)
			print "If I remove it, this is what the cell props will look like:\n"
			print AdminConfig.show(cell, ['properties'])
			print "\n"
			if save == 'yes':
				print "Save option set. Saving..."
				AdminConfig.save()
			sys.exit()
	print "%s not found in the list of cell properties, exiting." % splicename
	sys.exit()

propName = sys.argv[0]
propValue = sys.argv[1]
save = 'no'

cellObj = AdminConfig.getid('/Cell:/')
attrs = []
attrs.append(['name',propName])
attrs.append(['value',propValue])
if (len(sys.argv) > 2) and sys.argv[2] != '-remove':
	attrs.append(['description',sys.argv[2]])

if " ".join(sys.argv).find('-remove') > 0:
	if " ".join(sys.argv).find('-save') > 0:
		save = 'yes'
	remove(propName)

#Verify the property doesn't exist yet, if it does, modify instead of create
cellProps = AdminConfig.getid('/Cell:/Property:/').split()
modProp = 0
cellProp = ''
if (len(cellProps) > 0):
	for prop in cellProps:
		pName = AdminConfig.showAttribute(prop,'name')
		if (pName == propName):
			modProp = 1
			cellProp = prop
			break

if (modProp):
	print 'Modifying existing '+propName+' ...'
	try: AdminConfig.modify(cellProp, attrs)
	except:
		print '### Error: Cell custom property modifcation failed!'
		print 'Error details:',sys.exc_info()
		sys.exit()
	else:
		print 'Cell custom property modified.'
		AdminConfig.save()
else:
	try: cpObj = AdminConfig.create('Property', cellObj, attrs)
	except:
		print '### Error: Cell custom property creation failed!'
		print 'Error details:',sys.exc_info()
		sys.exit()
	else:
		print 'Cell custom property created: '+cpObj
		AdminConfig.save()
