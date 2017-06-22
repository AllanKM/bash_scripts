#!/bin/bash
#   Usage: was_tsm_backup.sh VERSION"

if [ "$USER" != "root" ]; then
	echo "Must be run with sudo!"
	exit 1
fi

FULLVERSION=${1:-70025}
VERSION=`echo $FULLVERSION | cut -c1-2`
DIRLIST="/projects /usr/WebSphere${VERSION}"
CUSTTAG=`lssys -x csv -l custtag -n |grep -v '^#'| awk '{split($0,c,","); print c[2]}'`
LOGFILE="/logs/was${VERSION}/was_tsm_bak_manual.log"

echo "!! Backing up ($DIRLIST) to TSM for customer ($CUSTTAG) !!"
/fs/system/tools/tsm/bin/tsm_bak $CUSTTAG $DIRLIST  > $LOGFILE
