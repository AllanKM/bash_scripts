#!/bin/bash
# Prompt user for WAS login credentials
# Return formatted string for other script to use with wsadmin.
# Usage: get_usercreds.sh <cell>
REG=`echo $1 | cut -c8-9 | tr '[:lower:]' '[:upper:]'`
read -p "$REG WAS User: " wasuser
read -sp "Password   : " userpwd
echo "-username ${wasuser} -password ${userpwd}"