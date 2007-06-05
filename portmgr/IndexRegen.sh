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
ROOT=/Users/mp-user/mp_svn_index_regen
# MP user.
MP_USER=mp-user
# MP group.
MP_GROUP=mp-user
# e-mail address to spam in case of failure.
SPAM_LOVERS=macports-mgr@lists.macosforge.org,dluke@geeklair.net

# Other settings (probably don't need to be changed).
SVN_CONFIG_DIR=${ROOT}/svnconfig
REPO_BASE=http://svn.macports.org/repository/macports
RELEASE_URL_FILE="config/RELEASE_URL"
SVN="/opt/local/bin/svn -q --non-interactive --config-dir $SVN_CONFIG_DIR"
# Where to checkout the source code. This needs to exist!
SRCTREE=${ROOT}/source
# Where MP will install its world. This gets created.
PREFIX=${ROOT}/opt/local
# Where MP installs macports1.0. This gets created.
TCLPKG=${PREFIX}/lib/tcl
# Path.
PATH=${PREFIX}/bin:/bin:/usr/bin:/usr/sbin:/opt/local/bin
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

# Checkout/update the ports tree
if [ -d ${SRCTREE}/dports ]; then
    $SVN update ${SRCTREE}/dports > $FAILURE_LOG 2>&1 \
	|| { echo "Updating the ports tree from $REPO_BASE/trunk/dports failed." >> $FAILURE_LOG; bail ; }
else
    $SVN checkout ${REPO_BASE}/trunk/dports ${SRCTREE}/dports > $FAILURE_LOG 2>&1 \
	|| { echo "Checking out the ports tree from $REPO_BASE/trunk/dports failed." >> $FAILURE_LOG ; bail ; }
fi
echo `date -u +%s` > ${ROOT}/PORTS-TIMESTAMP

# Checkout/update HEAD
TMPDIR=mp_trunk/base
if [ -d ${ROOT}/${TMPDIR} ]; then
    $SVN update ${ROOT}/${TMPDIR} > $FAILURE_LOG 2>&1 \
	|| { echo "Updating the trunk from $REPO_BASE/trunk/base failed." >> $FAILURE_LOG; bail ; }
else
    $SVN checkout ${REPO_BASE}/trunk/base ${ROOT}/${TMPDIR} > $FAILURE_LOG 2>&1 \
       || { echo "Checking out the trunk from $REPO_BASE/trunk/base failed." >> $FAILURE_LOG ; bail ; }
fi

# Extract the release URL from HEAD
read RELEASE_URL < ${ROOT}/${TMPDIR}/${RELEASE_URL_FILE}
[ -n ${RELEASE_URL} ] || { echo "no RELEASE_URL specified in svn HEAD." >> $FAILURE_LOG; bail ; }

# Checkout/update the release base
if [ -d ${SRCTREE}/base ]; then
    $SVN switch ${RELEASE_URL} ${SRCTREE}/base > $FAILURE_LOG 2>&1 \
	|| { echo "Updating base from ${RELEASE_URL} failed." >> $FAILURE_LOG; bail ; }
else
    $SVN checkout ${RELEASE_URL} ${SRCTREE}/base > $FAILURE_LOG 2>&1 \
	|| { echo "Checking out base from ${RELEASE_URL} failed." >> $FAILURE_LOG ; bail ; }
fi
echo `date -u +%s` > ${ROOT}/BASE-TIMESTAMP

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
cleanup && exit 0
