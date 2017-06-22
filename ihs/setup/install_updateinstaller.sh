#!/bin/ksh

###################################################################
#
#  install_updateinstaller.sh -- This script is used to install
#             the latest UpdateInstaller code
#
#------------------------------------------------------------------
#
#  Todd Stephens - 8/21/07 - Initial creation
#
###################################################################

# Set umask
umask 002

# Default values
DESTDIR=/usr/HTTPServer
VERSION=6.1
BITS=32
TOOLSDIR=/lfs/system/tools
UPDI_LEVEL=""

# Process command-line options
until [ -z "$1" ] ; do
        case $1 in
                root=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DESTDIR=$VALUE; fi ;;
                version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FULLVERSION=$VALUE; fi ;;
                bits=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then BITS=$VALUE; fi ;;
                updiVersion=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then UPDI_LEVEL=$VALUE; fi ;;
                toolsdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
                *)      print -u2 -- "#### Unknown argument: $1"
                        print -u2 -- "#### Usage: $0 [ root=<IHS install root directory ] [ version=<desired IHS version> ]"
                        print -u2 -- "####           [ bits=<64 or 32> ] [ toolsdir=<path to ihs scripts> ]"
                        exit 1
                        ;;
        esac
        shift
done

UpdateInstaller_61 ()
{


case `uname` in
   AIX)
      if [[ $BITS == "64" ]]; then
         WASSRCDIR="/fs/system/images/websphere/6.1/aix-64"
      else
         WASSRCDIR="/fs/system/images/websphere/6.1/aix"
      fi
      ;;

      Linux)
         uname -a | grep ppc

         if [[ "$?" -eq 0 ]]; then
            WASSRCDIR="/fs/system/images/websphere/6.1/linuxppc"
            if [[ $BITS == "64" ]]; then
               WASSRCDIR="/fs/system/images/websphere/6.1/linuxppc-64"
            fi
         else
            WASSRCDIR="/fs/system/images/websphere/6.1/linux"
         fi
         ;;

      *)
         print -u2 -- "${0:##*/}: `uname` not supported by this install script."
         exit 1
         ;;
esac



    SRCDIR="${WASSRCDIR}/supplements"
    RESPDIR="${TOOLSDIR}/ihs/responsefiles"

    SLEEP=10

    UPDRESPFILE=ihs${BASELEVEL}.updinst.silent.script
    if [ ! -d ${WASSRCDIR}/update/UPDI-${UPDI_LEVEL}/UpdateInstaller ]; then
      echo "UpdateInstaller image not found in $WASSRCDIR/update/UPDI-${UPDI_LEVEL}/UpdateInstaller."
      echo "Exiting UpdateInstaller install."
      echo "Note:  Can not install any updates."
      exit 1
    elif [ ! -f ${RESPDIR}/${UPDRESPFILE} ]; then
      echo "File ${RESPDIR}/${UPDRESPFILE} does not exist"
      echo "Use Tivoli SD tools to push /lfs/system/tools/ihs files to this server"
      echo "Exiting UpdateInstaller install."
      echo "Note:  Can not install any updates."
      exit 2
    else
      FIXLEVEL=`cat ${DESTDIR}/UpdateInstaller/version.txt| grep Version: | awk {'print $2'}`
      UPDIVERSION=`cat ${WASSRCDIR}/update/UPDI-${UPDI_LEVEL}/UpdateInstaller/version.txt| grep Version: | awk {'print $2'}`

#     if [[ `echo $FIXLEVEL|sed 's/\.//g'` -lt `echo $UPDIVERSION|sed 's/\.//g'` ]]; then
      CURFIXLEVEL=`echo $FIXLEVEL| awk -F . '{ print ($1*1000000)+($2*10000)+($3*100)+$4 }'`
      NEWFIXLEVEL=`echo $UPDIVERSION| awk -F . '{ print ($1*1000000)+($2*10000)+($3*100)+$4 }'`
      if [[ $CURFIXLEVEL -lt $NEWFIXLEVEL ]]; then
        echo "Installing UpdateInstaller..."
        cp ${RESPDIR}/${UPDRESPFILE} /tmp
        cd /tmp
        sed -e "s%installLocation=.*%installLocation=${DESTDIR}/UpdateInstaller%" ${UPDRESPFILE} > ${UPDRESPFILE}.custom && mv ${UPDRESPFILE}.custom  $UPDRESPFILE
        # Install using edited responsefile
        /${WASSRCDIR}/update/UPDI-${UPDI_LEVEL}/UpdateInstaller/install -options /tmp/${UPDRESPFILE} -silent
        echo "UpdateInstaller installation complete!"

        echo ""
        FIXLEVEL=`cat ${DESTDIR}/UpdateInstaller/version.txt| grep Version: | awk {'print $2'}`
        echo "UpdateInstaller fixlevel is $FIXLEVEL"
      else
        echo "UpdateInstaller is already at a version (${FIXLEVEL})"
        echo "which is equal to or higher then"
        echo "the requested level of $UPDIVERSION (${UPDI_LEVEL})"
      fi   
    fi
}

# Removes everything after the first two levels 
BASELEVEL=`echo $VERSION | cut -d"." -f1,2`

case $BASELEVEL in
     6.1)
          UpdateInstaller_61
     ;;
     *)
          print -u2 -- "${0:##*/}: Version $BASELEVEL not supported by this install script."
          exit 3
     ;;
esac
