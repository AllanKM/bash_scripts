#!/bin/ksh
#Check the health of a system based on associated roles
#Usage:
#         check.sh  [list of focus areas rather than checking all roles]
#Example: check.sh ihs pub
# If argements are passed to the command, they are used as patterns for matching against roles.
# Only checks for matching roles will be used.

#All errors messages begin the line with "###"
#To look for just errors, run:  check.sh | grep \#

funcs=/lfs/system/tools/configtools/lib/check_functions.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"


#Obtain list of roles for this node
getRoles

if [[ -n $* ]]; then
	NEWLIST=""
	#If args were passed in to the script use only associated matching roles for our check
	for ARG in $* ; do
		typeset -u ARG
		for ROLE in $ROLES; do
			if [[ "$ROLE" = *"$ARG"* ]]; then 
				NEWLIST="$NEWLIST $ROLE"
			fi
		done
	done
	ROLES=$NEWLIST
fi

for ROLE in $ROLES ; do
	typeset -l ROLE
	#echo "Looking at role:  $ROLE"
	case $ROLE in 
		*webserver.spong*)
						/lfs/system/bin/check_ihs.sh $ROLE
						/lfs/system/bin/check_spong.sh ;;
		*webserver.esc)
						/lfs/system/bin/check_ihs.sh $ROLE
						/lfs/system/bin/check_lcs.sh
						/lfs/system/bin/check_spong.sh ;;				
		*ibm.origin*|*webserver.ice|*webserver.srm*|*webserver.xsr.prd*)
						/lfs/system/bin/check_ihs.sh $ROLE
						/lfs/system/bin/check_lcs.sh
						/lfs/system/bin/check_spong.sh ;;
		*webserver.events.origin*)
						/lfs/system/bin/check_ihs.sh $ROLE
						/lfs/system/bin/check_lcs.sh
						/lfs/system/bin/check_spong.sh ;;
		*pub*)			/lfs/system/bin/check_bNimble.sh $ROLE ;;																				
		*was*)  		/lfs/system/bin/check_was.sh $ROLE ;;
		*database*client*)		echo "";;  #skip db2 client role - don't know what to check here
		*db2*) 			/lfs/system/bin/check_db2.sh $ROLE ;;
		*webserver*) 	/lfs/system/bin/check_ihs.sh $ROLE ;;
		*mq*)			/lfs/system/bin/check_mq.sh $ROLE ;;
		*wbimb*)		/lfs/system/bin/check_wbimb.sh $ROLE ;;
		*lcs*)			/lfs/system/bin/check_lcs.sh ;;
		*spong*)		/lfs/system/bin/check_spong.sh ;;
		*search*origin)		/lfs/system/bin/check_htdig.sh ;;	
	esac
done
