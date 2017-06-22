#!/usr/bin/python
#
#
#         <fc:Partner entityRef="uuid179cfa66-0148-1211-8068-86016b9bfe7b" state="enabled">
#          <fc:EntityProperty name="com.tivoli.am.fim.sts.saml.2.0.ValidateKeyIdentifier">
#            <fim:Value>DefaultKeyStore_developer.apim.ibmcloud.com-validationkey</fim:Value>
#          </fc:EntityProperty>
import sys, string
SEARCH=''
CSV=0
from xml.sax import handler, make_parser
class ServerIndexHandler(handler.ContentHandler):             
    def __init__(self, outfile, **serverinfo):                   
        self.outfile = outfile
        self.count = 0
        self.currenttag = ''
        self.ENTITY_DICT = {}
        self.parent_tag = ''
        self.entity = ''
    def startElement(self, name, attrs):                      
#        print "Start : %s" % name
        self.count += 1
        self.currenttag = name
        if name=='fc:Partner':
	  self.state = attrs['state']
          self.entity = attrs['entityRef']
          self.ENTITY_DICT.setdefault(self.entity, {})
          self.parent_tag = name
        if name=='fc:Entity':
          self.entity = attrs['id']
          self.parent_tag = name
          self.ENTITY_DICT.setdefault(self.entity, {})
          self.ENTITY_DICT[self.entity].setdefault('partner_id', attrs['protocolId'])
        if name=='fc:EntityProperty' and attrs['name'] == "com.tivoli.am.fim.sts.saml.2.0.ValidateKeyIdentifier":
          self.parent_tag = 'SSL'
          self.key_type = 'validate'
        if name=='fc:EntityProperty' and attrs['name'].find("com.tivoli.am.fim.sts.saml.2.0.EncryptionKeyIdentifier") >= 0:
          self.parent_tag = 'SSL'
          self.key_type = 'encryption'
        if name=='fc:ProtocolEndpoint':
          self.endpoint = attrs['endpoint']
          self.ENTITY_DICT[self.entity].setdefault('endpoint', self.endpoint)

    def characters(self,content):
        if self.currenttag == 'fim:Value' and self.parent_tag == 'SSL':
          c = content.strip()
          if self.key_type == 'validate':
            self.ENTITY_DICT[self.entity].setdefault('validate_key', c) 
          elif self.key_type == 'encryption':
            self.ENTITY_DICT[self.entity].setdefault('encryption_key', c) 
        if self.currenttag == 'fc:DisplayName' and self.parent_tag == 'fc:Entity':
          c = content.strip()
          if len(c) > 0:
            self.display_name = c
        #    print self.entity
            self.ENTITY_DICT[self.entity].setdefault('display_name',  self.display_name)

    def endElement(self, name):                              
        pass

    def reset_vars(self):
        self.entity = ''

def handsome_print(partner_dict):
    for k in partner_dict.keys():
      if SEARCH=='':
        print '%sDisplay Name:%s	%s' % ('\033[95m', '\033[0m', partner_dict[k]['display_name'])
        for j in partner_dict[k].keys():
          if j != 'display_name':
            print '''	%s%s%s:	%s''' % ('\033[94m', j, '\033[0m', partner_dict[k][j])
        print
      else:
        disp= '%sDisplay Name:%s	%s' % ('\033[95m', '\033[0m', partner_dict[k]['display_name'])
        det=''
        for j in partner_dict[k].keys():
          if j != 'display_name':
            det+= '''	%s%s%s:	%s\n''' % ('\033[94m', j, '\033[0m', partner_dict[k][j])
        if disp.upper().find(SEARCH)>=0 or det.upper().find(SEARCH)>=0:
          print disp
          print det

def csv_print(partner_dict):
    csvlist = []
    # pick arbitrary partner to get column names
    rand = partner_dict.keys()[0]
    header = [col.upper() for col in partner_dict[rand].keys()]
    header.sort()
    csvlist.append(header)
    for k in partner_dict.keys():
      entity = partner_dict[k]
      templist = [ entity['display_name'] ]
      p_keys = entity.keys()
      p_keys.sort()
      for e in p_keys:
        if e != 'display_name':
          templist.append(entity[e])
      csvlist.append(templist) 
    # Header
    print "#%s" % (",".join( csvlist[0] ))
    for partner in csvlist[1:]:
      p_str = ",".join(partner)
      if p_str.upper().find(SEARCH)>=0:
        print p_str

def test(inFileName, out='handsome'):
    outFile = sys.stdout
    handler = ServerIndexHandler(outFile)
    parser = make_parser()
    parser.setContentHandler(handler)
    inFile = open(inFileName, 'r')
    parser.parse(inFile)                                   
    inFile.close()
    if CSV == 0:
      handsome_print(handler.ENTITY_DICT)
    else:
      csv_print(handler.ENTITY_DICT)

def main():
    global SEARCH
    global CSV
    args = sys.argv[1:]
    if " ".join(args).find('search=') >= 0:
      SEARCH = args[1].split('search=')[1].upper()
    else:
      SEARCH = ''
    if " ".join(args).find('csv') >= 0: 
      CSV = 1
    if len(args) > 4:
        print 'usage: python test.py infile.xml [search=filter] [csv]'
        sys.exit(-1)
    test(args[0])

if __name__ == '__main__':
    main()
