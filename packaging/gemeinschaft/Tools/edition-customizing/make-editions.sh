#!/bin/bash
#####################################################################
#                           Gemeinschaft
#                            repo tools
# 
# $Revision: 325 $
# 
# Copyright 2008-2009, amooma GmbH, Bachstr. 126, 56566 Neuwied,
# Germany, http://www.amooma.de/
# Philipp Kempgen <philipp.kempgen@amooma.de>
# 
# Alle Rechte vorbehalten. -- All rights reserved.
#####################################################################


# ======== CONFIGURATION ======== {
#
PRESEED_CFG_VERSION="2.3"   # ../misc/install-preseed-*.cfg
#
# ======== CONFIGURATION ======== }


PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

CWD=`pwd`
MYDIR=`pwd`/`dirname $0`

TMPDIR="/var/tmp/${PROJECT_NAME}-`date '+%Y%m%d-%H%M%S'`-$$"

trap "rm -rf ${TMPDIR} 2>>/dev/null" EXIT
trap "echo 'Aborted!' >&2; exit 130" SIGINT SIGTERM SIGQUIT SIGHUP
trap "echo 'Error!' >&2; exit 1" ERR

if [ -z $1 ] || [ -z $2 ]; then
	echo "Usage:  `basename $0` tarball edition" >&2
	echo "   tarball:  original Gemeinschaft tarball," >&2
	echo "             e.g. \"/tmp/gemeinschaft-2.3.1.tgz\"" >&2
	echo "   edition:  name of the edition to generate" >&2
	exit 1
fi

ORIGINAL_TGZ=$1
cd $CWD
if [ ! -e $ORIGINAL_TGZ ]; then
	echo "Input tarball \"${ORIGINAL_TGZ}\" not found!" >&2
	exit 1
fi

EDITION=$2

# scan for customizer scripts
EDITIONS=""
cd $MYDIR
for SCRIPT in scripts/edition-*.sh; do
	if [ ! -e "$SCRIPT" ]; then
		continue
	fi
	ED=`echo ${SCRIPT} | cut -d '/' -f 2- | cut -d '-' -f 2- | cut -d '.' -f 1`
	EDITIONS="${EDITIONS} ${ED}"
done

# check if edition script is available
HAVE_EDITION_SCRIPT=0
for ED in $EDITIONS; do
	if [ $ED == $EDITION ]; then
		HAVE_EDITION_SCRIPT=1
		break
	fi
done
if [ $HAVE_EDITION_SCRIPT != 1 ]; then
	echo "\"scripts/edition-${EDITION}.sh\" not found!" >&2
	echo -n "Available editions: "
	for ED in $EDITIONS; do
		echo -n " \"$ED\""
	done
	echo ""
	exit 1
fi

# create temporary directory
mkdir -p "${TMPDIR}"

# copy original tarball to tmpdir
cd $CWD
cp ${ORIGINAL_TGZ} ${TMPDIR}/

# unpack original tarball
echo "Unpacking tarball \"$TMPDIR/`basename $ORIGINAL_TGZ`\" ..." >&2
cd $TMPDIR
tar -xzf `basename $ORIGINAL_TGZ`
rm `basename $ORIGINAL_TGZ`
GEMEINSCHAFT_SRC=$TMPDIR/`basename $ORIGINAL_TGZ .tgz`
if [ ! -d $GEMEINSCHAFT_SRC ]; then
	echo "Expected top-level directory \"`basename $GEMEINSCHAFT_SRC`\" in tarball!" >&2
	exit 1
fi

# modify Gemeinschaft version
echo "Modifying Gemeinschaft version ..." >&2
cd $GEMEINSCHAFT_SRC
if [ ! -e $GEMEINSCHAFT_SRC/etc/gemeinschaft/.gemeinschaft-version ]; then
	echo "Expected \"etc/gemeinschaft/.gemeinschaft-version\" in the tarball!" >&2
	exit 1
fi
ORIG_VERSION=`head -n 1 etc/gemeinschaft/.gemeinschaft-version`
echo "Original version :  $ORIG_VERSION" >&2
EDITION_VERSION="${ORIG_VERSION}-${EDITION}"
echo "Edition version  :  $EDITION_VERSION" >&2
echo -n ${EDITION_VERSION} > etc/gemeinschaft/.gemeinschaft-version

