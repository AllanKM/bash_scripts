#!/bin/ksh

###################################################################
#
#  install_ihs_fixes.sh -- This script is used to install ihs fixes
#             either explicitely or by getting this list from the
#             fix dir
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

# Process command-line options
until [ -z "$1" ] ; do
        case $1 in
                root=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DESTDIR=$VALUE; fi ;;
                version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FULLVERSION=$VALUE; fi ;;
                bits=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then BITS=$VALUE; fi ;;
                toolsdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
                fix=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PACKAGES=$VALUE; fi ;;
                *)      print -u2 -- "#### Unknown argument: $1"
                        print -u2 -- "#### Usage: $0 [ root=<IHS install root directory ] [ version=<desired IHS version> ]"
                        print -u2 -- "####           [ bits=<64 or 32> ] [ toolsdir=<path to ihs scripts> ]"
                        print -u2 -- "####           [ fix=< fixpkg name > ]"
                        exit 1
                        ;;
        esac
        shift
done

install_fixes_61 ()
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

    FIXRESPFILE=ihs${BASELEVEL}.fixes.silent.script

    cd ${SRCDIR}/fixes/ihs

    if [[ $PACKAGES == "" ]]; then
      LIST=`ls ${BASELEVEL}*.pak |grep -n pak |sed 's/^\([0-9]*\):/\1.- /'`
    else
      SPLITPACKAGES=`echo ${PACKAGES} | sed 's/\:/\\\n/g'`
      LIST=`echo ${SPLITPACKAGES} | grep -n pak |sed 's/^\([0-9]*\):/\1.- /'`
    fi

    if [[ ! -f ${DESTDIR}/UpdateInstaller/update.sh ]]; then
      echo "Cannot find ${DESTDIR}/UpdateInstaller/update.sh"
      echo "Skipping updates"
      exit 1
    elif [[ `ls ${SRCDIR}/fixes/ihs/${BASELEVEL}*.pak|wc -l` -gt 0 ]]; then
      echo "Applying patches in this order in $SLEEP seconds, Ctrl-C to suspend"
      echo "$LIST"
      echo ""
      sleep $SLEEP

      for FIXPKG in $LIST; do
        if [[ $FIXPKG == *.pak ]]; then
          FIXPACKTYPE=`echo ${FIXPKG}|sed 's/-FP.*//'`

          if ls ${DESTDIR}/UpdateInstaller/maintenance/${FIXPACKTYPE}* > /dev/null 2>&1 ; then
             echo "Removing previous fixpacks of type ${FIXPACKTYPE}"
             echo " from ${DESTDIR}/UpdateInstaller/maintenance"
             rm ${DESTDIR}/UpdateInstaller/maintenance/${FIXPACKTYPE}*
          fi

          echo "Copying ${FIXPKG} to ${DESTDIR}/UpdateInstaller/ ..."
          cp ${SRCDIR}/fixes/ihs/${FIXPKG} ${DESTDIR}/UpdateInstaller/maintenance
          if [ ! -f ${RESPDIR}/${FIXRESPFILE} ]; then
            echo "File ${RESPDIR}/${FIXRESPFILE} does not exist"
            echo "Use Tivoli SD tools to push /lfs/system/tools/ihs files to this server"
          else
            echo "Applying $FIXPKG now...."
            cp ${RESPDIR}/${FIXRESPFILE} /tmp
            cd /tmp
            sed -e "s%maintenance.package=.*%maintenance.package=${SRCDIR}/fixes/ihs/${FIXPKG}%" ${FIXRESPFILE}  > ${FIXRESPFILE}.custom && mv ${FIXRESPFILE}.custom  $FIXRESPFILE
            sed -e "s%product.location=.*%product.location=${DESTDIR}%" ${FIXRESPFILE}  > ${FIXRESPFILE}.custom && mv ${FIXRESPFILE}.custom  $FIXRESPFILE
            #Install fix using created response file
            ${DESTDIR}/UpdateInstaller/update.sh -options /tmp/${FIXRESPFILE} -silent
            if [[ $FIXPKG == *IHS* ]]; then
              FIXLEVEL=`cat ${DESTDIR}/version.signature | awk '{print $4}'`
              echo "Updated IHS fix level is $FIXLEVEL"
            elif [[ $FIXPKG == *SDK* ]]; then
              SDKVERSION=`${DESTDIR}/java/jre/bin/java -fullversion 2>&1`
              echo "Updated SDK is ${SDKVERSION}"
            fi
          fi
          echo ""
        fi
      done
    else
      echo "No fixes found to apply in ${SRCDIR}/fixes/"
    fi
}

# Removes everything after the first two levels
BASELEVEL=`echo $VERSION | cut -d"." -f1,2`

case $BASELEVEL in
     6.1)
          install_fixes_61
     ;;
     *)
          print -u2 -- "${0:##*/}: Version $BASELEVEL not supported by this install script."
          exit 3
     ;;
esac

       
