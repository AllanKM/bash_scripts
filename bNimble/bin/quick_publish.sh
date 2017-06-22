#!/bin/ksh

#-----------------------------------------------------
# quick_publish.sh
# Discription - Command to do manual publish
#=====================================================
# History
#    01/29/2008 - Todd Stephens - Took script from bj
#                    and modified it to be more
#                    generic
#    09/12/2008 - Todd Stephens - Fixed bug where it
#                    allows you to publish files 
#                    outside of pubroot
#    06/22/2010 - Todd Stephens - updated java default
#-----------------------------------------------------

#
# Set trap for cntl c
#

trap 'echo "Publish aborted"; rm /tmp/pubthis.$$; exit 0' 1 2 15
 
#
# Define functions
#

command_syntax ()
{
	echo ""
	echo "USAGE: "
	echo "  quick_publish.sh [-d] [-p] [-r] [-n] -c <pub_config> <file|dir>"
        echo ""
	echo "      Debug:                -d"
        echo "      Publish:              -p"
        echo "      Recursive Pub:        -r"
	echo "      Files since last pub: -n"
        echo "      Publishing config :   -c <...>"
	echo ""
	exit 2
} 

#
# Define defaults
#

PROMPT=1
RECURSIVE=0
NEWER=0
JAVA="/usr/java5/bin/java"
SITE=""
URL=""
PUBROOT=""
USE_SSL="No"
TRUSTSTORE=""
KEYSTORE=""
TRUSTPASS=""
KEYPASS=""
PUBFILE="/tmp/pubthis.$$"
USER=""
HTTP_METHOD="http"
DEBUG=0
FIND_FLAGS=""


#
# Process commandline
#

while getopts dprnc: option
do
	case $option in
		d)         DEBUG=1 ;;
		p)         PROMPT=0 ;;
		r)         RECURSIVE=1 ;;
		n)         NEWER=1 ;;
		c)         CONFIG_PARAM="$OPTARG" ;;
		?)         command_syntax ;;
	esac
done

shift $(($OPTIND -1))

#
# Ensure config path includes .conf
#

CONFIGSTRIPPED=`echo $CONFIG_PARAM | sed s/\.conf$//`
CONFIGEXT=.conf
FULL_CONFIGFILE=${CONFIGSTRIPPED}${CONFIGEXT}

#
# Check that the config file exist
#

if [ ! -f $FULL_CONFIGFILE ] ; then
	echo "Config file does not exist"
	exit 1
fi

#
# Read in config file
#

for i in `cat $FULL_CONFIGFILE                      \
             | grep -v "[[:space:]]*#"              \
             | sed 's/^[[:space:]][[:space:]]*//g'  \
             | sed 's/[[:space:]][[:space:]]*/%%/g'`
do
	PARM=`echo $i | awk -F%% '{print $1}'`
        VAL=`echo $i | awk -F%% '{print $2}'`

	case $PARM in
		SITE)            SITE=$VAL ;;
                URL)             URL="$VAL" ;;
                JAVA)            JAVA=$VAL ;;
                PUBROOT)         PUBROOT=$VAL ;;
                USE_SSL)         USE_SSL=$VAL ;;
                TRUSTSTORE)      TRUSTSTORE=$VAL ;;
                KEYSTORE)        KEYSTORE=$VAL ;;
		USER)            USER=$VAL ;;
	esac
done

#
# Check that all is provided
#

if [[ $SITE == "" || $URL == "" || PUBROOT == "" || $JAVA == "" || $USER == "" ]]; then
	echo "Inproperly formatted configfile"
	exit 3
fi

if [[ ! -f $JAVA ]]; then
	echo "Specified java command not found"
	exit 3
fi

if [[ ! -d $PUBROOT ]]; then
	echo "Specified PUBROOT not found"
	exit 3
fi

