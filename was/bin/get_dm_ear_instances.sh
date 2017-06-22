#!/bin/sh
host=`hostname`
excludes=`lssys -q -e role==was.dm.*cdt*`
excludes="$excludes gt0206a at0702a"
for EXCLUDE in $excludes; do
 if [[ "$host" = "$EXCLUDE" ]] ; then
	echo "$host excluded"
	 exit
 fi
done

indexes=`find /usr/ -name "serverindex.xml" | grep "config/cells" | grep -iE "profiles|Deploymentmanager"`
if [ ! -z "$indexes" ]; then
   for index in $indexes; do
		was=`echo $index | awk -F"/" '{print $(NF-1)}'`
      case $was in
              *e0)
                  was=`echo $was | sed "s/e0$/e1/"`
                      ;;
              [adg][ct][0-9][0-9][0-9][0-9]?e1)
                  was=`echo $was | sed "s/e1$//"`
                      ;;
              rdu*|stl*|den*)
                   was="${was}e1"
                      ;;
      esac

		cust=`lssys -l custtag $was | grep -i custtag | awk '{print $3}'`
		dmgr=`echo $index | awk -F"/" '{print $(NF-3)}'`
		case $index in
			*manager*)
			;;
			*)
				deploys=`grep -i deployedapplications $index | awk -F ">" '{print $2}' | awk -F"/" '{print $1}'`
				for ear in $deploys; do
					echo "${host};${dmgr};${was};${cust};${ear}"
				done 
			;;
      esac 
	done
else
	echo $host no deployment manager dirs found
fi

