#!/bin/ksh

#---------------------------------------------------------------
# IHS silent install according to EI standards
#---------------------------------------------------------------

# Set umask
umask 002

#Default values
#Standard IHS version to install
FULLVERSION=6.1.0.13
UPDI_LEVEL=FP0000013
# Size of IHS install filesystem
IHS_FS_SIZE=1504
# Size of /project in MB ( default is 15GB )
PROJECT_FS_SIZE=15360
# Specify where to install the server root files
DESTDIR=/usr/HTTPServer
BITS=32
TOOLSDIR=/lfs/system/tools
if lsvg appvg >/dev/null 2>&1; then
	VG=appvg
else
	VG=rootvg
fi


#process command-line options
until [ -z "$1" ] ; do
	case $1 in
		size=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then PROJECT_FS_SIZE=$VALUE; fi ;;
		root=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DESTDIR=$VALUE; fi ;;
		version=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then FULLVERSION=$VALUE; fi ;;
		bits=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then BITS=$VALUE; fi ;;	
                updiVersion=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then UPDI_LEVEL=$VALUE; fi ;;
		toolsdir=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then TOOLSDIR=$VALUE; fi ;;
		vg=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then VG=$VALUE; fi ;;
		*) 	print -u2 -- "#### Unknown argument: $1" 
			print -u2 -- "#### Usage: $0 [ size=<size of /projects in MB> ] [ root=<IHS install root directory ]"
			print -u2 -- "####           [ version=<desired IHS version> ] [ bits=<64 or 32> ]"
			print -u2 -- "####           [ toolsdir=<path to ihs scripts> ] [ vg=<volume group> ]"
			print -u2 -- "####           [ updiVersion=<UpdateInstaller Version> ]"
			exit 1
			;;
        esac
        shift
done


