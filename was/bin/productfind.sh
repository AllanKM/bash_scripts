#!/usr/bin/env bash
libdir=/lfs/system/tools/was/lib
productfind=${libdir}/productfind.py
xmlscript=${libdir}/getProduct.py
fixscript=${libdir}/getFix.py
dropdir=/fs/system/config/was/version
altdropdir=/fs/scratch/version
node=`hostname`
role=`lssys -x csv -l role $node |grep -v '#' |awk -F, {'print $2'}`
# Create dropdir
if [ ! -d $dropdir ]; then
  echo "$dropdir does not exist, creating."
  mkdir $dropdir
fi
# If perms not able to be updated, dropdir is readonly - use alt
chmod 755 $dropdir
if [ $? -ne 0 ]; then
  echo "Failed on modifying ${dropdir}, using alternate location"
  if [ ! -d $altdropdir ]; then
    echo "$altdropdir does not exist, creating."
    mkdir $altdropdir
  fi
  chmod 755 $altdropdir
  versionfile=${altdropdir}/${node}.csv
else
  versionfile=${dropdir}/${node}.csv
fi

if [ -f $versionfile ]; then
rm $versionfile
fi

for f in `${productfind}`; do 
  file=`basename $f`
  proddir=`echo $f |awk -F$file {'print $1'}`
if [ $f == '*product' ]; then
	  $xmlscript $file $node $proddir $role |tee -a $versionfile
else
          $fixscript $f $node $proddir $role |tee -a $versionfile
fi
done
