#!/bin/bash

# (c) 2009 AMOOMA GmbH - http://www.amooma.de
# Alle Rechte vorbehalten. -- All rights reserved.
# $Revision: 274 $


ZAPTEL_VERS="1.4.12.1"
#ASTERISK_VERS="1.4.21.2"
ASTERISK_VERS="1.4.21"
ASTERISK_ADDONS_VERS="1.4.7"
LAME_VERS="398-2"
GEMEINSCHAFT_VERS="2.1.0"
GEMEINSCHAFT_SIEMENS_VERS="trunk-r00358"


err()
{
	echo '' >&2
	echo -n '***** Error!' >&2
	[ ! -z "$ERRMSG" ] && echo -n " $ERRMSG" >&2
	echo -e "\n" >&2
	exit 1
}

trap "(echo ''; echo '***** Aborted!') >&2; exit 130" SIGINT SIGTERM SIGQUIT SIGHUP
trap "err; exit 1" ERR

# do nothing if Gemeinschaft has already been installed
#
if [ -e /opt/gemeinschaft ]; then
	echo "Gemeinschaft has already been installed." >&2
	exit 0
fi

# check system
#
if [ ! -e /etc/debian_version ]; then
	ERRMSG="This script works on Debian only."
	err
fi
if [ "`id -un`" != "root" ]; then
	ERRMSG="This script must be run as root."
	err
fi

# set PATH
#
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:${PATH}"

# setup basic stuff
#
echo "***"
echo "***  Setup basic stuff ..."
echo "***"
type apt-get 1>>/dev/null 2>>/dev/null
type aptitude 1>>/dev/null 2>>/dev/null || apt-get -y install aptitude
#APTITUDE_INSTALL="aptitude -y --allow-new-upgrades --allow-new-installs install"
APTITUDE_INSTALL="aptitude -y"
APTITUDE_REMOVE="aptitude -y purge"
if [[ `grep 5\. /etc/debian_version` ]]; then
	echo "Debian 5 (Lenny) mode"
	APTITUDE_INSTALL="${APTITUDE_INSTALL} --allow-new-upgrades --allow-new-installs"
else
	echo "Debian 4 (Etch) mode"
fi
APTITUDE_INSTALL="${APTITUDE_INSTALL} install"
echo "APTITUDE_INSTALL = ${APTITUDE_INSTALL}"

# very cheap hack to wait for the DHCP-client
#
COUNTER=0
while [  $COUNTER -lt 60 ]; do
    echo -n "."
    sleep 1
    let COUNTER=COUNTER+1 
done
echo ""

# install and configure local nameserver
#
echo "***"
echo "***  Installing local caching nameserver ..."
echo "***"
${APTITUDE_INSTALL} bind9
aptitude clean
[ -e /etc/resolv.conf ]
if [[ `grep -Ee "^nameserver[ \t]+" /etc/resolv.conf | head -n 1 | grep -Ee "127\.0\.0\.1"` ]]; then
	echo "nameserver 127.0.0.1 already configured."
else
	[ -e /tmp/resolv.conf ] && rm -f /tmp/resolv.conf || true
	echo "nameserver 127.0.0.1" > /tmp/resolv.conf
	cat /etc/resolv.conf >> /tmp/resolv.conf
	mv -fT /tmp/resolv.conf /etc/resolv.conf
fi
[ -e /etc/bind/named.conf.local ]
[ -e /etc/bind/zones.rfc1918 ]
if [[ `grep "^include" /etc/bind/named.conf.local | grep "zones\.rfc1918"` ]]; then
	echo "/etc/bind/named.conf.local already includes /etc/bind/zones.rfc1918"
else
	echo 'include "/etc/bind/zones.rfc1918";' >> /etc/bind/named.conf.local
fi
/etc/init.d/bind9 restart || true
sleep 2

