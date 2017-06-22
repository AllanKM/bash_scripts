#!/usr/bin/python
import sys
from xml.sax import handler, make_parser
TAGLIST = {'numDocs':'', 'size': '', 'lastModified':'', 'dataDir':''}
NODE = sys.argv[2]
try:
  EVENT = sys.argv[3]
except:
  EVENT = 'all'

class ServerIndexHandler(handler.ContentHandler):             
    def __init__(self, outfile, node):                   
        self.outfile = outfile
        self.count = 0
        self.currenttag = ''
	self.event = ''
	self.csvstr = ''
	self.eventstart = 0
        self.currentname = ''
        self.node = node
    def startElement(self, name, attrs):                      
        self.currenttag = name
	try:	
	  curname = attrs['name']
          if curname.find('instanceDir') == 0: # Start tag dump where the name='cmxxxx'
             self.event = curname
	     self.eventstart = 1
             self.currentname = curname
	  else:
             self.currentname = curname
	     self.csvstr = "%s" % (self.currentname)
	except:
	  pass
    def characters(self,content):
        if self.currentname == 'instanceDir':
          self.eventname = content.split('/')[-2].split('/')[-1]
        if self.eventstart and content.strip() != '' and TAGLIST.has_key(self.currentname):
          if self.node == '':
            if EVENT == 'all':
	      print "%s,%s" % (self.csvstr,content)
            elif self.eventname == EVENT:
	      print "%s,%s" % (self.csvstr,content)
          else:
            if EVENT == 'all':
              print "%s,%s,%s,%s" % (self.node, self.eventname, self.csvstr, content)
            elif self.eventname == EVENT:
              print "%s,%s,%s,%s" % (self.node, self.eventname, self.csvstr, content)
    def endElement(self, name):                              
        self.csvstr = ''

def doIt(inFileName, node):
    outFile = sys.stdout
    handleryo = ServerIndexHandler(outFile, node)
    parser = make_parser()
    parser.setFeature(handler.feature_external_ges, False)
    parser.setContentHandler(handleryo)
    # If piping output to this script
    if inFileName == '-':
      try:
        inFile = sys.stdin
        parser.parse(inFile)                                   
        inFile.close()
      except:
        print "%s,No XML output from solr (Possibly down)" % node
    # else use filename
    else:
      inFile = open(inFileName, 'r')
      parser.parse(inFile)                                   
      inFile.close()

def main():
    doIt(sys.argv[1], NODE)

if __name__ == '__main__':
    main()
