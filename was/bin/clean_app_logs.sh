#!/bin/bash
# Uses the log names passed as arguments and searches the log directories for old instances of them to prune
# Usage: clean_app_logs.sh VERSION LOG-1 ... LOG-N
#
# Example: clean_app_logs.sh 61 ied.log
# Will prune: WAS 6.1 Logs matching the name ied.log.* (for the archived ones)
#
# Note: The script cannot prune logs for more than one version in a given run.

HOST=`hostname -s`
VERSION=$1
LOGDIR="/logs/was${VERSION}"
LOGS=`echo $* | cut -d' ' -f2-`

# Clean up app logs older than 15 days
for log in $LOGS; do
        find $LOGDIR -name "${log}.*" -mtime +15 -exec rm {} \;
done