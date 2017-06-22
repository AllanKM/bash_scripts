#!/usr/bin/ksh 

#
# mksitetxt_apps.ksh: Script to create site.txt for the specified event
#			and push to appropriate directory
#
# carolami 3/20/06:  added chown pubinst.apps to original mksitetxt.ksh
# todds    8/20/07:  Will continue by redoing this copy since our leader
#                    strted this one

echo "Setting umask"
umask 002

# Default values
EVENT="HTTPServer"
SITENAME=""

# Process command-line options
until [ -z "$1" ] ; do
        case $1 in
                site=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then EVENT=$VALUE; fi ;;
                name=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SITENAME=$VALUE; fi ;;
                *)      print -u2 -- "#### Unknown argument: $1"
                        print -u2 -- "#### Usage: $0 [ site=< site name > ] [ name=< long site name > ]"
                        exit 1
                        ;;
        esac
        shift
done

if [[ ! -f /etc/apachectl ]]; then
  echo "/etc/apachectl not found. Please ensure IHS has been installed"
  echo "Exiting..."
  exit 1
elif [[ -h /etc/apachectl ]]; then
  HTTPDIR=`ls -al /etc/apachectl | cut -d">" -f2 | cut  -d"/" -f3`
  DESTDIR=`ls -al /etc/apachectl | cut -d">" -f2 | cut  -d"/" -f1-3| sed 's/ //g'`
fi

if [[ $SITENAME == "" && $EVENT != "HTTPServer" ]]; then
  echo "Most specify sitename"
  exit 2
fi 
 
global_server ()
{
  if [[ ! -f /projects/${HTTPDIR}/content/site.txt ]]; then 
    echo "Create global server site.txt"
    echo "Global HTTPServer on `hostname -s`" > /projects/HTTPServer/content/site.txt
    echo "Virtualhost list:" >> /projects/HTTPServer/content/site.txt
  fi
  if [[ ! -h /projects/${HTTPDIR}/content/sslsite.txt ]]; then
    echo "Creating sslsite.txt link"
    ln -s site.txt /projects/${HTTPDIR}/content/sslsite.txt
  fi
}

virtualhost ()
{
  if [[ ! -f /projects/${EVENT}/content/site.txt ]]; then
    echo "Create $EVENT site.txt"
    echo "${SITENAME}" > /projects/${EVENT}/content/site.txt
  fi

  if [[ ! -h /projects/${EVENT}/content/sslsite.txt ]]; then
    echo "Creating sslsite.txt link"
    ln -s site.txt /projects/${EVENT}/content/sslsite.txt
  fi

  if [[ -f /projects/${HTTPDIR}/content/site.txt ]]; then
    cat /projects/${HTTPDIR}/content/site.txt | grep "${SITENAME}" > /dev/null 2>&1
    if [[ $? -gt 0 ]]; then
      echo "Updating Global Server site.txt"
      echo "  ${SITENAME}" >> /projects/HTTPServer/content/site.txt
      sed '/^ \{2\}/d' /projects/HTTPServer/content/site.txt > /projects/HTTPServer/content/site_tmp.txt
      sed -n '/^ \{2\}/p' /projects/HTTPServer/content/site.txt | sort >> /projects/HTTPServer/content/site_tmp.txt
      cp /projects/HTTPServer/content/site_tmp.txt /projects/HTTPServer/content/site.txt
      rm /projects/HTTPServer/content/site_tmp.txt
      /lfs/system/tools/ihs/setup/vhost_perms.sh
    fi
  fi
}

if [[ $EVENT == "HTTPServer" ]]; then
   global_server
else
   virtualhost
fi
