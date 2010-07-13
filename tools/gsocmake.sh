#!/bin/bash

source ~/.bash_macports
read _ user <<< $(id -p | grep login )
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
MP_PREFIX=/opt/mp-gsoc
port cd gsoc
sudo -u "$user" make distclean
sudo -u "$user" ./configure --prefix=$MP_PREFIX \
    --with-tclpackage=$MP_PREFIX/Library/Tcl \
    --with-applications-dir=$MP_PREFIX/Applications
sudo -u "$user" make
make install

