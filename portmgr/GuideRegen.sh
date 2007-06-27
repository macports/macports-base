#!/bin/bash

####
# Guide regen automation script.
# Created by Daniel J. Luke
# e-mail: dluke@geeklair.net
# Based on IndexRegen.sh
# $Id$
####

# Configuration
LOCKFILE=/tmp/.mp_svn_guide_regen.lock
# ROOT directory, where everything is. This needs to exist!
ROOT=/Users/mp-user/mp_svn_guide_regen
# MP user.
MP_USER=mp-user
# MP group.
MP_GROUP=mp-user
# e-mail address to spam in case of failure.
SPAM_LOVERS=macports-mgr@lists.macosforge.org,dluke@geeklair.net

# Other settings (probably don't need to be changed).
SVN_CONFIG_DIR=${ROOT}/svnconfig
REPO_BASE=http://svn.macports.org/repository/macports
SVN="/opt/local/bin/svn -q --non-interactive --config-dir $SVN_CONFIG_DIR"
# Where to checkout the source code. This needs to exist!
SRCTREE=${ROOT}/source
# Where MP will install its world. This gets created.
PREFIX=/opt/local
# Where MP installs darwinports1.0. This gets created.
# Path.
PATH=${PREFIX}/bin:/bin:/usr/bin:/usr/sbin:/opt/local/bin
# Log for the e-mail in case of failure.
FAILURE_LOG=${ROOT}/guide_failure.log
# Commit message.
COMMIT_MSG=${ROOT}/commit.msg
# The date.
DATE=$(date +'%A %Y-%m-%d at %H:%M:%S')


# Function to spam people in charge if something goes wrong during indexing.
bail () {
    mail -s "Guide regen Failure on ${DATE}" $SPAM_LOVERS < $FAILURE_LOG
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
    echo "Guide regen lockfile found, is another index regen running?"
    exit 1
fi

# Checkout/update the doc tree
if [ -d ${SRCTREE}/doc ]; then
    $SVN update ${SRCTREE}/doc > $FAILURE_LOG 2>&1 \
        || { echo "Updating the doc tree from $REPO_BASE/trunk/doc failed." >> $FAILURE_LOG; bail ; }
else
    $SVN checkout ${REPO_BASE}/trunk/doc ${SRCTREE}/doc > $FAILURE_LOG 2>&1 \
        || { echo "Checking out the doc tree from $REPO_BASE/trunk/s failed." >> $FAILURE_LOG; bail ; }
fi

# Checkout/update HEAD
if [ -d ${SRCTREE}/base ]; then
    $SVN update ${SRCTREE}/base > $FAILURE_LOG 2>&1 \
        || { echo "Updating the trunk from $REPO_BASE/trunk/base failed." >> $FAILURE_LOG; bail ; }
else
    $SVN checkout ${REPO_BASE}/trunk/base ${SRCTREE}/base > $FAILURE_LOG 2>&1 \
        || { echo "Checking out the trunk from $REPO_BASE/trunk/base failed." >> $FAILURE_LOG; bail ; }
fi

# (re)configure.
cd ${SRCTREE}/base/ && \
    ./configure \
    --prefix=${PREFIX} \
    --with-install-user=${MP_USER} \
    --with-install-group=${MP_GROUP} > $FAILURE_LOG 2>&1 \
    || { echo "./configure script failed." >> $FAILURE_LOG ; bail ; }

# (re)build
{ cd ${SRCTREE}/doc/guide && make xhtml > $FAILURE_LOG 2>&1 ; } \
    || { echo "make failed." >> $FAILURE_LOG ; bail ; }

# At this point the guide was regen'd successfuly, so we cleanup before we exit.
cleanup
