/^([0-9]{2}:){2}[0-9]{2}\ Checking\ Status\ of\ Distributor\ using\ https?:\/\/localhost:[0-9]+\/L?Dist-.*$/ { check_url = $7; }
/^Monitored(\t|\ {7})[A-Z][a-z]{2}\ [0-9]{2}\ [0-9]{2}:[0-9]{2}\ \/.*$/ { print $5"\t"$1; }
/^(\t|\ {8})+[A-Z][a-z]{2}\ [0-9]{2}\ [0-9]{2}:[0-9]{2}\ \/.*$/ { print $4"\t-"; }
/^(\t|\ {8})https?:\/\/.*$/ { print check_url"(->"$1")\t"$2; }
/^#+(\t|\ +)https?:\/\/.*$/ { print check_url"(->"$1$2")\t"$3; }
/^#### Unable to read \/usr\/local\/etc\/pubstatus\.conf\.$/ { print $5"\tCan't_Read"; }
/^##### No publishing status files being monitored$/ { print "Status_File_Monitored\tNone"; }
/^\[[a-zA-Z0-9:\ ]+\]\ [a-f0-9]+\ [a-f0-9]+\ -\ lib_socket:\ \ connect\ failed\ \(.*\)$/ { print check_url"("$6"_"$7"-lib_socket:)\tconnect_failed"; }

# Case 1 example:
#node roles:  MQ.STG.CLIENT WAS.STG.CDT PUB.STG.LDIST.CDT DATABASE.STG.CLIENT.DB2V8
#09:39:11 Checking bNimble
#09:39:11 Checking Publishing Status
#Monitored       Dec 03 09:35 /projects/pubmon/stg_pubstatus.txt
#Monitored       Dec 03 09:35 /projects/pubmon/stg_pubstatus.txt
#Monitored       Dec 03 09:35 /projects/pubmon/stg_pubstatus.txt
#Monitored       Dec 03 09:35 /projects/pubmon/stg_pubstatus.txt
#09:39:11 Checking Status of Distributor using https://localhost:6329/LDist-IScdtI
#        Target URL                                 Status    Memory     Disk    Total
#        -----------------------------------------------------------------------------
#        https://w20012:6329/IScdtI                  UP           0        0        0
#09:39:11 Checking Status of Distributor using https://localhost:6329/LDist-IScdtW
#        Target URL                                 Status    Memory     Disk    Total
#        -----------------------------------------------------------------------------
#        https://localhost:6329/IScdtW               UP           0        0        0
#        https://w20014:6329/IScdtW                  UP           0        0        0
#09:39:11 Checking Status of Distributor using https://localhost:6329/LDist-SPEcdtI
#        Target URL                                 Status    Memory     Disk    Total
#        -----------------------------------------------------------------------------
#        https://w20012:6329/SPEcdtI                 UP           0        0        0
#09:39:12 Checking Status of Distributor using https://localhost:6329/LDist-SPEcdtW
#        Target URL                                 Status    Memory     Disk    Total
#        -----------------------------------------------------------------------------
#        https://w20076:6329/SPEcdtW                 UP           0        0        0
#        https://w20077:6329/SPEcdtW                 UP           0        0        0
###### /lfs/system/bin/check_bNimble.sh Done

# Case 2 example:
#jimjiang@w20006:/lfs/system/bin> sudo /lfs/system/tools/bNimble/bin/check_bNimble.sh
#node roles:  WEBSERVER.SSO.PRE WEBSERVER.ESC.PRE WEBSERVER.CLUSTER.YZPRECL007 PUB.ESC.ENDPOINT.PRE
#06:42:44 Checking bNimble
#06:42:44 Checking Publishing Status
#### Unable to read /usr/local/etc/pubstatus.conf.
##### No publishing status files being monitored
###### /lfs/system/tools/bNimble/bin/check_bNimble.sh Done

