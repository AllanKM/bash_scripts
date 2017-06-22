#!/bin/ksh

#---------------------------------------------------------------
# MQ install.
#---------------------------------------------------------------

# USAGE: install_mq.sh [client|server] [VERSION]

# Will this be a client or server install?
TYPE=${1:-CLIENT}
# Convert to upper case
typeset -u TYPE


#What version of MQ will be installed
if [ "$TYPE" == "CLIENT" ]; then
        FULLVERSION=${2:-6.0.2.3}
else
        FULLVERSION=${2:-6.0.2.3}
fi

VERSION=`echo $FULLVERSION | cut -c1-2`
FIXLVL=`echo $FULLVERSION | cut -d. -f2`

install_mq_aix ()
{
    chgrpmem -m = webinst,mqm mqm
    chgrpmem -m = webinst,mqm mqbrkrs
    chuser pgrp=mqm groups=mqm,apps,mqbrkrs webinst

        case "$VERSION" in
        6.|60)  SRCDIR="/fs/system/images/websphere/mq/6.0/aix/server"
                FIXDIR="/fs/system/images/websphere/mq/6.0/aix/fp${FULLVERSION}"
                CLIENT_FILESETS="mqm.base mqm.client mqm.keyman mqm.man.en_US.data mqm.java.rte"
                ;;
        53) SRCDIR="/fs/system/images/websphere/mq/5.3.0.x/aix/server"
        FIXDIR="/fs/system/images/websphere/mq/5.3.0.x/aix/fixes/fp${FIXLVL}"
        CLIENT_FILESETS="mqm.base mqm.client mqm.keyman mqm.man.en_US.data mqm.java.rte mqm.Client.Bnd"
        ;;
    *)  echo "Not configured to install $VERSION"
        exit 1
        ;;
        esac

    case "$TYPE" in
        CLIENT)
                echo "Installing MQ Client from $SRCDIR"
                        sleep 3
                        cd $SRCDIR

                        installp -acgXYd ./ $CLIENT_FILESETS

                        echo "install complete"
                        echo "Applying MQ fix pack ${FIXLVL}"
                        cd $FIXDIR && /usr/lib/instl/sm_inst installp_cmd -a -d $FIXDIR -f '_update_all' '-c' '-N' '-g' '-X'
        ;;
        SERVER)
                lslpp -l OpenGL.OpenGL_X.rte.base > /dev/null 2>&1
                        if [ $? -ne 0 ]; then
                        echo "Installing OpenGL prerequisite"
                                case `oslevel` in
                                        6.1*) installp -acgXYd /fs/system/images/aix/610/installp/ppc OpenGL.OpenGL_X.rte X11.fnt.ucs && /usr/lib/instl/sm_inst installp_cmd -a -d /fs/system/images/aix/610/tl0 -f _update_all -c -N -g -X;;
                                        5.3*) installp -acgXYd /fs/system/images/aix/530/installp/ppc OpenGL.OpenGL_X.rte X11.fnt.ucs && /usr/lib/instl/sm_inst installp_cmd -a -d /fs/system/images/aix/530/tl5 -f _update_all -c -N -g -X;;
                                        5.2*) installp -acgXYd /fs/system/images/aix/520/lppsource OpenGL.OpenGL_X.rte X11.fnt.ucs && /usr/lib/instl/sm_inst installp_cmd -a -d /fs/system/images/aix/520/tl9 -f _update_all -c -N -g -X;;
                                                *)  echo "Update $0 to recognize this level of AIX"
                                                        echo "exiting..."
                                                        exit 1
                                                        ;;
                                esac
                                lslpp -l OpenGL.OpenGL_X.rte.base > /dev/null 2>&1
                                if [ $? -ne 0 ]; then
                                                echo "Failed to install OpenGL prerequisite"
                                                echo "exiting...."
                                                exit 1
                                fi
                        fi
                        echo "Installing MQ Filesets from $SRCDIR"
                        sleep 3
                        cd $SRCDIR
                        installp -acgXYd ./ mqm.base mqm.client mqm.keyman mqm.java.rte mqm.msg.en_US mqm.man.en_US mqm.server mqm.txclient.rte gsksa.rte Java14
                echo "Applying MQ fix pack ${FIXLVL}"
                        cd $FIXDIR && /usr/lib/instl/sm_inst installp_cmd -a -d $FIXDIR -f '_update_all' '-c' '-N' '-g' '-X' '-Y'
                        su - mqm -c "setmqcap 4"
                ;;
        *)
                        echo "Don't know how to perform a $TYPE install on AIX"
                        exit 1
                ;;
    esac
}

