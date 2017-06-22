#!/bin/sh

# Runs TIP WAS post installer script for NCR on z10059 
# Run under sudo


/lfs/system/tools/tip/bin

sudo ./tip_backup.sh  tip  -washome /opt/IBM/Netcool/tip 

