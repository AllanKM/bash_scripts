#!/usr/bin/python
import sys
f = open(sys.argv[1], 'r')
lines = f.readlines()
f.close()
tags = {'Cluster Name':'','Cluster Properties':'','Cluster Resource Demand':'','Cluster Utility':'','Cluster Members':'','Cluster Placements':'','Node Capacity and Demands':'','Cluster Resource Allocation':'','Failed Server Starts':'','Removed Nodes':'', 'Cluster Node Membership':''}

def convertToTimestamp(data):
  timestamp = line.strip()[1:].split(']')[0]
  thedate, thetime, thetz = timestamp.split(' ')
  newdate = massageDate(thedate)
  newtime = massageTime(thetime)
  return "%s %s %s" % (newdate, newtime, thetz)

def leadingZ(thing):
  if len(thing) == 1:
    return "0%s" % thing
  else:
    return thing

def massageDate(thedate):
  d, m, y = thedate.split('/')
  return "%s/%s/%s" % (leadingZ(d), leadingZ(m), y)

def massageTime(thetime):
  h, m, s, ms = thetime.split(':') 
  while (len(ms) < 3):
    ms = "0%s" % ms 
  return "%s:%s:%s:%s" % (leadingZ(h), leadingZ(m), leadingZ(s), ms)
  
current = ''
logstuff = []
curlabel = ''
for line in lines:
  if line.find('[')==0 and line.find('application placement controller')>0:
    timestamp = convertToTimestamp(line.strip()[1:].split(']')[0])
    current = timestamp
  elif current != '':
    cLine = line.strip()
    label = cLine.split(':')[0]
    if tags.has_key(label):
      curlabel = label
    if (len(timestamp) + len(curlabel) + len(cLine) == len(timestamp) + len(curlabel) + len(curlabel) + 1):
      pass
    elif cLine.find(curlabel)==0:
      print "%s##%s##%s" % (timestamp, cLine.split(':')[0], ''.join(cLine.split(':')[1:]))
    else:
      print "%s##%s##%s" % (timestamp, curlabel, cLine)
