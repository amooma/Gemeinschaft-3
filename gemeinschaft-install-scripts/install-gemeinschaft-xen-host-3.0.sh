#!/bin/bash

### BEGIN INIT INFO
# Provides:          install-gemeinschaft-xen-host
# Required-Start:    $network $syslog $named $local_fs $remote_fs $all
# Required-Stop:     $network $syslog $named $local_fs $remote_fs
# Should-Start:      rc.local xend xendomains
# Should-Stop:       rc.local xend xendomains
# X-Interactive:     true
# Default-Start:     2
# Default-Stop:      
# Short-Description: Gemeinschaft Xen host installer
# Description:       Gemeinschaft Xen host installer
### END INIT INFO


# (c) 2009-2010 AMOOMA GmbH - http://www.amooma.de
# Alle Rechte vorbehalten. -- All rights reserved.

# Dieses Skript wird als preseed/late_command von
# preseed-3.0-xen-host.cfg aufgerufen.
# Zweck: Installation des Xen-Host-Systems (dom0).

if [ "-$1" != "-start" ]; then
	exit 0
fi


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

type apt-get 1>>/dev/null 2>>/dev/null
type aptitude 1>>/dev/null 2>>/dev/null || apt-get -y install aptitude
#APTITUDE_INSTALL="aptitude -y --allow-new-upgrades --allow-new-installs install"
APTITUDE_INSTALL="aptitude -y"
APTITUDE_REMOVE="aptitude -y purge"
APTITUDE_INSTALL="${APTITUDE_INSTALL} --allow-new-upgrades --allow-new-installs"
APTITUDE_INSTALL="${APTITUDE_INSTALL} install"
#echo "APTITUDE_INSTALL = ${APTITUDE_INSTALL}"


# very cheap hack to wait for the DHCP-client
#
COUNTER=0
while [  $COUNTER -lt 10 ]; do
    echo -n "."
    sleep 1
    let COUNTER=COUNTER+1
done
echo ""

# update package lists
#
echo ""
echo "***"
echo "***  Updating package lists ..."
echo "***"
aptitude update




