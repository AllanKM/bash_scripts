#!/bin/sh

# Runs TIP WAS post installer script for NCR on z10059 
# Run under sudo


WASHOME=/opt/IBM/Netcool/tip

cd /lfs/system/tools/tip/setup

./tip_postinstall_was_v2.sh 70  -washome $WASHOME -heap 128 256

