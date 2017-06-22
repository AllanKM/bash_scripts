#!/bin/ksh
if [[ -f /usr/HTTPServer/bin/httpd ]]; then
	/lfs/system/tools/itcs104/ihs/1_1_users.sh
	/lfs/system/tools/itcs104/ihs/4_1_ssl.sh
	/lfs/system/tools/itcs104/ihs/5_1_root_dirs.sh
	/lfs/system/tools/itcs104/ihs/5_2_osr_dirs.sh
	/lfs/system/tools/itcs104/ihs/5_3_default_access_rule.sh
	/lfs/system/tools/itcs104/ihs/5_4_cgi.sh
	/lfs/system/tools/itcs104/ihs/6_1_logging.sh
fi
