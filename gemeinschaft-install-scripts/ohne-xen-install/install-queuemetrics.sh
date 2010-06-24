#!/bin/bash

# (c) 2009 AMOOMA GmbH - http://www.amooma.de
# Alle Rechte vorbehalten. -- All rights reserved.
# $Revision: 337 $

GEMEINSCHAFT_VERS="2.3.1"

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

# do nothing if QM has already been installed
#
if [ -e /var/lib/tomcat5.5/webapps/queuestat/ ]; then
	echo "QueueMetrics has already been installed." >&2
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
clear
echo ""
if [ -e /opt/gemeinschaft/ ]; then
	echo "*** Status: A Gemeinschaft system has been installed."
else
	echo "*** Status: A Gemeinschaft system has not been installed."
fi
echo "***         Now we start to install and setup QueueMetrics."
echo "***         This will take some time." 
echo "***         Better get yourself a whole pot of coffee or walk your dog."	

echo "***"
echo "***  Setup basic stuff ..."
echo "***"
export DEBIAN_FRONTEND=dialog
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

echo "***"
echo "***  Setting Repositories ..."
echo "***"

echo "" >>/etc/apt/sources.list
echo "deb http://ftp.de.debian.org/debian/ lenny main contrib non-free" >>/etc/apt/sources.list
echo "deb-src http://ftp.de.debian.org/debian/ lenny main contrib non-free" >>/etc/apt/sources.list

apt-get -y update

echo "***"
echo "***  Installing Java ..."
echo "***"
PACKAGE_INSTALLED="no"

while ! [ "$PACKAGE_INSTALLED" = "installed" ]
do
        ${APTITUDE_INSTALL} sun-java5-jdk || true

	RESULT=`dpkg-query -W -f='${Status}' sun-java5-jdk`
	PACKAGE_INSTALLED=`echo $RESULT | awk  '{print $3}'`

        if  [ ! "$PACKAGE_INSTALLED" = "installed" ]; then
		echo "ERROR: Java not installed !"
        	sleep 4
	fi
done

update-alternatives --config java
update-alternatives --config javac


echo "***"
echo "***  Installing Tomcat ..."
echo "***"
${APTITUDE_INSTALL} tomcat5.5 tomcat5.5-admin tomcat5.5-webapps

# set TOMCAT5_SECURITY to "no"
sed -i "s/TOMCAT5_SECURITY=yes/TOMCAT5_SECURITY=no/g" /etc/init.d/tomcat5.5 || true

echo "***"
echo "***  Installing Apach mod_jk ..."
echo "***"
${APTITUDE_INSTALL} libapache2-mod-jk

cat <<\ENDCONFFILE >/etc/apache2/workers.properties
workers.tomcat_home=/usr/share/tomcat5.5/
workers.java_home=/usr/lib/jvm/java-1.5.0-sun
ps=/
worker.list=mainworker
worker.mainworker.type=ajp13
worker.mainworker.host=localhost
worker.mainworker.port=8009
worker.mainworker.cachesize=20
ENDCONFFILE

cat <<\ENDCONFFILE >/etc/apache2/mods-available/jk.conf
<IfModule mod_jk.c>
JkWorkersFile /etc/apache2/workers.properties
JkLogFile /var/log/apache2/mod_jk.log
JkLogLevel error
</IfModule>
ENDCONFFILE

cd /etc/apache2/mods-enabled
ln -s ../mods-available/jk.conf jk.conf

