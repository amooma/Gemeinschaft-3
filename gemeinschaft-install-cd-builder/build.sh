#!/bin/bash

# Sustomizes a Debian installer ISO image.
# See http://wiki.debian.org/DebianInstaller/Modify/CD

# Stop on error
trap "echo 'Error!'; free_loop_devices; exit 1" ERR;

# Store my directory
MY_DIR=`pwd`/`dirname "$0"`

# Set PATH
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"

usage()
{
	USAGE=""
	USAGE="${USAGE}\n"
	USAGE="${USAGE}Usage: $0 what preseed_cfg_url\n"
	#USAGE="${USAGE}Usage: $0 what format\n"
	
	USAGE="${USAGE}\n"
	USAGE="${USAGE}  what:\n"
	USAGE="${USAGE}    debian-current-i386    (x86,    32 bit)\n"
	USAGE="${USAGE}    debian-current-amd64   (x86_64, 64 bit)\n"  # "amd64" on Debian = AMD-64 = Intel-64 = x86_64
	USAGE="${USAGE}    debian-testing-i386    (x86,    32 bit)  <-\n"
	USAGE="${USAGE}    debian-testing-amd64   (x86_64, 64 bit)  <-\n"
	
	#USAGE="${USAGE}\n"
	#USAGE="${USAGE}  format:\n"
	#USAGE="${USAGE}    iso    (ISO-9660 CD image)\n"
	#USAGE="${USAGE}    usb    (USB-HD image)\n"
	
	USAGE="${USAGE}\n"
	USAGE="${USAGE}  preseed_cfg_url: \n"
	USAGE="${USAGE}    URL of the preseed.cfg, e.g.:\n"
	USAGE="${USAGE}    http://www.amooma.de/gemeinschaft/installer/install-preseed-2.3.cfg\n"
	USAGE="${USAGE}    http://www.amooma.de/gemeinschaft/installer/install-preseed-2.3-eco.cfg\n"
	USAGE="${USAGE}    http://www.amooma.de/gemeinschaft/installer/install-preseed-2.3-business.cfg\n"
	
	echo -e "$USAGE" >&2
	exit 1
}

# Only root can loop-mount etc.
if [ "x`id -u`" != "x0" ]; then
	echo "Must be run as root!"
	exit 1
fi

free_loop_devices()
{
	echo "Trying to free loop devices ..."
	#FIXME
	for (( i=0; i<=7; i++ )); do
		losetup -d "/dev/loop$i" 2>>/dev/null || true
	done
	loopdirs=`ls -d ${MY_DIR}/loopdir-* 1>>/dev/null 2>>/dev/null || true`
	if [ ! -z $loopdirs ]; then
		for ldir in $loopdirs; do
			umount -dl $ldir 2>>/dev/null || true
			rm -rf $ldir 2>>/dev/null || true
		done
	fi
	for (( i=0; i<=7; i++ )); do
		umount -dl "${MY_DIR}/usb-tmp" 2>>/dev/null || true
	done
}

WHAT=$1
case $WHAT in
	"debian-current-i386")
		RELEASE="current"
		DEBIAN_ARCH="i386"
		KERNEL_INSTALL_DIR_ARCH="386"
		;;
	"debian-current-amd64")
		RELEASE="current"
		DEBIAN_ARCH="amd64"
		KERNEL_INSTALL_DIR_ARCH="amd"
		;;
	"debian-testing-i386")
		RELEASE="testing"
		DEBIAN_ARCH="i386"
		KERNEL_INSTALL_DIR_ARCH="386"
		;;
	"debian-testing-amd64")
		RELEASE="testing"
		DEBIAN_ARCH="amd64"
		KERNEL_INSTALL_DIR_ARCH="amd"
		;;
	*)
		usage;
		;;
esac

PRESEED_CFG_URL=$2
if [ -z $PRESEED_CFG_URL ]; then
	usage
fi

#FORMAT=$2
#case $FORMAT in
#	"iso")
#		;;
#	"usb")
#		;;
#	*)
#		usage;
#		;;
#esac
FORMAT="iso"

case $RELEASE in
	"current")
		# Find current Debian version
		DEBIAN_VERS_SHORT=`wget -O - "http://cdimage.debian.org/cdimage/release/current/${DEBIAN_ARCH}/iso-cd/" | grep -o 'debian-[0-9\.a-z]*-[a-z0-9_]*-businesscard\.iso' | head -n 1 | cut -d '-' -f 2`
		#DEBIAN_VERS_SHORT="501"
		if [ -z "${DEBIAN_VERS_SHORT}" ]; then
			echo "Could not find the current Debian version!"
			exit 1
		fi
		echo "The current Debian version is: ${DEBIAN_VERS_SHORT}"
		;;
	"testing")
		DEBIAN_VERS_SHORT="testing"
		;;
	*)
		usage;
		;;
