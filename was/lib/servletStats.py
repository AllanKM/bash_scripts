#*******************************************************************************************************
# servletStats.py - based on migration from servletStats.jacl
#
#   Author: James Walton
#   Initial Revision Date: 07/23/2008
#*******************************************************************************************************
import sys
import re
def regsuball(pattern, string, replacement, flags=0):
        return re.compile(pattern, flags).sub(replacement, string)

def usage():
        print 'Usage:'
        print '   wsadmin -lang jython -f servletStats.py -server <appServerName> [-node <nodeName>] [-csv]'
        print 'Given an application server name <appServerName>, this script will display all'
        print 'servlets (with web module name) and their related statistics, such as response time.'
        print ''
        print '** Adding the -csv flag for operations noted will print the output in CSV (comma separated) format.'

#*******************************************************************************************************
# Commandline parameter handling
#*******************************************************************************************************
argerr = 0
printCSV = 0
if ( ('nodeName' in locals().keys() or 'nodeName' in globals().keys()) ):
        nodeName = ''

i = 0
while ( i < argc ):
        arg = sys.argv[i]
        if (arg == '-server'):
                i+=1
                if (i < argc): appServer = sys.argv[i]
                else: argerr = 1
        elif (arg == '-node'):
                i+=1 
                if (i < argc): nodeName = sys.argv[i]
                else: argerr = 2
        elif (arg == '-csv'): printCSV = 1
        else: argerr = 3
        i += 1

nodeExists = ('nodeName' in locals().keys() or 'nodeName' in globals().keys()) 
serverExists = ('appServer' in locals().keys() or 'appServer' in globals().keys())
if (not serverExists): argerr = 4

if (argerr):
        print 'Invalid command line invocation (reason code '+argerr+').'
	usage()
        sys.exit()

if (printCSV):
        print appServer
        print 'WebModule,Servlet,AvgResponse,TotalRequests,ConcurrentRequests,MaxConcurrentRequests,ErrCount'
else:
        print '====================================================================================================='
        print '                     :                      : Avg Response : Concurrent : Max Concurrent :'
        print 'Web Module           : Servlet name         : Time (ms)    :  Requests  :    Requests    : Err Count'
        print '====================================================================================================='

if (nodeExists): servletList = AdminControl.queryNames('node='+nodeName+',process='+appServer+',type=Servlet,*').split()
else: servletList = AdminControl.queryNames('process='+appServer+',type=Servlet,*').splitlines()

for servlet in servletList:
        srvFullName = AdminControl.getAttribute(servlet, 'name')
        wmName = srvFullName.split('#')[1]
        srvName = srvFullName.split('#')[2]
        srvStats = AdminControl.getAttribute(servlet, 'stats').split('{')[1].split('}')[0]
        srvStats = regsuball('\n\n', srvStats, ',')
	srvStats = regsuball('\n', srvStats, '')
	theStats = regsuball(', ', srvStats, ',').split(',')
        ## Servlet response time average
        iAvg = theStats.index('type=AverageStatistic') + 1
        srvAvg = theStats[iAvg]
        ## Servlet total requests
        iCnt = theStats.index('name=ConcurrentRequests') - 1
        srvReq = theStats[iCnt]
        ## Servlet error count
        iErr =len(theStats) - 1
        srvErr = theStats[iErr]
        ## Servlet concurrent request max
        srvCRMax = theStats[iCnt+7]
        ## Servlet concurrent request current
        srvCRCur = theStats[iCnt+8]

        if (printCSV): print wmName+','+srvName+','+srvAvg+','+srvCRCur+','+srvCRMax+','+srvErr
        else: print wmName+'  :  '+srvName+'  :  '+srvAvg+'  :  '+srvCRCur+'  :  '+srvCRMax+'  :  '+srvErr
