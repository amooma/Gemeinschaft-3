#!/bin/bash

# -- Philipp Kempgen

if [ -z $1 ]; then
	echo "Arg 1: Path to Debian source dir, e.g. \"../trunk/\""
	exit 1
fi
DEB_SRC_DIR=`pwd`/$1
if [ ! -d $DEB_SRC_DIR/. ]; then
	echo "$DEB_SRC_DIR is not a directory"
	exit 1
fi


cd $DEB_SRC_DIR || exit 1

#nice --adjustment=5 \
#	svn-buildpackage -us -uc -rfakeroot --svn-noninteractive --svn-rm-prev-dir --svn-dont-clean

nice --adjustment=5 \
	svn-buildpackage -us -uc -rfakeroot --svn-noninteractive --svn-rm-prev-dir

# final build (make changelog entry, create tag): ... --svn-tag
# (--svn-noautodch)

