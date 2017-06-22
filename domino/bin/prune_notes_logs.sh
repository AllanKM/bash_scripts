#!/bin/sh
#This utility is meant to prune log files that have not been accessed in over 60 days.
# In a nutshell, it  executes a find command on a list of directories and performs a remove of any files not access in over 60 days


for director in  /logs/domino 

do
   find $director -name  "access*"  -mtime +60 -print | wc -l >> /tmp/logprune.log 2>&1

   find $director -name  "agent*"  -mtime +60 -print | wc -l >> /tmp/logprune.log 2>&1
   find $director -name  "referer*"  -mtime +60 -print | wc -l >> /tmp/logprune.log 2>&1

   find $director -name "refer*" -mtime +60 -exec rm {} ';'  >> /tmp/logprune.log 2>&1
   find $director -name "access*" -mtime +60 -exec rm {} ';' >> /tmp/logprune.log 2>&1
   find $director -name "agent*"  -mtime +60 -exec rm {} ';' >> /tmp/logprune.log 2>&1

done
