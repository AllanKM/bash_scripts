#!/usr/bin/env python
import os,glob
# Use BASEDIRS to begin search of products
BASEDIRS = [ '/opt', '/usr' ]
# Common subdir names
DIRS = ['HTTP*', 'Web*', 'IBM']
# File extensions containing fix info and product info
EXTENSIONS = [ 'fxtag', 'product' ]
# List to be populated with directories to search
FOUNDDIRS = []

def gofind():
	for d in FOUNDDIRS:
		for root, dirs, files in os.walk(d, topdown=False):
			for name in files:
				if name.split('.')[-1] in EXTENSIONS:
					print os.path.join(root, name)  
		
for B in BASEDIRS:
	for D in DIRS:
		try:
			dirs = [d for d in glob.glob("%s/%s" % ( B, D ) ) if os.path.isdir(d) and not os.path.islink(d) ]
			if len(dirs) > 0: FOUNDDIRS.extend(dirs)
		except OSError:
			pass

gofind()