install_ihs_aix ()
{

#Find some IBM JDK to use
    unset JAVA
    for java in /usr/bin/java /opt/IBMJava*/bin/java /usr/java14/jre/bin/java; do
        test -x "$java"  && $java -fullversion 2>&1 |grep -q IBM && JAVA=$java
    done
    JAVA_COMMAND=$JAVA

    SRCDIR="/fs/system/images/ihs/aix/IHS-2.0.47.1"
    EIMODULES="$SRCDIR/libexec/*"
    

# removes everything upto IHS- and the trailing /
    BASELEVEL="${SRCDIR##*IHS-}"
    BASELEVEL=${BASELEVEL%/}

    SLEEP=10

    if test -x "$JAVA_COMMAND" ; then
#---------------------------------------------------------------
# Uninstall previous version
#---------------------------------------------------------------
        echo "Removing old versions of IHS if they exist"

        echo "Stop Apache if running"
    	/lfs/system/tools/configtools/countprocs.sh 2 httpd 
        if [ $? -eq 0 ]; then
		echo "Stopping IHS"
		/etc/apachectl stop 
	fi

        echo "Removing Previous versions of Apache if installed in $DESTDIR"
        if test -f ${DESTDIR}/_uninst/uninstall.jar
        then
           cd ${DESTDIR}/_uninst/
           $JAVA_COMMAND -jar uninstall.jar -silent
        fi

	if [ -d $DESTDIR ]; then
        	echo "removing contents of "$DESTDIR
        	cd /tmp
        	rm -rf $DESTDIR/*
	fi

        lsfs $DESTDIR > /dev/null 2>&1
        if [ $? -gt 0 ]; then
           unmount $DESTDIR
           rmfs -r $DESTDIR
        fi

#---------------------------------------------------------------
# Install
#---------------------------------------------------------------
        echo "Installing IHS ${BASELEVEL} from $SRCDIR"
        sleep $SLEEP
        cd $SRCDIR
        echo "Present directory is $SRCDIR"
        $JAVA_COMMAND -jar setup.jar -silent -options ei_silent.res

        installp -ac -d ${SRCDIR}/gskta.rte gskta

        [ -x $SRCDIR/bin/apachectl ] && cp -p $SRCDIR/bin/apachectl $DESTDIR/bin/apachectl

        echo "install complete"
        $DESTDIR/bin/apachectl stop
        echo "stopped server"
        /usr/sbin/slibclean

        if ls $SRCDIR/fixes/${BASELEVEL}-PK*tar >/dev/null 2>&1 ; then
                echo "Applying patches in this order in $SLEEP seconds, Ctrl-C to suspend"
                cd $SRCDIR/fixes
                ls ${BASELEVEL}-PK*tar |grep -n tar |sed 's/^\([0-9]*\):/\1.- /'
                sleep $SLEEP
                for fixpkg in ${BASELEVEL}-PK*tar; do
                        echo Applying $fixpkg now....
                        cd $DESTDIR && tar xf $SRCDIR/fixes/$fixpkg
                done
        else
                echo "No PK-level fixes found to apply in $SRCDIR/fixes/"
        fi
	echo "Installing EI specific modules"
	cp -f $EIMODULES  $DESTDIR/modules/

    else
        echo "No suitable JDK found, exiting."
        exit 1
    fi
}

install_ihs_61_aix ()
{

###Check for 64-bit flag
    if [[ $BITS == "64" ]]; then
       WASSRCDIR="/fs/system/images/websphere/6.1/aix-64"
    else
       WASSRCDIR="/fs/system/images/websphere/6.1/aix"
    fi

    SRCDIR="${WASSRCDIR}/supplements"
    RESPDIR="/lfs/system/tools/ihs/responsefiles"


# removes everything upto IHS- and the trailing /
    BASELEVEL=`echo $VERSION | cut -d"." -f1,2`

    SLEEP=10

#---------------------------------------------------------------
# Uninstall previous version
#---------------------------------------------------------------
        echo "Removing old versions of IHS if they exist"

        echo "Stop Apache if running"
	/lfs/system/tools/configtools/countprocs.sh 2 httpd 
	if [ $? -eq 0 ]; then
		echo "Stopping IHS"
		/etc/apachectl stop 
        else
                echo "IHS is not running"
	fi

        if [ -d $DESTDIR ]
        then
           echo "Removing Previous version of Apache from $DESTDIR"
           if test -f ${DESTDIR}/_uninst/uninstall.jar
           then
              cd ${DESTDIR}/_uninst/
              $JAVA_COMMAND -jar uninstall.jar -silent
           elif test -f ${DESTDIR}/uninstall/uninstall
           then
              cd ${DESTDIR}/uninstall/
              ./uninstall -silent
           else
              echo "No uninstall program exist in $DESTDIR"
           fi

           cd /tmp

           echo "Removing remaining dest dir $DESTDIR contents"
           rm -rf $DESTDIR/*

           lsfs $DESTDIR > /dev/null 2>&1
           if [ $? -eq 0 ]; then
              echo "Removing filesystem $DESTDIR"
              unmount $DESTDIR
              rmfs $DESTDIR
           fi
        else
           echo "$DESTDIR does not exist -- No previous install detected"
        fi

        HTTPDIR=`echo ${DESTDIR} | cut -d"/" -f3`
        if [ -d /logs/$HTTPDIR ]; then
                echo "Cleaning out global webserver logs from /logs/${HTTPDIR}"
                rm -r /logs/${HTTPDIR}/*
        fi
        echo ""

#---------------------------------------------------------------
# Install IHS base
#--------------------------------------------------------------
        echo "Installing IHS ${BASELEVEL} from $SRCDIR/IHS"
        sleep $SLEEP
        RESPONSEFILE=ihs${BASELEVEL}.base.silent.script
        if [ ! -f ${RESPDIR}/${RESPONSEFILE} ]; then
          echo "File ${RESPDIR}/${RESPONSEFILE} does not exist"
          echo "Use Tivoli SD tools to push /lfs/system/tools/ihs files to this server"
          echo "Exiting..."
          exit 1
        else
          /fs/system/bin/make_filesystem $DESTDIR $IHS_FS_SIZE $VG
          rm -rf ${DESTDIR}/*
          cp ${RESPDIR}/${RESPONSEFILE} /tmp
          cd /tmp
          sed -e "s%installLocation=.*%installLocation=${DESTDIR}%" ${RESPONSEFILE} > ${RESPONSEFILE}.custom && mv ${RESPONSEFILE}.custom  ${RESPONSEFILE}
          cd $SRCDIR/IHS
          echo "Beginning installation ..."
          ./install -options "/tmp/${RESPONSEFILE}" -silent -is:javaconsole
        fi
        echo "install complete"
        echo ""
 
        FIXLEVEL=`cat ${DESTDIR}/version.signature | awk '{print $4}'`
        echo "IHS version is $FIXLEVEL"
        SDKVERSION=`$DESTDIR/java/jre/bin/java -fullversion 2>&1`
        echo "SDK ${SDKVERSION}"

        echo ""
        echo "Stop Apache if running"
	/lfs/system/tools/configtools/countprocs.sh 2 httpd 
	if [ $? -eq 0 ]; then
	      echo "Stopping IHS"
	      $DESTDIR/bin/apachectl stop
        else
              echo "IHS is not running"
	fi
        /usr/sbin/slibclean
        echo ""
  
#--------------------------------------------------
# Installing Update installer needed to apply fixes
#---------------------------------------------------
        if [[ -d $DESTDIR/UpdateInstaller ]]; then
                FIXLEVEL=`cat ${DESTDIR}/UpdateInstaller/version.txt 2>/dev/null | grep Version: | awk {'print $2'}`
                echo "Initial image contains a version of UpdateInstaller"
                echo "UpdateInstaller fixlevel is $FIXLEVEL"
        fi
            
        ${TOOLSDIR}/ihs/setup/install_updateinstaller.sh root=$DESTDIR bits=$BITS version=$FULLVERSION updiVersion=$UPDI_LEVEL toolsdir=$TOOLSDIR

        if [[ $? -gt 0 ]]; then
          SKIPUPDATES=1
        fi

        echo ""

#------------------------------------------
# Installing Fixes
#------------------------------------------
        if [[ $SKIPUPDATES -eq 1 ]]; then
                echo "Install of UpdateInstaller required to install fixes failed"
                echo "Skipping updates"
        else
          ${TOOLSDIR}/ihs/setup/install_ihs_fixes.sh root=$DESTDIR bits=$BITS version=$FULLVERSION toolsdir=$TOOLSDIR
        fi

#------------------------------------------
# Summary of install
#------------------------------------------

  echo ""
  echo "Installation Summary"
  echo "-------------------------------------------"
  echo "IHS installed in $DESTDIR"
  FIXLEVEL=`cat ${DESTDIR}/version.signature | awk '{print $4}'`
  echo "IHS version is $FIXLEVEL"
  SDKVERSION=`${DESTDIR}/java/jre/bin/java -fullversion 2>&1`
  echo "SDK version is ${SDKVERSION}"
  FIXLEVEL=`cat ${DESTDIR}/UpdateInstaller/version.txt| grep Version: | awk {'print $2'}`
  echo "UpdateInstaller version is $FIXLEVEL"
  echo "-------------------------------------------"
  echo ""
}

install_ihs_linux ()
{

#Find some IBM JDK to use
    unset JAVA
    for java in /usr/bin/java /opt/IBMJava*/bin/java /usr/lib/IBMJava2/jre/bin/java; do
        test -x "$java"  && $java -fullversion 2>&1 |grep -q IBM && JAVA=$java
    done
    JAVA_COMMAND=$JAVA


    uname -a | grep ppc > /dev/null
    if [[ $? -eq 0 ]]; then
        SRCDIR="/fs/system/images/ihs/linux_ppc/IHS-2.0.47.1"
        EIMODULES="$SRCDIR/libexec/*"
    else
        SRCDIR="/fs/system/images/ihs/linux/IHS-2.0.47.1"
        EIMODULES="$SRCDIR/libexec_linux/*"
    fi

# removes everything upto IHS- and the trailing /
    BASELEVEL="${SRCDIR##*IHS-}"
    BASELEVEL=${BASELEVEL%/}

    SLEEP=3
    if test -x "$JAVA_COMMAND" ; then
#---------------------------------------------------------------
# Uninstall previous version
#---------------------------------------------------------------
        echo "Removing old versions of IHS if they exist"

        echo "Stop Apache if running"
    	/lfs/system/tools/configtools/countprocs.sh 2 httpd 
	    if [ $? -eq 0 ]; then
			echo "===>Stopping IHS"
			/etc/apachectl stop 
	    fi

        echo "Removing Previous versions of Apache if installed in $DESTDIR"
        if test -f ${DESTDIR}/_uninst/uninstall.jar
        then
           cd ${DESTDIR}/_uninst/
           $JAVA_COMMAND -jar uninstall.jar -silent
        fi

        echo "Removing Previous versions of Apache if installed in /opt/IBMHTTPServer"
        if test -f /opt/IBMHTTPServer/_uninst/uninstall.jar
        then
           cd /opt/IBMHTTPServer/_uninst/
           $JAVA_COMMAND -jar uninstall.jar -silent
           cd /tmp
           rm -fr /opt/IBMHTTPServer
        fi

        echo "Removing Previous versions GSK if installed"
        rpm -e gsk5bas 2>/dev/null

        echo "removing dest dir "$DESTDIR
        cd /tmp
        rm -rf $DESTDIR
        rm -f /usr/HTTPServer
        rm -fr /opt/IBMHTTPServer
        rm -f /opt/IBMHTTPServer


#---------------------------------------------------------------
# Install
#---------------------------------------------------------------
        echo "Installing IHS ${BASELEVEL} from $SRCDIR"
        sleep $SLEEP
        cd $SRCDIR
        echo "Present directory is $SRCDIR"
        $JAVA_COMMAND -jar setup.jar -silent -options ei_silent.res

        rpm -Uh --nodeps --ignorearch ${SRCDIR}/gsk7bas*rpm

        [ -x $SRCDIR/bin/apachectl ] && cp -p $SRCDIR/bin/apachectl $DESTDIR/bin/apachectl

        echo "install complete"
        $DESTDIR/bin/apachectl stop 2>/dev/null  && echo "stopped server"

        if ls $SRCDIR/fixes/${BASELEVEL}-PK*tar >/dev/null 2>&1 ; then
                echo "Applying patches in this order in $SLEEP seconds, Ctrl-C to suspend"
                cd $SRCDIR/fixes
                ls ${BASELEVEL}-PK*tar |grep -n tar |sed 's/^\([09-]*\):/\1.- /'
                sleep $SLEEP
                for fixpkg in ${BASELEVEL}-PK*tar; do
                        echo Applying $fixpkg now....
                        cd $DESTDIR && tar xf $SRCDIR/fixes/$fixpkg
                done
        else
                echo "No PK-level fixes found to apply in ${SRCDIR}/fixes/"
        fi
		echo "Installing EI specific modules"
		mkdir -p $DESTDIR/modules > /dev/null 2>&1
		cp -f $EIMODULES  $DESTDIR/modules/

    else
        echo "No suitable JDK found, exiting."
        exit 1
    fi
}


