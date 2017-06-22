#!/usr/bin/python
import sys,time
from datetime import date, timedelta
def usage():
	print "sudo %s <event> <days ago - 0 for today>" % (sys.argv[0])
	sys.exit(0)

try:
	when = int(sys.argv[2])
	event = sys.argv[1]
except:	usage()

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
start,solrstart,fetchDocs,solrDocs = 0,0,0,0
for line in f.readlines():
	# Start of Nutch crawl
	if line.find('Injector: starting') >= 0:
		# Another start was found before and end occurred
		if start == 1:
			print "Job(Nutch): %s Duration:          DNF Documents: %d " % (job_start, fetchDocs)
			hour = time.strptime(line.split(',')[0],"%Y-%m-%d %H:%M:%S")
			start_time = time.mktime(hour)
			job_start = line.split(' ')[1]
			fetchDocs = 0
		else:
			hour = time.strptime(line.split(',')[0],"%Y-%m-%d %H:%M:%S")
			job_start = line.split(' ')[1]
			start_time = time.mktime(hour)
			start = 1
	# Nutch document fetch counter
	if line.find('fetching') >= 0:
		if start != 0: fetchDocs = fetchDocs + 1
	# End of Nutch crawl
	if line.find('LinkDb: finished') >= 0:
		if start != 0:
			hour = time.strptime(line.split(',')[0],"%Y-%m-%d %H:%M:%S")
			end_time = time.mktime(hour)
      			print "Job(Nutch): %s Duration: %.2f minutes  Documents Fetched: %d" % (job_start, (end_time - start_time) / 60, fetchDocs )
      			fetchDocs = 0
	# Solr indexing start
	if line.find('SolrIndexer: starting') >= 0:
		# There will be more than one indexer started, we will ignore all but the first for now
		if (start != 0 and solrstart == 0):
			hour = time.strptime(line.split(',')[0],"%Y-%m-%d %H:%M:%S")
			solr_job_start = line.split(' ')[1]
			solrstart = 1
	# Solr Document total
	if line.find('solr.SolrWriter - Indexing') >= 0:
		if (start != 0 and solrstart == 1): solrDocs = line.split(' ')[7]
	# Solr indexing complete
	if line.find('SolrIndexer: finished') >= 0:
		if (start != 0 and solrstart != 0):
			elapsed = line.split(' ')[12].rstrip('\n')
      			print "Job(Solr) : %s Duration: %s      Documents Indexed: %s" % (solr_job_start, elapsed, solrDocs )
      			start,solrstart,solrDocs = 0,0,0
      			# There will be more than one indexer finishing, ignore all but the first for now
      			# Most indexer jobs will finish within a few seconds of each other
	
# Reached of log file
if start != 0: print "Job(Nutch): %s Duration:          DNF Documents: %d " % (job_start, fetchDocs)
f.close()