# wait for internet access
#
echo "Checking Internet access ..."
while ! ( wget -O - -T 30 http://www.amooma.de/ >>/dev/null ); do sleep 5; done
MY_MAC_ADDR=`LANG=C ifconfig | grep -oE '[0-9a-fA-F]{1,2}\:[0-9a-fA-F]{1,2}\:[0-9a-fA-F]{1,2}\:[0-9a-fA-F]{1,2}\:[0-9a-fA-F]{1,2}\:[0-9a-fA-F]{1,2}' | head -n 1`
wget -O - -T 30 http://www.amooma.de/gemeinschaft/installer/checkin?mac=$MY_MAC_ADDR >>/dev/null 2>>/dev/null || true

# install basic stuff
#

${APTITUDE_INSTALL} \
	coreutils lsb-base grep findutils sudo wget curl cron \
	expect logrotate hostname net-tools ifupdown iputils-ping netcat \
	openssh-client openssh-server \
	udev psmisc dnsutils iputils-arping pciutils bzip2 \
	console-data console-tools \
	vim less

WGET="wget"
WGET_ARGS="-c -T 60 --no-check-certificate"
DOWNLOAD="${WGET} ${WGET_ARGS}"

# set up lang enviroment
#
echo "***"
echo "***  Setting up language environment ..."
echo "***"
${APTITUDE_INSTALL} locales
[ -e /etc/locale.gen ]
grep -e "^de_DE\.UTF-8 UTF-8" /etc/locale.gen || echo "de_DE.UTF-8 UTF-8" >> /etc/locale.gen
grep -e "^en_US\.UTF-8 UTF-8" /etc/locale.gen || echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
type locale-gen 1>>/dev/null 2>>/dev/null
locale-gen 


# install ntp
#
echo "***"
echo "***  Installing NTP ..."
echo "***"
${APTITUDE_INSTALL} ntp ntpdate
${APTITUDE_INSTALL} ntp-simple || true
/etc/init.d/ntp stop 2>>/dev/null || true
ntpdate 0.debian.pool.ntp.org
ntpdate 0.debian.pool.ntp.org
/etc/init.d/ntp start 

# make the system use a tmpfs for /tmp on the next boot
#
sed -i -r -e 's/^(RAMRUN=)no/\1yes/' /etc/default/rcS || true

# install build env
#
echo "***"
echo "***  Installing build environment ..."
echo "***"
${APTITUDE_INSTALL} \
	gcc g++ binutils libtool make

# install asterisk stuff
#
echo "***"
echo "***  Installing build dependencies ..."
echo "***"
${APTITUDE_INSTALL} linux-headers-`uname -r` linux-kernel-headers
${APTITUDE_INSTALL} bison byacc flex libnewt0.52 libnewt-dev ncurses-base ncurses-bin ncurses-dev ncurses-term libncurses4 libncurses5 libncurses-dev openssl zlib1g zlib1g-dev libmysqlclient15-dev

# clean up and save some space
#
aptitude clean

# download and build zaptel
#
echo "***"
echo "***  Installing Zaptel ..."
echo "***"
cd /usr/src/
${DOWNLOAD} "http://downloads.digium.com/pub/zaptel/releases/zaptel-${ZAPTEL_VERS}.tar.gz"
tar -xzf zaptel-${ZAPTEL_VERS}.tar.gz
rm -rf zaptel-${ZAPTEL_VERS}.tar.gz
cd zaptel-${ZAPTEL_VERS}
./configure && make clean && make && make install && make config
rm -rf firmware/zaptel-fw-* || true
rm -rf /usr/src/zaptel-${ZAPTEL_VERS}
cd
update-rc.d -f zaptel remove
update-rc.d zaptel defaults 15 30
modprobe ztdummy
dmesg | grep -iE 'zap|zt' || true

# download and install Asterisk
#
echo "***"
echo "***  Installing Asterisk ..."
echo "***"
cd /usr/src/
${DOWNLOAD} "http://downloads.digium.com/pub/asterisk/releases/asterisk-${ASTERISK_VERS}.tar.gz"
tar -xzf asterisk-${ASTERISK_VERS}.tar.gz
rm -rf asterisk-${ASTERISK_VERS}.tar.gz
cd asterisk-${ASTERISK_VERS}
./configure && make clean && make
rm -rf /usr/lib/asterisk/modules 2>>/dev/null || true
make install && make config && make samples
rm -rf /usr/src/asterisk-${ASTERISK_VERS}
cd
update-rc.d -f asterisk remove
update-rc.d asterisk defaults 50 15

# create directory for call-files
#
mkdir -p /var/spool/asterisk/outgoing
chmod a+rwx /var/spool/asterisk/outgoing
chmod a+rwx /var/spool/asterisk/tmp

# download and install Asterisk Addons
#
echo "***"
echo "***  Installing Asterisk addons ..."
echo "***"
cd /usr/src/
${DOWNLOAD} "http://downloads.digium.com/pub/asterisk/releases/asterisk-addons-${ASTERISK_ADDONS_VERS}.tar.gz"
tar -xzf asterisk-addons-${ASTERISK_ADDONS_VERS}.tar.gz
rm -rf asterisk-addons-${ASTERISK_ADDONS_VERS}.tar.gz
cd asterisk-addons-${ASTERISK_ADDONS_VERS}
./configure
[ -e menuselect.makedeps ] && rm -f menuselect.makedeps || true
[ -e menuselect.makeopts ] && rm -f menuselect.makeopts || true
cat <<HEREDOC >menuselect.makedeps
MENUSELECT_DEPENDS_app_addon_sql_mysql=MYSQLCLIENT 
MENUSELECT_DEPENDS_cdr_addon_mysql=MYSQLCLIENT 
MENUSELECT_DEPENDS_res_config_mysql=MYSQLCLIENT 
HEREDOC
cat <<HEREDOC >menuselect.makeopts
MENUSELECT_APPS=app_saycountpl 
MENUSELECT_CDR=
MENUSELECT_CHANNELS=chan_ooh323 
MENUSELECT_FORMATS=format_mp3 
MENUSELECT_RES=
MENUSELECT_BUILD_DEPS=
HEREDOC
make clean && make && make install
[ -e /usr/lib/asterisk/modules/res_config_mysql.so ]
make samples
rm -rf /usr/src/asterisk-addons-${ASTERISK_ADDONS_VERS}
cd

# install lame
#
echo "***"
echo "***  Installing Lame ..."
echo "***"
cd /usr/src/
${DOWNLOAD} "http://dfn.dl.sourceforge.net/sourceforge/lame/lame-${LAME_VERS}.tar.gz"
tar -xzf lame-${LAME_VERS}.tar.gz
rm -rf lame-${LAME_VERS}.tar.gz
cd lame-${LAME_VERS}
./configure && make clean && make && make install
rm -rf /usr/src/lame-${LAME_VERS}
cd

# remove build environment 
#
echo "***"
echo "***  Removing build environment  ..."
echo "***"
${APTITUDE_REMOVE} linux-headers-`uname -r` linux-kernel-headers
${APTITUDE_REMOVE} bison byacc flex libnewt-dev ncurses-dev libncurses-dev zlib1g-dev libmysqlclient15-dev

# install misc packages
#
echo "***"
echo "***  Installing other packages ..."
echo "***"
${APTITUDE_INSTALL} \
	perl perl-modules libnet-daemon-perl libnet-netmask-perl libio-interface-perl libio-socket-multicast-perl \
	sipsak \
	mysql-client libmysqlclient-dev mysql-server \
	apache2 \
	php5-cli libapache2-mod-php5 php5-mysql php5-ldap \
	sox mpg123

# install German voice prompts for Asterisk
#
echo "***"
echo "***  Installing German voice prompts for Asterisk ..."
echo "***"

cd /var/lib/asterisk/sounds/
[ -e de ] && rm -rf de || true
${DOWNLOAD} "http://www.amooma.de/asterisk/sprachbausteine/asterisk-core-sounds-de-alaw.tar.gz"
tar -xzf asterisk-core-sounds-de-alaw.tar.gz
rm -f asterisk-core-sounds-de-alaw.tar.gz

# install Gemeinschaft
#
echo "***"
echo "***  Installing Gemeinschaft ..."
echo "***"
cd /usr/src/
${DOWNLOAD} "http://www.amooma.de/gemeinschaft/download/gemeinschaft-${GEMEINSCHAFT_VERS}.tgz"
tar -xzf gemeinschaft-${GEMEINSCHAFT_VERS}.tgz
rm -f gemeinschaft-${GEMEINSCHAFT_VERS}.tgz
ln -snf gemeinschaft-${GEMEINSCHAFT_VERS} gemeinschaft

# main Gemeinschaft dir link
#
cd /opt/
ln -snf /usr/src/gemeinschaft/opt/gemeinschaft

# voice prompts for Gemeinschaft
#
echo "Downloading Voiceprompts for Gemeinschaft ..."
[ -e /opt/gemeinschaft/sounds ]
cd /opt/gemeinschaft/sounds
if [ -e de-DE ]; then
	rm -rf de-DE || true
fi
if [ -e de-DE-tts ]; then
	rm -rf de-DE-tts || true
fi
${DOWNLOAD} "http://www.amooma.de/gemeinschaft/download/gemeinschaft-sounds-de-wav-current.tar.gz"
tar -xzf gemeinschaft-sounds-de-wav-current.tar.gz
rm -f gemeinschaft-sounds-de-wav-current.tar.gz || true
if [ -e de-DE ]; then
	mv de-DE de-DE-tts
fi
if [ -e de-DE-tts ]; then
	ln -snf de-DE-tts de-DE
fi


# MySQL: add gemeinschaft user
#
echo "***"
echo "***  Installing Gemeinschaft database ..."
echo "***"
GEMEINSCHAFT_DB_PASS=`head -c 20 /dev/urandom | md5sum -b - | cut -d ' ' -f 1 | head -c 30`
[ -e /tmp/mysql-gemeinschaft-grant.sql ] && rm -f /tmp/mysql-gemeinschaft-grant.sql || true
touch /tmp/mysql-gemeinschaft-grant.sql
chmod go-rwx /tmp/mysql-gemeinschaft-grant.sql
echo "GRANT ALL ON \`asterisk\`.* TO 'gemeinschaft'@'localhost' IDENTIFIED BY '${GEMEINSCHAFT_DB_PASS}';" >> /tmp/mysql-gemeinschaft-grant.sql
echo "GRANT ALL ON \`asterisk\`.* TO 'gemeinschaft'@'%' IDENTIFIED BY '${GEMEINSCHAFT_DB_PASS}';" >> /tmp/mysql-gemeinschaft-grant.sql
echo "FLUSH PRIVILEGES;" >> /tmp/mysql-gemeinschaft-grant.sql
cat /tmp/mysql-gemeinschaft-grant.sql | mysql --batch
rm -f /tmp/mysql-gemeinschaft-grant.sql
mysql --batch --user=gemeinschaft --password="${GEMEINSCHAFT_DB_PASS}" -e "SELECT 'test'"

# Gemeinschaft database
#
cd /usr/src/gemeinschaft/usr/share/doc/gemeinschaft/
mysql --batch --user=gemeinschaft --password="${GEMEINSCHAFT_DB_PASS}" < asterisk.sql

# Apache configuration
#
echo "***"
echo "***  Setting up Apache web server ..."
echo "***"
cd /etc/apache2/conf.d/
ln -snf /usr/src/gemeinschaft/etc/apache2/conf.d/gemeinschaft.conf gemeinschaft.conf
if [ -e /usr/src/gemeinschaft/etc/apache2/sites-available/gemeinschaft ]; then
	cd /etc/apache2/sites-available/
	ln -snf /usr/src/gemeinschaft/etc/apache2/sites-available/gemeinschaft gemeinschaft
	a2dissite default
	a2ensite gemeinschaft
else
	cd /etc/apache2/sites-available/
	cat default | sed -e 's/AllowOverride None/AllowOverride All/i' > gemeinschaft
	a2dissite default
	a2ensite gemeinschaft
fi
a2enmod rewrite alias
a2enmod rewrite mime
a2enmod rewrite php5

/etc/init.d/apache2 restart

# sudo permissions for Apache
#
echo "www-data  ALL=(ALL)  NOPASSWD: ALL" >> /etc/sudoers

# configure Asterisk
#
echo "***"
echo "***  Setting up Gemeinschaft ..."
echo "***"
cd /etc/
rm -rf asterisk || true
ln -snf /usr/src/gemeinschaft/etc/asterisk

# configure Gemeinschaft
#
cd /etc/
ln -snf /usr/src/gemeinschaft/etc/gemeinschaft

# find IP address
# FIXME: Vielleicht geht das auch schoener.
#
MY_IP_ADDR=`LANG=C ifconfig | grep inet | grep -v 'inet6' | grep -v '127\.0\.0\.1' | head -n 1 | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -v '^255' | head -n 1`
if [ "x$?" != "x0" ] || [ -z ${MY_IP_ADDR} ]; then
	echo "***** Failed to find your IP address." 2>&1
	MY_IP_ADDR="192.168.1.130"
fi
MY_NETMASK=`LANG=C ifconfig | grep inet | grep -v 'inet6' | grep -v '127\.0\.0\.1' | head -n 1 | grep -io 'mask.*' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep '^255' | sort -n | head -n 1`
if [ "x$?" != "x0" ] || [ -z ${MY_NETMASK} ]; then
	echo "***** Failed to find your netmask." 2>&1
	MY_NETMASK="255.0.0.0"
fi

# configure gemeinschaft.php - IP address, DB password etc.
#
sed -i "s/\(^[\s#\/]*\$INSTALLATION_TYPE\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\1'single';/g" /etc/gemeinschaft/gemeinschaft.php


sed -i "s/\(^[\s#\/]*\$DB_MASTER_HOST\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\1'127.0.0.1';/g" /etc/gemeinschaft/gemeinschaft.php
sed -i  "s/\(^[\s#\/]*\$DB_SLAVE_HOST\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\1'127.0.0.1';/g" /etc/gemeinschaft/gemeinschaft.php
sed -i "s/\(^[\s#\/]*\$DB_MASTER_USER\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\1'gemeinschaft';/g" /etc/gemeinschaft/gemeinschaft.php
sed -i  "s/\(^[\s#\/]*\$DB_SLAVE_USER\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\1'gemeinschaft';/g" /etc/gemeinschaft/gemeinschaft.php
sed -i "s/\(^[\s#\/]*\$DB_MASTER_PWD\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\1'${GEMEINSCHAFT_DB_PASS}';/g" /etc/gemeinschaft/gemeinschaft.php
sed -i  "s/\(^[\s#\/]*\$DB_SLAVE_PWD\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\1'${GEMEINSCHAFT_DB_PASS}';/g" /etc/gemeinschaft/gemeinschaft.php
sed -i "s/\(^[\s#\/]*\$DB_MASTER_DB\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\1'asterisk';/g" /etc/gemeinschaft/gemeinschaft.php
sed -i  "s/\(^[\s#\/]*\$DB_SLAVE_DB\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\1'asterisk';/g" /etc/gemeinschaft/gemeinschaft.php

sed -i "s/\(^[\s#\/]*\$PROV_HOST\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\1'${MY_IP_ADDR}';/g" /etc/gemeinschaft/gemeinschaft.php

sed -i "s/\(^[\s#\/]*\$CALL_INIT_FROM_NET\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\1'${MY_IP_ADDR}\/${MY_NETMASK}';/g" /etc/gemeinschaft/gemeinschaft.php
sed -i "s/\(^[\s#\/]*\$MONITOR_FROM_NET\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\1'${MY_IP_ADDR}\/${MY_NETMASK}';/g" /etc/gemeinschaft/gemeinschaft.php

sed -i "s/\(^[\s#\/]*\$EMAIL_DELIVERY\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\1'sendmail';/g" /etc/gemeinschaft/gemeinschaft.php

sed -i "s/\(^[\s#\/]*\$LOG_GMT\s*=\s*\)[^a-z0-9]*\s*;/\1false;/g" /etc/gemeinschaft/gemeinschaft.php


echo $MY_IP_ADDR > /opt/gemeinschaft/etc/listen-to-ip

mysql --batch --user=gemeinschaft --password="${GEMEINSCHAFT_DB_PASS}" -e "USE \`asterisk\`; UPDATE \`hosts\` SET \`host\`='${MY_IP_ADDR}' WHERE \`id\`=1;" || true
mysql --batch --user=gemeinschaft --password="${GEMEINSCHAFT_DB_PASS}" -e "USE \`asterisk\`; UPDATE \`hosts\` SET \`host\`='${MY_IP_ADDR}';" || true

# moved gemeinschaft-siemens installing here cause gemeinschaft have to be configured before generating the SSL cert

# install gemeinschaft-siemens addon
#
echo "Downloading Siemens addon for Gemeinschaft (Openstage provisoning) ..."
cd /usr/src
${DOWNLOAD} "http://www.amooma.de/gemeinschaft/download/gemeinschaft-siemens-${GEMEINSCHAFT_SIEMENS_VERS}.tgz"
tar -xzf gemeinschaft-siemens-${GEMEINSCHAFT_SIEMENS_VERS}.tgz
rm -f gemeinschaft-siemens-${GEMEINSCHAFT_SIEMENS_VERS}.tgz
ln -snf gemeinschaft-siemens-${GEMEINSCHAFT_SIEMENS_VERS} gemeinschaft-siemens
cd /opt/
ln -snf /usr/src/gemeinschaft-siemens/opt/gemeinschaft-siemens
cd

# configure gemeinschaft-siemens
#
${APTITUDE_INSTALL} openssl 
a2enmod rewrite 
a2enmod ssl

cd /etc/apache2/
[ -e ssl ] && rm -rf ssl || true
ln -snf /usr/src/gemeinschaft-siemens/doc/etc-apache2-ssl ssl
cd /etc/apache2/ssl/
./gen-cert.sh >>/dev/null
chown root:root openstage-*.pem
chmod 640 openstage-*.pem
cd /etc/apache2/sites-available/
ln -snf /usr/src/gemeinschaft-siemens/doc/httpd-vhost.conf.example gemeinschaft-siemens
a2ensite gemeinschaft-siemens
cd

# documentation
#
cd /usr/share/doc
ln -snf /usr/src/gemeinschaft/usr/share/doc/gemeinschaft

# log dir
#
mkdir -p /var/log/gemeinschaft
chmod a+rwx /var/log/gemeinschaft

# logrotate rules
#
cd /etc/logrotate.d/
ln -snf /usr/src/gemeinschaft/etc/logrotate.d/asterisk
ln -snf /usr/src/gemeinschaft/etc/logrotate.d/gemeinschaft

# web dir
#
cd /var/www/
ln -snf /usr/src/gemeinschaft/var/www/gemeinschaft
ln -snf /usr/src/gemeinschaft/var/www/.htaccess

# misc
#
cd /var/lib/
ln -snf /usr/src/gemeinschaft/var/lib/gemeinschaft


# gs-sip-ua-config-responder fuer Snom
#
if [ -e /usr/src/gemeinschaft/etc/init.d/gs-sip-ua-config-responder ]; then
	cd /etc/init.d/
	ln -snf /usr/src/gemeinschaft/etc/init.d/gs-sip-ua-config-responder
	update-rc.d gs-sip-ua-config-responder defaults 92 8
	invoke-rc.d gs-sip-ua-config-responder start
fi

# dialplan
#
/etc/init.d/asterisk stop || true
/opt/gemeinschaft/sbin/gs-ast-dialplan-gen
/etc/init.d/asterisk start || true

# cron jobs
#
cd /etc/cron.d/
ln -snf /usr/src/gemeinschaft/etc/cron.d/gs-cc-guardian || true
ln -snf /usr/src/gemeinschaft/etc/cron.d/gs-queuelog-to-db || true
ln -snf /usr/src/gemeinschaft/etc/cron.d/gs-queues-refresh || true

# delete example users, queues etc.
#
for user in "anna" "hans" "lisa" "peter"; do
	/opt/gemeinschaft/scripts/gs-user-del --user="${user}" 1>>/dev/null 2>>/dev/null || true
done
for queue in "5000"; do
	/opt/gemeinschaft/scripts/gs-queue-del --queue="${queue}" 1>>/dev/null 2>>/dev/null || true
done
mysql --batch --user=gemeinschaft --password="${GEMEINSCHAFT_DB_PASS}" -e \
	"USE \`asterisk\`; DELETE FROM \`phones\`;" 1>>/dev/null 2>>/dev/null || true


# Add an admin user
#

PIN=0
VPIN=1
NAME=0
VNAME=1
EXTEN=0
VEXTEN=1
LNAME=0
VLNAME=1
FNAME=1
VFNAME=0

echo "Info"
echo "===="
echo "Everything looks good. Now we need to configure a User account"
echo "which is going to have Admin rights. For security reasons we "
echo "do not have a default User activated."
echo ""
echo "DE: Zum Einloggen in Gemeinschaft benoetigen Sie einen Account."
echo "    Bitte beantworten Sie die folgenden Fragen. Danach koennen"
echo "    Sie sich dann mit diesem Account auf dem Webinterface einloggen."
echo ""

while ! [ "$NAME" = "$VNAME" ]
do
	echo "Please enter the username for your account"
	echo "(must be lowercase alphanumeric, and not \"admin\")"
	echo "[ENTER=administrator]: "
	read NAME
	if [ "x$NAME" = "x" ]; then
		NAME="administrator"
	fi
	if [ "$NAME" = "admin" ]; then
		echo "I said NOT \"admin\""
		NAME=0
	fi
	VNAME=`echo $NAME | grep -oE '[a-z]{2,20}'`
done

while ! [ "$EXTEN" = "$VEXTEN" ]
do
	echo "Please enter the extension for the admin account"
	echo "(must be numeric AND 2-10 numbers)"
	echo "[ENTER=123]: "
	read EXTEN
	if [ "x$EXTEN" = "x" ]; then
		EXTEN="123"
	fi
	VEXTEN=`echo $EXTEN | grep -oE '[0-9]{2,10}'`
done

while ! [ "$PIN" = "$VPIN" ]
do
	echo "Please enter the PIN number for the admin account"
	echo "(must be numeric AND 3-10 numbers)"
	echo "[ENTER=1234]: "
	read PIN
	if [ "x$PIN" = "x" ]; then
		PIN="1234"
	fi
	VPIN=`echo $PIN | grep -oE '[0-9]{4,10}'`
done

while ! [ "$FNAME" = "$VFNAME" ]
do
	echo "Please enter the real firstname for the admin account"
	echo "(must be alphanumeric)"
	echo "[ENTER=Example]: "
	read FNAME
	if [ "x$FNAME" = "x" ]; then
		FNAME="Example"
	fi
	VFNAME=`echo $FNAME | grep -oE '[a-zA-Z]{1,20}'`
done

while ! [ "$LNAME" = "$VLNAME" ]
do
	echo "Please enter the real lastname for the admin account"
	echo "(must be alphanumeric)"
	echo "[ENTER=Admin]: "
	read LNAME
	if [ "x$LNAME" = "x" ]; then
		LNAME="Admin"
	fi
	VLNAME=`echo $LNAME | grep -oE '[a-zA-Z0-9]{1,20}'`
done

echo ""
echo "Adding this user:"
echo "User:       $NAME"
echo "Extension:  $EXTEN"
echo "Pin:        $PIN"
echo "Firstname:  $FNAME"
echo "Lastname:   $LNAME"
echo ""

#TODO: Loop on error!
/opt/gemeinschaft/scripts/gs-user-add \
	--user="$NAME" \
	--ext="$EXTEN" \
	--pin="$PIN" \
	--firstname="$FNAME" \
	--lastname="$LNAME" \
	--email="" \
	--host=1 || true

#update gemeinschaft.php for this user
sed -i "s/\(^[\s#\/]*\$GUI_SUDO_ADMINS\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\1'${NAME}';/g" /etc/gemeinschaft/gemeinschaft.php

# dircolors
#
echo "" >> /root/.bashrc || true
echo "export LS_OPTIONS='--color=auto'" >> /root/.bashrc || true
echo "eval \"\`dircolors\`\"" >> /root/.bashrc || true
echo "alias ls='ls \$LS_OPTIONS'" >> /root/.bashrc || true
echo "alias l='ls \$LS_OPTIONS -lF'" >> /root/.bashrc || true
echo "alias ll='ls \$LS_OPTIONS -lFA'" >> /root/.bashrc || true
echo "" >> /root/.bashrc || true

# add /opt/gemeinschaft/scripts to PATH
#
echo "" >> /root/.bashrc || true
echo "export PATH=\"\$PATH:/opt/gemeinschaft/scripts\"" >> /root/.bashrc || true
echo "" >> /root/.bashrc || true

# motd
#
echo "***" > /etc/motd.static
echo "***    _____                                              _____" >> /etc/motd.static
echo "***   (.---.)       G E M E I N S C H A F T  ${GEMEINSCHAFT_VERS}       (.---.)" >> /etc/motd.static
echo "***    /:::\\ _.-----------------------------------------._/:::\\" >> /etc/motd.static
echo "***    -----                                              -----" >> /etc/motd.static
echo "***" >> /etc/motd.static
echo "***   Need help with Gemeinschaft? We have an excellent free mailinglist" >> /etc/motd.static
echo "***   and offer the best support and consulting money can buy. Have a" >> /etc/motd.static
echo "***   look at http://www.amooma.de/gemeinschaft/ for more information." >> /etc/motd.static
echo "***" >> /etc/motd.static
[ -e /etc/motd ] && rm -rf /etc/motd || true
ln -s /etc/motd.static /etc/motd

# checking out
#
wget -O - -T 30 "http://www.amooma.de/gemeinschaft/installer/checkout?mac=$MY_MAC_ADDR" >>/dev/null 2>>/dev/null || true

logger "Gemeinschaft ${GEMEINSCHAFT_VERS} has just been installed."

# warning
#
echo "Security Warning"
echo "================"
echo ""
echo "Never ever run this system outside of a save intranet "
echo "environment without doing some serious security auditing!"
echo "See /etc/gemeinschaft/gemeinschaft.php"
echo ""

# let's do some ASCII art
#
echo ""
echo "***"
echo "***    _____                                              _____"
echo "***   (.---.)       G E M E I N S C H A F T  ${GEMEINSCHAFT_VERS}       (.---.)"
echo "***    /:::\\ _.-----------------------------------------._/:::\\"
echo "***    -----                                              -----"
echo "***"
echo "***   Please fire up your webbrowser and login as user ${NAME}"
echo "***"
echo "***               http://${MY_IP_ADDR}/gemeinschaft/"
echo "***"
echo ""
exit 0

