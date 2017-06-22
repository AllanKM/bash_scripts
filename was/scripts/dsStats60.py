##############################################################################
# 
# dsStats60.py
#
# Description: Dumps pool contents for datasources 
# Updated version of dsStats.pyfor WAS 6.0 since regex not allowed
# 
# Usage: 
# ./wsadmin.sh -lang jython -f dsStats.py
#
# Author: Marvin Gjoni (mgjoni@us.ibm.com)
#
# Date: 2008/10/08
#
#############################################################################
import sys
server = 'spe'
dslist = AdminControl.queryNames('type=DataSource,*').split('\n')
for ds in dslist:
                servername = ds.split(':')[1].split(',')[1].split('=')[1]
                if (servername.find(server)>=0):
                        dsname=ds.split(':')[1].split('=')[1].split(',')[0]
                        print "=================================================================================================================="
                        print dsname + " " + servername
                        print "=================================================================================================================="
                        dsobj=AdminControl.completeObjectName('type=DataSource,name='+dsname+',process='+servername+',*')
                        print AdminControl.invoke(dsobj,'showPoolContents')