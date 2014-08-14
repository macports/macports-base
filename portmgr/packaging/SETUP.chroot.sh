# !/bin/sh

# DarwinPorts chrooted automated build system setup.
# kevin@opendarwin.org
# 21-Feb-2003

# This should be run as uid 0, gid 0 from within the chroot.

# Set up some necessary environment variables.

export PATH=/opt/local/bin:/usr/X11R6/bin:${PATH}
export HOME=/Users/Shared
export CVSROOT=:pserver:anoncvs@anoncvs.opendarwin.org:/Volumes/src/cvs/od

export MACOSX_DEPLOYMENT_TARGET=10.2
export UNAME_RELEASE=6.0

# Update the copy of darwinports from cvs,
# sync the ports tree, and re-index.

cd $HOME/darwinports
cvs update
make
make install
port sync
cd dports
portindex

# Start building ports
mkdir -p /darwinports/distfiles
mkdir -p /darwinports/logs
mkdir -p /darwinports/pkgs
mkdir -p /darwinports/mpkgs

cd $HOME/darwinports
#tclsh base/src/portmgr/packageall.tcl

bash