esac

# Download
URL="http://cdimage.debian.org/cdimage"

case $RELEASE in
	"current")
		URL="${URL}/release/current/${DEBIAN_ARCH}/iso-cd/debian-${DEBIAN_VERS_SHORT}-${DEBIAN_ARCH}-businesscard.iso"
		;;
	"testing")
		URL="${URL}/daily-builds/testing/current/${DEBIAN_ARCH}/iso-cd/debian-${DEBIAN_VERS_SHORT}-${DEBIAN_ARCH}-businesscard.iso"
		;;
	*)
		;;
esac

mkdir -p "${MY_DIR}/downloads"
cd "${MY_DIR}/downloads"
wget -c "$URL"
cd "${MY_DIR}"

case $FORMAT in
	"usb")
		URL="http://ftp.debian.org/debian/dists/stable/main/installer-${DEBIAN_ARCH}/current/images/hd-media/boot.img.gz"
		cd "${MY_DIR}/downloads"
		wget -c \
			-O "hd-media-boot.img.gz" \
			"$URL"
		;;
esac
cd "${MY_DIR}"


free_loop_devices;


# Can't directly modify an ISO-9660 image so loop-mount it and copy
# the content

echo "Loop-mounting the Debian installer image ..."
LOOP_DIR="loopdir-$$"
mkdir -p "${MY_DIR}/${LOOP_DIR}"
if ! [[ `lsmod | grep '^loop'` ]]; then
	echo "Kernel module \"loop\" not loaded!"
	modprobe loop
	if ! [[ `lsmod | grep '^loop'` ]]; then
		echo "Failed to load kernel module \"loop\"!"
		echo "modprobe loop"
		exit 1
	fi
fi
cd "${MY_DIR}"
mount -o loop "downloads/debian-${DEBIAN_VERS_SHORT}-${DEBIAN_ARCH}-businesscard.iso" "${LOOP_DIR}" && err=0 || err=$?
if [ "x$err" == "x2" ]; then
	free_loop_devices;
	echo "Please run this script again."
	exit 1
	#echo "####################################################"
	#exec $0 $WHAT $FORMAT
	## never executed
	#exit 1
fi
echo "Copying contents of the Debian installer image ..."
rm -rf "cd" || true
mkdir -p "cd"
rsync -a -H --exclude=TRANS.TBL "${LOOP_DIR}/" "cd"
umount -dl "${LOOP_DIR}" || true
sleep 1
umount -df "${LOOP_DIR}" 2>>/dev/null || true
rm -rf "${LOOP_DIR}" 2>>/dev/null || true


# Customization
#

echo "Customizing ..."
cd "${MY_DIR}"

cat <<HEREDOC > "cd/isolinux/stdmenu.cfg"
menu background splash.png
menu color title	* #FFFFFFFF *
menu color border	* #00000000 #00000000 none
menu color sel		* #ffffffff #76a1d0ff *
menu color hotsel	1;7;37;40 #ffffffff #76a1d0ff *
menu color tabmsg	* #ffffffff #00000000 *
menu color help		37;40 #ffdddd00 #00000000 none
menu vshift 12
menu rows 10
menu helpmsgrow 15
# The command line must be at least one line from the bottom.
menu cmdlinerow 16
menu timeoutrow 16
menu tabmsgrow 18
menu tabmsg Press ENTER to boot or TAB to edit a menu entry
HEREDOC

cat <<HEREDOC > "cd/isolinux/menu.cfg"
menu hshift 17
menu width 59

menu title Gemeinschaft Installer boot menu
include stdmenu.cfg
include txt.cfg
include amdtxt.cfg
include gtk.cfg
include amdgtk.cfg
HEREDOC

<<\COMMENT
cat <<HEREDOC > "cd/isolinux/boot.msg"
0fWelcome to the GEMEINSCHAFT Auto Installer07 
HEREDOC
COMMENT

cat <<HEREDOC > "cd/isolinux/txt.cfg"
default install
label install
	menu label ^Install Gemeinschaft
	menu default
	kernel /install.${KERNEL_INSTALL_DIR_ARCH}/vmlinuz
	append url=${PRESEED_CFG_URL} hostname=gemeinschaft vga=normal initrd=/install.${KERNEL_INSTALL_DIR_ARCH}/initrd.gz -- quiet 
