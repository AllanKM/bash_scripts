#!/bin/sh

# Runs TIP WAS security config for NCO on z10059 
# Run under sudo

US=netcool; GR=itmusers; WH=/opt/IBM/Netcool/tip; PR=/opt/IBM/Netcool
DKTS_override="-DKTS z10031_netcool.jks  o0py7Gtr" 

pw=""     # No password supplied, so use "tipadmin"  
#  Use this  if rerunning after pw has eebn changed: 
#  pw="-tippw Um1nhTy7"

cd  /lfs/system/tools/tip/setup
sudo ./tip_was_security_setup_v2.sh  ED   70  TIPProfile -projroot $PR -washome $WH $pw \
      -user $US -group $GR $DKTS_override -debug