install_ihs_61_linux ()
{

   uname -a | grep ppc

   if [[ "$?" -eq 0 ]]; then
     ###Check for 64-bit flag
     if [[ $BITS == "64" ]]; then
        WASSRCDIR="/fs/system/images/websphere/6.1/linuxppc-64"
     else
        WASSRCDIR="/fs/system/images/websphere/6.1/linuxppc"
     fi
   else
        WASSRCDIR="/fs/system/images/websphere/6.1/linux"
   fi


    SRCDIR="${WASSRCDIR}/supplements"
    RESPDIR="/lfs/system/tools/ihs/responsefiles"


   # removes everything upto IHS- and the trailing /
   BASELEVEL=`echo $VERSION | cut -d"." -f1,2`

   SLEEP=10

   #---------------------------------------------------------------
   # Uninstall previous version
   #---------------------------------------------------------------
   echo "Removing old versions of IHS if they exist"

   echo "Stop Apache if running"
   /lfs/system/tools/configtools/countprocs.sh 2 httpd 
   if [ $? -eq 0 ]; then
      echo "Stopping IHS"
      /etc/apachectl stop 
   else
      echo "IHS is not running"
   fi

   if [ -d $DESTDIR ]
   then
      echo "Removing Previous version of Apache from $DESTDIR"
      if test -f ${DESTDIR}/_uninst/uninstall.jar
      then
         cd ${DESTDIR}/_uninst/
         $JAVA_COMMAND -jar uninstall.jar -silent
      elif test -f ${DESTDIR}/uninstall/uninstall
      then
         cd ${DESTDIR}/uninstall/
         ./uninstall -silent
      else
         echo "No uninstall program exist in $DESTDIR"
      fi

      cd /tmp

      echo "Removing remaining dest dir $DESTDIR contents"
      rm -rf $DESTDIR/*
      rm /opt/.ibm/.nif/.nifregistry

      grep $DESTDIR /etc/fstab  > /dev/null 2>&1
      if [ $? -eq 0 ]; then
         echo "Removing filesystem $DESTDIR"
         #umount $DESTDIR
      fi
   else
      echo "$DESTDIR does not exist -- No previous install detected"
   fi

   HTTPDIR=`echo ${DESTDIR} | cut -d"/" -f3`
   if [ -d /logs/$HTTPDIR ]; then
      echo "Cleaning out global webserver logs from /logs/${HTTPDIR}"
      rm -r /logs/${HTTPDIR}/*
   fi
   echo ""

   #---------------------------------------------------------------
   # Install IHS base
   #--------------------------------------------------------------
   echo "Installing IHS ${BASELEVEL} from $SRCDIR/IHS"
   sleep $SLEEP
   RESPONSEFILE=ihs${BASELEVEL}.base.silent.script
   if [ ! -f ${RESPDIR}/${RESPONSEFILE} ]; then
      echo "File ${RESPDIR}/${RESPONSEFILE} does not exist"
      echo "Use Tivoli SD tools to push /lfs/system/tools/ihs files to this server"
      echo "Exiting..."
      exit 1
   else
      /fs/system/bin/make_filesystem $DESTDIR $IHS_FS_SIZE $VG
      if [[ $? -gt 0 ]]; then
         echo "make filesystem script failed for $DESTDIR "
         echo "   exiting install"
         exit 1
      fi
      mount $DESTDIR
      rm -rf ${DESTDIR}/*
      cp ${RESPDIR}/${RESPONSEFILE} /tmp
      cd /tmp
      sed -e "s%installLocation=.*%installLocation=${DESTDIR}%" ${RESPONSEFILE} > ${RESPONSEFILE}.custom && mv ${RESPONSEFILE}.custom  ${RESPONSEFILE}
      cd $SRCDIR/IHS
      echo "Beginning installation ..."
      ./install -options "/tmp/${RESPONSEFILE}" -silent -is:javaconsole
   fi
   echo "install complete"
   echo ""
 
   FIXLEVEL=`cat ${DESTDIR}/version.signature | awk '{print $4}'`
   echo "IHS version is $FIXLEVEL"
   SDKVERSION=`$DESTDIR/java/jre/bin/java -fullversion 2>&1`
   echo "SDK ${SDKVERSION}"

   echo ""
   echo "Stop Apache if running"
   /lfs/system/tools/configtools/countprocs.sh 2 httpd 
   if [ $? -eq 0 ]; then
      echo "Stopping IHS"
      $DESTDIR/bin/apachectl stop
   else
      echo "IHS is not running"
   fi
   echo ""
  
   #--------------------------------------------------
   # Installing Update installer needed to apply fixes
   #---------------------------------------------------
   if [[ -d $DESTDIR/UpdateInstaller ]]; then
      FIXLEVEL=`cat ${DESTDIR}/UpdateInstaller/version.txt 2>/dev/null | grep Version: | awk {'print $2'}`
      echo "Initial image contains a version of UpdateInstaller"
      echo "UpdateInstaller fixlevel is $FIXLEVEL"
   fi
            
   ${TOOLSDIR}/ihs/setup/install_updateinstaller.sh root=$DESTDIR bits=$BITS version=$FULLVERSION updiVersion=$UPDI_LEVEL toolsdir=$TOOLSDIR

   if [[ $? -gt 0 ]]; then
      SKIPUPDATES=1
   fi

   echo ""

   #------------------------------------------
   # Installing Fixes
   #------------------------------------------
   if [[ $SKIPUPDATES -eq 1 ]]; then
      echo "Install of UpdateInstaller required to install fixes failed"
      echo "Skipping updates"
   else
      ${TOOLSDIR}/ihs/setup/install_ihs_fixes.sh root=$DESTDIR bits=$BITS version=$FULLVERSION toolsdir=$TOOLSDIR
   fi

   #------------------------------------------
   # Summary of install
   #------------------------------------------

   echo ""
   echo "Installation Summary"
   echo "-------------------------------------------"
   echo "IHS installed in $DESTDIR"
   FIXLEVEL=`cat ${DESTDIR}/version.signature | awk '{print $4}'`
   echo "IHS version is $FIXLEVEL"
   SDKVERSION=`${DESTDIR}/java/jre/bin/java -fullversion 2>&1`
   echo "SDK version is ${SDKVERSION}"
   FIXLEVEL=`cat ${DESTDIR}/UpdateInstaller/version.txt| grep Version: | awk {'print $2'}`
   echo "UpdateInstaller version is $FIXLEVEL"
   echo "-------------------------------------------"
   echo ""
}
#---------------------------------------------------------------
# Commands that run on all platforms
#---------------------------------------------------------------

unset JAVA
for java in /usr/bin/java /opt/IBMJava*/bin/java /usr/lib/IBMJava2/jre/bin/java /usr/java14/jre/bin/java /usr/java5/jre/bin/java; do
   test -x "$java"  && $java -fullversion 2>&1 |grep -q IBM && JAVA=$java
done
JAVA_COMMAND=$JAVA

echo "Ensuring /tmp has 500MB in it"
/fs/system/bin/make_filesystem /tmp 500
if [[ $? -gt 0 ]]; then
   echo "The check and possible increase of /tmp failed --- aborting install"
   exit 1
fi

VERSION=`echo ${FULLVERSION} | cut -d"." -f1,2`
if [ $VERSION == 6.1 ]; then
   case `uname` in
          AIX)
            install_ihs_61_aix
          ;;
          Linux)
                install_ihs_61_linux
          ;;
          *)
                print -u2 -- "${0:##*/}: `uname` not supported by this install script."
                exit 1
          ;;
   esac
