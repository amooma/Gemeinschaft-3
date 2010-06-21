#!/bin/bash
#####################################################################
# $Revision: 320 $
# 
# Copyright 2008-2009, amooma GmbH, Bachstr. 126, 56566 Neuwied,
# Germany, http://www.amooma.de/
# Philipp Kempgen <philipp.kempgen@amooma.de>
# 
# Alle Rechte vorbehalten. -- All rights reserved.
#####################################################################


PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH

CWD=`pwd`
MYDIR=`pwd`/`dirname $0`

trap "echo '`basename $0` aborted!' >&2; exit 130" SIGINT SIGTERM SIGQUIT SIGHUP
trap "echo 'Error in `basename $0`!' >&2; exit 1" ERR



if [ -z $1 ] || [ -z $2 ]; then
	echo "Usage:  `basename $0` sourcedir maxcalls" >&2
	exit 1
fi

SRC_DIR=$1
if [ ! -e $SRC_DIR ]; then
	echo "Source dir \"${SRC_DIR}\" not found!" >&2
	exit 1
fi
if [ ! -d $SRC_DIR ]; then
	echo "Source dir \"${SRC_DIR}\" is not a directory!" >&2
	exit 1
fi

MAX_CALLS=$2



cd $SRC_DIR
if cat etc/asterisk/asterisk.conf | grep -m 1 -Ee '^\s*maxcalls' 1>>/dev/null; then
	echo "Setting maxcalls = $MAX_CALLS ..."
	sed -i -e "'s/^\s*maxcalls.*/maxcalls = ${MAX_CALLS}/'" \
	  etc/asterisk/asterisk.conf
else
	echo "Adding maxcalls = $MAX_CALLS ..."
	echo "" >> etc/asterisk/asterisk.conf
	echo "maxcalls = $MAX_CALLS    ;  :-)" >> etc/asterisk/asterisk.conf
	echo "" >> etc/asterisk/asterisk.conf
fi

