#!/bin/bash
#####################################################################
# $Revision: 318 $
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



if [ -z $1 ]; then
	echo "Usage:  `basename $0` sourcedir" >&2
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


# set maxcalls in Asterisk to 5
cd $MYDIR
./shared-set-asterisk-maxcalls.sh $SRC_DIR 5


# more customizations
#...


