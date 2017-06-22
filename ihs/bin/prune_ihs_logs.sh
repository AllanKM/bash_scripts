#!/bin/sh
#This utility is meant to prune log files that were written  over 60 days ago.
# In a nutshell, it  executes a find command on a list of directories and performs a removal  of any access_log and error_log files created over 60 days ago.
#NOTE:  It executes as user webinst and on specific directories to mitigate risk of removing files required by some one system funciton or utility.

LOGS=`ls /logs/redirect* /logs/splitter*`
for director in  "$LOGS"

do
   find $director -name  "access*"  -mtime +60 -print | wc -l >> /tmp/logprune.log 2>&1

   find $director -name  "error*"  -mtime +60 -print | wc -l >> /tmp/logprune.log 2>&1

   find $director -name  "access*" -mtime +60 -exec rm {} ';' >> /tmp/logprune.log 2>&1
   find $director -name  "error*"  -mtime +60 -exec rm {} ';' >> /tmp/logprune.log 2>&1

done
