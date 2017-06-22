#!/bin/ksh

###################################################################
#
#  validate_httpd_v2.sh -- performs simple validation steps on
#                          config files
#
#------------------------------------------------------------------
#
#  Steve Farrell - Unknown    - Initial version
#  Todd Stephens - 06/03/2013 - Revamped to take arguments to
#                                 pave the way to do shared IHS
#
###################################################################

# Default values
LIB_HOME="/lfs/system/tools"
SITETAG="HTTPServer"
typeset -l DEBUG=false DETAILS=false

#process command-line options
until [[ -z "$1" ]] ; do
  case $1 in
    sitetag=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SITETAG=$VALUE; fi ;;
    details=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DETAILS=$VALUE; fi ;;
    debug=*)  VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DEBUG=$VALUE; fi ;;
    *)  print -u2 -- "#### Unknown argument: $1"
        print -u2 -- "#### Usage: ${0:##*/}: "
        print -u2 -- "####       [ sitetag = < sitetag of site > ]"
        print -u2 -- "####       [ details = < true or false > ]"
        print -u2 -- "####       [ debug = < true or false > ]"
        print -u2 -- "#### ---------------------------------------------------------------------------"
        print -u2 -- "####       Defaults:"
        print -u2 -- "####           sitetag = HTTPServer"
        print -u2 -- "####           details = false"
        print -u2 -- "####           debug   = false"
        exit 1
      ;;
  esac
  shift
done 

if [[ $DEBUG != "true" && $DEBUG != "false" ]]; then
   echo "Parameter debug needs a value of \"true\" or \"false\""
   exit 1
fi

if [[ $DETAILS != "true" && $DETAILS != "false" ]]; then
   echo "Parameter details needs a value of \"true\" or \"false\""
   exit 1
fi
 
# Check if plugin-cfg.xml is good 
${LIB_HOME}/ihs/bin/highlight.pl "Performing WebSphere Plugin Advanced XML Verification" SUBHEADER; echo
echo ""

if [[ $SITETAG = HTTPServer* ]]; then
  ihs_cluster=$(lssys -1 -l role -n | awk '{
                                        for (i=1;i<=NF;i++) {
                                          if ( $(i)~/^WEBSERVER\.CLUSTER\.[A-Z0-9]+$/ ) { 
                                            print $(i); 
                                            break 
                                          }
                                          if ( $(i)~/^CHEF\.CLIENT$/ ) {
                                            print "--no-dirstore";
                                            break
                                          }
                                        }
                                      }')
else
  ALLCAPSITETAG=$( echo $SITETAG | tr '[:lower:]' '[:upper:]' )
  SHORTHOST=`/bin/hostname -s`
  service_host=`lssys -q -e eihostname==${SHORTHOST} role==webserver.${SITETAG}.*`
  if [[ $service_host != "" ]]; then
    ihs_cluster=$(lssys -1 -l role $service_host | awk -v sitetag="^WEBSERVER.${ALLCAPSITETAG}.*Z$" '{
                                                     for (i=1;i<=NF;i++) {
                                                       if ( $(i)~sitetag ) {
                                                         print $(i); 
                                                         break
                                                       }
                                                     }
                                                   }')
  fi
fi

if [[ $DEBUG == "true" ]]; then
  saved_debug_value="echo $debug"
  debug=1
  export debug
fi

if [[ $DETAILS == "true" ]]; then
  saved_details_value="echo $details"
  details=1
  export details
fi

if [[ $DEBUG == "true" ]]; then
  echo "ihs_cluster is $ihs_cluster"
fi

if [[ ! -z "$ihs_cluster" ]]; then
  cd /projects/${SITETAG}/conf
  ${LIB_HOME}/was/bin/verify_plugin.pl plugin-cfg.xml $ihs_cluster
  verify_plugin_rc=$?
  if [[ $debug != "" ]]; then
    if [[ $saved_debug_value != "" ]]; then
      debug=$saved_debug_value
      export $debug
    else
      unset $debug
    fi
  fi
  if [[ $details != "" ]]; then
    if [[ $saved_details_value != "" ]]; then
      details=$saved_details_value
      export $details
    else
      unset $details
    fi
  fi
  if [[ $verify_plugin_rc -gt 0 ]]; then
    echo "  ////////////////////////////////"
    print "  ////\c"
    ${LIB_HOME}/ihs/bin/highlight.pl "  Verification Failed   " ERROR
    print "////"
    echo "  ////////////////////////////////"
    echo ""
    exit 8
  else
    echo "  ////////////////////////////////"
    print "  ////\c"
    ${LIB_HOME}/ihs/bin/highlight.pl " Verification Completed " GOLDEN
    print "////"
    echo "  ////////////////////////////////"
    echo ""
    exit 0
  fi
else
  if [[ $DEBUG = "true" || $DETAILS = "true" ]]; then 
    print "  Extended verification of plugin not performed"
    if [[ $ihs_cluster == "" ]]; then
      print "    Error: Server is missing a suitable webserver role"
    fi
    echo ""
  fi
  if [[ $debug != "" ]]; then
    if [[ $saved_debug_value != "" ]]; then
      debug=$saved_debug_value
      export $debug
    else
      unset $debug
    fi
  fi
  if [[ $details != "" ]]; then
    if [[ $saved_details_value != "" ]]; then
      details=$saved_details_value
      export $details
    else
      unset $details
    fi
  fi
  echo "  ////////////////////////////////"
  print "  ////\c"
  ${LIB_HOME}/ihs/bin/highlight.pl "  Verification Failed   " ERROR
  print "////"
  echo "  ////////////////////////////////"
  echo ""
  exit 8
fi