if ! uname -r | grep xen
then
	# Xen kernel not running.
	# Install basic stuff and Xen ...
	
	
	# install and configure local nameserver
	#
	echo ""
	echo "***"
	echo "***  Installing local caching nameserver ..."
	echo "***"
	${APTITUDE_INSTALL} bind9 dnsutils
	# install dnsutils so we can use dig later
	#aptitude clean
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
	  "downloads.asterisk.org" \
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
	while ! ( wget -O - -T 30 --spider http://www.amooma.de/ >>/dev/null ); do sleep 5; done
	
	MY_MAC_ADDR=`LANG=C ifconfig | grep -oE '[0-9a-fA-F]{1,2}\:[0-9a-fA-F]{1,2}\:[0-9a-fA-F]{1,2}\:[0-9a-fA-F]{1,2}\:[0-9a-fA-F]{1,2}\:[0-9a-fA-F]{1,2}' | head -n 1`
	wget -O - -T 30 --spider http://www.amooma.de/gemeinschaft/installer/checkin?mac=$MY_MAC_ADDR >>/dev/null 2>>/dev/null || true
	
	
	# install basic stuff
	#
	echo ""
	echo "***"
	echo "***  Installing basic stuff ..."
	echo "***"
	${APTITUDE_INSTALL} \
		coreutils lsb-base grep findutils sudo wget curl cron \
		expect dialog logrotate hostname net-tools ifupdown iputils-ping netcat \
		openssh-client openssh-server \
		udev psmisc dnsutils iputils-arping pciutils bzip2 \
		console-data console-tools \
		vim less
	#aptitude clean
	
	
	# now that we have vim, enable syntax highlighting by default:
	if [ `which vim` ]; then
		sed -i -r -e 's/^"(syntax) on/\1 on/' /etc/vim/vimrc || true
	fi
	
	# set EDITOR to "vim"
	if [ `which vim` ]; then
		echo "" >> /root/.bashrc || true
		echo "export EDITOR=\"vim\"" >> /root/.bashrc || true
		echo "" >> /root/.bashrc || true
		#if [ "x${SHELL}" = "x/bin/bash" ]; then
		#	source /root/.bashrc
		#fi
	fi
	
	# and add ls colors and some useful bash aliases:
	cat <<\HEREDOC >> /root/.bashrc

export LS_OPTIONS='--color=auto'
eval "`dircolors`"
alias ls='ls $LS_OPTIONS'
alias l='ls $LS_OPTIONS -lF'
alias ll='ls $LS_OPTIONS -lFA'

HEREDOC
	#if [ "x${SHELL}" = "x/bin/bash" ]; then
	#	source /root/.bashrc
	#fi
	
	
	
	# Input box for the license key.
	# At this point this is not meant as a security measure but mainly
	# to avoid invalid keys early in the installation process.
	
	LICENSE_KEY=""
	INPUT_OK="NO"
	while ! [ "$INPUT_OK" = "OK" ]; do
		dialog --nocancel \
		  --title "Lizenz-Schluessel / License Key" \
		  --form \
		  "\nBitte geben Sie den Lizenz-Schluessel fuer Gemeinschaft ein:\nPlease enter the license key for Gemeinschaft:" 11 68 2 \
		  "Lizenz-Schluessel:" 1 2 "${LICENSE_KEY}" 1 24 35 32 \
		  2> ~/dialog-tmp.$$
		
		if [ ${?} -ne 0 ]; then sleep 1; continue; fi
		
		clear
		
		LICENSE_KEY=$( cat ~/dialog-tmp.$$| tail -n +1 | head -n 1 )
		rm ~/dialog-tmp.$$
		
		LICENSE_KEY=`echo $LICENSE_KEY | sed -e 's/ /-/g' | grep -aoE '[0-9a-zA-Z\-]{1,50}'`
			
		if [ -z $LICENSE_KEY ]; then sleep 1; continue; fi
		
		dialog --infobox "Lizenz-Schlüssel wird überprüft ..." 6 60
		sleep 1
		check_result=`wget -q -O - -T 40 "http://www.kempgen.net/tmp/gemeinschaft-amooma/xen/license-check?key=${LICENSE_KEY}"`
		if ! echo $check_result | grep -i CHECK 1>>/dev/null 2>>/dev/null
		then
			sleep 1
			dialog --msgbox "Der Lizenz-Schlüssel konnte nicht überprüft werden." 8 60
			continue
		fi
		
		if echo $check_result | grep -i CHECK | grep -i OK 1>>/dev/null 2>>/dev/null
		then
			INPUT_OK="OK"
		fi
		
		if ! [ "$INPUT_OK" = "OK" ]; then
			sleep 1
			dialog --msgbox "Der eingegebene Lizenz-Schlüssel ist ungültig." 8 60
		fi
	done
	clear
	LICENSE_KEY=`echo $LICENSE_KEY | tr a-z A-Z`
	#echo "LICENSE_KEY = \"${LICENSE_KEY}\""
	echo "${LICENSE_KEY}" > /etc/.gemeinschaft-license.key

	
	
	
	WGET="wget"
	WGET_ARGS="-c -T 60 --no-check-certificate"
	DOWNLOAD="${WGET} ${WGET_ARGS}"
	
	
	
	# set up lang enviroment
	#
	echo ""
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
	echo ""
	echo "***"
	echo "***  Installing NTP ..."
	echo "***"
	${APTITUDE_INSTALL} ntp ntpdate
	/etc/init.d/ntp stop 2>>/dev/null || true
	ntpdate 0.debian.pool.ntp.org || true
	ntpdate 1.debian.pool.ntp.org || true
	/etc/init.d/ntp start
	sleep 3
	
	
	# make /var/run/ available as a ram file system (tmpfs).
	#
	sed -i -r -e 's/^(RAMRUN=)no/\1yes/' /etc/default/rcS || true
	
	
	
	echo ""
	echo "***"
	echo "***  Installing Xen ..."
	echo "***"
	
	LINUX_IMAGE_ARCH=`uname -r | awk 'BEGIN { FS = "-" } ; { print $NF }'`
	# e.g. "686" or "amd64"
	echo "    LINUX_IMAGE_ARCH = $LINUX_IMAGE_ARCH"
	
	DPKG_ARCH=`dpkg --print-architecture`
	# e.g. "i386" or "x86_64"
	echo "           DPKG_ARCH = $DPKG_ARCH"
	
	if ! aptitude show linux-image-xen-${LINUX_IMAGE_ARCH} 1>>/dev/null
	then
		echo ""
		echo "********************************************************************"
		echo "Sorry. Package \"linux-image-xen-${LINUX_IMAGE_ARCH}\" not available."
		echo "Your architecture \"${LINUX_IMAGE_ARCH}\" (`uname -m`) is not supported."
		echo "********************************************************************"
		exit 1
	fi
	
	${APTITUDE_INSTALL} \
	  linux-image-xen-${LINUX_IMAGE_ARCH} \
	  xen-hypervisor-${DPKG_ARCH} \
	  xen-utils
	
	# We have to reboot.
	echo "***"
	echo "***  Rebooting into Xen dom0 ..."
	echo "***"
	COUNTER=5
	while [  $COUNTER -gt 0 ]; do
		echo -n " ${COUNTER} "
		sleep 1
		let COUNTER=COUNTER-1
	done
	echo ""
	( sleep 10 ; reboot ) &
	( sleep 5 ; reboot ) &
	reboot || true
	exit 0
	
fi


# Xen kernel running.



#NON_XEN_KERNELS=`find /boot/ -mindepth 1 -maxdepth 1 -name 'initrd.img-*' -printf '%f\n' | grep -v virt | cut -d - -f 2-`
#if [ ! -z "$NON_XEN_KERNELS" ]; then
#	echo "Removing non-Xen kernels ..."
#	for k in $NON_XEN_KERNELS
#	do
#		echo "Removing kernel linux-image-$k ..."
#		aptitude -y remove linux-image-$k
#	done
#fi







echo ""
echo "***"
echo "***  Installing Gemeinschaft Xen domU ..."
echo "***"

echo "(FIXME)"

echo "DONE"






