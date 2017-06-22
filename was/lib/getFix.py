#!/usr/bin/python
import sys, string
from xml.sax import handler, make_parser
class ServerIndexHandler(handler.ContentHandler):             
    def __init__(self, outfile, **serverinfo):                   
        self.outfile = outfile
        self.fix_name = ''
	self.id = ''
	self.fix_version = ''
        self.node_name = serverinfo['node']
	self.role = serverinfo['role']
        self.dir = serverinfo['dir']
        if self.node_name.endswith('e1'): # legacy nodes had e1 at the end
            self.node_name = self.node_name[:-2] # strip out e1
        self.count = 0
        self.currenttag = ''
    def startElement(self, name, attrs):                      
        self.count += 1
        self.currenttag = name
    def characters(self,content):
        if self.currenttag == 'FixName':
          c = content.strip()
          if len(c) > 0:
	    self.fix_name = c
	elif self.currenttag == 'FixVersion':
	  c = content.strip()
	  if len(c) > 0:
	    self.fix_version = c
	elif self.currenttag == 'FixID':
	  c = content.strip()
	  if len(c) > 0:
	    self.id = c
    def endElement(self, name):                              
        if name=='Fix':
            self.outfile.write('%s,FIX,%s,%s,%s,%s,%s\n' % (self.node_name, self.fix_name, self.id, self.fix_version,self.dir,self.role))
            self.reset_vars()
    def reset_vars(self):
        self.fix_version = ''
        self.id = ''
        self.fix_name = ''
        self.dir = ''
        self.currenttag = ''

def test(inFileName, node, dir, role):
    outFile = sys.stdout
    handleryo = ServerIndexHandler(outFile, node=node, dir=dir, role=role)
    parser = make_parser()
    parser.setFeature(handler.feature_external_ges, False)
    parser.setContentHandler(handleryo)
    inFile = open(inFileName, 'r')
    parser.parse(inFile)                                   
    inFile.close()

def main():
    node = sys.argv[2]
    dir = sys.argv[3] 
    try:
      role = sys.argv[4]
    except:
      role = ''
    test(sys.argv[1], node, dir, role)

if __name__ == '__main__':
    main()
