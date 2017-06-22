#!/usr/bin/python
import sys, string
from xml.sax import handler, make_parser
class ServerIndexHandler(handler.ContentHandler):             
    def __init__(self, outfile, **serverinfo):                   
        self.outfile = outfile
        self.product_name = ''
	self.id = ''
	self.version = ''
        self.node_name = serverinfo['node']
        self.dir = serverinfo['dir']
        self.role = serverinfo['role']
        if self.node_name.endswith('e1'): # legacy nodes had e1 at the end
            self.node_name = self.node_name[:-2] # strip out e1
        self.count = 0
        self.currenttag = ''
    def startElement(self, name, attrs):                      
        self.count += 1
        self.currenttag = name
        if name=='product':
            self.product_name = attrs['name']
    def characters(self,content):
        if self.currenttag == 'id':
          c = content.strip()
          if len(c) > 0:
	    self.id = c
	elif self.currenttag == 'version':
	  c = content.strip()
	  if len(c) > 0:
	    self.version = c
    def endElement(self, name):                              
        if name=='product':
            self.outfile.write('%s,PRODUCT,%s,%s,%s,%s,%s\n' % (self.node_name, self.product_name, self.id, self.version,self.dir,self.role))
            self.reset_vars()
    def reset_vars(self):
        self.version = ''
        self.id = ''
        self.product_name = ''
        self.dir = ''
        self.currenttag = ''

def test(inFileName, node, dir,role):
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
    test(sys.argv[1], node, dir,role)

if __name__ == '__main__':
    main()
