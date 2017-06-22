#!/bin/bash
# Query, delete, reload, create, and generally manage Solr
# 01-Jul-2013 | James Walton <jfwalton@us.ibm.com>
#
# Usage: solr.sh core=<name> [cluster=<name>] [role=WAS.ROLE] [scope=local|all|pp(1,2,3,5)|s(1-7)] (query='string' [count=<num>] | delete='type:string' | deleteall | create | reload | status)
# Defaults: cluster=wwsm_search4 scope=local count=10
# For WLP use: cluster=wlp

# Set defaults
SOLRWAS="wwsm_search4"
HOST=`hostname`
COUNT=10
LFSTOOLS="/lfs/system/tools"
case `uname` in
	"AIX") CURL="curl -s";;
	"Linux") CURL="curl -s -k";;
esac
# Process command-line opts
until [ -z "$1" ] ; do
	case $1 in
		cluster=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SOLRWAS=$VALUE; fi ;;
		core=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then CORE=$VALUE; fi ;;
		role=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then ROLE=$VALUE; fi ;;
		scope=*|site=*|plex=*)	VALUE=${1#*=}; if [ "$VALUE" != "" ]; then SCOPE=$VALUE; fi ;;
		count=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then COUNT=$VALUE; fi ;;
		query=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then QUERY=$VALUE; fi
			ACTION="query" ;;
		delete=*) VALUE=${1#*=}; if [ "$VALUE" != "" ]; then DELETE=$VALUE; fi
			ACTION="delete" ;;
		"deleteall") ACTION="delete"; DELETE="'*:*'" ;;
		"create") ACTION=$1 ;;
		"reload") ACTION=$1 ;;
		"status") ACTION=$1 ;;
		*)	echo "### Error: Unknown argument: $1"
			echo "Usage: ${0##*/} core=<name> [cluster=<name>] [role=WAS.ROLE] [scope=local|all|p(1,2,3,5)|s(1-7)] (query='string' [count=<num>] | delete='type:string' | create | reload | status)"
			echo "Defaults: cluster=wwsm_search4 scope=local count=10"
			exit 1 ;;
	esac
	shift
done

if [[ -z $CORE && $ACTION != "status" ]]; then echo "### Error: Solr core name required. (core=name)"; exit 1; fi
if [[ $SOLRWAS == "wlp" && $ACTION == "create" ]]; then echo "### Error: Do NOT create new cores manually on Chef-managed WLP nodes."; exit 1; fi

# Get clientauth info
zone=`lssys -x csv -l realm -n |tail -1 |awk '{split($0,r,","); split(r[2],z,"."); print z[1]"z"}'`
certfile="${LFSTOOLS}/was/etc/ei.${zone}.was.client.pem"
encpass=`grep clientauth_${zone} ${LFSTOOLS}/was/etc/was_passwd`
encpass=${encpass#*${zone}=}
dcpass=`openssl enc -base64 -d <<< $encpass`
CURL="$CURL --cert $certfile --pass $dcpass"

# Pull node list
case $SCOPE in
	p[1235]|s[1-7]) NODELIST=`lssys -qe role==${ROLE} realm==*.${SCOPE}` ;;
	"all") NODELIST=`lssys -qe role==${ROLE}` ;;
	*) NODELIST=$HOST;;
esac
NODEGREP=`echo $NODELIST |tr ' ' '|'`

# Get Solr application server ports
case $SOLRWAS in
	"wlp") for n in $NODELIST; do SOLRLIST="${n}:9045 $SOLRLIST"; done ;;
	*) SOLRLIST=`${LFSTOOLS}/was/bin/portreport.sh |egrep "($NODEGREP)" |grep $SOLRWAS |grep 'WC_.*secure' |awk '{split($0,s,","); print s[2]":"s[5]}'` ;;
esac

for SOLRINST in $SOLRLIST; do
	case $ACTION in
		"create")
			echo "===================================================================================================="
			echo "CREATING Solr core: $CORE  (${SOLRINST}) :  /projects/events/solr/${CORE}"
			echo "===================================================================================================="
			echo -n "Continue with creation? (y|N) "; read confq
			case $confq in
				y|Y) $CURL "https://${SOLRINST}/slsearch/admin/cores?action=CREATE&name=${CORE}&instanceDir=/projects/events/solr/${CORE}&wt=json"
			esac ;;
		"delete")
			echo "===================================================================================================="
			echo "DELETING from Solr core: $CORE  (${SOLRINST}) : ${DELETE}"
			echo "===================================================================================================="
			echo "!!!!! This will delete ALL items from the index matching your query, so be absolutely certain !!!!!"
			echo -n "Continue with deletion? (y|N) "; read confq
			case $confq in
				y|Y) $CURL "https://${SOLRINST}/slsearch/${CORE}/update?stream.body=<delete><query>${DELETE}</query></delete>&commit=true&wt=json"
			esac ;;
		"reload")
			echo "==========================================================="
			echo "RELOADING Solr core: $CORE (${SOLRINST})"
			echo "==========================================================="
			$CURL "https://${SOLRINST}/slsearch/admin/cores?action=RELOAD&core=${CORE}&wt=json" ;;
		"status")
			echo "================================================="
			echo "STATUS Query"
			if [[ -n $CORE ]]; then
				echo "Solr core: $CORE (${SOLRINST})"
				echo "================================================="
				$CURL "https://${SOLRINST}/slsearch/admin/cores?action=STATUS&core=${CORE}&wt=json&indent=on&omitHeader=true"
			else
				echo "ALL Solr cores... (${SOLRINST})"
				echo "================================================="
				$CURL "https://${SOLRINST}/slsearch/admin/cores?action=STATUS&wt=json&indent=on&omitHeader=true"
			fi ;;
		"query")
			echo "======================================================================================================"
			echo "QUERYING Solr core: $CORE  (${SOLRINST}) : $QUERY : Top $COUNT results"
			echo "======================================================================================================"
			xmlout=`$CURL "https://${SOLRINST}/slsearch/${CORE}/select?q=${QUERY}&fl=url&start=0&rows=${COUNT}"`
			xmlout=$(echo $xmlout |sed -e "s/></>\\`echo -e '\n\r'`</g")
			num=`echo $xmlout |perl -ne '$_ =~ s/.*<result name="response" numFound="(.*?)".*/$1/g;print $_ unless $_ =~ /</;'`
			echo "Results: $num"; echo "URLs: $urls"
			for line in $xmlout; do
			   echo $line |grep '^name=\"url\"' 2>&1 > /dev/null
			   if [ $? -eq 0 ]; then echo $line |awk '{split($0,a,">"); split(a[2],b,"<"); print "   "b[1]}'; fi
			done
	esac
	echo
done
