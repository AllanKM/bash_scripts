#!/usr/bin/python
#
#<server>
#  <include optional="true" location="/usr/WebSphere/wlp/usr/servers/SolrServer/Solr.xml"/>
#  <application id="solr" name="solr" type="ear" location="solr.ear"/>
#  <featureManager>
#    <feature>ssl-1.0</feature>
#    <feature>servlet-3.0</feature>
#    <feature>jsp-2.2</feature>
#    <feature>jndi-1.0</feature>
#  </featureManager>
#  <httpSession cloneId="v10201_SolrServer"/>
#  <httpEndpoint id="defaultHttpEndpoint" host="*" httpPort="9082" httpsPort="9045">
#    <tcpOptions soReuseAddr="true"/>
#  </httpEndpoint>
import sys, string
from xml.sax import handler, make_parser
class ServerIndexHandler(handler.ContentHandler):             
    def __init__(self, outfile, **serverinfo):                   
        self.outfile = outfile
        self.server_name = serverinfo['server']
        self.node_name = serverinfo['node']
        if self.node_name.endswith('e1'): # legacy nodes had e1 at the end
            self.node_name = self.node_name[:-2] # strip out e1
        self.cell = serverinfo['cell']
        self.count = 0
        self.transport_count = 0
	self.app_list = []
        self.currenttag = ''
    def startElement(self, name, attrs):                      
        self.count += 1
        self.currenttag = name
        if name=='httpSession' and self.server_name=='':
            self.server_name = attrs['cloneId']
    #    if name=='application':
#	    self.app_list.append(attrs['name'])
        if name=='httpEndpoint':
            self.http = attrs['httpPort']
            self.https = attrs['httpsPort']
    def endElement(self, name):                              
        if name=='httpEndpoint':
            self.outfile.write('%s,%s,%s,%s,%s\n' % (self.cell, self.node_name, self.server_name, 'WC_defaulthost', self.http))
            self.outfile.write('%s,%s,%s,%s,%s\n' % (self.cell, self.node_name, self.server_name, 'WC_defaulthost_secure', self.https))
	if name=='server':
#	    for f in self.app_list:
#	      self.outfile.write('%s,%s,%s,%s,%s\n' % ('Application', self.cell, self.node_name, self.server_name, f))
            self.reset_vars()
    def reset_vars(self):
        self.server_name = ''
        self.port_name = ''
        self.port = ''
        self.currenttag = ''
	self.app_list = []

def test(inFileName, cell, node, server):
    outFile = sys.stdout
    handler = ServerIndexHandler(outFile, cell=cell, node=node, server=server)
    parser = make_parser()
    parser.setContentHandler(handler)
    inFile = open(inFileName, 'r')
    parser.parse(inFile)                                   
    inFile.close()

def main():
    args = sys.argv[1:]
    if len(args) > 3:
        print 'usage: python test.py infile.xml (servername)'
        sys.exit(-1)
    cell = 'WLP'
    node = args[2]
    server = ''
    try:
        server = "%s_%s" % (node, args[1])
    except:
        server = ''
    test(args[0], cell, node, server)

if __name__ == '__main__':
    main()