install_mq_linux ()
{

    /usr/sbin/usermod -g mqm -G mqm,apps,mqbrkrs webinst

        case "$VERSION" in
        6.|60)  SRCDIR="/fs/system/images/websphere/mq/6.0/linux/server"
                FIXDIR="/fs/system/images/websphere/mq/6.0/linux/fp${FULLVERSION}"
                ;;
        53) SRCDIR="/fs/system/images/websphere/mq/5.3.0.x/linux/server"
        FIXDIR="/fs/system/images/websphere/mq/5.3.0.x/linux/fixes/fp${FIXLVL}"
        ;;
    *)  echo "Not configured to install $VERSION"
        exit 1
        ;;
        esac

    case "$TYPE" in
    CLIENT)
                echo "Installing MQ Client from $SRCDIR"
                sleep 3
                cd $SRCDIR
                rpm -ivh MQSeriesRuntime*rpm  MQSeriesClient*rpm MQSeriesKeyMan*rpm MQSeriesJava*rpm MQSeriesMan*rpm

                echo "install complete"
                echo "Applying MQ fix pack ${FIXLVL}"
                cd $FIXDIR
                rpm -Uvh MQSeriesRuntime  MQSeriesClient MQSeriesKeyMan MQSeriesJava MQSeriesMan
        ;;
    *)
        echo "$TYPE support for Linux has not beed added to this script"
                echo "exiting ... "
                exit 1
        ;;
     esac

}
if [[ $SUDO_USER == "" ]]; then
  echo "Please run as \"sudo\""
  exit 1
fi
#---------------------------------------------------------------
# Commands that run on all platforms
#---------------------------------------------------------------

#---------------------------------------------------------------
# Check if MQ is already installed
#---------------------------------------------------------------
su - mqm -c "/usr/bin/dspmqver" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "MQ is already installed. Exiting..."
    exit 1
fi


#---------------------------------------------------------------
# IDs
#---------------------------------------------------------------

id mqm > /dev/null 2>&1
if [  $? -ne 0 ]; then
    /fs/system/tools/auth/bin/mkeigroup -r local -f mqm
    /fs/system/tools/auth/bin/mkeiuser  -r local -t sys -n 69 -f mqm mqm /var/mqm
    /fs/system/tools/auth/bin/mkeigroup  -r local -f mqbrkrs
fi

id webinst > /dev/null 2>&1
if [  $? -ne 0 ]; then
    /fs/system/tools/auth/bin/mkeigroup -r local -f apps
    /fs/system/tools/auth/bin/mkeiuser  -r local -f webinst apps
fi

id pubinst > /dev/null 2>&1
if [  $? -ne 0 ]; then
    /fs/system/tools/auth/bin/mkeiuser  -r local -f pubinst apps
fi


#---------------------------------------------------------------
# Setup /var/mqm
#---------------------------------------------------------------
if [ -f /var/mqm/.profile ]; then
    cp -p /var/mqm/.profile /tmp
fi

if lsvg appvg >/dev/null 2>&1; then
        VG=appvg
else
        VG=rootvg
fi

case "$TYPE" in
CLIENT)
    /lfs/system/tools/configtools/make_filesystem /var/mqm 50 $VG
    ;;
SERVER)
    /lfs/system/tools/configtools/make_filesystem /var/mqm 2048 $VG
    ;;
esac

if [[ -f /tmp/.profile ]]; then
    cp -p /tmp/.profile /var/mqm/.profile
fi

chown -R mqm:mqm /var/mqm

case `uname` in
        AIX)
                install_mq_aix

        ;;
        Linux)
                install_mq_linux

        ;;
        *)
                print -u2 -- "${0:##*/}: `uname` not supported by this install script."
                exit 1
        ;;
esac

#---------------------------------------------------------------
# Validate Installation was successful
#---------------------------------------------------------------

echo
echo
echo "Checking installation version..."
su - mqm -c "/usr/bin/dspmqver" | grep Version
if [ $? -ne 0 ]; then
        echo "Failed to install MQ client.  Exiting..."
        exit 1
else
        echo "MQ install finished"
fi

