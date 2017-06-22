#! /bin/ksh

################################################################
#
#  install_plugin_fixes.sh -- script used to install fix packs 
#           for websphere plugin
#
#---------------------------------------------------------------
#
#  Todd Stephens - 08/22/07 - Initial creation
#
################################################################

# Set umask
umask 002

# Set Defaults
FULLVERSION=51111
BITS=32
TOOLSDIR="/lfs/system/tools"
RESPDIR=${TOOLSDIR}/was/responsefiles
WAS_ETC=${TOOLSDIR}/was/etc
IHSDIR=/usr/HTTPServer

SLEEP=10

#process command-line options

until [ -z "$1" ] ; do
        case $1 in
                root=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then IHSDIR=$VALUE; fi ;;
                version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FULLVERSION=$VALUE; fi ;;
                bits=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then BITS=$VALUE; fi ;;
                toolsdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
                responsedir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then RESPDIR=$VALUE; fi ;;
                fix=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PACKAGES=$VALUE; fi ;;
                *)      print -u2 -- "#### Unknown argument: $1"
                        print -u2 -- "#### Usage: $0 [ version=< desired WAS version > ] [ bits=< 64 or 32 > ]"
                        print -u2 -- "####           [ toolsdir=< path to ihs scripts > ] [ vg=< volume group > ]"
                        print -u2 -- "####           [ responsedir=< full path to direcdtory with response files > ]"
                        print -u2 -- "####           [ root=< IHS install root directory > ] [ fix=< fixpkg name > ]"
                        exit 1
                        ;;
        esac
        shift
done

install_fixes_61 ()
{
   case `uname` in
        AIX)
			###Check for 64-bit flag
			if [[ $BITS == "64" ]]; then
				WASSRCDIR="/fs/system/images/websphere/6.1/aix-64"
			else
				WASSRCDIR="/fs/system/images/websphere/6.1/aix"
			fi
        ;;
		Linux)
			###Check cpu type
			if [[ -n `uname -p|grep ppc` ]]; then
				###Check for 64-bit flag
				if [[ $BITS == "64" ]]; then
					WASSRCDIR="/fs/system/images/websphere/6.1/linuxppc-64"
				else
					WASSRCDIR="/fs/system/images/websphere/6.1/linuxppc"
				fi
			else
				###Check for 64-bit flag
				if [[ $BITS == "64" ]]; then
					echo "No 64-bit src image defined for non-ppc linux"
					echo "exiting..."
					exit 1
				else
					WASSRCDIR="/fs/system/images/websphere/6.1/linux"
				fi
			fi
        ;;
    esac
	FIXDIR="${WASSRCDIR}/supplements/fixes/plugin"
    DESTDIR="${IHSDIR}/Plugins"
    FIXRESPFILE="v${VERSION}silent.plugin.fixes.script"
              
    cd $FIXDIR

    if [[ $PACKAGES == "" ]]; then
       LIST=`ls 6.1*.pak |grep -n pak |sed 's/^\([0-9]*\):/\1.- /'`
    else
       SPLITPACKAGES=`echo ${PACKAGES} | sed 's/\:/\\\n/g'`
       LIST=`echo ${SPLITPACKAGES} | grep -n pak |sed 's/^\([0-9]*\):/\1.- /'`
    fi

  
    if [ ! -f ${IHSDIR}/UpdateInstaller/update.sh ]; then
       echo "UpdateInstaller required to install fixes. Cannot find ${IHSDIR}/UpdateInstaller/update.sh"
       echo "Exiting..."
       exit 1
    elif ls ${FIXDIR}/6.1*.pak >/dev/null 2>&1 ; then
       echo "Applying patches in this order in $SLEEP seconds, Ctrl-C to suspend"
       echo "$LIST"
       echo ""
       sleep $SLEEP

       for FIXPKG in 6.1*.pak; do
          if [[ $FIXPKG == *.pak ]]; then
             FIXPACKTYPE=`echo ${FIXPKG}|sed 's/-FP.*//'`
        
             if ls ${IHSDIR}/UpdateInstaller/maintenance/${FIXPACKTYPE}* > /dev/null 2>&1 ; then
                echo "Removing previous fixpacks of type ${FIXPACKTYPE}"
                echo " from ${IHSDIR}/UpdateInstaller/maintenance"
                rm ${IHSDIR}/UpdateInstaller/maintenance/${FIXPACKTYPE}*
             fi

             echo Copying ${FIXPKG} to ${IHSDIR}/UpdateInstaller/...
             cp ${FIXDIR}/${FIXPKG} ${IHSDIR}/UpdateInstaller/maintenance
             echo Applying $FIXPKG now....
             if [ ! -f ${RESPDIR}/${FIXRESPFILE} ]; then
                echo "File ${RESPDIR}/${FIXRESPFILE} does not exist"
                echo "Use Tivoli SD tools to push ${TOOLSDIR}/was files to this server"
                echo "Exiting..."
                exit 1
             else
                cp ${RESPDIR}/${FIXRESPFILE} /tmp
                cd /tmp
                sed -e "s%maintenance.package=.*%maintenance.package=${FIXDIR}/${FIXPKG}%" ${FIXRESPFILE}  > ${FIXRESPFILE}.custom && mv ${FIXRESPFILE}.custom $FIXRESPFILE
                sed -e "s%product.location=.*%product.location=${DESTDIR}%" ${FIXRESPFILE}  > ${FIXRESPFILE}.custom && mv ${FIXRESPFILE}.custom  $FIXRESPFILE
                #Install fix using created response file
                ${IHSDIR}/UpdateInstaller/update.sh -options /tmp/${FIXRESPFILE} -silent
                echo "Installation complete"
                echo ""
                FULLVER=`grep "<version>" ${DESTDIR}/properties/version/PLG.product | cut -d">" -f2 | cut -d"<" -f1`
                echo "Updated Plugin version is now ${FULLVER}"
                echo ""
             fi
          fi
       done
    else
       echo "No fixes found to apply in ${FIXDIR}"
    fi
}

VERSION=`echo $FULLVERSION | cut -c1,2`

echo "Ensuring /tmp has 500MB in it"
fsize=`df -m /tmp|tail -1|awk '{split($2,s,"."); print s[1]}'`
if [ "$fsize" -lt 1024 ]; then
	echo "  -> Increasing /tmp filesystem size to 500MB"
	/fs/system/bin/eichfs /tmp 500M
else
	echo "  -> Filesystem /tmp already larger than 500MB, making no changes."
fi

case $VERSION in
        61)     
            install_fixes_61
        ;;
        *)
            echo "Version $VERSION plugin install not supported by this script."
            echo "Exiting"
            exit 1
        ;;
esac

