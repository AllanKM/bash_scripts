#!/bin/bash
function usage {
  echo "Description: Grabs the list of runtime tasks from a VE dmgr."
  echo "Required arguments:"
  echo "	arg1 - resolvable name of dmgr port - e.g. g2pre70wiveManager"
  echo "	arg2 - dmgr port [optional - default is 9043]"
  echo 
  echo "Usage:"
  echo "      $0 <cell>Manager [port]"
  echo 
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi
dmgr=$1
port=${2:-9043}
WAS_TOOLS=/lfs/system/tools/was
WAS_PASSWD=${WAS_TOOLS}/etc/was_passwd
WSADMIN=${WAS_HOME}/bin/wsadmin.sh
WASLIB=${WAS_TOOLS}/lib       
encrypted_passwd=$(grep global_security $WAS_PASSWD |awk '{split($0,pwd,"global_security="); print pwd[2]}' |sed -e 's/\\//g')
passwd_string=`$WAS_TOOLS/bin/PasswordDecoder.sh $encrypted_passwd`
gsPass=$(echo $passwd_string | awk '{split($0,pwd," == "); print pwd[3]}' | sed -e "s/\"//g")

if [ -z $gsPass ]; then
  echo $passwd_string
  echo "Please run the script from a WAS node"
  exit 1
fi

# Embedded python code for logging in and scraping automation
# Depends on BeautifulSoup.py library for html processing
cat <<EOF | python - ${dmgr} ${gsPass} ${port}
import sys,os
custom_python_lib_path = '/lfs/system/tools/was/lib'
sys.path.insert(0,custom_python_lib_path)
from BeautifulSoup import BeautifulSoup
import re
import urllib,urllib2,cookielib

dmgr = sys.argv[1]
pwd = sys.argv[2].replace('@', '%40')
port = sys.argv[3]
cj = cookielib.CookieJar()
BASE = 'https://%s:%s' % (dmgr,port)
LOGIN_URL = '%s/ibm/console/j_security_check' % (BASE)
LOGOUT_URL = '%s/ibm/console/logout.do' % (BASE)
RTASKS_URL = '%s/ibm/console/navigatorCmd.do?forwardName=taskmanagement.content.main&WSC=true' % (BASE)
USERNAME = 'eiauth%40events.ihost.com'
PASSWORD = pwd
LOGIN_FORM = 'j_username=%s&j_password=%s' % (USERNAME,PASSWORD)
opener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cj))
opener.open(LOGIN_URL, LOGIN_FORM)
myresp = opener.open(RTASKS_URL)
data = myresp.read()
tasklist = []

def get_task_urls(data):
  taskssoup = BeautifulSoup(data)
  rows = taskssoup.findAll('tr', { "class" : "table-row" })
  if len(rows) == 1 and rows[0].td.next == "None":
    return []
  else:
    return [row.findAll('td')[2].find('a')['href'] for row in rows]

def get_task_details(html):
  tasksoup = BeautifulSoup(html)
  desc = tasksoup.find('p',{'id':'reasonMsg'}).next.strip()
  # Not all runtime tasks have Action plans
  try:
    #action = tasksoup.find('table', {'id':'actionplan'}).td.next.replace('&nbsp;','').strip()
    action = [] 
    actions = tasksoup.find('table', {'id':'actionplan'})
    for a in actions.findAll('td'):
      act = re.sub("\s+", ' ', a.next.replace('&nbsp;','').strip())
      action.append(act)
  except:
    action = ["No action plan associated with this runtime task"]
  state = tasksoup.find('p',{'id':'currentState'}).next.replace('&nbsp;','').strip()
  origTime = tasksoup.find('p',{'id':'formattedTime'}).next.replace('&nbsp;',' ').strip()
  taskId = tasksoup.find('p',{'id':'taskId'}).next.replace('&nbsp;',' ').strip()
  try:
    finalStatus = tasksoup.find('p',{'id':'finalStatus'}).next.replace('&nbsp;',' ').strip()
  except:
    finalStatus = ''
  print "Task: %s" % (taskId)
  print "Originated Time: %s\n" % (origTime)
  print "State\n\t%s\n" % state
  print "Final Status\n\t%s\n" % finalStatus
  print "Action Plan\n\t%s\n" % "\n\t".join(action)
  print "Description\n\t%s\n" % desc.replace('&quot;','"')

tasklist = get_task_urls(data)
if len(tasklist) == 0:
  print "There are no runtime tasks, or you are logged in already.  Please login via browser to verify."
else:
  for task in tasklist:
    myresp = opener.open(BASE + "/ibm/console/" + task)
    data = myresp.read()
    get_task_details(data)
opener.open(LOGOUT_URL)
EOF