# Case 3 example:
#ronaldl@v10001:/fs/home/ronaldl$ sudo /lfs/system/bin/check_bNimble.sh
#node roles:  WEBSERVER.SSO.PRD WEBSERVER.ESC.PRD WEBSERVER.CLUSTER.YZPRDCL002 PUB.ESC.ENDPOINT
#16:05:09 Checking bNimble
#16:05:09 Checking Publishing Status
#### Unable to read /usr/local/etc/pubstatus.conf.
##### No publishing status files being monitored
#		Oct 17 16:00 /projects/esprod/content/espong/pubstatus_esc.txt
###### /lfs/system/bin/check_bNimble.sh Done

# Case 4 example:
#node roles:  PUB.IBM.HUB PUB.IBM.LDIST
#03:17:21 Checking bNimble
#03:17:21 Checking Publishing Status
#### Unable to read /usr/local/etc/pubstatus.conf.
##### No publishing status files being monitored
#03:17:21 Checking Status of Distributor using http://localhost:6327/LDist-CWibm
#[Mon Nov  7 03:17:21 2011] 00990028 00000001 - lib_socket:  connect failed (Connection refused)
#[Mon Nov  7 03:17:21 2011] 00990028 00000001 - lib_socket:  connect failed (Connection refused)
#[Mon Nov  7 03:17:21 2011] 00990028 00000001 - lib_socket:  connect failed (Connection refused)
#03:17:21 Checking Status of Distributor using http://localhost:6327/LDist-CWgrn
#[Mon Nov  7 03:17:21 2011] 0091006e 00000001 - lib_socket:  connect failed (Connection refused)
#[Mon Nov  7 03:17:21 2011] 0091006e 00000001 - lib_socket:  connect failed (Connection refused)
#[Mon Nov  7 03:17:21 2011] 0091006e 00000001 - lib_socket:  connect failed (Connection refused)
#03:17:21 Checking Status of Distributor using http://localhost:6327/LDist-CWdb2
#[Mon Nov  7 03:17:21 2011] 00870050 00000001 - lib_socket:  connect failed (Connection refused)
#[Mon Nov  7 03:17:21 2011] 00870050 00000001 - lib_socket:  connect failed (Connection refused)
#[Mon Nov  7 03:17:21 2011] 00870050 00000001 - lib_socket:  connect failed (Connection refused)
###### /lfs/system/bin/check_bNimble.sh Done

# Case 5:
#16:13:40 Checking Status of Distributor using https://localhost:6329/Dist-SPEcdtW
#        Target URL                                 Status    Memory     Disk    Total
#        -----------------------------------------------------------------------------
#        https://w20013:6329/LDist-SPEcdtW           UP           0        0        0
#16:13:41 Checking Status of Distributor using https://localhost:6329/Dist-SPEpreW
#        Target URL                                 Status    Memory     Disk    Total
#        -----------------------------------------------------------------------------
#        https://w30043:6329/SPEpreW                 UP           0        0        0
#        https://w30044:6329/SPEpreW                 UP           0        0        0
#16:13:41 Checking Status of Distributor using https://localhost:6329/Dist-SPEpreIB
#        Target URL                                 Status    Memory     Disk    Total
#        -----------------------------------------------------------------------------
#        https://w30007:6329/SPEpreIB                UP           0        0        0
#16:13:41 Checking Status of Distributor using https://localhost:6329/Dist-SPEprdW
####    https://v30010:6329/LDist-SPEprdW         DOWN           0      199      199
#        Target URL                                 Status    Memory     Disk    Total
#        -----------------------------------------------------------------------------
#        https://v10009:6329/LDist-SPEprdW           UP           0        0        0
#        https://v20011:6329/LDist-SPEprdW           UP           0        0        0
#16:13:42 Checking Status of Distributor using https://localhost:6329/Dist-SPEprdI
####    https://v30010:6329/LDist-SPEprdI         DOWN           0      158      158
#        Target URL                                 Status    Memory     Disk    Total
#        -----------------------------------------------------------------------------
#        https://v10009:6329/LDist-SPEprdI           UP           0        0        0
#        https://v20011:6329/LDist-SPEprdI           UP           0        0        0
