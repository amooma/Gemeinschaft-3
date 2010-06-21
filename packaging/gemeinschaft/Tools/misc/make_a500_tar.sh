#!/bin/sh

rm -rf a500-install a500-install-$1.tar.gz && cp -r  a500 a500-install && rm -rf a500-install/.svn a500-install/*~ && tar cvfz a500-install-$1.tar.gz a500-install