else
   case `uname` in
          AIX)
                install_ihs_aix
          ;;
          Linux)
                install_ihs_linux
          ;;
          *)
                print -u2 -- "${0:##*/}: `uname` not supported by this install script."
                exit 1
          ;;
  esac
fi

echo "Adding umask statement to apachectl"
sed '
/ARGV\=\"\$\@\"/ i\
umask 027
' ${DESTDIR}/bin/apachectl > ${DESTDIR}/bin/apachectl.new && mv ${DESTDIR}/bin/apachectl.new ${DESTDIR}/bin/apachectl

echo "Setting the apachectl symlink"
rm -f /etc/apachectl
ln -s ${DESTDIR}/bin/apachectl /etc/apachectl

echo "Setting up global log directory"
HTTPDIR=`echo ${DESTDIR} | cut -d"/" -f3`
if [[ ! -d /logs/${HTTPDIR} ]]
then
        echo "Creating /logs/${HTTPDIR}"
        mkdir /logs/${HTTPDIR}
fi

if [[ -d /logs/${HTTPDIR} ]]
then
        echo ""
        echo "Rsync over ${DESTDIR}/logs directory"
        /lfs/system/tools/configtools/filesync ${DESTDIR}/logs/ /logs/${HTTPDIR}/ avc 0 0
        echo "Replace ${DESTDIR}/logs with a symlink to /logs/${HTTPDIR}"
        rm -rf ${DESTDIR}/logs
        ln -s /logs/${HTTPDIR} ${DESTDIR}/logs
