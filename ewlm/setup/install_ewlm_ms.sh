#!/bin/sh

#
# install_ewlm_ms.sh - Script to install/configure ARM services and the EWLM managed server client code
#
# Author:	Sandy Cash
# Date:		29.June.2005
# Contact:	lhcash@us.ibm.com
#
#
# $Id: install_ewlm_ms.sh,v 1.1.1.1 2006/04/08 18:12:57 russcadd Exp $
#

while getopts

#
# Enable webinst to ARM-enable apps:
#

chuser capabilities=CAP_ARM_APPLICATION,CAP_PROPAGATE webinst

#
# Increase filesystems
#

chfs -a size=1000000 /opt

#
# Install netWLM AIX filesets
#

cd /fs/system/images/aix/530/lppsource
installp -acgNd . bos.net.ewlm.rte
cd /fs/system/images/aix/530/ml1
installp -acgNd . bos.net.ewlm.rte

#
# /fs/system/tools/syscfg/bin/chksyscfg (make sure that the installed versions of the netWLM filesets are sufficient)
#

#
# Install EWLM
#

cp /fs/system/images/ve/Agents/EWLMAixMS.bin /tmp

cd /tmp
./EWLMAixMS.bin -silent -P managedServerBean.active=true

rm /tmp/ELWMAixMS.bin

#
# Install EWLM fixes
#

cp /fs/system/images/ve/fixes/EWLM/MS/EWLMAixMSService.bin /tmp

/tmp/EWLMAixMSService.bin -silent -P managedServerBean.active=true

rm /tmp/EWLMAixMSService.bin

#
# Configure ManagedServer
#

cd /opt/IBM/VE/EWLMMS/bin
./createMS.sh /opt/IBM/VE/EWLMMS/workingDirectory -ma gt0802c -mp 20002 -auth None

#
# Enable platform support for ARM:
#

echo <<EOM
Enabling EWLM on AIX
To enable EWLM on AIX®, log in as the root user, or as a user with root authority, and use the series of SMIT panels available by typing smitty ewlm at the command line. The SMIT panels will lead you through the following process to enable EWLM on AIX:
1.	Select Change/Show Status of the EWLM services and press Enter. 
2.	Select Enable the EWLM services and press Enter. You are prompted to confirm your request to enable EWLM. Select Enter to continue or F3 to cancel.
EOM
