#!/bin/bash
#####################################################################
#                           Gemeinschaft
#                            repo tools
# 
# $Revision: 340 $
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
REPO_PATH="https://svn.amooma.com/gemeinschaft"
PROJECT_NAME="gemeinschaft"
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
TAG_AND_VERSION=`cd "${PROJECT_DIR}" && ./get-version`
echo -n "${TAG_AND_VERSION}" > "${PROJECT_DIR}/etc/gemeinschaft/.gemeinschaft-version"
REV_SUFFIX=`echo -n ${TAG_AND_VERSION} | grep -oEe '-r[0-9]+' | head -n 1 || true`
if [ ! -z "${REV_SUFFIX}" ]; then
	TAG_AND_VERSION="${TAG_NAME}${REV_SUFFIX}"
fi

cd "${PROJECT_DIR}"
tar czf "${PROJECT_DIR}.tgz" \
  --owner=root --group=root \
  --exclude '\.svn' \
  --exclude '\.git' \
  --exclude 'get-version' \
  --exclude 'svn-diff-incremental.sh' \
  -C "${TMPDIR}" \
  "${PROJECT_NAME}-${TAG_NAME}"
mv "${PROJECT_DIR}.tgz" "/tmp/${PROJECT_NAME}-${TAG_AND_VERSION}.tgz"
echo ""
echo "***  Here's your archive: /tmp/${PROJECT_NAME}-${TAG_AND_VERSION}.tgz"
echo ""

exit 0