fi

echo ""

if [[ ! -d /logs/${HTTPDIR}/UpdateInstaller && -d ${DESTDIR}/UpdateInstaller ]]
then
        echo "UpdateInstaller loaded.  Create /logs/${HTTPDIR}/UpdateInstaller"
        mkdir /logs/${HTTPDIR}/UpdateInstaller
fi

if [[ -d /logs/${HTTPDIR}/UpdateInstaller && -d ${DESTDIR}/UpdateInstaller ]]
then
        echo "Rsync over UpdateInstaller logs"
        /lfs/system/tools/configtools/filesync ${DESTDIR}/UpdateInstaller/logs/ /logs/${HTTPDIR}/UpdateInstaller/ avc 0 0
        echo "Replace ${DESTDIR}/UpdateInstaller/log with a symlink to /logs/${HTTPDIR}/UpdateInstaller"
        rm -rf ${DESTDIR}/UpdateInstaller/logs
        ln -s /logs/${HTTPDIR}/UpdateInstaller ${DESTDIR}/UpdateInstaller/logs 
fi

#---------------------------------------------------------------
# Setup Filesystems
#---------------------------------------------------------------
echo "Setting up /projects filesystem according to the EI standards for an IHS webserver"

case `uname` in
          AIX)

                FS_TABLE="/etc/filesystems"
          ;;

          Linux)
                FS_TABLE="/etc/fstab"
          ;;

   esac

