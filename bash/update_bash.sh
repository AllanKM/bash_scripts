#!/bin/ksh
TOOLSDIR=/lfs/system/tools/bash/
if [[ -f ${TOOLSDIR}/bash_profile ]]; then
	cp ${HOME}/.bash_profile ${HOME}/.bash_profile.bak 2>/dev/null
	cp /lfs/system/tools/bash/bash_profile ${HOME}/.bash_profile
	echo "Updated .bash_profile"
fi

if [[ -f ${TOOLSDIR}/bashrc ]]; then
	cp ${HOME}/.bashrc ${HOME}/.bashrc.bak 2>/dev/null
	cp /lfs/system/tools/bash/bashrc ${HOME}/.bashrc
	echo "Updated .bashrc"
fi