#!/bin/bash

# (c) 2009 AMOOMA GmbH - http://www.amooma.de
# Alle Rechte vorbehalten. -- All rights reserved.
# $Revision: 297 $

LIBPRI_VERS="1.4.9"
ZAPTEL_VERS="1.4.12.1"
#ASTERISK_VERS="1.4.21.2"
#ASTERISK_VERS="1.4.21"
ASTERISK_VERS="1.4.19.2"
ASTERISK_ADDONS_VERS="1.4.7"
LAME_VERS="398-2"
GEMEINSCHAFT_VERS="2.3.0"
GEMEINSCHAFT_SIEMENS_VERS="trunk-r00358"
HYLAFAX_PLUS_VERS="5.2.9-1"
#WANPIPE_VERSION="3.3.15"


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

# list of SourceForge mirrors:
SOURCEFORGE_MIRRORS=""
SOURCEFORGE_MIRRORS="${SOURCEFORGE_MIRRORS} http://downloads.sourceforge.net/sourceforge"       #
SOURCEFORGE_MIRRORS="${SOURCEFORGE_MIRRORS} http://mesh.dl.sourceforge.net/sourceforge"         # de
SOURCEFORGE_MIRRORS="${SOURCEFORGE_MIRRORS} http://dfn.dl.sourceforge.net/sourceforge"          # de
SOURCEFORGE_MIRRORS="${SOURCEFORGE_MIRRORS} http://switch.dl.sourceforge.net/sourceforge"       # ch
SOURCEFORGE_MIRRORS="${SOURCEFORGE_MIRRORS} http://puzzle.dl.sourceforge.net/sourceforge"       # ch
SOURCEFORGE_MIRRORS="${SOURCEFORGE_MIRRORS} http://surfnet.dl.sourceforge.net/sourceforge"      # nl
SOURCEFORGE_MIRRORS="${SOURCEFORGE_MIRRORS} http://kent.dl.sourceforge.net/sourceforge"         # uk
SOURCEFORGE_MIRRORS="${SOURCEFORGE_MIRRORS} http://internap.dl.sourceforge.net/sourceforge"     # us
SOURCEFORGE_MIRRORS="${SOURCEFORGE_MIRRORS} http://superb-west.dl.sourceforge.net/sourceforge"  # us
SOURCEFORGE_MIRRORS="${SOURCEFORGE_MIRRORS} http://superb-east.dl.sourceforge.net/sourceforge"  # us
SOURCEFORGE_MIRRORS="${SOURCEFORGE_MIRRORS} http://garr.dl.sourceforge.net/sourceforge"         # it
SOURCEFORGE_MIRRORS="${SOURCEFORGE_MIRRORS} http://heanet.dl.sourceforge.net/sourceforge"       # ie
SOURCEFORGE_MIRRORS="${SOURCEFORGE_MIRRORS} http://optusnet.dl.sourceforge.net/sourceforge"     # au
SOURCEFORGE_MIRRORS="${SOURCEFORGE_MIRRORS} http://ufpr.dl.sourceforge.net/sourceforge"         # br
SOURCEFORGE_MIRRORS="${SOURCEFORGE_MIRRORS} http://jaist.dl.sourceforge.net/sourceforge"        # jp
SOURCEFORGE_MIRRORS="${SOURCEFORGE_MIRRORS} http://nchc.dl.sourceforge.net/sourceforge"         # tw

