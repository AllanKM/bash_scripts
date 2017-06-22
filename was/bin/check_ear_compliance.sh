#!/bin/bash
# USAGE: check_ear_compliance.sh <path-to-ear>
#
#---------------------------------------------------------------------------------
#
# Change History: 
#
#  Lou Amodeo     03-01-2013  Add support for WebSphere V8.5
#
#
#---------------------------------------------------------------------------------
#
APPEAR=$1
TMPDIR=/tmp/checkear
FAIL=0
WARN=0
WASDIRLIST="/usr/WebSphere85/AppServer /usr/WebSphere70/AppServer /usr/WebSphere61/AppServer /usr/WebSphere60/AppServer"

non_compliant()
{
	#Function usage: non_compliant filename fileServing dirBrowsing serveServlets reloading
	echo "!! FAIL: Application NOT compliant, $1 contains:"
	if [[ -n "$2" ]]; then
		echo "!!   (EI JAAG)  fileServingEnabled=\"true\""
	fi
	if [[ -n "$3" ]]; then
		echo "!!   (EI JAAG)  directoryBrowsingEnabled=\"true\""
	fi
	if [[ -n "$4" ]]; then
		echo "!!   (EI JAAG)  serveServletsByClassnameEnabled=\"true\""
	fi
	if [[ -n "$5" ]]; then
		echo "!!   (EI JAAG)  reloadingEnabled=\"true\""
	fi
	echo "Settings should be disabled, or have EI documented business reason for enablement. (No CIRATS/RA needed)"
}

for dir in $WASDIRLIST; do
	if [[ -e $dir ]]; then
		WASDIR=$dir
		break
	fi
done
if [[ -z $WASDIR ]]; then
	echo "ERROR: EAR compliance verification must be performed from a node with WebSphere installed!"
	exit 1
