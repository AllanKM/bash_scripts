#!/bin/bash
#
# Usage: sudo ./fetchfixpack.sh 61035 plg aixppc32
#

who=`whoami`
if [ $who != 'root' ]; then
  echo "Execute as root"
  exit 1
fi
if [ `hostname` != 'z10048' ]; then
  echo "Script should be run z10048 only"
  exit 1
fi
ver=$1
type=$2
platform=$3
ver_short=${ver:0:2}
major=${ver:0:1}
submajor=${ver:1:1}
subsubmajor=${ver:2:1}
fp_ver=`printf "%02d" ${ver:3:2}`
ver_long=${major}.${submajor}.${subsubmajor}

case $platform in
[aA][iI][xX][pP][pP][cC]32)
  platform=AixPPC32
  os=aix
  ;;
[aA][iI][xX][pP][pP][cC]64)
  platform=AixPPC64
  os=aix-64
  ;;
[lL][iI][nN][uU][xX][xX]32)
  platform=LinuxX32
  os=linux
  ;;
[lL][iI][nN][uU][xX][xX]64)
  platform=LinuxX64
  os=linux-64
  ;;
[lL][iI][nN][uU][xX][pP][pP][cC]64)
  platform=LinuxPPC64
  os=linuxppc64
  ;;
[lL][iI][nN][uU][xX][pP][pP][cC])
  platform=LinuxPPC32
  os=linuxppc
  ;;
*)
  echo "Supported platforms are the following:"
  echo "  AixPPC32"
  echo "  AixPPC64"
  echo "  LinuxX32"
  echo "  LinuxX64"
  echo "  LinuxPPC"
  echo "  LinuxPPC64"
  exit 1
esac

case $type in
[wW][aA][sS][sS][dD][kK])
  type=WASSDK
  subdir='base/fixes/'
  ;;
[wW][aA][sS])
  type=WAS
  subdir='base/fixes/'
  ;;
[iI][hH][sS])
  type=IHS
  subdir="supplements/fixes/${ver}/ihs/"
  ;;
[pP][lL][gG])
  type=PLG
  subdir="supplements/fixes/${ver}/plugin/"
  ;;
*)
  echo "Supported fixpack types are the following:"
  echo "  was"
  echo "  wassdk"
  echo "  ihs"
  echo "  plg"
  exit 1
esac

function wgetit(){
cd $1
if [ ! -f $filename ]; then
  wget ${ftp}/${filename}
else    
  echo ${filename} exists.
fi
}

function mkfixdir(){
if [ ! -d $1 ]; then
  echo $1 does not exist.  Creating...
  mkdir -p $1
  chmod 775 $1
  chgrp eiadm $1
fi
}

ftp=ftp://ftp.software.ibm.com/software/websphere/appserv/support/fixpacks/was${ver_short}/cumulative/cf${ver}/${platform}
filename=${ver_long}-WS-${type}-${platform}-FP00000${fp_ver}.pak
fixdir=/fs/system/images/websphere/${major}.${submajor}/${os}/${subdir}
mkfixdir $fixdir
wgetit $fixdir

if [ ${type} = 'IHS' ]; then
  # Get WASSDK as well for IHS
  filename=${ver_long}-WS-WASSDK-${platform}-FP00000${fp_ver}.pak
  wgetit $fixdir
fi
if [ ${type} = 'PLG' ]; then
  filename=${ver_long}-WS-WASSDK-${platform}-FP00000${fp_ver}.pak
  wgetit $fixdir
fi

echo "*** Starting sync operation ***"
echo ""
/fs/system/bin/eisync --notgpfs ${fixdir} --ecctoo
#ls ${fixdir}
cd -
