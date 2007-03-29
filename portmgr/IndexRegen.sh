#!/bin/bash

####
# PortIndex regen automation script.
# Created by Juan Manuel Palacios,
# e-mail: jmpp@macports.org
# Updated by Paul Guyot, <pguyot@kallisys.net>
# Updated for svn by Daniel J. Luke <dluke@geeklair.net>
# $Id$
####

# Configuration
LOCKFILE=/tmp/.mp_svn_index_regen.lock
# ROOT directory, where everything is. This needs to exist!
ROOT=/Users/dluke/Projects/mp_svn_index_regen
# MP user.
MP_USER=dluke
# MP group.
MP_GROUP=staff
# e-mail address to spam in case of failure.
SPAM_LOVERS=macports-mgr@lists.macosforge.org,dluke@geeklair.net

# Other settings (probably don't need to be changed).
SVN_DPORTS_URL=http://svn.macports.org/repository/macports/trunk/dports
SVN_BASE_URL=http://svn.macports.org/repository/macports/trunk/base
SVN_CONFIG_DIR=${ROOT}/svnconfig
# Where to checkout the source code. This needs to exist!
SRCTREE=${ROOT}/source
# Where MP will install its world. This gets created.
PREFIX=${ROOT}/opt/local
# Where MP installs darwinports1.0. This gets created.
TCLPKG=${PREFIX}/lib/tcl
# Path.
PATH=${PREFIX}/bin:/bin:/usr/bin:/opt/local/bin
# Log for the e-mail in case of failure.
FAILURE_LOG=${ROOT}/failure.log
# Commit message.
COMMIT_MSG=${ROOT}/commit.msg
# The date.
DATE=$(date +'%A %Y-%m-%d at %H:%M:%S')


# Function to spam people in charge if something goes wrong during indexing.
bail () {
    mail -s "AutoIndex Failure on ${DATE}" $SPAM_LOVERS < $FAILURE_LOG
    cleanup; exit 1
}

# Cleanup fuction for runtime files.
cleanup () {
    rm -f $COMMIT_MSG $FAILURE_LOG
    rm -f $LOCKFILE
}


if [ ! -e $LOCKFILE ]; then
    touch $LOCKFILE
else
    echo "Index Regen lockfile found, is another index regen running?"
    exit 1
fi

# Update both the ports tree and base sources, bail out if they don't exist beforehand.
if [ ! -d ${SRCTREE}/dports/.svn ]; then
    echo "No dports tree found at ${SRCTREE}. This needs to exist (with proper svn \
        credentials at ${SVN_CONFIG_DIR}) prior to runnig this script." > $FAILURE_LOG; bail
else
    cd ${SRCTREE}/dports && \
	svn -q --non-interactive --config-dir $SVN_CONFIG_DIR update > $FAILURE_LOG 2>&1 \
	|| { echo "Updating the ports tree from $SVN_DPORTS_URL failed." >> $FAILURE_LOG ; bail ; }
fi
if [ ! -d ${SRCTREE}/base/.svn ]; then
    echo "No base sources found at ${SRCTREE}. This needs to exist (with proper svn \
        credentials at ${SVN_CONFIG_DIR}) prior to running this script." > $FAILURE_LOG; bail
else
    cd ${SRCTREE}/base && \
	svn -q --non-interactive --config-dir $SVN_CONFIG_DIR update > $FAILURE_LOG 2>&1 \
       || { echo "Updating the base sources from $SVN_BASE_URL failed." >> $FAILURE_LOG ; bail ; }
fi

# (re)configure.
cd ${SRCTREE}/base/ && \
    mkdir -p ${TCLPKG} && \
    ./configure \
    --prefix=${PREFIX} \
    --with-tclpackage=${TCLPKG} \
    --with-install-user=${MP_USER} \
    --with-install-group=${MP_GROUP} > $FAILURE_LOG 2>&1 \
    || { echo "./configure script failed." >> $FAILURE_LOG ; bail ; }

# clean
# (cleaning is useful because we don't want the indexing to fail because dependencies aren't properly computed).
{ cd ${SRCTREE}/base/ && make clean > $FAILURE_LOG 2>&1 ; } \
    || { echo "make clean failed." >> $FAILURE_LOG ; bail ; }

# (re)build
{ cd ${SRCTREE}/base/ && make > $FAILURE_LOG 2>&1 ; } \
    || { echo "make failed." >> $FAILURE_LOG ; bail ; }

# (re)install
{ cd ${SRCTREE}/base/ && make install > $FAILURE_LOG 2>&1 ; } \
    || { echo "make install failed." >> $FAILURE_LOG ; bail ; }

# (re)index
{ cd ${SRCTREE}/dports/ && ${PREFIX}/bin/portindex > $FAILURE_LOG 2>&1 ; } \
    || { echo "portindex failed." >> $FAILURE_LOG ; bail ; }

# Commit the new index using the last 5 lines of the log for the commit message,
tail -n 5 $FAILURE_LOG > $COMMIT_MSG
# plus parsing failures, if any.
echo "" >> $COMMIT_MSG
grep Failed $FAILURE_LOG >> $COMMIT_MSG
{ cd ${SRCTREE}/dports/ && \
    svn --config-dir $SVN_CONFIG_DIR commit -F $COMMIT_MSG PortIndex > $FAILURE_LOG 2>&1 ; } \
    || { echo "SVN commit failed." >> $FAILURE_LOG ; bail ; }

# At this point the index was committed successfuly, so we cleanup before we exit.
cleanup
