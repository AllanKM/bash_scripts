#!/usr/bin/python
import sys, string
reload(sys)  # to enable `setdefaultencoding` again
sys.setdefaultencoding("UTF-8")
sys.getdefaultencoding()
HEADER = '\033[95m'
ENDC = '\033[0m'
YELLOW = '\033[93m'
CLUSTERS = {}
SERVERS = {}
URIMAPPING = {}
UTF=1
from xml.sax import handler, make_parser
class PluginHandler(handler.ContentHandler):             
    def __init__(self, outfile, **serverinfo):                   
        self.outfile = outfile
        self.count = 0
        self.currenttag = ''
    def startElement(self, name, attrs):                      
        self.count += 1
        self.currenttag = name
        if name=='ServerCluster':
            self.clustername = attrs['Name']
        if name=='Server' and len(attrs.keys())>1:
	    self.server = attrs['Name']
            CLUSTERS.setdefault(self.clustername, []).append(self.server)
        if name=='Transport' and attrs['Protocol']=='https':
            self.port = attrs['Port']
	    SERVERS.setdefault(self.server, {'port': self.port, 'cluster': self.clustername})
        if name=='Route':
            URIMAPPING.setdefault(attrs['ServerCluster'], []).append(attrs['UriGroup'])
    def endElement(self, name):                              
        pass
    def reset_vars(self):
        self.server_name = ''
        self.port_name = ''
        self.port = ''
        self.currenttag = ''
	self.app_list = []

def setup_parser(inFileName):
    outFile = sys.stdout
    handler = PluginHandler(outFile)
    parser = make_parser()
    parser.setContentHandler(handler)
    inFile = open(inFileName, 'r')
    parser.parse(inFile)                                   
    inFile.close()

def main():
    args = sys.argv[1:]
    if len(args) < 1:
        print 'usage: python %s infile.xml' % sys.argv[0]
        sys.exit(-1)
    setup_parser(args[0])

if __name__ == '__main__':
    main()
    if sys.argv[2]=='noutf':
      UTF=0
    print "%s%s%s" % (HEADER, sys.argv[1], ENDC)
    for c in URIMAPPING.keys():
      for jvm in CLUSTERS[c]:
        print "\t%s:%s" % (jvm, SERVERS[jvm]['port'])
        count = 1
        num = len(URIMAPPING[c])
        for u in URIMAPPING[c]:
          if count==num:
            if UTF==1:
              print "\t\t%s%s%s%s" % (YELLOW, u"\u2517", u, ENDC)  
            else:
              print "\t\t%s%s %s%s" % (YELLOW, ">", u, ENDC)  
	  else:
            if UTF==1:
              print "\t\t%s%s%s%s" % (YELLOW, u"\u2523", u, ENDC)  
            else:
              print "\t\t%s%s %s%s" % (YELLOW, ">", u, ENDC)  
          count+=1