# setup basic stuff
#
clear
echo ""
echo "*** Status: A minimal Debian system has been installed."
echo "***         Now we start to install and setup stuff we need for"
echo "***         Gemeinschaft. Better get yourself a cup of coffee."
cat <<\HEREDOC

                   )
                  (
                      )
              ,.----------.
             ((|          |
            .--\          /--.
           '._  '========'  _.'
              `""""""""""""`

HEREDOC
sleep 1
echo "***"
echo "***  Setup basic stuff ..."
echo "***"
type apt-get 1>>/dev/null 2>>/dev/null
type aptitude 1>>/dev/null 2>>/dev/null || apt-get -y install aptitude
#APTITUDE_INSTALL="aptitude -y --allow-new-upgrades --allow-new-installs install"
APTITUDE_INSTALL="aptitude -y"
APTITUDE_REMOVE="aptitude -y purge"
if [[ `grep '5\.' /etc/debian_version` ]]; then
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
${APTITUDE_INSTALL} bind9 dnsutils
# install dnsutils so we can use dig later
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
if [[ `grep "OPTIONS" /etc/default/bind9 | grep -e "-4"` ]]; then
	echo "/etc/default/bind9 already has -4 option for named."
else
	sed -i 's/OPTIONS.*/OPTIONS="-4 -u bind"/' /etc/default/bind9
fi
/etc/init.d/bind9 restart
# try to fill the DNS cache to speed up things later:
for server in \
  "www.amooma.de" \
  "www.amooma.com" \
  "downloads.digium.com" \
  "downloads.sourceforge.net" \
  "0.debian.pool.ntp.org" \
  "1.debian.pool.ntp.org" \
  "ftp.de.debian.org" \
  "security.debian.org" \
  "ftp.debian.org" \
  "ftp.sangoma.com" \
  "example.com" \
  "example.net" \
  "example.org" \
; do
    dig +short ${server} >>/dev/null 2>>/dev/null &
    sleep 0.01 2>>/dev/null || true
done
sleep 1

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
	expect dialog logrotate hostname net-tools ifupdown iputils-ping netcat \
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
ntpdate 0.debian.pool.ntp.org || true
ntpdate 1.debian.pool.ntp.org || true
/etc/init.d/ntp start
sleep 3

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

# functions for installing ISDN/analog drivers
#
function setup_sangoma_a500 {
	echo "setup_sangoma_a500"
	cd /usr/src
	${DOWNLOAD} http://www.amooma.de/gemeinschaft/installer/a500-install-2.2.0.tar.gz || true
	tar xzf a500-install-2.2.0.tar.gz || true
	cd a500-install  || true
	bash setup_sangoma_a500.sh ${GEMEINSCHAFT_DB_PASS}
}

function setup_sangoma_b700 {
	echo "setup_sangoma_b700"
	cd /usr/src
	${DOWNLOAD} http://www.amooma.de/gemeinschaft/installer/b700-install-2.2.0.tar.gz || true
	tar xzf b700-install-2.2.0.tar.gz || true
	cd b700-install  || true
	bash setup_sangoma_b700.sh ${GEMEINSCHAFT_DB_PASS}
}


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

# download and build libpri
#
echo "***"
echo "***  Installing LibPRI ..."
echo "***"
cd /usr/src/
${DOWNLOAD} "http://downloads.digium.com/pub/libpri/releases/libpri-${LIBPRI_VERS}.tar.gz"
tar -xzf libpri-${LIBPRI_VERS}.tar.gz
rm -rf libpri-${LIBPRI_VERS}.tar.gz
cd libpri-${LIBPRI_VERS}
make clean && make && make install

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
cd

# install lame
#
echo "***"
echo "***  Installing Lame ..."
echo "***"
cd /usr/src/
#${DOWNLOAD} "http://downloads.sourceforge.net/sourceforge/lame/lame-${LAME_VERS}.tar.gz" || true
#if [ ! -s lame-${LAME_VERS}.tar.gz ]; then
#	echo "File not found - Use AMOOMA mirror to download Lame "
#	${DOWNLOAD} "http://www.amooma.de/gemeinschaft/download/lame-${LAME_VERS}.tar.gz" -O "lame-${LAME_VERS}.tar.gz"
#fi
SF_FILE="lame/lame-${LAME_VERS}.tar.gz"
OK=0
for SF_MIRROR in $SOURCEFORGE_MIRRORS; do
	echo "Fetching ${SF_MIRROR}/${SF_FILE} ..."
	${DOWNLOAD} "${SF_MIRROR}/${SF_FILE}" && err=$? || err=$?
	if [ "x$err" == "x0" ]; then
		OK=1
		break
	fi
done
if [ "x$OK" != "x1" ]; then
	echo "No more mirrors to try." >&2
	echo "Failed to download ${SF_FILE} from SourceForge!" >&2
	err
fi

tar -xzf lame-${LAME_VERS}.tar.gz
rm -rf lame-${LAME_VERS}.tar.gz
cd lame-${LAME_VERS}
./configure && make clean && make && make install
rm -rf /usr/src/lame-${LAME_VERS}
cd

# install misc packages
#
echo "***"
echo "***  Installing other packages ..."
echo "***"
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
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
cd de-DE-tts
/opt/gemeinschaft/sbin/sounds-wav-to-alaw.sh
rm *.wav || true


# MySQL: add gemeinschaft user
#
echo "***"
echo "***  Creating Gemeinschaft database ..."
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
mysql --batch --user=gemeinschaft --password="${GEMEINSCHAFT_DB_PASS}" -e "SELECT 'test'" > /dev/null

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
a2enmod rewrite
a2enmod alias
a2enmod mime
a2enmod php5
a2enmod headers || true

# PHP-APC
#
echo "***"
echo "***  Installing PHP-APC ..."
echo "***"
${APTITUDE_INSTALL} php-apc
aptitude clean

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
#ln -snf /usr/src/gemeinschaft/etc/gemeinschaft
mkdir -p /etc/gemeinschaft
cd /etc/gemeinschaft
if [ ! -e gemeinschaft.php ]; then
	cp /usr/src/gemeinschaft/etc/gemeinschaft/gemeinschaft.php ./
fi
mkdir -p /etc/gemeinschaft/asterisk
cd /etc/gemeinschaft/asterisk
cp /usr/src/gemeinschaft/etc/gemeinschaft/asterisk/* ./

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

sed -i "s/\(^[\s#\/]*\)\(\$FAX_ENABLED\s*=\s*\)\([A-Za-z0-9']\)*\s*;/\2true;/g" /etc/gemeinschaft/gemeinschaft.php
sed -i "s/\(^[\s#\/]*\)\(\$FAX_PREFIX\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\2'*96';/g" /etc/gemeinschaft/gemeinschaft.php
sed -i "s/\(^[\s#\/]*\)\(\$FAX_TSI_PREFIX\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\2'';/g" /etc/gemeinschaft/gemeinschaft.php
sed -i "s/\(^[\s#\/]*\)\(\$FAX_TSI\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\2 @\$CANONIZE_NATL_PREFIX.@\$CANONIZE_AREA_CODE.@\$CANONIZE_LOCAL_BRANCH.'0';/g" /etc/gemeinschaft/gemeinschaft.php
sed -i "s/\(^[\s#\/]*\)\(\$FAX_HYLAFAX_HOST\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\2'127.0.0.1';/g" /etc/gemeinschaft/gemeinschaft.php
sed -i "s/\(^[\s#\/]*\)\(\$FAX_HYLAFAX_PORT\s*=\s*\)\([0-9']\)*\s*;/\2 4559;/g" /etc/gemeinschaft/gemeinschaft.php

HFAXADM_PASS=`head -c 20 /dev/urandom | md5sum -b - | cut -d ' ' -f 1 | head -c 12`

sed -i "s/\(^[\s#\/]*\)\(\$FAX_HYLAFAX_ADMIN\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\2'hfaxadm';/g" /etc/gemeinschaft/gemeinschaft.php
sed -i "s/\(^[\s#\/]*\)\(\$FAX_HYLAFAX_PASS\s*=\s*\)\([\"']\)[^\"']*[\"']\s*;/\2'${HFAXADM_PASS}';/g" /etc/gemeinschaft/gemeinschaft.php

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


# Identify Sangoma cards and install Wanpipe
#
cd /usr/src
[ -e zaptel ] && rm -f zaptel || true
[ -e asterisk ] && rm -f asterisk || true
ln -snf zaptel-${ZAPTEL_VERS} zaptel
ln -snf asterisk-${ASTERISK_VERS} asterisk

# Detect A500
CARD=""
CARD=$(lspci -m -n -D -d '1923:' | cut -d' ' -f 5 | grep -oEie '[0-9a-f]{4}' | grep -i 'a500' ; echo x)
if [ "x${CARD}" != "xx" ]; then
	echo "Sangoma A500 card detected."
	echo "I will configure this card for you ..."
	setup_sangoma_a500
fi
#else
#	# Detect B700
#	CARD=""
#	CARD=$(lspci -m -n -D -d '1923:' | cut -d' ' -f 5 | grep -oEie '[0-9a-f]{4}' | grep -i 'a700' ; echo x)
#	if [ "x${CARD}" != "xx" ]; then
#		echo "Sangoma B700 card detected."
#		echo "I will configure this card for you ..."
#		setup_sangoma_b700
#	else
#		echo "No supported Sangoma cards detected, continuing without Wanpipe."
#	fi
#fi

# remove sources
#
rm -rf /usr/src/libpri-${LIBPRI_VERS} || true
rm -rf /usr/src/zaptel-${ZAPTEL_VERS} || true
rm -rf /usr/src/asterisk-${ASTERISK_VERS} || true
rm -rf /usr/src/asterisk-addons-${ASTERISK_ADDONS_VERS} || true
rm -f  /usr/src/asterisk || true
rm -f  /usr/src/zaptel || true

# remove build environment 
#
echo "***"
echo "***  Removing build environment  ..."
echo "***"
${APTITUDE_REMOVE} linux-headers-`uname -r` linux-kernel-headers
${APTITUDE_REMOVE} bison byacc flex libnewt-dev ncurses-dev libncurses-dev zlib1g-dev libmysqlclient15-dev

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

# fax installation starts here
#
HF_CONF_SRC="/usr/share/doc/gemeinschaft/misc/fax-integration"

echo "***"
echo "***  Installing HylaFax+ dependencies ..."
echo "***"
${APTITUDE_INSTALL} libtiff4 libtiff-tools sharutils gs-gpl gsfonts iaxmodem

echo "***"
echo "***  Installing HylaFax+ ..."
echo "***"
cd /usr/src/
# ${DOWNLOAD} "http://downloads.sourceforge.net/hylafax/hylafax_${HYLAFAX_PLUS_VERS}_i386.deb" || true
#if [ ! -s hylafax_${HYLAFAX_PLUS_VERS}_i386.deb ]; then
#	echo "File not found - Use AMOOMA mirror to download HylaFax+ "
#	${DOWNLOAD} "http://www.amooma.de/gemeinschaft/download/hylafax_${HYLAFAX_PLUS_VERS}_i386.deb" -O "hylafax_${HYLAFAX_PLUS_VERS}_i386.deb"
#fi
SF_FILE="hylafax/hylafax_${HYLAFAX_PLUS_VERS}_i386.deb"
OK=0
for SF_MIRROR in $SOURCEFORGE_MIRRORS; do
	echo "Fetching ${SF_MIRROR}/${SF_FILE} ..."
	${DOWNLOAD} "${SF_MIRROR}/${SF_FILE}" && err=$? || err=$?
	if [ "x$err" == "x0" ]; then
		OK=1
		break
	fi
done
if [ "x$OK" != "x1" ]; then
	echo "No more mirrors to try." >&2
	echo "Failed to download ${SF_FILE} from SourceForge!" >&2
	err
fi

if [[ `grep '5\.' /etc/debian_version` ]]; then
	# The HylaFax+ package from SourceForge depends on libldap2
	# which is expected to contain /usr/lib/libldap_r.so.2 and
	# /usr/lib/liblber.so.2
	# However that package is called libldap-2.4-2 on Lenny.
	#
	${APTITUDE_INSTALL} libldap-2.4-2
	echo "Create links needed by HylaFax on Debian 5 (Lenny) ..."
	cd /usr/lib/
	ln -s libldap_r-2.4.so.2 libldap_r.so.2
	ln -s liblber-2.4.so.2 liblber.so.2
	
	# download empty libldap2 package
	cd /usr/src/
	${DOWNLOAD} "http://www.amooma.de/gemeinschaft/download/libldap2-compat_2.4.11-1_all.deb"
	dpkg -i "libldap2-compat_2.4.11-1_all.deb"
	rm -f "libldap2-compat_2.4.11-1_all.deb" || true
	dpkg --ignore-depends=libldap2 -i "hylafax_${HYLAFAX_PLUS_VERS}_i386.deb"
	# do we still need --ignore-depends=libldap2 ?
else
	dpkg -i "hylafax_${HYLAFAX_PLUS_VERS}_i386.deb"
fi
rm -f "hylafax_${HYLAFAX_PLUS_VERS}_i386.deb" || true

# make tmp directory world accessible
chmod 777 /var/spool/hylafax/tmp/

# sudo permissions for FaxDispatch
#
echo "uucp ALL = NOPASSWD: /bin/chgrp" >> /etc/sudoers

echo "***"
echo "***  Creating initial configuration ..."
echo "***"

# run HylaFax config script
#
/usr/sbin/faxsetup -nointeractive

# fax modem config
#
cp "${HF_CONF_SRC}/config.ttyIAX0" /var/spool/hylafax/etc/config.ttyIAX0
cp "${HF_CONF_SRC}/config.ttyIAX0" /var/spool/hylafax/etc/config.ttyIAX1

# fax daemon config
#
cp "${HF_CONF_SRC}/hfaxd.conf" /etc/hylafax/hfaxd.conf

# fax dispatch config
#
cp "${HF_CONF_SRC}/FaxDispatch" /var/spool/hylafax/etc/

# iaxmodem config
#
cp "${HF_CONF_SRC}/ttyIAX0" /etc/iaxmodem/ttyIAX0
cp "${HF_CONF_SRC}/ttyIAX1" /etc/iaxmodem/ttyIAX1

# add iaxmodem entries to iax.conf
#
cat "${HF_CONF_SRC}/iax.conf.template" >> /opt/gemeinschaft/etc/asterisk/iax.conf

# add faxgetty entries to inittab
#
echo "" >> /etc/inittab 
echo "# HylaFAX+ getty" >> /etc/inittab
echo "mo00:23:respawn:/usr/sbin/faxgetty ttyIAX0" >> /etc/inittab
echo "mo01:23:respawn:/usr/sbin/faxgetty ttyIAX1" >> /etc/inittab

# Add an admin user
#

PIN="0000"
VPIN=1
NAME="muster"
VNAME=1
EXTEN="200"
VEXTEN=1
LNAME="Muster"
VLNAME=1
FNAME="Heino"
VFNAME=0

INPUT_OK="Empty"
while ! [ "$INPUT_OK" = "OK" ]
do
	INPUT_COUNT=0
	while ! [ $INPUT_COUNT = 5 ]
	do
		dialog --nocancel --form "Bitte konfigurieren Sie einen User fuer Gemeinschaft:\nPlease configure a user for Gemeinschaft:" 12 90 6 \
			"Benutzername / Username " 1 2 "$NAME" 1 38 20 20\
			"Vorname / Firstname"                             2 2 "$FNAME" 2 38 20 20\
			"Nachname / Lastname"                            3 2 "$LNAME" 3 38 20 20\
			"PIN (Passwort) / PIN (Password)"                    4 2 "$PIN" 4 38 10 10\
			"Nebenstelle / Extension"              5 2 "$EXTEN" 5 38 10 10\
			2> ~/tmp.$$
		if [ ${?} -ne 0 ]; then return; fi
		result=$(cat ~/tmp.$$)
		rm ~/tmp.$$
		
		INPUT_COUNT=`echo $result | wc -w`
		if [ $INPUT_COUNT != "5" ]; then
			dialog --msgbox "Fehler / Error!" 5 60
		fi
	done
	
	INPUT_OK="OK"
	
	trap cleanup ERR
	
	NAME=`echo $result | awk '{print $1}'`
	VNAME=`echo $NAME | grep -oE '[a-z]{2,20}'`
	
	if [ "$NAME" = "admin" ]; then
		dialog --msgbox "Sorry, aber \"admin\" ist als Benutzername nicht erlaubt." 10 60
		NAME="muster"
		INPUT_OK="FAIL"
	fi
	
	if [ "x$NAME" != "x$VNAME" ]; then
		dialog --msgbox "Der Benutzername darf nur Kleinbuchstaben enthalten!" 10 60
		NAME=""
		INPUT_OK="FAIL"
	fi
	
	EXTEN=`echo $result | awk '{print $5}'`
	VEXTEN=`echo $EXTEN | grep -oE '[0-9]{2,10}'`
	
	if [ "x$EXTEN" != "x$VEXTEN" ]; then
		dialog --msgbox "Die Nebenstelle darf nur Ziffern enthalten!" 10 60
		EXTEN=""
		INPUT_OK="FAIL"
	fi
	
	PIN=`echo $result | awk '{print $4}'`
	VPIN=`echo $PIN | grep -oE '[0-9]{4,10}'`

	if [ "x$PIN" != "x$VPIN" ]; then
		dialog --msgbox "Die PIN darf nur Ziffern enthalten und muss 4 bis 10 Zeichen lang sein!" 10 60
		PIN=""
		INPUT_OK="FAIL"
	fi
	
	FNAME=`echo $result | awk '{print $2}'`
	VFNAME=`echo $FNAME | grep -oE '[a-zA-Z0-9]{1,20}'`
	
	if [ "x$FNAME" != "x$VFNAME" ]; then
		dialog --msgbox "Der Vorname darf keine Sonderzeichen enthalten!" 10 60
		FNAME=""
		INPUT_OK="FAIL"
	fi
	
	LNAME=`echo $result | awk '{print $3}'`
	VLNAME=`echo $LNAME | grep -oE '[a-zA-Z0-9]{1,20}'`
	
	if [ "x$LNAME" != "x$VLNAME" ]; then
		dialog --msgbox "Der Nachname darf keine Sonderzeichen enthalten!" 10 60
		LNAME=""
		INPUT_OK="FAIL"
	fi
	
	trap "err; exit 1" ERR
	
done

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

echo "***"
echo "***  Restarting services ..."
echo "***"

# stop services
#
/etc/init.d/hylafax stop  || true
/etc/init.d/iaxmodem stop || true

# dialplan
#
/etc/init.d/asterisk stop || true
/opt/gemeinschaft/sbin/gs-ast-dialplan-gen
/etc/init.d/asterisk start || true

# start services
#
/etc/init.d/hylafax start  || true
/etc/init.d/iaxmodem start || true
/sbin/init q

# updating authentication file
#
/opt/gemeinschaft/sbin/gs-hylafax-auth-update || true

# check out
#
wget -O - -T 30 "http://www.amooma.de/gemeinschaft/installer/checkout?mac=$MY_MAC_ADDR" >>/dev/null 2>>/dev/null || true

logger "Gemeinschaft ${GEMEINSCHAFT_VERS} has just been installed."

# warning
#
clear
echo "Security Warning"
echo "================"
echo ""
echo "Never ever run this system outside of a safe intranet "
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
echo "***   Please fire up your webbrowser and log in as \"${NAME}\""
echo "***"
echo "***               http://${MY_IP_ADDR}/gemeinschaft/"
echo "***"
echo ""
exit 0

