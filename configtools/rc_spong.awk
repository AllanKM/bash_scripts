BEGIN   { RS = "\n"; FS = " " }
/^####### Spong not running$/ { print "Spong\tNot_Running"; }
/(Polling|Checking)\ every\ [0-9]+\ seconds/ { print $2"\t"$1; }



# Success Case example:
#ronaldl@v10001:/fs/home/ronaldl$ sudo /lfs/system/bin/check_spong.sh
#02:51:37 Checking Spong
#   1 espong-apache 1.4.1.1 (Polling every 60 seconds)
#   1 spong-client (Checking every 240 seconds)
#02:51:37 ###### /lfs/system/bin/check_spong.sh Done



# Fail Case example:
#ronaldl@v10001:/fs/home/ronaldl$ sudo /lfs/system/bin/check_spong.sh
#03:01:00 Checking Spong
####### Spong not running
#03:01:00 ###### /lfs/system/bin/check_spong.sh Done
