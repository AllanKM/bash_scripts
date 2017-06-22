#!/bin/ksh
# Provide the subdirectory under /projects to traverse and set permissons for
# /projects/<sub directory>/search
# This is used to set permissions after syncing over htdig search config files.

funcs=/lfs/system/tools/ihs/lib/htdig_functions.sh
[ -r $funcs ] && . $funcs || print -u2 -- "#### Can't read functions file at $funcs"

htdig_perms $1
