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
SPAM_LOVERS=macports-dev@lists.macosforge.org,dluke@geeklair.net,markd@macports.org

# Other settings (probably don't need to be changed).
SVN_CONFIG_DIR=${ROOT}/svnconfig
REPO_BASE=http://svn.macports.org/repository/macports
SVN="/opt/local/bin/svn -q --non-interactive --config-dir $SVN_CONFIG_DIR"
# Where to checkout the source code. This needs to exist!
SRCTREE=${ROOT}/source
# Where MP will install its world. This gets created.
PREFIX=/opt/local
# Path.
PATH=${PREFIX}/bin:/bin:/usr/bin:/usr/sbin:/opt/local/bin
# Log for the e-mail in case of failure.
FAILURE_LOG=${ROOT}/guide_failure.log
# The date.
DATE=$(date +'%A %Y-%m-%d at %H:%M:%S')


# Function to spam people in charge if something goes wrong during guide regen.
bail () {
    mail -s "Guide Regen Failure on ${DATE}" $SPAM_LOVERS < $FAILURE_LOG
    cleanup; exit 1
}

# Cleanup fuction for runtime files.
cleanup () {
    rm -f $FAILURE_LOG $LOCKFILE
}


if [ ! -e $LOCKFILE ]; then
    touch $LOCKFILE
else
    echo "Guide Regen lockfile found, is another regen job running?"
    exit 1
fi

# Checkout/update the doc tree
if [ -d ${SRCTREE}/doc-new ]; then
    $SVN update ${SRCTREE}/doc-new > $FAILURE_LOG 2>&1 \
        || { echo "Updating the doc tree from $REPO_BASE/trunk/doc-new failed." >> $FAILURE_LOG; bail ; }
else
    $SVN checkout ${REPO_BASE}/trunk/doc-new ${SRCTREE}/doc-new > $FAILURE_LOG 2>&1 \
        || { echo "Checking out the doc tree from $REPO_BASE/trunk/doc-new failed." >> $FAILURE_LOG; bail ; }
fi

# (re)build
{ cd ${SRCTREE}/doc-new && make guide > $FAILURE_LOG 2>&1 ; } \
    || { echo "make failed." >> $FAILURE_LOG ; bail ; }

# At this point the guide was regen'd successfuly, so we cleanup before we exit.
cleanup && exit 0
