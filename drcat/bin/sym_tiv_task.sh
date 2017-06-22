#!/bin/ksh

function tivfooter {
cat <<ENDFOOT
############################################################################

Deleting Task


##### CLEAN UP ####


******* Removing Node List and TaskTemp File from Region(s) *******
Removing /tmp/NODE_1700044 from at1001b **************************
ENDFOOT
}

function tivtask {
print -u2 -- "TIVTASK header"
cat <<ENDTIV
            Tivoli Task Run
***************************************************************************************



Options Selected:

Distribution Max time is: 600 seconds
EP Filename is: $servfile

Task Script: $cmdfile   



Distributing to...$env 
******* Copying Task Script to Temp File on Region(s) *******
Copying /tmp/TASK_1159370 to: at1001b
Xfering /tmp/TASK_1159370 to at1001b **************************
******* Copying Node List File to Temp File on Region(s) *******
Copying /tmp/NODE_1159370 to: at1001b
Xfering /tmp/NODE_1159370 to at1001b **************************
Running task on $env *************
#
#
###############################################################################
Running task on $env *************
WARNING: Timeout exceeds gateway maximum timeout. Task may timeout though it will continue to run on targets.
Input string is /tmp/TASK_1159370
Creating Task...This may take a few seconds....
Running Task....
ENDTIV
}







#########################################################################################
# wait a random amount of time

guessed=$((${RANDOM} % 10))
guessed=`expr $guessed + 1`

sleep $guessed

env=$6
servfile=$4
cmdfile=$7
nodes=`cat $servfile`

if [[ $cmdfile = *_cmds.sh ]]; then

   # Submit cmds

   tivtask

   for node in $nodes; do
      cat <<ENDNODE
############################################################################
Task Name:  TEMP_TASK_827640
Task Endpoint: $node (Endpoint)
Return Code:   0
------Standard Output------
------Standard Error Output------
DRCAT running:  process information for DRCAT task will go here
ENDNODE
   done 
   tivfooter   
elif [[ $cmdfile = *_check.sh ]]; then
   # check if complete
   tivtask
   for node in $nodes; do
   guessed=$((${RANDOM} % 1000))
   guessed=`expr $guessed + 1`
   if [[ $guessed -gt 800 ]]; then
      ps="drcat_1_cmds.sh"
   else
      ps=""
   fi
   cat <<ENDCHECK
############################################################################
Task Name:  TEMP_TASK_827640
Task Endpoint: $node (Endpoint)
Return Code:   0
------Standard Output------
------Standard Error Output------
$ps
ENDCHECK
   done 
   tivfooter
else
   # recover log
   tivtask
   for node in $nodes; do
      cat <<ENDOUTPUT
############################################################################
Task Name:  TEMP_TASK_827640
Task Endpoint: $node (Endpoint)
Return Code:   0
------Standard Output------
ENDOUTPUT
initcmdfile="${cmdfile%%_get.sh}_cmds.sh"

awk '/'$node'/,/^fi$/ {
   if ( $1 ~/if/ ) { next }
   if ( $1 ~/fi/ ) { next }
   gsub(/print --/,"")
   gsub(/print "rc="\$\?/,"rc=0") 
   print }' $initcmdfile
cat <<ENDFOOTER
------Standard Error Output------ 
ENDFOOTER
   done
   tivfooter 
 fi
