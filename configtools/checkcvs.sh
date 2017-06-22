#!/bin/bash

function checkrole() {
   # check role is assigned in dirstore
   if ! dsls role $1 | grep -i $1 >/dev/null 2>&1 ; then
      echo -e  "$red** ERROR **"
      echo "New ROLE $1 must be in Dirstore before it can be configured"
      echo "** ERROR **"
      tput sgr0
      return
   fi

   nodes=`lssys -o -q -e role==$1`
   if [ ! -z "$nodes" ]; then
      echo "ROLE $1 affects the following servers:"
      echo $nodes
   else
      echo -e "$red** ERROR **"
      echo "ROLE $1 is not used by any servers"
      echo "** ERROR **"
      tput sgr0
   fi
}

red='\E[31;40m\E[1m'

REALM=`lssys -l realm $HOSTNAME | grep realm | awk {'print $3'}`
if [[ ! $REALM == "g.ei.p3"  ]]; then
	echo "This command can only be run from a g.ei.p3 server"
	exit 1
fi

SOURCE=configtool_ds
me=`whoami`
BASEDIR="/fs/system/src/cvsroot/locks/${SOURCE}"
LOCKFILE="${BASEDIR}/${SOURCE}.lck"

PROD_DS=/fs/system/config/configtool_ds

if [[ "$SOURCE" = "configtool_ds" ]] ; then
	# check we have the lock for the source
	if  grep $me $LOCKFILE >/dev/null 2>&1 ;then
		if [ -d ~/src/${SOURCE} ]; then
			# Show changes to be made to dirstore
			configtool_ds -t upload | tee ~/src/.checkcvs.tmp
			CHANGES=`cat ~/src/.checkcvs.tmp | egrep -i "^NEW|^CHANGE" | awk '{if ($1=="NEW") print $2":"$NF; else print $4":"$NF}' | sort | uniq`
			rm -f  ~/src/.checkcvs.tmp
			for CHANGE in $CHANGES
			do
				target=${CHANGE#*:}
				target=${target%:*}
				type=${CHANGE%%:*}
				
				echo -e "\n****************************************************************************************"
				if [ "$type" == "ROLE" ]; then
					checkrole $target
				else
					# its a resource so we need to find the role(s) that use it
					roles=`dsls -q -e role resource==$target`
					if [ ! -z "$roles" ]; then
						echo RESOURCE $target is used by ROLE $roles
						for ROLE in $roles
						do
							checkrole $ROLE
						done
					else
						
						echo -e  "$red** ERROR **"
						echo "RESOURCE $target is not assigned to any ROLE"
						echo "** ERROR **"
						tput sgr0
					fi
				fi
				echo "****************************************************************************************"
			done
		else
			echo "~/src/${SOURCE} does not exist"
		fi
	else
		echo "You do not hold the lock for $SOURCE, check-out the source using lockcvs before continuing"
	fi
fi
