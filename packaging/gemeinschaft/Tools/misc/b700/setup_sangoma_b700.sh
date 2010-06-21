#!/bin/bash

# (c) 2009 AMOOMA GmbH - http://www.amooma.de
# Alle Rechte vorbehalten. -- All rights reserved.
# $Revision: 205 $


WANPIPE_VERSION="3.5.0.10"

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

CUR_PATH=`pwd`


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

${APTITUDE_INSTALL} udev lksctp-tools libsctp-dev linux-headers-`uname -r` build-essential libncurses5-dev flex bison bzip2 expect dialog
aptitude clean

# installs the Wanpipe drivers and configure the Sangoma cards
cd /usr/src
wget ftp://ftp.sangoma.com/linux/custom/DavidYS/wanpipe-$WANPIPE_VERSION.tgz || true
tar xvf wanpipe-$WANPIPE_VERSION.tgz || true
cd wanpipe-$WANPIPE_VERSION || true

asterisk -rx "stop now" || true

make && make install

# linking woomera.conf
ln -s /etc/asterisk/woomera.conf /opt/gemeinschaft/etc/asterisk/

echo n | ./Setup install --silent --protocol=TDM-SMG-BRI || true

# re compile an re install zaptel

cd /usr/src/zaptel/ && make clean && make && make install

sleep 2

_temp="/tmp/answer.$$"

# get Port count
PORTS=$(wanrouter hwprobe | grep AFT-B700-SH | wc -l >&1)
let PORTS=PORTS-1
COUNTER=0
while [ $COUNTER -lt $PORTS  ]; do
	let SHOW_PORT=COUNTER+1
	dialog --backtitle "Point to Point/Multipoint Configuration" --title "Please Choose for Port $SHOW_PORT" --no-cancel \
		--menu "Move using [UP] [DOWN], [Enter] to select" 17 60 10 \
		0 "Point to multipoint" \
		1 "Point to point" \
		2>$_temp
	
	menuitem=`cat $_temp`
	
	#ptp=$ptp" "$menuitem
	ptp="$ptp $menuitem"
	let COUNTER=COUNTER+1
done

cd $CUR_PATH
./setup.expect $ptp

# Add start/stop links
update-rc.d -f smg_ctrl remove
ln -s /usr/sbin/smg_ctrl /etc/init.d/
update-rc.d smg_ctrl defaults 16 20

# add Ports to Gemeinschaft as Gateways
echo "Adding Sangoma B700-Ports to Gemeinschaft"
COUNTER=0
while [ $COUNTER -lt $PORTS  ]; do
  let SHOW_PORT=COUNTER+1
  echo "INSERT INTO \`gates\` (\`type\`, \`name\`, \`title\`, \`allow_out\`, \`dialstr\`) VALUES ('zap', 'Sangoma B700 $SHOW_PORT', 'Port $SHOW_PORT', 1 , 'WOOMERA/g$SHOW_PORT/{number}');" >> /tmp/gs_sangoma_a500_gw.sql
  let COUNTER=COUNTER+1
done

# Add devices for the Analog Ports!
echo "INSERT INTO \`gates\` (\`type\`, \`name\`, \`title\`, \`allow_out\`, \`dialstr\`) VALUES ('zap', 'Sangoma B700 Analog 1', 'Port 1', 1 , 'Zap/g1/{number}');" >> /tmp/gs_sangoma_a500_gw.sql
echo "INSERT INTO \`gates\` (\`type\`, \`name\`, \`title\`, \`allow_out\`, \`dialstr\`) VALUES ('zap', 'Sangoma B700 Analog 2', 'Port 2', 1 , 'Zap/g2/{number}');" >> /tmp/gs_sangoma_a500_gw.sql

mysql asterisk --batch --user=gemeinschaft --password="$1" < /tmp/gs_sangoma_a500_gw.sql