cd $TMPDIR
mv `basename ${GEMEINSCHAFT_SRC}` `basename ${GEMEINSCHAFT_SRC}-${EDITION}`
GEMEINSCHAFT_SRC=$TMPDIR/`basename ${GEMEINSCHAFT_SRC}-${EDITION}`

# call customization script
echo "Calling \"./scripts/edition-${EDITION}.sh\" ..." >&2
cd $MYDIR
./scripts/edition-${EDITION}.sh $GEMEINSCHAFT_SRC

# pack new tarball
echo "Packing new tarball \"`basename ${GEMEINSCHAFT_SRC}`.tgz\" ..." >&2
cd $GEMEINSCHAFT_SRC/../
tar czf `basename ${GEMEINSCHAFT_SRC}`.tgz \
  --owner=root --group=root \
  `basename ${GEMEINSCHAFT_SRC}`

mv `basename ${GEMEINSCHAFT_SRC}`.tgz $MYDIR/out/
echo "+-------------------------------------------------------------"
echo "|  Here is the tarball:" >&2
echo "|    out/`basename ${GEMEINSCHAFT_SRC}`.tgz" >&2
echo "+-------------------------------------------------------------"
echo ""


# find latest matching install script
cd $MYDIR
INSTALL_SCRIPT=`ls ../misc/install-gemeinschaft-${ORIG_VERSION}-*.sh | sort -nr | head -n 1`
if [ -z $INSTALL_SCRIPT ]; then
	echo "Did not find matching \"../misc/install-gemeinschaft-${ORIG_VERSION}-*.sh\"" >&2
	exit 1
fi
echo "Matching install script: \"$INSTALL_SCRIPT\"" >&2
echo "Modifying install script ..." >&2
cat $INSTALL_SCRIPT \
  | sed -e s/^\s*GEMEINSCHAFT_VERS\s*=.*/GEMEINSCHAFT_VERS='"'${ORIG_VERSION}-${EDITION}'"'/ \
  > out/`basename $INSTALL_SCRIPT .sh`-${EDITION}.sh
echo "Checking install script ..." >&2
cat out/`basename $INSTALL_SCRIPT .sh`-${EDITION}.sh \
  | grep '^\s*GEMEINSCHAFT_VERS\s*='
echo "+-------------------------------------------------------------"
echo "|  Here is the install script:" >&2
echo "|    out/`basename $INSTALL_SCRIPT .sh`-${EDITION}.sh" >&2
echo "+-------------------------------------------------------------"
echo ""

# modify install-preseed-*.cfg
cd $MYDIR
PRESEED_CFG=../misc/install-preseed-${PRESEED_CFG_VERSION}.cfg
echo "Modifying `basename $PRESEED_CFG` ..." >&2
cat $PRESEED_CFG \
  | sed -r -e s/install-gemeinschaft-"("[0-9.a-z]*")"-current.sh/install-gemeinschaft-"\\"1-${EDITION}-current.sh/g \
  > out/`basename $PRESEED_CFG .cfg`-${EDITION}.cfg
echo "Checking preseed.cfg ..." >&2
cat out/`basename $PRESEED_CFG .cfg`-${EDITION}.cfg \
  | grep 'install-gemeinschaft-.*-'${EDITION}'-current\.sh'
echo "+-------------------------------------------------------------"
echo "|  Here is the preseed.cfg:" >&2
echo "|    out/`basename $PRESEED_CFG .cfg`-${EDITION}.cfg" >&2
echo "+-------------------------------------------------------------"
echo ""


echo ""
echo ""
echo "Summary:"
echo "+-------------------------------------------------------------"
echo "|  Here is the tarball:" >&2
echo "|    out/`basename ${GEMEINSCHAFT_SRC}`.tgz" >&2
echo "+-------------------------------------------------------------"
#echo ""
echo "+-------------------------------------------------------------"
echo "|  Here is the install script:" >&2
echo "|    out/`basename $INSTALL_SCRIPT .sh`-${EDITION}.sh" >&2
echo "+-------------------------------------------------------------"
#echo ""
echo "+-------------------------------------------------------------"
echo "|  Here is the preseed.cfg:" >&2
echo "|    out/`basename $PRESEED_CFG .cfg`-${EDITION}.cfg" >&2
echo "+-------------------------------------------------------------"
#echo ""


exit 0
