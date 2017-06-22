#!/bin/ksh
#Usage:
#config_webseal.sh <site url>
#Example: config_webseal.sh www-947.ibm.com

if [ `whoami` != "root" ]; then
      echo "You must run this script as root"; exit 1
fi

if [[ $# -lt 1 ]];then
   print "Usage: config_webseal.sh <site url> "
   print "  Example: config_webseal.sh www-947.ibm.com"
   exit
fi

#Ensure webseal is installed on this node
lslpp -lq PDWeb.Web | grep -q COMMITTED
if [ $? -ne 0 ]; then
    echo "WebSEAL does not appear to be installed on this node.  Exiting..."
    exit 1
fi

filecheck()
{
        if [ ! -f $1 ]; then
                echo "File $1 does not exist. Please ensure all prerequisite files are present. Exiting..."
                exit 1
        fi

}

getid()
{
read response?"Please enter your WebSEAL admin ID: "
print ""
if [[ "$response" = "" ]]; then
    getid
else
	adminid=$response
fi
}

getpass()
{
read lresponse?"Please enter the ltpa password: "
print ""
if [[ "$lresponse" = "" ]]; then
    getpass
else
	ltpa_pwd=$lresponse
fi
}

vhost=$1
label=`echo $vhost | awk 'BEGIN { FS = "." } ; { print $1 }'`
shlabel=`echo $label | awk 'BEGIN { FS = "-" } ; { print $1$2 }'`
keystore=${label}.kdb
keystash=${label}.sth
ssosrc=/fs/projects/prd/sso/WebSEAL
wsroot=/opt/pdweb
typeset -u keydir=$shlabel
keypath=/fs/system/security/certauth/KEYRINGS/$keydir
wskeydest=/var/pdweb/www-default/certs
toolsdir=/lfs/system/tools
datestamp=`date +%Y%m%d-%H%M`
ssocontent=$ssosrc/content/userservices/userservicescontent.tar
wsinst=/opt/pdweb/www-default
backuplst=$wsroot/etc/amwebbackup.lst
file=webseald-default.conf
scriptfile=update_userservices_host.sh
wsuser=ivmgr
host=`hostname -s`
ltpa_src=${ssosrc}/etc
ltpa_dest=$wsroot/keys
ltpa_key=ibm_ltpa.key
Cdir=$wsinst/lib/errors/C
jtzu_dir=/fs/system/images/java/jtzu
tplfile=EI_template_v1_0.tar

#Check for prerequisite files
filecheck $keypath/$keystore
filecheck $keypath/$keystash
filecheck $ssocontent
filecheck $backuplst
filecheck $ltpa_src/$ltpa_key
filecheck $ssosrc/content/errorpages.zip
filecheck $ssosrc/content/docs.tar
filecheck $jtzu_dir/runjtzu.sh
filecheck $ssosrc/conf/EI_template_v1_0.tar
filecheck $ssosrc/conf/$tplfile

#backup webseal configs
echo "Backing up WebSEAL config to /fs/scratch/amwebbackup_${datestamp}..."
/usr/bin/pdbackup -action backup -list $backuplst -path /fs/scratch -file amwebbackup_${datestamp}
echo "Done"

#edit webseald-default.conf with appropriate values
echo "Updating $file..."
filecheck $wsroot/etc/${file}
        cp $wsroot/etc/${file} /tmp
        cd /tmp
        sed -e "s/^web-host-name = .*/web-host-name = ${vhost}/" ${file} > ${file}.custom && mv ${file}.custom $file
        sed -e "s/^webseal-cert-keyfile = .*/webseal-cert-keyfile = \/var\/pdweb\/www-default\/certs\/${keystore}/" ${file} > ${file}.custom && mv ${file}.custom $file
        sed -e "s/^webseal-cert-keyfile-stash = .*/webseal-cert-keyfile-stash = \/var\/pdweb\/www-default\/certs\/${keystash}/" ${file} > ${file}.custom && mv ${file}.custom $file
        sed -e "s/^webseal-cert-keyfile-label = .*/webseal-cert-keyfile-label = ${label}/" ${file} > ${file}.custom && mv ${file}.custom $file
        sed -e "s/^server-name = ${host}-default/server-name = Events/" ${file} > ${file}.custom && mv ${file}.custom $file
    cp $file $wsroot/etc
echo "Done"
#copy keystore from gpfs
echo "Copying Keystore..."
        cp $keypath/$keystore $wskeydest
        cp $keypath/$keystash $wskeydest
echo "Done"

#untar sso content to webseal content path
	#First remove an previous content
	cd $wsinst/lib
	rm -rf htmlredir/
	rm -r errors/C/38cf0427.html
echo "Updating sso content and executing $scriptfile..."
tar -xvf $ssocontent

echo "Updating WebSEAL error pages as per the Common Error Pages for WebSEAL IPG..."
#Add ibm.com error pages
cd $ssosrc/content/errorpages
cp 400.html 404.html 500.html 503.html 38cf0434.html 38cf0428.html $Cdir
cd $Cdir
#Code taken from Common Error Pages for WebSEAL IPG
cat << _EOF > ibmlist
400.html 38cf0424.html
404.html 38cf0428.html
500.html default.html
503.html 38cf0432.html
503.html 38cf0442.html
400.html websealerror.html
_EOF

cat ibmlist |\
{
while read frum too 
do
        if [ ! -f $too.orig ]
        then
          cp $too $too.orig
        fi
        echo  replacing WebSEAL $too with IBM $frum
        cp $frum $too
	  chown ivmgr:ivmgr $too
	  chmod 440 $too
done
}
echo remove IBM original files
rm ???.html
for therest in `ls *.html`
do
        if [ ! -f $therest.orig ] && [ $therest != default.html ] && \
           [ $therest != deletesuccess.html ] &&  [ $therest != putsuccess.html ] && \
           [ $therest != relocated.html ] &&  [ $therest != 38cf0427.html ] && \
           [ $therest != 38cf0434.html ]
        then
          echo  move $therest to $therest.orig and link to default
          mv $therest $therest.orig
          ln -s default.html $therest   
        fi
done
#End code taken from IPG

#Add content
echo "Adding content to $wsinst/docs..."
cd $wsinst/docs
tar -xf $ssosrc/content/docs.tar
#update test.html
	cd /tmp
    cp $wsinst/docs/test.html /tmp
        sed -e "s/HOSTNAME/${host}/" /tmp/test.html > test.html.custom && mv test.html.custom $wsinst/docs/test.html
echo "Done"

#Update TONAME value in update_userservices_host.sh script
echo "Updating redirect error pages..."
filecheck $wsinst/lib/${scriptfile}
        cp $wsinst/lib/${scriptfile} /tmp
        cd /tmp
        sed -e "s;^TONAME=.*;TONAME='${vhost}\\\/account\\\/userservices';" ${scriptfile} > ${scriptfile}.custom && mv ${scriptfile}.custom $wsinst/lib/$scriptfile
        #execute scriptfile
        cd $wsinst/lib;chmod 750 ./$scriptfile;./$scriptfile
echo "Done"

#Create user services junction
echo "Creating userservices junction..."
mkdir -p $ltpa_dest
cp $ltpa_src/$ltpa_key $ltpa_dest
filecheck $ltpa_dest/$ltpa_key
getpass
getid
pdadmin -a '$adminid' server task default-webseald-${host} create -t ssl -p 443 -h origin.ibm.com.cs186.net -K www-947 -D "CN=www.ibm.com,OU=Events and ibm.com infrastructure,O=IBM,L=Research Triangle Park,ST=North Carolina,C=US" -c iv-user,iv-user-l -A -F ${ltpa_dest}/${ltpa_key} -Z '${ltpa_pwd}' /usrsrvc
 
#Update jmt.conf with /account/userservices context root
cp $ssosrc/conf/jmt.conf /opt/pdweb/www-default/lib/

echo "Done"

#Apply JTZU to java instances
echo "Applying Java Time Zone Update..."
cd $jtzu_dir
#Run in discover mode first to discover java instances and create SDKList.txt
./runjtzu.sh
#Now run in silent patch mode by editing the runjtzuenv.sh
cp runjtzuenv.sh /tmp
cd /tmp
sed -e "s/DISCOVERONLY=true/DISCOVERONLY=false/" /tmp/runjtzuenv.sh > runjtzuenv.sh.custom && mv runjtzuenv.sh.custom $jtzu_dir/runjtzuenv.sh
cd $jtzu_dir
./runjtzu.sh
#Restore original config for future runs
cp /tmp/runjtzuenv.sh $jtzu_dir/
rm -r $jtzu_dir/Temp
echo "Done"

#Apply webseadl-default template
echo "Applying EI config template..."
cd $wsroot/etc
tar -xf $ssosrc/conf/$tplfile
chmod 700 apply_template.sh
./apply_template.sh
mv webseald-default.conf webseald-default.conf.$datestamp && mv webseald-default.conf.new webseald-default.conf
echo "Done"

#Update Ownership and Permissions
echo "Updating ownership and permissions..."
chown -R ivmgr.ivmgr $wsroot
chown root.ivmgr $wsroot/bin/webseald $wsroot/.configure
chmod 440 $wsinst/lib/htmlredir/C/* $wsinst/lib/errors/C/* $wskeydest/*
chmod 755 /logs/www-947.ibm.com
chown -R ivmgr.eiadm /logs/www-947.ibm.com/*

echo "Done"

#Restart WebSEAL
/usr/local/bin/webseal.ksh restart
#Check Status
/usr/bin/pdweb status