fi
if [[ -f $APPEAR ]]; then
	echo "Checking $APPEAR for compliance with EI Java Application Acceptence Guidelines (includes ITCS104)..."
	if [ -d $TMPDIR ]; then
		rm -r ${TMPDIR}
	fi
	mkdir ${TMPDIR}
	${WASDIR}/bin/EARExpander.sh -ear ${APPEAR} -operationDir ${TMPDIR} -operation expand -expansionFlags war
	echo ""
	cd ${TMPDIR}
	if [[ -f "${TMPDIR}/META-INF/ibm-application-ext.xmi" ]]; then
		#Check EAR settings for ITCS104 recommendations
		earFS=`grep 'fileServingEnabled="true"' META-INF/ibm-application-ext.xmi`
		earDB=`grep 'directoryBrowsingEnabled="true"' META-INF/ibm-application-ext.xmi`
		earSSBC=`grep 'serveServletsByClassnameEnabled="true"' META-INF/ibm-application-ext.xmi`
		#Check EAR settings for ITCS104 recommendations
		earRL=`grep 'reloadingEnabled="true"' META-INF/ibm-application-ext.xmi`
		if [[ $earFS || $earDB || $earSSBC || $earRL ]]; then
			non_compliant "META-INF/ibm-application-ext.xmi" "$earFS" "$earDB" "$earSSBC" "$earRL"
			FAIL=$(($FAIL+1))
		fi
	fi
	for webext in $(find *.war/ -name ibm-web-ext.xmi); do
		#Check WAR settings for ITCS104 recommendations
		warFS=`grep 'fileServingEnabled="true"' $webext`
		warDB=`grep 'directoryBrowsingEnabled="true"' $webext`
		warSSBC=`grep 'serveServletsByClassnameEnabled="true"' $webext`
		#Check WAR settings for ITCS104 recommendations
		warRL=`grep 'reloadingEnabled="true"' $webext`
		if [[ $warFS || $warDB || $warSSBC || $warRL ]]; then
			non_compliant "$webext" "$warFS" "$warDB" "$warSSBC" "$warRL"
			FAIL=$(($FAIL+1))
		fi
	done
	
	#Check for security.xml files
	securityFiles=$(find ${TMPDIR} -name security.xml)
	if [ ${#securityFiles} -ne 0 ]; then
		#Check if files are non-harmful default one
		SECFAIL=0
		for secFile in $securityFiles; do
			#Do not grep with $, there may be ^M chars at end of lines
			grep '^<security:Security.*/>' $secFile
			if [ $? -ne 0 ]; then
				SECFAIL=$(($SECFAIL+1))
			fi
		done
		if [ $SECFAIL -ne 0 ]; then
			echo "!! WARNING: EAR contains 1 or more non-default security.xml files, which could affect WAS admin security."
			echo "!!   (EI JAAG)  Existence of modified security.xml files is not allowed as they can affect WAS admin security behavior."
			echo "!!              Modified file(s) found: $securityFiles"
			WARN=$(($WARN+1))
		fi
	fi

	#Check for policy file -- SOON TO BE DISABLED, no longer EI policy
	#if [[ ! -f "${TMPDIR}/META-INF/was.policy" ]]; then
	#	echo "!! WARNING: Application $APPEAR does not contain a policy file:"
	#	echo "!!   Application will require a was.policy file until 4Q Maintenance is completed and Java 2 Security is disabled."
	#	echo "!!   (Ex: myapp.ear/META-INF/was.policy)"
	#	WARN=$(($WARN+1))
	#else
	#	policyPerms=`grep 'permission' ${TMPDIR}/META-INF/was.policy|wc -l|sed -e "s/\ //g"`
	#	if [[ $policyPerms -lt 1 ]]; then
	#		echo "!! WARNING: Policy file found (META-INF/was.policy), but it contains no permission grants."
	#		WARN=$(($WARN+1))
	#	fi
	#fi

	#Check that servlets are configured for load at startup
	for webxml in $(find *.war/ -name web.xml); do
		wName=`echo $webxml|awk '{split($0,a,"/");print a[1]}'`
		servlets=`grep '<servlet>' $webxml |wc -l|sed -e "s/\ //g"`
		#servletNames=`grep '<servlet-name>' $webxml |wc -l|sed -e "s/\ //g"`
		los=`grep '<load-on-startup>' $webxml|wc -l|sed -e "s/\ //g"`
		struts=`grep 'org.apache.struts' $webxml|wc -l|sed -e "s/\ //g"`
		if [[ $servlets -gt 0 ]]; then
			if [[ $los -gt 0 ]]; then
				if [[ $los -ne $servlets && $struts -eq 0 ]]; then
					echo "!! WARNING: Not all servlets configured for load on startup:"
					echo "!!   (EI JAAG)  Module $wName in $APPEAR has $los of $servlets servlets configured to load on startup."
					echo "!!              At a minimum, please ensure commonly called servlets are loaded on startup."
					WARN=$(($WARN+1))
				elif [[ $los -ne $servlets && $struts -gt 0 ]]; then
					echo "!! WARNING: Struts in Use, not all servlets configured for load on startup:"
					echo "!!   (EI JAAG)  Module $wName in $APPEAR has $los of $servlets servlets configured to load on startup."
					echo "!!              At a minimum, please ensure any commonly called servlets are loaded on startup."
					echo "!!              If the primary functions of the application are all built on Struts, ignore this warning."
					WARN=$(($WARN+1))
				fi
			elif [[ $struts -gt 0 ]]; then
				echo "!! WARNING: Struts in Use, no servlets configured for load on startup:"
				echo "!!   (EI JAAG)  Module $wName in $APPEAR has $los of $servlets servlets configured to load on startup."
				echo "!!              At a minimum, please ensure any commonly called servlets are loaded on startup."
				echo "!!              If the primary functions of the application are all built on Struts, ignore this warning."
				WARN=$(($WARN+1))
			else
				echo "!! FAIL: No servlets configured for load on startup:"
				echo "!!   (EI JAAG)  Module $wName in $APPEAR has $los of $servlets servlets configured to load on startup."
				echo "!!              At a minimum, please configure commonly called servlets for load on startup."
				FAIL=$(($FAIL+1))
			fi
		fi
	done
	
	cd ..
	echo ""
	echo "Cleaning up ${TMPDIR} ..."
	echo ""
	rm -r ${TMPDIR}
	if [[ $FAIL -gt 0 ]]; then
		if [[ $WARN -gt 0 ]]; then
			echo "!! Application $APPEAR has FAILED compliance check, and returned $WARN warning(s)!"
		else
			echo "!! Application $APPEAR has FAILED compliance check!"
		fi
	else
		if [[ $WARN -gt 0 ]]; then
			echo "!! Application $APPEAR has PASSED compliance check, but returned $WARN warning(s)!"
		else
			echo "!! Application $APPEAR has PASSED compliance check!"
		fi
	fi
else
	echo "File not found: $1"
fi