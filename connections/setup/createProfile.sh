#!/bin/ksh
# Create a standalone Profile for use in installing Lotus Connections
HOST=`/bin/hostname -s`   
WAS_HOME="/usr/WebSphere61/AppServer/profiles/${HOST}"



echo "Removing current Profile for $HOST"
/usr/WebSphere61/AppServer/bin/manageprofiles.sh -delete -profileName $HOST
rm -fr $WAS_HOME
rm -fr /logs/was61/${HOST}/*

echo "Creating a new standalone Profile"
#Need to update to use the ei template
/usr/WebSphere61/AppServer/bin/manageprofiles.sh -create -templatePath /usr/WebSphere61/AppServer/profileTemplates/default -profileName $HOST -profilePath /usr/WebSphere61/AppServer/profiles/${HOST} -hostName $HOST -nodeName $HOST -cellName ${HOST}Cell -startingPort 21000 -isDefault
cp ${WAS_HOME}/logs/* /logs/was61/${HOST}
rm -fr ${WAS_HOME}/logs
ln -s /logs/was61/${HOST} ${WAS_HOME}/logs

echo "Setting up EI security for the new profile"
/lfs/system/tools/was/setup/was_security_setup.sh WI 61013  

#Putting the EI Templates in place
echo "Unpacking WAS v6.1 EI Application Server templates ...."
cd ${WAS_HOME}/config/templates
tar -xf /lfs/system/tools/was/setup/was61_ei_templates.tar

echo "Setting permissions"
/lfs/system/tools/was/setup/was_perms.ksh

echo "Create link for ei_gz_was.jks certificate"
ln -sf /usr/WebSphere61/AppServer/etc/ei_gz_was.jks ${WAS_HOME}/etc/ei_gz_was.jks 

echo "Starting the Standalone WAS profile"
/lfs/system/bin/rc.was start server1

echo "Setting permissions"
/lfs/system/tools/was/setup/was_perms.ksh
