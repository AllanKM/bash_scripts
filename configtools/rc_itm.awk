#$2 ~ /ux|lz|px|pk|ph|va|ul|um|ms|cq|hd|sy|pa|p5|pv|is|e9|ud|mq|ht|yn|nd/ { print $2"\t"$7"\("$3,$5"\)"; }
/\.\.\.running\ *$/ { print $2"("$4")\tRunning("$3","$5")"; }
#/^\.\.\.no known processes are running$/ { print "No_Known_Proc"; }	#should not output anything
/\.\.\.process not running$/ { print $2"\tProc_Not_Running("$3")"; }

# yn: Websphere agent
# ud: DB2 agent
# mq: MQ monitoring agent
# hd: warehouse proxy agent
# um: Universal agent
# ht: HTTPD agent
# nd: netview Server Monitor


#Case 1:
#*********** Tue Nov 16 03:00:38 CUT 2010 ******************
#User: root Groups: system bin sys security cron audit lp
#Host name : v20065       Installer Lvl:06.21.00.03
#CandleHome: /opt/IBM/ITM
#***********************************************************
#Host    Prod  PID     Owner  Start  ID    ..Status
#v20065  px    659660  root   Jan    None  ...running
#v20065  ux    262228  root   Jul    None  ...running
#v20065  yn    217134  root   Nov    None  ...running
#v20065  ul    843974  root   Nov    None  ...running

#Case 2:
#*********** Fri Mar 25 02:01:15 UTC 2011 ******************
#User: root Groups: system bin sys security cron audit lp
#Host name : v20106       Installer Lvl:06.21.00.03
#CandleHome: /opt/IBM/ITM
#***********************************************************
#...no known processes are running

#Case 3:
#*********** Mon Aug  8 11:15:26 UTC 2011 ******************
#User: root Groups: root pkcs11 sfcb
#Host name : v20132       Installer Lvl:06.22.04.00
#CandleHome: /opt/IBM/ITM
#***********************************************************
#Host    Prod  PID   Owner  Start  ID    ..Status
#v20132  ul    5201                None  ...process not running
#v20132  lz    3295  root   Aug05  None  ...running            
