#!/bin/ksh

# Default Values
TOOLSDIR=/lfs/system/tools
CUSTTAG="edr"

#process command-line options
until [ -z "$1" ] ; do
        case $1 in
                custtag=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTTAG=$VALUE; fi ;;
                env=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CUSTENV=$VALUE; fi ;;
                *)      print -u2 -- "#### Unknown argument: $1"
                        print -u2 -- "#### Usage: $0 [ custtag=< Customer > ] [ env =< Environment for this install > ]"
                        exit 1
                        ;;
        esac
        shift
done

config_dir=/etc/${CUSTTAG}_raddb
chmod 2750  $config_dir
find $config_dir -type d | xargs -I {} sudo chmod 2750 {}
find $config_dir -type f | xargs -I {} sudo chmod 640 {}
chown -R radiusd:radiusd $config_dir
chown radiusd:radiusd /logs/radiusd

