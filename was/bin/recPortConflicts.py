#!/usr/bin/python
"""
Usage: recPortConflicts.py file1[,file2,file3,fileN] [transfile]

    Description: 
        Script pulls in specified dump files generated from getPorts.py to find port conflicts for 
        app servers running on same node

    file1[,file2,file3,fileN]: 
        The files specified are obtained from running getPorts.py against a WebSphere install. You can
        specify one or more dump file but multiple files must be separated by a comma.  Each dump needs
        come from a separate WebSphere install running on the same server(s).  

    transfile [optional]:
        The translation file specifies nodes whose name's differ but exist on the same server.
        This is meant to overcome scenario's where WAS 6+ node naming standards have changed from
        from the WAS 5.1 standards.  For example, node dt1103a in a WAS 6 config = dt1103ae1 in a
        WAS 5.1 config. Currently getPorts.py removes 'e1' from any WAS 5.1 node name so this option
        only needs to be used for cases outside this scenario.  
    
        Transfile Requirements:
            - each line needs to be a "=" delimited list of equal nodenames
                example line: dt1103a=dt1103ae1=w10002 
            - no single nodename can exist on more than one line in the transfile: all equal nodes
              need to be defined on the same line
"""
# Author: Thad Hinz
# Date:   06/06/2008
#
# Potential Future enhancements:
#   - want to be able to specify app server name pattern to filter output (use 'grep -p' for now)
#   - want to be able to specify a port and node to see if it is avail for use
#   - cleanup the code and functionize where possible (this is my 2nd python script)
#   - maybe beautify the output 
#   - use getopt for commandline args

# getPorts.py output file key = <cell[0]>:<node[1]>:<appserv[2]>:<portname[3]>:<portnumb[4]>

import sys
import os

def usage():
    print __doc__

def uniq(list):
    uniq_items = dict.fromkeys(list).keys()
    uniq_items.sort()
    return uniq_items

if len(sys.argv) < 2:  
    usage()
    sys.exit('\nERROR: Must provide filename(s) to slurp in.')

# functionize this trans stuff later
# if transfile is specified, create a dict from names in file, 
# then compare nodenames from slurp lines to key and convert name if matches
istransfile = 0
if len(sys.argv) == 3: 
    transfile = sys.argv[2]
    trans_dict = {}
    if not os.path.isfile(transfile):
        sys.exit('\nERROR: Specified translation file does not exist. Exiting\n')
    else:
        istransfile = 1
    tf = open(transfile)
    for line in tf:
        strip_line = line.rstrip('\n')
        line_list = strip_line.split('=')
        # skip lines that aren't valid, need at least 2 nodes to translate
        if len(line_list) < 2:
            #print "Line " + str(linecnt) + " is not a valid line. Skipping..."
            continue
        for nodename in line_list:
            trans_dict[nodename] = line_list
    tf.close

all_lines = []
all_nodes = []

files = sys.argv[1].split(',')

for file in files:
    linecnt=0
    if not os.path.isfile(file):
        answer = raw_input('\nFile "' + file + '" does not exist.  Continue? (y/n) : ')
        if answer in 'yY':
            print '\nNOTICE: Skipping slurp of file "' + file + '"\n'
            continue
        elif answer in 'nN':
            sys.exit('\nExiting script')
        else:
            sys.exit('\nERROR: "' + answer + '" is not a valid answer!  Exiting script\n')
    f = open(file)
    for line in f:
        linecnt = linecnt + 1
        strip_line = line.rstrip('\n')
        line_list = strip_line.split(',')
        # skip lines that aren't valid 
        if len(line_list) != 5:
            #print "Line " + str(linecnt) + " is not a valid line. Skipping..."
            continue
        # if transfile was specified, do the translations now
        if istransfile == 1:
            if trans_dict.has_key(line_list[1]):
                trans_nodename = " :: ".join(trans_dict[line_list[1]])
                line_list[1] = trans_nodename
        all_lines.append(line_list)
        # make a list of all nodes
        all_nodes.append(line_list[1])
    f.close

# create a unique the list of nodes 
uniq_nodes = uniq(all_nodes)

#for each node, make a list of unique ports for that node, then put in a dict
node_ports = {}
for node in uniq_nodes:
    port_list = []
    for element in all_lines:
        if node in element[1]:
            if element[4] != '0':
                port_list.append(element[4])
    uniq_ports =  uniq(port_list)
    node_ports[node] = uniq_ports

matchlist = []
for key in node_ports.keys():
    for port in node_ports[key]:
        for element in all_lines:
            # for this node and this node's port, compare to the entire list to find matches
            # if a match is found put it in the match list
            if key == element[1] and port == element[4]:
                matchlist.append(element)            
        # if the matchlist is > than 1 then we have a conflict
        if len(matchlist) > 1:
            conflict = 1
            print "Port Conflict Detected on Node " + key + " at " + port
            print '%-5s %-20s %-25s %s' % ('','CELL','APP SERVER','PORT NAME')
            print '%-5s %-20s %-25s %s' % ('','----','----------','---------')
            for portdef in matchlist:
                print '%-5s %-20s %-25s %s' % ('',portdef[0],portdef[2],portdef[3])
            print ''
            matchlist = []
        else:
            matchlist = []