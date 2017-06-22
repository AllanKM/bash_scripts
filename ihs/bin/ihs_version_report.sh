#!/bin/ksh

print "PRE"
grep -i "server version" ~/*_IHS.txt | sed -e 's/^.*\.txt://' -e 's/\/bin\/[a-z0-9]*//' -e 's/Server //' | grep 'PRE' | sort
print "p1ci excluding PRE/CDT"
grep -i "server version"~/ *_IHS.txt | sed -e 's/^.*\.txt://' -e 's/\/bin\/[a-z0-9]*//' -e 's/Server //' | grep 'w1[0-9]*' | grep -vE "PRE|CDT"| sort
print "p1cs"
grep -i "server version" ~/*_IHS.txt | sed -e 's/^.*\.txt://' -e 's/\/bin\/[a-z0-9]*//' -e 's/Server //' | grep 'v1[0-9]*' | sort
print "p2ci excluding PRE/CDT"
grep -i "server version" ~/*_IHS.txt | sed -e 's/^.*\.txt://' -e 's/\/bin\/[a-z0-9]*//' -e 's/Server //' | grep 'w2[0-9]*' | grep -vE "PRE|CDT"| sort
print "p2cs"
grep -i "server version" ~/*_IHS.txt | sed -e 's/^.*\.txt://' -e 's/\/bin\/[a-z0-9]*//' -e 's/Server //' | grep 'v2[0-9]*' | sort
print "p3ci excluding PRE/CDT"
grep -i "server version" ~/*_IHS.txt | sed -e 's/^.*\.txt://' -e 's/\/bin\/[a-z0-9]*//' -e 's/Server //' | grep 'w3[0-9]*' | grep -vE "PRE|CDT"| sort
print "p3cs"
grep -i "server version" ~/*_IHS.txt | sed -e 's/^.*\.txt://' -e 's/\/bin\/[a-z0-9]*//' -e 's/Server //' | grep 'v3[0-9]*' | sort
print "p5cs"
grep -i "server version" ~/*_IHS.txt | sed -e 's/^.*\.txt://' -e 's/\/bin\/[a-z0-9]*//' -e 's/Server //' | grep 'v5[0-9]*' | sort
