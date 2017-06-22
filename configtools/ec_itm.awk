BEGIN { FS=":"; }
/Installer Lvl/ { print "Installer_Lvl:\t"$3; }
#/Installer Lvl/ { FS=":"; print "Installer_Lvl:\t"$3; }

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
#*********** Fri Mar 25 02:01:11 UTC 2011 ******************
#User: root Groups: system bin sys security cron audit lp
#Host name : v20105       Installer Lvl:06.21.00.03
#CandleHome: /opt/IBM/ITM
#***********************************************************
#Host    Prod  PID       Owner  Start  ID    ..Status
#v20105  yn    14549218                None  ...process not running
