#!/usr/bin/env bash
locale -a |grep -q UTF-8
if [ $? -ne 0 ]; then
  noutf="noutf"
else
  noutf="utf"
fi
for d in $(find /projects -name plugin-cfg.xml); do
  export LANG=en_US.UTF-8
  /lfs/system/tools/was/lib/genPlgPaths.py $d $noutf
  echo
done