cat <<\ENDCONFFILE >/etc/apache2/sites-available/gemeinschaft
<VirtualHost *:80>
        ServerAdmin webmaster@localhost

        DocumentRoot /var/www/
        <Directory />
                Options FollowSymLinks
                AllowOverride None
        </Directory>
        <Directory /var/www/>
                Options FollowSymLinks
                AllowOverride All
                Order allow,deny
                Allow from all
        </Directory>

        ErrorLog /var/log/apache2/error.log

        # Possible values include: debug, info, notice, warn, error, crit,
        # alert, emerg.
        LogLevel warn

        CustomLog /var/log/apache2/access.log combined

        Alias /queuestat/ "/usr/share/tomcat5.5/webapps/queuestat/"
        <Directory "/usr/share/tomcat5.5/webapps/queuestat/">
        Options Indexes +FollowSymLinks
        </Directory>
        JkMount /queuestat/* mainworker

</VirtualHost>
ENDCONFFILE

mkdir /var/www/queuestat || true
mkdir /var/www/queuemetrics || true
mkdir /var/www/queuestats || true

cat <<\ENDCONFFILE >/var/www/queuemetrics/index.html
<html>
        <head>
                <meta http-equiv="Refresh" content="0; url=/queuestat/">
        </head>
        <body>
                <p>Redirecting to <a href="/queuestat/">QueueStat</a></p>
        </body>
</html>
ENDCONFFILE

cp /var/www/queuemetrics/index.html /var/www/queuestats/index.html || true

echo "***"
echo "***  Installing QueueMetrics ..."
echo "***"
cd /var/lib/tomcat5.5/webapps

#wget http://queuemetrics.com/download/QueueMetrics-1.5.4-trial.tar.gz
#tar -xzf QueueMetrics-1.5.4-trial.tar.gz

wget http://www.amooma.de/gemeinschaft/download/QueueMetrics-1.5.4-Gemeinschaft-trial.tar.gz
tar -xzf QueueMetrics-1.5.4-Gemeinschaft-trial.tar.gz

if [ ! -e  queuemetrics-1.5.4 ]; then
	ERRMSG="QueueMetrics directory not found."
	err 
fi

mv queuemetrics-1.5.4 queuestat
cd /var/lib/tomcat5.5/webapps/queuestat/WEB-INF/lib/
wget http://mirrors.uol.com.br/pub/mysql/Downloads/Connector-J/mysql-connector-java-5.0.5.tar.gz
tar -xvzf mysql-connector-java-5.0.5.tar.gz
cp mysql-connector-java-5.0.5/mysql-connector-java-5.0.5-bin.jar /var/lib/tomcat5.5/webapps/queuestat/WEB-INF/lib/

echo "***"
echo "***  Setting up QueueMetrics database ..."
echo "***"

QM_DB_PASS=`head -c 20 /dev/urandom | md5sum -b - | cut -d ' ' -f 1 | head -c 30`

mysqladmin create queuemetrics
mysql --execute="GRANT ALL PRIVILEGES ON \`queuemetrics\`.* TO 'queuemetrics'@'localhost' IDENTIFIED BY '${QM_DB_PASS}'"
mysql --execute="FLUSH PRIVILEGES"

sed -i "s/password=javadude/password=${QM_DB_PASS}/g" /var/lib/tomcat5.5/webapps/queuestat/WEB-INF/web.xml || true

cd /var/lib/tomcat5.5/webapps/queuestat/WEB-INF/README/
wget http://www.amooma.de/gemeinschaft/download/queuemetrics.sql.gz
gzip -fd queuemetrics.sql.gz

mysql --user=queuemetrics --password=${QM_DB_PASS} queuemetrics < queuemetrics.sql

echo "***"
echo "***  Restarting Tomcat Service ..."
echo "***"
/etc/init.d/tomcat5.5 restart


echo "***"
echo "***  Creating configuration ..."
echo "***"

# Create some example users in QM 
ADMIN_NAME="admin"
ADMIN_FNAME="System"
ADMIN_LNAME="Administrator"
ADMIN_EXTEN="9999"

USER_NAME="user"
USER_FNAME="Ordinary"
USER_LNAME="User"
USER_EXTEN="9998"

SQL_RESULT=$(mysql -Dasterisk --execute="SELECT \`secret\` FROM \`ast_sipfriends\` WHERE \`name\` IN ('$ADMIN_EXTEN', '$USER_EXTEN')" );
ADMIN_SIPPW=`echo $SQL_RESULT | awk  '{print $2}'`
USER_SIPPW=`echo $SQL_RESULT | awk  '{print $3}'`

SQL_RESULT=$(mysql -Dasterisk --execute="SELECT \`pin\` FROM \`users\` WHERE \`user\` IN ('$ADMIN_NAME', '$USER_NAME')" );
ADMIN_PIN=`echo $SQL_RESULT | awk  '{print $2}'`
USER_PIN=`echo $SQL_RESULT | awk  '{print $3}'`

mysql -Dqueuemetrics --execute="UPDATE \`arch_users\` SET \`PASSWORD\`='${USER_PIN}'"
mysql -Dqueuemetrics --execute="UPDATE \`arch_users\` SET \`PASSWORD\`='${ADMIN_PIN}' WHERE \`login\` = 'admin'"

MY_IP_ADDR=`LANG=C ifconfig | grep inet | grep -v 'inet6' | grep -v '127\.0\.0\.1' | head -n 1 | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -v '^255' | head -n 1`

if [ "x$?" != "x0" ] || [ -z ${MY_IP_ADDR} ]; then
        echo "***** Failed to find your IP address." 2>&1
        MY_IP_ADDR="localhost"
fi

# remove queuelog database updating script and queue statisctics from Gemeinschaft
#
rm /etc/cron.d/gs-queuelog-to-db || true
sed -i "s/'qclassical'/\/\/'qclassical'/g" /opt/gemeinschaft/htdocs/gui/inc/modules.php || true

# create example queue
#
/opt/gemeinschaft/scripts/gs-queue-add --queue=5000 --title="Test Queue" --maxlen=100 --host=1 || true

echo "***"
echo "***  Restarting Apache ..."
echo "***"
/etc/init.d/apache2 restart

echo "***"
echo "***  QueueMetrics installed !"
echo "***"

# let's do some ASCII art
#
clear
echo "**************************************************************************"
echo "***                 G E M E I N S C H A F T   ${GEMEINSCHAFT_VERS}"
echo "***"
echo "***   Use your admin account \"${ADMIN_NAME}\" and PIN \"${ADMIN_PIN}\" to log into the GUI at"
echo "***     http://${MY_IP_ADDR}/gemeinschaft/"
echo "***   and to log into QueueMetrics at"
echo "***     http://${MY_IP_ADDR}/queuestat/"
echo "***"
echo "***   Use these SIP accounts to setup your first two phones:"
echo "***"
echo "***                      (.---.)                 (.---.)"
echo "***                       /:::\\ _.--------------._/:::\\"
echo "***                       -----                   -----"
echo "***"
echo "***     SIP Username :    $(printf "% -5s" $ADMIN_EXTEN)                   $(printf "% -5s" $USER_EXTEN)"
echo "***     SIP Password :    $(printf "% -20s" $ADMIN_SIPPW)    $(printf "% -20s" $USER_SIPPW)"
echo "***     SIP Server   :    $(printf "% -15s" $MY_IP_ADDR)         $(printf "% -15s" $MY_IP_ADDR)"
echo "***"
echo "***   Find mailinglists and more info at"
echo "***     http://www.amooma.de/gemeinschaft/"
echo "**************************************************************************"
exit 0