HEREDOC
<<\COMMENT
cat <<HEREDOC > "cd/isolinux/gtk.cfg"
label installgui
	menu label ^Install Gemeinschaft (graphical)
	kernel /install.${KERNEL_INSTALL_DIR_ARCH}/vmlinuz
	append url=${PRESEED_CFG_URL} hostname=gemeinschaft video=vesa:ywrap,mtrr vga=788 initrd=/install.${KERNEL_INSTALL_DIR_ARCH}/gtk/initrd.gz -- quiet 
HEREDOC
COMMENT
rm -f "cd/isolinux/gtk.cfg"    2>>/dev/null || true
rm -f "cd/isolinux/amdgtk.cfg" 2>>/dev/null || true
rm -rf "cd/install.${KERNEL_INSTALL_DIR_ARCH}/gtk" 2>>/dev/null || true

cp -f "splash.png" "cd/isolinux/splash.png"




# Fix md5sums
echo "Fixing checksums ..."
cd "${MY_DIR}/cd"
md5sum `find ! -name "md5sum.txt" ! -path "./isolinux/*" -follow -type f 2>>/dev/null` > "md5sum-NEW.txt"
mv -f "md5sum-NEW.txt" "md5sum.txt"
cd "${MY_DIR}"

# Create new image
OUT_FILE="out/gemeinschaft-installer-debian-${DEBIAN_VERS_SHORT}-${DEBIAN_ARCH}"
case $FORMAT in
	"iso")
		if ! [[ `which mkisofs` ]]; then
			echo "mkisofs not installed."
			echo "Installing mkisofs ..."
			aptitude install mkisofs
			if ! [[ `which mkisofs` ]]; then
				echo "mkisofs not installed!"
				exit 1
			fi
		fi
		echo "Generating ISO image ..."
		cd "${MY_DIR}"
		mkdir -p "out"
		OUT_FILE="${OUT_FILE}-cd.iso"
		mkisofs \
		  -o "${OUT_FILE}" \
		  -r -J \
		  -T \
		  -input-charset iso8859-1 \
		  -no-emul-boot -boot-load-size 4 -boot-info-table \
		  -b "isolinux/isolinux.bin" -c "isolinux/boot.cat" \
		  -V "Gemeinschaft-Installer" \
		  -p "Amooma GmbH, info@amooma.de" \
		  -publisher "Amooma GmbH, info@amooma.de" \
		  -A "Gemeinschaft" \
		  "./cd"
		echo "Here is your ISO image:"
		echo "  `dirname \"${MY_DIR}\"`/${OUT_FILE}"
		echo ""
		;;
	"usb")
		if ! [[ `which mkdosfs` ]]; then
			echo "mkdosfs not installed."
			echo "Installing dosfstools ..."
			aptitude install dosfstools
			if ! [[ `which mkdosfs` ]]; then
				echo "mkdosfs not installed!"
				exit 1
			fi
		fi
		#echo "Generating USB-HD image ..."
		cd "${MY_DIR}"
		
		echo "Unzipping USB image ..."
		zcat "${MY_DIR}/downloads/hd-media-boot.img.gz" > "${MY_DIR}/downloads/hd-media-boot.img"
		rm -rf "usb-tmp" 2>>/dev/null || true
		mkdir -p "usb-tmp"
		echo "Mounting USB image ..."
		mount -o loop -t vfat "${MY_DIR}/downloads/hd-media-boot.img" "usb-tmp" && err=0 || err=$?
		if [ "x$err" == "x2" ]; then
			free_loop_devices;
			echo "Please run this script again."
			exit 1
			#echo "####################################################"
			#exec $0 $WHAT $FORMAT
			## never executed
			#exit 1
		fi
		rm -rf usb-tmp/*
		echo "Generating USB image ..."
		cp -LpRu cd/* "usb-tmp"
		#rsync -a -H "cd/" "usb-tmp"
		umount -dl "usb-tmp" 2>>/dev/null || true
		sleep 1
		umount -df "usb-tmp" 2>>/dev/null || true
		rm -rf "usb-tmp"
		
		mkdir -p "out"
		OUT_FILE="${OUT_FILE}-usb-hd.img"
		#mkdosfs -v -F 16 -n "Gem" -S 512 ....
		
		echo "Here is your USB-HD image:"
		echo "  `dirname \"${MY_DIR}\"`/${OUT_FILE}"
		echo ""
		;;
esac

