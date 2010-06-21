#!/bin/bash
#####################################################################
#                           Gemeinschaft
#                            repo tools
# 
# $Revision: 280 $
# 
# Copyright 2008-2009, amooma GmbH, Bachstr. 126, 56566 Neuwied,
# Germany, http://www.amooma.de/
# Philipp Kempgen <philipp.kempgen@amooma.de>
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#####################################################################


# ======== CONFIGURATION ======== {
#
#if [ "`hostname -f`" != "oahu.amooma.com" ]; then
	REPO_PATH="https://svn.amooma.com/gs-siemens"
#else
#	REPO_PATH="https://127.0.0.1/gs-siemens"
#fi
PROJECT_NAME="gemeinschaft-siemens"
#
# ======== CONFIGURATION ======== }



PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

TMPDIR="/var/tmp/${PROJECT_NAME}-`date '+%Y%m%d-%H%M%S'`-$$"

trap "rm -rf ${TMPDIR} 2>>/dev/null" EXIT
trap "echo ''; echo 'Aborted!' >&2; exit 130" SIGINT SIGTERM SIGQUIT SIGHUP
trap "echo ''; echo 'Error!' >&2; exit 1" ERR

if [ -z $1 ]; then
	echo "Usage:  `basename $0` tag"
	echo "  tag: e.g. \"tags/2.0.0\" or \"trunk\""
	exit 1
fi
TAG=$1
TAG_NAME=`echo -n ${TAG} | sed 's/^tags\///' | sed 's/\//-/g'`
#echo $TAG
#echo $TAG_NAME

PROJECT_DIR="${TMPDIR}/${PROJECT_NAME}-${TAG_NAME}"

mkdir -p "${TMPDIR}"
svn co --no-auth-cache --non-interactive "${REPO_PATH}/${TAG}" "${PROJECT_DIR}"
#cd "${PROJECT_DIR}" && ./get-version > "etc/gemeinschaft/.gemeinschaft-version"
cd "${PROJECT_DIR}" && \
	LANG=C svnversion -c | grep -oEe '[0-9]+' | tail -n 1 \
	> ${PROJECT_DIR}/../${PROJECT_NAME}-${TAG_NAME}.rev
REV=`cat ${PROJECT_DIR}/../${PROJECT_NAME}-${TAG_NAME}.rev`
REV=`echo ${REV} \
	| sed -e 's:^[0-9]$:0\0:' \
	| sed -e 's:^[0-9][0-9]$:0\0:' \
	| sed -e 's:^[0-9][0-9][0-9]$:0\0:' \
	| sed -e 's:^[0-9][0-9][0-9][0-9]$:0\0:'`
cd ${PROJECT_DIR}/../
rm ${PROJECT_NAME}-${TAG_NAME}.rev
ORIG="${PROJECT_NAME}-${TAG_NAME}-r${REV}.orig"
DEST="${PROJECT_NAME}-${TAG_NAME}-r${REV}"
mv ${PROJECT_NAME}-${TAG_NAME} ${ORIG}
mkdir ${DEST}
mkdir -p ${DEST}/opt
mkdir -p ${DEST}/opt/gemeinschaft-siemens
mkdir -p ${DEST}/opt/gemeinschaft-siemens/firmware
mkdir -p ${DEST}/opt/gemeinschaft-siemens/firmware/os40
mkdir -p ${DEST}/opt/gemeinschaft-siemens/firmware/os40/01.05.03.000
mkdir -p ${DEST}/opt/gemeinschaft-siemens/firmware/os80
mkdir -p ${DEST}/opt/gemeinschaft-siemens/firmware/os80/01.05.03.000
mkdir -p ${DEST}/doc
mkdir -p ${DEST}/doc/etc-apache2-ssl
cp -dp ${ORIG}/opt/gemeinschaft-siemens/os-firmware-identify ${DEST}/opt/gemeinschaft-siemens/
cp -dp ${ORIG}/opt/gemeinschaft-siemens/prov-checkcfg.php ${DEST}/opt/gemeinschaft-siemens/
cp -dp ${ORIG}/opt/gemeinschaft-siemens/prov-settings.php ${DEST}/opt/gemeinschaft-siemens/
cp -dp ${ORIG}/opt/gemeinschaft-siemens/conf.php ${DEST}/opt/gemeinschaft-siemens/
cp -dp ${ORIG}/opt/gemeinschaft-siemens/firmware/wallpaper1.jpg ${DEST}/opt/gemeinschaft-siemens/firmware/
cp -dp ${ORIG}/doc/ssl-certificate.txt ${DEST}/doc/
cp -dp ${ORIG}/doc/dhcpd.conf.example ${DEST}/doc/
cp -dp ${ORIG}/doc/httpd-vhost.conf.example ${DEST}/doc/
cp -dp ${ORIG}/doc/INSTALL.txt ${DEST}/doc/
cp -dp ${ORIG}/doc/etc-apache2-ssl/gen-cert.sh ${DEST}/doc/etc-apache2-ssl/
cd ${DEST}/opt/gemeinschaft-siemens/firmware/
ln -snf os80 os60
ln -snf os40 os20


cd ${TMPDIR}
tar czf "${DEST}.tgz" \
  --owner=root --group=root \
  --exclude '\.svn' \
  --exclude 'nda' \
  --exclude 'opera_bind.img' \
  -C "${TMPDIR}" \
  "${DEST}"
mv "${DEST}.tgz" "/tmp/${DEST}.tgz"
echo ""
echo "***  Here's your archive: /tmp/${DEST}.tgz"
echo ""

exit 0