#See if /projects is a link to /www or other wise not a candidate for a
#filesystem change
if [[ -e /projects ]]; then
        ls -ld /projects | grep -e '->' >/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
             echo "/projects is a link.  Leaving it alone"
             ls -ld /projects
        fi
fi
#
if [[ -d /projects ]]; then
        if [[ `ls -l /projects | wc -l` -gt 0 ]]; then
             grep  /projects $FS_TABLE > /dev/null 2>&1
             if [[ $? -eq 0 ]]; then
                echo "/projects exist and is not empty or a filesystem"
                echo "Do nothing"
             else
	        if [ $PROJECT_FS_SIZE -gt 0 ]; then
               echo "Create /projects of size $PROJECT_FS_SIZE mb"
		/fs/system/bin/make_filesystem /projects $PROJECT_FS_SIZE $VG
	        fi
             fi
         else
             if [ $PROJECT_FS_SIZE -gt 0 ]; then
             echo "Create /projects of size $PROJECT_FS_SIZE mb"
             /fs/system/bin/make_filesystem /projects $PROJECT_FS_SIZE $VG
             fi
         fi
else
         if [ $PROJECT_FS_SIZE -gt 0 ]; then
         echo "Create /projects of size $PROJECT_FS_SIZE mb"
         /fs/system/bin/make_filesystem /projects $PROJECT_FS_SIZE $VG
         fi
fi
