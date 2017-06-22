#*******************************************************************************************************
# itcam-check.py
#   Author: 	James Walton
#   Build Date:	02/26/2014
#   Usage: 	wsadmin.sh -conntype NONE -f /path/to/itcam-check.py
#*******************************************************************************************************
agentStr = 'agentlib:am_ibm'
jvmList = AdminConfig.list('JavaVirtualMachine').split()
for jvm in jvmList:
	jvmname = jvm.split('/')[5].split('|')[0]
	if (jvmname != 'nodeagent' and jvmname != 'dmgr'):
		argList = AdminConfig.showAttribute(jvm, 'genericJvmArguments')
		if(AdminConfig.showAttribute(jvm, 'genericJvmArguments').find(agentStr) >= 0):
			print '%-30s\tCONFIGURED' % jvmname
		else:
			print '%-30s\tNO AGENT' % jvmname