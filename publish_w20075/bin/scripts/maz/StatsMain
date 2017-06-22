#!/bin/ksh
# Skeleton script for command-line interface  with bNibmle v2 
# by Mauro Marzorati mauro1@us.ibm.com
# 3/2/2006	Initial Version
#
# DefaultValues
defaultPort="6328"
defaultHost="localhost"
defaultDist="Main"
baseURI="toEI"
localDist="LocalDist"
mainDist=""
defaultFacility="info"
defaultProto="http"
defaultMethod="GET"
defaultAction="version"

doError() {
	errornum=$1 && shift 1
	case ${errornum} in
		usage) cat <<EOF
Usage ${1}  [ -a Action ] [ -d Dist ] [ -f Facility ] [ -h host ] [ -p Port ] [ -P proto ] [ -t ] [arguments]
where
	Action 	(Add|Remove|Delete|Config|Queue|Version|Stats|TargetStatus) (default = ${defaultAction})
	Dist	(Main|Local) (default = ${defaultDist})
	Fac'y	anyvalue (default = ${defaultFacility})
	Host	anyvalue (default = ${defaultHost})
	Port	anyvalue (default = ${defaultPort})
	Proto	(http|https) (default = ${defaultProto})

Naming this program with the an appropriate <Action><Dist> will default those values. The flag can still override.
The Add and Remove or Delete actions will iterate each argument over the action and resulting URL.
The -t flag will do a mock run, ie it tests. 
EOF
;;
		nomethod) print -u2 -- "Unknown method: ${*}";;
		*)	print "Trapping error $errornum, with parameters $*" ;;
	esac


exit 1
}


myName=${0##*/} && myName=${myName%.*} 	# removes dir and extenstion

#Process options
while getopts :p:h:d:P:f:a:t flag; do
	case $flag in 
		p) pFlag=true; userPort=${OPTARG};;
		P) PFlag=true; userProto=${OPTARG};;
		h) hFlag=true; userHost=${OPTARG};;
		d) dFlag=true; userDist=${OPTARG};;
		f) fFlag=true; userFacility=${OPTARG};;
		a) aFlag=true; userAction=${OPTARG};;
		t) tFlag=true;;
		*) doError usage ${0##*/};;
	esac
done
shift $(( ${OPTIND} - 1 ))

#Assign values
Action=${userAction:-${myName}}
Facility=${userFacility:-${defaultFacility}}
Port=${userPort:-${defaultPort}}
Proto=${userProto:-${defaultProto}}
Host=${userHost:-${defaultHost}}
case $myName in
	*Local)	Dist=${userDist:-Local};;
	*Main)	Dist=${userDist:-Main};;
	*)	Dist=${userDist:-${defaultDist}};;
esac
Method=${defaultMethod}
case ${Action} in
	Add*)	unset Action;  Method="POST" ; Args=$*; verb=ADD;;
	Remove*|Delete*) unset Action; Method="POST" ; Args=$* ; verb=REMOVE;;
	Config*)	Query=config;;
	Queue*)		Query=queue;;
	Version*)	Query=version;;
	Stats*)		Query=stats;;
	TargetStatus*)	Query=TargetStatus;;
	*)		Query=${myName%${Dist}};;
esac
	

# Local or Main context to the URI
case ${Dist} in 
	Local)	URI=${baseURI}${localDist}  ;;
	Main)	URI=${baseURI}${mainDist}  ;;
	*)	URI=${baseURI} ;;
esac

# Build the target URL
URL="${Proto}://${Host}:${Port}/${URI}/${Facility}${Query:+"?"}${Query}" 

# Process the URL and argsuments
case ${Method} in
	POST)
		for arg in ${Args}; do
			print -- Performing ${tFlag:+"mock "}${verb} of ${arg} on URL=${URL}
			[ "${tFlag}" ] && echo curl --data \"${verb} ${arg}\" --url ${URL} || curl --data "${verb} ${arg}" --url ${URL}
		done ;;
	GET)
		print -- Performing ${tFlag:+"mock "}${Action} with URL=${URL}
		[ "${tFlag}" ] && echo curl --url ${URL} || curl --url ${URL}
	;;
	*)	doError nomethod ${Method};;
esac

exit 0

URL to name pattern
http://localhost:6328/toEI/				AddMain
http://localhost:6328/toEILocalDist/			AddLocal
http://localhost:6328/toEI/				RemoveMain
http://localhost:6328/toEILocalDist/			RemoveLocal
http://localhost:6328/toEI/info?config			ConfigMain
http://localhost:6328/toEILocalDist/info?config		ConfigLocal
http://localhost:6328/toEI/info?queue			QueueStatusMain
http://localhost:6328/toEILocalDist/info?queue		QueueStatusLocal
http://localhost:6328/toEI/info?version			VersionMain
http://localhost:6328/toEILocalDist/info?version	VersionLocal
http://localhost:6328/toEI/info?stats			StatsMain
http://localhost:6328/toEILocalDist/info?stats		StatsLocal
http://localhost:6328/toEI/info?TargetStatus		TargetStatusMain
http://localhost:6328/toEILocalDist/info?TargetStatus	TargetStatusLocal