if [ $# -eq 1 ]; then 
	PUBTHIS=$1
else 
	command_syntax
fi

#
# Process viables if using ssl
#

if [[ $USE_SSL == "true" ]]; then
	set -- $(grep search /etc/resolv.conf)

	while [[ "$1" != "" ]]; do
        	if [[ "$1" = [bgy].*.p?.event.ibm.com ]]
         	then
                	ENV=`echo "$1" | cut -d. -f1`
        	fi
    		shift
	done
	
	if [[ $TRUSTSTORE == "" ]]; then
		TRUSTSTORE="/lfs/system/tools/bNimble/etc/ei_${ENV}z_pubtool_shared.jks"
	fi

	if [[ $KEYSTORE == "" ]]; then
                KEYSTORE="/lfs/system/tools/bNimble/etc/ei_${ENV}z_pubtool_shared.jks"
        fi

	if [ -f /home/${USER}/.publish ]; then
		KEYSTORENAME=`echo $KEYSTORE | awk -F "/" {'print $NF'}`
		TRUSTSTORENAME=`echo $TRUSTSTORE | awk -F "/" {'print $NF'}`

		if [[ $KEYSTORENAME == [a-zA-Z_]*.jks ]]; then
			KEYPASS=`cat /home/${USER}/.publish | grep -F " $KEYSTORENAME " | awk {'print $NF'}`
		fi

		if [[ $TRUSTSTORENAME  == [a-zA-Z_]*.jks ]]; then
			TRUSTPASS=`cat /home/${USER}/.publish | grep -F " $TRUSTSTORENAME "| awk {'print $NF'}`
		fi

		if [[ ! -f $TRUSTSTORE || ! -f $KEYSTORE || $TRUSTPASS == "" || $KEYPASS == "" ]]; then
			echo "SSL Parameters are not properly initialized"
			echo "Check config and the $USER .publish file"
			exit 3
		fi
	else
		echo "$USER .publish file not found"
		exit 3
	fi

	CERT_FLAGS="-Djavax.net.ssl.trustStore=$TRUSTSTORE -Djavax.net.ssl.trustStorePassword=$TRUSTPASS -Djavax.net.ssl.keyStore=$KEYSTORE -Djavax.net.ssl.keyStorePassword=$KEYPASS"

	HTTP_METHOD="https"

fi

#
# Construct the publish command
#

BPUT="$JAVA -Xmx256M $CERT_FLAGS -jar /lfs/system/tools/bNimble/lib/Transmit.jar -u ${HTTP_METHOD}://$URL -e $SITE -t 2 -r"

#
# Output variable values in debug mode
#

if [[ $DEBUG == 1 ]]; then
	echo "PROMPT=$PROMPT"
	echo "RECURSIVE=$RECURSIVE"
	echo "NEWER=$NEWER"
	echo "JAVA=$JAVA"
	echo "SITE=$SITE"
	echo "URL=$URL"
	echo "PUBROOT=$PUBROOT"
	echo "USE_SSL=$USE_SSL"
	echo "TRUSTSTORE=$TRUSTSTORE"
	echo "KEYSTORE=$KEYSTORE"
	echo "TRUSTPASS=$TRUSTPASS"
	echo "KEYPASS=$KEYPASS"
	echo "BPUT=$BPUT"
fi


#
# Determine list of files to publish
#

PUBTHIS=${PUBTHIS#${PUBROOT}}
PUBTHIS=${PUBTHIS#/}
if [[ $DEBUG == 1 ]]; then
        echo "PUBTHIS=$PUBTHIS"
fi

if [[ $RECURSIVE == 0 ]]; then
	FIND_FLAGS="-prune "
fi

if [[ $NEWER == 1 && -f /home/${USER}/.lastpub ]]; then
	FIND_FLAGS="${FIND_FLAGS} -newer /home/${USER}/.lastpub "
fi

cd $PUBROOT
if [[ -d ${PUBTHIS} ]]; then
	find ${PUBTHIS}/* $FIND_FLAGS -type f -print > $PUBFILE
elif [[ -f ${PUBTHIS} ]]; then
	echo ${PUBTHIS} > $PUBFILE
else
	echo "File/Dir ${PUBROOT}/${PUBTHIS} was not found"
	exit 4
fi

if [[ `cat $PUBFILE | wc -l` -gt 0 ]]; then
	echo ""
	echo "File list:"
	cat $PUBFILE
else
	echo "Found nothing to publish"
	exit 0
fi

if [[ $DEBUG == 0 ]]; then
	echo ""
	echo "About to publish file(s) listed above."
	if [ $PROMPT -eq 1 ]; then
		echo "<enter> to continue, ctrl-c to exit:"
		read
	fi
else
	exit 0
fi

#
# Publish
#

echo ""
echo "Begin Publishing"
cat $PUBFILE | $BPUT
echo "Publishing Complete"

rm -f $PUBFILE

touch /home/${USER}/.lastpub

