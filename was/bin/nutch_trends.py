#!/usr/bin/python
import sys,time
from datetime import date, timedelta
def usage():
  print "sudo %s <event> <days ago - 0 for today>" % (sys.argv[0])
#  print "sudo %s <event> <version 0.9|1.0> <days ago - 0 for today>" % (sys.argv[0])
  sys.exit(0)
try:
  when = int(sys.argv[2])
#  ver = sys.argv[2]
  event = sys.argv[1]
except:
  usage()
if when==0:
  d=''
  sep=''
else:
  dateobj=date.today()-timedelta(days=when)
  datestring=str(dateobj)
  d="".join(datestring.split('-'))
  sep='.'
nutch_log = "/logs/nutch/%s.log%s%s" % (event,sep,d)
f = file(nutch_log, 'r')
start = 0
docs = 0
#for line in sys.stdin.readlines():
for line in f.readlines():
# Document fetch counter
  if line.find('fetching') >= 0:
    if start != 0:
      docs = docs + 1
  if line.find('merging indexes') >= 0:
    if start != 0:
      hour = time.strptime(line.split(',')[0],"%Y-%m-%d %H:%M:%S")
      end_time = time.mktime(hour)
      print "Job: %s Duration: %.2f minutes Documents: %d" % (job_start, (end_time - start_time) / 60, docs )
      start = 0
      docs = 0
# Start of job
  if line.find('Injector: starting') >= 0:
# Another start was found before and end occurred
    if start == 1:
      print "Job: %s Duration:           DNF Documents: %d " % (job_start, docs)
      hour = time.strptime(line.split(',')[0],"%Y-%m-%d %H:%M:%S")
      start_time = time.mktime(hour)
      job_start = line.split(' ')[1]
      docs = 0
    else:
      hour = time.strptime(line.split(',')[0],"%Y-%m-%d %H:%M:%S")
      job_start = line.split(' ')[1]
      start_time = time.mktime(hour)
      start = 1
# Reached of log file
if start != 0:
  print "Job: %s Duration:           DNF Documents: %d " % (job_start, docs)
f.close()

